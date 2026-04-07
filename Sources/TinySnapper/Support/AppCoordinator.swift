import AppKit

@MainActor
final class AppCoordinator: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let captureService = CaptureService()
    private let importService = ImportService()
    private let exportService = ExportService()
    private let launchAtLoginService = LaunchAtLoginService()
    private lazy var hotkeyService = HotkeyService(
        captureAction: { [weak self] in
            self?.captureScreenshot()
        },
        captureAndCopyStyledAction: { [weak self] in
            self?.captureAndCopyStyled()
        }
    )

    private var editorWindowController: EditorWindowController?

    func start() {
        NSApp.applicationIconImage = NSImage.tinySnapperLogo(size: 512)
        statusItem.button?.title = ""
        statusItem.button?.image = NSImage.tinySnapperStatusIcon(size: 18, isTemplate: true)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.setAccessibilityLabel(AppBrand.displayName)
        rebuildMenu()
        hotkeyService.registerHotkeys()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let captureItem = menu.addItem(withTitle: "Capture Screenshot", action: #selector(captureScreenshotAction), keyEquivalent: "2")
        captureItem.keyEquivalentModifierMask = [.command, .control]
        let copyStyledItem = menu.addItem(withTitle: "Capture and Copy Styled", action: #selector(captureAndCopyStyledAction), keyEquivalent: "2")
        copyStyledItem.keyEquivalentModifierMask = [.command, .shift]

        menu.addItem(withTitle: "Open From Clipboard", action: #selector(openClipboardAction), keyEquivalent: "v")
        menu.addItem(withTitle: "Open From File", action: #selector(openFileAction), keyEquivalent: "o")
        menu.addItem(.separator())
        menu.addItem(withTitle: editorWindowController == nil ? "Open Empty Editor" : "Show Editor", action: #selector(showEditorAction), keyEquivalent: "")
        let launchAtLoginItem = menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLaunchAtLoginAction), keyEquivalent: "")
        launchAtLoginItem.state = launchAtLoginService.menuItemState
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quitAction), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc private func captureScreenshotAction() {
        scheduleMenuCapture(copyStyled: false)
    }

    @objc private func captureAndCopyStyledAction() {
        scheduleMenuCapture(copyStyled: true)
    }

    func captureScreenshot() {
        captureScreenshot(copyStyled: false)
    }

    func captureAndCopyStyled() {
        captureScreenshot(copyStyled: true)
    }

    private func scheduleMenuCapture(copyStyled: Bool) {
        // Let the status bar menu fully dismiss before invoking screencapture.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.captureScreenshot(copyStyled: copyStyled)
        }
    }

    private func captureScreenshot(copyStyled: Bool) {
        captureService.captureInteractive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(.some(let image)):
                    if copyStyled {
                        self.copyStyledCaptureToClipboard(image)
                    } else {
                        self.openEditor(with: image, title: "Screenshot")
                    }
                case .success(.none):
                    break
                case .failure(let error):
                    self.showError(
                        title: "Capture Failed",
                        message: self.captureErrorMessage(for: error)
                    )
                }
            }
        }
    }

    @objc private func openClipboardAction() {
        openClipboard()
    }

    private func openClipboard() {
        do {
            let image = try importService.importFromClipboard()
            openEditor(with: image, title: "Clipboard")
        } catch {
            showError(title: "No Image Found", message: "The clipboard does not contain an image.")
        }
    }

    @objc private func openFileAction() {
        openFile()
    }

    private func openFile() {
        guard let image = importService.openImagePanel() else {
            return
        }
        openEditor(with: image, title: "Imported Image")
    }

    @objc private func showEditorAction() {
        if let editorWindowController {
            editorWindowController.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let placeholder = EditorState.placeholder()
        let controller = makeEditorWindowController(state: placeholder)
        controller.showWindow(nil)
        controller.showStatus("Ready")
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleLaunchAtLoginAction() {
        do {
            let result = try launchAtLoginService.toggle()
            rebuildMenu()

            switch result {
            case .enabled, .disabled:
                break
            case .requiresApproval:
                showError(
                    title: "Approve Launch at Login",
                    message: "macOS requires approval for this login item. Open System Settings > General > Login Items and allow \(AppBrand.displayName)."
                )
            }
        } catch {
            rebuildMenu()
            showError(
                title: "Launch at Login Unavailable",
                message: "TinySnapper could not register itself to start at login.\n\nMake sure you are running the signed app bundle, not the raw development executable.\n\n\(error.localizedDescription)"
            )
        }
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    private func openEditor(with image: NSImage, title: String) {
        let state = EditorState(sourceImage: image, title: title)
        let controller = editorWindowController ?? makeEditorWindowController(state: state)
        controller.load(state: state)
        controller.showWindow(nil)
        controller.showStatus("Screenshot ready")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func copyStyledCaptureToClipboard(_ image: NSImage) {
        let preset = editorWindowController?.currentStylePreset() ?? .default
        let state = EditorState(sourceImage: image, title: "Screenshot")
        state.apply(stylePreset: preset)
        exportService.copyToClipboard(from: state) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success:
                    self.editorWindowController?.showStatus("Styled capture copied")
                case .failure:
                    self.showError(title: "Copy Failed", message: "The styled screenshot could not be copied.")
                }
            }
        }
    }

    private func makeEditorWindowController(state: EditorState) -> EditorWindowController {
        let controller = EditorWindowController(
            state: state,
            exportService: exportService,
            onCaptureRequested: { [weak self] in
                self?.captureScreenshot()
            },
            onPasteRequested: { [weak self] in
                self?.openClipboard()
            },
            onOpenRequested: { [weak self] in
                self?.openFile()
            }
        )
        controller.onClose = { [weak self] in
            self?.editorWindowController = nil
            self?.rebuildMenu()
        }
        editorWindowController = controller
        rebuildMenu()
        return controller
    }

    private func captureErrorMessage(for error: CaptureError) -> String {
        switch error {
        case .failed(let message):
            let normalizedMessage = message.localizedLowercase
            if normalizedMessage.contains("screen") ||
                normalizedMessage.contains("permission") ||
                normalizedMessage.contains("could not create image from rect") {
                return "\(message)\n\nGrant Screen Recording permission in System Settings > Privacy & Security > Screen & System Audio Recording."
            }
            return message.isEmpty ? "The screenshot command failed." : message
        }
    }

    func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
