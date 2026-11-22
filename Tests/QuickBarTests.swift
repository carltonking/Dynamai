// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

enum QuickBarTests {
    static func run(_ suite: TestSuite) {
        suite.run("quick bar") {
            sizing(suite)
            placement(suite)
            catalog(suite)
        }
    }

    private static func sizing(_ suite: TestSuite) {
        suite.expect((Defaults.registeredDefaults[DefaultsKey.quickBarTextSize] as? Double)
                        == QuickBarSupport.defaultTextSize,
                     "the bar ships at its default text size")
        suite.expect(QuickBarSupport.sanitizedTextSize(40.4) == 40
                        && QuickBarSupport.sanitizedTextSize(2) == QuickBarSupport.textSizeRange.lowerBound
                        && QuickBarSupport.sanitizedTextSize(500) == QuickBarSupport.textSizeRange.upperBound
                        && QuickBarSupport.sanitizedTextSize(.nan) == QuickBarSupport.defaultTextSize,
                     "a stored size is kept whole and inside the slider's range")
        let source = (try? String(contentsOfFile: "Sources/Vorssaint/UI/QuickBar/QuickBarView.swift",
                                  encoding: .utf8)) ?? ""
        suite.expect(source.contains("DefaultsKey.quickBarTextSize") && !source.contains("text.count"),
                     "the text size follows the setting alone, never the length of the message")
    }

    private static func placement(_ suite: TestSuite) {
        let screen = CGRect(x: 1512, y: 0, width: 2560, height: 1415)
        let frame = QuickBarSupport.panelFrame(in: screen)
        suite.expect(frame.size == QuickBarSupport.panelSize && abs(frame.midX - screen.midX) <= 1,
                     "the bar opens at full size, centered on the display it was summoned on")
        suite.expect(frame.midY > screen.midY && screen.contains(frame),
                     "it sits a little above the middle, inside the screen")
        let small = CGRect(x: 0, y: 0, width: 500, height: 300)
        suite.expect(small.contains(QuickBarSupport.panelFrame(in: small)),
                     "a display smaller than the bar still holds all of it")
    }

    private static func catalog(_ suite: TestSuite) {
        let feature = AppFeature.quickBar
        suite.expect(feature.group == .tools && feature.permissions.isEmpty
                        && feature.enabledKeys.isEmpty && !feature.installedByDefault,
                     "the quick bar is an opt-in tool that needs no permission")
        suite.expect(GlobalShortcut.quickBarDefault.storageValue
                        == GlobalShortcut(keyCode: 49, modifiers: [.shift, .option]).storageValue,
                     "it ships on Shift-Option-Space, beside the Command Bar's Option-Space")
        suite.expect(GlobalShortcutRole.quickBar.requiredEnableKeys == [DefaultsKey.quickBarShortcutEnabled]
                        && (Defaults.registeredDefaults[DefaultsKey.quickBarShortcutEnabled] as? Bool) == true,
                     "its shortcut is on as soon as the tool is installed")
        for language in AppLanguage.allCases {
            let values = Mirror(reflecting: FeatureStrings.quickBar(language)).children
                .compactMap { $0.value as? String }
            suite.expect(values.count == 4 && values.allSatisfy { !$0.isEmpty && !$0.contains("—") },
                         "the quick bar has every localized field for \(language.rawValue)")
        }
    }
}
