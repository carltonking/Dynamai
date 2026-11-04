// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The Siri settings: the switch, the page's shortcut, and whether Apple
/// Intelligence is ready for it. The page itself is `NotchSiriPage`, carrying
/// `NotchHermesChatService.siri`.
struct NotchSiriChatSettingsControls: View {
    @ObservedObject private var chat = NotchHermesChatService.siri
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchSiriChatEnabled) private var enabled = false
    private var words: NotchSiriChatStrings { FeatureStrings.notchSiriChat(l10n.language) }
    private var text: NotchHermesChatStrings { chat.strings(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(words.enable, isOn: $enabled)
                .disabled(!AppFeature.notchSiriChat.isAvailable)
            Text(words.description).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if enabled {
                status
            }
        }
        .onChange(of: enabled) { _, _ in chat.syncWithPreferences() }
    }

    @ViewBuilder private var status: some View {
        switch chat.state {
        case .off:
            EmptyView()
        case .connecting:
            Label(text.connecting, systemImage: "clock")
                .font(.caption).foregroundStyle(.secondary)
        case .ready:
            Label(text.ready, systemImage: "checkmark.circle")
                .font(.caption).foregroundStyle(.secondary)
        case .failed(let failure):
            VStack(alignment: .leading, spacing: 6) {
                Label(chat.describe(failure, language: l10n.language), systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Button(text.retry) { chat.retry() }
                    .controlSize(.small)
            }
        }
    }
}
