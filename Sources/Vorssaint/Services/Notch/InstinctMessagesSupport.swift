// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// One message as `imsg` prints it with `--json`: a JSON object per line.
struct InstinctMessageRecord: Equatable {
    /// The Messages database row, which only grows: a watch resumes after it.
    let rowID: Int64
    let guid: String
    let fromMe: Bool
    let sender: String
    let text: String
    let date: Date
    let chatIdentifier: String?
    let participants: [String]
    let isGroup: Bool
    /// The tapbacks on it, as Messages holds them now.
    var reactions: [NotchHermesChatMessage.Reaction] = []
    /// The message it answers inline (`thread_originator_guid`). Not
    /// `reply_to_guid`, which imsg sets on every message to the one before.
    var replyToGuid: String? = nil
    /// Files on the message, where Messages keeps them.
    var attachments: [NotchHermesChatMessage.Attachment] = []
    /// A poll the message carries (Apple's Polls app).
    var poll: NotchHermesChatMessage.Poll? = nil
    /// An iMessage app's message the island cannot draw.
    var interactive: NotchHermesChatMessage.Interactive? = nil
}

/// A vote cast on a poll, here or on the phone: Messages stores it as a row
/// of its own naming the poll, and imsg prints it as one.
struct InstinctPollVote: Equatable {
    let rowID: Int64
    let guid: String
    let pollGuid: String
    let optionID: String
    let participant: String
    let fromMe: Bool
    /// False when the choice was taken back.
    let selected: Bool
    let chatIdentifier: String?
    let participants: [String]
    let isGroup: Bool
    let sender: String
}

/// The tapbacks Messages can send without its private bridge: the six
/// classic ones, by the name `imsg react` takes.
enum MessagesTapback: String, CaseIterable, Identifiable {
    case love, like, dislike, laugh, emphasis, question
    var id: String { rawValue }
    var emoji: String {
        switch self {
        case .love: return "❤️"
        case .like: return "👍"
        case .dislike: return "👎"
        case .laugh: return "😂"
        case .emphasis: return "‼️"
        case .question: return "❓"
        }
    }
}

/// A tapback arriving on the watch: Messages stores it as a row of its own
/// pointing at the message it sits on, and `imsg watch --reactions` prints it
/// as one.
struct InstinctReactionEvent: Equatable {
    let rowID: Int64
    let guid: String
    /// The message the tapback sits on.
    let targetGuid: String
    /// Missing on some removals: a removal takes that side's tapback away
    /// whatever it was.
    let emoji: String?
    let fromMe: Bool
    let sender: String
    let chatIdentifier: String?
    let participants: [String]
    let isGroup: Bool
    /// False when the tapback was taken back.
    let added: Bool
}

/// One conversation as `imsg chats --json` prints it.
struct InstinctChatRecord: Equatable {
    let id: Int64
    let identifier: String
    /// The contact or group name Messages shows, when it has one.
    var name: String = ""
    let participants: [String]
    let isGroup: Bool
    /// Messages' own id for the chat, as AppleScript names it.
    var guid: String = ""
}

/// The pure half of the Instinct page: reading what `imsg` prints, telling
/// Instinct's thread from every other one whatever way its number was typed,
/// and finding the links a message carries. The client runs the commands;
/// nothing here touches a process, the disk or the island.
enum InstinctMessagesSupport {
    static let defaultCommand = "imsg"
    /// The thread shown on opening: enough to pick up where the phone left
    /// off, within the page's own transcript cap.
    static let historyLimit = 60
    /// How many recent conversations are searched for Instinct's. A thread
    /// older than this is found again by the first message sent to it.
    static let chatSearchLimit = 400
    /// Instinct often answers in a few messages. Those landing this soon
    /// after the one that answered a turn are still the answer, not Instinct
    /// reaching out on its own.
    static let replyWindow: TimeInterval = 120
    /// Instinct is a hosted agent and can take a while, but a turn that has
    /// heard nothing for this long stops showing it is waiting.
    static let replyTimeout: TimeInterval = 600

    // MARK: Which conversation

