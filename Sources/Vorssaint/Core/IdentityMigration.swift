// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Carries settings and data over from the bundle identifier the app had
/// before it became Dynamai: `com.vorssaint.utils`, or `.dev` for the
/// Developer build. macOS files preferences and the Application Support
/// folder under the bundle identifier, so without this the renamed app would
/// start as a fresh install with an empty clipboard history and shelf.
///
/// It runs once, before anything reads a preference, and never overwrites:
/// a setting already made under the new identity wins, and an existing new
/// folder is left alone. Permissions cannot be carried at all; macOS ties
/// them to the identity, so each one is granted again once.
enum IdentityMigration {
    static func previousIdentifier(for current: String?) -> String? {
        switch current {
        case "com.dynamai.app": return "com.vorssaint.utils"
        case "com.dynamai.app.dev": return "com.vorssaint.utils.dev"
        default: return nil
        }
    }

    /// The old settings the new identity does not have yet.
    static func preferencesToCopy(old: [String: Any], current: [String: Any]) -> [String: Any] {
        old.filter { current[$0.key] == nil }
    }

    /// Runs the migration for the running app, once.
    static func runIfNeeded() {
        guard let current = Bundle.main.bundleIdentifier,
              let previous = previousIdentifier(for: current) else { return }
        migrate(from: previous, to: current, defaults: .standard,
                supportDirectory: FileManager.default.urls(for: .applicationSupportDirectory,
                                                           in: .userDomainMask).first)
    }

    /// `defaults` must be the domain named `current`; tests pass their own.
    static func migrate(from previous: String, to current: String, defaults: UserDefaults,
                        supportDirectory: URL?, fileManager: FileManager = .default) {
        guard !defaults.bool(forKey: DefaultsKey.identityMigrated) else { return }

        if let old = defaults.persistentDomain(forName: previous), !old.isEmpty {
            let existing = defaults.persistentDomain(forName: current) ?? [:]
            for (key, value) in preferencesToCopy(old: old, current: existing) {
                defaults.set(value, forKey: key)
            }
        }

        // Clipboard history, shelf files, recordings and the rest live here.
        // A move, not a copy: recordings can be large, and the old identity
        // has no app left to read them.
        if let supportDirectory {
            let source = supportDirectory.appendingPathComponent(previous, isDirectory: true)
            let target = supportDirectory.appendingPathComponent(current, isDirectory: true)
            if fileManager.fileExists(atPath: source.path), !fileManager.fileExists(atPath: target.path) {
                try? fileManager.moveItem(at: source, to: target)
            }
        }

        defaults.set(true, forKey: DefaultsKey.identityMigrated)
    }
}
