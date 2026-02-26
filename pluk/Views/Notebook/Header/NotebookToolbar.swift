import AppKit

final class NotebookToolbarController: NSViewController {

    private let dataController: NotebookDataController

    private var containerView: NSView!

    // Normal toolbar
    private var normalToolbar: NSView!
    private var segmentContainer: NSView!
    private var segmentHighlight: NSView!
    private var notebookSegmentButton: NSButton!
    private var dashboardSegmentButton: NSButton!
    private var publishButton: NSView!
    private var chatButton: NSView!
    private var scrolledTitleLabel: NSTextField!
    private var scrolledBackground: NSView!
    private var scrolledDivider: NSView!

    // Published toolbar
    private var publishedToolbar: NSView!
    private var editButton: NSView!
    private var publishedScrolledBackground: NSView!
    private var publishedScrolledDivider: NSView!

    private var segmentHighlightLeading: NSLayoutConstraint!

    init(dataController: NotebookDataController) {
        self.dataController = dataController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        containerView = NSView()
        containerView.wantsLayer = true
        self.view = containerView

        setupNormalToolbar()
        setupPublishedToolbar()
        setupContainerConstraints()
        updateScrolledColors()
        applyState()
        observeViewMode()
        observeScrollState()
        observeTitle()
        observePublishedState()
    }

    // MARK: - Normal Toolbar

    private func setupNormalToolbar() {
        normalToolbar = NSView()
        normalToolbar.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(normalToolbar)

        setupScrolledBackground()
        setupSegmentedControl()
        setupTrailingButtons()
        setupScrolledTitle()
        setupNormalConstraints()
    }

