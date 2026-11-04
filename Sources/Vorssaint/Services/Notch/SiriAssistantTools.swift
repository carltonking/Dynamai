// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

// The island's Siri runs on Apple's language models, which the macOS 26 SDK
// and later carry. Builds against an older SDK (CI's compatibility job) leave
// the assistant out and the page says it needs Apple Intelligence.
#if canImport(FoundationModels)
import AppKit
import EventKit
import FoundationModels

/// What the tools hand back besides their words: the page's status line
/// while they run, and the cards they show.
final class SiriToolContext: @unchecked Sendable {
    let status: (String?) -> Void
    let card: (NotchHermesChatMessage.Card) -> Void
    /// Keeps something only the person's tap may do, and names it for the
    /// card whose buttons settle it.
    let pend: (SiriMailSupport.Pending) -> String
    let store = EKEventStore()
    var timeZone: TimeZone { .current }

    init(status: @escaping (String?) -> Void, card: @escaping (NotchHermesChatMessage.Card) -> Void,
         pend: @escaping (SiriMailSupport.Pending) -> String) {
        self.status = status
        self.card = card
        self.pend = pend
    }

    /// Runs one of the Mail scripts with its arguments.
    func mail(_ script: String, _ arguments: [String]) -> (ok: Bool, output: String) {
        let result = Shell.run("/usr/bin/osascript", ["-e", script] + arguments, timeout: 45)
        return (result.status == 0, result.output)
    }

    /// Calendar or Reminders access, asked for the first time it is needed.
    func access(to type: EKEntityType) async -> Bool {
        switch EKEventStore.authorizationStatus(for: type) {
        case .fullAccess: return true
        case .notDetermined:
            let granted = type == .event
                ? (try? await store.requestFullAccessToEvents())
                : (try? await store.requestFullAccessToReminders())
            return granted == true
        default: return false
        }
    }
}

/// The arguments a tool takes, described for the model at run time rather
/// than through the `@Generable` macro, which the build's plain `swiftc` has
/// no plugin for.
/// What kind of value an argument is.
private enum ArgumentKind { case text, number, flag }

@available(macOS 26.0, *)
private func arguments(_ name: String, _ properties: [(String, String, ArgumentKind, Bool)]) -> GenerationSchema {
    let fields = properties.map { field -> DynamicGenerationSchema.Property in
        let schema: DynamicGenerationSchema
        switch field.2 {
        case .text: schema = DynamicGenerationSchema(type: String.self)
        case .number: schema = DynamicGenerationSchema(type: Int.self)
        case .flag: schema = DynamicGenerationSchema(type: Bool.self)
        }
        return DynamicGenerationSchema.Property(name: field.0, description: field.1, schema: schema, isOptional: field.3)
    }
    // A schema built from these parts is always valid.
    return (try? GenerationSchema(root: DynamicGenerationSchema(name: name, properties: fields), dependencies: []))
        ?? (try! GenerationSchema(root: DynamicGenerationSchema(name: name, properties: []), dependencies: []))
}

@available(macOS 26.0, *)
private extension GeneratedContent {
    func text(_ name: String) -> String? {
        guard let value = try? value(String?.self, forProperty: name) else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func number(_ name: String) -> Int? {
        (try? value(Int?.self, forProperty: name)) ?? nil
    }

    func flag(_ name: String) -> Bool? {
        (try? value(Bool?.self, forProperty: name)) ?? nil
    }
}

@available(macOS 26.0, *)
enum SiriAssistantTools {
    static func all(_ context: SiriToolContext) -> [any Tool] {
        [CalendarEvents(context: context), CreateEvent(context: context), Reminders(context: context),
         CreateReminder(context: context), Weather(context: context), StartTimer(context: context),
         SetVolume(context: context), OpenApp(context: context), OpenLink(context: context),
         ListShortcuts(context: context), RunShortcut(context: context),
         ListEmails(context: context), SearchEmails(context: context), ReadEmail(context: context),
         DraftEmail(context: context), DraftReply(context: context), MarkEmail(context: context),
         TrashEmail(context: context)]
    }

    private static let calendarApp = "file:///System/Applications/Calendar.app"
    private static let remindersApp = "file:///System/Applications/Reminders.app"

