// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import OSLog
import UniformTypeIdentifiers
import WebKit

/// The island's Muse page, carried by Muse's own website (muse.ai) running in
/// a page this app keeps out of sight. The Muse app is never opened or
/// brought forward: the page signs in once (in a window of this app, the
/// first time) and from then on reading and sending happen inside it.
///
/// The website draws the same conversation the Muse app does, so the page's
/// chat log is turned into the `MuseAppSupport.Node` tree Accessibility would
/// give for it, and everything `MuseAppSupport` knows about Muse's messages
/// applies unchanged. Unlike the app, the website's message field is part of
/// the page, so a message is put in and sent from script, wherever the person
/// is working.
///
/// Like the other transports nothing here touches the island's state: events
/// arrive on the main thread and the service decides what they mean.
final class NotchMuseWebClient: NotchAgentChatTransport {
    typealias Event = NotchHermesChatClient.Event
    typealias Support = MuseAppSupport

    private let onEvent: (Event) -> Void
    private let known: [UUID: Date]
    private var tracker = Support.Tracker()
    private var counts: [String: Int] = [:]
    private var problem: Support.Problem?
    private var connected = false
    private var sent: [String] = []
    private var awaitingSince: Date?
    private var queue: [(text: String, files: [URL])] = []
    private var sending = false
    private var reading = false
    private var timer: Timer?
    private var lastRead = Date.distantPast
    private var dirty = true
    /// A message is waiting for the page to sign in or load.
    private var waitingSince: Date?
    private var ended = false

    init(history: [NotchHermesChatMessage], onEvent: @escaping (Event) -> Void) {
        known = Dictionary(history.map { ($0.id, $0.date) }, uniquingKeysWith: { first, _ in first })
        self.onEvent = onEvent
    }

    deinit { timer?.invalidate() }

    func start() {
        MainActor.assumeIsolated {
            MuseWebSession.shared.onChange = { [weak self] in self?.dirty = true }
            MuseWebSession.shared.load()
        }
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

    /// The website's Stop stays on Muse's side; the island stops waiting, and
    /// whatever Muse still writes arrives as its own message.
    func cancel() {
        guard awaitingSince != nil else { return }
        awaitingSince = nil
        emit(.finished(.cancelled))
    }

    func end() {
        ended = true
        timer?.invalidate()
        timer = nil
        MainActor.assumeIsolated { MuseWebSession.shared.onChange = nil }
    }

    /// Muse asks its questions on its own page (`MuseWebSession.show`).
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
        guard !ended, !sending, !reading else { return }
        dirty = false
        lastRead = Date()
        reading = true
        let whole = !connected || !tracker.started
        MainActor.assumeIsolated {
            MuseWebSession.shared.snapshot(tail: whole ? 0 : Support.tailLength) { [weak self] result in
                guard let self else { return }
                self.reading = false
                self.handle(result, whole: whole)
            }
        }
    }

    private func handle(_ result: MuseWebSession.Snapshot, whole: Bool) {
        guard !ended else { return }
        if case .log(let nodes) = result {
            let rows = Support.rows(in: nodes)
            MuseWebSession.log.info("Muse read \(whole ? "whole" : "tail", privacy: .public): \(nodes.count) items, \(rows.filter { $0.author == .person }.count) mine, \(rows.filter { $0.author == .muse }.count) Muse's")
        } else {
            MuseWebSession.log.info("Muse read: \(String(describing: result), privacy: .public)")
        }
        let children: [Support.Node]
        switch result {
        case .loading:
            return
        case .offline:
            return report(.noWindow)
        case .signedOut:
            return report(.noConversation)
        case .log(let nodes):
            children = nodes
        }
        if whole || !connected || !tracker.started {
            let rows = Support.rows(in: children)
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
        let tail = Support.rows(in: Array(children.suffix(Support.tailLength)))
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

    // MARK: Sending

    private func pump() {
        guard !sending, !ended, let next = queue.first else { return }
        // Signed out or still loading: the message waits for the page rather
        // than failing at once, so signing in finishes the send.
        guard connected else {
            let since = waitingSince ?? Date()
            waitingSince = since
            guard Date().timeIntervalSince(since) < Support.openWait else {
                waitingSince = nil
                queue.removeFirst()
                awaitingSince = nil
                emit(.turnFailed(MuseAppSupport.sendFailed))
                return pump()
            }
            dirty = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.pump() }
            return
        }
        waitingSince = nil
        queue.removeFirst()
        sending = true
        MainActor.assumeIsolated {
            MuseWebSession.shared.send(next.text, files: next.files) { [weak self] failure in
                guard let self else { return }
                self.sending = false
                self.dirty = true
                if let failure {
                    self.awaitingSince = nil
                    self.emit(.turnFailed(failure))
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.pump() }
            }
        }
    }

    private func emit(_ event: Event) {
        guard !ended else { return }
        onEvent(event)
    }
}

/// The muse.ai page this app keeps for the island, signed in with the
/// person's own Muse account and kept in this app's website data, so signing
/// in once lasts. It lives off screen; `show()` puts it in a window, which is
/// where the person signs in and answers what Muse asks.
@MainActor
final class MuseWebSession: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, NSWindowDelegate {
    static let shared = MuseWebSession()
    static let home = URL(string: "https://muse.ai/")!
    /// Files larger than this are not handed to the page.
    static let attachmentLimit = 25 * 1024 * 1024

