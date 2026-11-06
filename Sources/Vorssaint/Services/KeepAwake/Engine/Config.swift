// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Adapted from Insomnia (MIT) (C) 2026 Krish Garg, Sources/Insomnia/Model/Config.swift

import Foundation

/// The engine's settings. Insomnia kept them in config.json; here each one is
/// a `DefaultsKey` (`KeepAwakeSettings.config()` builds this value), so the
/// engine reads one snapshot and Settings writes preferences. The session
/// presets, the login item and the one-time lid-close update are gone: the
/// switch is on or off, and Dynamai owns its login item.
struct InsomniaConfig: Equatable, Sendable {
    /// Ceiling on one lease. The switch has no end; the lease
    /// (`KeepAwakeLease`) only ever runs minutes ahead.
    var maxDuration: TimeInterval = 30 * 24 * 3600

    // Lid close
    /// Bundle ids to SIGSTOP while the lid is closed.
    var freezeList: [String] = InsomniaConfig.defaultFreezeList
    /// Also SIGSTOP every other Dock app that is not an agent app, an Apple
    /// app, Docker Desktop or built-in protected (`FreezePlanner.builtInProtected`).
    var freezeAllApps: Bool = false
    /// SIGSTOP Docker Desktop on lid close when `docker ps` finds no running
    /// container, checked once more right before the signal.
    var dockerRule: Bool = false
    /// Mute the output on lid close and restore the volume on open: with
    /// sleep disabled, sound otherwise keeps playing from the closed laptop.
    var muteOnLidClose: Bool = true
    /// Save the display brightness and keyboard backlight, set both to zero
    /// on lid close and restore them on lid open. With sleep disabled macOS
    /// no longer turns the panel off itself.
    var darkenDisplayOnLidClose: Bool = true
    /// Switch Low Power Mode on while the lid is closed (heat and battery:
    /// with sleep disabled the machine otherwise runs at full speed).
    var lowPowerOnLidClose: Bool = true

    // Agents
    var agentList: [String] = InsomniaConfig.defaultAgentList
    /// Write `NSAppSleepDisabled = YES` into each agent app's preferences
    /// while on, and put the previous value back when off.
    var disableAppNapForAgents: Bool = false

    // Power
    /// Battery percentage below which Low Power Mode is switched on.
    var lowPowerFloor: Int = 40
    /// Battery percentage below which Keep Awake turns off. 0 turns the
    /// battery end off. Kept below `lowPowerFloor`.
    var endFloor: Int = 10
    var thermalRules: Bool = true

    // Network
    var hotspotSSID: String = ""
    /// Seconds of outage after which tmux panes are nudged.
    var nudgeThreshold: TimeInterval = 90
    /// tmux targets as `session:window.pane`. Only a pane carrying the
    /// `@insomnia-nudge` pane option is nudged (TmuxNudge).
    var tmuxTargets: [String] = []
    /// Press Enter after typing `continue`.
    var tmuxNudgePressesEnter: Bool = false

    /// Default freeze list: chat apps that burn battery in the background.
    static let defaultFreezeList: [String] = [
        "com.tinyspeck.slackmacgap",      // Slack
        "net.whatsapp.WhatsApp",          // WhatsApp
        "com.hnc.Discord",                // Discord
    ]

    /// Default agent list (spec section 5). Bundle ids confirmed against
    /// installed apps where possible; see README for how to edit.
    static let defaultAgentList: [String] = [
        "com.t3tools.t3code",             // T3 Code (Nightly)
        "com.t3tools.t3code.reasoning",   // T3 Code (Reasoning)
        "com.conductor.app",              // Conductor
        "com.apple.Terminal",             // Terminal
        "com.googlecode.iterm2",          // iTerm2
        "com.mitchellh.ghostty",          // Ghostty
        "dev.warp.Warp-Stable",           // Warp
        "com.google.Chrome",              // Google Chrome
        "org.chromium.Chromium",          // Chromium
        "company.thebrowser.Browser",     // Arc
        "com.docker.docker",              // Docker Desktop
        "com.microsoft.VSCode",           // Visual Studio Code
        "com.todesktop.230313mzl4w4u92",  // Cursor
        "dev.zed.Zed",                    // Zed
        "com.google.antigravity",         // Antigravity
        "com.anthropic.claudefordesktop", // Claude
        "com.openai.codex",               // ChatGPT (hosts Codex and computer use)
        "io.tailscale.ipn.macsys",        // Tailscale
        "ai.elementlabs.lmstudio",        // LM Studio
        "com.electron.ollama",            // Ollama
    ]
}

// MARK: Battery floors

extension InsomniaConfig {
    /// Settings step for both floors; the floors are kept at least one step
    /// apart.
    static let floorStep = 5
    /// Highest end floor Settings offers: one step below a 100% Low Power
    /// Mode floor.
    static let maxEndFloor = 100 - floorStep

    /// A non-zero end floor sits below the Low Power Mode floor, so the mode
    /// gets its chance before the end.
    var floorsAreOrdered: Bool { endFloor == 0 || endFloor < lowPowerFloor }

    /// Sets the end floor (0...`maxEndFloor`) and raises the Low Power Mode
    /// floor one step above it when it would otherwise not be above it.
    mutating func setEndFloor(_ value: Int) {
        endFloor = min(max(value, 0), InsomniaConfig.maxEndFloor)
        if endFloor > 0, lowPowerFloor <= endFloor {
            lowPowerFloor = min(endFloor + InsomniaConfig.floorStep, 100)
        }
    }

    /// Sets the Low Power Mode floor (0...100) and lowers the end floor one
    /// step below it when it would otherwise not be below it. An end floor
    /// pushed to 0 is off.
    mutating func setLowPowerFloor(_ value: Int) {
        lowPowerFloor = min(max(value, 0), 100)
        if endFloor > 0, endFloor >= lowPowerFloor {
            endFloor = max(lowPowerFloor - InsomniaConfig.floorStep, 0)
        }
    }

    /// Clamps both floors to their ranges and restores the order by raising
    /// the Low Power Mode floor, never by lowering the end the user asked
    /// for. Returns a description of the change for the log, or nil when
    /// nothing changed. Run on a config.json that Settings did not write.
    mutating func normalizeFloors() -> String? {
        let before = (lowPowerFloor, endFloor)
        lowPowerFloor = min(max(lowPowerFloor, 0), 100)
        endFloor = min(max(endFloor, 0), InsomniaConfig.maxEndFloor)
        if !floorsAreOrdered {
            lowPowerFloor = min(endFloor + InsomniaConfig.floorStep, 100)
        }
        guard (lowPowerFloor, endFloor) != before else { return nil }
        return "battery floors corrected: lowPowerFloor \(before.0) -> \(lowPowerFloor), endFloor \(before.1) -> \(endFloor)"
    }
}
