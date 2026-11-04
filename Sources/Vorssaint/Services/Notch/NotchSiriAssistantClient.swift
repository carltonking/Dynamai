// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Whether this Mac can run the island's Siri: Apple's on-device model has to
/// be there and ready (Apple Intelligence on, a supported Mac and language).
enum SiriAssistantAvailability {
    /// Why it cannot, in a few words for the page; `nil` when it can.
    static func unavailableReason() -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return nil
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible: return "this Mac does not support Apple Intelligence"
                case .appleIntelligenceNotEnabled: return "Apple Intelligence is turned off"
                case .modelNotReady: return "Apple Intelligence is still getting ready"
                @unknown default: return "Apple Intelligence is not available"
                }
            }
        }
        #endif
        return "it needs macOS 26 or later"
    }

    /// The Mac itself can never run it, as opposed to it being turned off or
    /// still downloading: the only case that keeps the feature from installing.
    static var deviceCanRun: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if case .unavailable(.deviceNotEligible) = SystemLanguageModel.default.availability { return false }
            return true
        }
        #endif
        return false
    }
}

/// The island's own Siri, an assistant of this app's on Apple's language
/// models, with tools for the calendar, reminders, weather, timers, volume,
/// apps, links and Shortcuts. It does not use the Siri AI app.
///
/// One model session holds the conversation, so a follow-up knows what came
/// before; a new client (a relaunch, a retry) starts one from the saved
/// history. Apple's on-device model answers: the build's pinned macOS 26 SDK
/// does not carry the server model (Private Cloud Compute), which macOS 27
/// added.
/// Like the other transports nothing here touches the island's state: events
/// arrive on the main thread and the service decides what they mean.
final class NotchSiriAssistantClient: NotchAgentChatTransport {
    typealias Event = NotchHermesChatClient.Event

    private let onEvent: (Event) -> Void
    /// The conversation the next session starts from.
    private var history: [NotchHermesChatMessage]
    /// The turn running now; each waits for the one before it.
    private var turn: Task<Void, Never>?
    /// The session, kept as `AnyObject` so this type exists on older SDKs.
    private var session: AnyObject?
    /// What Siri prepared and only the person's tap does (an email to send),
    /// by the action named on its card. Tools add from the model's thread,
    /// taps settle from the main one.
    private var pending: [String: SiriMailSupport.Pending] = [:]
    private let pendingLock = NSLock()
    private var ended = false

    init(history: [NotchHermesChatMessage], onEvent: @escaping (Event) -> Void) {
        self.history = history
        self.onEvent = onEvent
    }

    func start() {
        emit(.ready(agent: "SIRI", model: "Apple Intelligence"))
        emit(.session)
    }

    func send(_ text: String) {
        let previous = turn
        turn = Task { [weak self] in
            await previous?.value
            await self?.respond(to: text)
        }
    }

    /// Stops the answer being written; what was written stays.
    func cancel() {
        turn?.cancel()
        turn = nil
        emit(.status(nil))
        emit(.finished(.cancelled))
    }

    func end() {
        ended = true
        turn?.cancel()
        turn = nil
    }

    /// Siri asks in plain words; there is no approval to answer.
    func answer(_ approval: String, choice: NotchAgentApproval.Choice) {}

    /// A button on one of Siri's cards: what it prepared is done (or not),
    /// once, and the card says how it went.
    func perform(action: String, button: String) {
        pendingLock.lock()
        let waiting = pending.removeValue(forKey: action)
        pendingLock.unlock()
        guard let waiting else {
            emit(.cardDone(action: action, result: "No longer available"))
            return
        }
        let command = SiriMailSupport.command(for: waiting, button: button)
        guard let script = command.script else {
            emit(.cardDone(action: action, result: command.done))
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Shell.run("/usr/bin/osascript", ["-e", script] + command.arguments, timeout: 60)
            let done = result.status == 0 ? command.done : SiriMailSupport.failure(result.output)
            self?.emit(.cardDone(action: action, result: done))
        }
    }

    private func keep(_ waiting: SiriMailSupport.Pending) -> String {
        let action = UUID().uuidString
        pendingLock.lock()
        pending[action] = waiting
        pendingLock.unlock()
        return action
    }

    /// The page was cleared: the next message starts a new conversation.
    func startOver() {
        turn?.cancel()
        turn = nil
        let previous = turn
        turn = Task { [weak self] in
            await previous?.value
            self?.session = nil
            self?.history = []
        }
    }

    private func emit(_ event: Event) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.ended else { return }
            self.onEvent(event)
        }
    }

    // MARK: A turn

    private func respond(to prompt: String) async {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            await answer(prompt)
            return
        }
        #endif
        emit(.turnFailed("Apple Intelligence needs macOS 26 or later."))
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func answer(_ prompt: String) async {
        let started = Date()
        for attempt in 0..<2 {
            guard !Task.isCancelled else { return }
            let session = self.session as? LanguageModelSession ?? makeSession()
            var written = ""
            do {
                for try await snapshot in session.streamResponse(to: prompt) {
                    guard !Task.isCancelled else { return }
                    let full = snapshot.content
                    // Each snapshot is the answer so far; only what is new
                    // goes on, and a rewrite of what was shown is left alone.
                    if full.count > written.count, full.hasPrefix(written) {
                        if written.isEmpty { emit(.status(nil)) }
                        emit(.text(String(full.dropFirst(written.count))))
                        written = full
                    }
                }
                remember(prompt, answer: written, at: started)
                emit(.status(nil))
                emit(.finished(.endTurn))
                return
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                emit(.status(nil))
                // Started over only when nothing has been shown yet: a retry
                // after words appeared would write them twice.
                let retry = written.isEmpty && attempt == 0
                if let failure = error as? LanguageModelSession.GenerationError {
                    switch failure {
                    case .guardrailViolation:
                        emit(.turnFailed("Apple Intelligence would not answer that."))
                        return
                    case .exceededContextWindowSize:
                        // The conversation outgrew the model: a new session
                        // with only its latest part carries on.
                        history = Array(history.suffix(4))
                        self.session = nil
                        if retry { continue }
                    default:
                        break
                    }
                }
                emit(.turnFailed(error.localizedDescription))
                return
            }
        }
    }

    @available(macOS 26.0, *)
    private func makeSession() -> LanguageModelSession {
        let context = SiriToolContext(status: { [weak self] words in self?.emit(.status(words)) },
                                      card: { [weak self] card in self?.emit(.card(card)) },
                                      pend: { [weak self] waiting in self?.keep(waiting) ?? UUID().uuidString })
        let instructions = SiriAssistantSupport.instructions(now: Date(), timeZone: .current, locale: .current,
                                                             history: history)
        let tools = SiriAssistantTools.all(context)
        let session = LanguageModelSession(model: SystemLanguageModel.default, tools: tools, instructions: instructions)
        self.session = session
        return session
    }
    #endif

    /// What a new session will be told of this turn.
    private func remember(_ prompt: String, answer: String, at date: Date) {
        history.append(NotchHermesChatMessage(role: .person, text: prompt, date: date))
        if !answer.isEmpty { history.append(NotchHermesChatMessage(role: .hermes, text: answer)) }
        history = Array(history.suffix(SiriAssistantSupport.carriedMessages))
    }
}
