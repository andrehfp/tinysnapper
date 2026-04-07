import AppKit
import Foundation

enum RatioPreset: String, CaseIterable {
    case automatic
    case square
    case ratio32
    case ratio43
    case ratio169

    var title: String {
        switch self {
        case .automatic: return "Auto"
        case .square: return "1:1"
        case .ratio32: return "3:2"
        case .ratio43: return "4:3"
        case .ratio169: return "16:9"
        }
    }

    var aspectRatio: CGFloat? {
        switch self {
        case .automatic: return nil
        case .square: return 1
        case .ratio32: return 3.0 / 2.0
        case .ratio43: return 4.0 / 3.0
        case .ratio169: return 16.0 / 9.0
        }
    }
}

enum BackgroundMode: String, CaseIterable {
    case none
    case solid
    case gradient
    case preset
    case customImage

    var title: String {
        switch self {
        case .none: return "None"
        case .solid: return "Solid"
        case .gradient: return "Gradient"
        case .preset: return "Preset"
        case .customImage: return "Custom Image"
        }
    }
}

enum BackgroundPreset: String, CaseIterable {
    case warmGlow
    case oceanBlue
    case mintCandy

    var title: String {
        switch self {
        case .warmGlow: return "Warm Glow"
        case .oceanBlue: return "Ocean Blue"
        case .mintCandy: return "Mint Candy"
        }
    }

    var colors: (String, String) {
        switch self {
        case .warmGlow:
            return ("#ffb36b", "#ff7b72")
        case .oceanBlue:
            return ("#73b7ff", "#2d5bff")
        case .mintCandy:
            return ("#90f7d0", "#6ab6ff")
        }
    }
}

final class EditorState {
    let id = UUID()
    let isPlaceholder: Bool
    var sourceImage: NSImage
    var title: String
    var padding: CGFloat = 72
    var ratioPreset: RatioPreset = .automatic
    var backgroundMode: BackgroundMode = .preset
    var backgroundPreset: BackgroundPreset = .warmGlow
    var solidColor: NSColor = NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.99, alpha: 1)
    var gradientStartColor: NSColor = NSColor(calibratedRed: 1, green: 0.75, blue: 0.42, alpha: 1)
    var gradientEndColor: NSColor = NSColor(calibratedRed: 0.99, green: 0.48, blue: 0.45, alpha: 1)
    var customBackgroundImage: NSImage?
    var shadow: CGFloat = 32
    var cornerRadius: CGFloat = 28
    var tiltX: CGFloat = 0
    var tiltY: CGFloat = 0
    var zoom: CGFloat = 1
    var watermarkEnabled = false
    var watermarkText = AppBrand.watermark
    var annotationColor: NSColor = .systemRed
    var selectedShapeKind: ShapeKind = .rectangle
    var annotations: [Annotation] = []

    init(sourceImage: NSImage, title: String, isPlaceholder: Bool = false) {
        self.isPlaceholder = isPlaceholder
        self.sourceImage = sourceImage
        self.title = title
    }

    static func placeholder() -> EditorState {
        EditorState(
            sourceImage: NSImage.placeholderCanvas(size: NSSize(width: 1200, height: 800)),
            title: "Untitled",
            isPlaceholder: true
        )
    }
}
