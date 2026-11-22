// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

enum KeepAwakeIslandBadgeTests {
    static func run(_ suite: TestSuite) {
        suite.run("keep awake island badge") {
            // A 14-inch MacBook Pro: camera housing between x 662 and 850,
            // menu bar band 32 points tall.
            let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
            func badge(besidePadlock: Bool) -> KeepAwakeIslandBadgeLayout {
                KeepAwakeIslandBadgeLayout(screenFrame: screen, cameraLeftMaxX: 662, cameraRightMinX: 850,
                                           topInset: 32, besidePadlock: besidePadlock)
            }
            let padlock = CleaningLockBadgeLayout(screenFrame: screen, cameraLeftMaxX: 662,
                                                  cameraRightMinX: 850, topInset: 32)
            let alone = badge(besidePadlock: false)
            suite.expect(alone == KeepAwakeIslandBadgeLayout(screenFrame: screen, cameraLeftMaxX: 662,
                                                              cameraRightMinX: 850, topInset: 32)
                            && alone.center == padlock.center && alone.size == padlock.size,
                         "on its own the bolt sits just right of the camera, where the padlock would")
            let shifted = badge(besidePadlock: true)
            suite.expect(shifted.center.y == padlock.center.y
                            && shifted.center.x - shifted.size.width / 2
                                == padlock.center.x + padlock.size.width / 2 + CleaningLockBadgeLayout.gap,
                         "with Cleaning Mode's padlock showing, the bolt moves right of it, a gap apart")

            let frame = alone.panelFrame(in: screen)
            suite.expect(frame.minX > 850 && frame.maxY == screen.maxY - (32 - alone.size.height) / 2
                            && frame.size == alone.size,
                         "its window covers only the glyph, in the menu bar band")

            // A second display to the right, without a notch.
            let external = CGRect(x: 1512, y: 0, width: 1920, height: 1080)
            let plain = KeepAwakeIslandBadgeLayout(screenFrame: external, cameraLeftMaxX: nil,
                                                   cameraRightMinX: nil, topInset: 0)
            suite.expect(plain.center.x > external.width / 2 + CleaningLockBadgeLayout.fallbackIslandWidth / 2
                            && plain.panelFrame(in: external).minX > external.minX + external.width / 2,
                         "without a notch it sits right of where the island draws, on that screen")

            suite.expect(MenuBarSpacingSupport.keepAwakeSignals(active: true, tint: .orange, style: .vorssaint)
                            && !MenuBarSpacingSupport.keepAwakeSignals(active: true, tint: .orange, style: .vorssaint,
                                                                       islandBadge: true),
                         "with the badge on, Keep Awake no longer brings back a menu bar icon the user hid")
            suite.expect((Defaults.registeredDefaults[DefaultsKey.keepAwakeIslandBadge] as? Bool) == false,
                         "the badge is off until switched on")
            for language in AppLanguage.allCases {
                let values = Mirror(reflecting: FeatureStrings.keepAwakeIslandBadge(language)).children
                    .compactMap { $0.value as? String }
                suite.expect(values.count == 3 && values.allSatisfy { !$0.isEmpty && !$0.contains("—") },
                             "the Keep Awake badge has every localized field for \(language.rawValue)")
            }
        }
    }
}
