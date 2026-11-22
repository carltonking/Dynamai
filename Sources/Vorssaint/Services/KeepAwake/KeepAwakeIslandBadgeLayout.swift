// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// Where the Keep Awake badge sits: beside the Dynamic Island, on the right,
/// where Cleaning Mode puts its padlock. While the padlock shows, the badge
/// steps one place further right so both stay readable. Mirrors
/// `CleaningLockBadgeLayout`, so the two match in size and height.
struct KeepAwakeIslandBadgeLayout: Equatable {
    let center: CGPoint
    let size: CGSize

    init(screenFrame: CGRect, cameraLeftMaxX: CGFloat?, cameraRightMinX: CGFloat?, topInset: CGFloat,
         besidePadlock: Bool = false) {
        let padlock = CleaningLockBadgeLayout(screenFrame: screenFrame, cameraLeftMaxX: cameraLeftMaxX,
                                              cameraRightMinX: cameraRightMinX, topInset: topInset)
        size = padlock.size
        let step = besidePadlock ? size.width + CleaningLockBadgeLayout.gap : 0
        center = CGPoint(x: padlock.center.x + step, y: padlock.center.y)
    }

    /// The badge's own window, in screen coordinates: only as large as the
    /// glyph, so nothing else on the menu bar is covered.
    func panelFrame(in screenFrame: CGRect) -> CGRect {
        CGRect(x: screenFrame.minX + center.x - size.width / 2,
               y: screenFrame.maxY - center.y - size.height / 2,
               width: size.width, height: size.height)
    }
}
