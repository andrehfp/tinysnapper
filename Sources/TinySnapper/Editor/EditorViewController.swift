import AppKit
import Foundation
import WebKit

private final class SidebarPanelView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedRed: 0.985, green: 0.988, blue: 0.993, alpha: 1).cgColor
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

@MainActor
final class EditorViewController: NSViewController, WKNavigationDelegate, WKScriptMessageHandler {
    private let exportService: ExportService
    private var state: EditorState
    private let onCaptureRequested: @MainActor () -> Void
    private let onPasteRequested: @MainActor () -> Void
    private let onOpenRequested: @MainActor () -> Void
    private let userContentController = WKUserContentController()

    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        configuration.suppressesIncrementalRendering = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        webView.translatesAutoresizingMaskIntoConstraints = false
        return webView
    }()

    private let statusLabel = NSTextField(labelWithString: "")

    private let textToolButton = NSButton(title: EditorToolShortcut.text.buttonTitle, target: nil, action: nil)
    private let arrowToolButton = NSButton(title: EditorToolShortcut.arrow.buttonTitle, target: nil, action: nil)
    private let shapeToolButton = NSButton(title: EditorToolShortcut.shape.buttonTitle, target: nil, action: nil)
    private let redactToolButton = NSButton(title: EditorToolShortcut.redact.buttonTitle, target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    private let saveButton = NSButton(title: "Save PNG", target: nil, action: nil)

    private let paddingSlider = NSSlider(value: 72, minValue: 0, maxValue: 180, target: nil, action: nil)
    private let paddingValueLabel = NSTextField(labelWithString: "")
    private let ratioPopup = NSPopUpButton()
    private let backgroundModePopup = NSPopUpButton()
    private let backgroundPresetPopup = NSPopUpButton()
    private let solidColorWell = NSColorWell()
    private let gradientStartWell = NSColorWell()
    private let gradientEndWell = NSColorWell()
    private let customBackgroundButton = NSButton(title: "Choose Background", target: nil, action: nil)
    private let shadowSlider = NSSlider(value: 32, minValue: 0, maxValue: 80, target: nil, action: nil)
    private let shadowValueLabel = NSTextField(labelWithString: "")
    private let cornerSlider = NSSlider(value: 28, minValue: 0, maxValue: 80, target: nil, action: nil)
    private let cornerValueLabel = NSTextField(labelWithString: "")
    private let tiltXSlider = NSSlider(value: 0, minValue: -20, maxValue: 20, target: nil, action: nil)
    private let tiltXValueLabel = NSTextField(labelWithString: "")
    private let tiltYSlider = NSSlider(value: 0, minValue: -20, maxValue: 20, target: nil, action: nil)
    private let tiltYValueLabel = NSTextField(labelWithString: "")
    private let resetTiltButton = NSButton(title: "Reset Tilt", target: nil, action: nil)
    private let watermarkCheckbox = NSButton(checkboxWithTitle: "Show Watermark", target: nil, action: nil)
    private let watermarkField = NSTextField(string: "")
    private let annotationColorWell = NSColorWell()
    private let shapeKindPopup = NSPopUpButton()

    private let sidePanelStack = NSStackView()
    private let quickPresetsRow = NSView()
    private let advancedDisclosureButton = NSButton(title: "", target: nil, action: nil)
    private let advancedContainer = NSView()
    private let annotationsDisclosureButton = NSButton(title: "", target: nil, action: nil)
    private let annotationsContainer = NSView()
    private let backgroundPresetRow = NSView()
    private let solidColorRow = NSView()
    private let gradientStartRow = NSView()
    private let gradientEndRow = NSView()
    private let customBackgroundRow = NSView()
    private let watermarkTextRow = NSView()
    private let shapeTypeRow = NSView()

    private let quickStyleButtons: [NSButton] = QuickStylePreset.allCases.enumerated().map { index, preset in
        let button = NSButton(title: preset.title, target: nil, action: nil)
        button.tag = index
        return button
    }

    private var canvasLoaded = false
    private var currentTool: String?
    private var isAdvancedExpanded = false
    private var isAnnotationsExpanded = true

    private var annotationToolButtons: [(NSButton, EditorToolShortcut)] {
        [
            (textToolButton, .text),
            (arrowToolButton, .arrow),
            (shapeToolButton, .shape),
            (redactToolButton, .redact),
        ]
    }

    init(
        state: EditorState,
        exportService: ExportService,
        onCaptureRequested: @escaping @MainActor () -> Void,
        onPasteRequested: @escaping @MainActor () -> Void,
        onOpenRequested: @escaping @MainActor () -> Void
    ) {
        self.state = state
        self.exportService = exportService
        self.onCaptureRequested = onCaptureRequested
        self.onPasteRequested = onPasteRequested
        self.onOpenRequested = onOpenRequested
        super.init(nibName: nil, bundle: nil)
        userContentController.add(self, name: "canvas")
        preferredContentSize = NSSize(width: 1440, height: 940)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let toolbar = buildToolbar()
        let sidePanel = buildSidePanel()
        let contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        let sidebarContainer = NSView()
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.wantsLayer = true
        sidebarContainer.layer?.backgroundColor = NSColor(calibratedRed: 0.965, green: 0.972, blue: 0.982, alpha: 1).cgColor
        sidebarContainer.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
        sidebarContainer.layer?.borderWidth = 1
        sidebarContainer.addSubview(sidePanel)
        NSLayoutConstraint.activate([
            sidePanel.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor),
            sidePanel.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            sidePanel.topAnchor.constraint(equalTo: sidebarContainer.topAnchor),
            sidePanel.bottomAnchor.constraint(equalTo: sidebarContainer.bottomAnchor),
            sidebarContainer.widthAnchor.constraint(equalToConstant: 320),
        ])

        let webContainer = NSView()
        webContainer.translatesAutoresizingMaskIntoConstraints = false
        webContainer.wantsLayer = true
        webContainer.layer?.backgroundColor = NSColor(calibratedWhite: 0.97, alpha: 1).cgColor
        webContainer.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: webContainer.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: webContainer.trailingAnchor),
            webView.topAnchor.constraint(equalTo: webContainer.topAnchor),
            webView.bottomAnchor.constraint(equalTo: webContainer.bottomAnchor),
        ])

        contentContainer.addSubview(sidebarContainer)
        contentContainer.addSubview(webContainer)
        NSLayoutConstraint.activate([
            sidebarContainer.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            sidebarContainer.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            sidebarContainer.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            sidebarContainer.widthAnchor.constraint(equalToConstant: 320),

            webContainer.leadingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            webContainer.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            webContainer.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            webContainer.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])

        view.addSubview(toolbar)
        view.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: view.topAnchor),

            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        syncControlsFromState()
        renderCanvas()
    }

    func load(state: EditorState) {
        self.state = state
        syncControlsFromState()
        renderCanvas()
    }

    func currentStylePreset() -> EditorStylePreset {
        state.stylePreset
    }

    func showStatus(_ message: String) {
        statusLabel.stringValue = message
    }

    private func buildToolbar() -> NSView {
        copyButton.target = self
        copyButton.action = #selector(copyAction)
        saveButton.target = self
        saveButton.action = #selector(saveAction)

        [copyButton, saveButton].forEach {
            $0.bezelStyle = .rounded
            $0.setButtonType(.momentaryPushIn)
        }

        for (button, shortcut) in annotationToolButtons {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.bezelStyle = .rounded
            button.setButtonType(.toggle)
            button.controlSize = .regular
            button.title = shortcut.buttonTitle
            button.image = NSImage(systemSymbolName: shortcut.symbolName, accessibilityDescription: shortcut.accessibilityDescription)
            button.imagePosition = .imageLeading
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = shortcut.tooltip
            button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 82).isActive = true
        }

        copyButton.keyEquivalent = "c"
        copyButton.keyEquivalentModifierMask = [.command]
        copyButton.bezelColor = .controlAccentColor
        copyButton.contentTintColor = .white
        copyButton.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        copyButton.controlSize = .large

        saveButton.keyEquivalent = "s"
        saveButton.keyEquivalentModifierMask = [.command]
        saveButton.controlSize = .regular

        statusLabel.stringValue = "Ready"
        statusLabel.textColor = .secondaryLabelColor

        let annotationTools = NSStackView(views: [textToolButton, arrowToolButton, shapeToolButton, redactToolButton])
        annotationTools.orientation = .horizontal
        annotationTools.spacing = 8
        annotationTools.alignment = .centerY
        annotationTools.distribution = .fillEqually

        let spacer = NSView()
        let toolbarStack = NSStackView(views: [annotationTools, statusLabel, spacer, copyButton, saveButton])
        toolbarStack.orientation = .horizontal
        toolbarStack.spacing = 10
        toolbarStack.alignment = .centerY
        toolbarStack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(toolbarStack)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 52),
            toolbarStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            toolbarStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            toolbarStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            toolbarStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
        ])

        return container
    }

    private func buildSidePanel() -> NSScrollView {
        sidePanelStack.orientation = .vertical
        sidePanelStack.spacing = 12
        sidePanelStack.alignment = .width
        sidePanelStack.translatesAutoresizingMaskIntoConstraints = false
        sidePanelStack.edgeInsets = NSEdgeInsets(top: 16, left: 14, bottom: 18, right: 14)
        sidePanelStack.detachesHiddenViews = true
        sidePanelStack.setViews([], in: .leading)

        configureControls()

        let quickPresetButtons = NSStackView(views: quickStyleButtons)
        quickPresetButtons.orientation = .horizontal
        quickPresetButtons.spacing = 8
        quickPresetButtons.alignment = .centerY
        quickPresetButtons.distribution = .fillEqually
        quickPresetButtons.translatesAutoresizingMaskIntoConstraints = false
        configureEmbeddedRow(quickPresetsRow, content: quickPresetButtons)

        let canvasStack = NSStackView(views: [
            controlRow("Padding", control: paddingSlider, valueLabel: paddingValueLabel)
        ])
        canvasStack.orientation = .vertical
        canvasStack.spacing = 12
        canvasStack.alignment = .width
        canvasStack.translatesAutoresizingMaskIntoConstraints = false

        let styleStack = NSStackView(views: [
            labeledRow("Background", control: backgroundModePopup),
            backgroundPresetRow,
            solidColorRow,
            gradientStartRow,
            gradientEndRow,
            customBackgroundRow,
            controlRow("Shadow", control: shadowSlider, valueLabel: shadowValueLabel),
            controlRow("Corner Radius", control: cornerSlider, valueLabel: cornerValueLabel),
        ])
        styleStack.orientation = .vertical
        styleStack.spacing = 12
        styleStack.alignment = .width
        styleStack.translatesAutoresizingMaskIntoConstraints = false

        let advancedRows = NSStackView(views: [
            labeledRow("Aspect Ratio", control: ratioPopup),
            controlRow("Tilt X", control: tiltXSlider, valueLabel: tiltXValueLabel),
            controlRow("Tilt Y", control: tiltYSlider, valueLabel: tiltYValueLabel),
            resetTiltButton,
            watermarkCheckbox,
            watermarkTextRow,
        ])
        advancedRows.orientation = .vertical
        advancedRows.spacing = 12
        advancedRows.alignment = .width
        advancedRows.translatesAutoresizingMaskIntoConstraints = false
        configureEmbeddedRow(advancedContainer, content: advancedRows)

        let annotationsRows = NSStackView(views: [
            labeledRow("Color", control: annotationColorWell),
            shapeTypeRow,
            shortcutLegend(),
        ])
        annotationsRows.orientation = .vertical
        annotationsRows.spacing = 12
        annotationsRows.alignment = .width
        annotationsRows.translatesAutoresizingMaskIntoConstraints = false
        configureEmbeddedRow(annotationsContainer, content: annotationsRows)

        sidePanelStack.addArrangedSubview(sidebarSection(
            title: "Quick Styles",
            subtitle: "One-click presets for the screenshot frame.",
            content: quickPresetsRow
        ))
        sidePanelStack.addArrangedSubview(sidebarSection(
            title: "Canvas",
            subtitle: "Control the space around the captured image.",
            content: canvasStack
        ))
        sidePanelStack.addArrangedSubview(sidebarSection(
            title: "Style",
            subtitle: "Set the background, depth, and corner treatment.",
            content: styleStack
        ))
        sidePanelStack.addArrangedSubview(sidebarDisclosureSection(button: advancedDisclosureButton, content: advancedContainer))
        sidePanelStack.addArrangedSubview(sidebarDisclosureSection(button: annotationsDisclosureButton, content: annotationsContainer))

        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(sidePanelStack)
        NSLayoutConstraint.activate([
            sidePanelStack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            sidePanelStack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            sidePanelStack.topAnchor.constraint(equalTo: document.topAnchor),
            sidePanelStack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            sidePanelStack.widthAnchor.constraint(equalTo: document.widthAnchor),
        ])

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = document
        return scrollView
    }

    private func configureControls() {
        ratioPopup.removeAllItems()
        ratioPopup.addItems(withTitles: RatioPreset.allCases.map(\.title))
        ratioPopup.target = self
        ratioPopup.action = #selector(ratioChanged)

        backgroundModePopup.removeAllItems()
        backgroundModePopup.addItems(withTitles: BackgroundMode.allCases.map(\.title))
        backgroundModePopup.target = self
        backgroundModePopup.action = #selector(backgroundModeChanged)

        backgroundPresetPopup.removeAllItems()
        backgroundPresetPopup.addItems(withTitles: BackgroundPreset.allCases.map(\.title))
        backgroundPresetPopup.target = self
        backgroundPresetPopup.action = #selector(backgroundPresetChanged)

        solidColorWell.target = self
        solidColorWell.action = #selector(colorControlChanged)
        gradientStartWell.target = self
        gradientStartWell.action = #selector(colorControlChanged)
        gradientEndWell.target = self
        gradientEndWell.action = #selector(colorControlChanged)
        customBackgroundButton.target = self
        customBackgroundButton.action = #selector(selectBackgroundImage)

        [paddingSlider, shadowSlider, cornerSlider, tiltXSlider, tiltYSlider].forEach {
            $0.target = self
            $0.action = #selector(sliderChanged(_:))
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalToConstant: 236).isActive = true
        }

        [ratioPopup, backgroundModePopup, backgroundPresetPopup, shapeKindPopup].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalToConstant: 236).isActive = true
        }

        [customBackgroundButton, resetTiltButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalToConstant: 236).isActive = true
        }

        watermarkField.translatesAutoresizingMaskIntoConstraints = false
        watermarkField.widthAnchor.constraint(equalToConstant: 236).isActive = true

        [solidColorWell, gradientStartWell, gradientEndWell, annotationColorWell].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalToConstant: 44).isActive = true
            $0.heightAnchor.constraint(equalToConstant: 24).isActive = true
        }

        resetTiltButton.target = self
        resetTiltButton.action = #selector(resetTiltAction)

        watermarkCheckbox.target = self
        watermarkCheckbox.action = #selector(watermarkToggleChanged)
        watermarkField.target = self
        watermarkField.action = #selector(watermarkFieldChanged)

        annotationColorWell.target = self
        annotationColorWell.action = #selector(annotationConfigChanged)

        shapeKindPopup.removeAllItems()
        shapeKindPopup.addItems(withTitles: ShapeKind.allCases.map(\.title))
        shapeKindPopup.target = self
        shapeKindPopup.action = #selector(annotationConfigChanged)

        for button in quickStyleButtons {
            button.target = self
            button.action = #selector(quickStyleAction(_:))
            button.bezelStyle = .rounded
            button.setButtonType(.momentaryPushIn)
            button.controlSize = .small
            button.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        }

        configureRow(backgroundPresetRow, labelText: "Preset", control: backgroundPresetPopup)
        configureRow(solidColorRow, labelText: "Color", control: solidColorWell)
        configureRow(gradientStartRow, labelText: "Gradient Start", control: gradientStartWell)
        configureRow(gradientEndRow, labelText: "Gradient End", control: gradientEndWell)
        configureRow(customBackgroundRow, labelText: "Image", control: customBackgroundButton)
        configureRow(watermarkTextRow, labelText: "Text", control: watermarkField)
        configureRow(shapeTypeRow, labelText: "Shape Type", control: shapeKindPopup)

        advancedDisclosureButton.target = self
        advancedDisclosureButton.action = #selector(toggleAdvancedSection)
        advancedDisclosureButton.bezelStyle = .inline
        advancedDisclosureButton.setButtonType(.momentaryPushIn)
        advancedDisclosureButton.isBordered = false
        advancedDisclosureButton.contentTintColor = .labelColor
        advancedDisclosureButton.alignment = .left
        advancedDisclosureButton.font = NSFont.systemFont(ofSize: 12, weight: .semibold)

        annotationsDisclosureButton.target = self
        annotationsDisclosureButton.action = #selector(toggleAnnotationsSection)
        annotationsDisclosureButton.bezelStyle = .inline
        annotationsDisclosureButton.setButtonType(.momentaryPushIn)
        annotationsDisclosureButton.isBordered = false
        annotationsDisclosureButton.contentTintColor = .labelColor
        annotationsDisclosureButton.alignment = .left
        annotationsDisclosureButton.font = NSFont.systemFont(ofSize: 12, weight: .semibold)

        for (button, _) in annotationToolButtons {
            button.target = self
            button.bezelStyle = .rounded
            button.setButtonType(.toggle)
        }

        textToolButton.action = #selector(textToolAction)
        arrowToolButton.action = #selector(arrowToolAction)
        shapeToolButton.action = #selector(shapeToolAction)
        redactToolButton.action = #selector(redactToolAction)
    }

    private func configureRow(_ row: NSView, labelText: String, control: NSView) {
        let content = labeledRow(labelText, control: control)
        configureEmbeddedRow(row, content: content)
    }

    private func configureEmbeddedRow(_ row: NSView, content: NSView) {
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            content.topAnchor.constraint(equalTo: row.topAnchor),
            content.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        ])
    }

    private func sidebarSection(title: String, subtitle: String? = nil, content: NSView) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .labelColor

        var headerViews: [NSView] = [titleLabel]
        if let subtitle {
            let subtitleLabel = NSTextField(wrappingLabelWithString: subtitle)
            subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
            subtitleLabel.textColor = .secondaryLabelColor
            subtitleLabel.maximumNumberOfLines = 2
            headerViews.append(subtitleLabel)
        }

        let headerStack = NSStackView(views: headerViews)
        headerStack.orientation = .vertical
        headerStack.spacing = 3
        headerStack.alignment = .leading
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [headerStack, content])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false

        let panel = SidebarPanelView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -12),
        ])
        return panel
    }

    private func sidebarDisclosureSection(button: NSButton, content: NSView) -> NSView {
        let stack = NSStackView(views: [button, content])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false

        let panel = SidebarPanelView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -12),
        ])
        return panel
    }

    private func controlRow(_ labelText: String, control: NSView, valueLabel: NSTextField) -> NSView {
        let label = NSTextField(labelWithString: labelText)
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .labelColor

        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right

        let spacer = NSView()
        let header = NSStackView(views: [label, spacer, valueLabel])
        header.orientation = .horizontal
        header.spacing = 8
        header.alignment = .centerY
        header.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [header, control])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func shortcutLegend() -> NSView {
        let title = NSTextField(labelWithString: "Shortcuts")
        title.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        title.textColor = .secondaryLabelColor

        let rows = EditorToolShortcut.keyboardShortcuts.map { shortcut in
            shortcutLegendItem(shortcut)
        }

        let list = NSStackView(views: rows)
        list.orientation = .vertical
        list.spacing = 7
        list.alignment = .width
        list.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [title, list])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func shortcutLegendItem(_ shortcut: EditorToolShortcut) -> NSView {
        let keyLabel = NSTextField(labelWithString: shortcut.display)
        keyLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        keyLabel.alignment = .center
        keyLabel.textColor = .labelColor
        keyLabel.wantsLayer = true
        keyLabel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        keyLabel.layer?.cornerRadius = 4
        keyLabel.layer?.borderWidth = 1
        keyLabel.layer?.borderColor = NSColor.separatorColor.cgColor
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            keyLabel.widthAnchor.constraint(equalToConstant: 24),
            keyLabel.heightAnchor.constraint(equalToConstant: 22),
        ])

        let label = NSTextField(labelWithString: shortcut.title)
        label.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = .labelColor

        let spacer = NSView()
        let row = NSStackView(views: [keyLabel, label, spacer])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func sectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text.uppercased())
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func labeledRow(_ labelText: String, control: NSView) -> NSView {
        let label = NSTextField(labelWithString: labelText)
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let stack = NSStackView(views: [label, control])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func syncControlsFromState() {
        paddingSlider.doubleValue = state.padding
        ratioPopup.selectItem(at: RatioPreset.allCases.firstIndex(of: state.ratioPreset) ?? 0)
        backgroundModePopup.selectItem(at: BackgroundMode.allCases.firstIndex(of: state.backgroundMode) ?? 0)
        backgroundPresetPopup.selectItem(at: BackgroundPreset.allCases.firstIndex(of: state.backgroundPreset) ?? 0)
        solidColorWell.color = state.solidColor
        gradientStartWell.color = state.gradientStartColor
        gradientEndWell.color = state.gradientEndColor
        shadowSlider.doubleValue = state.shadow
        cornerSlider.doubleValue = state.cornerRadius
        tiltXSlider.doubleValue = state.tiltX
        tiltYSlider.doubleValue = state.tiltY
        watermarkCheckbox.state = state.watermarkEnabled ? .on : .off
        watermarkField.stringValue = state.watermarkText
        annotationColorWell.color = state.annotationColor
        shapeKindPopup.selectItem(at: ShapeKind.allCases.firstIndex(of: state.selectedShapeKind) ?? 0)
        customBackgroundButton.title = state.customBackgroundImage == nil ? "Choose Background" : "Replace Background"
        updateSliderValueLabels()
        updateDisclosureTitles()
        updateControlVisibility()
        refreshQuickPresetButtons()
        setReadyStatus()
    }

    private func setReadyStatus() {
        statusLabel.stringValue = state.isPlaceholder ? "Ready" : "Screenshot ready"
    }

    private func updateSliderValueLabels() {
        paddingValueLabel.stringValue = "\(Int(round(paddingSlider.doubleValue))) px"
        shadowValueLabel.stringValue = "\(Int(round(shadowSlider.doubleValue)))"
        cornerValueLabel.stringValue = "\(Int(round(cornerSlider.doubleValue))) px"
        tiltXValueLabel.stringValue = "\(Int(round(tiltXSlider.doubleValue))) deg"
        tiltYValueLabel.stringValue = "\(Int(round(tiltYSlider.doubleValue))) deg"
    }

    private func renderCanvas() {
        if canvasLoaded {
            let json = CanvasRenderer.payloadJSON(for: state, interactive: true)
            webView.evaluateJavaScript("window.updatePayload(\(json));")
        } else {
            canvasLoaded = false
            webView.alphaValue = 0
            webView.loadHTMLString(CanvasRenderer.html(for: state, interactive: true), baseURL: CanvasRenderer.resourceBaseURL())
        }
    }

    private func pushToolConfigToCanvas() {
        guard canvasLoaded else { return }
        let config: [String: String] = [
            "annotationColor": state.annotationColor.hexString,
            "shapeKind": state.selectedShapeKind.rawValue,
        ]

        guard
            let data = try? JSONSerialization.data(withJSONObject: config),
            let json = String(data: data, encoding: .utf8)
        else {
            return
        }

        webView.evaluateJavaScript("window.updateEditorConfig(\(json));")
    }

    private func activateTool(_ tool: String?) {
        currentTool = tool
        updateToolButtonState()
        updateControlVisibility()
        guard canvasLoaded else { return }
        if let tool {
            webView.evaluateJavaScript("window.activateTool('\(tool)');")
        } else {
            webView.evaluateJavaScript("window.activateTool(null);")
        }
    }

    private func updateToolButtonState() {
        for (button, shortcut) in annotationToolButtons {
            let selected = currentTool == shortcut.tool
            button.state = selected ? .on : .off
            button.contentTintColor = selected ? .white : .labelColor
            button.bezelColor = selected ? .controlAccentColor : nil
            button.font = NSFont.systemFont(ofSize: 12, weight: selected ? .semibold : .medium)
        }
    }

    private func refreshQuickPresetButtons() {
        let activePreset = QuickStylePreset.allCases.first { $0.matches(state: state) }
        for (index, button) in quickStyleButtons.enumerated() {
            let preset = QuickStylePreset.allCases[index]
            let isActive = preset == activePreset
            button.contentTintColor = isActive ? .white : .labelColor
            button.bezelColor = isActive ? .controlAccentColor : nil
            button.font = NSFont.systemFont(ofSize: 11, weight: isActive ? .semibold : .regular)
        }
    }

    private func updateDisclosureTitles() {
        advancedDisclosureButton.title = isAdvancedExpanded ? "▾ Advanced" : "▸ Advanced"
        annotationsDisclosureButton.title = isAnnotationsExpanded ? "▾ Annotations" : "▸ Annotations"
    }

    private func updateControlVisibility() {
        let backgroundMode = state.backgroundMode
        backgroundPresetRow.isHidden = backgroundMode != .preset
        solidColorRow.isHidden = backgroundMode != .solid
        gradientStartRow.isHidden = backgroundMode != .gradient
        gradientEndRow.isHidden = backgroundMode != .gradient
        customBackgroundRow.isHidden = backgroundMode != .customImage
        watermarkTextRow.isHidden = !state.watermarkEnabled
        shapeTypeRow.isHidden = currentTool != "shape"
        advancedContainer.isHidden = !isAdvancedExpanded
        annotationsContainer.isHidden = !isAnnotationsExpanded
    }

    @objc private func toggleAdvancedSection() {
        isAdvancedExpanded.toggle()
        updateDisclosureTitles()
        updateControlVisibility()
    }

    @objc private func toggleAnnotationsSection() {
        isAnnotationsExpanded.toggle()
        updateDisclosureTitles()
        updateControlVisibility()
    }

    @objc private func quickStyleAction(_ sender: NSButton) {
        let preset = QuickStylePreset.allCases[sender.tag]
        state.apply(stylePreset: preset.preset)
        syncControlsFromState()
        renderCanvas()
    }

    @objc private func textToolAction() {
        activateTool(currentTool == "text" ? nil : "text")
    }

    @objc private func arrowToolAction() {
        activateTool(currentTool == "arrow" ? nil : "arrow")
    }

    @objc private func shapeToolAction() {
        activateTool(currentTool == "shape" ? nil : "shape")
    }

    @objc private func redactToolAction() {
        activateTool(currentTool == "redact" ? nil : "redact")
    }

    @objc private func copyAction() {
        exportService.copyToClipboard(from: state) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.statusLabel.stringValue = "Copied"
                case .failure:
                    self.showError(title: "Copy Failed", message: "The current composition could not be copied.")
                }
            }
        }
    }

    @objc private func saveAction() {
        exportService.savePNG(from: state) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.statusLabel.stringValue = "Saved"
                case .failure:
                    self.showError(title: "Save Failed", message: "The current composition could not be exported.")
                }
            }
        }
    }

    @objc private func ratioChanged() {
        state.ratioPreset = RatioPreset.allCases[ratioPopup.indexOfSelectedItem]
        renderCanvas()
    }

    @objc private func backgroundModeChanged() {
        state.backgroundMode = BackgroundMode.allCases[backgroundModePopup.indexOfSelectedItem]
        updateControlVisibility()
        if state.backgroundMode == .customImage, state.customBackgroundImage == nil {
            selectBackgroundImage()
            return
        }
        renderCanvas()
    }

    @objc private func backgroundPresetChanged() {
        state.backgroundPreset = BackgroundPreset.allCases[backgroundPresetPopup.indexOfSelectedItem]
        if state.backgroundMode == .preset {
            renderCanvas()
        }
    }

    @objc private func colorControlChanged() {
        state.solidColor = solidColorWell.color
        state.gradientStartColor = gradientStartWell.color
        state.gradientEndColor = gradientEndWell.color
        renderCanvas()
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        switch sender {
        case paddingSlider:
            state.padding = sender.doubleValue
        case shadowSlider:
            state.shadow = sender.doubleValue
        case cornerSlider:
            state.cornerRadius = sender.doubleValue
        case tiltXSlider:
            state.tiltX = sender.doubleValue
        case tiltYSlider:
            state.tiltY = sender.doubleValue
        default:
            break
        }
        updateSliderValueLabels()
        renderCanvas()
    }

    @objc private func resetTiltAction() {
        state.tiltX = 0
        state.tiltY = 0
        syncControlsFromState()
        renderCanvas()
    }

    @objc private func watermarkToggleChanged() {
        state.watermarkEnabled = watermarkCheckbox.state == .on
        updateControlVisibility()
        renderCanvas()
    }

    @objc private func watermarkFieldChanged() {
        state.watermarkText = watermarkField.stringValue
        renderCanvas()
    }

    @objc private func annotationConfigChanged() {
        state.annotationColor = annotationColorWell.color
        state.selectedShapeKind = ShapeKind.allCases[shapeKindPopup.indexOfSelectedItem]
        updateControlVisibility()
        pushToolConfigToCanvas()
    }

    @objc private func selectBackgroundImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .gif, .bmp]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else {
            return
        }

        state.customBackgroundImage = image
        state.backgroundMode = .customImage
        syncControlsFromState()
        renderCanvas()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        canvasLoaded = true
        webView.alphaValue = 1
        pushToolConfigToCanvas()
        activateTool(currentTool)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        webView.alphaValue = 1
        showError(title: "Canvas Error", message: error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        webView.alphaValue = 1
        showError(title: "Canvas Error", message: error.localizedDescription)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            message.name == "canvas",
            let body = message.body as? [String: Any],
            let type = body["type"] as? String
        else {
            return
        }

        switch type {
        case "annotationsChanged":
            if let annotations = body["annotations"] {
                updateAnnotations(from: annotations)
            }
        case "toolChanged":
            currentTool = body["tool"] as? String
            updateToolButtonState()
            updateControlVisibility()
        case "launchAction":
            guard let action = body["action"] as? String else { return }
            switch action {
            case "capture":
                onCaptureRequested()
            case "paste":
                onPasteRequested()
            case "open":
                onOpenRequested()
            default:
                break
            }
        case "bootError":
            let message = body["message"] as? String ?? "Unknown canvas boot failure."
            showError(title: "Canvas Error", message: message)
        default:
            break
        }
    }

    private func updateAnnotations(from object: Any) {
        guard JSONSerialization.isValidJSONObject(object), let data = try? JSONSerialization.data(withJSONObject: object) else {
            return
        }

        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([Annotation].self, from: data) {
            state.annotations = decoded
        }
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.beginSheetModal(for: view.window ?? NSWindow()) { _ in }
    }
}
