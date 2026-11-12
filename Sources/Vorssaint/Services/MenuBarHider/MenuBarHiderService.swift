// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices

/// Hides the menu bar items left of an arrow and shows them again on click.
///
/// macOS 27 ejects a status item that grows too wide, which is how every older
/// hider pushed icons off screen. This asks macOS itself to hide them through
/// the visibility restriction behind assessment mode, so the result does not
/// depend on display width or the notch. The restriction is an allow-list,
/// held only while this process lives: if Dynamai quits or crashes, macOS
/// drops it and the whole bar comes back by itself.
///
/// ⌘-drag decides what hides: anything left of the arrow (in a left-to-right
/// bar). The sides are read through Accessibility, and only from an
/// unrestricted bar, because hidden items report stale positions.
///
/// Nothing runs while the feature is off: no status item, no observers.
final class MenuBarHiderService: ObservableObject {
    static let shared = MenuBarHiderService()

    /// The restriction exists from macOS 27 and only as private API, so it is
    /// resolved once and checked rather than assumed.
    static let isSupported: Bool = {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
            && NativeMenuBarVisibility.isAvailable
    }()

    private static let arrowAutosaveName = "dynamai.menuBarHider.arrow"

    enum State {
        case expanded
        case collapsing
        case collapsed
    }

    @Published private(set) var state: State = .expanded
    @Published private(set) var isRunning = false

    private var arrow: NSStatusItem?
    private var assertion: NSObject?
    /// Bumped whenever a collapse in flight must no longer win.
    private var generation = 0
    private var isLearning = false

    private init() {}

    func syncWithPreferences() {
        guard Self.isSupported else { return }
        if AppFeature.menuBarHider.isAvailable,
           UserDefaults.standard.bool(forKey: DefaultsKey.menuBarHiderEnabled) {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        guard arrow == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = Self.arrowAutosaveName
        // Removable by ⌘-drag would orphan the feature; the switch removes it.
        item.behavior = []
        arrow = item
        item.isVisible = true
        if let button = item.button {
            button.target = self
            button.action = #selector(arrowClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.identifier = NSUserInterfaceItemIdentifier(Self.arrowAutosaveName)
        }
        isRunning = true
        updateArrow()
        // Other apps' items appear during login; collapsing straight away
        // would read a half-built bar.
        let generation = self.generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.arrow != nil, generation == self.generation,
                  self.state == .expanded, AXIsProcessTrusted() else { return }
            self.collapse()
        }
    }

    func stop() {
        expand()
        if let arrow {
            NSStatusBar.system.removeStatusItem(arrow)
        }
        arrow = nil
        isRunning = false
    }

    @objc private func arrowClicked(_ sender: NSStatusBarButton) {
        toggle()
    }

    func toggle() {
        switch state {
        case .expanded: collapse()
        case .collapsing, .collapsed: expand()
        }
    }

    func expand() {
        generation += 1
        releaseAssertion()
        state = .expanded
        updateArrow()
    }

    func collapse() {
        guard arrow != nil, state == .expanded, !isLearning else { return }
        guard AXIsProcessTrusted() else {
            // Without Accessibility the sides cannot be read, and guessing
            // would hide icons the user kept visible.
            Permissions.shared.requestAccessibility()
            return
        }
        guard let arrowFrame = arrow?.button?.window?.frame else { return }
        generation += 1
        let generation = self.generation
        state = .collapsing
        updateArrow()
        let isLeftToRight = NSApp.userInterfaceLayoutDirection == .leftToRight
        let ownBundle = Bundle.main.bundleIdentifier
        MenuBarItemInventory.snapshot { [weak self] items in
            guard let self, generation == self.generation else { return }
            let layout = MenuBarHiderSupport.layout(of: items, arrowFrame: arrowFrame,
                                                    isLeftToRight: isLeftToRight, ownBundle: ownBundle)
            self.learnNumbersIfNeeded(for: layout.hiddenSystemItems) { [weak self] in
                guard let self, generation == self.generation else { return }
                self.activate(layout: layout, generation: generation)
            }
        }
    }

