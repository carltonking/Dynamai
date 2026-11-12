// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// The decisions behind the menu bar hider, kept free of AppKit and
/// Accessibility so they can be tested directly.
///
/// On macOS 27 a menu bar item can no longer be pushed off screen by an
/// oversized separator: the system ejects it. What still works is the
/// visibility restriction behind assessment mode, which keeps only an
/// allow-list of apps and system items. Everything here turns "what sits left
/// of the arrow" into that allow-list. Adapted from Hidden Bar's macOS 27
/// engine (MIT, Dwarves Foundation).
enum MenuBarHiderSupport {
    /// Processes that own macOS's own items (clock, Wi-Fi, Bluetooth…). They
    /// are hidden per item by number, never by bundle: restricting the bundle
    /// would take every system item with it.
    static let systemItemOwners: Set<String> = ["com.apple.MenuBarAgent", "com.apple.controlcenter",
                                                "com.apple.systemuiserver"]

    /// System items are named by a private number below `1 << bits`. Numbers
    /// a Mac does not use are ignored by the restriction, so the full range is
    /// always offered. 0 to 8 are in use on macOS 27.2; 64 leaves room.
    static let systemItemNumberBits = 6
    static let allSystemItemNumbers = Array(0..<(1 << systemItemNumberBits))

    /// One status item another process owns, as Accessibility reports it.
    struct Item: Equatable {
        let bundleIdentifier: String?
        let frame: CGRect
        /// The menu extra's identifier ("com.apple.menuextra.wifi") for
        /// macOS's own items. Nil for apps.
        let systemIdentifier: String?

        init(bundleIdentifier: String?, frame: CGRect, systemIdentifier: String? = nil) {
            self.bundleIdentifier = bundleIdentifier
            self.frame = frame
            self.systemIdentifier = systemIdentifier
        }
    }

    /// Which side of the arrow everything sits on.
    struct Layout: Equatable {
        var hiddenBundles: Set<String> = []
        var visibleBundles: Set<String> = []
        var hiddenSystemItems: Set<String> = []
    }

    /// Splits the bar at the arrow. In a left-to-right bar the hidden side is
    /// the left. An app with icons on both sides stays visible, because hiding
    /// is per app and an icon the user kept visible must never disappear.
    static func layout(of items: [Item], arrowFrame: CGRect, isLeftToRight: Bool,
                       ownBundle: String?) -> Layout {
        var layout = Layout()
        for item in items {
            guard let bundle = item.bundleIdentifier, bundle != ownBundle else { continue }
            let towardArrow = isLeftToRight ? item.frame.midX - arrowFrame.midX
                                            : arrowFrame.midX - item.frame.midX
            let hidden = towardArrow <= 0
            if systemItemOwners.contains(bundle) {
                if hidden, let identifier = item.systemIdentifier {
                    layout.hiddenSystemItems.insert(identifier)
                }
                continue
            }
            if hidden {
                layout.hiddenBundles.insert(bundle)
            } else {
                layout.visibleBundles.insert(bundle)
            }
        }
        layout.hiddenBundles.subtract(layout.visibleBundles)
        return layout
    }

    /// Everything that may stay on screen: Dynamai first, then the visible
    /// side, then every other running app not on the hidden side. Hiding by
    /// subtraction means an app whose icon Accessibility could not read in
    /// time stays visible rather than vanishing from the visible side.
    static func allowedBundles(ownBundle: String?, layout: Layout, runningBundles: [String]) -> [String] {
        let head = (ownBundle.map { [$0] } ?? []) + layout.visibleBundles.sorted()
        let rest = Set(runningBundles)
            .subtracting(head)
            .subtracting(layout.hiddenBundles)
            .sorted()
        return head + rest
    }

    /// Every system item number except those of the hidden system items.
    /// Unlearned identifiers simply stay visible.
    static func allowedSystemItems(hiding identifiers: Set<String>, numbers: [String: Int]) -> [Int] {
        let hidden = Set(identifiers.compactMap { numbers[$0] })
        return allSystemItemNumbers.filter { !hidden.contains($0) }
    }

    // MARK: Learning system item numbers

    /// Accessibility names system items by identifier, the restriction by
    /// number. One pass learns every number on screen: an unrestricted round,
    /// one round per bit hiding every number with that bit set, and a round
    /// hiding them all.
    static var learningRounds: [[Int]] {
        [allSystemItemNumbers]
            + (0..<systemItemNumberBits).map { bit in allSystemItemNumbers.filter { $0 & (1 << bit) == 0 } }
            + [[]]
    }

    /// Reads the rounds back. `seen[i]` holds the identifiers on screen during
    /// `learningRounds[i]`. An item's number is the bits of the rounds it
    /// disappeared in. One missing from the unrestricted round (Now Playing,
    /// which follows the playing app) or still present with every number
    /// hidden cannot be controlled, and is remembered so it is not relearned
    /// on every collapse.
    static func decode(seen: [Set<String>], wanted: Set<String>)
        -> (numbers: [String: Int], uncontrollable: Set<String>) {
        guard seen.count == systemItemNumberBits + 2,
              let unrestricted = seen.first, let hiddenAll = seen.last else {
            return ([:], [])
        }
        var numbers: [String: Int] = [:]
        var uncontrollable: Set<String> = []
        for identifier in unrestricted.union(wanted) {
            guard unrestricted.contains(identifier), !hiddenAll.contains(identifier) else {
                uncontrollable.insert(identifier)
                continue
            }
            var number = 0
            for bit in 0..<systemItemNumberBits where !seen[bit + 1].contains(identifier) {
                number |= 1 << bit
            }
            numbers[identifier] = number
        }
        return (numbers, uncontrollable)
    }

    /// Identifiers on the hidden side whose number has to be learned first.
    static func needsLearning(_ identifiers: Set<String>, numbers: [String: Int],
                              uncontrollable: Set<String>) -> Set<String> {
        identifiers.filter { numbers[$0] == nil && !uncontrollable.contains($0) }
    }

    /// Learned numbers belong to one macOS build; an update may renumber.
    static func storedNumbers(_ stored: [String: Int]?, storedBuild: String?,
                              currentBuild: String) -> [String: Int] {
        storedBuild == currentBuild ? stored ?? [:] : [:]
    }
}
