// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Files, screenshots and pictures dropped on the page wait with the draft
/// and go with the next message.
extension NotchHermesChatService {
    /// Where dropped pictures and copies of temporary files are kept. The
    /// transcript opens attachments by path, so they outlive the drop.
    private static var dropDirectory: URL? {
        PrivateFileStore.containerURL?.appendingPathComponent("agent-drops", isDirectory: true)
    }

    private static let dropQueue = DispatchQueue(label: "com.vorssaint.notch.agent-drops", qos: .userInitiated)

    /// Takes what the drag carries; false when it carries nothing to attach.
    @discardableResult
    func acceptDrop(_ pasteboard: NSPasteboard) -> Bool {
        guard let content = NotchAgentDropSupport.content(of: pasteboard) else { return false }
        switch content {
        case .files(let urls):
            let kept = urls.filter { !NotchAgentDropSupport.isTransient($0) }
            attach(kept)
            let transient = urls.filter { NotchAgentDropSupport.isTransient($0) }
            guard !transient.isEmpty else { return true }
            // The screenshot thumbnail's file goes with the thumbnail, so it
            // is copied now; off the main thread, as a recording can be large.
            Self.dropQueue.async { [weak self] in
                let copies = transient.compactMap { Self.keep($0) }
                DispatchQueue.main.async { self?.attach(copies) }
            }
            return true
        case .promised:
            let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil)
                as? [NSFilePromiseReceiver] ?? []
            guard !receivers.isEmpty, let directory = Self.preparedDropDirectory() else {
                return acceptImage(from: pasteboard)
            }
            // A promise that fails still leaves the picture's pixels, when
            // the app put them on the pasteboard too.
            let fallback = NotchAgentDropSupport.imagePNG(in: pasteboard)
            let operations = OperationQueue()
            operations.underlyingQueue = Self.dropQueue
            for receiver in receivers {
                receiver.receivePromisedFiles(atDestination: directory, options: [:],
                                              operationQueue: operations) { [weak self] url, error in
                    let received = error == nil ? url : fallback.flatMap { Self.write($0) }
                    DispatchQueue.main.async { self?.attach(received.map { [$0] } ?? []) }
                }
            }
            return true
        case .image:
            return acceptImage(from: pasteboard)
        }
    }

    private func acceptImage(from pasteboard: NSPasteboard) -> Bool {
        guard let png = NotchAgentDropSupport.imagePNG(in: pasteboard) else { return false }
        Self.dropQueue.async { [weak self] in
            let url = Self.write(png)
            DispatchQueue.main.async { self?.attach(url.map { [$0] } ?? []) }
        }
        return true
    }

    private func attach(_ urls: [URL]) {
        for url in urls where !pendingAttachments.contains(url) { pendingAttachments.append(url) }
    }

    private static func preparedDropDirectory() -> URL? {
        guard let directory = dropDirectory, PrivateFileStore.createDirectory(at: directory) else { return nil }
        return directory
    }

    /// A copy of a file macOS is about to remove, under its own name.
    private static func keep(_ url: URL) -> URL? {
        guard let directory = preparedDropDirectory() else { return nil }
        let copy = NotchAgentDropSupport.unusedURL(named: url.lastPathComponent, in: directory)
        guard (try? FileManager.default.copyItem(at: url, to: copy)) != nil else { return nil }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: copy.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: copy.path)
        }
        return copy
    }

    private static func write(_ png: Data) -> URL? {
        guard let directory = preparedDropDirectory() else { return nil }
        let url = NotchAgentDropSupport.unusedURL(named: NotchAgentDropSupport.imageName(at: Date()), in: directory)
        return PrivateFileStore.write(png, to: url) ? url : nil
    }
}
