// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Static identity of the app, shared by UI, notifications and tooling.
enum AppInfo {
    static let name = "Dynamai"
    /// Dynamai is built from Vorssaint (GPL-3.0-or-later), whose copyright
    /// notice the license requires the app to keep showing.
    static let copyright = "Based on Vorssaint · © 2026 Vorssaint · GPL-3.0"

    // Dynamai has no website, repository, donation or community pages of its
    // own yet. Every link, invitation and menu item that would point at one
    // is hidden while its address is nil; set one and it comes back.
    static let websiteURL: URL? = nil
    static let repositoryURL: URL? = nil
    static let coffeeURL: URL? = nil
    static let discordURL: URL? = nil
    static let socialURL: URL? = nil
    static var hasSupportLinks: Bool { coffeeURL != nil || repositoryURL != nil || discordURL != nil }

    /// The GitHub `owner/repo` whose releases the in-app updater installs.
    /// Nil turns updating off entirely: nothing is checked or downloaded, and
    /// the update controls are hidden. The app this was forked from publishes
    /// its own releases, which would replace Dynamai if they were installed.
    static let updateRepository: String? = nil
    static var updatesEnabled: Bool { updateRepository != nil }

    /// Where Send Feedback posts. Nil hides it: the server the fork came with
    /// belongs to Vorssaint's maintainers, not to this app.
    static let feedbackEndpoint: URL? = nil

    /// The bundle version. The fallback only applies to the bare binary
    /// (e.g. `--selftest`), never the shipped app, which reads its Info.plist.
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    /// True for the local developer build (bundle id ends in `.dev`).
    /// It is never published and never auto-updates; all work is tested here first.
    static var isDeveloperBuild: Bool {
        (Bundle.main.bundleIdentifier ?? "").hasSuffix(".dev")
    }

    /// True when the current version is a pre-release (e.g. 3.3.4-beta.1 or 3.3.4-rc.1).
    static var isBeta: Bool {
        if isDeveloperBuild && UserDefaults.standard.bool(forKey: DefaultsKey.simulateBetaUI) {
            return true
        }
        let v = version.lowercased()
        return v.contains("-beta") || v.contains("-rc") || v.contains("-alpha")
    }

    /// The git commit a Developer build was compiled from, e.g. "ed2ebba · 2026-06-15 21:30"
    /// (or with a "-dirty" suffix on the SHA for uncommitted changes). build.sh stamps
    /// this into the Developer bundle only, so you can confirm at a glance that the
    /// running dev app matches the source you are about to change. nil in the official app.
    static var buildCommit: String? {
        Bundle.main.object(forInfoDictionaryKey: "VorssaintBuildCommit") as? String
    }
}
