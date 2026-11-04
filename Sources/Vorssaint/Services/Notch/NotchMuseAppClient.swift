// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// The island's Muse page, carried by the Muse for Mac app. Muse keeps the
/// conversation; the island reads it from Muse's window as it changes, and
/// sends by bringing Muse forward for a moment, pasting into its message
/// field and pressing Return, then going back to where the person was.
/// Muse draws that field natively, out of every other app's reach, so typing
/// into it is the only way in (`MuseAppSupport` explains the window).
///
/// Like the other transports nothing here touches the island's state: events
/// arrive on the main thread and the service decides what they mean.
final class NotchMuseAppClient: NotchAgentChatTransport {
    typealias Event = NotchHermesChatClient.Event
    typealias Support = MuseAppSupport

    private let onEvent: (Event) -> Void
    /// Called after a send that started in this app (the island), to put
    /// the island back on Muse's page once Muse has gone back behind.
    private let returnToIsland: () -> Void
    /// When each message already shown was first seen, so reading the thread
    /// again keeps it in place.
    private let known: [UUID: Date]
    private var tracker = Support.Tracker()
    /// How many of each message (by its words) the conversation holds, so an
    /// equal message later gets an identity of its own.
    private var counts: [String: Int] = [:]
    private var problem: Support.Problem?
    private var connected = false
    /// Words sent from here that Muse has not shown back yet.
    private var sent: [String] = []
    private var awaitingSince: Date?
    private var queue: [(text: String, files: [URL])] = []
    private var sending = false
    private var timer: Timer?
    private var lastRead = Date.distantPast
    private var dirty = true
    private var observer: AXObserver?
    private var observedPID: pid_t = 0
    private var launched = false
    private var ended = false

    init(history: [NotchHermesChatMessage], returnToIsland: @escaping () -> Void,
         onEvent: @escaping (Event) -> Void) {
        known = Dictionary(history.map { ($0.id, $0.date) }, uniquingKeysWith: { first, _ in first })
        self.returnToIsland = returnToIsland
        self.onEvent = onEvent
    }

    deinit { stopWatching() }

