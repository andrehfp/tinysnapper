import AppKit
import Foundation

enum CanvasRenderer {
    struct Payload: Encodable {
        let isPlaceholder: Bool
        let captureShortcutDisplay: String
        let captureAndCopyShortcutDisplay: String
        let stageWidth: Int
        let stageHeight: Int
        let stageCornerRadius: Double
        let zoom: Double
        let sourceImageURL: String
        let backgroundMode: String
        let solidColor: String
        let gradientStart: String
        let gradientEnd: String
        let presetStart: String
        let presetEnd: String
        let customBackgroundURL: String?
        let cardX: Double
        let cardY: Double
        let imageWidth: Double
        let imageHeight: Double
        let shadow: Double
        let cornerRadius: Double
        let tiltX: Double
        let tiltY: Double
        let watermarkEnabled: Bool
        let watermarkText: String
        let annotations: [Annotation]
        let annotationColor: String
        let shapeKind: String

        var stageSize: CGSize {
            CGSize(width: stageWidth, height: stageHeight)
        }
    }

    private static let defaultStageCornerRadius: Double = 36
    private static let exportStageCornerRadius: Double = 0
    private static let resourceBundleName = "tinysnapper_TinySnapper.bundle"

    static func makePayload(for state: EditorState, interactive: Bool) -> Payload {
        if state.isPlaceholder {
            return Payload(
                isPlaceholder: true,
                captureShortcutDisplay: AppBrand.captureShortcutDisplay,
                captureAndCopyShortcutDisplay: AppBrand.captureAndCopyShortcutDisplay,
                stageWidth: 860,
                stageHeight: 540,
                stageCornerRadius: interactive ? defaultStageCornerRadius : exportStageCornerRadius,
                zoom: interactive ? state.zoom : 1,
                sourceImageURL: "",
                backgroundMode: state.backgroundMode.rawValue,
                solidColor: state.solidColor.hexString,
                gradientStart: state.gradientStartColor.hexString,
                gradientEnd: state.gradientEndColor.hexString,
                presetStart: "#F5F7FB",
                presetEnd: "#EDF1F7",
                customBackgroundURL: nil,
                cardX: 170,
                cardY: 110,
                imageWidth: 520,
                imageHeight: 320,
                shadow: 0,
                cornerRadius: 24,
                tiltX: 0,
                tiltY: 0,
                watermarkEnabled: false,
                watermarkText: state.watermarkText,
                annotations: [],
                annotationColor: state.annotationColor.hexString,
                shapeKind: state.selectedShapeKind.rawValue
            )
        }

        let maxDimension: CGFloat = interactive ? 1200 : 1400
        let sourceSize = state.sourceImage.size
        let scale = min(1, maxDimension / max(sourceSize.width, sourceSize.height))
        let displayWidth = max(240, floor(sourceSize.width * scale))
        let displayHeight = max(160, floor(sourceSize.height * scale))
        let paddedWidth = displayWidth + (state.padding * 2)
        let paddedHeight = displayHeight + (state.padding * 2)

        let stageWidth: CGFloat
        let stageHeight: CGFloat

        if let ratio = state.ratioPreset.aspectRatio {
            stageWidth = max(paddedWidth, paddedHeight * ratio)
            stageHeight = max(paddedHeight, paddedWidth / ratio)
        } else {
            stageWidth = paddedWidth
            stageHeight = paddedHeight
        }

        let cardX = (stageWidth - displayWidth) / 2
        let cardY = (stageHeight - displayHeight) / 2
        let preset = state.backgroundPreset.colors

        return Payload(
            isPlaceholder: false,
            captureShortcutDisplay: AppBrand.captureShortcutDisplay,
            captureAndCopyShortcutDisplay: AppBrand.captureAndCopyShortcutDisplay,
            stageWidth: Int(ceil(stageWidth)),
            stageHeight: Int(ceil(stageHeight)),
            stageCornerRadius: interactive ? defaultStageCornerRadius : exportStageCornerRadius,
            zoom: interactive ? Double(state.zoom) : 1,
            sourceImageURL: state.sourceImage.dataURL ?? "",
            backgroundMode: state.backgroundMode.rawValue,
            solidColor: state.solidColor.hexString,
            gradientStart: state.gradientStartColor.hexString,
            gradientEnd: state.gradientEndColor.hexString,
            presetStart: preset.0,
            presetEnd: preset.1,
            customBackgroundURL: state.customBackgroundImage?.dataURL,
            cardX: cardX,
            cardY: cardY,
            imageWidth: displayWidth,
            imageHeight: displayHeight,
            shadow: Double(state.shadow),
            cornerRadius: Double(state.cornerRadius),
            tiltX: Double(state.tiltX),
            tiltY: Double(state.tiltY),
            watermarkEnabled: state.watermarkEnabled,
            watermarkText: state.watermarkText,
            annotations: state.annotations,
            annotationColor: state.annotationColor.hexString,
            shapeKind: state.selectedShapeKind.rawValue
        )
    }

    static func html(for state: EditorState, interactive: Bool) -> String {
        let safeJSON = payloadJSON(for: state, interactive: interactive)

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1.0" />
          <style>\(resource(named: "canvas", extension: "css"))</style>
        </head>
        <body class="\(interactive ? "interactive" : "snapshot")">
          <script>
            window.__PAYLOAD = \(safeJSON);
            window.__INTERACTIVE = \(interactive ? "true" : "false");
          </script>
          <script>\(resource(named: "canvas", extension: "js"))</script>
        </body>
        </html>
        """
    }

    static func payloadJSON(for state: EditorState, interactive: Bool) -> String {
        let payload = makePayload(for: state, interactive: interactive)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let json = (try? encoder.encode(payload)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return json.replacingOccurrences(of: "</", with: "<\\/")
    }

    private static func resource(named name: String, extension ext: String) -> String {
        guard
            let url = resourceBundle()?.url(forResource: name, withExtension: ext),
            let content = try? String(contentsOf: url)
        else {
            return ""
        }
        return content
    }

    static func resourceBaseURL() -> URL? {
        resourceBundle()?.resourceURL ?? Bundle.main.resourceURL
    }

    private static func resourceBundle() -> Bundle? {
        let fileManager = FileManager.default
        let candidateDirectories = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true),
            Bundle.main.executableURL?.deletingLastPathComponent(),
        ]

        for directory in candidateDirectories.compactMap({ $0 }) {
            let directBundleURL = directory.appendingPathComponent(resourceBundleName, isDirectory: true)
            if let bundle = Bundle(url: directBundleURL) {
                return bundle
            }

            guard let contents = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            if let bundleURL = contents.first(where: { $0.lastPathComponent.hasSuffix("_TinySnapper.bundle") }),
               let bundle = Bundle(url: bundleURL) {
                return bundle
            }
        }

        return nil
    }
}
