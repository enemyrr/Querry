import AppKit

final class ThinkingBlockView: NSView {

    private let statusIcon: NSImageView
    private let titleLabel: NSTextField
    private let chevronIcon: NSImageView
    private let headerArea: NSView
    private let contentField: NSTextField
    private let contentContainer: NSView
    private var containerHeightConstraint: NSLayoutConstraint!
    private var contentTopConstraint: NSLayoutConstraint!
    private var isExpanded = false
    private var autoExpanded = false
    private var streamingStartTime: Date?
    private var isFinished = false
    private var shimmerMaskLayer: CAGradientLayer?

    init(text: String, finishedDuration: Int? = nil) {
        statusIcon = NSImageView()
        titleLabel = NSTextField(labelWithString: "Thinking")
        chevronIcon = NSImageView()
        headerArea = NSView()
        contentField = NSTextField(wrappingLabelWithString: Self.stripTitle(text))
        contentContainer = NSView()
        super.init(frame: .zero)
        setupViews()

        chevronIcon.isHidden = true

        if let duration = finishedDuration {
            isFinished = true
            chevronIcon.isHidden = false
            showFinishedHeader(duration: duration)
        } else {
            startHeaderAnimations()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(text: String) {
        contentField.stringValue = Self.stripTitle(text)
        if isExpanded {
            updateExpandedHeight(animated: false)
        }
        invalidateIntrinsicContentSize()
    }

    func setActivelyStreaming(_ streaming: Bool) {
        if streaming && !isFinished {
            stopHeaderAnimations()
            chevronIcon.isHidden = false
            if streamingStartTime == nil {
                streamingStartTime = Date()
            }
            if !isExpanded {
                autoExpanded = true
                setExpanded(true, animated: false)
            }
        } else if !streaming && !isFinished {
            isFinished = true
            autoExpanded = false
            updateHeaderToFinished()
            collapseQuietly()
        }
    }

    private func updateHeaderToFinished() {
        let durationSeconds: Int
        if let start = streamingStartTime {
            durationSeconds = max(1, Int(Date().timeIntervalSince(start)))
        } else {
            durationSeconds = 0
        }
        showFinishedHeader(duration: durationSeconds)
    }

    private func showFinishedHeader(duration: Int) {
        stopHeaderAnimations()

        statusIcon.contentTintColor = .secondaryLabelColor

        if duration > 0 {
            titleLabel.stringValue = "Thought for \(duration) second\(duration == 1 ? "" : "s")"
        } else {
            titleLabel.stringValue = "Thought"
        }
    }

    // MARK: - Expand / Collapse

    private func collapseQuietly() {
        guard isExpanded else { return }
        isExpanded = false

        let chevronConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        chevronIcon.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)?
            .withSymbolConfiguration(chevronConfig)

        containerHeightConstraint.constant = 0
        contentTopConstraint.constant = 0
    }

    private func setExpanded(_ expanded: Bool, animated: Bool) {
        guard expanded != isExpanded else { return }
        isExpanded = expanded

        let chevronName = isExpanded ? "chevron.down" : "chevron.right"
        let chevronConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)

        chevronIcon.image = NSImage(systemSymbolName: chevronName, accessibilityDescription: nil)?
            .withSymbolConfiguration(chevronConfig)

        let targetHeight: CGFloat = isExpanded ? targetContentHeight() : 0
        let targetGap: CGFloat = isExpanded ? 4 : 0

        if !animated {
            containerHeightConstraint.constant = targetHeight
            contentTopConstraint.constant = targetGap
            layoutAncestorTree()
            return
        }

        let timingName: CAMediaTimingFunctionName = isExpanded ? .easeOut : .easeIn
        let duration: CGFloat = isExpanded ? 0.25 : 0.2

        NSAnimationContext.runAnimationGroup { [self] ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: timingName)
            ctx.allowsImplicitAnimation = true
            containerHeightConstraint.constant = targetHeight
            contentTopConstraint.constant = targetGap
            layoutAncestorTree()
        }
    }

    private func updateExpandedHeight(animated: Bool) {
        guard isExpanded else { return }
        let target = targetContentHeight()
        guard abs(containerHeightConstraint.constant - target) > 1 else { return }

        if animated {
            NSAnimationContext.runAnimationGroup { [self] ctx in
                ctx.duration = 0.15
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                ctx.allowsImplicitAnimation = true
                containerHeightConstraint.constant = target
                layoutAncestorTree()
            }
        } else {
            containerHeightConstraint.constant = target
        }
    }

    private func layoutAncestorTree() {
        if let contentView = window?.contentView {
            contentView.layoutSubtreeIfNeeded()
        } else {
            superview?.layoutSubtreeIfNeeded()
        }
    }

    private func targetContentHeight() -> CGFloat {
        let width = contentContainer.bounds.width > 0 ? contentContainer.bounds.width : (superview?.bounds.width ?? 300)
        let size = contentField.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude)) ?? .zero
        return ceil(size.height)
    }

    override func layout() {
        super.layout()
        if isExpanded {
            let target = targetContentHeight()
            if abs(containerHeightConstraint.constant - target) > 1 {
                containerHeightConstraint.constant = target
            }
        }
        shimmerMaskLayer?.frame = titleLabel.bounds.insetBy(dx: -24, dy: 0)
    }

    // MARK: - Setup

    private func setupViews() {
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        statusIcon.image = NSImage(systemSymbolName: "lightbulb.max", accessibilityDescription: nil)?
            .withSymbolConfiguration(iconConfig)
        statusIcon.contentTintColor = .secondaryLabelColor
        statusIcon.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let chevronConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        chevronIcon.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)?
            .withSymbolConfiguration(chevronConfig)
        chevronIcon.contentTintColor = .tertiaryLabelColor
        chevronIcon.translatesAutoresizingMaskIntoConstraints = false

        headerArea.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerArea)
        headerArea.addSubview(statusIcon)
        headerArea.addSubview(titleLabel)
        headerArea.addSubview(chevronIcon)

        let click = NSClickGestureRecognizer(target: self, action: #selector(toggleExpanded))
        headerArea.addGestureRecognizer(click)

        contentContainer.wantsLayer = true
        contentContainer.layer?.masksToBounds = true
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentContainer)

        contentField.font = .systemFont(ofSize: 12)
        contentField.textColor = .secondaryLabelColor
        contentField.isEditable = false
        contentField.isSelectable = true
        contentField.isBordered = false
        contentField.isBezeled = false
        contentField.drawsBackground = false
        contentField.lineBreakMode = .byCharWrapping
        contentField.maximumNumberOfLines = 0
        contentField.cell?.wraps = true
        contentField.cell?.isScrollable = false
        contentField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        contentField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentField.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(contentField)

        let heightC = contentContainer.heightAnchor.constraint(equalToConstant: 0)
        containerHeightConstraint = heightC

        let topC = contentContainer.topAnchor.constraint(equalTo: headerArea.bottomAnchor, constant: 0)
        contentTopConstraint = topC

        NSLayoutConstraint.activate([
            headerArea.topAnchor.constraint(equalTo: topAnchor),
            headerArea.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerArea.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            headerArea.heightAnchor.constraint(equalToConstant: 18),

            statusIcon.leadingAnchor.constraint(equalTo: headerArea.leadingAnchor),
            statusIcon.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor, constant: 1),
            statusIcon.widthAnchor.constraint(equalToConstant: 16),
            statusIcon.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: statusIcon.trailingAnchor, constant: 4),
            titleLabel.centerYAnchor.constraint(equalTo: headerArea.centerYAnchor),

            chevronIcon.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 4),
            chevronIcon.centerYAnchor.constraint(equalTo: headerArea.centerYAnchor),
            chevronIcon.trailingAnchor.constraint(equalTo: headerArea.trailingAnchor),
            chevronIcon.widthAnchor.constraint(equalToConstant: 12),

            topC,
            contentContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightC,

            contentField.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            contentField.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            contentField.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
        ])
    }

    @objc private func toggleExpanded() {
        autoExpanded = false
        setExpanded(!isExpanded, animated: true)
    }

    // MARK: - Header Animations

    private func startHeaderAnimations() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        guard shimmerMaskLayer == nil else { return }

        titleLabel.wantsLayer = true
        let mask = CAGradientLayer()
        mask.startPoint = CGPoint(x: 0, y: 0.5)
        mask.endPoint = CGPoint(x: 1, y: 0.5)
        mask.colors = [
            NSColor.white.withAlphaComponent(0.55).cgColor,
            NSColor.white.cgColor,
            NSColor.white.withAlphaComponent(0.55).cgColor,
        ]
        mask.locations = [0.0, 0.18, 0.36]
        mask.frame = titleLabel.bounds.insetBy(dx: -24, dy: 0)

        let shimmer = CABasicAnimation(keyPath: "locations")
        shimmer.fromValue = [-0.25, -0.1, 0.05]
        shimmer.toValue = [0.95, 1.1, 1.25]
        shimmer.duration = 1.4
        shimmer.repeatCount = .infinity
        shimmer.timingFunction = CAMediaTimingFunction(name: .easeOut)

        mask.add(shimmer, forKey: "shimmer")
        titleLabel.layer?.mask = mask
        shimmerMaskLayer = mask
    }

    private func stopHeaderAnimations() {
        if let mask = shimmerMaskLayer {
            mask.removeAllAnimations()
            titleLabel.layer?.mask = nil
            shimmerMaskLayer = nil
        }
    }

    private static func stripTitle(_ text: String) -> String {
        guard text.hasPrefix("**") else { return text }
        guard text.count > 4 else { return "" }
        guard let closeRange = text.range(of: "**", range: text.index(text.startIndex, offsetBy: 2)..<text.endIndex) else {
            return ""
        }
        let afterTitle = text[closeRange.upperBound...]
        let trimmed = afterTitle.drop(while: { $0 == "\n" || $0 == "\r" })
        return String(trimmed)
    }
}
