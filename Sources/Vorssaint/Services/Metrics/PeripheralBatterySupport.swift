// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum PeripheralBatteryKind: String, Comparable {
    case keyboard, mouse, trackpad, audio, device

    var menuLabel: String {
        switch self {
        case .keyboard: return "KBD"
        case .mouse: return "MOU"
        case .trackpad: return "TRK"
        case .audio: return "AUD"
        case .device: return "PER"
        }
    }

    static func < (lhs: PeripheralBatteryKind, rhs: PeripheralBatteryKind) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct PeripheralBatteryDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let percent: Int
    let kind: PeripheralBatteryKind
    /// Only power sources report charging; HID and Bluetooth reads do not.
    var isCharging = false
}

/// Accessories as IOKit's power-source registry lists them: the list Apple's
/// own Batteries widget is drawn from. `names` holds every name a listed
/// accessory goes by, so the same device read from HID or Bluetooth is
/// recognized as already shown.
struct PowerSourceBatteries: Equatable {
    var devices: [PeripheralBatteryDevice] = []
    var names: Set<String> = []
}

struct BluetoothBatteryReading: Equatable {
    let id: String
    let name: String
    let percent: Int
}

enum PeripheralBatterySupport {
    static let percentKeys = [
        "BatteryPercent",
        "BatteryPercentRemaining",
        "BatteryLevel",
        "Battery Level",
        "Battery",
    ]

