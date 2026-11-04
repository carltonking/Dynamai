// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The scratchpad's document inside the island: the editor or its formatted
/// reading fills the page, and the island's top row holds the pads. Beside
/// the camera the chosen pad's name opens a menu of the pads and what a pad
/// can do; a full row keeps the tabs, and the chosen tab opens that menu.
/// Everything the floating pad does, at the island's size: tabs close from
/// their own cross, Command-T and Command-W work, a new or chosen pad puts
/// the caret in its text, and a cleared pad comes back with one undo.
struct NotchScratchpadView: View {
    @ObservedObject var service: NotchService
    @ObservedObject private var pad = ScratchpadService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.notchBand) private var band
    @State private var loadFailed = false
    @State private var copied = false
    @State private var hoveredPadID: UUID?
    @State private var editor = EditorHandle()
    @AppStorage(DefaultsKey.scratchpadTextSize) private var storedTextSize = ScratchpadSupport.defaultTextSize
    private var text: ScratchpadFeatureStrings { FeatureStrings.scratchpad(l10n.language) }
    private var textSize: CGFloat { CGFloat(ScratchpadSupport.sanitizedTextSize(storedTextSize)) }
    private static let editorInset = NSSize(width: 6, height: 6)

    /// Holds the editor's text view so a tab change can aim the caret at it
    /// and a clear or a checkbox click can go through its undo. Weak, since
    /// the view belongs to the editor.
    private final class EditorHandle {
        weak var view: NSTextView?
    }

    private var selectedPad: ScratchpadPad? { pad.pads.first { $0.id == pad.selectedPadID } }

    /// The live editor, apart from `body` so the compiler checks it alone.
    private var textEditor: some View {
        PlainTextEditor(text: $pad.text, fontSize: textSize,
                        textColor: .white,
                        textContainerInset: Self.editorInset,
                        usesFindBar: true,
                        completesTaskBoxes: true,
                        continuesLists: true,
                        onCommandReturn: { pad.togglePreview() },
                        isActive: !pad.isPreviewing,
                        livePreview: true,
                        onToggleTask: { pad.toggleTask(box: $0, through: editor.view) },
                        onOpenWikilink: { pad.openLinkedNote($0) },
                        wikilinkNames: { pad.wikilinkNoteNames() },
                        resolveEmbed: { pad.embedURL(for: $0) }) { view in
            view.insertionPointColor = .white
            editor.view = view
            installTitle(in: view)
            DispatchQueue.main.async { focusEditor() }
        }
    }

    /// The note itself: the editor, with the note's name as its title, or
    /// its formatted reading.
    private var notePage: some View {
        ZStack(alignment: .topLeading) {
            textEditor
            .opacity(pad.isPreviewing ? 0 : 1)
            .allowsHitTesting(!pad.isPreviewing)
            .accessibilityHidden(pad.isPreviewing)
            if pad.isPreviewing {
                MarkdownPreview(blocks: ScratchpadSupport.markdownPreview(pad.text),
                                baseSize: textSize,
                                taskStates: (done: text.taskDone, notDone: text.taskNotDone),
                                onToggleTask: { pad.toggleTask(box: $0, through: editor.view) })
            } else if pad.text.isEmpty {
                Text(text.placeholder)
                    .font(.system(size: textSize))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.leading, Self.editorInset.width + PlainTextEditor.lineFragmentPadding)
                    .padding(.top, Self.editorInset.height + titleHeight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(NotchControlSurface(cornerRadius: 12, interactive: false))
    }

    var body: some View {
        Group {
            if loadFailed, pad.vaultPath == nil {
                NotchEmptyView(symbol: "folder.badge.questionmark", message: text.vaultMissing)
            } else if loadFailed {
                NotchEmptyView(symbol: "exclamationmark.triangle", message: text.loadFailed)
            } else {
                VStack(spacing: 6) {
                    // The marks open under the row, above the text they format.
                    if pad.marksExpanded {
                        markRow
                    }
                    if pad.saveFailed {
                        Label(text.saveFailed, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    notePage
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .notchBand(leading: {
            if !loadFailed { padControls }
        }, trailing: {
            if !loadFailed { noteActions }
        })
        .onAppear { loadFailed = !pad.loadForEmbedding() }
        // A vault chosen in Settings while this page is up loads its notes
        // here, rather than leaving the page on the error until it reopens.
        .onChange(of: pad.vaultPath) { _, _ in loadFailed = !pad.loadForEmbedding() }
        .onDisappear { pad.commitEdits() }
        .onChange(of: textSize) { _, _ in
            if let view = editor.view { installTitle(in: view) }
        }
        .onChange(of: pad.selectedPadID) { _, _ in
            DispatchQueue.main.async { focusEditor() }
        }
        .onChange(of: pad.isPreviewing) { _, previewing in
            guard let view = editor.view else { return }
            if previewing {
                pad.hideFindBar(in: view)
                if view.window?.firstResponder === view || PlainTextEditor.findBarHasKeyboard(in: view.window) {
                    view.window?.makeFirstResponder(nil)
                }
            } else {
                DispatchQueue.main.async {
                    // Preview closed the bar and took the keyboard, so a bar
                    // up now was opened by Command-F and a focused text was
                    // given the keyboard by Command-G, both on their way out
                    // of preview. Either keeps its focus and the match.
                    guard view.enclosingScrollView?.isFindBarVisible != true,
                          view.window?.firstResponder !== view else { return }
                    focusEditor()
                }
            }
        }
        .onChange(of: service.scratchpadCloseSerial) { _, _ in
            guard let selectedPad else { return }
            requestClose(selectedPad)
        }
        .onChange(of: service.scratchpadFindSerial) { _, _ in
            pad.performFind(service.scratchpadFindAction, in: editor.view)
        }
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            copied = false
        }
    }

    private var tabStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(pad.pads) { entry in tab(entry).id(entry.id) }
                }
            }
            .scrollIndicators(.hidden)
            .frame(height: 28)
            .onAppear {
                guard let selected = pad.selectedPadID else { return }
                proxy.scrollTo(selected, anchor: .center)
            }
            .onChange(of: pad.selectedPadID) { _, selected in
                guard let selected else { return }
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(selected, anchor: .center) }
            }
        }
    }

    private var markRow: some View {
        ScratchpadFormatBar(style: .island, editor: editor.view)
            .frame(height: 28)
    }

    /// Beside the camera the row has room for one pad: the chosen one's name
    /// opens the list of pads and what a pad can do. A full row keeps the
    /// tabs, with the way to a new pad after them.
    @ViewBuilder private var padControls: some View {
        if band.besideCamera {
            NotchMenuButton(title: text.padActions, items: [], cornerRadius: 9,
                            makeItems: { padItems(listsPads: true) }) {
                NotchBandMenuLabel(title: pad.selectedPadName)
            }
            .help(text.padActions)
            .accessibilityValue(pad.selectedPadName)
        } else {
            HStack(spacing: 6) {
                tabStrip
                NotchMenuButton(title: text.openNote, items: [], cornerRadius: 9, makeItems: vaultItems) {
                    Image(systemName: "folder")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 28, height: 28)
                        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .help(text.openNote)
                NotchIconButton(symbol: "plus", title: newPadTitle) {
                    pad.createPad(defaultName: text.newNoteName)
                }
                .disabled(!pad.canCreatePad)
            }
        }
    }

    private var noteActions: some View {
        HStack(spacing: 6) {
            NotchIconButton(symbol: "textformat",
                            title: text.formatMarks,
                            selected: pad.marksExpanded) {
                withAnimation(.easeOut(duration: 0.15)) { pad.toggleMarks() }
            }
            .disabled(pad.isPreviewing)
            NotchIconButton(symbol: pad.isPreviewing ? "pencil" : "eye",
                            title: pad.isPreviewing ? text.editText : text.previewFormatting,
                            selected: pad.isPreviewing, action: pad.togglePreview)
                .disabled(pad.text.isEmpty)
            NotchIconButton(symbol: copied ? "checkmark" : "doc.on.doc", title: copied ? text.copied : text.copyAll) {
                pad.copyAll()
                copied = true
            }
            .disabled(pad.text.isEmpty)
        }
    }

    private var newPadTitle: String {
        pad.canCreatePad ? text.newPad : String(format: text.padLimitFormat, ScratchpadDocument.maximumPadCount)
    }

    /// The pads, where the row shows only the chosen one, then what a pad
    /// can do, each with the confirmation or dialog it always had.
    private func padItems(listsPads: Bool) -> [NotchMenuItem] {
        let current = selectedPad
        var items: [NotchMenuItem] = []
        if listsPads, !pad.pads.isEmpty {
            items = pad.pads.map { entry in
                NotchMenuItem(title: entry.name, checked: entry.id == pad.selectedPadID) { pad.selectPad(entry.id) }
            }
            items.append(.separator)
        }
        items += [
            NotchMenuItem(title: newPadTitle, enabled: pad.canCreatePad) { pad.createPad(defaultName: text.newNoteName) },
            NotchMenuItem(title: text.openNote, symbol: "folder", children: vaultItems()),
            NotchMenuItem(title: text.renamePad, enabled: current != nil) {
                if let current { presentRename(current) }
            },
            NotchMenuItem(title: text.closePad, enabled: current != nil && pad.canClosePad) {
                if let current { requestClose(current) }
            },
            .separator,
            NotchMenuItem(title: text.exportAction, enabled: !pad.text.isEmpty) {
                guard let window = service.presentationWindow else { return }
                pad.exportText(suggestedName: ScratchpadSupport.exportFileName(title: pad.selectedPadName, date: Date()),
                               from: window)
            },
            NotchMenuItem(title: text.clearAction, enabled: !pad.text.isEmpty) { pad.clear(through: editor.view) },
            .separator,
            NotchMenuItem(title: text.openButton) { service.perform { pad.show(allowsIsland: false) } }
        ]
        return items
    }

    /// Every note in the vault, folders as submenus, as Obsidian's file list
    /// lays them out. Built when a menu opens, since it reads the vault.
    private func vaultItems() -> [NotchMenuItem] {
        func items(_ nodes: [ScratchpadVaultNode]) -> [NotchMenuItem] {
            nodes.map { node in
                guard let children = node.children else {
                    return NotchMenuItem(title: node.name, checked: pad.pads.contains { $0.path == node.path },
                                         symbol: "doc.text") { pad.openVaultNote(node.path) }
                }
                return NotchMenuItem(title: node.name, symbol: "folder", children: items(children))
            }
        }
        let notes = items(pad.vaultNoteTree())
        return notes.isEmpty ? [NotchMenuItem(title: text.vaultMissing, enabled: false)] : notes
    }

    /// The chosen tab opens the pad's menu, as the pad's name does beside the
    /// camera. Another tab shows its cross under the pointer, as in the
    /// floating pad, while the strip keeps two pads or more.
    private func tab(_ entry: ScratchpadPad) -> some View {
        let selected = entry.id == pad.selectedPadID
        return Group {
            if selected {
                NotchMenuButton(title: text.padActions, items: [], cornerRadius: 11,
                                makeItems: { padItems(listsPads: false) }) {
                    tabLabel(entry, selected: true)
                }
                .accessibilityValue(entry.name)
            } else {
                Button { pad.selectPad(entry.id) } label: { tabLabel(entry, selected: false) }
                    .buttonStyle(NotchButtonStyle(cornerRadius: 11, lifts: false))
            }
        }
        .onHover { hovering in
            if hovering { hoveredPadID = entry.id } else if hoveredPadID == entry.id { hoveredPadID = nil }
        }
        .contextMenu {
            Button(text.renamePad) { presentRename(entry) }
            Button(text.closePad) { requestClose(entry) }
                .disabled(!pad.canClosePad)
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(selected ? text.padActions : entry.name)
    }

    private func tabLabel(_ entry: ScratchpadPad, selected: Bool) -> some View {
        let showsClose = !selected && pad.canClosePad && hoveredPadID == entry.id
        return HStack(spacing: 4) {
            Text(entry.name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            if selected {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            } else if showsClose {
                Button { requestClose(entry) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(text.closePad)
                .accessibilityLabel(text.closePad)
            }
        }
        .foregroundStyle(selected ? .white : .white.opacity(0.6))
        .padding(.leading, 10)
        .padding(.trailing, showsClose ? 5 : selected ? 8 : 10)
        .frame(height: 22)
        .background(.white.opacity(selected ? 0.14 : 0.05), in: Capsule())
        .contentShape(Capsule())
    }

    /// The caret lands at the end of the pad's text, as the floating pad
    /// puts it after a tab change.
    private var titleFontSize: CGFloat { (textSize * 1.75).rounded() }
    private var titleHeight: CGFloat { (titleFontSize * 1.3).rounded() + 12 }

    /// The note's name above its first line, scrolling away with the text as
    /// Obsidian's inline title does.
    private func installTitle(in view: NSTextView) {
        guard let live = view as? ScratchpadLiveTextView else { return }
        let title = NotchScratchpadTitleField(fontSize: titleFontSize,
                                              label: text.renamePad,
                                              inset: Self.editorInset.width + PlainTextEditor.lineFragmentPadding,
                                              onFinish: { focusEditor(atStart: true) })
        if let host = live.header as? NSHostingView<NotchScratchpadTitleField> {
            host.rootView = title
            live.setHeader(host, height: titleHeight)
        } else {
            live.setHeader(NSHostingView(rootView: title), height: titleHeight)
        }
    }

    /// Return in the title goes to the note's first line instead, as in
    /// Obsidian.
    private func focusEditor(atStart: Bool = false) {
        guard !pad.isPreviewing, let view = editor.view, let window = view.window, window.isKeyWindow else { return }
        window.makeFirstResponder(view)
        let end = NSRange(location: atStart ? 0 : (view.string as NSString).length, length: 0)
        view.setSelectedRange(end)
        view.scrollRangeToVisible(end)
    }

    private func presentRename(_ entry: ScratchpadPad) {
        DispatchQueue.main.async {
            let field = NSTextField(string: entry.name)
            field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
            let alert = NSAlert()
            alert.messageText = text.renamePad
            alert.accessoryView = field
            alert.addButton(withTitle: text.saveName)
            alert.addButton(withTitle: text.cancel)
            alert.window.initialFirstResponder = field
            guard NotchIslandAlert.run(alert, above: service.presentationWindow) == .alertFirstButtonReturn else { return }
            pad.renamePad(entry.id, to: field.stringValue)
        }
    }

    /// Closing never deletes the note, so there is nothing to confirm, as in
    /// the floating pad.
    private func requestClose(_ entry: ScratchpadPad) {
        guard pad.canClosePad else { return }
        _ = pad.closePad(entry.id)
    }
}

/// The note's name at the top of its page, as Obsidian's inline title: the
/// file name, edited in place. A rename happens when editing ends, never per
/// keystroke, since each one moves the file in the vault. Escape, or a name
/// the vault refuses, puts the current name back. It watches the pads itself
/// because it lives in the editor's text view, outside this page's updates.
struct NotchScratchpadTitleField: View {
    let fontSize: CGFloat
    let label: String
    let inset: CGFloat
    let onFinish: () -> Void
    @ObservedObject private var pad = ScratchpadService.shared
    @State private var draft = ""
    @FocusState private var focused: Bool

    private var selected: ScratchpadPad? { pad.pads.first { $0.id == pad.selectedPadID } }
    private var name: String { selected?.name ?? "" }

    var body: some View {
        TextField(label, text: $draft)
            .textFieldStyle(.plain)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .focused($focused)
            .padding(.horizontal, inset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.bottom, 4)
            .accessibilityLabel(label)
            .onAppear { draft = name }
            .onChange(of: name) { _, current in draft = current }
            .onChange(of: pad.selectedPadID) { _, _ in draft = name }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
            .onSubmit {
                commit()
                onFinish()
            }
            .onExitCommand {
                draft = name
                onFinish()
            }
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let id = selected?.id, !trimmed.isEmpty, trimmed != name else {
            draft = name
            return
        }
        pad.renamePad(id, to: trimmed)
        // A refused name leaves the note's name unchanged, so no change
        // arrives to reset the field; put back whatever the note is called.
        draft = name
    }
}
