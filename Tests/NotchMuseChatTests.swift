// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Muse is read from the Muse for Mac app's window: `MuseAppSupport` tells
/// its messages apart and decides what is news. These pin that against
/// windows shaped like Muse's, without Muse running.
enum NotchMuseChatTests {
    typealias Support = MuseAppSupport
    typealias Node = MuseAppSupport.Node
    typealias Row = MuseAppSupport.Row

    static func text(_ value: String) -> Node { Node(role: "AXStaticText", value: value) }
    static func group(_ children: [Node], classes: [String] = [], subrole: String = "") -> Node {
        Node(role: "AXGroup", subrole: subrole, classes: classes, children: children)
    }
    static let controls = [Node(role: "AXPopUpButton", title: "React"), Node(role: "AXButton", title: "Reply")]

    /// The person's bubble, as Muse draws it: a hidden label, then the words.
    static func mine(_ words: String) -> Node {
        group([text("You:"), group([text(words)])] + controls, classes: [Support.bubbleClass, "min-h-[44px]"])
    }

    /// Muse's message: paragraphs of plain text, without a bubble.
    static func muses(_ paragraphs: [String]) -> Node {
        group([group(paragraphs.map { group([text($0)]) } + controls)], classes: ["flex", "flex-col"])
    }

    static func run(_ suite: TestSuite) {
        suite.run("Muse's window is read as the person's messages and Muse's") {
            let log = [
                text("Assistant message: Morning! Two classes today."),
                group([text("Nov 3 at 9:58 PM")], classes: ["py-4", "text-center"]),
                mine("Move my call to 5"),
                muses(["Done.", "Anything else?"]),
                text("User message: thanks"),
                text("System message: Muse joined"),
            ]
            let rows = Support.rows(in: log)
            suite.expect(rows == [Row(author: .muse, text: "Morning! Two classes today."),
                                  Row(author: .person, text: "Move my call to 5"),
                                  Row(author: .muse, text: "Done.\nAnything else?"),
                                  Row(author: .person, text: "thanks")],
                         "bubbles are the person's, plain text Muse's, and date and system lines are left out")
        }

        suite.run("Muse's words keep their lines, without buttons or the hidden label") {
            let code = Node(role: "AXGroup", subrole: "AXCodeStyleGroup", children: [text("claude")])
            let link = Node(role: "AXLink", title: "Docs", children: [text("Docs")])
            let message = group([group([text("Run "), code, text(" then read "), link]),
                                 group([text("Done")])] + controls)
            suite.expect(Support.text(of: message, skippingLabel: false) == "Run claude then read Docs\nDone",
                         "inline code and links run on, paragraphs break, buttons are not words")
            suite.expect(Support.text(of: mine("Hi there"), skippingLabel: true) == "Hi there",
                         "the person's hidden label is not part of what they wrote")
            suite.expect(Support.isLabel("You:") && Support.isLabel("Vous :") && !Support.isLabel("Here is the plan for today:"),
                         "a short line ending in a colon is a label, in any language; a sentence is not")
            let bold = group([group([text("Heads up:"), text(" the call moved")])], classes: ["flex", "flex-col"])
            suite.expect(Support.rows(in: [bold]) == [Row(author: .muse, text: "Heads up: the call moved")],
                         "Muse starting with a bold phrase is still Muse, not the person")
        }

        suite.run("Muse's message field is found by the bubble the page draws for it") {
            let field = Node(role: "AXButton", classes: ["backdrop-blur-elevation-01", "bg-fill-blur-thick", "shadow-blur-elevation-01"],
                             title: "Message Attach file\nSend")
            let reply = Node(role: "AXButton", classes: ["inline-flex"], title: "Reply")
            suite.expect(Support.isComposer(field) && !Support.isComposer(reply),
                         "the field is told apart from the buttons on messages")
            suite.expect(Support.isComposer(Node(role: "AXButton", title: "Message Attach file\nSend")),
                         "its words find it if the page renames its classes")
        }

        let hello = Row(author: .person, text: "What's on today?")
        let answer = Row(author: .muse, text: "Two classes and a call at 4.")
        let start = Date(timeIntervalSince1970: 1_800_000_000)

        suite.run("the conversation on first sight is the thread, and only what follows is news") {
            var tracker = Support.Tracker()
            suite.expect(tracker.begin([hello, answer]) == [hello, answer], "the thread is what the window shows")
            suite.expect(tracker.changes([hello, answer], now: start).isEmpty, "reading it again is not news")
            let next = Row(author: .person, text: "Move the call to 5")
            suite.expect(tracker.changes([hello, answer, next], now: start) == [.delivered(next)],
                         "a message of the person's is delivered as soon as the window shows it")
        }

        suite.run("Muse's reply streams in and lands whole once it stops changing") {
            var tracker = Support.Tracker()
            _ = tracker.begin([hello])
            let partial = Row(author: .muse, text: "Two classes")
            suite.expect(tracker.changes([hello, partial], now: start) == [.streaming("Two classes")],
                         "the first words stream")
            suite.expect(tracker.changes([hello, answer], now: start.addingTimeInterval(1))
                            == [.streaming(" and a call at 4.")],
                         "then only the new words")
            suite.expect(tracker.changes([hello, answer], now: start.addingTimeInterval(2)).isEmpty,
                         "a reply that just changed is not whole yet")
            suite.expect(tracker.changes([hello, answer], now: start.addingTimeInterval(1 + Support.settleDelay))
                            == [.received(answer)],
                         "it is received once it has held still")
            suite.expect(tracker.changes([hello, answer], now: start.addingTimeInterval(20)).isEmpty, "and only once")
        }

        suite.run("Muse writing two messages receives the first as soon as the second starts") {
            var tracker = Support.Tracker()
            _ = tracker.begin([hello])
            let second = Row(author: .muse, text: "Want me to move it?")
            suite.expect(tracker.changes([hello, answer, second], now: start)
                            == [.received(answer), .streaming("Want me to move it?")],
                         "a message Muse has moved past is whole")
        }

        suite.run("an equal message later is news, and a lost place starts over quietly") {
            var tracker = Support.Tracker()
            let ok = Row(author: .person, text: "ok")
            _ = tracker.begin([ok, answer])
            suite.expect(tracker.changes([ok, answer, ok], now: start) == [.delivered(ok)],
                         "the same words again are a new message")
            suite.expect(tracker.changes([Row(author: .muse, text: "Another chat")], now: start).isEmpty,
                         "a window showing nothing known (another chat) is not reported as new")
            let after = Row(author: .person, text: "back")
            suite.expect(tracker.changes([Row(author: .muse, text: "Another chat"), after], now: start) == [.delivered(after)],
                         "and the conversation goes on from there")
        }

        suite.run("the thread keeps its identities and the island's times") {
            let earlier = Date(timeIntervalSince1970: 1_700_000_000)
            let ok = Row(author: .person, text: "ok")
            let first = Support.thread([ok, answer, ok], known: [:], now: start)
            suite.expect(first.map(\.role) == [.person, .hermes, .person] && Set(first.map(\.id)).count == 3,
                         "each message keeps its side and an identity of its own, equal words included")
            suite.expect(first[0].date < first[1].date && first[2].date <= start, "messages seen together keep their order")
            let again = Support.thread([ok, answer, ok], known: [first[0].id: earlier], now: start)
            suite.expect(again.map(\.id) == first.map(\.id) && again[0].date == earlier,
                         "reading it again keeps each identity and when it was first seen")
            suite.expect(Support.message(ok, earlier: 2, date: start).id != first[2].id
                         && Support.message(ok, earlier: 1, date: start).id == first[2].id,
                         "a message arriving later is told apart by how many equal ones came before")
        }

        suite.run("a message sent from here is known when Muse shows it back") {
            let sent = ["Move the **call** to 5", "Thanks!"]
            suite.expect(Support.echo(of: "Move the call  to 5", among: sent) == "Move the **call** to 5",
                         "markdown and spacing the window draws differently still match")
            suite.expect(Support.echo(of: "Something else", among: sent) == nil,
                         "a message typed on the phone is not taken for one sent here")
        }

        suite.run("Muse is an island page of its own, off until asked for") {
            suite.expect(AppFeature.notchMuseChat.group == .dynamicIsland
                         && !AppFeature.notchMuseChat.installedByDefault
                         && AppFeature.notchMuseChat.permissions == [.accessibility]
                         && Defaults.registeredDefaults[DefaultsKey.notchMuseChatEnabled] as? Bool == false,
                         "Muse is an uninstalled island extension that needs Accessibility, switched off")
            suite.expect(NotchModule.museChat.isAgentChat
                         && NotchModule.museChat.symbol == AppFeature.notchMuseChat.symbolName
                         && NotchAgentReplySupport.noticeName("muse") == "MUSE",
                         "Muse has an agent page of its own, drawn with its feature's mark, and its notices name it")
            let all: [Support.Problem] = [.notInstalled, .needsAccessibility, .noWindow, .noConversation]
            suite.expect(AppLanguage.allCases.allSatisfy { language in
                let words = FeatureStrings.notchMuseChat(language)
                return words.title == "MUSE" && words.unreachableFormat.contains("%1$@")
                    && Set(all.map(words.problem)).count == all.count && !all.map(words.problem).contains("")
            }, "every language names MUSE and says what is missing, a line per reason")
        }
    }
}
