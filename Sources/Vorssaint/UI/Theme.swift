// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Shared look & feel: brand colors, card styling and the brand mark.
enum Theme {
    /// Near-black background behind the brand mark. Neutral greys into black, no
    /// colour cast, with just a hint of depth so the badge does not read as flat.
    static let spaceGradient = LinearGradient(
        colors: [Color(white: 0.10),
                 Color(white: 0.04),
                 Color.black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum PanelMetricColor {
    static func green(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.00, green: 0.44, blue: 0.18) : .green
    }

    static func cyan(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.00, green: 0.43, blue: 0.54) : .cyan
    }

    static func mint(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.00, green: 0.44, blue: 0.40) : .mint
    }

    static func yellow(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.56, green: 0.36, blue: 0.00) : .yellow
    }

    static func red(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.68, green: 0.08, blue: 0.10) : .red
    }

    static func orange(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.68, green: 0.30, blue: 0.00) : .orange
    }

    static func pink(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.68, green: 0.06, blue: 0.34) : .pink
    }
}

private struct NotchPresentationKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var notchPresentation: Bool {
        get { self[NotchPresentationKey.self] }
        set { self[NotchPresentationKey.self] = newValue }
    }
}

enum PanelSurface {
    /// Whether the menu popover hosts the panel across its whole balloon, so the
    /// panel's own surface can reach the arrow (#1030). Only macOS 26 lays the
    /// content out that way. On macOS 15, `hasFullSizeContent` publishes the
    /// full-size safe area but leaves the view at its content size in the frame's
    /// lower-left corner: the popover grows by that safe area, the panel sits off
    /// center, and a band of system material shows along the top and right edges.
    static var popoverHostsFullSizeContent: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }

    static func baseFill(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.white.opacity(0.68) : Color.black.opacity(0.42)
    }

    static func cardFill(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.white.opacity(0.38) : Color.white.opacity(0.075)
    }

    static func controlFill(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.black.opacity(0.055) : Color.white.opacity(0.085)
    }

    /// Raised contrast is asked for by someone who cannot see a hairline at a
    /// tenth of an opacity, so the outlines that separate one card from the
    /// next are the ones that answer. A panel is rebuilt every time it opens,
    /// which is when a change to this setting shows.
    static func border(for scheme: ColorScheme) -> Color {
        let raised = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        return scheme == .light
            ? Color.black.opacity(raised ? 0.24 : 0.09)
            : Color.white.opacity(raised ? 0.28 : 0.11)
    }

    /// A control that sits ON a glass surface rather than in it: the system's
    /// own round toggles read as physical because they are lighter than what
    /// is behind them and carry their own shadow.
    static func raisedFill(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.white.opacity(0.88) : Color.white.opacity(0.14)
    }

    static func raisedBorder(for scheme: ColorScheme) -> Color {
        let raised = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        return scheme == .light
            ? Color.black.opacity(raised ? 0.22 : 0.07)
            : Color.white.opacity(raised ? 0.32 : 0.16)
    }

    static func raisedShadow(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.black.opacity(0.14) : Color.black.opacity(0.38)
    }

    /// The lit edge of a glass surface: bright where the light comes from,
    /// gone by the bottom. Without it a translucent panel reads as paper.
    static func rimHighlight(for scheme: ColorScheme) -> LinearGradient {
        LinearGradient(colors: [Color.white.opacity(scheme == .light ? 0.95 : 0.30),
                                Color.white.opacity(scheme == .light ? 0.12 : 0.04)],
                       startPoint: .top,
                       endPoint: .bottom)
    }
}

func sectionTitle(_ text: String) -> some View {
    Text(text.uppercased())
        .font(.system(size: 10, weight: .semibold))
        .kerning(0.5)
        .foregroundStyle(.secondary)
}

extension View {
    /// The rounded card background used by every panel section. A card
    /// holding a list of rows is not padded: each row brings its own insets,
    /// so hover highlights and separators can reach the card's edges.
    func panelCard(interactive: Bool = true, padded: Bool = true) -> some View {
        modifier(PanelCardModifier(interactive: interactive, padded: padded))
    }

    /// A restrained glass base for the menu panel: still translucent, but with a
    /// stable tint so text and controls do not depend too much on the wallpaper.
    /// It reaches the popover's arrow; see PanelGlassSurface.
    func panelGlassSurface() -> some View {
        background(PanelGlassSurface())
    }
}

