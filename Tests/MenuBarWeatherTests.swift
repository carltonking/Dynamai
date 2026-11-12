// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum MenuBarWeatherTests {
    private typealias Support = MenuBarWeatherSupport

    static func run(_ suite: TestSuite) {
        suite.run("menu bar weather") {
            let forecast = Data("""
            {"current": {"temperature_2m": 11.7, "weather_code": 2, "is_day": 0},
             "daily": {"temperature_2m_max": [14.0], "temperature_2m_min": [6.0]}}
            """.utf8)
            let reading = Support.reading(fromForecast: forecast)
            suite.expect(reading == Support.Reading(celsius: 11.7, code: 2, isDay: false),
                         "the current Celsius reading is kept unrounded")
            suite.expect(Support.reading(fromForecast: Data("{}".utf8)) == nil
                            && Support.reading(fromForecast: Data("not json".utf8)) == nil,
                         "an unreadable answer is no reading")

            // 11.7 °C is 53.06 °F. Rounding to 12 °C first would give 54 °F.
            let precise = Support.Reading(celsius: 11.7, code: 0, isDay: true)
            suite.expect(Support.celsius(precise) == 12 && Support.fahrenheit(precise) == 53,
                         "both units come from the unrounded reading, so they agree")
            suite.expect(Support.title(precise, fahrenheitFirst: true) == "53°F · 12°C"
                            && Support.title(precise, fahrenheitFirst: false) == "12°C · 53°F",
                         "the Mac's own unit comes first")
            let freezing = Support.Reading(celsius: -40, code: 71, isDay: true)
            suite.expect(Support.title(freezing, fahrenheitFirst: true) == "-40°F · -40°C",
                         "below zero reads the same in both")
            suite.expect(Support.symbol(Support.Reading(celsius: 0, code: 2, isDay: false)) == "cloud.moon.fill",
                         "the symbol follows the condition and the time of day")

            let newYork = TimeZone(identifier: "America/New_York")!
            suite.expect(Support.city(typed: "  ", timeZone: newYork) == "New York"
                            && Support.city(typed: " Lisbon ", timeZone: newYork) == "Lisbon",
                         "an empty city falls back to the time zone's, without asking for Location")

            let feature = AppFeature.menuBarWeather
            suite.expect(feature.group == .tools && feature.permissions.isEmpty
                            && !feature.installedByDefault && feature.energyProfile == .periodic,
                         "menu bar weather is opt-in, needs no permission and wakes only to refresh")
            suite.expect((Defaults.registeredDefaults[DefaultsKey.menuBarWeatherEnabled] as? Bool) == false
                            && (Defaults.registeredDefaults[DefaultsKey.menuBarWeatherCity] as? String) == "",
                         "nothing reaches the network until the weather is switched on")

            for language in AppLanguage.allCases {
                let values = Mirror(reflecting: FeatureStrings.menuBarWeather(language)).children
                    .compactMap { $0.value as? String }
                suite.expect(values.count == 7 && values.allSatisfy { !$0.isEmpty && !$0.contains("—") },
                             "menu bar weather has every localized field for \(language.rawValue)")
            }
        }
    }
}
