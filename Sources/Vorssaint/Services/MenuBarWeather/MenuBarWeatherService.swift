// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// A menu bar item with the current temperature in Fahrenheit and Celsius
/// at once, which macOS's own Weather item cannot show.
///
/// Off by default, because it is the one thing in the menu bar that reaches
/// the network on its own: every 15 minutes and on wake, it asks Open-Meteo
/// for one city's current conditions. Nothing else is sent. Clicking it
/// opens the Weather app for the full forecast.
///
/// Nothing runs while the feature is off: no status item, no timer, no
/// requests.
final class MenuBarWeatherService: ObservableObject {
    static let shared = MenuBarWeatherService()

    private static let autosaveName = "dynamai.menuBarWeather"
    private static let weatherAppBundle = "com.apple.weather"

    /// Whether the last refresh failed, for the Settings caption.
    @Published private(set) var lastRefreshFailed = false

    private var item: NSStatusItem?
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var reading: MenuBarWeatherSupport.Reading?
    /// Coordinates are looked up once per city, not on every refresh.
    private var place: (city: String, place: SiriAssistantSupport.Place)?
    private var refreshTask: Task<Void, Never>?

    private init() {}

    func syncWithPreferences() {
        if AppFeature.menuBarWeather.isAvailable,
           UserDefaults.standard.bool(forKey: DefaultsKey.menuBarWeatherEnabled) {
            start()
        } else {
            stop()
        }
    }

    /// The city field changed: forget its coordinates and fetch again.
    func cityChanged() {
        place = nil
        guard item != nil else { return }
        refresh()
    }

    private func start() {
        guard item == nil else { return }
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = Self.autosaveName
        item = statusItem
        statusItem.isVisible = true
        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(clicked)
            button.identifier = NSUserInterfaceItemIdentifier(Self.autosaveName)
        }
        render()
        timer = Timer.scheduledTimer(withTimeInterval: MenuBarWeatherSupport.refreshInterval,
                                     repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer?.tolerance = 60
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            // The network is rarely back the instant the Mac wakes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self?.refresh() }
        }
        refresh()
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        timer?.invalidate()
        timer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        wakeObserver = nil
        if let item {
            NSStatusBar.system.removeStatusItem(item)
        }
        item = nil
        reading = nil
    }

    private func refresh() {
        let city = MenuBarWeatherSupport.city(
            typed: UserDefaults.standard.string(forKey: DefaultsKey.menuBarWeatherCity) ?? "",
            timeZone: .current)
        let known = place?.city == city ? place?.place : nil
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            let result = await Self.fetch(city: city, known: known, language: language)
            await MainActor.run {
                guard let self, !Task.isCancelled, self.item != nil else { return }
                if let result {
                    self.place = (city, result.place)
                    self.reading = result.reading
                }
                // A failed refresh keeps the last reading rather than blanking.
                self.lastRefreshFailed = result == nil
                self.render()
            }
        }
    }

    private static func fetch(city: String, known: SiriAssistantSupport.Place?, language: String) async
        -> (place: SiriAssistantSupport.Place, reading: MenuBarWeatherSupport.Reading)? {
        var place = known
        if place == nil {
            guard let url = SiriAssistantSupport.geocodingURL(city: city, language: language),
                  let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
            place = SiriAssistantSupport.place(fromGeocoding: data)
        }
        guard let place,
              let url = SiriAssistantSupport.forecastURL(latitude: place.latitude, longitude: place.longitude,
                                                         fahrenheit: false),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let reading = MenuBarWeatherSupport.reading(fromForecast: data) else { return nil }
        return (place, reading)
    }

    private func render() {
        guard let button = item?.button else { return }
        let strings = FeatureStrings.menuBarWeather(L10n.shared.language)
        guard let reading else {
            button.image = NSImage(systemSymbolName: "cloud", accessibilityDescription: strings.pageTitle)
            button.title = lastRefreshFailed ? "--" : ""
            button.toolTip = lastRefreshFailed ? strings.unavailable : strings.pageTitle
            return
        }
        let title = MenuBarWeatherSupport.title(reading,
                                                fahrenheitFirst: Locale.current.measurementSystem == .us)
        button.image = NSImage(systemSymbolName: MenuBarWeatherSupport.symbol(reading),
                               accessibilityDescription: nil)
        button.image?.isTemplate = true
        button.title = " " + title
        button.toolTip = place.map { "\($0.place.name): \(title)" } ?? title
    }

    @objc private func clicked() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.weatherAppBundle) else {
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