    private func setupScrolledBackground() {
        let effect = NSVisualEffectView()
        effect.material = .headerView
        effect.blendingMode = .withinWindow
        effect.wantsLayer = true
        effect.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        effect.layer?.cornerRadius = 16
        effect.layer?.masksToBounds = true
        effect.translatesAutoresizingMaskIntoConstraints = false
        effect.isHidden = true
        scrolledBackground = effect
        normalToolbar.addSubview(scrolledBackground, positioned: .below, relativeTo: nil)

        scrolledDivider = NSView()
        scrolledDivider.wantsLayer = true
        scrolledDivider.alphaValue = 0.5
        scrolledDivider.translatesAutoresizingMaskIntoConstraints = false
        scrolledDivider.isHidden = true
        normalToolbar.addSubview(scrolledDivider)

        updateScrolledColors()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: .appAppearanceDidChange,
            object: nil
        )
    }

    private func setupSegmentedControl() {
        segmentContainer = NSView()
        segmentContainer.wantsLayer = true
        segmentContainer.translatesAutoresizingMaskIntoConstraints = false
        normalToolbar.addSubview(segmentContainer)

        updateSegmentContainerColor()

        segmentHighlight = NSView()
        segmentHighlight.wantsLayer = true
        segmentHighlight.layer?.cornerRadius = 4
        segmentHighlight.translatesAutoresizingMaskIntoConstraints = false
        segmentContainer.addSubview(segmentHighlight)

        updateSegmentHighlightColor()
        updateSegmentHighlightShadow()

        notebookSegmentButton = makeSegmentButton(title: "Notebook", action: #selector(selectNotebook))
        dashboardSegmentButton = makeSegmentButton(title: "Dashboard", action: #selector(selectDashboard))
        segmentContainer.addSubview(notebookSegmentButton)
        segmentContainer.addSubview(dashboardSegmentButton)

        segmentContainer.layer?.cornerRadius = 6

        segmentHighlightLeading = segmentHighlight.leadingAnchor.constraint(
            equalTo: notebookSegmentButton.leadingAnchor
        )

        NSLayoutConstraint.activate([
            notebookSegmentButton.leadingAnchor.constraint(equalTo: segmentContainer.leadingAnchor, constant: 2),
            notebookSegmentButton.topAnchor.constraint(equalTo: segmentContainer.topAnchor, constant: 2),
            notebookSegmentButton.bottomAnchor.constraint(equalTo: segmentContainer.bottomAnchor, constant: -2),

            dashboardSegmentButton.leadingAnchor.constraint(equalTo: notebookSegmentButton.trailingAnchor),
            dashboardSegmentButton.topAnchor.constraint(equalTo: segmentContainer.topAnchor, constant: 2),
            dashboardSegmentButton.bottomAnchor.constraint(equalTo: segmentContainer.bottomAnchor, constant: -2),
            dashboardSegmentButton.trailingAnchor.constraint(equalTo: segmentContainer.trailingAnchor, constant: -2),

            segmentHighlightLeading,
            segmentHighlight.topAnchor.constraint(equalTo: notebookSegmentButton.topAnchor),
            segmentHighlight.bottomAnchor.constraint(equalTo: notebookSegmentButton.bottomAnchor),
            segmentHighlight.widthAnchor.constraint(equalTo: notebookSegmentButton.widthAnchor),
        ])

        updateSegmentSelection(animated: false)
    }

    private func makeSegmentButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.font = .systemFont(ofSize: 11, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        (button.cell as? NSButtonCell)?.highlightsBy = []
        button.contentTintColor = .secondaryLabelColor
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
        return button
    }

    private func setupTrailingButtons() {
        publishButton = makeIconLabelButton(icon: "square.and.arrow.up", label: "Share", action: #selector(publishTapped))
        normalToolbar.addSubview(publishButton)

        chatButton = makeIconLabelButton(icon: "bubble.fill", label: "Chat", action: #selector(chatTapped))
        normalToolbar.addSubview(chatButton)
    }

    private func makeIconLabelButton(icon: String, label: String, action: Selector) -> NSView {
        let wrapper = ToolbarButtonView(target: self, action: action)
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: icon, accessibilityDescription: label)
        imageView.symbolConfiguration = .init(pointSize: 11, weight: .regular)
        imageView.contentTintColor = .labelColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(imageView)

        let textField = NSTextField(labelWithString: label)
        textField.font = .systemFont(ofSize: 12)
        textField.textColor = .labelColor
        textField.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(textField)

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        wrapper.layer?.backgroundColor = isDark
            ? NSColor.white.withAlphaComponent(0.04).cgColor
            : NSColor.black.withAlphaComponent(0.04).cgColor

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 8),
            imageView.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
            textField.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
            textField.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -8),
            wrapper.heightAnchor.constraint(equalToConstant: 28),
        ])

        return wrapper
    }

    private func setupScrolledTitle() {
        scrolledTitleLabel = NSTextField(labelWithString: "")
        scrolledTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        scrolledTitleLabel.textColor = .labelColor
        scrolledTitleLabel.lineBreakMode = .byTruncatingTail
        scrolledTitleLabel.maximumNumberOfLines = 1
        scrolledTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        scrolledTitleLabel.isHidden = true
        normalToolbar.addSubview(scrolledTitleLabel)
    }

    private func setupNormalConstraints() {
        NSLayoutConstraint.activate([
            segmentContainer.centerXAnchor.constraint(equalTo: normalToolbar.centerXAnchor),
            segmentContainer.centerYAnchor.constraint(equalTo: normalToolbar.centerYAnchor),

            scrolledTitleLabel.leadingAnchor.constraint(equalTo: normalToolbar.leadingAnchor, constant: 16),
            scrolledTitleLabel.centerYAnchor.constraint(equalTo: normalToolbar.centerYAnchor),
            scrolledTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: segmentContainer.leadingAnchor, constant: -8),

            chatButton.trailingAnchor.constraint(equalTo: normalToolbar.trailingAnchor, constant: -8),
            chatButton.centerYAnchor.constraint(equalTo: normalToolbar.centerYAnchor),

            publishButton.trailingAnchor.constraint(equalTo: chatButton.leadingAnchor, constant: -8),
            publishButton.centerYAnchor.constraint(equalTo: normalToolbar.centerYAnchor),

            scrolledBackground.topAnchor.constraint(equalTo: normalToolbar.topAnchor),
            scrolledBackground.leadingAnchor.constraint(equalTo: normalToolbar.leadingAnchor),
            scrolledBackground.trailingAnchor.constraint(equalTo: normalToolbar.trailingAnchor),
            scrolledBackground.bottomAnchor.constraint(equalTo: normalToolbar.bottomAnchor),

            scrolledDivider.leadingAnchor.constraint(equalTo: normalToolbar.leadingAnchor),
            scrolledDivider.trailingAnchor.constraint(equalTo: normalToolbar.trailingAnchor),
            scrolledDivider.bottomAnchor.constraint(equalTo: normalToolbar.bottomAnchor),
            scrolledDivider.heightAnchor.constraint(equalToConstant: 1.0 / (NSScreen.main?.backingScaleFactor ?? 2)),
        ])
    }

    // MARK: - Published Toolbar

    private func setupPublishedToolbar() {
        publishedToolbar = NSView()
        publishedToolbar.translatesAutoresizingMaskIntoConstraints = false
        publishedToolbar.isHidden = true
        containerView.addSubview(publishedToolbar)

        let pubEffect = NSVisualEffectView()
        pubEffect.material = .headerView
        pubEffect.blendingMode = .withinWindow
        pubEffect.wantsLayer = true
        pubEffect.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        pubEffect.layer?.cornerRadius = 16
        pubEffect.layer?.masksToBounds = true
        pubEffect.translatesAutoresizingMaskIntoConstraints = false
        publishedScrolledBackground = pubEffect
        publishedToolbar.addSubview(publishedScrolledBackground, positioned: .below, relativeTo: nil)

        publishedScrolledDivider = NSView()
        publishedScrolledDivider.wantsLayer = true
        publishedScrolledDivider.alphaValue = 0.5
        publishedScrolledDivider.translatesAutoresizingMaskIntoConstraints = false
        publishedToolbar.addSubview(publishedScrolledDivider)

        editButton = makeIconLabelButton(icon: "pencil", label: "Edit", action: #selector(editTapped))
        publishedToolbar.addSubview(editButton)

        NSLayoutConstraint.activate([
            editButton.trailingAnchor.constraint(equalTo: publishedToolbar.trailingAnchor, constant: -8),
            editButton.centerYAnchor.constraint(equalTo: publishedToolbar.centerYAnchor),

            publishedScrolledBackground.topAnchor.constraint(equalTo: publishedToolbar.topAnchor),
            publishedScrolledBackground.leadingAnchor.constraint(equalTo: publishedToolbar.leadingAnchor),
            publishedScrolledBackground.trailingAnchor.constraint(equalTo: publishedToolbar.trailingAnchor),
            publishedScrolledBackground.bottomAnchor.constraint(equalTo: publishedToolbar.bottomAnchor),

            publishedScrolledDivider.leadingAnchor.constraint(equalTo: publishedToolbar.leadingAnchor),
            publishedScrolledDivider.trailingAnchor.constraint(equalTo: publishedToolbar.trailingAnchor),
            publishedScrolledDivider.bottomAnchor.constraint(equalTo: publishedToolbar.bottomAnchor),
            publishedScrolledDivider.heightAnchor.constraint(equalToConstant: 1.0 / (NSScreen.main?.backingScaleFactor ?? 2)),
        ])
    }

    // MARK: - Container Constraints

    private func setupContainerConstraints() {
        NSLayoutConstraint.activate([
            normalToolbar.topAnchor.constraint(equalTo: containerView.topAnchor),
            normalToolbar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            normalToolbar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            normalToolbar.heightAnchor.constraint(equalToConstant: 44),
            normalToolbar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            publishedToolbar.topAnchor.constraint(equalTo: containerView.topAnchor),
            publishedToolbar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            publishedToolbar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            publishedToolbar.heightAnchor.constraint(equalToConstant: 44),
            publishedToolbar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }

    // MARK: - State

    private func applyState() {
        let isDashboardPublished = dataController.viewMode == .dashboard && dataController.isPublished
        normalToolbar.isHidden = isDashboardPublished
        publishedToolbar.isHidden = !isDashboardPublished

        updateScrollState()
        updateScrolledTitleText()
        updateSegmentSelection(animated: false)
    }

    private func updateScrollState() {
        let scrolled = dataController.isScrolled
        scrolledTitleLabel.isHidden = !scrolled
        scrolledBackground.isHidden = !scrolled
        scrolledDivider.isHidden = !scrolled

        publishedScrolledBackground.isHidden = !scrolled
        publishedScrolledDivider.isHidden = !scrolled
    }

    private func updateScrolledTitleText() {
        let title = dataController.title
        scrolledTitleLabel.stringValue = title.isEmpty ? "Untitled Notebook" : title
    }

    private func updateSegmentSelection(animated: Bool) {
        let isNotebook = dataController.viewMode == .notebook
        let targetButton = isNotebook ? notebookSegmentButton! : dashboardSegmentButton!

        notebookSegmentButton.contentTintColor = isNotebook ? .labelColor : .secondaryLabelColor
        dashboardSegmentButton.contentTintColor = isNotebook ? .secondaryLabelColor : .labelColor

        segmentHighlightLeading.isActive = false
        segmentHighlightLeading = segmentHighlight.leadingAnchor.constraint(equalTo: targetButton.leadingAnchor)
        segmentHighlightLeading.isActive = true

        for c in segmentHighlight.constraints where c.firstAttribute == .width {
            c.isActive = false
        }
        segmentHighlight.widthAnchor.constraint(equalTo: targetButton.widthAnchor).isActive = true

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.allowsImplicitAnimation = true
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1.0)
                self.segmentContainer.layoutSubtreeIfNeeded()
            }
        }
    }

    // MARK: - Actions

    @objc private func selectNotebook() {
        guard dataController.viewMode != .notebook else { return }
        dataController.viewMode = .notebook
    }

    @objc private func selectDashboard() {
        guard dataController.viewMode != .dashboard else { return }
        dataController.viewMode = .dashboard
    }

    @objc private func publishTapped() {
        if dataController.viewMode != .dashboard {
            dataController.viewMode = .dashboard
        }

        let popoverVC = PublishConfirmationController { [weak self] in
            self?.dataController.publishDashboard()
        }
        let pop = NSPopover()
        pop.contentViewController = popoverVC
        pop.behavior = .transient
        popoverVC.popover = pop
        pop.show(relativeTo: publishButton.bounds, of: publishButton, preferredEdge: .maxY)
    }

    @objc private func editTapped() {
        dataController.unpublishDashboard()
    }

    @objc private func chatTapped() {
        dataController.isRightSidebarVisible.toggle()
    }

    // MARK: - Appearance

    @objc private func appearanceChanged() {
        updateScrolledColors()
        updateSegmentContainerColor()
        updateSegmentHighlightColor()
        updateButtonBackgrounds()
    }

    private func updateScrolledColors() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            scrolledDivider?.layer?.backgroundColor = NSColor.separatorColor.cgColor
            publishedScrolledDivider?.layer?.backgroundColor = NSColor.separatorColor.cgColor
        }
    }

    private func updateSegmentContainerColor() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            segmentContainer?.layer?.backgroundColor = isDark
                ? NSColor.black.withAlphaComponent(0.2).cgColor
                : NSColor.black.withAlphaComponent(0.04).cgColor
        }
    }

    private func updateSegmentHighlightColor() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            segmentHighlight?.layer?.backgroundColor = isDark
                ? NSColor.controlColor.withAlphaComponent(0.3).cgColor
                : NSColor.white.cgColor
        }
    }

    private func updateSegmentHighlightShadow() {
        segmentHighlight.shadow = NSShadow()
        segmentHighlight.layer?.shadowColor = NSColor.black.withAlphaComponent(0.10).cgColor
        segmentHighlight.layer?.shadowOpacity = 1
        segmentHighlight.layer?.shadowRadius = 1
        segmentHighlight.layer?.shadowOffset = .zero
    }

    private func updateButtonBackgrounds() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            let bgColor = isDark
                ? NSColor.white.withAlphaComponent(0.04).cgColor
                : NSColor.black.withAlphaComponent(0.04).cgColor
            chatButton?.layer?.backgroundColor = bgColor
            editButton?.layer?.backgroundColor = bgColor
        }
    }

    // MARK: - Observation

    private func observeViewMode() {
        withObservationTracking {
            _ = self.dataController.viewMode
            _ = self.dataController.isPublished
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let isDashboardPublished = self.dataController.viewMode == .dashboard && self.dataController.isPublished
                self.normalToolbar.isHidden = isDashboardPublished
                self.publishedToolbar.isHidden = !isDashboardPublished
                self.updateSegmentSelection(animated: true)
                self.observeViewMode()
            }
        }
    }

    private func observeScrollState() {
        withObservationTracking {
            _ = self.dataController.isScrolled
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateScrollState()
                self.observeScrollState()
            }
        }
    }

    private func observeTitle() {
        withObservationTracking {
            _ = self.dataController.title
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateScrolledTitleText()
                self.observeTitle()
            }
        }
    }

    private func observePublishedState() {
        withObservationTracking {
            _ = self.dataController.isDashboardPublished
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let isDashboardPublished = self.dataController.isDashboardPublished
                self.normalToolbar.isHidden = isDashboardPublished
                self.publishedToolbar.isHidden = !isDashboardPublished
                self.observePublishedState()
            }
        }
    }
}

