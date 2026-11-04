// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Renaming the app to Dynamai changed its bundle identifier, which is what
/// macOS files settings and data under. The first launch has to find them
/// under the old identity, once, without overwriting anything newer.
enum IdentityMigrationTests {
    static func run(_ suite: TestSuite) {
        suite.run("identity migration maps each build to its old identity") {
            suite.expect(IdentityMigration.previousIdentifier(for: "com.dynamai.app") == "com.vorssaint.utils",
                   "the official app takes over the official identity")
            suite.expect(IdentityMigration.previousIdentifier(for: "com.dynamai.app.dev") == "com.vorssaint.utils.dev",
                   "the Developer build takes over its own, never the official one")
            suite.expect(IdentityMigration.previousIdentifier(for: nil) == nil
                    && IdentityMigration.previousIdentifier(for: "com.vorssaint.utils") == nil,
                   "a bare binary or an unrenamed build migrates nothing")
        }

        suite.run("identity migration carries settings and data over once") {
            let old = "com.vorssaint.tests.identity-old"
            let new = "com.vorssaint.tests.identity-new"
            let support = FileManager.default.temporaryDirectory
                .appendingPathComponent("identity-migration-\(UUID().uuidString)", isDirectory: true)
            guard let defaults = UserDefaults(suiteName: new) else {
                suite.expect(false, "test defaults available")
                return
            }
            defer {
                defaults.removePersistentDomain(forName: new)
                defaults.removePersistentDomain(forName: old)
                try? FileManager.default.removeItem(at: support)
            }
            defaults.removePersistentDomain(forName: new)
            defaults.setPersistentDomain(["notchEnabled": true, "language": "pt-BR"], forName: old)
            defaults.set("en", forKey: "language")
            let oldFolder = support.appendingPathComponent(old, isDirectory: true)
            try? FileManager.default.createDirectory(at: oldFolder, withIntermediateDirectories: true)
            try? Data("history".utf8).write(to: oldFolder.appendingPathComponent("clipboard.json"))

            IdentityMigration.migrate(from: old, to: new, defaults: defaults, supportDirectory: support)

            suite.expect(defaults.bool(forKey: "notchEnabled"), "an old setting arrives under the new identity")
            suite.expect(defaults.string(forKey: "language") == "en", "a setting already made under the new one wins")
            let moved = support.appendingPathComponent(new, isDirectory: true).appendingPathComponent("clipboard.json")
            suite.expect(FileManager.default.fileExists(atPath: moved.path)
                    && !FileManager.default.fileExists(atPath: oldFolder.path),
                   "the data folder moves to the new identity")

            defaults.setPersistentDomain(["notchEnabled": false], forName: old)
            IdentityMigration.migrate(from: old, to: new, defaults: defaults, supportDirectory: support)
            suite.expect(defaults.bool(forKey: "notchEnabled"), "it runs once: later changes to the old identity are ignored")
        }
    }
}
