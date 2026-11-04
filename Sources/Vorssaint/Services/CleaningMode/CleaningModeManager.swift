// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import SwiftUI

/// "Cleaning mode" temporarily locks the keyboard and trackpad so the user can
/// wipe them down without typing gibberish or clicking around, then restores
/// them on a deliberate gesture. The lock is a HID-level event tap that swallows
/// key, pointer, click, scroll and gesture events before the system handles
/// them, including keyboard system keys such as brightness, media and volume.
/// The very same tap watches for the unlock gesture, so there is always a way
/// back: press Escape five times in a row. A cloth on the trackpad must not be
/// able to end the lock, so there is deliberately no clickable Unlock button.
///
/// Requires Accessibility, like the app's other event taps. If it is missing the
/// tap can't be created, so we never lock the keyboard with no way to unlock it.
final class CleaningModeManager: ObservableObject {
    static let shared = CleaningModeManager()

    private static let systemDefinedEventType = CGEventType(rawValue: CleaningSystemKeyEvent.systemDefinedEventTypeRawValue)!
    private static let gestureEventType = CGEventType(rawValue: UInt32(NSEvent.EventType.gesture.rawValue))!
    private static let escapeKeyCode: Int64 = 53
    private static let eventMask: CGEventMask = [
        CGEventType.keyDown,
        .keyUp,
        .flagsChanged,
        .scrollWheel,
        .mouseMoved,
        .leftMouseDragged,
        .rightMouseDragged,
        .otherMouseDragged,
        .leftMouseDown,
        .leftMouseUp,
        .rightMouseDown,
        .rightMouseUp,
        .otherMouseDown,
        .otherMouseUp,
        systemDefinedEventType,
        gestureEventType,
    ].reduce(CGEventMask(0)) { mask, type in
        mask | (CGEventMask(1) << type.rawValue)
    }

    @Published private(set) var isActive = false
    /// Consecutive Escape presses so far (0...unlockThreshold). The
    /// overlay shows this as progress.
    @Published private(set) var unlockProgress = 0
    @Published private(set) var shortcutRegistrationFailed = false
    /// Touches blocked since the lock began (anything but Escape). The lock
    /// badge shows the number and stays red from the first one to the unlock.
    @Published private(set) var blockedInputCount = 0
    var isBlockingInput: Bool { blockedInputCount > 0 }
    private var blockedInputTally = CleaningBlockedInputTally()
    /// Modifier state before the latest flags-changed event, so a modifier
    /// release is not counted as another touch.
    private var lastModifierFlags: UInt64 = 0

    /// Deliberate Escape presses needed to unlock. Other keys reset the count so
    /// wiping the keyboard cannot complete the gesture accidentally.
    let unlockThreshold = 5

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var overlays: [NSPanel] = []
    private var screenObserver: NSObjectProtocol?
    private let hotkey = QuickToolHotkey(id: 17)
    /// Where the cursor sat when the lock began. Dropping motion events does
    /// not stop the system moving the cursor, so every motion warps it back.
    private var pinnedCursorLocation: CGPoint?
    private var shouldRestoreSuspendedFeaturesOnSessionReturn = false
    // Mouse events still pass through Cleaning Mode. We only remember the
    // down/up lifecycle so teardown never cuts a click in half.
    private var mouseReleaseGate = CleaningMouseReleaseGate()
    /// Ends a user unlock's wait for a release this tap never sees.
    private var releaseDeadline: DispatchWorkItem?

    /// The unlock-gesture state machine (pure, unit-tested separately).
    /// The 6s press window forgives hesitant, deliberate presses — at 2s a user
    /// pressing Escape slower than once per two seconds could never unlock
    /// (progress restarted at 1 on every press). The window's one remaining job
    /// is rejecting five isolated Esc-only contacts spread across a long wipe:
    /// every other key resets the count — modifiers included, they reach the
    /// counter as flags-changed events — and auto-repeat never counts, but a
    /// cloth can strike Escape alone. Widening to 6s weakens that guard on
    /// purpose — a gesture a deliberate user cannot complete protects nothing.
    private lazy var unlock = CleaningUnlockCounter(requiredKeyCode: Self.escapeKeyCode,
                                                    threshold: unlockThreshold,
                                                    pressWindow: 6.0)

