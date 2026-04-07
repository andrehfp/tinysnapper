import AppKit

@MainActor
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?

    private let editorViewController: EditorViewController

    init(
        state: EditorState,
        exportService: ExportService,
        onCaptureRequested: @escaping @MainActor () -> Void,
        onPasteRequested: @escaping @MainActor () -> Void,
        onOpenRequested: @escaping @MainActor () -> Void
    ) {
        self.editorViewController = EditorViewController(
            state: state,
            exportService: exportService,
            onCaptureRequested: onCaptureRequested,
            onPasteRequested: onPasteRequested,
            onOpenRequested: onOpenRequested
        )
        let initialSize = NSSize(width: 1440, height: 940)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppBrand.displayName
        window.isReleasedWhenClosed = false
        super.init(window: window)
        _ = editorViewController.view
        window.contentViewController = editorViewController
        window.delegate = self
        window.minSize = NSSize(width: 980, height: 720)
        window.setContentSize(initialSize)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func load(state: EditorState) {
        editorViewController.load(state: state)
    }

    func currentStylePreset() -> EditorStylePreset {
        editorViewController.currentStylePreset()
    }

    func showStatus(_ message: String) {
        editorViewController.showStatus(message)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