private struct PanelCardModifier: ViewModifier {
    var interactive: Bool
    var padded = true
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.notchPresentation) private var notchPresentation

    func body(content: Content) -> some View {
        if notchPresentation {
            content.padding(padded ? 12 : 0).modifier(NotchControlSurface(cornerRadius: 18, interactive: interactive))
        } else {
        content
            .padding(padded ? 10 : 0)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PanelSurface.cardFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(PanelSurface.border(for: colorScheme), lineWidth: 0.7)
            )
        }
    }
}

private struct PanelGlassSurface: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.notchPresentation) private var notchPresentation
    @Environment(\.notchGlassSurface) private var notchGlassSurface
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(DefaultsKey.liquidGlassEnabled) private var liquidGlassEnabled = false

    var body: some View {
        // AppKit hands the hosted panel a safe area for the popover's border and
        // arrow, so a surface that stopped at the panel would leave the tip in the
        // plain system material. The panel content keeps that inset and never sits
        // under the arrow; only this background bleeds into it. The popover clips
        // it to its own balloon, so the surface is a plain rectangle: rounding would
        // expose the system material at the corners, while stroking would duplicate
        // the outline AppKit already draws. Where the popover still insets its
        // content, the panel is a card inside the balloon instead; see
        // PanelSurface.popoverHostsFullSizeContent.
        if notchPresentation {
            Rectangle().fill(notchGlassSurface ? Color.clear : .black)
        } else if PanelSurface.popoverHostsFullSizeContent {
            surface.ignoresSafeArea()
        } else {
            insetSurface
        }
    }

    @ViewBuilder
    private var surface: some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *), liquidGlassEnabled, !reduceTransparency {
            Rectangle()
                .fill(Color.clear)
                .glassEffect(.regular, in: Rectangle())
                .overlay(
                    Rectangle()
                        .fill(PanelSurface.baseFill(for: colorScheme).opacity(colorScheme == .light ? 0.35 : 0.45))
                )
        } else {
            standardSurface
        }
#else
        standardSurface
#endif
    }

    @ViewBuilder
    private var standardSurface: some View {
        Rectangle()
            .fill(.regularMaterial)
            .overlay(Rectangle().fill(PanelSurface.baseFill(for: colorScheme)))
    }

    /// The panel as a card inside a popover that insets its content (before
    /// macOS 26): the balloon's rounding never reaches it there, so it carries
    /// its own rounding and rim. Liquid Glass needs macOS 26, so this is always
    /// the standard material.
    private var insetSurface: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return shape
            .fill(.regularMaterial)
            .overlay(shape.fill(PanelSurface.baseFill(for: colorScheme)))
            .overlay(shape.strokeBorder(PanelSurface.border(for: colorScheme), lineWidth: 0.8))
    }
}

func appDelegate() -> AppDelegate? {
    NSApp.delegate as? AppDelegate
}

/// The official mark (Resources/Brand/logo.png, trimmed at build time),
/// tintable for light or dark surfaces.
struct BrandMark: View {
    var width: CGFloat
    var tint: Color = .white

    private static let mark: NSImage? = {
        guard let url = Bundle.main.url(forResource: "BrandMark", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }()

    var body: some View {
        if let mark = Self.mark {
            Image(nsImage: mark)
                .renderingMode(.template)
                .interpolation(.high)
                .antialiased(true)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(tint)
                .frame(width: width)
        } else {
            Image(systemName: "circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(tint)
                .frame(width: width * 0.5)
        }
    }
}

struct DiscordMark: View {
    var width: CGFloat

    private static let mark: NSImage? = {
        guard let url = Bundle.main.url(forResource: "discord-symbol",
                                        withExtension: "svg",
                                        subdirectory: "Images") else { return nil }
        return NSImage(contentsOf: url)
    }()

    var body: some View {
        if let mark = Self.mark {
            Image(nsImage: mark)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width)
        }
    }
}

/// The Obsidian logo for the pad that edits Obsidian notes. It is drawn as a
/// template so it takes the tint of the row it sits in, like the SF Symbols
/// beside it.
/// The VERTUS logo (hexagon mark and wordmark), white on nothing, as a
/// template image. Falls back to the drawn hexagon mark.
struct VertusWordmark: View {
    var height: CGFloat

