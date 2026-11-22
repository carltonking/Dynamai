// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import SwiftUI

/// Shows the Keep Awake bolt beside the Dynamic Island on every screen
/// while Keep Awake is on, so a glance tells the Mac will not sleep. It is
/// click-through and sits one level below the island, which covers it when
/// it opens; the open island shows the same bolt in its top row. Off by default; nothing is observed while the option is off.
final class KeepAwakeIslandBadge {
    static let shared = KeepAwakeIslandBadge()

    private var panels: [NSPanel] = []
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    /// Called once at launch. Reacts to Keep Awake starting and stopping,
    /// the option, the chosen icon and tint, and display changes.
    func start() {
        guard cancellables.isEmpty else { return }
        KeepAwakeManager.shared.$isActive
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.sync() }
            .store(in: &cancellables)
        // The padlock takes the badge's place; the badge moves along.
        CleaningModeManager.shared.$isActive
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.sync() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &cancellables)
        sync()
    }

    private var shouldShow: Bool {
        AppFeature.keepAwake.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeIslandBadge)
            && KeepAwakeManager.shared.isActive
    }

    /// The filled bolt Keep Awake shows while it is on in the launcher and
    /// the command bar, so the badge reads as that tool rather than as the
    /// menu bar icon.
    private var symbolName: String { "bolt.fill" }

    /// Cleaning Mode draws its padlock beside the island only while the
    /// screen stays visible; the blackout covers the badge anyway.
    private var padlockShown: Bool {
        CleaningModeManager.shared.isActive
            && UserDefaults.standard.bool(forKey: DefaultsKey.cleaningModeKeepScreenVisible)
    }

    /// Plain white at full strength, like Cleaning Mode's padlock.
    private var tint: Color { .white }

    /// Defaults change often; only rebuild when what is shown would change.
    private var shownStyle: (symbol: String, tint: Color)?

    private func sync() {
        guard shouldShow else {
            hide()
            return
        }
        if panels.isEmpty || shownStyle?.symbol != symbolName || shownStyle?.tint != tint {
            rebuild()
        }
    }

    private func rebuild() {
        hide()
        guard shouldShow else { return }
        let style = (symbol: symbolName, tint: tint)
        shownStyle = style
        let label = FeatureStrings.keepAwakeIslandBadge(L10n.shared.language).accessibilityLabel
        panels = NSScreen.screens.map { screen in
            let layout = KeepAwakeIslandBadgeLayout(screenFrame: screen.frame,
                                                    cameraLeftMaxX: screen.auxiliaryTopLeftArea?.maxX,
                                                    cameraRightMinX: screen.auxiliaryTopRightArea?.minX,
                                                    topInset: screen.safeAreaInsets.top,
                                                    besidePadlock: padlockShown)
            let panel = OverlayPanel(contentRect: layout.panelFrame(in: screen.frame),
                                     styleMask: [.borderless, .nonactivatingPanel],
                                     backing: .buffered, defer: false)
            panel.isFloatingPanel = true
            // Above the menu bar, one below the island (`NotchPanel.normalLevel`).
            panel.level = .statusBar
            panel.ignoresMouseEvents = true
            panel.backgroundColor = .clear
            panel.alphaValue = 1
            panel.isOpaque = false
            panel.hasShadow = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            let glyph = Image(systemName: style.symbol)
                .font(.system(size: layout.size.height * 0.7, weight: .semibold))
                .foregroundStyle(style.tint)
                .opacity(1)
                .frame(width: layout.size.width, height: layout.size.height)
                .accessibilityLabel(label)
            panel.contentView = NSHostingView(rootView: glyph)
            panel.orderFrontRegardless()
            return panel
        }
    }

    private func hide() {
        panels.forEach { $0.orderOut(nil) }
        panels = []
        shownStyle = nil
    }
}