// MARK: - Toolbar Button View

private final class ToolbarButtonView: NSView {

    private weak var target: AnyObject?
    private let action: Selector
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    init(target: AnyObject, action: Selector) {
        self.target = target
        self.action = action
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateBackground()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateBackground()
    }

    override func mouseDown(with event: NSEvent) {
        _ = target?.perform(action, with: nil)
    }

    private func updateBackground() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isHovering {
            layer?.backgroundColor = isDark
                ? NSColor.white.withAlphaComponent(0.10).cgColor
                : NSColor.black.withAlphaComponent(0.08).cgColor
        } else {
            layer?.backgroundColor = isDark
                ? NSColor.white.withAlphaComponent(0.04).cgColor
                : NSColor.black.withAlphaComponent(0.04).cgColor
        }
    }
}

// MARK: - Publish Confirmation Popover

private final class PublishConfirmationController: NSViewController, NSPopoverDelegate {

    private let onConfirm: () -> Void
    weak var popover: NSPopover?

    init(onConfirm: @escaping () -> Void) {
        self.onConfirm = onConfirm
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Publish Dashboard")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .labelColor
        title.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(title)

        let desc = NSTextField(wrappingLabelWithString: "Lock the dashboard into a read-only view. You can edit again anytime.")
        desc.font = .systemFont(ofSize: 12)
        desc.textColor = .secondaryLabelColor
        desc.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(desc)

        // Share link row (coming soon — disabled)
        let linkRow = NSView()
        linkRow.wantsLayer = true
        linkRow.layer?.cornerRadius = 8
        linkRow.layer?.borderWidth = 1
        linkRow.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        linkRow.translatesAutoresizingMaskIntoConstraints = false
        linkRow.alphaValue = 0.5
        container.addSubview(linkRow)

        let linkIcon = NSImageView()
        linkIcon.image = NSImage(systemSymbolName: "link", accessibilityDescription: "Share link")
        linkIcon.symbolConfiguration = .init(pointSize: 11, weight: .medium)
        linkIcon.contentTintColor = .secondaryLabelColor
        linkIcon.translatesAutoresizingMaskIntoConstraints = false
        linkRow.addSubview(linkIcon)

        let linkLabel = NSTextField(labelWithString: "Share with public link")
        linkLabel.font = .systemFont(ofSize: 12)
        linkLabel.textColor = .secondaryLabelColor
        linkLabel.translatesAutoresizingMaskIntoConstraints = false
        linkRow.addSubview(linkLabel)

        let comingSoonTag = NSTextField(labelWithString: "Soon")
        comingSoonTag.font = .systemFont(ofSize: 10, weight: .medium)
        comingSoonTag.textColor = .tertiaryLabelColor
        comingSoonTag.alignment = .center
        comingSoonTag.wantsLayer = true
        comingSoonTag.layer?.cornerRadius = 4
        comingSoonTag.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        comingSoonTag.translatesAutoresizingMaskIntoConstraints = false
        linkRow.addSubview(comingSoonTag)

        // Publish button — full-width primary style
        let publishButton = PrimaryActionButton(title: "Publish Dashboard", target: self, action: #selector(confirmTapped))
        publishButton.keyEquivalent = "\r"
        publishButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(publishButton)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            title.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            desc.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            desc.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            desc.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            linkRow.topAnchor.constraint(equalTo: desc.bottomAnchor, constant: 16),
            linkRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            linkRow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            linkRow.heightAnchor.constraint(equalToConstant: 36),

            linkIcon.leadingAnchor.constraint(equalTo: linkRow.leadingAnchor, constant: 10),
            linkIcon.centerYAnchor.constraint(equalTo: linkRow.centerYAnchor),

            linkLabel.leadingAnchor.constraint(equalTo: linkIcon.trailingAnchor, constant: 6),
            linkLabel.centerYAnchor.constraint(equalTo: linkRow.centerYAnchor),

            comingSoonTag.trailingAnchor.constraint(equalTo: linkRow.trailingAnchor, constant: -10),
            comingSoonTag.centerYAnchor.constraint(equalTo: linkRow.centerYAnchor),
            comingSoonTag.widthAnchor.constraint(equalToConstant: 40),
            comingSoonTag.heightAnchor.constraint(equalToConstant: 18),

            publishButton.topAnchor.constraint(equalTo: linkRow.bottomAnchor, constant: 16),
            publishButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            publishButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            publishButton.heightAnchor.constraint(equalToConstant: 36),
            publishButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),

            container.widthAnchor.constraint(equalToConstant: 280),
        ])

        self.view = container
    }

    @objc private func confirmTapped() {
        onConfirm()
        popover?.performClose(nil)
    }
}

// MARK: - Primary Action Button

private final class PrimaryActionButton: NSButton {

    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    convenience init(title: String, target: AnyObject?, action: Selector) {
        self.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        self.isBordered = false
        self.font = .systemFont(ofSize: 13, weight: .medium)
        self.alignment = .center
        self.wantsLayer = true
        self.layer?.cornerRadius = 8
        (self.cell as? NSButtonCell)?.highlightsBy = []
        updateColors()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateColors()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateColors()
    }

    private static let darkColor = NSColor(red: 0xE5 / 255.0, green: 0x7E / 255.0, blue: 0x52 / 255.0, alpha: 1.0)
    private static let lightColor = NSColor(red: 0xB9 / 255.0, green: 0x55 / 255.0, blue: 0x31 / 255.0, alpha: 1.0)

    private func updateColors() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let baseColor = isDark ? Self.darkColor : Self.lightColor
        layer?.backgroundColor = isHovering
            ? baseColor.withAlphaComponent(0.85).cgColor
            : baseColor.cgColor
        contentTintColor = .white
    }
}
