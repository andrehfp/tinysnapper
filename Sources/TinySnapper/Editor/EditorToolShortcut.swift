import Foundation

struct EditorToolShortcut: Encodable {
    let tool: String?
    let title: String
    let key: String
    let display: String
    let symbolName: String
    let accessibilityDescription: String

    var buttonTitle: String {
        title
    }

    var tooltip: String {
        "\(accessibilityDescription) (\(display))"
    }

    static let select = EditorToolShortcut(
        tool: nil,
        title: "Select",
        key: "v",
        display: "V",
        symbolName: "cursorarrow",
        accessibilityDescription: "Select or move annotations"
    )

    static let text = EditorToolShortcut(
        tool: "text",
        title: "Text",
        key: "t",
        display: "T",
        symbolName: "textformat",
        accessibilityDescription: "Text annotation"
    )

    static let arrow = EditorToolShortcut(
        tool: "arrow",
        title: "Arrow",
        key: "a",
        display: "A",
        symbolName: "arrow.up.right",
        accessibilityDescription: "Arrow annotation"
    )

    static let shape = EditorToolShortcut(
        tool: "shape",
        title: "Shape",
        key: "s",
        display: "S",
        symbolName: "rectangle",
        accessibilityDescription: "Shape annotation"
    )

    static let redact = EditorToolShortcut(
        tool: "redact",
        title: "Redact",
        key: "r",
        display: "R",
        symbolName: "rectangle.fill",
        accessibilityDescription: "Redact area"
    )

    static let annotationTools = [text, arrow, shape, redact]
    static let keyboardShortcuts = [select, text, arrow, shape, redact]
}