    private func activate(layout: MenuBarHiderSupport.Layout, generation: Int) {
        let bundles = MenuBarHiderSupport.allowedBundles(ownBundle: Bundle.main.bundleIdentifier,
                                                         layout: layout,
                                                         runningBundles: Self.runningBundles())
        let systemItems = MenuBarHiderSupport.allowedSystemItems(hiding: layout.hiddenSystemItems,
                                                                 numbers: SystemItemNumbers.numbers)
        NativeMenuBarVisibility.activate(systemItems: systemItems, bundles: bundles) { [weak self] newAssertion in
            guard let self, generation == self.generation, let newAssertion else {
                // Superseded by an expand, or refused: never leave icons hidden.
                if let newAssertion { NativeMenuBarVisibility.invalidate(newAssertion) }
                if let self, generation == self.generation {
                    self.state = .expanded
                    self.updateArrow()
                }
                return
            }
            self.releaseAssertion()
            self.assertion = newAssertion
            self.state = .collapsed
            self.updateArrow()
        }
    }

    private func releaseAssertion() {
        if let assertion {
            NativeMenuBarVisibility.invalidate(assertion)
        }
        assertion = nil
    }

    private func updateArrow() {
        guard let button = arrow?.button else { return }
        let leftToRight = NSApp.userInterfaceLayoutDirection == .leftToRight
        // Points at where the hidden icons will come from.
        let pointsOut = (state == .expanded) == leftToRight
        let strings = FeatureStrings.menuBarHider(L10n.shared.language)
        let label = state == .expanded ? strings.hideItems : strings.showItems
        button.image = NSImage(systemSymbolName: pointsOut ? "chevron.right" : "chevron.left",
                               accessibilityDescription: label)
        button.image?.isTemplate = true
        button.toolTip = label
    }

    private static func runningBundles() -> [String] {
        NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
    }

    // MARK: Learning system item numbers

    /// Runs the learning rounds from `MenuBarHiderSupport` when an item on
    /// the hidden side has no known number yet. Every app stays allowed while
    /// learning, so only macOS's own items flicker, once per macOS build.
    private func learnNumbersIfNeeded(for identifiers: Set<String>, completion: @escaping () -> Void) {
        let unknown = MenuBarHiderSupport.needsLearning(identifiers, numbers: SystemItemNumbers.numbers,
                                                        uncontrollable: SystemItemNumbers.uncontrollable)
        guard !unknown.isEmpty, assertion == nil else { return completion() }
        isLearning = true
        let bundles = MenuBarHiderSupport.allowedBundles(ownBundle: Bundle.main.bundleIdentifier,
                                                         layout: .init(), runningBundles: Self.runningBundles())
        runRound(0, rounds: MenuBarHiderSupport.learningRounds, bundles: bundles, seen: []) { [weak self] seen in
            self?.isLearning = false
            if let seen {
                let learned = MenuBarHiderSupport.decode(seen: seen, wanted: unknown)
                SystemItemNumbers.record(learned.numbers, uncontrollable: learned.uncontrollable)
            }
            completion()
        }
    }

    private func runRound(_ index: Int, rounds: [[Int]], bundles: [String], seen: [Set<String>],
                          completion: @escaping ([Set<String>]?) -> Void) {
        guard index < rounds.count else { return completion(seen) }
        NativeMenuBarVisibility.activate(systemItems: rounds[index], bundles: bundles) { [weak self] roundAssertion in
            guard let self, let roundAssertion else { return completion(nil) }
            // The bar reflows a moment after the restriction lands.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                MenuBarItemInventory.systemIdentifiers { present in
                    NativeMenuBarVisibility.invalidate(roundAssertion)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        self?.runRound(index + 1, rounds: rounds, bundles: bundles,
                                       seen: seen + [present], completion: completion)
                    }
                }
            }
        }
    }
}

