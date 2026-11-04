// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// Pure state machine for the cleaning-mode unlock gesture: it counts deliberate
/// presses of one required key. Other keys reset the count, auto-repeat is ignored,
/// and a long pause restarts it. Extracted from the event tap so the logic can be
/// tested deterministically.
struct CleaningUnlockCounter {
    let requiredKeyCode: Int64
    let threshold: Int
    /// A required-key press only counts if it lands within this window of the previous
    /// one; a longer gap restarts the count.
    let pressWindow: TimeInterval

    private(set) var progress = 0
    private var lastKeyTime: TimeInterval = -.greatestFiniteMagnitude

    init(requiredKeyCode: Int64, threshold: Int, pressWindow: TimeInterval) {
        self.requiredKeyCode = requiredKeyCode
        self.threshold = threshold
        self.pressWindow = pressWindow
    }

    /// Registers a key-down at `time` (a monotonic clock). `isRepeat` is true for
    /// auto-repeat events, which never count. Returns true once `progress` reaches
    /// the threshold, signalling the caller to unlock.
    mutating func registerKeyDown(code: Int64, time: TimeInterval, isRepeat: Bool) -> Bool {
        guard !isRepeat else { return false }
        guard code == requiredKeyCode else {
            progress = 0
            lastKeyTime = -.greatestFiniteMagnitude
            return false
        }
        if time - lastKeyTime <= pressWindow {
            progress += 1
        } else {
            progress = 1
        }
        lastKeyTime = time
        return progress >= threshold
    }

    mutating func reset() {
        progress = 0
        lastKeyTime = -.greatestFiniteMagnitude
    }
}

/// Counts the touches the lock has blocked and keeps the lock badge red from
/// the first one until the lock ends, so a user returning from a wipe can see
/// that, and how often, the keyboard or trackpad was touched. A short flash
/// that went dark after a moment was easy to miss.
///
/// Pure, so the counting rules are testable; the manager feeds it events and
/// owns the clock.
struct CleaningBlockedInputTally {
    /// Pointer events (motion, scrolling, trackpad gestures, clicks) arrive
    /// by the hundred for one finger on the trackpad. They belong to the same
    /// touch until the pointer has been quiet for this long.
    static let touchGap: TimeInterval = 0.5

    /// Device-independent modifier bits plus the low device-dependent bits
    /// that tell left from right, so pressing the second Shift still counts.
    static let modifierBits: UInt64 = 0xFFFF
        | CGEventFlags.maskShift.rawValue | CGEventFlags.maskControl.rawValue
        | CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskCommand.rawValue
        | CGEventFlags.maskSecondaryFn.rawValue | CGEventFlags.maskAlphaShift.rawValue
    static let capsLockKeyCode: Int64 = 57

    private(set) var count = 0
    var isLit: Bool { count > 0 }

    private var lastPointerEvent: TimeInterval = -.greatestFiniteMagnitude
    private var touchHasClick = false

    /// A key press (never a release or auto-repeat). Each one counts.
    mutating func registerKeyPress() {
        count += 1
    }

    /// Any pointer event at `time`. A new touch counts once however many events
    /// it produces. A click on a touch that is already counted is the same
    /// contact, but a second click in it (a double-click) counts again.
    mutating func registerPointerEvent(at time: TimeInterval, isClick: Bool) {
        defer { lastPointerEvent = time }
        if time - lastPointerEvent > Self.touchGap {
            count += 1
            touchHasClick = isClick
            return
        }
        guard isClick else { return }
        if touchHasClick { count += 1 }
        touchHasClick = true
    }

    /// Modifiers arrive as flags-changed events for both press and release.
    /// A press adds a modifier bit; a release only removes one. Caps Lock
    /// toggles its bit off on a press, so its every event is a press.
    static func isModifierPress(keyCode: Int64, previousFlags: UInt64, flags: UInt64) -> Bool {
        if keyCode == capsLockKeyCode { return true }
        let gained = flags & ~previousFlags & modifierBits
        return gained != 0
    }

    mutating func reset() {
        count = 0
        lastPointerEvent = -.greatestFiniteMagnitude
        touchHasClick = false
    }

    /// The badge is small: past three digits it shows "999+".
    static func label(for count: Int) -> String {
        count > 999 ? "999+" : "\(count)"
    }
}

/// Where the lock badge sits while Cleaning Mode is on: in the menu-bar band,
/// just right of the Dynamic Island, so the locked state is visible without
/// covering the screen. Coordinates are the overlay view's own (top-left
/// origin, sized like the screen).
struct CleaningLockBadgeLayout: Equatable {
    /// The island is about the width of a camera housing; displays without
    /// one get an island of roughly this width centered at the top.
    static let fallbackIslandWidth: CGFloat = 190
    static let fallbackBandHeight: CGFloat = 24
    static let gap: CGFloat = 8

    let center: CGPoint
    let size: CGSize

    /// `cameraLeftMaxX`/`cameraRightMinX` are the screen-space edges of the
    /// two menu-bar areas beside the camera housing (nil without a notch);
    /// `topInset` is the screen's top safe-area inset.
    init(screenFrame: CGRect, cameraLeftMaxX: CGFloat?, cameraRightMinX: CGFloat?, topInset: CGFloat) {
        let band = topInset > 0 ? topInset : Self.fallbackBandHeight
        let height = max(16, min(band, 32) - 6)
        size = CGSize(width: (height * 1.5).rounded(), height: height)
        let islandRight: CGFloat
        if let left = cameraLeftMaxX, let right = cameraRightMinX, right > left {
            islandRight = right - screenFrame.minX
        } else {
            islandRight = screenFrame.width / 2 + Self.fallbackIslandWidth / 2
        }
        center = CGPoint(x: islandRight + Self.gap + size.width / 2, y: band / 2)
    }
}

struct CleaningSystemKeyEvent: Equatable {
    static let systemDefinedEventTypeRawValue: UInt32 = 14
    static let powerKeySubtype = 1
    static let auxiliaryControlButtonsSubtype = 8
    static let keyDownState = 10
    static let keyUpState = 11

    private static let syntheticKeyCodeBase: Int64 = 10_000

    let code: Int64
    let isKeyDown: Bool
    let isRepeat: Bool

    static func decode(subtype: Int, data1: Int) -> CleaningSystemKeyEvent? {
        switch subtype {
        case auxiliaryControlButtonsSubtype:
            return decodeAuxiliaryControl(data1: data1)
        case powerKeySubtype:
            return CleaningSystemKeyEvent(code: syntheticKeyCodeBase + Int64(powerKeySubtype),
                                          isKeyDown: true,
                                          isRepeat: false)
        default:
            return nil
        }
    }

    private static func decodeAuxiliaryControl(data1: Int) -> CleaningSystemKeyEvent? {
        let raw = UInt32(truncatingIfNeeded: data1)
        let keyCode = Int64((raw >> 16) & 0xffff)
        let state = Int((raw >> 8) & 0xff)
        guard state == keyDownState || state == keyUpState else { return nil }
        return CleaningSystemKeyEvent(code: syntheticKeyCodeBase + keyCode,
                                      isKeyDown: state == keyDownState,
                                      isRepeat: (raw & 0x1) != 0)
    }
}