    enum Snapshot {
        case loading
        case offline
        case signedOut
        case log([MuseAppSupport.Node])
    }

    /// Called when the page's content changes, so a reading follows at once.
    var onChange: (() -> Void)?

    private var web: WKWebView?
    private var window: NSWindow?
    /// Where the page lives while out of sight: a window of one point, nearly
    /// clear, above the others and passing clicks through. WebKit only runs a
    /// page fully in a window nothing covers, and Muse draws nothing otherwise.
    private var holder: NSWindow?
    private static let pageSize = NSRect(x: 0, y: 0, width: 900, height: 1300)
    private var popups: [NSWindow] = []
    private var failedAt: Date?
    /// When the page last finished loading: a page that shows no chat long
    /// after that is not going to (signed out on a page not recognized).
    private var finishedAt: Date?
    /// Whether the last reading found the chat. Signed out, the page's sign-in
    /// form expires after a while ("Your login session expired"), so it is
    /// loaded afresh before it is shown and now and then while it waits.
    private var showsChat = false
    nonisolated static let log = Logger(subsystem: "com.dynamai.app", category: "MuseWeb")
    private var log: Logger { Self.log }

    func load() {
        if web != nil { return }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: Self.visibleScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        controller.addUserScript(WKUserScript(source: Self.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        controller.add(WeakScriptHandler(self), name: "dynamaiMuse")
        configuration.userContentController = controller
        // Kept working while out of sight: a hidden page's timers are
        // otherwise slowed and its process may be paused, and Muse's replies
        // would only arrive when the page is next looked at.
        let preferences = configuration.preferences
        for selector in ["_setHiddenPageDOMTimerThrottlingEnabled:", "_setPageVisibilityBasedProcessSuppressionEnabled:"] {
            let name = NSSelectorFromString(selector)
            if preferences.responds(to: name) { preferences.perform(name, with: false) }
        }
        let web = WKWebView(frame: Self.pageSize, configuration: configuration)
        web.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/19.0 Safari/605.1.15"
        web.navigationDelegate = self
        web.uiDelegate = self
        self.web = web
        keepOutOfSight()
        web.load(URLRequest(url: Self.home))
    }

    private func keepOutOfSight() {
        guard let web else { return }
        if holder == nil {
            let corner = NSScreen.screens.first?.frame.origin ?? .zero
            let holder = NSWindow(contentRect: NSRect(origin: corner, size: NSSize(width: 1, height: 1)),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            holder.isReleasedWhenClosed = false
            holder.alphaValue = 0.01
            holder.backgroundColor = .clear
            holder.isOpaque = false
            holder.hasShadow = false
            holder.ignoresMouseEvents = true
            holder.level = .statusBar
            holder.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            holder.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
            self.holder = holder
        }
        web.removeFromSuperview()
        web.frame = Self.pageSize
        holder?.contentView?.addSubview(web)
        holder?.orderFrontRegardless()
    }

    /// The page in a window of this app: to sign in, answer Muse's questions,
    /// or use anything the island does not show.
    func show() {
        load()
        guard let web else { return }
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 800),
                                  styleMask: [.titled, .closable, .resizable, .miniaturizable],
                                  backing: .buffered, defer: false)
            window.title = "Muse"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.setFrameAutosaveName("DynamaiMuseWindow")
            if !window.setFrameUsingName("DynamaiMuseWindow") { window.center() }
            self.window = window
        }
        if failedAt != nil || !showsChat { reload() }
        web.removeFromSuperview()
        window?.contentView = web
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }
        if closing == window {
            // Back out of sight, still loaded and signed in.
            closing.contentView = nil
            keepOutOfSight()
            onChange?()
        } else {
            popups.removeAll { $0 == closing }
        }
    }

