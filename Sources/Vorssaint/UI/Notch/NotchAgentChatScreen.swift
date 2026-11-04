// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Every agent's conversation on one screen: a sidebar of the agents on the
/// left, and the chosen agent's own page beside it. Each page is the one the
/// agent always had, so VERTUS on this Mac or over iMessage, Instinct's
/// iMessage thread and Siri on Apple's model keep every control they offer,
/// and the chosen agent's mark stays at the top left. Only the conversation
/// changes when another agent is picked; the sidebar stays where it is.
struct NotchAgentChatScreen: View {
    @ObservedObject var service: NotchService
    let size: CGSize
    @ObservedObject private var l10n = L10n.shared
    /// The agent being dragged to a new place, the order shown while it
    /// moves, the place it started from and how far it sits from its slot.
    @State private var dragging: NotchModule?
    @State private var dragOrder: [NotchModule]?
    @State private var dragStart = 0
    @State private var dragOffset: CGFloat = 0

    static let sidebarWidth: CGFloat = 40
    static let sidebarSpacing: CGFloat = 10
    static let tileSide: CGFloat = 30
    static let tileSpacing: CGFloat = 8

    var body: some View {
        let agents = service.modules.filter(\.isAgentChat)
        // A lone agent has nothing to choose between.
        let showsSidebar = agents.count > 1
        let pageWidth = size.width - (showsSidebar ? Self.sidebarWidth + Self.sidebarSpacing : 0)
        HStack(alignment: .top, spacing: Self.sidebarSpacing) {
            if showsSidebar {
                sidebar(agents)
            }
            page(CGSize(width: max(0, pageWidth), height: size.height))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Each agent keeps its own draft, focus and swipe handling.
                .id(service.selected)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private func page(_ size: CGSize) -> some View {
        switch service.selected {
        case .instinctChat: NotchHermesChatView(size: size, chat: .instinct)
        case .siriChat: NotchSiriPage(size: size)
        default:
            // VERTUS, or an iMessage agent on Instinct's page with its own thread.
            NotchHermesChatView(size: size, chat: NotchHermesChatService.service(for: service.selected) ?? .shared)
        }
    }

    /// The agents, in the island's section order: drag one to move it, click
    /// one (or press Command and its place) to talk to it.
    private func sidebar(_ agents: [NotchModule]) -> some View {
        let shown = dragOrder ?? agents
        return ScrollView(.vertical) {
            VStack(spacing: Self.tileSpacing) {
                ForEach(Array(shown.enumerated()), id: \.element) { index, agent in
                    NotchAgentSidebarTile(agent: agent, selected: agent == service.selected,
                                          title: agent.title(l10n.language), place: index + 1) {
                        if agent != service.selected { service.select(agent) }
                    }
                    .offset(y: agent == dragging ? dragOffset : 0)
                    .zIndex(agent == dragging ? 1 : 0)
                    .scaleEffect(agent == dragging ? 1.08 : 1)
                    // A pointer drag, not a drag-and-drop: a drop over the
                    // conversation would attach the agent's name to the message.
                    .gesture(reorder(agent, in: agents))
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .animation(.easeOut(duration: 0.15), value: shown)
        }
        .scrollIndicators(.never)
        .frame(width: Self.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(FeatureStrings.notch(l10n.language).agentChat)
    }

    private func reorder(_ agent: NotchModule, in agents: [NotchModule]) -> some Gesture {
        let pitch = Self.tileSide + Self.tileSpacing
        return DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragging == nil {
                    dragging = agent
                    dragOrder = agents
                    dragStart = agents.firstIndex(of: agent) ?? 0
                }
                guard var order = dragOrder, let current = order.firstIndex(of: agent) else { return }
                let target = min(order.count - 1, max(0, dragStart + Int((value.translation.height / pitch).rounded())))
                if target != current {
                    order.move(fromOffsets: IndexSet(integer: current), toOffset: target > current ? target + 1 : target)
                    dragOrder = order
                }
                dragOffset = value.translation.height - CGFloat(target - dragStart) * pitch
            }
            .onEnded { _ in
                if let order = dragOrder, order != agents { service.reorderAgentChats(order) }
                withAnimation(.easeOut(duration: 0.15)) {
                    dragging = nil
                    dragOrder = nil
                    dragOffset = 0
                }
            }
    }
}

/// One agent in the sidebar: its mark on a rounded square, lit while it is
/// the agent being talked to.
private struct NotchAgentSidebarTile: View {
    let agent: NotchModule
    let selected: Bool
    let title: String
    /// Its place in the list, which Command and that number chooses.
    let place: Int
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        // A tap rather than a button, so the drag that reorders the list
        // starts on the tile without the button swallowing it.
        mark
            .foregroundStyle(selected ? .black : .white.opacity(0.85))
            .frame(width: NotchAgentChatScreen.tileSide, height: NotchAgentChatScreen.tileSide)
            .background(selected ? Color.white.opacity(0.9) : Color.white.opacity(hovering ? 0.16 : 0.09), in: shape)
            .overlay { shape.strokeBorder(.white.opacity(selected ? 0 : 0.08), lineWidth: 1) }
            .contentShape(shape)
            .onTapGesture(perform: action)
            .onHover { hovering = $0 }
            .help(place <= 9 ? "\(title)  ⌘\(place)" : title)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { action() }
    }

    @ViewBuilder private var mark: some View {
        switch agent {
        case .instinctChat:
            InstinctMark().fill().frame(width: 6, height: 14)
        case .siriChat:
            SiriMark().frame(width: 15, height: 15)
        case .museChat:
            // No drawn mark of Meta's here: the agent's initial, as the
            // iMessage agents have.
            Text("M").font(.system(size: 14, weight: .bold))
        case _ where agent.messagesAgent != nil:
            // No drawn mark of its own: the agent's initial.
            Text(String(agent.messagesAgent?.name.prefix(1) ?? ""))
                .font(.system(size: 14, weight: .bold))
        default:
            VertusMark().fill(style: FillStyle(eoFill: true)).frame(width: 13, height: 15)
        }
    }
}
