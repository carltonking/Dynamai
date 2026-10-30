// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// What a drag dropped on an agent's page attaches: files from Finder, a
/// screenshot thumbnail's temporary file, a promised file, or bare pixels,
/// while a dragged word stays the field's to type.
enum NotchAgentDropTests {
    typealias Support = NotchAgentDropSupport

    static func run(_ suite: TestSuite) {
        suite.run("an agent's page reads files, promises and pictures from a drop") {
            let finder = pasteboard()
            let file = URL(fileURLWithPath: "/Users/someone/Desktop/Screenshot 2026-10-30 at 14.03.12.png")
            finder.writeObjects([file as NSURL])
            finder.setData(png(), forType: .png)
            suite.expect(Support.content(of: finder) == .files([file]),
                         "a dropped file is attached as itself, not as the picture it also carries")
            suite.expect(Support.carriesAttachments(finder), "a dropped file is the page's to take")

            let picture = pasteboard()
            picture.setData(NSImage(size: CGSize(width: 4, height: 4)).tiffRepresentation(of: 4) ?? Data(), forType: .tiff)
            if case .image(let data) = Support.content(of: picture) {
                suite.expect(NSBitmapImageRep(data: data)?.pixelsWide == 4,
                             "a picture dropped as pixels alone is kept as a PNG of the same picture")
            } else {
                suite.expect(false, "a picture dropped as pixels alone is attached")
            }

            let promise = pasteboard()
            if let type = NSFilePromiseReceiver.readableDraggedTypes.first {
                promise.setData(Data(), forType: NSPasteboard.PasteboardType(type))
            }
            suite.expect(Support.content(of: promise) == .promised,
                         "a file an app promises, as Photos or a browser does, is taken once delivered")

            let words = pasteboard()
            words.setString("dinner at 8", forType: .string)
            suite.expect(Support.content(of: words) == nil && !Support.carriesAttachments(words),
                         "dragged words are left to the message field")
        }

        suite.run("a screenshot thumbnail's file is copied before macOS removes it") {
            let temporary = URL(fileURLWithPath: "/private/var/folders/jt/abc/T", isDirectory: true)
            let thumbnail = URL(fileURLWithPath:
                "/var/folders/jt/abc/T/TemporaryItems/NSIRD_screencaptureui_dSEBKA/Screenshot 2026-10-27 at 14.57.16.png")
            suite.expect(Support.isTransient(thumbnail, temporaryDirectory: temporary),
                         "the floating thumbnail's file is temporary")
            suite.expect(Support.isTransient(temporary.appendingPathComponent("drop.png"), temporaryDirectory: temporary),
                         "anything in the temporary folder is temporary")
            suite.expect(!Support.isTransient(URL(fileURLWithPath: "/Users/someone/Desktop/Screenshot.png"),
                                              temporaryDirectory: temporary),
                         "a saved screenshot is attached where it is")
            suite.expect(!Support.isTransient(URL(fileURLWithPath: "/Users/someone/tmp/notes.txt"),
                                              temporaryDirectory: temporary),
                         "a folder merely named tmp is not temporary")
        }

        suite.run("a dropped picture gets a screenshot's kind of name, never another file's") {
            let date = Date(timeIntervalSince1970: 1_793_368_992) // 2026-10-30 14:03:12 UTC
            suite.expect(Support.imageName(at: date, timeZone: TimeZone(identifier: "UTC")!)
                            == "Image 2026-10-30 at 14.03.12.png", "named like a screenshot, by when it came")
            let directory = URL(fileURLWithPath: "/drops", isDirectory: true)
            let taken: Set<String> = ["/drops/Image.png", "/drops/Image 2.png"]
            suite.expect(Support.unusedURL(named: "Image.png", in: directory) { taken.contains($0.path) }.path
                            == "/drops/Image 3.png", "a name in use is numbered")
            suite.expect(Support.unusedURL(named: "notes", in: directory) { _ in false }.path == "/drops/notes",
                         "a free name is kept as it is")
        }
    }

    private static func pasteboard() -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.vorssaint.tests.agent-drop.\(UUID().uuidString)"))
        pasteboard.clearContents()
        return pasteboard
    }

    private static func png() -> Data {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
                                      samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        return bitmap.representation(using: .png, properties: [:]) ?? Data()
    }
}

private extension NSImage {
    /// A plain picture of `side` pixels, as AppKit writes one to a pasteboard.
    func tiffRepresentation(of side: Int) -> Data? {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
                                      samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        return bitmap?.tiffRepresentation
    }
}
