// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The Muse settings: the switch, whether the Muse app can be read, and the
/// way to fix it when it cannot. The page itself is the shared chat page,
/// carrying `NotchHermesChatService.muse`.
struct NotchMuseChatSettingsControls: View {
    @ObservedObject private var chat = NotchHermesChatService.muse
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchMuseChatEnabled) private var enabled = false
    private var words: NotchMuseChatStrings { FeatureStrings.notchMuseChat(l10n.language) }
    private var text: NotchHermesChatStrings { chat.strings(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(words.enable, isOn: $enabled)
                .disabled(!AppFeature.notchMuseChat.isAvailable)
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
            HStack(spacing: 8) {
                Label(text.ready, systemImage: "checkmark.circle")
                    .font(.caption).foregroundStyle(.secondary)
                Button(words.openMuse) { chat.openMuseApp() }
                    .controlSize(.small)
            }
        case .failed(let failure):
            VStack(alignment: .leading, spacing: 6) {
                Label(chat.describe(failure, language: l10n.language), systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Group {
                    if failure == .muse(.needsAccessibility) {
                        Button(words.allowAccessibility) { Permissions.shared.requestAccessibility() }
                    } else if case .muse(let problem) = failure {
                        if problem != .notInstalled { Button(words.openMuse) { chat.openMuseApp() } }
                    } else {
                        Button(text.retry) { chat.retry() }
                    }
                }
                .controlSize(.small)
            }
        }
    }
}
