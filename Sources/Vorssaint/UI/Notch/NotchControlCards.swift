// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The Controls page's widgets, as Apple's widgets page: full-width screens
/// stacked one above the other, a vertical swipe or scroll moving to the
/// next. No dots say which one shows: they took a column of the strip the
/// widgets need, and the slide already tells the screens apart. The calendar's
/// hours have the first screen; the smaller widgets share the second, side
/// by side. The stack is a loop, so swiping the same way keeps cycling, and
/// only one screen is ever on show: a scroll view let the next screen show
/// through mid-swipe, half over the one leaving.
struct NotchControlCards: View {
    @ObservedObject var service: NotchService
    let items: [NotchControlItem]
    let height: CGFloat
    /// Unbounded, so the slide always runs the way the swipe went; the shown
    /// screen is this wrapped into the stack.
    @State private var position = 0
    @State private var direction = 1
    @State private var hovering = false
    @State private var scroll = NotchWidgetStackScroll()
    @State private var monitor: Any?
    /// Read by the scroll monitor, which outlives the items it was made with.
    @State private var screenCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let screens = NotchSupport.widgetScreens(items)
        let shown = NotchWidgetStackScroll.wrapped(position, count: screens.count)
        GeometryReader { proxy in
            ZStack {
                if screens.indices.contains(shown) {
                    screen(screens[shown], size: proxy.size)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .id(position)
                        .transition(slide)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .frame(height: height)
        .onHover { hovering = $0 }
        .onAppear { screenCount = screens.count; installMonitor() }
        .onChange(of: screens.count) { screenCount = screens.count }
        .onDisappear { removeMonitor() }
    }

    /// The new screen comes in from the side the swipe is heading to and the
    /// old one leaves by the other, with a gap between them as they pass.
    private var slide: AnyTransition {
        if reduceMotion { return .opacity }
        let forward = direction > 0
        return .asymmetric(
            insertion: .move(edge: forward ? .bottom : .top).combined(with: .opacity),
            removal: .move(edge: forward ? .top : .bottom).combined(with: .opacity))
    }

    private func move(by step: Int) {
        guard step != 0, screenCount > 1 else { return }
        // The leaving screen takes its transition from the render before it
        // goes, so the direction is set a turn ahead of the move.
        direction = step
        DispatchQueue.main.async {
            withAnimation(.smooth(duration: 0.32)) { position += step }
        }
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard hovering, screenCount > 1 else { return event }
            // Sideways swipes belong to whatever is under the pointer.
            guard abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX) else { return event }
            let step = scroll.step(deltaY: event.scrollingDeltaY,
                                   precise: event.hasPreciseScrollingDeltas,
                                   began: event.phase.contains(.began),
                                   ended: event.phase.contains(.ended) || event.phase.contains(.cancelled),
                                   momentum: !event.momentumPhase.isEmpty,
                                   at: Date())
            move(by: step)
            return nil
        }
    }

    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    @ViewBuilder private func screen(_ widgets: [NotchControlItem], size: CGSize) -> some View {
        if widgets == [.calendar] {
            NotchCalendarTimelineWidget(service: service)
        } else {
            let width = (size.width - NotchLayout.cardSpacing * CGFloat(max(0, widgets.count - 1)))
                / CGFloat(max(1, widgets.count))
            HStack(spacing: NotchLayout.cardSpacing) {
                ForEach(widgets) { widget in
                    card(widget, size: CGSize(width: width, height: size.height))
                }
            }
        }
    }

