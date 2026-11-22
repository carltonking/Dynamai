// SPDX-License-Identifier: MIT
// Hidden Bar, Copyright (c) 2019 Dwarves Foundation, (c) 2026 Console Labs.
// Ported into Dynamai: what Hidden Bar's AppDelegate did at launch, as a
// feature Dynamai switches on and off. See LICENSE-HiddenBar.txt.

import AppKit

/// Hidden Bar, built into Dynamai: the arrow, the sections, the shortcuts and
/// every one of Hidden Bar's own windows, run inside this app instead of as a
/// second one. Dynamai already starts at login and updates itself, so Hidden
/// Bar's login item, single-instance check, App Store import and Sparkle
/// updater are left out.
final class HiddenBarFeature {
    static let shared = HiddenBarFeature()

    private(set) var statusBarController: StatusBarController?
    private var hotKeysRegistered = false
    private var hotKeys: HotKeyRegistry { HotKeyRegistry.shared }

    private init() {}

    var isRunning: Bool { statusBarController != nil }

    func syncWithPreferences() {
        if AppFeature.menuBarHider.isAvailable,
           UserDefaults.standard.bool(forKey: DefaultsKey.menuBarHiderEnabled) {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        guard statusBarController == nil else { return }
        #if HIDDENBAR_NATIVE_VISIBILITY
        if MenuBarEngineFactory.usesNativeEngine() {
            MenuBarAppsPane.makeViewController = { MenuBarAppsSettingsViewController(context: .live) }
        }
        #endif
        AppDefaults.store.register(defaults: Self.defaultPreferenceValues)
        Constant.isUsingLTRLanguage = NSApplication.shared.userInterfaceLayoutDirection == .leftToRight
        statusBarController = StatusBarController()
        registerHotKeys()
        if Preferences.isShowPreference {
            Util.showPrefWindow()
        }
    }

    private func stop() {
        guard let controller = statusBarController else { return }
        for key in Self.hotKeyNames { hotKeys.unregister(key: key) }
        hotKeysRegistered = false
        controller.shutDown()
        statusBarController = nil
    }

    /// Hidden Bar's settings window, from Dynamai's settings.
    func showSettings() {
        guard isRunning else { return }
        Util.showPrefWindow()
    }

    // MARK: Launch, as Hidden Bar's AppDelegate did it

    static let defaultPreferenceValues: [String: Any] = [
        UserDefaults.Key.isAutoStart: false,
        UserDefaults.Key.isShowPreference: true,
        UserDefaults.Key.isAutoHide: true,
        UserDefaults.Key.numberOfSecondForAutoHide: 10.0,
        UserDefaults.Key.areSeparatorsHidden: false,
        UserDefaults.Key.alwaysHiddenSectionEnabled: false,
        UserDefaults.Key.notchOverflowEnabled: true,
        UserDefaults.Key.stealthExpandIconEnabled: false,
        UserDefaults.Key.arrowStyle: ArrowStyle.default.rawValue,
        UserDefaults.Key.showWholeBarWhenCaptureStarts: true,
        UserDefaults.Key.pinnedSectionsEnabled: true,
    ]

    private static let hotKeyNames = [UserDefaults.Key.globalKey, UserDefaults.Key.findHiddenIconShortcut,
                                      UserDefaults.Key.presentationShortcut]

    private func registerHotKeys() {
        guard !hotKeysRegistered else { return }
        hotKeysRegistered = true
        hotKeys.register(key: UserDefaults.Key.globalKey, title: "Show or hide icons".localized) { [weak self] in
            self?.statusBarController?.expandCollapseIfNeeded()
        }
        #if HIDDENBAR_NATIVE_VISIBILITY
        guard MenuBarEngineFactory.usesNativeEngine() else { return }
        hotKeys.register(key: UserDefaults.Key.findHiddenIconShortcut, title: "Find a hidden icon".localized) { [weak self] in
            self?.statusBarController?.togglePalette()
        }
        hotKeys.register(key: UserDefaults.Key.presentationShortcut, title: "Presentation mode".localized) { [weak self] in
            self?.statusBarController?.togglePresentationMode()
        }
        #endif
    }
}

extension HotKeyRegistry {
    static let shared = HotKeyRegistry { combo, handler in
        let hotKey = HotKey(keyCombo: KeyCombo(carbonKeyCode: combo.keyCode, carbonModifiers: combo.carbonFlags))
        hotKey.keyDownHandler = handler
        return hotKey
    }
}
