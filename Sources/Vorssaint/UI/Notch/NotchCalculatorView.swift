// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// What the calculator holds between visits to its page, so leaving it to
/// check something does not lose the expression being written.
final class NotchCalculatorModel: ObservableObject {
    static let shared = NotchCalculatorModel()
    @Published var input = ""
    /// The last whole answer, shown dimmed while the input is half-typed so
    /// the number does not flicker away between keystrokes.
    @Published private(set) var lastAnswer: String?

    private init() {}

    func remember(_ answer: String?) {
        if let answer { lastAnswer = answer }
        if input.trimmingCharacters(in: .whitespaces).isEmpty { lastAnswer = nil }
    }
}

/// The calculator page: the expression typeset in the middle as it is
/// written, its answer to the right, and the field to write it in along the
/// bottom. LaTeX and keyboard arithmetic both work, with or without
/// backslashes, and the answer follows every keystroke.
struct NotchCalculatorView: View {
    let size: CGSize
    @ObservedObject private var model = NotchCalculatorModel.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.notchSettingsPreview) private var preview
    @FocusState private var typing: Bool
    /// Bumped when a typeset formula becomes ready, so the page draws it.
    @State private var rendered = 0

    private static let previewSize: CGFloat = 26

    var body: some View {
        let result = NotchCalculatorEngine.evaluate(model.input)
        let answer = result.value.map(NotchCalculatorEngine.format)
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 20) {
                typeset(result.tex)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                answerView(answer)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            field
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: answer) { _, value in model.remember(value) }
        .onReceive(NotificationCenter.default.publisher(for: ScratchpadMathRenderer.didRender)) { _ in rendered += 1 }
        .task {
            guard !preview else { return }
            try? await Task.sleep(for: .milliseconds(80))
            typing = true
        }
    }

    /// KaTeX's picture of the expression; until it is ready, or offline, the
    /// expression as typed.
    @ViewBuilder private func typeset(_ tex: String) -> some View {
        let _ = rendered
        if tex.isEmpty {
            Color.clear
        } else if let image = ScratchpadMathRenderer.shared.image(tex: tex, display: true,
                                                                  fontSize: Self.previewSize, color: .white) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: min(image.size.width, max(0, size.width * 0.56)),
                       maxHeight: min(image.size.height, max(0, size.height - 80)))
                .accessibilityLabel(model.input)
        } else {
            Text(model.input)
                .font(.system(size: 17, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(3)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder private func answerView(_ answer: String?) -> some View {
        let shown = answer ?? model.lastAnswer
        if let shown {
            Text("= \(shown)")
                .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(answer == nil ? 0.35 : 1))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .textSelection(.enabled)
                .frame(maxWidth: size.width * 0.34, alignment: .trailing)
                .animation(.easeOut(duration: 0.12), value: answer == nil)
        }
    }

    private var field: some View {
        TextField(FeatureStrings.notch(l10n.language).calculatorPlaceholder, text: $model.input)
            .textFieldStyle(.plain)
            .font(.system(size: 15, design: .monospaced))
            .foregroundStyle(.white)
            .focused($typing)
            .autocorrectionDisabled()
            .padding(.horizontal, 16)
            .frame(height: 38)
            .overlay(Capsule().inset(by: 0.5).stroke(.white.opacity(0.7), lineWidth: 1))
            .contentShape(Capsule())
            .onTapGesture { typing = true }
            .accessibilityLabel(FeatureStrings.notch(l10n.language).calculator)
    }
}
