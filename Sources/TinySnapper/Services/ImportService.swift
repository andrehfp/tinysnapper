import AppKit

enum ImportError: Error {
    case clipboardMissingImage
    case invalidImage
}

final class ImportService {
    func importFromClipboard() throws -> NSImage {
        let pasteboard = NSPasteboard.general

        if let objects = pasteboard.readObjects(forClasses: [NSImage.self]), let image = objects.first as? NSImage {
            return image
        }

        if
            let data = pasteboard.data(forType: .png),
            let image = NSImage(data: data)
        {
            return image
        }

        throw ImportError.clipboardMissingImage
    }

    func openImagePanel() -> NSImage? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .gif, .bmp]

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        guard let image = NSImage(contentsOf: url) else {
            return nil
        }

        return image
    }
}
