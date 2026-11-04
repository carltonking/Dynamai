// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The hosted agents texted over iMessage beside Instinct, each working
/// exactly as Instinct does: the conversation is the person's Messages thread
/// with it, read aloud and previewed and announced the same way. Built in by
/// name; the number each is texted at is the person's own and lives only in
/// this Mac's preferences, never in the source.
enum NotchMessagesAgent: String, CaseIterable, Identifiable, Sendable {
    case sauna, rho, caddy, rene, iris, folk, maverick

    var id: String { rawValue }

    /// The agent's name, a name in every language.
    var name: String {
        switch self {
        case .sauna: return "Sauna"
        case .rho: return "Rho"
        case .caddy: return "Caddy"
        case .rene: return "Rene"
        case .iris: return "Iris"
        case .folk: return "Folk"
        case .maverick: return "Maverick"
        }
    }

    /// As notices and the page's mark show it, like VERTUS and INSTINCT.
    var displayName: String { name.uppercased() }

    var module: NotchModule {
        switch self {
        case .sauna: return .saunaChat
        case .rho: return .rhoChat
        case .caddy: return .caddyChat
        case .rene: return .reneChat
        case .iris: return .irisChat
        case .folk: return .folkChat
        case .maverick: return .maverickChat
        }
    }

    /// Option-Command and this letter open its page inside the island; the
    /// letters the other pages left.
    var shortcutKey: String {
        switch self {
        case .sauna: return "u"
        case .rho: return "q"
        case .caddy: return "k"
        case .rene: return "e"
        case .iris: return "j"
        case .folk: return "l"
        case .maverick: return "z"
        }
    }

    var historyFile: String { "\(rawValue)-chat.json" }

    /// Off-by-default preferences, in the same three parts Instinct has: its
    /// switch, its number (kept off settings backups) and reading aloud.
    var enabledKey: String { DefaultsKey.notchMessagesAgentEnabled(self) }
    var numberKey: String { DefaultsKey.notchMessagesAgentNumber(self) }
    var speakRepliesKey: String { DefaultsKey.notchMessagesAgentSpeakReplies(self) }

    static func agent(for module: NotchModule) -> NotchMessagesAgent? {
        allCases.first { $0.module == module }
    }

    static var registeredDefaults: [String: Any] {
        var defaults: [String: Any] = [:]
        for agent in allCases {
            defaults[agent.enabledKey] = true
            defaults[agent.numberKey] = ""
            defaults[agent.speakRepliesKey] = false
        }
        return defaults
    }

    /// The numbers are this Mac's, as Instinct's is.
    static var machineStateKeys: Set<String> { Set(allCases.map(\.numberKey)) }
}
