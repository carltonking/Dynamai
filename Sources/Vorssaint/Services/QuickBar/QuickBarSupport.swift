// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// The decisions behind the quick bar, kept free of AppKit so they can be
/// tested directly.
///
/// The bar is for text someone else reads over your shoulder, so it is set
/// large, at one size the person chooses: the type never changes on its own
/// as the message grows.
enum QuickBarSupport {
    static let panelSize = CGSize(width: 680, height: 380)

    static let defaultTextSize: Double = 32
    static let textSizeRange: ClosedRange<Double> = 16...64

    static func sanitizedTextSize(_ value: Double) -> Double {
        guard value.isFinite else { return defaultTextSize }
        return min(max(value.rounded(), textSizeRange.lowerBound), textSizeRange.upperBound)
    }

    /// Centered on the screen, a little above the middle, where Spotlight
    /// opens, and kept inside the visible frame on a small display.
    static func panelFrame(in visibleFrame: CGRect, size: CGSize = panelSize) -> CGRect {
        let width = min(size.width, visibleFrame.width - 40)
        let height = min(size.height, visibleFrame.height - 40)
        let x = visibleFrame.midX - width / 2
        let centeredY = visibleFrame.midY - height / 2
        let raisedY = centeredY + visibleFrame.height * 0.08
        let y = min(raisedY, visibleFrame.maxY - height - 20)
        return CGRect(x: x.rounded(), y: max(visibleFrame.minY + 20, y).rounded(),
                      width: width, height: height)
    }
}
