// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

enum MenuBarHiderTests {
    private typealias Support = MenuBarHiderSupport

    private static let arrow = CGRect(x: 1300, y: 0, width: 20, height: 24)

    private static func app(_ bundle: String?, x: CGFloat) -> Support.Item {
        Support.Item(bundleIdentifier: bundle, frame: CGRect(x: x, y: 0, width: 24, height: 24))
    }

    private static func system(_ identifier: String, x: CGFloat) -> Support.Item {
        Support.Item(bundleIdentifier: "com.apple.MenuBarAgent",
                     frame: CGRect(x: x, y: 0, width: 24, height: 24),
                     systemIdentifier: identifier)
    }

    static func run(_ suite: TestSuite) {
        suite.run("menu bar hider") {
            layout(suite)
            allowList(suite)
            learning(suite)
            catalog(suite)
        }
    }

    private static func layout(_ suite: TestSuite) {
        let items = [app("com.left", x: 1100), app("com.right", x: 1400),
                     app("com.split", x: 1100), app("com.split", x: 1400),
                     app("com.vorssaint.dynamai", x: 1100), app(nil, x: 1100),
                     system("com.apple.menuextra.bluetooth", x: 1200),
                     system("com.apple.menuextra.wifi", x: 1500)]
        let ltr = Support.layout(of: items, arrowFrame: arrow, isLeftToRight: true,
                                 ownBundle: "com.vorssaint.dynamai")
        suite.expect(ltr.hiddenBundles == ["com.left"],
                     "only apps left of the arrow hide, never Dynamai itself or an unnamed process")
        suite.expect(ltr.visibleBundles == ["com.right", "com.split"],
                     "an app with an icon on each side stays visible")
        suite.expect(ltr.hiddenSystemItems == ["com.apple.menuextra.bluetooth"],
                     "macOS's own items left of the arrow are hidden one by one")

        let rtl = Support.layout(of: [app("com.left", x: 1100), app("com.right", x: 1400)],
                                 arrowFrame: arrow, isLeftToRight: false, ownBundle: nil)
        suite.expect(rtl.hiddenBundles == ["com.right"] && rtl.visibleBundles == ["com.left"],
                     "a right-to-left bar hides the right side")
    }

    private static func allowList(_ suite: TestSuite) {
        let layout = Support.Layout(hiddenBundles: ["com.hidden"], visibleBundles: ["com.visible"],
                                    hiddenSystemItems: ["com.apple.menuextra.bluetooth",
                                                        "com.apple.menuextra.unlearned"])
        let allowed = Support.allowedBundles(ownBundle: "com.own", layout: layout,
                                             runningBundles: ["com.hidden", "com.unread", "com.own", "com.visible"])
        suite.expect(allowed == ["com.own", "com.visible", "com.unread"],
                     "every running app stays allowed except the hidden side, so an unread app never vanishes")

        let systemItems = Support.allowedSystemItems(hiding: layout.hiddenSystemItems,
                                                     numbers: ["com.apple.menuextra.bluetooth": 1,
                                                               "com.apple.menuextra.wifi": 6])
        suite.expect(!systemItems.contains(1) && systemItems.contains(6)
                        && systemItems.count == Support.allSystemItemNumbers.count - 1,
                     "only learned hidden system items are taken out; unlearned ones stay visible")
    }

    private static func learning(_ suite: TestSuite) {
        let rounds = Support.learningRounds
        suite.expect(rounds.count == Support.systemItemNumberBits + 2
                        && rounds.first == Support.allSystemItemNumbers && rounds.last == [],
                     "learning runs unrestricted, once per bit, then with every system item hidden")

        // Battery 0, Bluetooth 1, Clock 2, Wi-Fi 6, as measured on macOS 27.2.
        // Now Playing vanishes under any restriction; a stuck item never does.
        let truth = ["battery": 0, "bluetooth": 1, "clock": 2, "wifi": 6]
        let seen = rounds.map { allowed -> Set<String> in
            Set(truth.filter { allowed.contains($0.value) }.keys).union(["stuck"])
        }
        let decoded = Support.decode(seen: seen, wanted: ["bluetooth", "nowplaying"])
        suite.expect(decoded.numbers == truth,
                     "each item's number is the bits of the rounds it disappeared in")
        suite.expect(decoded.uncontrollable == ["nowplaying", "stuck"],
                     "items the restriction cannot move are remembered rather than relearned")
        suite.expect(Support.decode(seen: Array(seen.dropLast()), wanted: ["bluetooth"]).numbers.isEmpty,
                     "an interrupted pass learns nothing")

        suite.expect(Support.needsLearning(["bluetooth", "wifi", "nowplaying"], numbers: ["wifi": 6],
                                           uncontrollable: ["nowplaying"]) == ["bluetooth"],
                     "only unknown, controllable items trigger a learning pass")
        suite.expect(Support.storedNumbers(["wifi": 6], storedBuild: "26B131", currentBuild: "26B131") == ["wifi": 6]
                        && Support.storedNumbers(["wifi": 6], storedBuild: "26A100", currentBuild: "26B131").isEmpty,
                     "a macOS update discards numbers it may have changed")
    }

    private static func catalog(_ suite: TestSuite) {
        let feature = AppFeature.menuBarHider
        suite.expect(feature.group == .tools
                        && feature.enabledKeys == [DefaultsKey.menuBarHiderEnabled]
                        && feature.permissions == [.accessibility]
                        && feature.onboardingPermissions.isEmpty
                        && !feature.installedByDefault,
                     "the menu bar hider is an opt-in tool that asks for Accessibility when switched on")
        suite.expect(feature.settingsDestination
                        == FeatureSettingsDestination(.general, sectionAnchor: .panelConfiguration),
                     "its switch lives in the Menu bar card")
        suite.expect((Defaults.registeredDefaults[DefaultsKey.menuBarHiderEnabled] as? Bool) == false,
                     "hiding menu bar icons is off until switched on")
        let exported = SettingsBackupSupport.exportKeys()
        suite.expect(exported.contains(DefaultsKey.menuBarHiderEnabled)
                        && !exported.contains(DefaultsKey.menuBarHiderSystemItemNumbers)
                        && !exported.contains(DefaultsKey.menuBarHiderUncontrollableItems)
                        && !exported.contains(DefaultsKey.menuBarHiderSystemItemBuild),
                     "the switch travels with a backup; numbers learned on this Mac do not")

        for language in AppLanguage.allCases {
            let strings = FeatureStrings.menuBarHider(language)
            let values = Mirror(reflecting: strings).children.compactMap { $0.value as? String }
            suite.expect(values.count == 8 && values.allSatisfy { !$0.isEmpty },
                         "the menu bar hider has every localized field for \(language.rawValue)")
            suite.expect(values.allSatisfy { !$0.contains("—") },
                         "menu bar hider text uses human punctuation for \(language.rawValue)")
        }
    }
}
