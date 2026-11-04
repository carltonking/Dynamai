// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Overlay shown while the keyboard and trackpad are locked for cleaning.
/// Blacked out, it makes the locked state unmistakable and shows progress
/// toward the unlock gesture; with the screen kept visible it is only a lock
/// badge beside the Dynamic Island. Clicks are locked too, so it offers
/// nothing to click: Escape five times is the only way out.
struct CleaningOverlayView: View {
    /// Where this screen's lock badge goes, beside its Dynamic Island.
    let lockBadge: CleaningLockBadgeLayout
    @ObservedObject private var manager = CleaningModeManager.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.cleaningModeKeepScreenVisible) private var keepScreenVisible = false

    var body: some View {
        ZStack {
            if keepScreenVisible {
                Color.clear.ignoresSafeArea()
                islandLockBadge
            } else {
                Color.black.ignoresSafeArea()
                fullBlackoutContent
            }
        }
    }

    private var fullBlackoutContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "keyboard")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.white)

            Text(l10n.s.cleaningOverlayTitle)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.white)

            Text(l10n.s.cleaningOverlaySubtitle)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)

            fullProgressDots
                .padding(.top, 2)
        }
        .padding(44)
        .frame(maxWidth: 460)
    }

    /// With the screen kept visible the only sign of the lock is a small
    /// padlock beside the island: no instructions, nothing to click. From the
    /// first blocked touch (anything but Escape) it stays red until the
    /// unlock, with the number of touches printed in its body.
    private var islandLockBadge: some View {
        let glyphSize = lockBadge.size.height * 0.7
        return Image(systemName: "lock.fill")
            .font(.system(size: glyphSize, weight: .semibold))
            .foregroundStyle(manager.isBlockingInput ? Color.red : Color.white)
            .overlay(alignment: .bottom) {
                if manager.isBlockingInput {
                    blockedInputCountLabel(glyphSize: glyphSize)
                }
            }
            .animation(.easeOut(duration: 0.15), value: manager.isBlockingInput)
            .frame(width: lockBadge.size.width, height: lockBadge.size.height)
            .position(lockBadge.center)
            .ignoresSafeArea()
            .accessibilityLabel(l10n.s.cleaningOverlayTitle)
    }

    /// Sized to the padlock's body, below the shackle; long counts shrink to
    /// fit rather than spill over the edges.
    private func blockedInputCountLabel(glyphSize: CGFloat) -> some View {
        Text(CleaningBlockedInputTally.label(for: manager.blockedInputCount))
            .font(.system(size: glyphSize * 0.46, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color.black)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .frame(width: glyphSize * 0.56, height: glyphSize * 0.5)
            .padding(.bottom, glyphSize * 0.08)
    }

    private var fullProgressDots: some View {
        HStack(spacing: 11) {
            ForEach(0..<manager.unlockThreshold, id: \.self) { index in
                Circle()
                    .fill(index < manager.unlockProgress ? Color.white : Color.white.opacity(0.22))
                    .frame(width: 12, height: 12)
            }
        }
        .animation(.easeOut(duration: 0.15), value: manager.unlockProgress)
    }
}