    private static let mark: NSImage? = {
        guard let url = Bundle.main.url(forResource: "vertus-wordmark",
                                        withExtension: "png",
                                        subdirectory: "Images"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        return image
    }()

    var body: some View {
        if let mark = Self.mark {
            Image(nsImage: mark)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: height)
        } else {
            VertusMark().fill(style: FillStyle(eoFill: true)).frame(width: height * 0.87, height: height)
        }
    }
}

/// Instinct's wordmark, white letters on nothing, as a template image so it
/// takes the island's colour. Falls back to the drawn serif I.
struct InstinctWordmark: View {
    var height: CGFloat

    private static let mark: NSImage? = {
        guard let url = Bundle.main.url(forResource: "instinct-wordmark",
                                        withExtension: "png",
                                        subdirectory: "Images"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        return image
    }()

    var body: some View {
        if let mark = Self.mark {
            Image(nsImage: mark)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: height)
        } else {
            InstinctMark().fill().frame(width: height * 0.4, height: height)
        }
    }
}

/// An iMessage agent's mark beside the pages button: its logo, then its
/// name in capitals, spaced and bold, the way VERTUS shows its hexagon and
/// name, in the island's black and white like the other marks.
struct MessagesAgentWordmark: View {
    let name: String
    let height: CGFloat
    /// The agent's logo as a template; without one, the name alone.
    var mark: NSImage? = nil

    var body: some View {
        HStack(spacing: height * 0.4) {
            if let mark {
                Image(nsImage: mark)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: height * 1.15)
            }
            Text(name)
                .font(.system(size: height * 0.95, weight: .bold))
                .tracking(height * 0.12)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(height: height)
    }
}

/// Each iMessage agent's own logo, the glyph from its app icon on its
/// website cut out as a white template, so it takes the island's colours
/// like VERTUS's and Instinct's marks. Loaded once per agent.
enum MessagesAgentMark {
    private static var cache: [NotchMessagesAgent: NSImage] = [:]

    static func image(for agent: NotchMessagesAgent) -> NSImage? {
        if let image = cache[agent] { return image }
        guard let url = Bundle.main.url(forResource: "agent-\(agent.rawValue)-mark", withExtension: "png",
                                        subdirectory: "Images"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        cache[agent] = image
        return image
    }
}

/// SIRI's mark beside the pages button: its ring-and-wave mark and the name,
/// in the island's black and white like the other agents' marks.
struct SiriWordmark: View {
    var height: CGFloat

    var body: some View {
        HStack(spacing: height * 0.35) {
            SiriMark()
                .frame(width: height * 1.15, height: height * 1.15)
            Text("SIRI")
                .font(.system(size: height * 0.95, weight: .bold))
                .tracking(height * 0.12)
        }
        .frame(height: height)
    }
}

/// SIRI's mark: a ring with a wave running through it, drawn as strokes so it
/// takes the island's white at any size.
struct SiriMark: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let line = side * 0.1
            ZStack {
                Circle()
                    .inset(by: line / 2)
                    .stroke(lineWidth: line)
                SiriMarkWave()
                    .stroke(style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// The wave inside the ring: in from the left a little below the middle, over
/// a crest left of centre, down through a trough and into the ring's lower
/// right, as Siri's mark has it.
struct SiriMarkWave: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let line = side * 0.1
        let r = side / 2 - line / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        func onRing(_ degrees: Double) -> CGPoint {
            let a = degrees * .pi / 180
            return CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
        }
        var path = Path()
        path.move(to: onRing(172))
        path.addCurve(to: onRing(22),
                      control1: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.48),
                      control2: CGPoint(x: c.x + r * 0.18, y: c.y + r * 0.62))
        return path
    }
}

struct ObsidianMark: View {
    var width: CGFloat

    private static let mark: NSImage? = {
        guard let url = Bundle.main.url(forResource: "obsidian",
                                        withExtension: "png",
                                        subdirectory: "Images"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        return image
    }()

    var body: some View {
        if let mark = Self.mark {
            Image(nsImage: mark)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width)
        } else {
            Image(systemName: "note.text")
        }
    }
}

/// Squircle badge with the mark on the space gradient — the app's face in the
/// About tab and onboarding.
struct BrandBadge: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(Theme.spaceGradient)
            BrandMark(width: size * 0.8)
        }
        .frame(width: size, height: size)
    }
}