    /// What carries a chat page's conversation.
    enum Transport: Equatable {
        /// The iMessage thread with this number.
        case messages(number: String)
        /// The page is only an iMessage thread, and has no number yet.
        case missingNumber
        /// The agent on this Mac (VERTUS's hub, or `hermes acp`).
        case onThisMac
    }

    /// Instinct is only reachable by iMessage. VERTUS is texted at its
    /// Photon line once its number is given, and otherwise spoken to on this
    /// Mac exactly as before the number existed.
    static func transport(messagesOnly: Bool, number: String?) -> Transport {
        let number = (number ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !number.isEmpty { return .messages(number: number) }
        return messagesOnly ? .missingNumber : .onThisMac
    }

    /// The saved conversation for each way of carrying it. The iMessage
    /// thread replaces the transcript whenever it is read, so VERTUS's thread
    /// keeps a file of its own: the conversation on this Mac is still there
    /// when the number is cleared.
    static func historyFile(base: String, transport: Transport) -> String {
        guard case .messages = transport, base == "vertus-chat.json" else { return base }
        return "vertus-imessage-chat.json"
    }

    // MARK: Reading imsg

    static func record(fromLine line: String) -> InstinctMessageRecord? {
        guard let object = jsonObject(line),
              let rowID = int64(object["id"]),
              let guid = object["guid"] as? String, !guid.isEmpty
        else { return nil }
        // A tapback's row carries words ("Reacted 🚀 to …") but is not a
        // message; it is read as a reaction instead.
        guard object["is_reaction"] as? Bool != true else { return nil }
        // A vote is read as a vote, applied to the poll it names.
        let pollObject = object["poll"] as? [String: Any]
        guard pollVote(in: pollObject) == nil else { return nil }
        let poll = Self.poll(in: pollObject)
        let interactive = Self.interactive(object["balloon_bundle_id"] as? String)
        // "Sent a poll" stands in for the poll on devices that cannot draw
        // one; the poll itself is shown instead.
        let text = poll == nil ? cleaned(object["text"] as? String ?? "") : ""
        let files = attachments(object["attachments"])
        // An edit record has neither words nor files to show. A poll or an
        // iMessage app's message has no words of its own but is still a
        // message: dropping it hid Poke's choices and Sauna's polls.
        guard !text.isEmpty || !files.isEmpty || poll != nil || interactive != nil else { return nil }
        let originator = (object["thread_originator_guid"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return InstinctMessageRecord(
            rowID: rowID,
            guid: guid,
            fromMe: object["is_from_me"] as? Bool ?? false,
            sender: object["sender"] as? String ?? "",
            text: text,
            date: date(object["created_at"] as? String) ?? Date(timeIntervalSince1970: 0),
            chatIdentifier: object["chat_identifier"] as? String,
            participants: object["participants"] as? [String] ?? [],
            isGroup: object["is_group"] as? Bool ?? false,
            reactions: reactions(object["reactions"]),
            replyToGuid: originator,
            attachments: files,
            poll: poll,
            interactive: interactive)
    }

    /// A poll as `imsg` describes the message that created it.
    static func poll(in object: [String: Any]?) -> NotchHermesChatMessage.Poll? {
        guard let object, object["kind"] as? String == "created" || object["event"] as? String == "imessage.poll.created",
              let guid = object["poll_guid"] as? String, !guid.isEmpty,
              let list = object["options"] as? [[String: Any]] else { return nil }
        let options = list.compactMap { item -> NotchHermesChatMessage.Poll.Option? in
            guard let id = item["id"] as? String, let text = item["text"] as? String else { return nil }
            return NotchHermesChatMessage.Poll.Option(id: id, text: text)
        }
        return options.isEmpty ? nil : NotchHermesChatMessage.Poll(guid: guid, options: options)
    }

    /// The part of a vote's row that names the poll and the choice.
    private static func pollVote(in object: [String: Any]?)
        -> (pollGuid: String, optionID: String, participant: String, selected: Bool)? {
        guard let object, let pollGuid = object["poll_guid"] as? String, !pollGuid.isEmpty else { return nil }
        let event = object["event"] as? String ?? ""
        let kind = object["kind"] as? String ?? ""
        guard event.hasPrefix("imessage.poll.") && event != "imessage.poll.created" || ["vote", "voted", "unvoted"].contains(kind),
              let vote = object["vote"] as? [String: Any],
              let option = vote["option_id"] as? String, !option.isEmpty else { return nil }
        let type = (vote["event_type"] as? String ?? event).lowercased()
        let selected = !(type.contains("unselect") || type.contains("unvote") || type.contains("remov"))
        return (pollGuid, option, vote["participant"] as? String ?? "", selected)
    }

    static func pollVote(fromLine line: String) -> InstinctPollVote? {
        guard let object = jsonObject(line),
              let found = pollVote(in: object["poll"] as? [String: Any]) else { return nil }
        return InstinctPollVote(
            rowID: int64(object["id"]) ?? 0,
            guid: object["guid"] as? String ?? "",
            pollGuid: found.pollGuid, optionID: found.optionID, participant: found.participant,
            fromMe: object["is_from_me"] as? Bool ?? false, selected: found.selected,
            chatIdentifier: object["chat_identifier"] as? String,
            participants: object["participants"] as? [String] ?? [],
            isGroup: object["is_group"] as? Bool ?? false,
            sender: object["sender"] as? String ?? "")
    }

    /// The votes in `imsg history` output, oldest first so a choice taken
    /// back after it was made ends taken back.
    static func pollVotes(in output: String) -> [InstinctPollVote] {
        output.split(whereSeparator: \.isNewline).compactMap { pollVote(fromLine: String($0)) }
            .sorted { $0.rowID < $1.rowID }
    }

    /// The vote applied to the poll it names; a thread without that poll is
    /// left as it is.
    static func applying(_ vote: InstinctPollVote,
                         to messages: [NotchHermesChatMessage]) -> [NotchHermesChatMessage] {
        guard let index = messages.firstIndex(where: { $0.poll?.guid == vote.pollGuid }),
              var poll = messages[index].poll else { return messages }
        let voter = vote.fromMe ? "" : normalizedHandle(vote.participant.isEmpty ? vote.sender : vote.participant)
        poll.votes.removeAll { $0.optionID == vote.optionID && $0.fromMe == vote.fromMe
            && (vote.fromMe || normalizedHandle($0.participant) == voter) }
        if vote.selected {
            poll.votes.append(.init(optionID: vote.optionID, participant: vote.fromMe ? "" : voter, fromMe: vote.fromMe))
        }
        var updated = messages
        updated[index].poll = poll
        return updated
    }

    static func belongs(_ vote: InstinctPollVote, to number: String) -> Bool {
        guard !vote.isGroup else { return false }
        if let identifier = vote.chatIdentifier, sameHandle(identifier, number) { return true }
        return vote.participants.count == 1 && sameHandle(vote.participants[0], number)
    }

    /// Which iMessage app drew a message, when it is one the island shows
    /// only as a card. Links and polls are drawn; their apps are not listed.
    static func interactive(_ bundle: String?) -> NotchHermesChatMessage.Interactive? {
        guard let bundle, !bundle.isEmpty, bundle.contains("MSMessageExtensionBalloonPlugin") else { return nil }
        if bundle.hasSuffix(":com.apple.messages.Polls") { return nil }
        return bundle.contains("messages.business") ? .business : .app
    }

    /// The files `imsg --attachments` lists on a message, where they are on
    /// this Mac. Files Messages no longer has are left out.
    static func attachments(_ value: Any?) -> [NotchHermesChatMessage.Attachment] {
        guard let list = value as? [[String: Any]] else { return [] }
        return list.compactMap { item in
            // Stickers are images and are shown like any other; a link's
            // preview payload is Messages' own and is drawn as the link card.
            guard item["missing"] as? Bool != true,
                  let raw = (item["original_path"] ?? item["path"] ?? item["filename"]) as? String,
                  !raw.isEmpty,
                  (raw as NSString).pathExtension.lowercased() != "pluginpayloadattachment" else { return nil }
            let path = (raw as NSString).expandingTildeInPath
            let name = (item["transfer_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? (path as NSString).lastPathComponent
            return NotchHermesChatMessage.Attachment(path: path, name: name)
        }
    }

    static func reaction(fromLine line: String) -> InstinctReactionEvent? {
        guard let object = jsonObject(line), object["is_reaction"] as? Bool == true,
              let rowID = int64(object["id"]),
              let target = object["reacted_to_guid"] as? String, !target.isEmpty
        else { return nil }
        let type = object["reaction_type"] as? String
        return InstinctReactionEvent(
            rowID: rowID,
            guid: object["guid"] as? String ?? "",
            targetGuid: target,
            emoji: emoji(object["reaction_emoji"] as? String, type: type),
            fromMe: object["is_from_me"] as? Bool ?? false,
            sender: object["sender"] as? String ?? "",
            chatIdentifier: object["chat_identifier"] as? String,
            participants: object["participants"] as? [String] ?? [],
            isGroup: object["is_group"] as? Bool ?? false,
            added: object["is_reaction_add"] as? Bool ?? true)
    }

    /// The tapbacks a message carries in imsg's `reactions` list.
    static func reactions(_ value: Any?) -> [NotchHermesChatMessage.Reaction] {
        guard let list = value as? [[String: Any]] else { return [] }
        var kept: [NotchHermesChatMessage.Reaction] = []
        for item in list {
            guard let emoji = emoji(item["emoji"] as? String, type: item["type"] as? String) else { continue }
            let reaction = NotchHermesChatMessage.Reaction(emoji: emoji, fromMe: item["is_from_me"] as? Bool ?? false)
            // One per side, the later one winning, as Messages shows it.
            kept.removeAll { $0.fromMe == reaction.fromMe }
            kept.append(reaction)
        }
        return kept
    }

    /// The classic tapbacks are named rather than given as an emoji.
    static func emoji(_ given: String?, type: String?) -> String? {
        if let given = given?.trimmingCharacters(in: .whitespacesAndNewlines), !given.isEmpty { return given }
        switch type?.lowercased() {
        case "love": return "❤️"
        case "like": return "👍"
        case "dislike": return "👎"
        case "laugh": return "😂"
        case "emphasize", "emphasis": return "‼️"
        case "question": return "❓"
        default: return nil
        }
    }

    /// A tapback put on (or taken off) a message in the transcript. Each side
    /// holds one tapback per message, so a new one replaces that side's last.
    static func applying(_ event: InstinctReactionEvent,
                         to messages: [NotchHermesChatMessage]) -> [NotchHermesChatMessage] {
        let target = stableID(event.targetGuid)
        guard let index = messages.firstIndex(where: { $0.id == target }) else { return messages }
        var reactions = messages[index].reactions ?? []
        reactions.removeAll { $0.fromMe == event.fromMe }
        if event.added, let emoji = event.emoji {
            reactions.append(NotchHermesChatMessage.Reaction(emoji: emoji, fromMe: event.fromMe))
        }
        var updated = messages
        updated[index].reactions = reactions.isEmpty ? nil : reactions
        return updated
    }

    /// Whether a tapback belongs to the thread with Instinct.
    static func belongs(_ event: InstinctReactionEvent, to number: String) -> Bool {
        guard !event.isGroup else { return false }
        if let identifier = event.chatIdentifier, sameHandle(identifier, number) { return true }
        if event.participants.count == 1, sameHandle(event.participants[0], number) { return true }
        return !event.fromMe && sameHandle(event.sender, number)
    }

    /// Every message in a command's output, oldest first and each once,
    /// whatever order `imsg` printed them in (history is newest first) and
    /// whatever else (warnings, a log line) shared the output.
    static func records(in output: String) -> [InstinctMessageRecord] {
        var seen = Set<String>()
        return output.split(whereSeparator: \.isNewline)
            .compactMap { record(fromLine: String($0)) }
            .sorted { ($0.date, $0.rowID) < ($1.date, $1.rowID) }
            .filter { seen.insert($0.guid).inserted }
    }

    static func chat(fromLine line: String) -> InstinctChatRecord? {
        guard let object = jsonObject(line), let id = int64(object["id"]) else { return nil }
        return InstinctChatRecord(
            id: id,
            identifier: object["identifier"] as? String ?? "",
            name: (object["display_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? object["name"] as? String ?? "",
            participants: object["participants"] as? [String] ?? [],
            isGroup: object["is_group"] as? Bool ?? false,
            guid: object["guid"] as? String ?? "")
    }

    static func chats(in output: String) -> [InstinctChatRecord] {
        output.split(whereSeparator: \.isNewline).compactMap { chat(fromLine: String($0)) }
    }

    /// The people texted most recently, to pick an agent's number from:
    /// one-to-one threads only, each handle once, newest first as imsg
    /// lists them.
    static func recentContacts(in output: String, limit: Int = 8) -> [InstinctChatRecord] {
        var seen = Set<String>()
        return Array(chats(in: output).filter {
            !$0.isGroup && !$0.identifier.isEmpty && seen.insert(normalizedHandle($0.identifier)).inserted
        }.prefix(limit))
    }

    static func recentChatsArguments() -> [String] {
        ["chats", "--limit", "25", "--json"]
    }

    /// `imsg` explains a database it cannot open in words, not a status of
    /// its own: without Full Disk Access every read fails the same way.
    static func isUnreadable(_ output: String) -> Bool {
        let words = output.lowercased()
        return words.contains("full disk access") || words.contains("unable to open database")
            || words.contains("authorization denied") || words.contains("operation not permitted")
    }

    /// The last line `imsg` wrote, as the reason a command failed.
    /// imsg reports `may_have_completed` when Messages accepted the text but
    /// the outgoing row did not show up in its database within its window —
    /// in practice the message went out (Instinct answers it). It counts as
    /// sent; the thread's own echo confirms it.
    static func probablySent(_ output: String) -> Bool {
        output.contains("may_have_completed")
    }

    static func reason(_ output: String) -> String {
        output.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? "imsg exited."
    }

    // MARK: Matching Instinct's number

    /// A handle reduced to what identifies it: an address in lower case, a
    /// phone number as its digits. `tel:` and `mailto:` prefixes, spaces,
    /// dashes, dots and brackets do not change who it is.
    static func normalizedHandle(_ handle: String) -> String {
        var value = handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["tel:", "sms:", "imessage:", "mailto:"] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
        }
        // A business id is a name, not a number: read as its digits, two
        // businesses' ids could share their last ten and pass as each other.
        if value.contains("@") || isBusinessHandle(value) { return value }
        let digits = value.filter(\.isASCII).filter(\.isNumber)
        return digits.isEmpty ? value : digits
    }

    /// Whether two handles name the same person. A number typed without its
    /// country code (`(555) 123-4567`) still matches the one Messages keeps
    /// with it (`+15551234567`): national numbers are compared by their last
    /// ten digits, never by fewer, so short codes do not collide.
    static func sameHandle(_ first: String, _ second: String) -> Bool {
        let a = normalizedHandle(first), b = normalizedHandle(second)
        guard !a.isEmpty, !b.isEmpty else { return false }
        if a == b { return true }
        guard !a.contains("@"), !b.contains("@"), !isBusinessHandle(a), !isBusinessHandle(b),
              a.count >= 10, b.count >= 10 else { return false }
        return a.suffix(10) == b.suffix(10)
    }

    /// Instinct's one-to-one conversation, never a group it happens to be in.
    static func chat(for number: String, in chats: [InstinctChatRecord]) -> InstinctChatRecord? {
        chats.first { chat in
            !chat.isGroup && (sameHandle(chat.identifier, number)
                || (chat.participants.count == 1 && sameHandle(chat.participants[0], number)))
        }
    }

    /// Whether a message belongs to the thread with Instinct: its one-to-one
    /// conversation, from either side.
    static func belongs(_ record: InstinctMessageRecord, to number: String) -> Bool {
        guard !record.isGroup else { return false }
        if let identifier = record.chatIdentifier, sameHandle(identifier, number) { return true }
        if record.participants.count == 1, sameHandle(record.participants[0], number) { return true }
        return !record.fromMe && sameHandle(record.sender, number)
    }

    // MARK: Messages on the page

    /// The line the page shows. Its identity comes from the Messages guid, so
    /// the same message read again (history, then the watch, then the next
    /// launch) is one line, never two.
    static func message(_ record: InstinctMessageRecord, role: NotchHermesChatMessage.Role? = nil)
        -> NotchHermesChatMessage {
        NotchHermesChatMessage(id: stableID(record.guid),
                               role: role ?? (record.fromMe ? .person : .hermes),
                               text: record.text, date: record.date,
                               reactions: record.reactions.isEmpty ? nil : record.reactions,
                               replyTo: record.replyToGuid.map(stableID),
                               attachments: record.attachments.isEmpty ? nil : record.attachments,
                               poll: record.poll, interactive: record.interactive)
    }

    /// The thread as Messages has it, in place of whatever the page held: the
    /// phone may have added to it, and Messages is where it lives. Lines of
    /// the island's own that are newer than the thread (a failure, a stop)
    /// stay after it. A message the page already marked as Instinct writing
    /// unasked keeps that mark when the thread is read again.
    static func merged(thread: [NotchHermesChatMessage],
                       current: [NotchHermesChatMessage]) -> [NotchHermesChatMessage] {
        guard let last = thread.last?.date else { return current }
        let roles = Dictionary(current.map { ($0.id, $0.role) }, uniquingKeysWith: { first, _ in first })
        let known = Set(thread.map(\.id))
        let lines = thread.map { line -> NotchHermesChatMessage in
            guard line.role == .hermes, roles[line.id] == .proactive else { return line }
            return line.with(role: .proactive)
        }
        let after = current.filter { $0.role == .note && $0.date > last && !known.contains($0.id) }
        return HermesACPSupport.trimmed(lines + after)
    }

    /// Whether a message from Instinct is one nobody on the island asked for.
    /// - Parameters:
    ///   - waiting: a turn sent from here has not been answered yet.
    ///   - lastAnswer: when the last message that answered a turn arrived.
    static func isUnprompted(waiting: Bool, lastAnswer: Date?, at date: Date) -> Bool {
        if waiting { return false }
        guard let lastAnswer else { return true }
        return date.timeIntervalSince(lastAnswer) > replyWindow
    }

    /// The web links in a message, in the order they appear and each once.
    /// Only http and https: a `tel:` or `mailto:` is not a page to preview.
    static func links(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        var seen = Set<String>()
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let url = match.url, let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  seen.insert(url.absoluteString).inserted else { return nil }
            return url
        }
    }

    /// A message's words with the links that get a card taken out. Instinct
    /// sends a link on its own, and the page showed it twice: once as plain
    /// text that could not be clicked and once as the card that could. Only
    /// the card stays; words around a link keep their bubble.
    static func wordsBesideLinks(_ text: String) -> String {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return text }
        let ns = text as NSString
        var kept = ""
        var cursor = 0
        for match in detector.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard let scheme = match.url?.scheme?.lowercased(), scheme == "http" || scheme == "https" else { continue }
            kept += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            cursor = NSMaxRange(match.range)
        }
        guard cursor > 0 else { return text }
        kept += ns.substring(from: cursor)
        // The space a link left between two words is one space, and a line
        // it emptied goes with it.
        let lines = kept.components(separatedBy: "\n").map { line in
            line.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A message this much older than the moment it reached the island is
    /// catching up, not arriving: the Mac was asleep or off, and Messages is
    /// syncing what came in meanwhile. It joins the thread and marks the
    /// agent unread, but is not announced or read aloud, so waking the Mac
    /// does not set off one notice per message missed.
    static let catchUpAge: TimeInterval = 120

    static func isCatchingUp(sent: Date, now: Date) -> Bool {
        sent.timeIntervalSince1970 > 0 && now.timeIntervalSince(sent) > catchUpAge
    }

    // MARK: Commands

    static func chatsArguments() -> [String] {
        ["chats", "--limit", String(chatSearchLimit), "--json"]
    }

    static func historyArguments(chatID: Int64) -> [String] {
        ["history", "--chat-id", String(chatID), "--limit", String(historyLimit), "--json", "--attachments"]
    }

    /// The live stream: the known conversation when there is one, else the
    /// number, which also catches the thread the first message creates.
    static func watchArguments(chatID: Int64?, number: String, after rowID: Int64?) -> [String] {
        // Tapbacks arrive as rows of their own, printed only when asked for.
        var arguments = ["watch", "--json", "--reactions", "--attachments"]
        if let chatID { arguments += ["--chat-id", String(chatID)] }
        else { arguments += ["--participants", number.trimmingCharacters(in: .whitespacesAndNewlines)] }
        if let rowID { arguments += ["--since-rowid", String(rowID)] }
        return arguments
    }

    /// The words go as one argument, never through a shell, so nothing in
    /// them is read as a command.
    static func sendArguments(number: String, text: String, chatGuid: String? = nil) -> [String] {
        ["send"] + recipient(number, chatGuid: chatGuid) + ["--text", text]
    }

    /// A tapback on the newest message the agent sent in the conversation:
    /// the one `imsg react` can reach while System Integrity Protection is on.
    static func reactArguments(chatID: Int64, tapback: MessagesTapback) -> [String] {
        ["react", "--chat-id", String(chatID), "--reaction", tapback.rawValue]
    }

    /// Messages opened on the conversation, for what only Messages can do
    /// here: answering a business's list picker, voting, editing, unsending.
    /// A business is opened by its Messages for Business link.
    static func messagesURL(for handle: String) -> URL? {
        let handle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !handle.isEmpty else { return nil }
        if isBusinessHandle(handle) { return URL(string: "https://bcrw.apple.com/" + handle) }
        // A number as Messages files it, + and digits; an address as it is.
        let address = handle.contains("@") ? handle
            : (handle.hasPrefix("+") ? "+" : "") + handle.filter(\.isASCII).filter(\.isNumber)
        return URL(string: "imessage:" + (address.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? address))
    }

    /// The name on a contact card, as its `FN` line gives it.
    static func contactName(inVCard text: String) -> String? {
        for line in text.components(separatedBy: .newlines) {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].split(separator: ";").first.map { $0.uppercased() } ?? ""
            guard key == "FN" else { continue }
            let name = parts[1].trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { return name }
        }
        return nil
    }

    static func sendArguments(number: String, file: URL, chatGuid: String? = nil) -> [String] {
        ["send"] + recipient(number, chatGuid: chatGuid) + ["--file", file.path]
    }

    /// Apple Messages for Business threads, as Poke texts from, are known by
    /// a business id (`urn:biz:…`) and never by a number or an address.
    static func isBusinessHandle(_ handle: String) -> Bool {
        handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("urn:biz:")
    }

    /// `imsg send --to` takes only a number or an address; a business is
    /// reached through its existing conversation by Messages' own chat id.
    /// `--chat-identifier` made imsg ask Messages for `iMessage;-;urn:biz:…`,
    /// which Messages does not have (AppleScript error -1728): a business
    /// chat is `any;-;urn:biz:…`. The id imsg read for the chat is used when
    /// known, and that form otherwise.
    private static func recipient(_ number: String, chatGuid: String?) -> [String] {
        let handle = number.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isBusinessHandle(handle) else { return ["--to", handle] }
        let guid = chatGuid.flatMap { $0.isEmpty ? nil : $0 } ?? "any;-;" + handle
        return ["--chat-guid", guid]
    }

    // MARK: Helpers

    /// A guid is usually a UUID already; anything else is hashed into one
    /// that stays the same across launches.
    static func stableID(_ guid: String) -> UUID {
        if let uuid = UUID(uuidString: guid) { return uuid }
        // Two FNV-1a passes with different seeds fill the 16 bytes.
        func fnv(_ seed: UInt64) -> UInt64 {
            var hash = seed
            for byte in guid.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
            return hash
        }
        let high = fnv(0xcbf29ce484222325), low = fnv(0x84222325cbf29ce4)
        var bytes = [UInt8](repeating: 0, count: 16)
        for index in 0..<8 {
            bytes[index] = UInt8(truncatingIfNeeded: high >> (UInt64(index) * 8))
            bytes[index + 8] = UInt8(truncatingIfNeeded: low >> (UInt64(index) * 8))
        }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    /// Messages marks where an attachment sat with an object replacement
    /// character; the words around it are what the page shows.
    private static func cleaned(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{FFFC}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func jsonObject(_ line: String) -> [String: Any]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func int64(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber { return number.int64Value }
        if let text = value as? String { return Int64(text) }
        return nil
    }

    private static func date(_ text: String?) -> Date? {
        guard let text else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: text) { return date }
        return ISO8601DateFormatter().date(from: text)
    }
}
