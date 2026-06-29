import AppKit

@MainActor
enum PanIcon {
    static func statusImage(tintHex: String) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = NSRect(origin: .zero, size: size)
        let base = iconImage()
            ?? NSImage(systemSymbolName: "pencil", accessibilityDescription: "Pan Notes")
        base?.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        NSColor(hex: tintHex).setFill()
        rect.fill(using: .sourceIn)
        image.isTemplate = false

        return image
    }

    private static func iconImage() -> NSImage? {
        let appResourceURL = Bundle.main.url(forResource: "pan", withExtension: "svg")
        let sourceResourceURL = URL(filePath: FileManager.default.currentDirectoryPath)
            .appending(path: "Sources/PanNotesApp/Resources/pan.svg")

        return [appResourceURL, sourceResourceURL]
            .compactMap { $0 }
            .lazy
            .compactMap(NSImage.init(contentsOf:))
            .first
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = Int(raw, radix: 16) ?? 0xD8A900
        let red = CGFloat((value >> 16) & 0xFF) / 255.0
        let green = CGFloat((value >> 8) & 0xFF) / 255.0
        let blue = CGFloat(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