    func start() {
        read()
        let timer = Timer(timeInterval: Support.activePoll, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func send(_ text: String) {
        send(text, attachments: [])
    }

    func send(_ text: String, attachments: [URL]) {
        sent.append(text)
        if sent.count > 20 { sent.removeFirst(sent.count - 20) }
        awaitingSince = Date()
        queue.append((text, attachments))
        pump()
    }

    /// Muse's Stop is part of its native field, which nothing else can press;
    /// the island stops waiting, and whatever Muse still writes arrives as
    /// its own message.
    func cancel() {
        guard awaitingSince != nil else { return }
        awaitingSince = nil
        emit(.finished(.cancelled))
    }

    func end() {
        ended = true
        stopWatching()
    }

    /// Muse asks its questions in its own window.
    func answer(_ approval: String, choice: NotchAgentApproval.Choice) {}

    // MARK: Reading

    private func tick() {
        guard !ended else { return }
        let active = awaitingSince != nil || tracker.isWriting
        let interval = active ? Support.activePoll : Support.idlePoll
        if dirty || Date().timeIntervalSince(lastRead) >= interval { read() }
        if let since = awaitingSince, Date().timeIntervalSince(since) > Support.answerTimeout {
            awaitingSince = nil
            emit(.finished(.endTurn))
        }
    }

    private func read() {
        guard !ended, !sending else { return }
        dirty = false
        lastRead = Date()
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: Support.bundleIdentifier) != nil
        else { return report(.notInstalled) }
        guard AXIsProcessTrusted() else { return report(.needsAccessibility) }
        guard let muse = Self.muse() else {
            launchMuse()
            return report(.noWindow)
        }
        watch(muse.processIdentifier)
        let app = AXUIElementCreateApplication(muse.processIdentifier)
        guard let window = Self.window(of: app) else { return report(.noWindow) }
        guard let log = Self.find(in: window, depth: 0, where: {
            Self.string($0, kAXSubroleAttribute) == Support.logSubrole
        }) else { return report(.noConversation) }

        let children = Self.children(log)
        if !connected || !tracker.started {
            let rows = Support.rows(in: children.map { Self.node($0, depth: 0) })
            counts = rows.reduce(into: [:]) { $0[Support.key($1), default: 0] += 1 }
            let thread = Support.thread(tracker.begin(rows), known: known, now: Date())
            problem = nil
            connected = true
            emit(.ready(agent: "MUSE", model: nil))
            emit(.thread(thread))
            emit(.session)
            return
        }
        if problem != nil {
            problem = nil
            emit(.session)
        }
        let tail = Support.rows(in: children.suffix(Support.tailLength).map { Self.node($0, depth: 0) })
        for change in tracker.changes(tail, now: Date()) {
            switch change {
            case .delivered(let row):
                var row = row
                if let words = Support.echo(of: row.text, among: sent) {
                    sent.removeAll { $0 == words }
                    row.text = words
                }
                emit(.delivered(message(row)))
            case .streaming(let words):
                emit(.text(words))
            case .received(let row):
                awaitingSince = nil
                emit(.received(message(row)))
            }
        }
    }

    private func message(_ row: Support.Row) -> NotchHermesChatMessage {
        let key = Support.key(row)
        let earlier = counts[key, default: 0]
        counts[key] = earlier + 1
        return Support.message(row, earlier: earlier, date: Date())
    }

    private func report(_ problem: Support.Problem) {
        connected = false
        guard self.problem != problem else { return }
        self.problem = problem
        emit(.museProblem(problem))
    }

    /// Muse opens behind the person's work the first time it is needed.
    private func launchMuse() {
        guard !launched, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Support.bundleIdentifier)
        else { return }
        launched = true
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] _, _ in
            DispatchQueue.main.async { self?.dirty = true }
        }
    }

    // MARK: Sending

    private func pump() {
        guard !sending, !ended, let next = queue.first else { return }
        queue.removeFirst()
        guard AXIsProcessTrusted(), let muse = Self.muse() else {
            awaitingSince = nil
            let missing: Support.Problem = AXIsProcessTrusted() ? .noWindow : .needsAccessibility
            emit(.museProblem(missing))
            emit(.turnFailed(MuseAppSupport.sendFailed))
            return pump()
        }
        sending = true
        let previous = NSWorkspace.shared.frontmostApplication
        let fromHere = previous?.processIdentifier == ProcessInfo.processInfo.processIdentifier
        let mouse = CGEvent(source: nil)?.location
        bringForward(muse) { [weak self] composer in
            guard let self else { return }
            guard let composer else {
                self.finishSending(previous: previous, fromHere: fromHere, mouse: mouse,
                                   failure: MuseAppSupport.sendFailed)
                return
            }
            Self.click(at: CGPoint(x: composer.midX, y: composer.midY))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.pasteFiles(next.files) {
                    self.pasteText(next.text) { pasted in
                        guard pasted else {
                            self.finishSending(previous: previous, fromHere: fromHere, mouse: mouse,
                                               failure: MuseAppSupport.sendFailed)
                            return
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            Self.press(kVK_Return)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                self.finishSending(previous: previous, fromHere: fromHere, mouse: mouse, failure: nil)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Muse in front with its window raised, and where its message field is.
    private func bringForward(_ muse: NSRunningApplication, then: @escaping (CGRect?) -> Void) {
        let app = AXUIElementCreateApplication(muse.processIdentifier)
        muse.unhide()
        if let window = Self.window(of: app) {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
        AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        ActivationHandoff.yield(to: muse)
        if !muse.activate(from: NSRunningApplication.current, options: []) {
            muse.activate(options: [])
        }
        func check(_ attempt: Int) {
            let front = NSWorkspace.shared.frontmostApplication?.processIdentifier == muse.processIdentifier
            if front || attempt >= 30 {
                guard front, let window = Self.window(of: app),
                      let field = Self.find(in: window, depth: 0, where: { Support.isComposer(Self.node($0, depth: .max)) })
                else { return then(nil) }
                let frame = Self.frame(field)
                return then(frame.isEmpty ? nil : frame)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { check(attempt + 1) }
        }
        check(0)
    }

    /// Files go first, pasted into Muse's field the way a copied file is,
    /// and the clipboard is put back before the words go in.
    private func pasteFiles(_ files: [URL], then: @escaping () -> Void) {
        guard !files.isEmpty else { return then() }
        let pasteboard = NSPasteboard.general
        GeneralPasteboardAccess.shared.async({ () -> ([NSPasteboardItem], Int) in
            let saved = (pasteboard.pasteboardItems ?? []).map { item -> NSPasteboardItem in
                let copy = NSPasteboardItem()
                for type in item.types { if let data = item.data(forType: type) { copy.setData(data, forType: type) } }
                return copy
            }
            pasteboard.clearContents()
            pasteboard.writeObjects(files as [NSURL])
            return (saved, pasteboard.changeCount)
        }, then: { saved, count in
            ClipboardHistoryService.shared.ignoreNextChange(upTo: count)
            Self.press(kVK_ANSI_V, flags: .maskCommand)
            // Muse reads the files before the clipboard changes again.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                GeneralPasteboardAccess.shared.async({ () -> Int in
                    pasteboard.clearContents()
                    if !saved.isEmpty { pasteboard.writeObjects(saved) }
                    return pasteboard.changeCount
                }, then: { restored in
                    ClipboardHistoryService.shared.ignoreNextChange(upTo: restored)
                    then()
                })
            }
        })
    }

    private func pasteText(_ text: String, then: @escaping (Bool) -> Void) {
        guard !text.isEmpty else { return then(true) }
        let started = TransientPaste.shared.paste(text, didPostShortcut: { then(true) }, didFail: { then(false) })
        if !started { then(false) }
    }

    /// Back to the app the person was in, the pointer where it was, and the
    /// island's Muse page if that is where the message was typed.
    private func finishSending(previous: NSRunningApplication?, fromHere: Bool, mouse: CGPoint?, failure: String?) {
        if let mouse { CGWarpMouseCursorPosition(mouse) }
        if fromHere {
            NSApp.activate()
            returnToIsland()
        } else if let previous {
            ActivationHandoff.yield(to: previous)
            if !previous.activate(from: NSRunningApplication.current, options: []) {
                previous.activate(options: [])
            }
        }
        sending = false
        dirty = true
        if let failure {
            awaitingSince = nil
            emit(.turnFailed(failure))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.pump() }
    }

    private func emit(_ event: Event) {
        guard !ended else { return }
        onEvent(event)
    }

    // MARK: Watching

    /// Muse's chat log is a live region: WebKit says when it changes, and the
    /// window is read then rather than on a fast clock.
    private func watch(_ pid: pid_t) {
        guard observedPID != pid else { return }
        stopWatching(keepTimer: true)
        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let client = Unmanaged<NotchMuseAppClient>.fromOpaque(refcon).takeUnretainedValue()
            client.dirty = true
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return }
        let app = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in ["AXLiveRegionChanged", "AXLiveRegionCreated", kAXValueChangedNotification,
                     kAXCreatedNotification, kAXWindowCreatedNotification, kAXUIElementDestroyedNotification] {
            AXObserverAddNotification(created, app, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        observedPID = pid
    }

    private func stopWatching(keepTimer: Bool = false) {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        observedPID = 0
        if !keepTimer {
            timer?.invalidate()
            timer = nil
        }
    }

    // MARK: Accessibility

    private static func muse() -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: Support.bundleIdentifier)
            .first { !$0.isTerminated }
    }

    private static func window(of app: AXUIElement) -> AXUIElement? {
        let windows = (value(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
        return windows.first { string($0, kAXSubroleAttribute) == kAXStandardWindowSubrole as String } ?? windows.first
    }

    private static func value(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return value
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String {
        value(element, attribute) as? String ?? ""
    }

    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        value(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    private static func find(in element: AXUIElement, depth: Int,
                             where matches: (AXUIElement) -> Bool) -> AXUIElement? {
        if matches(element) { return element }
        guard depth < 40 else { return nil }
        for child in children(element) {
            if let found = find(in: child, depth: depth + 1, where: matches) { return found }
        }
        return nil
    }

    /// An element and what is under it, as far as telling messages apart
    /// needs to look.
    private static func node(_ element: AXUIElement, depth: Int) -> Support.Node {
        let role = string(element, kAXRoleAttribute)
        var node = Support.Node(role: role)
        node.subrole = string(element, kAXSubroleAttribute)
        node.classes = value(element, "AXDOMClassList") as? [String] ?? []
        node.title = string(element, kAXTitleAttribute)
        if role == "AXStaticText" { node.value = string(element, kAXValueAttribute) }
        // Past this depth only the element itself is read (`.max`: just it).
        if depth < 14, role != "AXStaticText" {
            node.children = children(element).prefix(80).map { self.node($0, depth: depth + 1) }
        }
        return node
    }

    private static func frame(_ element: AXUIElement) -> CGRect {
        var origin = CGPoint.zero, size = CGSize.zero
        if let position = value(element, kAXPositionAttribute) { AXValueGetValue(position as! AXValue, .cgPoint, &origin) }
        if let extent = value(element, kAXSizeAttribute) { AXValueGetValue(extent as! AXValue, .cgSize, &size) }
        return CGRect(origin: origin, size: size)
    }

    private static func click(at point: CGPoint) {
        let source = CGEventSource(stateID: .combinedSessionState)
        CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point,
                mouseButton: .left)?.post(tap: .cghidEventTap)
        CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point,
                mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    private static func press(_ key: Int, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(key), keyDown: down)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
    }
}
