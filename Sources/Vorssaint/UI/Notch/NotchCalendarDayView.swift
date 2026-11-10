// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// One day's hours top to bottom, as Calendar's Day view shows them: each
/// timed event a block at its time and as tall as it lasts, events that
/// overlap side by side, the all-day ones in a row above, and a line at the
/// present moment on today. It opens scrolled to now (or the day's first
/// event), and scrolls through the whole day. A click opens the event in
/// Calendar, as the agenda's cards do.
struct NotchCalendarDayTimeline: View {
    let day: Date
    let now: Date
    let events: [NotchCalendarEvent]
    let text: NotchCalendarStrings
    let open: (NotchCalendarEvent) -> Void

    static let hourHeight: CGFloat = 40
    private static let labelWidth: CGFloat = 40
    private static let gutter: CGFloat = 6

    private var isToday: Bool { Calendar.current.isDate(day, inSameDayAs: now) }
    private var dayStart: Date { Calendar.current.startOfDay(for: day) }

    var body: some View {
        let allDay = NotchCalendarSupport.events(events, on: day).filter(\.allDay)
        let slots = NotchCalendarSupport.timeline(events, on: day)
        VStack(alignment: .leading, spacing: 6) {
            if !allDay.isEmpty { allDayRow(allDay) }
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        hourGrid
                        GeometryReader { geometry in
                            let lane = max(0, geometry.size.width - Self.labelWidth - Self.gutter)
                            ForEach(slots, id: \.event.id) { slot in
                                block(slot, lane: lane)
                            }
                        }
                        if isToday { nowLine }
                    }
                    .frame(height: 24 * Self.hourHeight)
                    .padding(.vertical, 6)
                }
                .scrollIndicators(.automatic)
                .onAppear { scrollToStart(proxy, slots: slots) }
                .onChange(of: Calendar.current.startOfDay(for: day)) { _, _ in scrollToStart(proxy, slots: slots) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Now on today, the first event on another day, the morning otherwise,
    /// with an hour of room above it.
    private func scrollToStart(_ proxy: ScrollViewProxy, slots: [NotchCalendarSupport.TimelineSlot]) {
        let minute: Double
        if isToday {
            minute = now.timeIntervalSince(dayStart) / 60
        } else {
            minute = slots.map(\.startMinute).min() ?? 8 * 60
        }
        let hour = min(23, max(0, Int(minute / 60) - 1))
        DispatchQueue.main.async { proxy.scrollTo(hour, anchor: .top) }
    }

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: Self.gutter) {
                    Text(Calendar.current.date(byAdding: .hour, value: hour, to: dayStart) ?? dayStart,
                         format: .dateTime.hour())
                        .font(.system(size: 9.5, weight: .medium)).monospacedDigit()
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                        .frame(width: Self.labelWidth, alignment: .trailing)
                        .offset(y: -6)
                        .opacity(hour == 0 ? 0 : 1)
                    Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5)
                }
                .frame(height: Self.hourHeight, alignment: .top)
                .id(hour)
            }
        }
        .accessibilityHidden(true)
    }

    private func block(_ slot: NotchCalendarSupport.TimelineSlot, lane: CGFloat) -> some View {
        let width = lane / CGFloat(slot.columns)
        let top = CGFloat(slot.startMinute / 60) * Self.hourHeight
        let height = max(16, CGFloat((slot.endMinute - slot.startMinute) / 60) * Self.hourHeight - 2)
        let event = slot.event
        let ended = event.end <= now
        return Button { open(event) } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title.isEmpty ? text.untitled : event.title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(ended ? 0.6 : 0.95))
                    .lineLimit(height > 34 ? 2 : 1)
                if height > 30 {
                    Text(event.start, format: .dateTime.hour().minute())
                        .font(.system(size: 9.5)).monospacedDigit()
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }
            .padding(.leading, 7)
            .padding(.trailing, 4)
            .padding(.vertical, 3)
            .frame(width: max(0, width - 2), height: height, alignment: .topLeading)
            .background(event.color.color.opacity(ended ? 0.18 : 0.32),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5).fill(event.color.color).frame(width: 3)
                    .padding(.vertical, 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 6, lifts: false))
        .help(text.openCalendar)
        .accessibilityLabel(Text(event.title.isEmpty ? text.untitled : event.title)
                            + Text(", ") + Text(event.start, format: .dateTime.hour().minute()))
        .offset(x: Self.labelWidth + Self.gutter + CGFloat(slot.column) * width, y: top)
    }

    private var nowLine: some View {
        let y = CGFloat(now.timeIntervalSince(dayStart) / 3600) * Self.hourHeight
        return HStack(spacing: 0) {
            Circle().fill(Color.red).frame(width: 7, height: 7)
            Rectangle().fill(Color.red).frame(height: 1.5)
        }
        .padding(.leading, Self.labelWidth + Self.gutter - 3.5)
        .offset(y: y - 3.5)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func allDayRow(_ events: [NotchCalendarEvent]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                Text(text.allDay)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: Self.labelWidth, alignment: .trailing)
                    .padding(.trailing, Self.gutter - 4)
                ForEach(events) { event in
                    Button { open(event) } label: {
                        Text(event.title.isEmpty ? text.untitled : event.title)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .frame(height: 20)
                            .background(event.color.color.opacity(0.3), in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(NotchButtonStyle(cornerRadius: 10, lifts: false))
                    .help(text.openCalendar)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
