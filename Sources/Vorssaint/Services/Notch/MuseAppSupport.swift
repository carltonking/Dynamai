// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Meta's Muse, read from and written to the Muse for Mac app.
///
/// Meta offers no API for the consumer agent. The Muse app keeps the
/// conversation in a web view whose chat log Accessibility can read, but
/// draws its message field natively where no other app can fill it in. So
/// the island reads Muse's window as it changes, and sends the way a person
/// would: Muse comes forward for a moment, the words are pasted into its
/// field, and Return sends them (`NotchMuseAppClient`). Everything here is
/// the part that needs no running Muse: what its window says, and what that
/// means for the conversation, so it can be tested without signing in.
enum MuseAppSupport {
    static let bundleIdentifier = "com.meta.endo"
    /// How long Muse's last message must stay unchanged to count as whole:
    /// Muse writes it in place, and nothing else on the page says it is done.
    static let settleDelay: TimeInterval = 3
    /// How often the window is read while Muse is answering, and otherwise.
    static let activePoll: TimeInterval = 0.7
    static let idlePoll: TimeInterval = 4
    /// How many of the last messages are read on every change; the whole
    /// conversation is read once, when the page connects.
    static let tailLength = 12
    /// A turn that hears nothing back in this long ends rather than spinning.
    static let answerTimeout: TimeInterval = 180
    /// Why a message did not go, shown inside the page's localized line, as
    /// the other transports' own reasons are.
    static let sendFailed = "Muse's message field could not be reached."

    /// Why the page cannot talk to Muse now. The client keeps watching, so
    /// the page recovers by itself once the reason is gone.
    enum Problem: String, Equatable, Codable {
        /// Muse for Mac is not on this Mac.
        case notInstalled
        /// This app may not read or press anything in another app's window.
        case needsAccessibility
        /// Muse is running without its window.
        case noWindow
        /// Muse's window has no conversation: signed out, or still starting.
        case noConversation
    }

    /// An element of Muse's window, as Accessibility describes it. Only what
    /// telling messages apart needs.
    struct Node: Equatable {
        var role: String
        var subrole = ""
        /// The web page's own class names, which WebKit passes along.
        var classes: [String] = []
        var title = ""
        var value = ""
        var children: [Node] = []
    }

    /// One message as Muse's window shows it.
    struct Row: Equatable {
        enum Author: Equatable { case person, muse }
        var author: Author
        var text: String
    }

    /// What a reading means for the page in the island.
    enum Change: Equatable {
        /// A message of the person's, sent from here or from another device.
        case delivered(Row)
        /// Muse is still writing its last message; these are its new words.
        case streaming(String)
        /// A whole message from Muse.
        case received(Row)
    }

    // MARK: Reading the window

    /// The class Muse puts on the message list (`role="log"`).
    static let logSubrole = "AXApplicationLog"
    /// The class of the bubble the person's messages are drawn in.
    static let bubbleClass = "hatch-chat-groupable-bubble"

    /// The messages in Muse's chat log, oldest first. A message scrolled out
    /// of view is drawn only as a screen-reader line ("Assistant message:
    /// …"); one on screen is a bubble (the person's, marked with a hidden
    /// "You:") or Muse's plain text. Date lines between them are left out.
    static func rows(in log: [Node]) -> [Row] {
        log.compactMap { node in
            if node.role == "AXStaticText" { return surrogate(node.value) }
            guard !node.classes.contains("text-center") else { return nil }
            let texts = staticTexts(node)
            guard let first = texts.first else { return nil }
            let person = contains(bubbleClass, in: node) && isLabel(first)
            let words = text(of: node, skippingLabel: person)
            return words.isEmpty ? nil : Row(author: person ? .person : .muse, text: words)
        }
    }

    /// A hidden label naming the speaker ("You:", "Vous :"), not words.
    static func isLabel(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.count <= 16 && (trimmed.hasSuffix(":") || trimmed.hasSuffix("："))
    }