    struct CalendarEvents: Tool {
        let context: SiriToolContext
        let name = "getCalendarEvents"
        let description = "Lists the user's calendar events for a range of days."
        var parameters: GenerationSchema {
            arguments("CalendarRange", [("startDate", "First day, as YYYY-MM-DD", .text, false),
                                        ("days", "How many days from the first, 1 for one day", .number, true)])
        }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            guard await context.access(to: .event) else { return "Calendar access is not allowed for this app." }
            let zone = context.timeZone
            let start = arguments.text("startDate").flatMap { SiriAssistantSupport.day($0, timeZone: zone) }
                ?? Calendar.current.startOfDay(for: Date())
            let days = max(1, min(31, arguments.number("days") ?? 1))
            let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
            let predicate = context.store.predicateForEvents(withStart: start, end: end, calendars: nil)
            // All-day events lead, as Calendar lists them; the rest by start.
            let events = context.store.events(matching: predicate).sorted {
                $0.isAllDay != $1.isAllDay ? $0.isAllDay : $0.startDate < $1.startDate
            }
            guard !events.isEmpty else { return "No events in that range." }
            let formatter = DateFormatter()
            formatter.timeZone = zone
            formatter.timeStyle = .short
            formatter.dateStyle = days > 1 ? .short : .none
            let lines = events.prefix(SiriAssistantSupport.listLimit).map { event -> String in
                let when = event.isAllDay ? "All day" : formatter.string(from: event.startDate)
                return "\(when) · \(event.title ?? "Event")"
            }
            context.card(.init(lines: ["Calendar"] + lines, symbol: "calendar", buttons: [], link: SiriAssistantTools.calendarApp))
            return lines.joined(separator: "\n") + (events.count > lines.count ? "\n(and \(events.count - lines.count) more)" : "")
        }
    }

