// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The Siri page, drawn by the island in Siri's own manner: no bubbles, the
/// answer as plain white words that stream in, what you asked set off to the
/// right, the cards its tools show under its answer, and Siri's glow along the
/// island's edge while it works. The island's own assistant on Apple's
/// language model answers (`NotchSiriAssistantClient`), not the Siri AI app.
struct NotchSiriPage: View {
    let size: CGSize
    @ObservedObject private var chat = NotchHermesChatService.siri
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchSiriChatEnabled) private var enabled = false
    @Environment(\.notchSettingsPreview) private var preview
    @FocusState private var typing: Bool

    private var text: NotchHermesChatStrings { chat.strings(l10n.language) }
    private var words: NotchSiriChatStrings { FeatureStrings.notchSiriChat(l10n.language) }
    private static let bottomID = "siri-bottom"

    var body: some View {
        VStack(spacing: 10) {
            if chat.messages.isEmpty && !chat.working {
                opening
            } else {
                transcript
            }
            composer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task {
            guard !preview else { return }
            try? await Task.sleep(for: .milliseconds(80))
            typing = true
            // Already focused from the last opening: no change to answer.
            NotchFieldCaret.placeAtEnd()
        }
        .onChange(of: typing) { _, focused in
            if focused { NotchFieldCaret.placeAtEnd() }
        }
        .notchBand(leading: {
            SiriWordmark(height: 11)
                .foregroundStyle(.white.opacity(0.9))
                .accessibilityLabel(text.title)
        })
    }

    // MARK: Conversation

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(chat.messages) { message in
                        line(message)
                    }
                    if chat.working {
                        // The answer as it streams in; until its first words,
                        // what Siri is doing.
                        if !chat.reply.isEmpty, chat.status == nil {
                            Self.styled(chat.reply)
                                .font(.system(size: 13.5))
                                .foregroundStyle(.white.opacity(0.94))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            NotchSiriStatusLine(words: chat.status ?? text.thinking)
                        }
                    }
                    Color.clear.frame(height: 1).id(Self.bottomID)
                }
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
            .onAppear { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
            .onChange(of: chat.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
            }
            .onChange(of: chat.working) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
            }
            .onChange(of: chat.reply) { _, _ in proxy.scrollTo(Self.bottomID, anchor: .bottom) }
        }
    }

    @ViewBuilder private func line(_ message: NotchHermesChatMessage) -> some View {
        switch message.role {
        case .person:
            HStack {
                Spacer(minLength: 60)
                Text(message.text)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .accessibilityLabel("\(text.you): \(message.text)")
        case .hermes, .proactive:
            answer(message)
        case .note, .tool:
            Text(message.text)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func answer(_ message: NotchHermesChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !message.text.isEmpty {
                Self.styled(message.text)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.white.opacity(0.94))
                    .tint(.white)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            ForEach(Array((message.cards ?? []).enumerated()), id: \.offset) { _, card in
                NotchSiriCard(card: card) { button in
                    if let action = card.action { chat.pressCardButton(action, button: button) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            Button(text.copyMessage) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.text, forType: .string)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(text.title): \(message.text)")
    }

    /// Siri's words with their bold, italics, code and links drawn.
    private static func styled(_ words: String) -> Text {
        guard let styled = try? AttributedString(
            markdown: HermesACPSupport.bubbleMarkdown(words),
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace,
                           failurePolicy: .returnPartiallyParsedIfPossible)) else { return Text(words) }
        return Text(styled)
    }

    // MARK: Before the first message

    @ViewBuilder private var opening: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            if case .failed(let failure) = chat.state {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.5))
                Text(chat.describe(failure, language: l10n.language))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                NotchPillButton(title: text.retry, prominent: true) { chat.retry() }
            } else {
                SiriMark()
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 30, height: 30)
                Text(enabled || preview ? text.emptyTitle : words.enable)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Asking

    private var trimmedDraft: String { chat.draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 6) {
            TextField(text.placeholder, text: $chat.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...4)
                .focused($typing)
                .onSubmit(submit)
                .padding(.vertical, 7)
                .accessibilityLabel(text.placeholder)
            if !trimmedDraft.isEmpty {
                Button(action: submit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 24, height: 24)
                        .background(Color.white, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 3)
                .help(text.send)
                .accessibilityLabel(text.send)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .frame(minHeight: 32)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: trimmedDraft.isEmpty)
        .disabled(preview)
    }

    private func submit() {
        let words = trimmedDraft
        guard !words.isEmpty else { return }
        chat.draft = ""
        chat.send(words)
        typing = true
    }
}

/// What Siri says it is doing before it answers, with a light passing
/// through the words as Siri's own status does.
struct NotchSiriStatusLine: View {
    let words: String
    @State private var phase: CGFloat = -1

    var body: some View {
        Text(words)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.35))
            .overlay {
                LinearGradient(colors: [.clear, .white.opacity(0.9), .clear],
                               startPoint: UnitPoint(x: phase, y: 0.5),
                               endPoint: UnitPoint(x: phase + 0.6, y: 0.5))
                    .mask(Text(words).font(.system(size: 13, weight: .medium)))
            }
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { phase = 1.4 }
            }
            .accessibilityLabel(words)
    }
}