    @ViewBuilder private func card(_ widget: NotchControlItem, size: CGSize) -> some View {
        Group {
            switch widget {
            case .music: NotchMusicWidget(notch: service, size: size)
            case .batteries: NotchBatteriesWidget(size: size)
            default: EmptyView()
            }
        }
        .frame(width: size.width, height: size.height)
        .modifier(NotchControlSurface(cornerRadius: 18, interactive: false))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Batteries

/// Every connected device with a battery, the Mac first, as Apple's
/// Batteries widget lists them: the device's glyph, its name, its charge and
/// a battery drawn to that level. Empty rows keep their lines, so the list
/// reads as the same widget with one device or five.
private struct NotchBatteriesWidget: View {
    let size: CGSize
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var l10n = L10n.shared
    private static let macName = Host.current().localizedName ?? "Mac"

    private struct Row: Identifiable {
        let id: String
        let symbol: String
        let name: String
        let percent: Int
        let charging: Bool
        /// On external power, charging or not: the bolt shows.
        let powered: Bool
    }

    private var rows: [Row] {
        var rows: [Row] = []
        if let power = monitor.snapshot.power, power.hasBattery, let charge = power.chargePercent {
            // A Mac held at its charge limit, or full on its adapter, reports
            // no charge in progress while still plugged in; the bolt follows
            // the adapter, as the menu bar's battery does.
            rows.append(Row(id: "mac", symbol: "laptopcomputer", name: Self.macName, percent: charge,
                            charging: power.isCharging,
                            powered: power.isCharging || power.externalConnected))
        }
        rows += PeripheralBatterySupport.sorted(monitor.snapshot.peripheralBatteries).map { device in
            Row(id: device.id, symbol: NotchAccessorySupport.symbol(for: device.kind, name: device.name),
                name: device.name, percent: device.percent, charging: device.isCharging,
                powered: device.isCharging)
        }
        return rows
    }

    var body: some View {
        let rows = rows
        // Rows of at least 44 points, so two lines each sit with room.
        let slots = max(rows.count, Int(size.height / 44))
        let rowHeight = size.height / CGFloat(max(1, slots))
        VStack(spacing: 0) {
            ForEach(0..<slots, id: \.self) { index in
                Group {
                    if index < rows.count {
                        row(rows[index])
                    } else if index == 0 {
                        Text(FeatureStrings.notch(l10n.language).batteriesEmpty)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 14)
                    } else {
                        Color.clear
                    }
                }
                .frame(height: rowHeight)
                .overlay(alignment: .bottom) {
                    if index < slots - 1 {
                        Rectangle().fill(.white.opacity(0.08)).frame(height: 1).padding(.leading, 44).padding(.trailing, 14)
                    }
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(FeatureStrings.notch(l10n.language).batteriesWidget)
    }

    /// The name has the row to itself and the charge sits under it, so a
    /// name like "Carlton's MacBook Pro" reads whole in a half-width card.
    private func row(_ row: Row) -> some View {
        HStack(spacing: 10) {
            Image(systemName: row.symbol)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(row.percent)%")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            NotchBatteryGlyph(percent: row.percent, charging: row.charging, powered: row.powered)
        }
        .padding(.horizontal, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.name), \(row.percent)%")
    }
}

/// A battery drawn to its level, white, green while charging and red when
/// low, as the system draws it, with a bolt while it is on power.
private struct NotchBatteryGlyph: View {
    let percent: Int
    let charging: Bool
    let powered: Bool

    var body: some View {
        let fill: Color = charging ? .green : percent <= 20 ? .red : .white
        let fillWidth = max(2, 19 * CGFloat(min(100, max(0, percent))) / 100)
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(.white.opacity(0.45), lineWidth: 1)
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(fill)
                    .frame(width: fillWidth)
                    .padding(2)
                if powered {
                    // White over the empty part and black over the level, so
                    // the bolt reads at any charge: a black bolt alone sat on
                    // the dark empty half of a low battery and vanished.
                    ZStack {
                        bolt.foregroundStyle(.white)
                        bolt.foregroundStyle(.black)
                            .mask(alignment: .leading) {
                                Rectangle().frame(width: fillWidth).padding(.leading, 2)
                            }
                    }
                }
            }
            .frame(width: 25, height: 12)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(.white.opacity(0.45))
                .frame(width: 1.5, height: 4)
        }
        .accessibilityHidden(true)
    }

    private var bolt: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: 7, weight: .bold))
            .frame(width: 25, height: 12)
    }
}

// MARK: - Calendar

/// Four hours of today, two either side of now, with now as a red line
/// through the middle. The line stays put and the events move up past it as
/// the time goes. A click on an event opens it on the Calendar page; a
/// click anywhere else opens the page.
private struct NotchCalendarTimelineWidget: View {
    @ObservedObject var service: NotchService
    @ObservedObject private var calendar = NotchCalendarService.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var l10n = L10n.shared
    private var text: NotchCalendarStrings { FeatureStrings.notchCalendar(l10n.language) }
    private static let gutter: CGFloat = 54
    private static let font = Font.system(size: 9.5, weight: .semibold, design: .monospaced)