    struct CreateEvent: Tool {
        let context: SiriToolContext
        let name = "createCalendarEvent"
        let description = "Adds an event to the user's default calendar."
        var parameters: GenerationSchema {
            arguments("NewEvent", [("title", "What the event is", .text, false),
                                   ("start", "When it starts, as YYYY-MM-DD HH:mm in 24-hour time", .text, false),
                                   ("durationMinutes", "How long it lasts in minutes", .number, true),
                                   ("location", "Where it is", .text, true)])
        }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            guard await context.access(to: .event) else { return "Calendar access is not allowed for this app." }
            guard let title = arguments.text("title"),
                  let start = arguments.text("start").flatMap({ SiriAssistantSupport.moment($0, timeZone: context.timeZone) })
            else { return "The event needs a title and a start time." }
            let event = EKEvent(eventStore: context.store)
            event.title = title
            event.startDate = start
            event.endDate = start.addingTimeInterval(TimeInterval(max(5, arguments.number("durationMinutes") ?? 60) * 60))
            event.location = arguments.text("location")
            event.calendar = context.store.defaultCalendarForNewEvents
            do { try context.store.save(event, span: .thisEvent) } catch {
                return "The event could not be saved: \(error.localizedDescription)"
            }
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let when = formatter.string(from: start)
            context.card(.init(lines: ["Event added", title, when] + (event.location.map { [$0] } ?? []),
                               symbol: "calendar.badge.plus", buttons: [], link: SiriAssistantTools.calendarApp))
            return "Added \"\(title)\" on \(when)."
        }
    }

    struct Reminders: Tool {
        let context: SiriToolContext
        let name = "getReminders"
        let description = "Lists the user's reminders that are not done yet."
        var parameters: GenerationSchema { arguments("ReminderQuery", []) }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            guard await context.access(to: .reminder) else { return "Reminders access is not allowed for this app." }
            let predicate = context.store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
            let reminders: [EKReminder] = await withCheckedContinuation { done in
                context.store.fetchReminders(matching: predicate) { done.resume(returning: $0 ?? []) }
            }
            guard !reminders.isEmpty else { return "No open reminders." }
            let titles = reminders.prefix(SiriAssistantSupport.listLimit).map { $0.title ?? "Reminder" }
            context.card(.init(lines: ["Reminders"] + titles, symbol: "checklist", buttons: [],
                               link: SiriAssistantTools.remindersApp))
            return titles.joined(separator: "\n") + (reminders.count > titles.count ? "\n(and \(reminders.count - titles.count) more)" : "")
        }
    }

    struct CreateReminder: Tool {
        let context: SiriToolContext
        let name = "createReminder"
        let description = "Adds a reminder to the user's default reminders list."
        var parameters: GenerationSchema {
            arguments("NewReminder", [("title", "What to be reminded of", .text, false),
                                      ("due", "When it is due, as YYYY-MM-DD HH:mm in 24-hour time", .text, true)])
        }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            guard await context.access(to: .reminder) else { return "Reminders access is not allowed for this app." }
            guard let title = arguments.text("title") else { return "The reminder needs a title." }
            let reminder = EKReminder(eventStore: context.store)
            reminder.title = title
            reminder.calendar = context.store.defaultCalendarForNewReminders()
            var lines = ["Reminder added", title]
            if let due = arguments.text("due").flatMap({ SiriAssistantSupport.moment($0, timeZone: context.timeZone) }) {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: due)
                reminder.addAlarm(EKAlarm(absoluteDate: due))
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                lines.append(formatter.string(from: due))
            }
            do { try context.store.save(reminder, commit: true) } catch {
                return "The reminder could not be saved: \(error.localizedDescription)"
            }
            context.card(.init(lines: lines, symbol: "checklist", buttons: [], link: SiriAssistantTools.remindersApp))
            return "Added the reminder \"\(title)\"."
        }
    }

    struct Weather: Tool {
        let context: SiriToolContext
        let name = "getWeather"
        let description = "Gets today's weather for a city, or where the user is when no city is given."
        var parameters: GenerationSchema {
            arguments("WeatherPlace", [("city", "The city, if the user named one", .text, true)])
        }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            let city = arguments.text("city") ?? SiriAssistantSupport.homeCity(timeZone: context.timeZone)
            let language = Locale.current.language.languageCode?.identifier ?? "en"
            let fahrenheit = Locale.current.measurementSystem == .us
            guard let geocoding = SiriAssistantSupport.geocodingURL(city: city, language: language),
                  let (placeData, _) = try? await URLSession.shared.data(from: geocoding),
                  let place = SiriAssistantSupport.place(fromGeocoding: placeData),
                  let forecast = SiriAssistantSupport.forecastURL(latitude: place.latitude, longitude: place.longitude,
                                                                  fahrenheit: fahrenheit),
                  let (weatherData, _) = try? await URLSession.shared.data(from: forecast),
                  let weather = SiriAssistantSupport.weather(fromForecast: weatherData)
            else { return "The weather for \(city) could not be fetched." }
            context.card(SiriAssistantSupport.weatherCard(place: place.name, weather: weather))
            return SiriAssistantSupport.weatherSummary(place: place.name, weather: weather, fahrenheit: fahrenheit)
        }
    }

    struct StartTimer: Tool {
        let context: SiriToolContext
        let name = "startTimer"
        let description = "Starts a countdown timer in the Dynamic Island."
        var parameters: GenerationSchema {
            arguments("TimerLength", [("minutes", "How many minutes", .number, false)])
        }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            let minutes = max(1, min(600, arguments.number("minutes") ?? 0))
            let started: Bool = await MainActor.run {
                guard NotchTimerSupport.isEnabled() else { return false }
                NotchTimerService.shared.start(mode: .timer, minutes: minutes)
                return NotchTimerService.shared.session.hasSession
            }
            guard started else { return "The island's timer is turned off in its settings, or a timer is already running." }
            context.card(.init(lines: ["Timer", "\(minutes) min"], symbol: "timer", buttons: []))
            return "Started a \(minutes)-minute timer."
        }
    }

    struct SetVolume: Tool {
        let context: SiriToolContext
        let name = "setVolume"
        let description = "Sets the Mac's output volume, from 0 (muted) to 100."
        var parameters: GenerationSchema {
            arguments("VolumeLevel", [("percent", "The volume from 0 to 100", .number, false)])
        }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            let percent = max(0, min(100, arguments.number("percent") ?? 50))
            let done: Bool = await MainActor.run {
                var error: NSDictionary?
                NSAppleScript(source: "set volume output volume \(percent)")?.executeAndReturnError(&error)
                return error == nil
            }
            return done ? "Volume set to \(percent)%." : "The volume could not be changed."
        }
    }

    struct OpenApp: Tool {
        let context: SiriToolContext
        let name = "openApp"
        let description = "Opens an app on the Mac by its name."
        var parameters: GenerationSchema {
            arguments("AppName", [("name", "The app's name, like Safari or Notes", .text, false)])
        }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            guard let app = arguments.text("name") else { return "Which app?" }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", app]
            do { try process.run() } catch { return "\(app) could not be opened." }
            process.waitUntilExit()
            return process.terminationStatus == 0 ? "Opened \(app)." : "There is no app called \(app) on this Mac."
        }
    }

    struct OpenLink: Tool {
        let context: SiriToolContext
        let name = "openLink"
        let description = "Opens a web address in the default browser."
        var parameters: GenerationSchema {
            arguments("Link", [("url", "The full web address, starting with https://", .text, false)])
        }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            guard let text = arguments.text("url"), let url = URL(string: text),
                  let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http"
            else { return "That is not a web address." }
            await MainActor.run { _ = NSWorkspace.shared.open(url) }
            return "Opened \(url.host ?? text)."
        }
    }

    struct ListShortcuts: Tool {
        let context: SiriToolContext
        let name = "listShortcuts"
        let description = "Lists the names of the user's shortcuts from the Shortcuts app."
        var parameters: GenerationSchema { arguments("ShortcutList", []) }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            let result = Shell.run("/usr/bin/shortcuts", ["list"], timeout: 15)
            let names = result.output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            return names.isEmpty ? "No shortcuts." : names.prefix(60).joined(separator: "\n")
        }
    }

    struct RunShortcut: Tool {
        let context: SiriToolContext
        let name = "runShortcut"
        let description = "Runs one of the user's shortcuts by its exact name, optionally with text as its input."
        var parameters: GenerationSchema {
            arguments("ShortcutRun", [("name", "The shortcut's exact name", .text, false),
                                      ("input", "Text to give the shortcut", .text, true)])
        }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            guard let shortcut = arguments.text("name") else { return "Which shortcut?" }
            var args = ["run", shortcut]
            var inputFile: URL?
            if let input = arguments.text("input") {
                let file = FileManager.default.temporaryDirectory.appendingPathComponent("siri-shortcut-\(UUID().uuidString).txt")
                try? input.write(to: file, atomically: true, encoding: .utf8)
                inputFile = file
                args += ["--input-path", file.path]
            }
            defer { if let inputFile { try? FileManager.default.removeItem(at: inputFile) } }
            let result = Shell.run("/usr/bin/shortcuts", args, timeout: 120)
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard result.status == 0 else {
                return "The shortcut \"\(shortcut)\" did not run\(output.isEmpty ? "." : ": \(output.prefix(300))")"
            }
            return output.isEmpty ? "Ran \"\(shortcut)\"." : "Ran \"\(shortcut)\". It returned: \(output.prefix(800))"
        }
    }

    // MARK: Email, through Mail

    struct ListEmails: Tool {
        let context: SiriToolContext
        let name = "listEmails"
        let description = "Lists recent emails in the user's Mail inbox, newest first, with the id each other email tool takes."
        var parameters: GenerationSchema {
            arguments("InboxQuery", [("unreadOnly", "Only unread emails", .flag, true),
                                     ("days", "How many days back to look, 7 if not said", .number, true)])
        }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            let unread = arguments.flag("unreadOnly") ?? false
            let days = max(1, min(90, arguments.number("days") ?? SiriMailSupport.defaultDays))
            let result = context.mail(SiriMailSupport.listScript, [String(days), unread ? "1" : "0"])
            guard result.ok else { return SiriMailSupport.failure(result.output) }
            let summaries = SiriMailSupport.summaries(result.output)
            if !summaries.isEmpty {
                context.card(SiriMailSupport.inboxCard(summaries, title: unread ? "Unread" : "Inbox"))
            }
            return SiriMailSupport.listing(summaries)
        }
    }

    struct SearchEmails: Tool {
        let context: SiriToolContext
        let name = "searchEmails"
        let description = "Finds emails in the inbox whose subject or sender contains the given words."
        var parameters: GenerationSchema {
            arguments("InboxSearch", [("query", "Words in the subject, or the sender's name or address", .text, false),
                                      ("days", "How many days back to look, 30 if not said", .number, true)])
        }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            guard let query = arguments.text("query") else { return "What should I look for?" }
            let days = max(1, min(365, arguments.number("days") ?? 30))
            let result = context.mail(SiriMailSupport.searchScript, [query, String(days)])
            guard result.ok else { return SiriMailSupport.failure(result.output) }
            let summaries = SiriMailSupport.summaries(result.output)
            if !summaries.isEmpty { context.card(SiriMailSupport.inboxCard(summaries, title: query)) }
            return SiriMailSupport.listing(summaries)
        }
    }

    struct ReadEmail: Tool {
        let context: SiriToolContext
        let name = "readEmail"
        let description = "Reads one email from the inbox by its id, from listEmails or searchEmails."
        var parameters: GenerationSchema { arguments("EmailID", [("id", "The email's id", .number, false)]) }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            guard let id = arguments.number("id") else { return "Which email? List them first to get its id." }
            let result = context.mail(SiriMailSupport.readScript, [String(id)])
            guard result.ok, let message = SiriMailSupport.message(result.output) else {
                return SiriMailSupport.failure(result.output)
            }
            return SiriMailSupport.reading(message)
        }
    }

    struct DraftEmail: Tool {
        let context: SiriToolContext
        let name = "draftEmail"
        let description = "Writes a new email and shows it to the user with Send and Open in Mail buttons. It is never sent until the user taps Send."
        var parameters: GenerationSchema {
            arguments("NewEmail", [("to", "Recipient email addresses, separated by commas", .text, false),
                                   ("cc", "Addresses to copy, separated by commas", .text, true),
                                   ("subject", "The subject line", .text, false),
                                   ("body", "The full text of the email, signed off naturally", .text, false)])
        }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            guard let to = SiriMailSupport.addresses(arguments.text("to")), !to.isEmpty else {
                return "The email needs the recipient's full email address. Ask the user for it."
            }
            guard let cc = SiriMailSupport.addresses(arguments.text("cc")) else { return "One of the copy addresses is not an email address." }
            let subject = arguments.text("subject") ?? ""
            guard let body = arguments.text("body") else { return "The email needs some text." }
            let action = context.pend(.compose(to: to, cc: cc, subject: subject, body: body))
            context.card(SiriMailSupport.draftCard(to: to.replacingOccurrences(of: ",", with: ", "), subject: subject,
                                                   body: body, action: action, reply: false))
            return "The draft is shown to the user with Send and Open in Mail buttons. It has NOT been sent; say it is ready for them to send."
        }
    }

    struct DraftReply: Tool {
        let context: SiriToolContext
        let name = "draftReply"
        let description = "Writes a reply to an inbox email and shows it with Send and Open in Mail buttons. It is never sent until the user taps Send."
        var parameters: GenerationSchema {
            arguments("Reply", [("id", "The id of the email being answered", .number, false),
                                ("body", "The text of the reply", .text, false),
                                ("replyAll", "Reply to everyone on the email", .flag, true)])
        }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            guard let id = arguments.number("id"), let body = arguments.text("body") else {
                return "The reply needs the email's id and its text."
            }
            let result = context.mail(SiriMailSupport.readScript, [String(id)])
            guard result.ok, let original = SiriMailSupport.message(result.output) else {
                return SiriMailSupport.failure(result.output)
            }
            let to = SiriMailSupport.name(original.sender)
            let subject = original.subject.lowercased().hasPrefix("re:") ? original.subject : "Re: \(original.subject)"
            let action = context.pend(.reply(id: id, to: to, body: body, toAll: arguments.flag("replyAll") ?? false))
            context.card(SiriMailSupport.draftCard(to: to, subject: subject, body: body, action: action, reply: true))
            return "The reply is shown to the user with Send and Open in Mail buttons. It has NOT been sent; say it is ready for them to send."
        }
    }

    struct MarkEmail: Tool {
        let context: SiriToolContext
        let name = "markEmail"
        let description = "Marks an inbox email as read or unread."
        var parameters: GenerationSchema {
            arguments("EmailMark", [("id", "The email's id", .number, false),
                                    ("read", "true to mark read, false to mark unread", .flag, false)])
        }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            guard let id = arguments.number("id") else { return "Which email?" }
            let read = arguments.flag("read") ?? true
            let result = context.mail(SiriMailSupport.markScript, [String(id), read ? "1" : "0"])
            return result.ok ? "Marked as \(read ? "read" : "unread")." : SiriMailSupport.failure(result.output)
        }
    }

    struct TrashEmail: Tool {
        let context: SiriToolContext
        let name = "trashEmail"
        let description = "Asks the user to confirm moving an inbox email to the Trash; it moves only when they tap the button."
        var parameters: GenerationSchema { arguments("EmailTrash", [("id", "The email's id", .number, false)]) }

        func call(arguments: GeneratedContent) async throws -> String {
            context.status(SiriAssistantSupport.status(forTool: name))
            guard let id = arguments.number("id") else { return "Which email?" }
            let result = context.mail(SiriMailSupport.readScript, [String(id)])
            guard result.ok, let message = SiriMailSupport.message(result.output) else {
                return SiriMailSupport.failure(result.output)
            }
            context.card(SiriMailSupport.trashCard(message, action: context.pend(.trash(id: id))))
            return "The user is asked to confirm with a Move to Trash button. It has NOT been moved yet."
        }
    }
}
#endif
