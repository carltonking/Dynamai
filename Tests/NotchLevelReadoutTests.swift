// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum NotchLevelReadoutTests {
    static func run(_ suite: TestSuite) {
        suite.run("island level readouts") {
            suite.expect(NotchSupport.levelPercent(0.456) == "46%" && NotchSupport.levelPercent(0) == "0%"
                            && NotchSupport.levelPercent(1) == "100%",
                         "a level reads as a whole percentage")
            suite.expect(NotchSupport.levelPercent(1.3) == "100%" && NotchSupport.levelPercent(-0.2) == "0%",
                         "a level past either end reads as that end")
            suite.expect(NotchSupport.levelPercent(nil) == nil && NotchSupport.levelPercent(.nan) == nil,
                         "an unknown level shows no readout rather than a made-up number")
            suite.expect(!NotchSupport.readsLevelOverOpenIsland(.volume)
                            && !NotchSupport.readsLevelOverOpenIsland(.brightness)
                            && NotchSupport.readsLevelOverOpenIsland(.keyboardLight),
                         "volume and brightness raise no reading over the open island; the keyboard light still does")

            let defaults = UserDefaults(suiteName: "com.vorssaint.tests.notch-hide-when-closed")!
            defaults.removePersistentDomain(forName: "com.vorssaint.tests.notch-hide-when-closed")
            defer { defaults.removePersistentDomain(forName: "com.vorssaint.tests.notch-hide-when-closed") }
            suite.expect(!NotchSupport.hidesUntilHover(in: defaults), "the island shows at rest by default")
            defaults.set(true, forKey: DefaultsKey.notchHideUntilHover)
            suite.expect(!NotchSupport.hidesUntilHover(in: defaults),
                         "hidden until hover still needs hover to open it")
            defaults.set(false, forKey: DefaultsKey.notchHideUntilHover)
            defaults.set(true, forKey: DefaultsKey.notchHideWhenClosed)
            suite.expect(NotchSupport.hidesUntilHover(in: defaults) && NotchSupport.hiddenShowsActivity(in: defaults)
                            && !NotchSupport.hidesNoticesUntilHover(in: defaults),
                         "hidden while closed, with no hover: nothing at rest, every activity still comes out")
            for language in AppLanguage.allCases {
                let strings = FeatureStrings.notchHideWhenClosed(language)
                suite.expect(!strings.toggle.isEmpty && !strings.caption.isEmpty && !strings.caption.contains("—"),
                             "hiding the closed island is worded for \(language.rawValue)")
            }
        }
    }
}
