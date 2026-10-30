// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// AppKit's field editor accepts any file dropped on the field it edits and
/// inserts the file's path. The island's editor hands such a drag to the
/// island instead, whenever the island says the drag is its own.
final class NotchFieldEditor: NSTextView {
    var forwardsDrop: ((NSPasteboard) -> NSView?)?
    private weak var forwarding: NSView?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        forwarding = forwardsDrop?(sender.draggingPasteboard)
        guard let forwarding else { return super.draggingEntered(sender) }
        return forwarding.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let forwarding else { return super.draggingUpdated(sender) }
        return forwarding.draggingUpdated(sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        guard let forwarding else { return super.draggingExited(sender) }
        self.forwarding = nil
        forwarding.draggingExited(sender)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        forwarding != nil || super.prepareForDragOperation(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let forwarding else { return super.performDragOperation(sender) }
        self.forwarding = nil
        return forwarding.performDragOperation(sender)
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        if forwarding == nil { super.concludeDragOperation(sender) }
    }
}