    static func percent(from value: Any?) -> Int? {
        let raw: Double?
        switch value {
        case let number as NSNumber:
            raw = number.doubleValue
        case let int as Int:
            raw = Double(int)
        case let double as Double:
            raw = double
        case let float as Float:
            raw = Double(float)
        case let string as String:
            let cleaned = string
                .replacingOccurrences(of: "%", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            raw = Double(cleaned)
        default:
            raw = nil
        }
        guard let raw, raw.isFinite else { return nil }
        // Failable, not clamping: a value past Int.max is a device lying, not a
        // 0...100 reading, so it returns nil like every other unusable input.
        guard let rounded = Int(exactly: raw.rounded()) else { return nil }
        guard (0...100).contains(rounded) else { return nil }
        return rounded
    }

    static func percent(in properties: [String: Any]) -> Int? {
        for key in percentKeys {
            if let percent = percent(from: properties[key]) {
                return percent
            }
        }
        return nil
    }

    static func bool(from value: Any?) -> Bool {
        switch value {
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return ["1", "true", "yes", "y"].contains(normalized)
        default:
            return false
        }
    }

    static func int(from value: Any?) -> Int? {
        switch value {
        case let number as NSNumber:
            return number.intValue
        case let int as Int:
            return int
        case let string as String:
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    static func string(from value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func name(in properties: [String: Any]) -> String? {
        for key in ["Product", "ProductName", "DeviceName", "IOProviderClass"] {
            if let name = string(from: properties[key]) {
                return name
            }
        }
        return nil
    }

    static func isBuiltIn(_ properties: [String: Any]) -> Bool {
        for key in ["Built-In", "BuiltIn", "Builtin", "built-in"] {
            if bool(from: properties[key]) {
                return true
            }
        }
        return false
    }

    static func usagePairs(from value: Any?) -> [[String: Any]] {
        guard let pairs = value as? [Any] else { return [] }
        return pairs.compactMap { pair in
            if let dict = pair as? [String: Any] {
                return dict
            }
            if let dict = pair as? NSDictionary {
                return dict as? [String: Any]
            }
            return nil
        }
    }

    static func kind(product: String,
                     minorType: String? = nil,
                     primaryUsagePage: Int?,
                     primaryUsage: Int?,
                     usagePairs: [[String: Any]]) -> PeripheralBatteryKind {
        let normalized = [product, minorType]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        if normalized.contains("keyboard") { return .keyboard }
        if normalized.contains("mouse") { return .mouse }
        if normalized.contains("trackpad") || normalized.contains("track pad") { return .trackpad }
        if normalized.contains("airpods")
            || normalized.contains("headphone")
            || normalized.contains("headset")
            || normalized.contains("buds") {
            return .audio
        }

        var usages: [(page: Int, usage: Int)] = []
        if let primaryUsagePage, let primaryUsage {
            usages.append((primaryUsagePage, primaryUsage))
        }
        for pair in usagePairs {
            let page = int(from: pair["DeviceUsagePage"])
                ?? int(from: pair["PrimaryUsagePage"])
                ?? int(from: pair["UsagePage"])
            let usage = int(from: pair["DeviceUsage"])
                ?? int(from: pair["PrimaryUsage"])
                ?? int(from: pair["Usage"])
            if let page, let usage {
                usages.append((page, usage))
            }
        }

        if usages.contains(where: { $0.page == 1 && $0.usage == 2 }) {
            return .mouse
        }
        if usages.contains(where: { ($0.page == 1 && $0.usage == 6) || $0.page == 7 }) {
            return .keyboard
        }
        if usages.contains(where: { $0.page == 13 && $0.usage == 5 }) {
            return .trackpad
        }
        return .device
    }

    static func shouldInclude(name: String?, isBuiltIn: Bool, percent: Int?) -> Bool {
        guard let name, !name.isEmpty, percent != nil else { return false }
        return !isBuiltIn
    }

    static func bluetoothDevices(fromSystemProfilerJSON data: Data) -> [PeripheralBatteryDevice] {
        var devices: [PeripheralBatteryDevice] = []
        for (name, properties) in connectedBluetoothEntries(from: data) {
            guard let percent = bluetoothPercent(in: properties) else { continue }
            let minorType = string(from: properties["device_minorType"])
            let kind = kind(product: name,
                            minorType: minorType,
                            primaryUsagePage: nil,
                            primaryUsage: nil,
                            usagePairs: [])
            let id = string(from: properties["device_address"])
                .map { "Bluetooth:\($0)" }
                ?? "BluetoothName:\(name.lowercased())"
            devices.append(PeripheralBatteryDevice(id: id,
                                                   name: name,
                                                   percent: percent,
                                                   kind: kind))
        }
        return sorted(devices)
    }

    static func bluetoothKindsByName(fromSystemProfilerJSON data: Data) -> [String: PeripheralBatteryKind] {
        var result: [String: PeripheralBatteryKind] = [:]
        for (name, properties) in connectedBluetoothEntries(from: data) {
            let minorType = string(from: properties["device_minorType"])
            result[normalizedBluetoothName(name)] = kind(product: name,
                                                         minorType: minorType,
                                                         primaryUsagePage: nil,
                                                         primaryUsage: nil,
                                                         usagePairs: [])
        }
        return result
    }

    static func mergingBluetoothReadings(_ readings: [BluetoothBatteryReading],
                                         into devices: [PeripheralBatteryDevice],
                                         knownKinds: [String: PeripheralBatteryKind]) -> [PeripheralBatteryDevice] {
        var result = devices
        var seenIDs = Set(devices.map(\.id))
        var seenNames = Set(devices.map { normalizedBluetoothName($0.name) })

        for reading in readings {
            let normalizedName = normalizedBluetoothName(reading.name)
            let id = "BluetoothGATT:\(reading.id)"
            guard !normalizedName.isEmpty,
                  (0...100).contains(reading.percent),
                  seenIDs.insert(id).inserted,
                  seenNames.insert(normalizedName).inserted else {
                continue
            }
            let kind = knownKinds[normalizedName]
                ?? kind(product: reading.name,
                        primaryUsagePage: nil,
                        primaryUsage: nil,
                        usagePairs: [])
            result.append(PeripheralBatteryDevice(id: id,
                                                  name: reading.name,
                                                  percent: reading.percent,
                                                  kind: kind))
        }
        return sorted(result)
    }

    /// Earbuds whose charges sit this close read as one row, at the lower
    /// charge, the way Apple's widget folds a pair; further apart, each bud
    /// keeps its own row so a flat one is not hidden behind a full one.
    static let earbudCoalescingTolerance = 10

    /// Accessory power sources from `IOPSCopyPowerSourcesByType`, as
    /// BatteryCenter (the framework behind Apple's Batteries widget) reads
    /// them. The Mac's own battery and UPSes are left to `PowerSampler`.
    static func powerSourceBatteries(from descriptions: [[String: Any]]) -> PowerSourceBatteries {
        struct Part {
            let id: String
            let name: String
            let partName: String?
            let partID: String?
            let percent: Int
            let charging: Bool
            let kind: PeripheralBatteryKind
        }
        var groups: [String: [Part]] = [:]
        var order: [String] = []
        var names = Set<String>()
        for description in descriptions {
            let type = string(from: description["Type"])
            guard type != "InternalBattery", type != "UPS",
                  description["Is Present"] == nil || bool(from: description["Is Present"]),
                  let name = string(from: description["Name"]),
                  let percent = powerSourcePercent(in: description) else { continue }
            let group = string(from: description["Group Identifier"])
                ?? string(from: description["Accessory Identifier"])
                ?? int(from: description["Power Source ID"]).map(String.init)
                ?? name.lowercased()
            let partID = string(from: description["Part Identifier"])
            let partName = string(from: description["Part Name"])
            let part = Part(id: "PowerSource:\(group):\(partID ?? "Main")",
                            name: name, partName: partName, partID: partID,
                            percent: percent, charging: bool(from: description["Is Charging"]),
                            kind: powerSourceKind(category: string(from: description["Accessory Category"]),
                                                  name: name))
            if groups[group] == nil { order.append(group) }
            groups[group, default: []].append(part)
            names.insert(normalizedBluetoothName(name))
            if let partName { names.insert(normalizedBluetoothName(partName)) }
        }

        var devices: [PeripheralBatteryDevice] = []
        for group in order {
            let parts = groups[group] ?? []
            let buds = parts.filter { $0.partID == "Left" || $0.partID == "Right" }
            if buds.count == 2,
               let low = buds.min(by: { $0.percent < $1.percent }),
               let high = buds.max(by: { $0.percent < $1.percent }),
               high.percent - low.percent <= earbudCoalescingTolerance {
                devices.append(PeripheralBatteryDevice(id: "PowerSource:\(group):Buds", name: low.name,
                                                       percent: low.percent, kind: low.kind,
                                                       isCharging: buds.contains(where: \.charging)))
                for part in parts where part.partID != "Left" && part.partID != "Right" {
                    devices.append(PeripheralBatteryDevice(id: part.id, name: part.name, percent: part.percent,
                                                           kind: part.kind, isCharging: part.charging))
                }
            } else {
                for part in parts {
                    let isBud = part.partID == "Left" || part.partID == "Right"
                    devices.append(PeripheralBatteryDevice(id: part.id,
                                                           name: isBud ? (part.partName ?? part.name) : part.name,
                                                           percent: part.percent, kind: part.kind,
                                                           isCharging: part.charging))
                }
            }
        }
        return PowerSourceBatteries(devices: devices, names: names)
    }

    /// Power sources win: a device the registry has ever listed is shown from
    /// there alone, so a HID read or a Bluetooth scan up to five minutes old
    /// cannot add a second, staler row for it, or keep it after it leaves.
    static func merging(powerSources: [PeripheralBatteryDevice],
                        others: [PeripheralBatteryDevice],
                        powerSourceNames: Set<String>) -> [PeripheralBatteryDevice] {
        let kept = others.filter { !powerSourceNames.contains(normalizedBluetoothName($0.name)) }
        return sorted(powerSources + kept)
    }

    static func powerSourceKind(category: String?, name: String) -> PeripheralBatteryKind {
        let category = category?.lowercased() ?? ""
        if category.contains("keyboard") { return .keyboard }
        if category.contains("mouse") { return .mouse }
        if category.contains("trackpad") { return .trackpad }
        if ["headset", "headphone", "audio", "speaker"].contains(where: category.contains) { return .audio }
        return kind(product: name, primaryUsagePage: nil, primaryUsage: nil, usagePairs: [])
    }

    private static func powerSourcePercent(in description: [String: Any]) -> Int? {
        guard let current = int(from: description["Current Capacity"]) else { return nil }
        let maximum = int(from: description["Max Capacity"]) ?? 100
        guard maximum > 0 else { return nil }
        return percent(from: Double(current) * 100 / Double(maximum))
    }

    private static func connectedBluetoothEntries(from data: Data) -> [(String, [String: Any])] {
        guard !data.isEmpty,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let controllers = root["SPBluetoothDataType"] as? [Any] else {
            return []
        }

        var entries: [(String, [String: Any])] = []
        for controllerValue in controllers {
            guard let controller = dictionary(from: controllerValue),
                  let connected = controller["device_connected"] as? [Any] else {
                continue
            }
            for entryValue in connected {
                guard let entry = dictionary(from: entryValue) else { continue }
                for (name, propertiesValue) in entry {
                    guard let properties = dictionary(from: propertiesValue) else { continue }
                    entries.append((name, properties))
                }
            }
        }
        return entries
    }

    private static func normalizedBluetoothName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func bluetoothPercent(in properties: [String: Any]) -> Int? {
        for key in ["device_batteryLevelMain", "device_batteryLevel"] {
            if let percent = percent(from: properties[key]) {
                return percent
            }
        }

        let partKeys = [
            "device_batteryLevelLeft",
            "device_batteryLevelRight",
            "device_batteryLevelCase",
        ]
        var values = partKeys.compactMap { percent(from: properties[$0]) }
        let knownKeys = Set(partKeys + ["device_batteryLevelMain", "device_batteryLevel"])
        values += properties
            .filter { key, _ in key.hasPrefix("device_batteryLevel") && !knownKeys.contains(key) }
            .compactMap { percent(from: $0.value) }
        return values.min()
    }

    private static func dictionary(from value: Any) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            return dictionary
        }
        if let dictionary = value as? NSDictionary {
            return dictionary as? [String: Any]
        }
        return nil
    }

    static func sorted(_ devices: [PeripheralBatteryDevice]) -> [PeripheralBatteryDevice] {
        devices.sorted {
            if $0.percent != $1.percent { return $0.percent < $1.percent }
            if $0.kind != $1.kind { return $0.kind < $1.kind }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    static func menuBarMetric(for devices: [PeripheralBatteryDevice]) -> (label: String, value: String)? {
        let devices = sorted(devices)
        guard let first = devices.first else { return nil }
        let extra = devices.count > 1 ? "+\(min(9, devices.count - 1))" : ""
        return (first.kind.menuLabel, "\(first.percent)%\(extra)")
    }
}

/// A cache keeps the time of its observation, including per-device sources:
/// refreshing HID does not make a cached Bluetooth percentage current.
struct PeripheralBatterySample: Equatable {
    var devices: [PeripheralBatteryDevice] = []
    var observedAt: [String: TimeInterval] = [:]
}

enum PeripheralBatteryRefreshPolicy {
    static func shouldStartBluetoothRefresh(now: TimeInterval,
                                            lastStartedAt: TimeInterval,
                                            lastFinishedAt: TimeInterval,
                                            isRunning: Bool,
                                            interval: TimeInterval) -> Bool {
        guard !isRunning else { return false }
        let lastAttempt = max(lastStartedAt, lastFinishedAt)
        return now - lastAttempt >= interval
    }
}