    private init() {
        hotkey.onPress = { [weak self] in self?.activateFromShortcut() }
        // A switched-away login session cannot keep a filter tap in the input
        // chain. Cleaning is a temporary local state, so leaving the session
        // ends it; suspended features resume only after this session returns.
        SessionActivity.shared.onChange { [weak self] active in
            guard let self else { return }
            if active {
                guard self.shouldRestoreSuspendedFeaturesOnSessionReturn else { return }
                self.shouldRestoreSuspendedFeaturesOnSessionReturn = false
                self.resumeSuspendedFeatures()
            } else if self.isActive {
                self.deactivate(restoreSuspendedFeatures: false)
            }
        }
    }

    func toggle() { isActive ? deactivate() : activate() }

    /// Option-3: the lock, with Keep Awake switched on as well, so a Mac left
    /// locked for a wipe or a walk away does not sleep under it. Unlocking
    /// ends the Keep Awake session this started; one already running before
    /// the lock was the person's own and keeps going.
    private func activateFromShortcut() {
        activate()
        guard isActive, AppFeature.keepAwake.isAvailable, !KeepAwakeManager.shared.isActive else { return }
        KeepAwakeManager.shared.startLastPick()
        startedKeepAwake = KeepAwakeManager.shared.isActive
    }

    /// Keep Awake is on because Option-3 turned it on with the lock.
    private var startedKeepAwake = false