/// One of Siri's cards, drawn by the island: the weather as Siri lays it
/// out, anything else as its title, its value and its details. A click opens
/// what the card is about (the day in Calendar, the list in Reminders); its
/// buttons settle what Siri prepared (Send on an email it drafted), the last
/// one the main one.
struct NotchSiriCard: View {
    let card: NotchHermesChatMessage.Card
    var press: (String) -> Void = { _ in }
    @State private var hovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: open) { face }
                .buttonStyle(.plain)
                .onHover { hovered = card.link != nil && $0 }
                .disabled(card.link == nil)
                .accessibilityLabel(card.lines.joined(separator: ", "))
            if !card.buttons.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(card.buttons.enumerated()), id: \.offset) { index, title in
                        let main = index == card.buttons.count - 1
                        Button { press(title) } label: {
                            Text(title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(main ? Color.black : Color.white.opacity(0.85))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(main ? Color.white : Color.white.opacity(0.12), in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(title)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func open() {
        guard let link = card.link, let url = URL(string: link) else { return }
        NSWorkspace.shared.open(url)
    }

    @ViewBuilder private var face: some View {
        if let weather = NotchSiriCardLayout.weather(card) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(weather.place, systemImage: "location.fill")
                        .labelStyle(TrailingIconLabel())
                        .font(.system(size: 13, weight: .semibold))
                    Text(weather.temperature)
                        .font(.system(size: 38, weight: .light))
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    if let symbol = card.symbol {
                        Image(systemName: symbol)
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 18))
                    }
                    Spacer(minLength: 0)
                    ForEach(weather.details, id: \.self) { detail in
                        Text(detail).font(.system(size: 11.5, weight: .medium))
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 104)
            .background(LinearGradient(colors: [Color(red: 0.17, green: 0.32, blue: 0.58),
                                                Color(red: 0.33, green: 0.52, blue: 0.78)],
                                       startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(hovered ? 0.9 : 1)
        } else {
            let layout = NotchSiriCardLayout.generic(card)
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    if let title = layout.title {
                        Text(title)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    if let value = layout.value {
                        Text(value)
                            .font(.system(size: 26, weight: .light))
                            .foregroundStyle(.white)
                    }
                    ForEach(layout.details, id: \.self) { detail in
                        Text(detail)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                if let symbol = card.symbol {
                    Image(systemName: symbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(hovered ? 0.13 : 0.09),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

/// A label with its icon after the words, as Siri marks the place it is
/// reporting on.
private struct TrailingIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon.font(.system(size: 10))
        }
    }
}