/// Learned system item numbers, kept per macOS build. They describe this Mac
/// only, so settings backup leaves them out.
private enum SystemItemNumbers {
    private static var build: String { ProcessInfo.processInfo.operatingSystemVersionString }

    static var numbers: [String: Int] {
        let defaults = UserDefaults.standard
        return MenuBarHiderSupport.storedNumbers(
            defaults.dictionary(forKey: DefaultsKey.menuBarHiderSystemItemNumbers) as? [String: Int],
            storedBuild: defaults.string(forKey: DefaultsKey.menuBarHiderSystemItemBuild),
            currentBuild: build)
    }

    static var uncontrollable: Set<String> {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: DefaultsKey.menuBarHiderSystemItemBuild) == build else { return [] }
        return Set(defaults.stringArray(forKey: DefaultsKey.menuBarHiderUncontrollableItems) ?? [])
    }

    static func record(_ learned: [String: Int], uncontrollable newUncontrollable: Set<String>) {
        let defaults = UserDefaults.standard
        let merged = numbers.merging(learned) { $1 }
        let skipped = uncontrollable.union(newUncontrollable).subtracting(learned.keys)
        defaults.set(merged, forKey: DefaultsKey.menuBarHiderSystemItemNumbers)
        defaults.set(skipped.sorted(), forKey: DefaultsKey.menuBarHiderUncontrollableItems)
        defaults.set(build, forKey: DefaultsKey.menuBarHiderSystemItemBuild)
    }
}

/// Lists other processes' status items through public Accessibility API:
/// each app's AXExtrasMenuBar children, with the owner's bundle identifier.
private enum MenuBarItemInventory {
    /// A busy app would otherwise stall the walk for seconds. One that times
    /// out is simply missing, and missing apps stay visible.
    private static let messagingTimeout: Float = 0.1

    static func snapshot(completion: @escaping ([MenuBarHiderSupport.Item]) -> Void) {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        // Only app bundles own status items; skipping the dozens of helpers
        // keeps the walk near a second.
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.processIdentifier != ownPID && $0.bundleURL?.pathExtension == "app" }
            .map { ($0.processIdentifier, $0.bundleIdentifier) }
        DispatchQueue.global(qos: .userInitiated).async {
            let items = statusItems(of: apps)
            DispatchQueue.main.async { completion(items) }
        }
    }

    /// Only the system item owners, so it is quick enough to repeat while
    /// learning numbers.
    static func systemIdentifiers(completion: @escaping (Set<String>) -> Void) {
        let apps = NSWorkspace.shared.runningApplications
            .filter { MenuBarHiderSupport.systemItemOwners.contains($0.bundleIdentifier ?? "") }
            .map { ($0.processIdentifier, $0.bundleIdentifier) }
        DispatchQueue.global(qos: .userInitiated).async {
            let identifiers = Set(statusItems(of: apps).compactMap(\.systemIdentifier))
            DispatchQueue.main.async { completion(identifiers) }
        }
    }

    private static func statusItems(of apps: [(pid_t, String?)]) -> [MenuBarHiderSupport.Item] {
        var items: [MenuBarHiderSupport.Item] = []
        for (pid, bundle) in apps {
            let application = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(application, messagingTimeout)
            guard let bar: AXUIElement = attribute(application, "AXExtrasMenuBar"),
                  let children: [AXUIElement] = attribute(bar, kAXChildrenAttribute) else { continue }
            let isSystemOwner = MenuBarHiderSupport.systemItemOwners.contains(bundle ?? "")
            for child in children {
                guard let frame = frame(of: child) else { continue }
                items.append(.init(bundleIdentifier: bundle, frame: frame,
                                   systemIdentifier: isSystemOwner ? menuExtraIdentifier(of: child) : nil))
            }
        }
        return items
    }

    /// macOS 27 wraps each system item in a group; the menu bar item inside
    /// carries the identifier.
    private static func menuExtraIdentifier(of element: AXUIElement) -> String? {
        let inner: [AXUIElement] = attribute(element, kAXChildrenAttribute) ?? []
        for candidate in [element] + inner {
            if let identifier: String = attribute(candidate, kAXIdentifierAttribute), !identifier.isEmpty {
                return identifier
            }
        }
        return nil
    }

    private static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    /// Only horizontal positions matter, and x is the same in Accessibility's
    /// top-left coordinates and AppKit's bottom-left ones.
    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }
}

