// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// A floating bar for typing something the person beside you reads, the way
/// people borrow Spotlight's search field to talk without speaking.
///
/// Nothing is kept: the text lives only while the bar is up and is erased the
/// moment it closes, so every opening starts empty. Nothing runs at rest
/// either; the panel is built on first use and only a hotkey stays registered.
final class QuickBarService: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = QuickBarService()

    @Published private(set) var shortcutRegistrationFailed = false
    @Published var text = ""
    /// Bumped on every opening so the view puts the caret back in the field.
    @Published private(set) var openSerial = 0

    private let hotkey = QuickToolHotkey(id: 91)
    private var panel: QuickBarPanel?

    private override init() {
        super.init()
        hotkey.onPress = { [weak self] in self?.toggle() }
    }

    func syncWithPreferences() {
        let available = AppFeature.quickBar.isAvailable
        let enabled = available
            && UserDefaults.standard.bool(forKey: DefaultsKey.quickBarShortcutEnabled)
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.quickBarShortcut,
                                            fallback: .quickBarDefault)
        shortcutRegistrationFailed = !hotkey.sync(enabled: enabled, shortcut: shortcut,
                                                  storageKey: DefaultsKey.quickBarShortcut)
        if !available {
            hide()
            panel = nil
        }
    }

    func suspend() {
        hotkey.unregister()
        hide()
    }

    var isVisible: Bool { panel?.isVisible == true }

    func toggle() {
        if panel?.isKeyWindow == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard AppFeature.quickBar.isAvailable else { return }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        if let screen {
            panel.setFrame(QuickBarSupport.panelFrame(in: screen.visibleFrame), display: false)
        }
        openSerial &+= 1
        let wasVisible = panel.isVisible
        if !wasVisible { panel.alphaValue = 0 }
        panel.makeKeyAndOrderFront(nil)
        guard !wasVisible else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        // Erased on every close, however it closes: nothing typed survives.
        text = ""
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        panel.alphaValue = 1
    }

    private func makePanel() -> QuickBarPanel {
        let panel = QuickBarPanel(contentRect: CGRect(origin: .zero, size: QuickBarSupport.panelSize),
                                  styleMask: [.borderless, .nonactivatingPanel],
                                  backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.hide() }
        let host = NSHostingView(rootView: QuickBarView(service: self))
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        return panel
    }

    /// A click anywhere else takes the keyboard away, which closes the bar.
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}

/// Borderless panels refuse the keyboard unless told otherwise, and Esc
/// arrives as cancelOperation from the text view's responder chain.
final class QuickBarPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
