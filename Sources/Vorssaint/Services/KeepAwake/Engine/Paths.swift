// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Adapted from Insomnia (MIT) (C) 2026 Krish Garg, Sources/Insomnia/Store/Paths.swift

import Foundation

/// Every on-disk location Keep Awake's engine uses.
///
/// Dynamai: everything is keyed by the running bundle's id, so a developer
/// build (`com.dynamai.app.dev`) and an installed release never share a
/// journal, a lock or a recovery agent. The journal sits in the
/// app's own Application Support folder, which uninstalling already removes.
/// The recovery script is sealed into the running bundle, wherever it was
/// installed. The whole tree can be relocated with
/// the `INSOMNIA_HOME` environment variable (tests, and `backstop.sh` honours
/// the same variable with the same layout).
///
/// Default layout (`<id>` is the bundle id):
///   <running app>/Contents/Resources/keepawake-backstop.sh
///   ~/Library/Application Support/<id>/KeepAwake/{session.json,state.json,unfinished-command.json}
///   ~/Library/Logs/<id>/{keep-awake.log,handoffs.log}
///   ~/Library/LaunchAgents/<id>.keepawake-backstop.plist
///
/// With INSOMNIA_HOME=/x:
///   /x/Insomnia.app/Contents/Resources/backstop.sh
///   /x/{session.json,state.json,config.json,unfinished-command.json}
///   /x/Logs/{insomnia.log,handoffs.log}
///   /x/LaunchAgents/com.insomnia.backstop.plist
struct InsomniaPaths: Sendable, Equatable {
    static let environmentKey = "INSOMNIA_HOME"
    static var bundleIdentifier: String { Bundle.main.bundleIdentifier ?? "com.dynamai.app" }
    static var backstopLabel: String { "\(bundleIdentifier).keepawake-backstop" }

    let appSupport: URL
    let logs: URL
    let launchAgents: URL
    /// Where install.sh puts the app bundle. backstop.sh is sealed inside it.
    let appBundle: URL

    init(appSupport: URL, logs: URL, launchAgents: URL, appBundle: URL) {
        self.appSupport = appSupport
        self.logs = logs
        self.launchAgents = launchAgents
        self.appBundle = appBundle
    }

    /// Relocated layout rooted at one directory (used for INSOMNIA_HOME).
    init(root: URL) {
        self.init(
            appSupport: root,
            logs: root.appendingPathComponent("Logs", isDirectory: true),
            launchAgents: root.appendingPathComponent("LaunchAgents", isDirectory: true),
            appBundle: root.appendingPathComponent("Insomnia.app", isDirectory: true)
        )
    }

    /// The standard per-user layout under ~/Library.
    static var standard: InsomniaPaths {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library", isDirectory: true)
        let id = bundleIdentifier
        return InsomniaPaths(
            appSupport: library.appendingPathComponent("Application Support/\(id)/KeepAwake", isDirectory: true),
            logs: library.appendingPathComponent("Logs/\(id)", isDirectory: true),
            launchAgents: library.appendingPathComponent("LaunchAgents", isDirectory: true),
            appBundle: Bundle.main.bundleURL
        )
    }

    /// `INSOMNIA_HOME` if set, else `standard`.
    static func fromEnvironment(_ env: [String: String] = ProcessInfo.processInfo.environment) -> InsomniaPaths {
        if let root = env[environmentKey], !root.isEmpty {
            return InsomniaPaths(root: URL(fileURLWithPath: root, isDirectory: true))
        }
        return .standard
    }

    var sessionFile: URL { appSupport.appendingPathComponent("session.json") }
    /// Where an unreadable session.json goes: this prefix, a UTC stamp
    /// (yyyyMMddTHHmmssZ) and, if that name is taken, -1, -2, ... The same
    /// shape is produced by backstop.sh and removed by `uninstall.sh --purge`.
    static let unreadableSessionPrefix = "session.json.unreadable-"
    var stateFile: URL { appSupport.appendingPathComponent("state.json") }
    /// scripts/backstop.sh as install.sh seals it into a bundle, under
    /// Contents/Resources, before the bundle is signed. The LaunchAgent
    /// verifies the bundle's signature before running it (LaunchdBackstop).
    static func backstopScript(inBundle bundle: URL) -> URL {
        bundle.appendingPathComponent("Contents/Resources/keepawake-backstop.sh")
    }
    /// The sealed backstop.sh of the installed bundle.
    var backstopScript: URL { Self.backstopScript(inBundle: appBundle) }
    /// flock(2) file shared with backstop.sh (`lockf -k` on the same path).
    /// Created once, never unlinked, so both sides lock the same inode.
    var recoveryLock: URL { appSupport.appendingPathComponent(".recovery.lock") }
    /// The `sudo pmset` left running that holds the recovery lock, written
    /// while it runs so a relaunch after a crash can name it. Removed when
    /// it exits, and by the next transaction that takes the lock.
    var unfinishedCommandFile: URL { appSupport.appendingPathComponent("unfinished-command.json") }

    /// Both logs are owner-only and rotate to `<name>.1` past
    /// `OwnerOnly.maxLogBytes`; uninstall.sh --purge removes the `.1` too.
    var logFile: URL { logs.appendingPathComponent("keep-awake.log") }
    var handoffsLog: URL { logs.appendingPathComponent("handoffs.log") }

    var backstopPlist: URL { launchAgents.appendingPathComponent("\(InsomniaPaths.backstopLabel).plist") }

    /// Create every directory Insomnia writes into. Its own two are made
    /// 0700 (an existing one is tightened); the LaunchAgents directory is
    /// shared with every other login agent, so it is only created.
    func createDirectories() throws {
        if let problem = try OwnerOnly.createDirectory(appSupport) { OwnerOnly.reportOnce(problem) }
        if let problem = try OwnerOnly.createDirectory(logs) { OwnerOnly.reportOnce(problem) }
        try FileManager.default.createDirectory(at: launchAgents, withIntermediateDirectories: true)
    }
}
