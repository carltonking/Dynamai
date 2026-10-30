// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import UniformTypeIdentifiers

/// What a drag dropped on VERTUS's or Instinct's page brings to the next
/// message, read from its pasteboard.
///
/// Finder hands over file URLs. A screenshot's floating thumbnail hands over
/// a file in a temporary folder that macOS removes once the thumbnail goes, so
/// such a file is copied before it is attached. Photos and browsers promise
/// files that only exist once the drop is accepted, and a dragged picture can
/// arrive as image data alone, which is written out as a PNG.
enum NotchAgentDropSupport {
    /// What the drop carries, in the order it is taken: real files win over
    /// a promise of them, and a promise over the picture's bare pixels.
    enum Content: Equatable {
        case files([URL])
        case promised
        case image(Data)
    }

    static func content(of pasteboard: NSPasteboard) -> Content? {
        let files = fileURLs(in: pasteboard)
        if !files.isEmpty { return .files(files) }
        if hasPromisedFiles(pasteboard) { return .promised }
        if let png = imagePNG(in: pasteboard) { return .image(png) }
        return nil
    }

    static func carriesAttachments(_ pasteboard: NSPasteboard) -> Bool {
        !fileURLs(in: pasteboard).isEmpty || hasPromisedFiles(pasteboard) || hasImage(pasteboard)
    }

    static func fileURLs(in pasteboard: NSPasteboard) -> [URL] {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self],
                                          options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return urls.filter(\.isFileURL)
    }

    static func hasPromisedFiles(_ pasteboard: NSPasteboard) -> Bool {
        let promised = Set(NSFilePromiseReceiver.readableDraggedTypes)
        return pasteboard.types?.contains { promised.contains($0.rawValue) } == true
    }

    private static let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]

    static func hasImage(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.availableType(from: imageTypes) != nil
    }

    /// The dragged picture as PNG data, converting TIFF, the type AppKit
    /// itself puts on a pasteboard.
    static func imagePNG(in pasteboard: NSPasteboard) -> Data? {
        if let png = pasteboard.data(forType: .png), !png.isEmpty { return png }
        guard let tiff = pasteboard.data(forType: .tiff),
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    /// A file macOS will remove on its own: a screenshot thumbnail's
    /// `TemporaryItems`, or anything else under the per-user temporary folder.
    static func isTransient(_ url: URL, temporaryDirectory: URL = FileManager.default.temporaryDirectory) -> Bool {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        if path.contains("/TemporaryItems/") { return true }
        let temporary = temporaryDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        let roots = [temporary, "/private/var/folders", "/var/folders", "/private/tmp", "/tmp"]
        return roots.contains { root in
            let root = root.hasSuffix("/") ? root : root + "/"
            return path.hasPrefix(root)
        }
    }

    /// The name of a picture dropped as data alone, as macOS names a
    /// screenshot.
    static func imageName(at date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Image \(formatter.string(from: date)).png"
    }

    /// `name` in `directory`, numbered when a file of that name is already there.
    static func unusedURL(named name: String, in directory: URL,
                          exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> URL {
        let first = directory.appendingPathComponent(name, isDirectory: false)
        guard exists(first) else { return first }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var number = 2
        while true {
            let numbered = ext.isEmpty ? "\(base) \(number)" : "\(base) \(number).\(ext)"
            let url = directory.appendingPathComponent(numbered, isDirectory: false)
            if !exists(url) { return url }
            number += 1
        }
    }
}