    /// A message drawn only for screen readers: "User message: …" is the
    /// person's, anything else Muse's. The words after the label are the
    /// message's own.
    static func surrogate(_ line: String) -> Row? {
        guard let colon = line.range(of: ": "), line.distance(from: line.startIndex, to: colon.lowerBound) <= 40
        else { return nil }
        let label = line[..<colon.lowerBound].lowercased()
        let words = String(line[colon.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty, !label.contains("system") else { return nil }
        return Row(author: label.hasPrefix("user") ? .person : .muse, text: words)
    }

    /// The words of a message: its text in order, a paragraph per block,
    /// without its buttons or the speaker's label.
    static func text(of node: Node, skippingLabel: Bool) -> String {
        var paragraphs: [String] = []
        var line = ""
        var skipped = !skippingLabel
        func visit(_ node: Node) {
            switch node.role {
            case "AXButton", "AXPopUpButton", "AXMenuButton", "AXImage":
                return
            case "AXStaticText":
                if !skipped { skipped = true; return }
                line += node.value
            default:
                // A group is a block of its own (a paragraph, a list item)
                // and starts a line; inline code and links run on.
                let block = node.role == "AXGroup" && node.subrole != "AXCodeStyleGroup"
                if block, !line.isEmpty { paragraphs.append(line); line = "" }
                node.children.forEach(visit)
                if block, !line.isEmpty { paragraphs.append(line); line = "" }
            }
        }
        node.children.forEach(visit)
        if !line.isEmpty { paragraphs.append(line) }
        return paragraphs.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func staticTexts(_ node: Node) -> [String] {
        if node.role == "AXStaticText" { return [node.value] }
        if node.role == "AXButton" || node.role == "AXPopUpButton" { return [] }
        return node.children.flatMap(staticTexts)
    }

    private static func contains(_ cls: String, in node: Node) -> Bool {
        node.classes.contains(cls) || node.children.contains { contains(cls, in: $0) }
    }

    /// Muse's message field: the bubble holding "Message", the attach button
    /// and Send, drawn by the page under the native field it lines up with.
    static func isComposer(_ node: Node) -> Bool {
        guard node.role == "AXButton" else { return false }
        if node.classes.contains("bg-fill-blur-thick") && node.classes.contains("backdrop-blur-elevation-01") {
            return true
        }
        return node.title.hasPrefix("Message") && node.title.contains("Send")
    }

    // MARK: Following the conversation

    /// What a message is known by: who wrote it and its words, as the window
    /// draws them. Muse gives the window no identities to go by.
    static func key(_ row: Row) -> String {
        (row.author == .person ? "p:" : "m:") + normalized(row.text)
    }

    /// Follows the conversation from one reading to the next. The first
    /// reading is the thread as it was; only what comes after it is news.
    struct Tracker: Equatable {
        /// The messages already reported, newest last.
        private(set) var settled: [String] = []
        /// Muse's last message, still being written, and when it last changed.
        private(set) var writing = ""
        private(set) var changedAt: Date?
        private(set) var started = false

        mutating func begin(_ rows: [Row]) -> [Row] {
            started = true
            settled = Array(rows.map(MuseAppSupport.key).suffix(200))
            writing = ""
            changedAt = nil
            return rows
        }

        /// The changes since the last reading. `rows` is the end of the
        /// conversation (at least the messages since the last reading).
        mutating func changes(_ rows: [Row], now: Date) -> [Change] {
            let keys = rows.map(MuseAppSupport.key)
            guard let anchor = anchor(in: keys) else {
                // Nothing known is in view (Muse switched to another chat, or
                // its window scrolled far up): start over from what is shown,
                // reporting nothing rather than repeating it.
                if !keys.isEmpty { _ = begin(rows) }
                return []
            }
            var changes: [Change] = []
            let fresh = Array(rows[(anchor + 1)...])
            for (index, row) in fresh.enumerated() {
                let last = index == fresh.count - 1
                if row.author == .muse && last {
                    // Muse writes in place: its last message is whole once it
                    // has stopped changing for a moment.
                    if row.text != writing {
                        if row.text.hasPrefix(writing), row.text.count > writing.count {
                            changes.append(.streaming(String(row.text.dropFirst(writing.count))))
                        }
                        writing = row.text
                        changedAt = now
                    }
                    if let changedAt, now.timeIntervalSince(changedAt) >= MuseAppSupport.settleDelay {
                        settle(row, into: &changes)
                    }
                    continue
                }
                settle(row, into: &changes)
            }
            return changes
        }

        /// Muse's last message is still settling: the client keeps reading.
        var isWriting: Bool { !writing.isEmpty }

        private mutating func settle(_ row: Row, into changes: inout [Change]) {
            settled.append(MuseAppSupport.key(row))
            if settled.count > 200 { settled.removeFirst(settled.count - 200) }
            if row.author == .muse {
                writing = ""
                changedAt = nil
                changes.append(.received(row))
            } else {
                changes.append(.delivered(row))
            }
        }

        /// Where the last reported message is in this reading: the latest
        /// place it appears whose message before it matches as well, so the
        /// same short reply twice ("ok") is not mistaken for the earlier one.
        private func anchor(in keys: [String]) -> Int? {
            guard let last = settled.last else { return keys.isEmpty ? nil : -1 }
            let before = settled.count >= 2 ? settled[settled.count - 2] : nil
            for index in keys.indices.reversed() where keys[index] == last {
                if index == 0 || before == nil || keys[index - 1] == before || !keys.contains(before!) {
                    return index
                }
            }
            return nil
        }
    }

    /// The thread as the island's messages. Each message keeps an identity
    /// made from its words and its place among equal ones, and the time the
    /// island first saw it, so reading the thread again never reorders or
    /// duplicates it.
    static func thread(_ rows: [Row], known: [UUID: Date], now: Date) -> [NotchHermesChatMessage] {
        var seen: [String: Int] = [:]
        return rows.enumerated().map { index, row in
            let key = key(row)
            let count = seen[key, default: 0]
            seen[key] = count + 1
            let id = identity(key, occurrence: count)
            // Never seen before: spaced a second apart, ending now, so the
            // order holds and a note the island wrote later still reads after.
            let date = known[id] ?? now.addingTimeInterval(-Double(rows.count - index))
            return message(row, id: id, date: date)
        }
    }

    /// A message that arrived after the thread was read. `earlier` is how
    /// many equal messages the conversation already holds.
    static func message(_ row: Row, earlier: Int, date: Date) -> NotchHermesChatMessage {
        message(row, id: identity(key(row), occurrence: earlier), date: date)
    }

    static func identity(_ key: String, occurrence: Int) -> UUID {
        InstinctMessagesSupport.stableID("muse:\(occurrence):" + key)
    }

    private static func message(_ row: Row, id: UUID, date: Date) -> NotchHermesChatMessage {
        NotchHermesChatMessage(id: id, role: row.author == .person ? .person : .hermes, text: row.text, date: date)
    }

    /// The window draws what was typed (markdown, spacing) differently from
    /// how it was typed; a message is known by its words alone.
    static func normalized(_ words: String) -> String {
        words.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .lowercased()
    }

    /// The words the island sent that a delivered message echoes, if any.
    static func echo(of delivered: String, among sent: [String]) -> String? {
        let words = normalized(delivered)
        return sent.first { normalized($0) == words }
    }
}
