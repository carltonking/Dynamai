// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The quick bar's face: one dark rounded sheet and the text, so whoever is
/// reading over your shoulder sees the message. The only control is the faint
/// size in the corner: type a number there and Return sets the text to it.
struct QuickBarView: View {
    @ObservedObject var service: QuickBarService
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.quickBarTextSize) private var textSize = QuickBarSupport.defaultTextSize
    @FocusState private var focus: Field?
    @State private var sizeDraft = ""

    private enum Field { case text, size }

    private var fontSize: CGFloat {
        CGFloat(QuickBarSupport.sanitizedTextSize(textSize))
    }

    var body: some View {
        editor
            .overlay(alignment: .topTrailing) { sizeField }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .environment(\.colorScheme, .dark)
            .onAppear { reset() }
            .onChange(of: service.openSerial) { _, _ in reset() }
            .onChange(of: textSize) { _, _ in
                if focus != .size { sizeDraft = sizeLabel }
            }
            .onChange(of: focus) { old, _ in
                // Clicking back into the message keeps a typed size too.
                if old == .size { commitSize() }
            }
    }

    private var sizeLabel: String { String(Int(fontSize)) }

    private var editor: some View {
        TextEditor(text: $service.text)
        .font(.system(size: fontSize, weight: .medium))
        .foregroundStyle(.white)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.never)
        .focused($focus, equals: .text)
        .tint(.white)
        .padding(.horizontal, 26)
        .padding(.top, 34)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(white: 0.07).opacity(0.97))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
        }
        .accessibilityLabel(FeatureStrings.quickBar(l10n.language).pageTitle)
    }

    private var sizeField: some View {
        TextField("", text: $sizeDraft)
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(focus == .size ? 0.9 : 0.4))
            .multilineTextAlignment(.trailing)
            .frame(width: 34)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.white.opacity(focus == .size ? 0.12 : 0.05),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .focused($focus, equals: .size)
            .onSubmit {
                commitSize()
                focus = .text
            }
            .onChange(of: sizeDraft) { _, typed in
                let digits = String(typed.filter(\.isNumber).prefix(3))
                if digits != typed { sizeDraft = digits }
            }
            .padding(.top, 10)
            .padding(.trailing, 14)
            .accessibilityLabel(FeatureStrings.scratchpad(l10n.language).textSize)
    }

    /// A number out of range lands on the nearest size the slider allows; an
    /// empty box puts the current size back.
    private func commitSize() {
        if let typed = Double(sizeDraft) {
            textSize = QuickBarSupport.sanitizedTextSize(typed)
        }
        sizeDraft = sizeLabel
    }

    private func reset() {
        sizeDraft = sizeLabel
        focus = .text
    }
}
