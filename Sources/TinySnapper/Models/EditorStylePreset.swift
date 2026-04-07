import AppKit

enum QuickStylePreset: String, CaseIterable {
    case clean
    case soft
    case warm
    case flat

    var title: String {
        switch self {
        case .clean: return "Clean"
        case .soft: return "Soft"
        case .warm: return "Warm"
        case .flat: return "Flat"
        }
    }

    var preset: EditorStylePreset {
        switch self {
        case .clean:
            return EditorStylePreset(
                padding: 56,
                ratioPreset: .automatic,
                backgroundMode: .solid,
                backgroundPreset: .warmGlow,
                solidColor: NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.99, alpha: 1),
                gradientStartColor: EditorStylePreset.default.gradientStartColor,
                gradientEndColor: EditorStylePreset.default.gradientEndColor,
                customBackgroundImage: nil,
                shadow: 18,
                cornerRadius: 18,
                tiltX: 0,
                tiltY: 0,
                watermarkEnabled: false,
                watermarkText: AppBrand.watermark,
                annotationColor: .systemRed,
                selectedShapeKind: .rectangle
            )
        case .soft:
            return EditorStylePreset(
                padding: 72,
                ratioPreset: .automatic,
                backgroundMode: .solid,
                backgroundPreset: .warmGlow,
                solidColor: NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.98, alpha: 1),
                gradientStartColor: EditorStylePreset.default.gradientStartColor,
                gradientEndColor: EditorStylePreset.default.gradientEndColor,
                customBackgroundImage: nil,
                shadow: 36,
                cornerRadius: 28,
                tiltX: 0,
                tiltY: 0,
                watermarkEnabled: false,
                watermarkText: AppBrand.watermark,
                annotationColor: .systemRed,
                selectedShapeKind: .rectangle
            )
        case .warm:
            return EditorStylePreset(
                padding: 72,
                ratioPreset: .automatic,
                backgroundMode: .preset,
                backgroundPreset: .warmGlow,
                solidColor: EditorStylePreset.default.solidColor,
                gradientStartColor: EditorStylePreset.default.gradientStartColor,
                gradientEndColor: EditorStylePreset.default.gradientEndColor,
                customBackgroundImage: nil,
                shadow: 32,
                cornerRadius: 28,
                tiltX: 0,
                tiltY: 0,
                watermarkEnabled: false,
                watermarkText: AppBrand.watermark,
                annotationColor: .systemRed,
                selectedShapeKind: .rectangle
            )
        case .flat:
            return EditorStylePreset(
                padding: 48,
                ratioPreset: .automatic,
                backgroundMode: .solid,
                backgroundPreset: .warmGlow,
                solidColor: NSColor.white,
                gradientStartColor: EditorStylePreset.default.gradientStartColor,
                gradientEndColor: EditorStylePreset.default.gradientEndColor,
                customBackgroundImage: nil,
                shadow: 0,
                cornerRadius: 12,
                tiltX: 0,
                tiltY: 0,
                watermarkEnabled: false,
                watermarkText: AppBrand.watermark,
                annotationColor: .systemRed,
                selectedShapeKind: .rectangle
            )
        }
    }

    func matches(state: EditorState) -> Bool {
        let preset = self.preset
        return abs(state.padding - preset.padding) < 0.5 &&
            state.ratioPreset == preset.ratioPreset &&
            state.backgroundMode == preset.backgroundMode &&
            state.backgroundPreset == preset.backgroundPreset &&
            state.solidColor.hexString == preset.solidColor.hexString &&
            state.gradientStartColor.hexString == preset.gradientStartColor.hexString &&
            state.gradientEndColor.hexString == preset.gradientEndColor.hexString &&
            state.shadow == preset.shadow &&
            state.cornerRadius == preset.cornerRadius &&
            state.tiltX == preset.tiltX &&
            state.tiltY == preset.tiltY &&
            state.watermarkEnabled == preset.watermarkEnabled &&
            state.annotationColor.hexString == preset.annotationColor.hexString &&
            state.selectedShapeKind == preset.selectedShapeKind &&
            ((state.customBackgroundImage == nil) == (preset.customBackgroundImage == nil))
    }
}

struct EditorStylePreset {
    var padding: CGFloat
    var ratioPreset: RatioPreset
    var backgroundMode: BackgroundMode
    var backgroundPreset: BackgroundPreset
    var solidColor: NSColor
    var gradientStartColor: NSColor
    var gradientEndColor: NSColor
    var customBackgroundImage: NSImage?
    var shadow: CGFloat
    var cornerRadius: CGFloat
    var tiltX: CGFloat
    var tiltY: CGFloat
    var watermarkEnabled: Bool
    var watermarkText: String
    var annotationColor: NSColor
    var selectedShapeKind: ShapeKind

    static let `default` = EditorStylePreset(
        padding: 72,
        ratioPreset: .automatic,
        backgroundMode: .preset,
        backgroundPreset: .warmGlow,
        solidColor: NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.99, alpha: 1),
        gradientStartColor: NSColor(calibratedRed: 1, green: 0.75, blue: 0.42, alpha: 1),
        gradientEndColor: NSColor(calibratedRed: 0.99, green: 0.48, blue: 0.45, alpha: 1),
        customBackgroundImage: nil,
        shadow: 32,
        cornerRadius: 28,
        tiltX: 0,
        tiltY: 0,
        watermarkEnabled: false,
        watermarkText: AppBrand.watermark,
        annotationColor: .systemRed,
        selectedShapeKind: .rectangle
    )
}

extension EditorState {
    var stylePreset: EditorStylePreset {
        EditorStylePreset(
            padding: padding,
            ratioPreset: ratioPreset,
            backgroundMode: backgroundMode,
            backgroundPreset: backgroundPreset,
            solidColor: solidColor,
            gradientStartColor: gradientStartColor,
            gradientEndColor: gradientEndColor,
            customBackgroundImage: customBackgroundImage,
            shadow: shadow,
            cornerRadius: cornerRadius,
            tiltX: tiltX,
            tiltY: tiltY,
            watermarkEnabled: watermarkEnabled,
            watermarkText: watermarkText,
            annotationColor: annotationColor,
            selectedShapeKind: selectedShapeKind
        )
    }

    func apply(stylePreset: EditorStylePreset) {
        padding = stylePreset.padding
        ratioPreset = stylePreset.ratioPreset
        backgroundMode = stylePreset.backgroundMode
        backgroundPreset = stylePreset.backgroundPreset
        solidColor = stylePreset.solidColor
        gradientStartColor = stylePreset.gradientStartColor
        gradientEndColor = stylePreset.gradientEndColor
        customBackgroundImage = stylePreset.customBackgroundImage
        shadow = stylePreset.shadow
        cornerRadius = stylePreset.cornerRadius
        tiltX = stylePreset.tiltX
        tiltY = stylePreset.tiltY
        watermarkEnabled = stylePreset.watermarkEnabled
        watermarkText = stylePreset.watermarkText
        annotationColor = stylePreset.annotationColor
        selectedShapeKind = stylePreset.selectedShapeKind
    }
}