    var body: some View {
        Group {
            if permissions.calendarAccess == .fullAccess {
                // Every half minute moves the events a fraction of a point,
                // which reads as the day sliding by without redrawing per frame.
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    timeline(now: context.date)
                }
            } else {
                permission
            }
        }
        .modifier(NotchControlSurface(cornerRadius: 18, interactive: false))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func timeline(now: Date) -> some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let width = proxy.size.width - Self.gutter - 6
            let placements = NotchCalendarTimeline.placements(calendar.events, now: now)
            let locale = l10n.language.formattingLocale()
            ZStack(alignment: .topLeading) {
                ForEach(NotchCalendarTimeline.hourMarks(now: now), id: \.date) { mark in
                    let y = mark.position * height
                    Text(Self.clock(mark.date, locale: locale))
                        .font(Self.font)
                        // The now label takes the gutter's middle.
                        .foregroundStyle(.white.opacity(abs(y - height / 2) < 11 ? 0 : 0.5))
                        .frame(width: Self.gutter - 8, alignment: .trailing)
                        .offset(y: y - 6)
                    Rectangle()
                        .fill(.white.opacity(0.08))
                        .frame(width: width + 6, height: 1)
                        .offset(x: Self.gutter, y: y)
                }

                ForEach(placements, id: \.event.id) { placement in
                    // Columns side by side with a clear gap, so no event
                    // ever covers another.
                    let gap: CGFloat = 4
                    let columnWidth = (width + gap) / CGFloat(placement.columns)
                    let top = placement.top * height
                    let bottom = placement.bottom * height
                    let size = CGSize(width: max(0, columnWidth * CGFloat(placement.span) - gap),
                                      height: max(12, bottom - top - 2))
                    Button { service.openCalendarEvent(placement.event.id) } label: {
                        NotchTimelineEvent(event: placement.event, locale: locale, untitled: text.untitled,
                                           size: size)
                    }
                    .buttonStyle(.plain)
                    .help(placement.event.title)
                    .frame(width: size.width, height: size.height)
                    .offset(x: Self.gutter + CGFloat(placement.column) * columnWidth, y: top + 1)
                }

                if placements.isEmpty, !calendar.loading {
                    Text(text.empty)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: width, height: height)
                        .offset(x: Self.gutter)
                }

                // Now, always in the middle.
                Rectangle()
                    .fill(Color.red)
                    .frame(width: width + 6, height: 1.5)
                    .offset(x: Self.gutter, y: height / 2 - 0.75)
                    .allowsHitTesting(false)
                Text(Self.clock(now, locale: locale))
                    .font(Self.font)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.red))
                    .frame(width: Self.gutter + 4, alignment: .trailing)
                    .offset(y: height / 2 - 7)
            }
            .frame(width: proxy.size.width, height: height, alignment: .topLeading)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { service.select(.calendar) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(text.title)
        .accessibilityAddTraits(.isButton)
    }

    private var permission: some View {
        let denied = permissions.calendarAccess == .denied || permissions.calendarAccess == .restricted
        return VStack(spacing: 8) {
            Image(systemName: NotchModule.calendar.symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
            Text(denied ? text.denied : text.permission)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if denied {
                Button(text.settings) { permissions.openCalendarSettings() }
            } else {
                Button(text.allow) { permissions.requestCalendar() }
                    .disabled(permissions.requestingCalendar)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The Mac's own clock format, 24-hour or with AM and PM.
    static func clock(_ date: Date, locale: Locale) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale))
    }
}

/// One event on the timeline: its calendar's colour as a wash with a solid
/// bar down the left, then the title, place and times as far as its card
/// has room for them. A line that would be cut in half is left off.
private struct NotchTimelineEvent: View {
    let event: NotchCalendarEvent
    let locale: Locale
    let untitled: String
    let size: CGSize

    var body: some View {
        let tint = Color(red: event.color.red, green: event.color.green, blue: event.color.blue)
        let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let font = Font.system(size: 9.5, weight: .semibold, design: .monospaced)
        // About 13 points a line under 3 points of padding either side.
        let lines = max(1, Int((size.height - 6) / 13))
        let showsTime = lines >= 2
        let showsLocation = lines >= 3 && !event.location.isEmpty && size.width >= 80
        HStack(alignment: .top, spacing: 0) {
            Rectangle().fill(tint).frame(width: 2.5)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .top, spacing: 4) {
                    Text(title.isEmpty ? untitled : title)
                        .font(font)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if event.recurring, size.width >= 60 {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 7, weight: .bold))
                    }
                }
                if showsLocation {
                    Label(event.location, systemImage: "mappin.circle")
                        .font(.system(size: 9, design: .monospaced))
                        .lineLimit(1)
                        .opacity(0.85)
                }
                if showsTime {
                    Label("\(time(event.start))–\(time(event.end))", systemImage: "clock")
                        .font(.system(size: 9, design: .monospaced))
                        .lineLimit(1)
                        .opacity(0.85)
                }
            }
            .labelStyle(NotchTimelineLabelStyle())
            .foregroundStyle(Self.readable(tint))
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: NSColor(tint).blended(withFraction: 0.72, of: .black) ?? .black))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func time(_ date: Date) -> String { NotchCalendarTimelineWidget.clock(date, locale: locale) }

    /// The calendar's colour lifted toward white, so dark calendars still read
    /// on the black island.
    private static func readable(_ tint: Color) -> Color {
        Color(nsColor: NSColor(tint).blended(withFraction: 0.35, of: .white) ?? NSColor(tint))
    }
}

private struct NotchTimelineLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.font(.system(size: 7.5))
            configuration.title
        }
    }
}
