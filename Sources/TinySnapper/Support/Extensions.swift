import AppKit

final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}

extension NSColor {
    var hexString: String {
        guard let rgb = usingColorSpace(.deviceRGB) else {
            return "#ffffff"
        }

        let red = Int(round(rgb.redComponent * 255))
        let green = Int(round(rgb.greenComponent * 255))
        let blue = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

extension NSImage {
    var pngData: Data? {
        var proposedRect = NSRect(origin: .zero, size: size)
        if let cgImage = cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) {
            let rep = NSBitmapImageRep(cgImage: cgImage)
            rep.size = size
            return rep.representation(using: .png, properties: [:])
        }

        guard
            let tiffData = tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }

        return rep.representation(using: .png, properties: [:])
    }

    func maskedToRoundedRect(cornerRadius: CGFloat) -> NSImage? {
        guard cornerRadius > 0 else {
            return self
        }

        var proposedRect = NSRect(origin: .zero, size: size)
        guard let cgImage = cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else {
            return nil
        }

        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        let scale = min(CGFloat(width) / max(size.width, 1), CGFloat(height) / max(size.height, 1))
        let pixelCornerRadius = cornerRadius * scale
        let rect = CGRect(x: 0, y: 0, width: width, height: height)

        context.clear(rect)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: pixelCornerRadius, cornerHeight: pixelCornerRadius, transform: nil))
        context.clip()
        context.draw(cgImage, in: rect)

        guard let maskedCGImage = context.makeImage() else {
            return nil
        }

        return NSImage(cgImage: maskedCGImage, size: size)
    }

    var dataURL: String? {
        guard let pngData else {
            return nil
        }
        return "data:image/png;base64,\(pngData.base64EncodedString())"
    }

    static func placeholderCanvas(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.99, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        let dash = NSBezierPath()
        dash.lineWidth = 2
        dash.setLineDash([8, 8], count: 2, phase: 0)
        NSColor(calibratedRed: 0.80, green: 0.84, blue: 0.90, alpha: 1).setStroke()
        let insetRect = NSRect(x: 60, y: 60, width: size.width - 120, height: size.height - 120)
        dash.appendRect(insetRect)
        dash.stroke()

        let text = "Capture a screenshot or import an image"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 34, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.33, green: 0.38, blue: 0.48, alpha: 1),
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textRect = NSRect(
            x: 0,
            y: (size.height / 2) - 20,
            width: size.width,
            height: 60
        )
        attributed.draw(in: textRect)

        image.unlockFocus()
        return image
    }

    static func tinySnapperLogo(size: CGFloat, isTemplate: Bool = false) -> NSImage {
        let imageSize = NSSize(width: size, height: size)
        let image = NSImage(size: imageSize)
        image.lockFocus()

        let bounds = NSRect(origin: .zero, size: imageSize)
        let outerPath = NSBezierPath(roundedRect: bounds, xRadius: size * 0.22, yRadius: size * 0.22)
        NSColor.black.setFill()
        outerPath.fill()

        let cornerLength = size * 0.16
        let cornerInset = size * 0.16
        let cornerPath = NSBezierPath()
        cornerPath.lineCapStyle = .round
        cornerPath.lineJoinStyle = .round
        cornerPath.lineWidth = max(3, size * 0.055)

        cornerPath.move(to: NSPoint(x: cornerInset, y: size - cornerInset - cornerLength))
        cornerPath.line(to: NSPoint(x: cornerInset, y: size - cornerInset))
        cornerPath.line(to: NSPoint(x: cornerInset + cornerLength, y: size - cornerInset))

        cornerPath.move(to: NSPoint(x: size - cornerInset - cornerLength, y: size - cornerInset))
        cornerPath.line(to: NSPoint(x: size - cornerInset, y: size - cornerInset))
        cornerPath.line(to: NSPoint(x: size - cornerInset, y: size - cornerInset - cornerLength))

        cornerPath.move(to: NSPoint(x: size - cornerInset, y: cornerInset + cornerLength))
        cornerPath.line(to: NSPoint(x: size - cornerInset, y: cornerInset))
        cornerPath.line(to: NSPoint(x: size - cornerInset - cornerLength, y: cornerInset))

        cornerPath.move(to: NSPoint(x: cornerInset + cornerLength, y: cornerInset))
        cornerPath.line(to: NSPoint(x: cornerInset, y: cornerInset))
        cornerPath.line(to: NSPoint(x: cornerInset, y: cornerInset + cornerLength))

        NSColor.white.setStroke()
        cornerPath.stroke()

        let dotRect = NSRect(
            x: size * 0.64,
            y: size * 0.64,
            width: size * 0.10,
            height: size * 0.10
        )
        NSColor.white.setFill()
        NSBezierPath(ovalIn: dotRect).fill()

        image.unlockFocus()
        image.isTemplate = isTemplate
        return image
    }

    static func tinySnapperStatusIcon(size: CGFloat, isTemplate: Bool = true) -> NSImage {
        let imageSize = NSSize(width: size, height: size)
        let image = NSImage(size: imageSize)
        image.lockFocus()

        let inset = size * 0.16
        let cornerLength = size * 0.20
        let strokeColor: NSColor = isTemplate ? .black : .labelColor

        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = max(1.75, size * 0.09)

        path.move(to: NSPoint(x: inset, y: size - inset - cornerLength))
        path.line(to: NSPoint(x: inset, y: size - inset))
        path.line(to: NSPoint(x: inset + cornerLength, y: size - inset))

        path.move(to: NSPoint(x: size - inset - cornerLength, y: size - inset))
        path.line(to: NSPoint(x: size - inset, y: size - inset))
        path.line(to: NSPoint(x: size - inset, y: size - inset - cornerLength))

        path.move(to: NSPoint(x: size - inset, y: inset + cornerLength))
        path.line(to: NSPoint(x: size - inset, y: inset))
        path.line(to: NSPoint(x: size - inset - cornerLength, y: inset))

        path.move(to: NSPoint(x: inset + cornerLength, y: inset))
        path.line(to: NSPoint(x: inset, y: inset))
        path.line(to: NSPoint(x: inset, y: inset + cornerLength))

        strokeColor.setStroke()
        path.stroke()

        image.unlockFocus()
        image.isTemplate = isTemplate
        return image
    }
}