    /// Registers the start shortcut (Option-3 by default). It only ever starts
    /// the lock: while the lock is up its tap swallows the combination before
    /// Carbon sees it, so Escape five times stays the one way out.
    func syncWithPreferences() {
        let available = AppFeature.cleaningMode.isAvailable
        let enabled = available
            && UserDefaults.standard.bool(forKey: DefaultsKey.cleaningModeShortcutEnabled)
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.cleaningModeShortcut,
                                            fallback: .cleaningModeDefault)
        shortcutRegistrationFailed = !hotkey.sync(enabled: enabled, shortcut: shortcut,
                                                  storageKey: DefaultsKey.cleaningModeShortcut)
        if !available { deactivate(restoreSuspendedFeatures: true) }
    }

    /// Starts the lock. No-op (and guides the user) when Accessibility is missing,
    /// because without the tap there would be no way to unlock the keyboard.
    func activate() {
        guard !isActive, AppFeature.cleaningMode.isAvailable,
              SessionActivity.shared.isActive else { return }
        // Check Accessibility explicitly (same gate the other event taps use) so a
        // missing grant is reported clearly, rather than inferred from a nil tap.
        guard Permissions.shared.accessibility else {
            promptForAccessibility()
            return
        }
        mouseReleaseGate.reset()
        guard installTap() else { return }
        // Debounce must not filter while the lock is up: its tap can run ahead
        // of ours (head-insert order depends on creation order) and would eat
        // the repeated same-key presses the unlock gesture counts on.
        KeyboardDebounceService.shared.suspend()
        MouseClickDebounceService.shared.suspend()
        // Wiping the trackpad is nothing but stray three-finger contacts;
        // middle-click emulation must not fire from them.
        MiddleClickService.shared.suspend()
        MouseNavigationService.shared.suspend()
        // A stray side-button press while wiping the mouse must not type a
        // key combination into the frontmost app (the synthesized keys are
        // posted below this lock's keyboard tap) nor open the wheel over
        // the cleaning overlay.
        MouseButtonShortcutService.shared.suspend()
        RadialMenuService.shared.suspend()
        unlock.reset()
        unlockProgress = 0
        resetBlockedInputCount()
        pinCursor()
        isActive = true
        installScreenObserver()
        showOverlays()
    }

    func deactivate() {
        guard isActive else { return }
        // If a press began while the lock was up, keep the overlay and tap
        // alive until its real mouse-up arrives and is swallowed, so no app sees
        // half a click. Never manufacture a release: the physical event is the
        // only event that completes the press.
        armReleaseDeadline()
        guard mouseReleaseGate.requestDeactivation() else { return }
        scheduleUserDeactivation()
    }

    /// Every unlock path waits on the gate, and the overlay can cover the menu
    /// bar, so the wait is bounded. Nothing is posted; it only stops waiting.
    private func armReleaseDeadline() {
        guard releaseDeadline == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.releaseDeadline = nil
            guard self.isActive, self.mouseReleaseGate.releaseWaitExpired() else { return }
            self.scheduleUserDeactivation()
        }
        releaseDeadline = work
        DispatchQueue.main.asyncAfter(deadline: .now() + CleaningMouseReleaseGate.releaseWaitLimit, execute: work)
    }

    /// Permission teardown must remove the tap before Accessibility is reset.
    func deactivateForSystemTeardown() {
        deactivate(restoreSuspendedFeatures: true)
    }

    private func deactivate(restoreSuspendedFeatures: Bool) {
        guard isActive else { return }
        // Session/tap failure paths cannot wait for another input event. They
        // retain the existing fail-open behaviour and tear down immediately.
        finishDeactivation(restoreSuspendedFeatures: restoreSuspendedFeatures)
    }

    private func scheduleUserDeactivation() {
        // Even when no button is currently held, leave the AppKit control action
        // before unmapping its non-activating panel. A new press may arrive before
        // this block runs, so keep the request pending until teardown completes.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isActive, self.mouseReleaseGate.deactivationPending,
                  self.mouseReleaseGate.pressedButtons.isEmpty else { return }
            self.finishDeactivation(restoreSuspendedFeatures: true)
        }
    }

    private func finishDeactivation(restoreSuspendedFeatures: Bool) {
        guard isActive else { return }
        releaseDeadline?.cancel()
        releaseDeadline = nil
        mouseReleaseGate.reset()
        removeTap()
        unpinCursor()
        removeScreenObserver()
        hideOverlays()
        unlock.reset()
        unlockProgress = 0
        resetBlockedInputCount()
        isActive = false
        if startedKeepAwake {
            startedKeepAwake = false
            if KeepAwakeManager.shared.isActive { KeepAwakeManager.shared.deactivate(reason: .manual) }
        }
        guard restoreSuspendedFeatures else {
            shouldRestoreSuspendedFeaturesOnSessionReturn = true
            return
        }
        shouldRestoreSuspendedFeaturesOnSessionReturn = false
        resumeSuspendedFeatures()
    }

    private func resumeSuspendedFeatures() {
        // Each owner reads its current availability, preference and permission,
        // so a feature changed while Cleaning Mode was active stays changed.
        KeyboardDebounceService.shared.syncWithPreferences()
        MouseClickDebounceService.shared.syncWithPreferences()
        MiddleClickService.shared.syncWithPreferences()
        MouseNavigationService.shared.syncWithPreferences()
        MouseButtonShortcutService.shared.syncWithPreferences()
        RadialMenuService.shared.syncWithPreferences()
    }

    // MARK: - Event tap

    private func installTap() -> Bool {
        let mask = Self.eventMask
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<CleaningModeManager>.fromOpaque(userInfo).takeUnretainedValue()
                return manager.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func removeTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        tap = nil
        runLoopSource = nil
    }

    /// The tap callback. Its run-loop source lives on the main run loop, so this
    /// runs on the main thread and can touch published state and AppKit directly.
    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system disables taps that stall or when the session locks; re-arm so
        // the keyboard stays locked instead of silently coming back.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if SessionActivity.shared.isActive, AXIsProcessTrusted(), let tap {
                // A disabled tap creates an observation gap: any tracked mouseDown
                // may already have received its real mouseUp while we were blind.
                // Invalidate that incomplete sequence so no later unlock can wait
                // forever for a release that already happened. If the user had
                // already requested deactivation, fail open after the callback.
                let shouldFinishUserDeactivation = mouseReleaseGate.deactivationPending
                mouseReleaseGate.invalidateTrackedPresses()
                CGEvent.tapEnable(tap: tap, enable: true)
                if shouldFinishUserDeactivation {
                    scheduleUserDeactivation()
                }
                return nil
            }
            let restoreSuspendedFeatures = SessionActivity.shared.isActive
            DispatchQueue.main.async { [weak self] in
                self?.deactivate(restoreSuspendedFeatures: restoreSuspendedFeatures)
            }
            return Unmanaged.passUnretained(event)
        }

        noteBlockedInput(type: type, event: event)

        // Clicks are locked like everything else. The one exception is the
        // release of a button already held when the lock began, so no app is
        // left believing that button is stuck down.
        if handleMouseButton(type: type, event: event) {
            return Unmanaged.passUnretained(event)
        }

        // The cursor follows the hardware even when its events are dropped,
        // so put it back where the lock found it.
        if Self.isPointerMotion(type) {
            holdCursorInPlace()
            return nil
        }

        // Feed key-downs to the unlock state machine. Auto-repeat (holding a key)
        // is ignored, so only distinct, deliberate taps of the same key count.
        if type == .keyDown {
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            registerUnlockKeyDown(code: code, isRepeat: isRepeat)
        } else if type == .flagsChanged {
            // Shift, control, option, command, fn and caps lock arrive here rather
            // than as key-downs, and they are the keys nearest Escape — a cloth
            // resting on them must reset the count like any other key. Both the
            // press and the release report the same key code and neither is
            // Escape, so each one resets and the pair is idempotent. Modifiers
            // never auto-repeat.
            registerUnlockKeyDown(code: event.getIntegerValueField(.keyboardEventKeycode),
                                  isRepeat: false)
        } else if type == Self.systemDefinedEventType,
                  let systemKey = systemKeyEvent(from: event),
                  systemKey.isKeyDown {
            registerUnlockKeyDown(code: systemKey.code, isRepeat: systemKey.isRepeat)
        }

        // Swallow keys, pointer movement, clicks, scrolling and trackpad
        // gestures while the lock is on. Only Escape five times unlocks.
        return nil
    }

    private static func isPointerMotion(_ type: CGEventType) -> Bool {
        type == .mouseMoved || type == .leftMouseDragged
            || type == .rightMouseDragged || type == .otherMouseDragged
    }

    // MARK: - Cursor pin

    private func pinCursor() {
        pinnedCursorLocation = CGEvent(source: nil)?.location
        // Detaching the cursor from the mouse is the stronger guarantee where
        // macOS honors it; the warp below covers it everywhere else.
        CGAssociateMouseAndMouseCursorPosition(0)
    }

    private func holdCursorInPlace() {
        guard let pinnedCursorLocation else { return }
        CGWarpMouseCursorPosition(pinnedCursorLocation)
    }

    private func unpinCursor() {
        pinnedCursorLocation = nil
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    // MARK: - Blocked-input count

    /// Counts input the user should see bounce off the lock: any key press but
    /// Escape (modifiers and media keys included), and every touch of the
    /// pointer — motion, clicks, scrolling and trackpad gestures. Releases and
    /// auto-repeat never count, and neither does Escape, so working toward the
    /// unlock never looks like a mistake.
    private func noteBlockedInput(type: CGEventType, event: CGEvent) {
        let before = blockedInputTally.count
        switch type {
        case .keyDown:
            guard event.getIntegerValueField(.keyboardEventKeycode) != Self.escapeKeyCode,
                  event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return }
            blockedInputTally.registerKeyPress()
        case .flagsChanged:
            let flags = event.flags.rawValue
            defer { lastModifierFlags = flags }
            guard CleaningBlockedInputTally.isModifierPress(
                keyCode: event.getIntegerValueField(.keyboardEventKeycode),
                previousFlags: lastModifierFlags, flags: flags) else { return }
            blockedInputTally.registerKeyPress()
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            blockedInputTally.registerPointerEvent(at: ProcessInfo.processInfo.systemUptime, isClick: true)
        case .scrollWheel, .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
             Self.gestureEventType:
            blockedInputTally.registerPointerEvent(at: ProcessInfo.processInfo.systemUptime, isClick: false)
        case Self.systemDefinedEventType:
            // Only real key-downs: the system also sends key-up and other
            // housekeeping events of this type.
            guard let key = systemKeyEvent(from: event), key.isKeyDown, !key.isRepeat else { return }
            blockedInputTally.registerKeyPress()
        default:
            return
        }
        // Publish only when the count moves, not for every motion event.
        if blockedInputTally.count != before {
            blockedInputCount = blockedInputTally.count
        }
    }

    private func resetBlockedInputCount() {
        blockedInputTally.reset()
        blockedInputCount = 0
        lastModifierFlags = CGEventSource.flagsState(.combinedSessionState).rawValue
    }

    /// Tracks a press seen under the lock and returns true only for a release
    /// that should pass through: one whose press predates the lock. Presses
    /// and their releases are swallowed; a pending unlock waits for the
    /// tracked release so that it is swallowed too instead of reaching an app
    /// as a stray mouse-up.
    private func handleMouseButton(type: CGEventType, event: CGEvent) -> Bool {
        let button: Int64
        let isDown: Bool
        switch type {
        case .leftMouseDown:
            button = 0
            isDown = true
        case .leftMouseUp:
            button = 0
            isDown = false
        case .rightMouseDown:
            button = 1
            isDown = true
        case .rightMouseUp:
            button = 1
            isDown = false
        case .otherMouseDown:
            button = event.getIntegerValueField(.mouseEventButtonNumber)
            isDown = true
        case .otherMouseUp:
            button = event.getIntegerValueField(.mouseEventButtonNumber)
            isDown = false
        default:
            return false
        }

        if isDown {
            mouseReleaseGate.buttonDown(button)
            return false
        }
        let pressedUnderLock = mouseReleaseGate.pressedButtons.contains(button)
        if mouseReleaseGate.buttonUp(button) {
            // The callback is running on this tap's run loop. Removing the tap
            // here would invalidate it from its own callback stack, so finish on
            // the next main-loop turn after the swallowed release.
            scheduleUserDeactivation()
        }
        return !pressedUnderLock
    }

    private func systemKeyEvent(from event: CGEvent) -> CleaningSystemKeyEvent? {
        guard let nsEvent = NSEvent(cgEvent: event) else { return nil }
        return CleaningSystemKeyEvent.decode(subtype: Int(nsEvent.subtype.rawValue),
                                             data1: nsEvent.data1)
    }

    private func registerUnlockKeyDown(code: Int64, isRepeat: Bool) {
        let unlocked = unlock.registerKeyDown(code: code,
                                              time: ProcessInfo.processInfo.systemUptime,
                                              isRepeat: isRepeat)
        unlockProgress = unlock.progress
        if unlocked {
            // deactivate() only records the request here; actual teardown is
            // scheduled after this tap callback has returned.
            deactivate()
        }
    }

    // MARK: - Overlay

    private func showOverlays() {
        let targets: [(frame: NSRect, badge: CleaningLockBadgeLayout)] = NSScreen.screens.map { screen in
            (screen.frame, CleaningLockBadgeLayout(screenFrame: screen.frame,
                                                   cameraLeftMaxX: screen.auxiliaryTopLeftArea?.maxX,
                                                   cameraRightMinX: screen.auxiliaryTopRightArea?.minX,
                                                   topInset: screen.safeAreaInsets.top))
        }
        let fallback = NSRect(x: 0, y: 0, width: 800, height: 600)
        let targetScreens = targets.isEmpty
            ? [(fallback, CleaningLockBadgeLayout(screenFrame: fallback, cameraLeftMaxX: nil,
                                                  cameraRightMinX: nil, topInset: 0))]
            : targets
        // Screen notifications can arrive in bursts even when the frames stay
        // unchanged. Reuse those panels so the overlay never flashes.
        var reusable = overlays
        overlays = targetScreens.map { target in
            if let index = reusable.firstIndex(where: { $0.frame == target.frame }) {
                return reusable.remove(at: index)
            }
            return makeOverlay(frame: target.frame, lockBadge: target.badge)
        }
        reusable.forEach { $0.orderOut(nil) }
    }

    private func makeOverlay(frame: NSRect, lockBadge: CleaningLockBadgeLayout) -> NSPanel {
        let panel = OverlayPanel(contentRect: frame,
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        // Above the menu bar and full-screen apps — the shielding level macOS uses
        // for its own lock-style windows.
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let host = NSHostingView(rootView: CleaningOverlayView(lockBadge: lockBadge))
        host.frame = NSRect(origin: .zero, size: frame.size)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.orderFrontRegardless()
        return panel
    }

    private func hideOverlays() {
        overlays.forEach { $0.orderOut(nil) }
        overlays = []
    }

    private func installScreenObserver() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self?.isActive == true else { return }
            self?.showOverlays()
        }
    }

    private func removeScreenObserver() {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
    }

    private func promptForAccessibility() {
        let strings = L10n.shared.s
        let alert = NSAlert()
        alert.messageText = strings.cleaningNeedsAxTitle
        alert.informativeText = strings.cleaningNeedsAxBody
        alert.addButton(withTitle: strings.permissionOpenSettings)
        alert.addButton(withTitle: strings.uninstallerCancel)
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            Permissions.shared.requestAccessibility()
            Permissions.shared.openAccessibilitySettings()
        }
    }
}
