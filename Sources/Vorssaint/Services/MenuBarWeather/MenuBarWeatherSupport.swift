// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The decisions behind the menu bar weather, kept free of AppKit and the
/// network so they can be tested directly.
///
/// macOS's own Weather item shows one unit. This one shows both, converted
/// from a single unrounded Celsius reading so the two always agree: rounding
/// first and converting after can put Fahrenheit a degree off.
///
/// The data is Open-Meteo's, reached through the same requests Siri's weather
/// tool uses: no key, no account, only a city name and its coordinates.
enum MenuBarWeatherSupport {
    /// Open-Meteo refreshes its current conditions about every quarter hour.
    static let refreshInterval: TimeInterval = 15 * 60

    struct Reading: Equatable {
        let celsius: Double
        let code: Int
        let isDay: Bool
    }

    static func reading(fromForecast data: Data) -> Reading? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = json["current"] as? [String: Any],
              let celsius = (current["temperature_2m"] as? NSNumber)?.doubleValue,
              let code = (current["weather_code"] as? NSNumber)?.intValue else { return nil }
        let isDay = (current["is_day"] as? NSNumber)?.intValue ?? 1
        return Reading(celsius: celsius, code: code, isDay: isDay == 1)
    }

    static func celsius(_ reading: Reading) -> Int {
        Int(reading.celsius.rounded())
    }

    static func fahrenheit(_ reading: Reading) -> Int {
        Int((reading.celsius * 9 / 5 + 32).rounded())
    }

    /// "53°F · 12°C", the Mac's own unit first.
    static func title(_ reading: Reading, fahrenheitFirst: Bool) -> String {
        let f = "\(fahrenheit(reading))°F"
        let c = "\(celsius(reading))°C"
        return fahrenheitFirst ? "\(f) · \(c)" : "\(c) · \(f)"
    }

    static func symbol(_ reading: Reading) -> String {
        SiriAssistantSupport.condition(code: reading.code, isDay: reading.isDay).symbol
    }

    /// The typed city, or the one the time zone is named for when the field
    /// is empty, so the feature works without asking for Location.
    static func city(typed: String, timeZone: TimeZone) -> String {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? SiriAssistantSupport.homeCity(timeZone: timeZone) : trimmed
    }
}
