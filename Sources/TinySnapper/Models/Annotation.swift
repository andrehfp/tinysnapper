import Foundation

enum AnnotationKind: String, Codable {
    case text
    case arrow
    case shape
    case redact
}

enum ShapeKind: String, Codable, CaseIterable {
    case rectangle
    case rounded
    case oval
    case line

    var title: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .rounded: return "Rounded"
        case .oval: return "Oval"
        case .line: return "Line"
        }
    }
}

struct Annotation: Codable, Equatable, Identifiable {
    let id: String
    var kind: AnnotationKind
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var rotation: Double
    var zIndex: Int
    var colorHex: String
    var text: String?
    var shapeKind: ShapeKind?

    init(
        id: String = UUID().uuidString,
        kind: AnnotationKind,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        rotation: Double = 0,
        zIndex: Int,
        colorHex: String,
        text: String? = nil,
        shapeKind: ShapeKind? = nil
    ) {
        self.id = id
        self.kind = kind
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotation = rotation
        self.zIndex = zIndex
        self.colorHex = colorHex
        self.text = text
        self.shapeKind = shapeKind
    }
}