    private func reload() {
        failedAt = nil
        finishedAt = nil
        web?.load(URLRequest(url: Self.home))
    }

    /// A sign-in form left waiting out of sight is loaded afresh every few
    /// minutes, so it has not expired when the person opens it. Never while
    /// it is on screen, where they may be typing.
    private func refreshSignInIfStale() {
        guard window?.isVisible != true, let finishedAt, Date().timeIntervalSince(finishedAt) > 240 else { return }
        reload()
    }

    // MARK: Reading

    func snapshot(tail: Int, completion: @escaping (Snapshot) -> Void) {
        load()
        guard let web else { return completion(.loading) }
        if let failedAt {
            // Offline: try again now and then, not on every reading.
            if Date().timeIntervalSince(failedAt) > 15 { reload() }
            return completion(.offline)
        }
        web.evaluateJavaScript("window.__dynamaiMuse ? window.__dynamaiMuse.snapshot(\(tail)) : null") { [weak self] value, _ in
            guard let self else { return completion(.loading) }
            guard let text = value as? String, let data = text.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return completion(.loading) }
            let state = object["state"] as? String
            if state != "log" {
                Self.log.info("Muse page shows no chat: \(state ?? "-", privacy: .public) at \(object["where"] as? String ?? "-", privacy: .public), \(object["seen"] as? String ?? "-", privacy: .public), \(object["words"] as? Int ?? -1) characters")
            }
            self.showsChat = state == "log"
            switch state {
            case "log":
                let nodes = (object["nodes"] as? [[String: Any]] ?? []).map(Self.node)
                // The list is drawn before the conversation arrives: an empty
                // one is only taken as empty once the page has had time.
                if nodes.isEmpty, let finishedAt = self.finishedAt, Date().timeIntervalSince(finishedAt) < 10 {
                    return completion(.loading)
                }
                completion(.log(nodes))
            case "signedOut":
                self.refreshSignInIfStale()
                completion(.signedOut)
            default:
                if let finishedAt = self.finishedAt, Date().timeIntervalSince(finishedAt) > 12 {
                    self.refreshSignInIfStale()
                    completion(.signedOut)
                } else {
                    completion(.loading)
                }
            }
        }
    }

    /// The tree Accessibility would give for the page's elements, as
    /// `MuseAppSupport` reads it.
    nonisolated static func node(_ object: [String: Any]) -> MuseAppSupport.Node {
        var made = MuseAppSupport.Node(role: object["r"] as? String ?? "")
        made.subrole = object["s"] as? String ?? ""
        made.classes = object["c"] as? [String] ?? []
        made.title = object["t"] as? String ?? ""
        made.value = object["v"] as? String ?? ""
        made.children = (object["k"] as? [[String: Any]] ?? []).map { Self.node($0) }
        return made
    }

    // MARK: Sending

    /// Puts the files and the words in Muse's message field and sends them.
    /// `completion` gets nil once sent, or why not.
    func send(_ text: String, files: [URL], completion: @escaping (String?) -> Void) {
        guard let web else { return completion(MuseAppSupport.sendFailed) }
        let attachments: [[String: String]] = files.compactMap { url in
            guard let data = try? Data(contentsOf: url), data.count <= Self.attachmentLimit else { return nil }
            let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            return ["name": url.lastPathComponent, "type": type, "data": data.base64EncodedString()]
        }
        guard let payload = try? JSONSerialization.data(withJSONObject: ["text": text, "files": attachments]),
              let json = String(data: payload, encoding: .utf8)
        else { return completion(MuseAppSupport.sendFailed) }
        web.callAsyncJavaScript("return await window.__dynamaiMuse.send(payload)",
                                arguments: ["payload": json], in: nil, in: .page) { result in
            switch result {
            case .success(let value):
                let answer = value as? String ?? ""
                completion(answer == "sent" ? nil : MuseAppSupport.sendFailed)
            case .failure:
                completion(MuseAppSupport.sendFailed)
            }
        }
    }

    // MARK: Page

    nonisolated func userContentController(_ userContentController: WKUserContentController,
                                           didReceive message: WKScriptMessage) {
        Task { @MainActor in self.onChange?() }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let address = webView.url.map { ($0.host ?? "") + $0.path } ?? ""
        Task { @MainActor in
            self.failedAt = nil
            self.finishedAt = Date()
            self.log.info("Muse page loaded \(address, privacy: .public)")
            self.onChange?()
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.failed(error) }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                             withError error: Error) {
        Task { @MainActor in self.failed(error) }
    }

    private func failed(_ error: Error) {
        // A navigation replaced by another one is not a failure.
        if (error as NSError).code == NSURLErrorCancelled { return }
        failedAt = Date()
        onChange?()
    }

    nonisolated func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Task { @MainActor in self.reload() }
    }

    /// Sign-in pages may open their own window; anything else a link opens
    /// goes to the person's browser.
    nonisolated func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                             for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        MainActor.assumeIsolated {
            guard let url = navigationAction.request.url else { return nil }
            guard Self.belongsToSignIn(url) else {
                NSWorkspace.shared.open(url)
                return nil
            }
            let popup = WKWebView(frame: NSRect(x: 0, y: 0, width: 520, height: 680), configuration: configuration)
            popup.uiDelegate = self
            popup.customUserAgent = webView.customUserAgent
            let window = NSWindow(contentRect: popup.frame, styleMask: [.titled, .closable, .resizable],
                                  backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = popup
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            popups.append(window)
            return popup
        }
    }

    nonisolated func webViewDidClose(_ webView: WKWebView) {
        Task { @MainActor in
            if let window = self.popups.first(where: { $0.contentView === webView }) { window.close() }
        }
    }

    /// Links inside the page that leave Meta's sign-in and Muse open in the
    /// browser; the page itself stays on Muse.
    nonisolated func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                             decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        MainActor.assumeIsolated {
            if let url = navigationAction.request.url,
               !["http", "https", "about", "blob", "data"].contains(url.scheme?.lowercased() ?? "") {
                // hatch:// and the like would open the Muse app, which this
                // page exists to avoid.
                log.info("Muse page refused a link to \(url.scheme ?? "", privacy: .public)://\(url.host ?? "", privacy: .public)")
                return decisionHandler(.cancel)
            }
            if navigationAction.targetFrame?.isMainFrame ?? false, navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url, !Self.belongsToSignIn(url),
               ["http", "https"].contains(url.scheme ?? "") {
                NSWorkspace.shared.open(url)
                return decisionHandler(.cancel)
            }
            decisionHandler(.allow)
        }
    }

    nonisolated static func belongsToSignIn(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return ["muse.ai", "meta.ai", "meta.com", "facebook.com", "instagram.com", "fbcdn.net", "whatsapp.com",
                "accountscenter.meta.com", "apple.com", "google.com"]
            .contains { host == $0 || host.hasSuffix("." + $0) }
    }

    // MARK: Script

    /// Muse draws its chat only on a page someone is looking at. This page is
    /// out of sight on purpose, so it always says it is in view.
    static let visibleScript = #"""
    (() => {
      try {
        Object.defineProperty(Document.prototype, "visibilityState", { configurable: true, get: () => "visible" });
        Object.defineProperty(Document.prototype, "hidden", { configurable: true, get: () => false });
        Document.prototype.hasFocus = () => true;
        const stop = e => e.stopImmediatePropagation();
        document.addEventListener("visibilitychange", stop, true);
        window.addEventListener("blur", stop, true);
        window.addEventListener("pagehide", stop, true);
      } catch (e) {}
    })();
    """#

    /// Runs in the page. `snapshot` describes the chat log as Accessibility
    /// would (`MuseAppSupport.Node`, shortened keys), `send` fills the message
    /// field and sends it, and changes to the page are reported so a reading
    /// follows at once.
    static let script = #"""
    (() => {
      if (window.__dynamaiMuse) return;
      const post = () => { try { window.webkit.messageHandlers.dynamaiMuse.postMessage(1); } catch (e) {} };
      let pending = null;
      new MutationObserver(() => {
        if (pending) return;
        pending = setTimeout(() => { pending = null; post(); }, 150);
      }).observe(document.documentElement, { childList: true, subtree: true, characterData: true });

      const buttons = new Set(["button", "menuitem", "tab", "switch", "checkbox", "radio", "link-button"]);
      function visuallyHidden(el, rect) {
        const st = getComputedStyle(el);
        return st.position === "absolute" && rect.width <= 1 && rect.height <= 1;
      }
      function node(n, depth) {
        if (n.nodeType === 3) {
          const v = n.nodeValue.replace(/\s+/g, " ");
          return v.trim() ? { r: "AXStaticText", v } : null;
        }
        if (n.nodeType !== 1) return null;
        const el = n, tag = el.tagName.toLowerCase();
        if (["script", "style", "template", "noscript", "input", "textarea", "select"].includes(tag)) return null;
        if (el.getAttribute("aria-hidden") === "true") return null;
        const st = getComputedStyle(el);
        if (st.display === "none" || st.visibility === "hidden") return null;
        const role = (el.getAttribute("role") || "").toLowerCase();
        const c = Array.from(el.classList), t = el.getAttribute("aria-label") || "";
        if (tag === "button" || buttons.has(role)) {
          return { r: el.getAttribute("aria-haspopup") ? "AXPopUpButton" : "AXButton", c, t };
        }
        if (["img", "svg", "video", "canvas", "picture"].includes(tag) || role === "img") return { r: "AXImage", c, t };
        if (tag === "br") return { r: "AXStaticText", v: "\n" };
        if (!el.firstElementChild && visuallyHidden(el, el.getBoundingClientRect())) {
          const v = el.textContent.replace(/\s+/g, " ").trim();
          return v ? { r: "AXStaticText", v } : null;
        }
        let r = "AXGroup", s = "";
        if (tag === "code" && !(el.parentElement && el.parentElement.tagName === "PRE")) s = "AXCodeStyleGroup";
        else if (st.display.startsWith("inline") && tag !== "pre") r = "AXInline";
        const out = { r, s, c, t, k: [] };
        if (depth < 14) {
          for (const child of el.childNodes) {
            const made = node(child, depth + 1);
            if (made) out.k.push(made);
            if (out.k.length >= 80) break;
          }
        }
        return out;
      }
      function log() { return document.querySelector('[role="log"]'); }
      function signedOut() {
        if (/\/(login|access|oidc)/.test(location.pathname) || !/(^|\.)muse\.ai$/.test(location.hostname)) return true;
        // The home page signs in in place: a field for a phone number or an
        // email, under "Log in or create an account".
        if (document.querySelector('input[type="email"], input[type="tel"], input[autocomplete~="username"], input[name*="email" i], input[name*="contact" i]')) return true;
        if (/log in or create an account/i.test(document.body ? document.body.innerText : "")) return true;
        return Array.from(document.querySelectorAll("a,button")).some(b => /^(log in|sign in)$/i.test((b.textContent || "").trim()));
      }
      function composer() {
        const all = Array.from(document.querySelectorAll('[contenteditable="true"], [contenteditable=""], textarea'))
          .filter(el => !el.closest('[role="log"]') && el.getBoundingClientRect().width > 0);
        return all.find(el => /message/i.test((el.getAttribute("aria-label") || "") + (el.getAttribute("placeholder") || "") + (el.getAttribute("aria-placeholder") || "") + (el.dataset.placeholder || "")))
          || all[all.length - 1] || null;
      }
      // Muse draws its whole message bar as one control (role="button"),
      // with Send inside it; anything that holds the field is not Send.
      function controls(scope, field) {
        return Array.from(scope.querySelectorAll('button, [role="button"], [type="submit"]'))
          .filter(b => !b.contains(field) && !b.closest('[role="log"]') && b.getBoundingClientRect().width > 0
            && !b.disabled && b.getAttribute("aria-disabled") !== "true");
      }
      function labelOf(b) {
        return [b.getAttribute("aria-label"), b.getAttribute("title"), b.getAttribute("data-testid"),
                b.getAttribute("name"), b.innerText].filter(Boolean).join(" ");
      }
      function sendButton(field) {
        let scope = field.parentElement;
        for (let i = 0; i < 10 && scope; i++, scope = scope.parentElement) {
          const all = controls(scope, field);
          const named = all.find(b => /\bsend\b/i.test(labelOf(b)));
          if (named) return named;
        }
        // No name: the rightmost control on the field's row (the arrow, right
        // of the microphone).
        const row = field.getBoundingClientRect();
        scope = field.parentElement;
        for (let i = 0; i < 6 && scope; i++, scope = scope.parentElement) {
          const inRow = controls(scope, field).filter(b => {
            const r = b.getBoundingClientRect();
            return r.top < row.bottom + 24 && r.bottom > row.top - 24 && r.left >= row.left;
          });
          if (inRow.length) return inRow.sort((a, b) => b.getBoundingClientRect().right - a.getBoundingClientRect().right)[0];
        }
        return null;
      }
      function press(el) {
        const r = el.getBoundingClientRect(), x = r.left + r.width / 2, y = r.top + r.height / 2;
        const init = { bubbles: true, cancelable: true, composed: true, clientX: x, clientY: y, button: 0, pointerId: 1, pointerType: "mouse", isPrimary: true };
        el.dispatchEvent(new PointerEvent("pointerdown", init));
        el.dispatchEvent(new MouseEvent("mousedown", init));
        el.dispatchEvent(new PointerEvent("pointerup", init));
        el.dispatchEvent(new MouseEvent("mouseup", init));
        el.click();
      }
      function textOf(field) { return ("value" in field ? field.value : field.innerText || "").trim(); }
      const pause = ms => new Promise(done => setTimeout(done, ms));

      window.__dynamaiMuse = {
        snapshot(tail) {
          const list = log();
          if (!list) return JSON.stringify({ state: signedOut() ? "signedOut" : "loading",
            where: location.pathname, seen: document.visibilityState, words: (document.body ? document.body.innerText.length : 0) });
          let kids = Array.from(list.childNodes);
          if (tail > 0) kids = kids.slice(-tail);
          const nodes = kids.map(k => node(k, 0)).filter(Boolean);
          return JSON.stringify({ state: "log", nodes });
        },
        async send(json) {
          const payload = JSON.parse(json);
          const field = composer();
          if (!field) return "no field";
          field.focus();
          if (payload.files && payload.files.length) {
            const transfer = new DataTransfer();
            for (const f of payload.files) {
              const bytes = Uint8Array.from(atob(f.data), ch => ch.charCodeAt(0));
              transfer.items.add(new File([bytes], f.name, { type: f.type }));
            }
            const picker = document.querySelector('input[type="file"]');
            if (picker) {
              picker.files = transfer.files;
              picker.dispatchEvent(new Event("change", { bubbles: true }));
            } else {
              field.dispatchEvent(new ClipboardEvent("paste", { clipboardData: transfer, bubbles: true, cancelable: true }));
            }
            await pause(1500);
            field.focus();
          }
          if (payload.text) {
            if ("value" in field) {
              const setter = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(field), "value").set;
              setter.call(field, payload.text);
              field.dispatchEvent(new Event("input", { bubbles: true }));
            } else {
              const lines = payload.text.split("\n");
              lines.forEach((line, i) => {
                if (i > 0) document.execCommand("insertLineBreak");
                if (line) document.execCommand("insertText", false, line);
              });
            }
            await pause(150);
            if (!textOf(field)) return "not filled";
          }
          const button = sendButton(field);
          if (button) {
            press(button);
          } else {
            for (const type of ["keydown", "keypress", "keyup"]) {
              field.dispatchEvent(new KeyboardEvent(type, { key: "Enter", code: "Enter", keyCode: 13, which: 13, bubbles: true, cancelable: true }));
            }
          }
          for (let i = 0; i < 20; i++) {
            await pause(100);
            if (!textOf(field)) return "sent";
          }
          return payload.text ? "not sent" : "sent";
        }
      };
      post();
    })();
    """#
}

/// The page's messages, without the page holding on to the session.
private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}
