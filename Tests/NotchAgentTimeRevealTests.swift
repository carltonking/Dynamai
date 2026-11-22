// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

enum NotchAgentTimeRevealTests {
    static func run(_ suite: TestSuite) {
        suite.run("agent conversation shows its times on a left swipe") {
            typealias Support = NotchAgentTimestampSupport
            let width = Support.revealWidth
            suite.expect(Support.revealOffset(fingers: 0) == 0 && Support.revealOffset(fingers: -30) == 0,
                         "a swipe the other way moves nothing")
            suite.expect(Support.revealOffset(fingers: 20) == 20 && Support.revealOffset(fingers: width) == width,
                         "the conversation follows the fingers until the times are out")
            let past = Support.revealOffset(fingers: width + 40)
            let farther = Support.revealOffset(fingers: width + 400)
            suite.expect(past > width && past < width + 40 && farther > past && farther < width + 24,
                         "past that it resists, like the end of a scroll, and never runs away")

            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(identifier: "UTC")!
            let evening = Date(timeIntervalSince1970: 1_794_517_800) // 21:10 UTC
            let english = Support.revealedTime(for: evening, locale: Locale(identifier: "en_US"), calendar: utc)
            let german = Support.revealedTime(for: evening, locale: Locale(identifier: "de_DE"), calendar: utc)
            suite.expect(english == "9:10\u{202F}PM" || english == "9:10 PM",
                         "beside a message only its time shows, in the language's own form: \(english ?? "nil")")
            suite.expect(german == "21:10", "a 24-hour language keeps its clock: \(german ?? "nil")")
            suite.expect(Support.revealedTime(for: Date(timeIntervalSince1970: 0), locale: .current) == nil,
                         "a message whose date never parsed shows no time")
        }
    }
}
