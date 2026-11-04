// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The Controls page's card row: the widget stack, square, and the calendar's
/// four hours beside it. Either takes the whole row when the other is hidden.
struct NotchControlCards: View {
    @ObservedObject var service: NotchService
    let items: [NotchControlItem]
    let height: CGFloat

    var body: some View {
        let widgets = items.filter(\.isWidget)
        let calendar = items.contains(.calendar)
        GeometryReader { proxy in
            HStack(spacing: NotchLayout.cardSpacing) {
                if !widgets.isEmpty {
                    // A third of the row, as designed, and never narrower than
                    // square, so the batteries keep room for their names.
                    NotchWidgetStack(service: service, widgets: widgets, height: height,
                                     width: calendar ? max(height, proxy.size.width * 0.34) : nil)
                }
                if calendar {
                    NotchCalendarTimelineWidget(service: service)
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                }
            }
        }
        .frame(height: height)
    }
}

/// Widgets stacked as Apple's Smart Stack stacks them: one shows at a time,
/// a vertical swipe or scroll pages to the next, and the dots beside the
/// stack say which one it is and jump to another.
private struct NotchWidgetStack: View {
    @ObservedObject var service: NotchService
    let widgets: [NotchControlItem]
    let height: CGFloat
    /// Its width beside the calendar; alone it takes the row.
    let width: CGFloat?
    @State private var current: NotchControlItem?
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let shown = current.flatMap { widgets.contains($0) ? $0 : nil } ?? widgets[0]
        HStack(spacing: 8) {
            GeometryReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(widgets) { widget in
                            page(widget, size: proxy.size)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .id(widget)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $current)
                .scrollIndicators(.hidden)
                .scrollDisabled(widgets.count < 2)
            }
            .frame(width: width)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .frame(height: height)
            .modifier(NotchControlSurface(cornerRadius: 18, interactive: false))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if widgets.count > 1 {
                dots(shown: shown)
            }
        }
    }

    @ViewBuilder private func page(_ widget: NotchControlItem, size: CGSize) -> some View {
        switch widget {
        case .music: NotchMusicWidget(notch: service, size: size)
        case .batteries: NotchBatteriesWidget(size: size)
        default: EmptyView()
        }
    }

    private func dots(shown: NotchControlItem) -> some View {
        VStack(spacing: 8) {
            ForEach(widgets) { widget in
                Button {
                    withAnimation(.easeOut(duration: 0.25)) { current = widget }
                } label: {
                    Circle()
                        .fill(.white.opacity(widget == shown ? 0.95 : 0.35))
                        .frame(width: 6, height: 6)
                        .frame(width: 12, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(widget.title(l10n))
                .accessibilityLabel(widget.title(l10n))
                .accessibilityAddTraits(widget == shown ? .isSelected : [])
            }
        }
        .frame(width: 12)
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
    }

    private var rows: [Row] {
        var rows: [Row] = []
        if let power = monitor.snapshot.power, power.hasBattery, let charge = power.chargePercent {
            rows.append(Row(id: "mac", symbol: "laptopcomputer", name: Self.macName, percent: charge,
                            charging: power.isCharging))
        }
        rows += PeripheralBatterySupport.sorted(monitor.snapshot.peripheralBatteries).map { device in
            Row(id: device.id, symbol: NotchAccessorySupport.symbol(for: device.kind, name: device.name),
                name: device.name, percent: device.percent, charging: false)
        }
        return rows
    }

    var body: some View {
        let rows = rows
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
                        Rectangle().fill(.white.opacity(0.08)).frame(height: 1).padding(.leading, 38)
                    }
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(FeatureStrings.notch(l10n.language).batteriesWidget)
    }

    private func row(_ row: Row) -> some View {
        HStack(spacing: 8) {
            Image(systemName: row.symbol)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 18)
            Text(row.name)
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            Text("\(row.percent)%")
                .font(.system(size: 11.5).monospacedDigit())
                .foregroundStyle(.white.opacity(0.75))
            NotchBatteryGlyph(percent: row.percent, charging: row.charging)
        }
        .padding(.horizontal, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.name), \(row.percent)%")
    }
}

/// A battery drawn to its level, white, green while charging and red when
/// low, as the system draws it.
private struct NotchBatteryGlyph: View {
    let percent: Int
    let charging: Bool

    var body: some View {
        let fill: Color = charging ? .green : percent <= 20 ? .red : .white
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(.white.opacity(0.45), lineWidth: 1)
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(fill)
                    .frame(width: max(2, 19 * CGFloat(min(100, max(0, percent))) / 100))
                    .padding(2)
                if charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: 25, height: 12)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(.white.opacity(0.45))
                .frame(width: 1.5, height: 4)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Calendar

/// Four hours of today, two either side of now, with now as a red line
/// through the middle. The line stays put and the events move up past it as
/// the time goes. A click opens the Calendar page.
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
                    let inset = CGFloat(placement.depth) * 12
                    let columnWidth = (width - inset) / CGFloat(placement.columns)
                    let top = placement.top * height
                    let bottom = placement.bottom * height
                    NotchTimelineEvent(event: placement.event, locale: locale, untitled: text.untitled)
                        .frame(width: max(0, columnWidth - 3), height: max(10, bottom - top - 2))
                        .offset(x: Self.gutter + inset + CGFloat(placement.column) * columnWidth, y: top + 1)
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
/// bar down the left, then the title, place and times as far as it has room.
private struct NotchTimelineEvent: View {
    let event: NotchCalendarEvent
    let locale: Locale
    let untitled: String

    var body: some View {
        let tint = Color(red: event.color.red, green: event.color.green, blue: event.color.blue)
        let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let font = Font.system(size: 9.5, weight: .semibold, design: .monospaced)
        HStack(alignment: .top, spacing: 0) {
            Rectangle().fill(tint).frame(width: 2.5)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .top, spacing: 4) {
                    Text(title.isEmpty ? untitled : title)
                        .font(font)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if event.recurring {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 7, weight: .bold))
                    }
                }
                if !event.location.isEmpty {
                    Label(event.location, systemImage: "mappin.circle")
                        .font(.system(size: 9, design: .monospaced))
                        .lineLimit(1)
                        .opacity(0.85)
                }
                Label("\(time(event.start))–\(time(event.end))", systemImage: "clock")
                    .font(.system(size: 9, design: .monospaced))
                    .lineLimit(1)
                    .opacity(0.85)
            }
            .labelStyle(NotchTimelineLabelStyle())
            .foregroundStyle(Self.readable(tint))
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        // Solid, so an event stepped in over another hides what is under it.
        .background(Color(nsColor: NSColor(tint).blended(withFraction: 0.72, of: .black) ?? .black))
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
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
