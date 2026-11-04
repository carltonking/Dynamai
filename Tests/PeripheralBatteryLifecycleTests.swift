// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum PeripheralBatteryLifecycleTests {
    private final class Reader: PeripheralBluetoothReading {
        let cancellation: BoundedProcessCancellation
        let completion: ([BluetoothBatteryReading]) -> Void
        var starts = 0
        var cancels = 0
        init(cancellation: BoundedProcessCancellation, completion: @escaping ([BluetoothBatteryReading]) -> Void) {
            self.cancellation = cancellation
            self.completion = completion
        }
        func start() { starts += 1 }
        func cancel() { cancels += 1 }
        // Deliberately misbehave after cancellation to exercise the real sampler's guard.
        func emit(_ percent: Int) {
            completion([BluetoothBatteryReading(id: "fixture", name: "Keyboard", percent: percent)])
        }
    }

    static func run(_ suite: TestSuite) {
        freshness(suite)
        cachedSources(suite)
        refreshHandoff(suite)
        cancellation(suite)
        cancelledProfiler(suite)
        cancelledFastRead(suite)
        processCancellation(suite)
        powerSourceParsing(suite)
        powerSourcePrecedence(suite)
        powerSourceNotifications(suite)
    }

    // Shaped like IOPSCopyPowerSourcesByType on macOS 27.2 with AirPods Pro
    // connected: one group, a case and two buds reported separately.
    private static func airPods(left: Int, right: Int, case casePercent: Int,
                                rightCharging: Bool = false) -> [[String: Any]] {
        let group = "3310B90C-8EAE-7C9B-B4BA-FCD5554E8DB5"
        func part(_ id: String, _ name: String, _ partName: String?, _ percent: Int,
                  _ category: String, charging: Bool = false) -> [String: Any] {
            var description: [String: Any] = [
                "Type": "Accessory Source", "Transport Type": "Bluetooth", "Is Present": true,
                "Name": name, "Current Capacity": percent, "Max Capacity": 100,
                "Is Charging": charging, "Accessory Category": category,
                "Group Identifier": group, "Accessory Identifier": group, "Part Identifier": id,
            ]
            if let partName { description["Part Name"] = partName }
            return description
        }
        return [
            ["Type": "InternalBattery", "Name": "InternalBattery-0", "Current Capacity": 62,
             "Max Capacity": 100, "Is Present": true, "Transport Type": "Internal"],
            part("Case", "Carlton’s AirPods Pro Case", nil, casePercent, "Audio Battery Case"),
            part("Left", "Carlton’s AirPods Pro", "Carlton’s AirPods Pro 🅛", left, "Headset"),
            part("Right", "Carlton’s AirPods Pro", "Carlton’s AirPods Pro 🅡", right, "Headset",
                 charging: rightCharging),
        ]
    }

    private static func powerSourceParsing(_ suite: TestSuite) {
        let paired = PeripheralBatterySupport.powerSourceBatteries(
            from: airPods(left: 100, right: 96, case: 79, rightCharging: true))
        let buds = paired.devices.first { $0.name == "Carlton’s AirPods Pro" }
        let chargingCase = paired.devices.first { $0.name == "Carlton’s AirPods Pro Case" }
        suite.expect(paired.devices.count == 2 && buds?.percent == 96 && buds?.isCharging == true
                     && buds?.kind == .audio,
                     "close buds fold into one row at the lower charge, charging if either is")
        suite.expect(chargingCase?.percent == 79 && chargingCase?.kind == .audio,
                     "the case keeps its own row, as Apple's Batteries widget shows it")
        suite.expect(!paired.devices.contains { $0.name.hasPrefix("InternalBattery") },
                     "the Mac's own battery stays with PowerSampler")

        let apart = PeripheralBatterySupport.powerSourceBatteries(from: airPods(left: 90, right: 20, case: 50))
        suite.expect(apart.devices.count == 3
                     && apart.devices.contains { $0.name == "Carlton’s AirPods Pro 🅡" && $0.percent == 20 }
                     && apart.devices.contains { $0.name == "Carlton’s AirPods Pro 🅛" && $0.percent == 90 },
                     "buds far apart keep one row each, so a flat bud is not hidden")

        let scaled = PeripheralBatterySupport.powerSourceBatteries(from: [[
            "Type": "Accessory Source", "Name": "Magic Mouse", "Current Capacity": 1, "Max Capacity": 4,
            "Accessory Category": "Mouse",
        ]])
        suite.expect(scaled.devices.first?.percent == 25 && scaled.devices.first?.kind == .mouse,
                     "a capacity out of a non-100 maximum reads as a percentage")
        suite.expect(PeripheralBatterySupport.powerSourceBatteries(from: [[
            "Type": "Accessory Source", "Name": "Gone", "Current Capacity": 50, "Is Present": false,
        ]]).devices.isEmpty, "an accessory the registry marks absent is not shown")
        suite.expect(NotchAccessorySupport.symbol(for: .audio, name: "Carlton’s AirPods Pro Case")
                     == "airpodspro.chargingcase.wireless",
                     "the AirPods Pro case draws as a case, not as earbuds")
    }

    private static func powerSourcePrecedence(_ suite: TestSuite) {
        let queue = DispatchQueue(label: "com.vorssaint.tests.battery-power-sources")
        var powerSources = PeripheralBatterySupport.powerSourceBatteries(from: airPods(left: 100, right: 100, case: 79))
        let staleScan = PeripheralBatteryDevice(id: "HID:airpods", name: "Carlton’s AirPods Pro", percent: 40, kind: .audio)
        let keyboard = PeripheralBatteryDevice(id: "HID:keyboard", name: "Magic Keyboard", percent: 60, kind: .keyboard)
        let sampler = PeripheralBatterySampler(bluetoothQueue: queue, readFast: { [staleScan, keyboard] },
            readPowerSources: { powerSources }, observePowerSources: { _ in {} },
            readProfiler: { _ in Data() }, makeBluetoothRead: { _, cancellation, completion in
                Reader(cancellation: cancellation, completion: completion)
            }, currentTime: { 1 })
        defer { sampler.setEnabled(false); queue.sync {} }
        sampler.setEnabled(true)
        let shown = sampler.sample(now: 1).devices
        suite.expect(shown.count == 3 && shown.contains { $0.id == keyboard.id }
                     && !shown.contains { $0.id == staleScan.id }
                     && shown.contains { $0.name == "Carlton’s AirPods Pro" && $0.percent == 100 },
                     "a device the power-source registry lists is shown from there, once")

        powerSources = PowerSourceBatteries()
        let afterDisconnect = sampler.sample(now: 100).devices
        suite.expect(afterDisconnect.map(\.id) == [keyboard.id],
                     "a scan cannot keep AirPods on screen after the registry stops listing them")
    }

    private static func powerSourceNotifications(_ suite: TestSuite) {
        let queue = DispatchQueue(label: "com.vorssaint.tests.battery-notifications")
        var percent = 50
        var handler: (() -> Void)?
        var stops = 0
        var refreshes = 0
        let sampler = PeripheralBatterySampler(bluetoothQueue: queue, readFast: { [] },
            readPowerSources: {
                PeripheralBatterySupport.powerSourceBatteries(from: [[
                    "Type": "Accessory Source", "Name": "Magic Mouse", "Current Capacity": percent,
                    "Max Capacity": 100, "Accessory Category": "Mouse",
                ]])
            }, observePowerSources: { changed in handler = changed; return { stops += 1 } },
            readProfiler: { _ in Data() }, makeBluetoothRead: { _, cancellation, completion in
                Reader(cancellation: cancellation, completion: completion)
            }, currentTime: { 1 })
        sampler.onBluetoothRefresh = { refreshes += 1 }
        sampler.setEnabled(true)
        _ = sampler.sample(now: 1)
        percent = 40
        suite.expect(sampler.sample(now: 2).devices.first?.percent == 50,
                     "without a change notice the fast cache still holds")
        handler?(); handler?(); handler?()
        Thread.sleep(forTimeInterval: 0.5)
        queue.sync {}
        suite.expect(refreshes == 1, "a burst of power-source notices asks for one refresh")
        suite.expect(sampler.sample(now: 3).devices.first?.percent == 40,
                     "a power-source notice makes the next sample read the registry again")
        sampler.setEnabled(false)
        queue.sync {}
        suite.expect(stops == 1, "disabling stops listening for power-source notices")
    }

    private static func device(_ percent: Int, id: String = "HID:fixture") -> PeripheralBatteryDevice {
        PeripheralBatteryDevice(id: id, name: "Keyboard", percent: percent, kind: .keyboard)
    }

    private static func sample(_ percent: Int, at observedAt: TimeInterval, id: String = "HID:fixture") -> PeripheralBatterySample {
        PeripheralBatterySample(devices: [device(percent, id: id)], observedAt: [id: observedAt])
    }

    private static func freshness(_ suite: TestSuite) {
        var state = NotchAccessoryBatteryState()
        suite.expect(state.consume(sample(35, at: 1), observedAfter: 10).isEmpty,
               "a previously high snapshot cannot establish the new accessory baseline")
        suite.expect(state.consume(sample(35, at: 1), observedAfter: 10).isEmpty,
               "republishing a cache cannot turn it into a new reading")
        suite.expect(state.consume(sample(19, at: 11), observedAfter: 10).isEmpty,
               "cache 35 then first actual 19 starts a silent low episode")
        suite.expect(state.consume(sample(35, at: 1), observedAfter: 10).isEmpty
               && state.consume(sample(18, at: 12), observedAfter: 10).isEmpty,
               "an older high value cannot rearm an established low episode")
        suite.expect(state.consume(sample(25, at: 13), observedAfter: 10).isEmpty,
               "a fresh recovery rearms without warning")
        suite.expect(state.consume(sample(20, at: 14), observedAfter: 10).count == 1,
               "a later observed fall after the fresh baseline warns exactly once")
        suite.expect(state.consume(sample(20, at: 14), observedAfter: 10).isEmpty,
               "a repeated fresh snapshot does not replay its alert")
        suite.expect(state.consume(sample(35, at: 19), observedAfter: 20).isEmpty
               && state.consume(sample(15, at: 21, id: "Bluetooth:fixture"), observedAfter: 20).isEmpty,
               "suspension keeps the low episode while ignoring caches from before resumption")
        _ = state.consume(sample(30, at: 22), observedAfter: 20)
        suite.expect(state.consume(sample(20, at: 23), observedAfter: 20).count == 1,
               "a measured recharge after resumption allows the next real fall")
        var freshHigh = NotchAccessoryBatteryState()
        _ = freshHigh.consume(sample(35, at: 10), observedAfter: 10)
        suite.expect(freshHigh.consume(sample(19, at: 20), observedAfter: 19).count == 1,
               "sleep preserves a genuinely established high baseline too")
    }

    private static func cachedSources(_ suite: TestSuite) {
        let queue = DispatchQueue(label: "com.vorssaint.tests.battery-cache")
        var clock: TimeInterval = 1
        var fast: [PeripheralBatteryDevice] = []
        var readers: [Reader] = [] // Access only while the serial queue is drained or inside it.
        let sampler = PeripheralBatterySampler(bluetoothQueue: queue, readFast: { fast },
            readPowerSources: { PowerSourceBatteries() }, observePowerSources: { _ in {} },
            readProfiler: { _ in Data() }, makeBluetoothRead: { _, cancellation, completion in
                let reader = Reader(cancellation: cancellation, completion: completion)
                readers.append(reader)
                return reader
            }, currentTime: { clock })
        defer { sampler.setEnabled(false); queue.sync {} }
        sampler.setEnabled(true)
        _ = sampler.sample(now: clock)
        queue.sync { readers[0].emit(35) }
        let cached = sampler.sample(now: clock)
        suite.expect(cached.devices.first?.percent == 35
               && cached.observedAt["BluetoothGATT:fixture"] == 1,
               "the sampler attaches the Bluetooth observation time")
        clock = 20
        fast = [PeripheralBatteryDevice(id: "HID:mouse", name: "Mouse", percent: 60, kind: .mouse)]
        let mixed = sampler.sample(now: clock)
        suite.expect(mixed.observedAt["HID:mouse"] == 20
               && mixed.observedAt["BluetoothGATT:fixture"] == 1,
               "a new HID read cannot refresh the age of cached Bluetooth data")
        var state = NotchAccessoryBatteryState()
        _ = state.consume(mixed, observedAfter: 10)
        clock = 302
        _ = sampler.sample(now: clock)
        queue.sync { readers[1].emit(19) }
        let actual = sampler.sample(now: clock)
        suite.expect(state.consume(actual, observedAfter: 10).isEmpty,
               "the production sampler's old Bluetooth 35 then actual 19 is silent on first observation")
        suite.expect(actual.observedAt["BluetoothGATT:fixture"] == 302,
               "the completed refresh supplies its own observation time")
        clock = 303
        suite.expect(sampler.sample(now: clock).observedAt == actual.observedAt,
               "the fast cache preserves source timestamps exactly")
    }

    /// A finished Bluetooth refresh tells the monitor to read at once, and
    /// devices left from a pause longer than the refresh interval are dropped.
    private static func refreshHandoff(_ suite: TestSuite) {
        let queue = DispatchQueue(label: "com.vorssaint.tests.battery-handoff")
        var clock: TimeInterval = 1
        var readers: [Reader] = [] // Access only while the serial queue is drained or inside it.
        var refreshes = 0
        let sampler = PeripheralBatterySampler(bluetoothQueue: queue, readFast: { [] },
            readPowerSources: { PowerSourceBatteries() }, observePowerSources: { _ in {} },
            readProfiler: { _ in Data() }, makeBluetoothRead: { _, cancellation, completion in
                let reader = Reader(cancellation: cancellation, completion: completion)
                readers.append(reader)
                return reader
            }, currentTime: { clock })
        sampler.onBluetoothRefresh = { refreshes += 1 }
        defer { sampler.setEnabled(false); queue.sync {} }
        sampler.setEnabled(true)
        _ = sampler.sample(now: clock)
        queue.sync {}
        suite.expect(refreshes == 0, "starting a Bluetooth refresh does not ask for a read before it lands")
        queue.sync { readers[0].emit(35) }
        suite.expect(refreshes == 1, "a finished Bluetooth refresh asks for one read")
        suite.expect(sampler.sample(now: clock).devices.first?.percent == 35,
               "the read it asks for sees the new Bluetooth devices")
        sampler.setEnabled(false)
        clock = 100
        sampler.setEnabled(true)
        suite.expect(sampler.sample(now: clock).devices.first?.percent == 35 && readers.count == 1,
               "a short pause keeps Bluetooth devices within their refresh interval")
        sampler.setEnabled(false)
        clock = 400
        sampler.setEnabled(true)
        suite.expect(sampler.sample(now: clock).devices.isEmpty,
               "a Bluetooth cache older than its refresh interval is not shown after a pause")
        queue.sync { readers[1].emit(19) }
        suite.expect(refreshes == 2 && sampler.sample(now: clock).devices.first?.percent == 19,
               "the refresh started after the pause brings the devices back")
        clock = 800
        _ = sampler.sample(now: clock)
        queue.sync {}
        sampler.setEnabled(false)
        queue.sync { readers[2].emit(50) }
        suite.expect(refreshes == 2, "a Bluetooth refresh cancelled by a disable does not ask for a read")
    }

    private static func cancellation(_ suite: TestSuite) {
        let queue = DispatchQueue(label: "com.vorssaint.tests.battery-cancel")
        var readers: [Reader] = []
        let sampler = PeripheralBatterySampler(bluetoothQueue: queue, readFast: { [] },
            readPowerSources: { PowerSourceBatteries() }, observePowerSources: { _ in {} },
            readProfiler: { _ in Data() }, makeBluetoothRead: { _, cancellation, completion in
                let reader = Reader(cancellation: cancellation, completion: completion)
                readers.append(reader)
                return reader
            }, currentTime: { 1 })
        sampler.setEnabled(true)
        _ = sampler.sample(now: 0)
        queue.sync {}
        suite.expect(readers.count == 1 && readers[0].starts == 1, "one active consumer starts one Bluetooth reader")
        sampler.setEnabled(true)
        _ = sampler.sample(now: 1)
        queue.sync {}
        suite.expect(readers[0].cancels == 0 && !readers[0].cancellation.isCancelled && readers.count == 1,
               "remaining shared demand preserves the existing reader without starting a second one")
        sampler.setEnabled(false)
        queue.sync {}
        suite.expect(readers[0].cancels == 1 && readers[0].cancellation.isCancelled,
               "losing the last consumer cancels the owned reader and its request")
        queue.sync { readers[0].emit(10) }
        suite.expect(sampler.sample(now: 2).devices.isEmpty, "a late callback cannot publish while observation is off")
        sampler.setEnabled(true)
        _ = sampler.sample(now: 3)
        queue.sync { readers[0].emit(99) }
        suite.expect(readers.count == 2 && sampler.sample(now: 3).devices.isEmpty,
               "a cancelled generation cannot contaminate a newly enabled reader")
        sampler.setEnabled(false)
        sampler.setEnabled(true)
        _ = sampler.sample(now: 4)
        queue.sync { readers[1].emit(99); readers[2].emit(19) }
        suite.expect(readers.count == 3 && readers[1].cancels == 1
               && readers[2].starts == 1 && readers[2].cancels == 0,
               "rapidly disabling and reenabling cannot apply old cleanup to the new reader")
        suite.expect(sampler.sample(now: 4).devices.first?.percent == 19,
               "only the replacement generation can supply the final battery value")
        sampler.setEnabled(false)
        queue.sync {}
    }

    private static func cancelledProfiler(_ suite: TestSuite) {
        let queue = DispatchQueue(label: "com.vorssaint.tests.battery-profiler")
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        var readers = 0
        var capturedRequest: BoundedProcessCancellation?
        let sampler = PeripheralBatterySampler(bluetoothQueue: queue, readFast: { [] },
            readPowerSources: { PowerSourceBatteries() }, observePowerSources: { _ in {} },
            readProfiler: { request in
                capturedRequest = request
                entered.signal()
                _ = release.wait(timeout: .now() + 3)
                return Data()
            }, makeBluetoothRead: { _, cancellation, completion in
                readers += 1
                return Reader(cancellation: cancellation, completion: completion)
            })
        sampler.setEnabled(true)
        _ = sampler.sample(now: 0)
        let didEnter = entered.wait(timeout: .now() + 2) == .success
        sampler.setEnabled(false)
        release.signal()
        queue.sync {}
        suite.expect(didEnter && capturedRequest?.isCancelled == true,
               "disabling during the profiler phase cancels that pending request")
        suite.expect(readers == 0, "a profiler result arriving after disable cannot create Bluetooth connections")
    }

    private static func cancelledFastRead(_ suite: TestSuite) {
        let queue = DispatchQueue(label: "com.vorssaint.tests.battery-fast-read")
        var sampler: PeripheralBatterySampler!
        sampler = PeripheralBatterySampler(bluetoothQueue: queue, readFast: {
            sampler.setEnabled(false)
            return [device(19)]
        }, readPowerSources: { PowerSourceBatteries() }, observePowerSources: { _ in {} },
        readProfiler: { _ in Data() }, makeBluetoothRead: { _, cancellation, completion in
            Reader(cancellation: cancellation, completion: completion)
        })
        sampler.setEnabled(true)
        suite.expect(sampler.sample(now: 0).devices.isEmpty, "a fast read finishing after disable cannot repopulate the cache")
        queue.sync {}
        sampler = nil
    }

    private static func processCancellation(_ suite: TestSuite) {
        let cancelled = BoundedProcessCancellation()
        cancelled.cancel()
        let skipped = BoundedProcessRunner.run("/usr/bin/printf", ["unexpected"], timeout: 1,
                                               maxOutputBytes: 32, cancellation: cancelled)
        suite.expect(skipped.status == -1 && skipped.output.isEmpty, "a cancelled queued process is never launched")
        let running = BoundedProcessCancellation()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { running.cancel() }
        let stopped = BoundedProcessRunner.run("/bin/sleep", ["30"], timeout: 5,
                                               maxOutputBytes: 0, cancellation: running)
        suite.expect(running.isCancelled && !stopped.timedOut && stopped.status != 0,
               "cancellation terminates an active process without waiting for its normal timeout")
    }
}