/// MenuBarClientCore's assessment mode restriction, reached at runtime so a
/// macOS that changes or drops it makes the feature unsupported instead of
/// breaking the launch.
private enum NativeMenuBarVisibility {
    private static let frameworkPath = "/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore"
    private static let configurationInit = NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:")
    private static let activateSelector = NSSelectorFromString("activateWithConfiguration:completionHandler:")
    private static let invalidateSelector = NSSelectorFromString("invalidate")

    private static var configurationClass: AnyClass? { NSClassFromString("MBAssessmentModeConfiguration") }
    private static var assertionClass: AnyClass? { NSClassFromString("MBAssessmentModeAssertion") }

    static let isAvailable: Bool = {
        guard dlopen(frameworkPath, RTLD_NOW | RTLD_LOCAL) != nil,
              let configuration = configurationClass, let assertion = assertionClass else { return false }
        return class_respondsToSelector(configuration, configurationInit)
            && class_respondsToSelector(assertion, activateSelector)
            && class_respondsToSelector(assertion, invalidateSelector)
    }()

    private typealias AllocFunction = @convention(c) (AnyClass, Selector) -> OpaquePointer?
    private typealias ConfigurationInitFunction =
        @convention(c) (OpaquePointer, Selector, NSArray, NSArray) -> Unmanaged<NSObject>?
    private typealias ActivateFunction =
        @convention(c) (NSObject, Selector, NSObject, @escaping @convention(block) (NSError?) -> Void) -> Void

    /// Keeps only these system items and apps on screen. The completion runs
    /// on the main queue with the held assertion, or nil when it failed.
    /// Both lists must be arrays: the framework indexes into them.
    static func activate(systemItems: [Int], bundles: [String], completion: @escaping (NSObject?) -> Void) {
        guard isAvailable, let configurationClass, let assertionClass = assertionClass as? NSObject.Type,
              let allocMethod = class_getClassMethod(configurationClass, NSSelectorFromString("alloc")),
              let initMethod = class_getInstanceMethod(configurationClass, configurationInit),
              let activateMethod = class_getInstanceMethod(assertionClass, activateSelector) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        // alloc returns +1 and init consumes it, so the raw pointer is handed
        // straight through without Swift retaining it in between.
        let alloc = unsafeBitCast(method_getImplementation(allocMethod), to: AllocFunction.self)
        let initialize = unsafeBitCast(method_getImplementation(initMethod), to: ConfigurationInitFunction.self)
        guard let raw = alloc(configurationClass, NSSelectorFromString("alloc")),
              let configuration = initialize(raw, configurationInit,
                                             systemItems.map { NSNumber(value: $0) } as NSArray,
                                             bundles as NSArray)?.takeRetainedValue() else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let assertion = assertionClass.init()
        let activate = unsafeBitCast(method_getImplementation(activateMethod), to: ActivateFunction.self)
        activate(assertion, activateSelector, configuration) { error in
            DispatchQueue.main.async { completion(error == nil ? assertion : nil) }
        }
    }

    static func invalidate(_ assertion: NSObject) {
        guard assertion.responds(to: invalidateSelector) else { return }
        assertion.perform(invalidateSelector)
    }
}
