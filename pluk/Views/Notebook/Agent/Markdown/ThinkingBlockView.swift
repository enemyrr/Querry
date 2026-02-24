import AppKit

final class ThinkingBlockView: NSView {

    private let statusIcon: NSImageView
    private let titleLabel: NSTextField
    private let chevronIcon: NSImageView
    private let headerArea: NSView
    private let bulletDot: NSView
    private let markdownView: MarkdownContentView
    private let contentContainer: NSView
    private var containerHeightConstraint: NSLayoutConstraint!
    private var contentTopConstraint: NSLayoutConstraint!
    private var isExpanded = false
    private var autoExpanded = false
    private var streamingStartTime: Date?
    private var isFinished = false
    private var shimmerMaskLayer: CAGradientLayer?

    // Tool calls
    private var toolCallContainer: NSView?
    private var toolCallHeaderIcon: NSImageView?
    private var toolCallHeaderLabel: NSTextField?
    private var timelineLine: NSView?
    private var toolCallPillStack: NSStackView?
    private var toolCallScrollView: NSScrollView?
    private var toolCallRows: [ToolCallRow] = []
    private var headerConfigured = false
    private static let maxVisiblePills = 6
    private static let pillHeight: CGFloat = 24
    private static let pillSpacing: CGFloat = 5

    private struct ToolCallRow {
        let id: String
        let pill: NSView
        let spinner: NSProgressIndicator
        let checkmark: NSImageView
        let label: NSTextField
    }

    init(text: String, finishedDuration: Int? = nil) {
        statusIcon = NSImageView()
        titleLabel = NSTextField(labelWithString: "Thinking")
        chevronIcon = NSImageView()
        headerArea = NSView()
        bulletDot = NSView()
        markdownView = MarkdownContentView()
        contentContainer = NSView()
        super.init(frame: .zero)
        setupViews()
        markdownView.update(content: Self.stripTitle(text))

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
        markdownView.update(content: Self.stripTitle(text))
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
            if toolCallContainer == nil {
                finishAll()
            }
        }
    }

    func finishAll() {
        guard !isFinished else { return }
        isFinished = true
        autoExpanded = false
        updateHeaderToFinished()
        collapseQuietly()
    }

    // MARK: - Tool Calls

    func addToolCall(id: String, name: String, displayText: String, isComplete: Bool) {
        if toolCallContainer == nil {
            setupToolCallSection(firstToolName: name)
        }

        if !headerConfigured {
            toolCallHeaderLabel?.stringValue = Self.toolGroupHeader(for: name)
            toolCallHeaderIcon?.image = NSImage(systemSymbolName: Self.toolGroupIcon(for: name), accessibilityDescription: nil)
            headerConfigured = true
        }

        guard let pillStack = toolCallPillStack else { return }

        let pill = NSView()
        pill.wantsLayer = true
        pill.layer?.cornerRadius = 14
        pill.layer?.backgroundColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.06)
                : NSColor.black.withAlphaComponent(0.05)
        }.cgColor
        pill.translatesAutoresizingMaskIntoConstraints = false

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let checkmark = NSImageView()
        checkmark.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        checkmark.contentTintColor = .tertiaryLabelColor
        checkmark.symbolConfiguration = .init(pointSize: 10, weight: .medium)
        checkmark.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: displayText)
        label.font = .systemFont(ofSize: 11.5)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false

        pill.addSubview(spinner)
        pill.addSubview(checkmark)
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            spinner.widthAnchor.constraint(equalToConstant: 13),
            spinner.heightAnchor.constraint(equalToConstant: 13),
            spinner.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 6),
            spinner.centerYAnchor.constraint(equalTo: pill.centerYAnchor),

            checkmark.widthAnchor.constraint(equalToConstant: 13),
            checkmark.heightAnchor.constraint(equalToConstant: 13),
            checkmark.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 6),
            checkmark.centerYAnchor.constraint(equalTo: pill.centerYAnchor),

            label.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 3),
            label.trailingAnchor.constraint(lessThanOrEqualTo: pill.trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: pill.centerYAnchor),

            pill.heightAnchor.constraint(equalToConstant: 24),
        ])

        if isComplete {
            spinner.isHidden = true
            checkmark.isHidden = false
        } else {
            spinner.startAnimation(nil)
            spinner.isHidden = false
            checkmark.isHidden = true
        }

        pillStack.addArrangedSubview(pill)
        pill.leadingAnchor.constraint(equalTo: pillStack.leadingAnchor).isActive = true
        pill.widthAnchor.constraint(lessThanOrEqualTo: pillStack.widthAnchor, multiplier: 0.85).isActive = true
        toolCallRows.append(ToolCallRow(id: id, pill: pill, spinner: spinner, checkmark: checkmark, label: label))

        if isExpanded {
            updateExpandedHeight(animated: true)
        }

        // Auto-scroll to show the latest pill
        if let scrollView = toolCallScrollView {
            pillStack.layoutSubtreeIfNeeded()
            let bottomPoint = NSPoint(x: 0, y: max(0, pillStack.frame.height - scrollView.contentView.bounds.height))
            scrollView.contentView.scroll(to: bottomPoint)
        }
    }

    func containsToolCall(id: String) -> Bool {
        toolCallRows.contains { $0.id == id }
    }

    func markToolCallComplete(id: String, displayText: String) {
        guard let entry = toolCallRows.first(where: { $0.id == id }) else { return }
        entry.spinner.stopAnimation(nil)
        entry.spinner.isHidden = true
        entry.checkmark.isHidden = false
        entry.label.stringValue = displayText
    }

    private func setupToolCallSection(firstToolName: String) {
        // Timeline line in contentContainer: from bullet dot all the way down
        let line = NSView()
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor.separatorColor.cgColor
        line.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(line)
        timelineLine = line

        // Tool call container (header + pills) to the right of the bullet/line
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(container)

        let hIcon = NSImageView()
        hIcon.image = NSImage(systemSymbolName: Self.toolGroupIcon(for: firstToolName), accessibilityDescription: nil)
        hIcon.contentTintColor = .secondaryLabelColor
        hIcon.symbolConfiguration = .init(pointSize: 10, weight: .medium)
        hIcon.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hIcon)
        toolCallHeaderIcon = hIcon

        let hLabel = NSTextField(labelWithString: Self.toolGroupHeader(for: firstToolName))
        hLabel.font = .systemFont(ofSize: 11.5, weight: .medium)
        hLabel.textColor = .secondaryLabelColor
        hLabel.lineBreakMode = .byTruncatingTail
        hLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hLabel)
        toolCallHeaderLabel = hLabel

        let pillStack = NSStackView()
        pillStack.orientation = .vertical
        pillStack.alignment = .leading
        pillStack.spacing = Self.pillSpacing
        pillStack.translatesAutoresizingMaskIntoConstraints = false
        toolCallPillStack = pillStack

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = .init(top: 0, left: 0, bottom: 0, right: 0)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let clipView = NSClipView()
        clipView.drawsBackground = false
        clipView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentView = clipView
        scrollView.documentView = pillStack

        container.addSubview(scrollView)
        toolCallScrollView = scrollView

        let maxHeight = Self.pillHeight * CGFloat(Self.maxVisiblePills) + Self.pillSpacing * CGFloat(Self.maxVisiblePills - 1)

        NSLayoutConstraint.activate([
            pillStack.topAnchor.constraint(equalTo: clipView.topAnchor),
            pillStack.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            pillStack.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),

            // Line: centered on bullet dot, from below dot to bottom of scroll view
            line.widthAnchor.constraint(equalToConstant: 1.5),
            line.centerXAnchor.constraint(equalTo: bulletDot.centerXAnchor),
            line.topAnchor.constraint(equalTo: bulletDot.bottomAnchor, constant: 4),
            line.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            // Container: aligned with markdown text
            container.topAnchor.constraint(equalTo: markdownView.bottomAnchor, constant: 8),
            container.leadingAnchor.constraint(equalTo: markdownView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),

            hIcon.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hIcon.topAnchor.constraint(equalTo: container.topAnchor),
            hIcon.widthAnchor.constraint(equalToConstant: 13),
            hIcon.heightAnchor.constraint(equalToConstant: 13),

            hLabel.leadingAnchor.constraint(equalTo: hIcon.trailingAnchor, constant: 3),
            hLabel.centerYAnchor.constraint(equalTo: hIcon.centerYAnchor),
            hLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            scrollView.topAnchor.constraint(equalTo: hIcon.bottomAnchor, constant: 6),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scrollView.heightAnchor.constraint(lessThanOrEqualToConstant: maxHeight),
        ])

        toolCallContainer = container
    }

    private static func toolGroupHeader(for toolName: String) -> String {
        switch toolName {
        case "list_tables": return "Exploring database"
        case "get_table_schema": return "Reading schema"
        case "run_query": return "Fetching data"
        case "create_chart_block": return "Building visualizations"
        case "create_text_block": return "Writing content"
        default: return "Processing"
        }
    }

    private static func toolGroupIcon(for toolName: String) -> String {
        switch toolName {
        case "list_tables": return "tablecells"
        case "get_table_schema": return "square.stack.3d.up"
        case "run_query": return "text.page.badge.magnifyingglass"
        case "create_chart_block": return "chart.bar"
        case "create_text_block": return "text.alignleft"
        default: return "gearshape"
        }
    }

    // MARK: - Header

    private func updateHeaderToFinished() {
        let duration = streamingStartTime.map { max(1, Int(Date().timeIntervalSince($0))) } ?? 0
        showFinishedHeader(duration: duration)
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

    private static let chevronConfig = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)

    private func updateChevronImage() {
        let name = isExpanded ? "chevron.down" : "chevron.right"
        chevronIcon.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(Self.chevronConfig)
    }

    private func collapseQuietly() {
        guard isExpanded else { return }
        isExpanded = false
        updateChevronImage()
        containerHeightConstraint.constant = 0
        contentTopConstraint.constant = 0
    }

    private func setExpanded(_ expanded: Bool, animated: Bool) {
        guard expanded != isExpanded else { return }
        isExpanded = expanded
        updateChevronImage()

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
        var height: CGFloat
        let fitting = markdownView.fittingSize
        if fitting.height > 0 {
            height = ceil(fitting.height)
        } else {
            let size = markdownView.intrinsicContentSize
            height = size.height > 0 ? ceil(size.height) : 20
        }

        if let tcContainer = toolCallContainer {
            let tcFitting = tcContainer.fittingSize
            let tcHeight = tcFitting.height > 0 ? ceil(tcFitting.height) : ceil(tcContainer.intrinsicContentSize.height)
            if tcHeight > 0 {
                height += 12 + tcHeight
            }
        }

        return height
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
        updateBulletDotAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBulletDotAppearance()
    }

    private func updateBulletDotAppearance() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        bulletDot.layer?.borderColor = (isDark
            ? NSColor.white.withAlphaComponent(0.35)
            : NSColor.black.withAlphaComponent(0.25)
        ).cgColor
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

        // Bullet dot: hollow outlined circle
        bulletDot.wantsLayer = true
        bulletDot.layer?.cornerRadius = 3.5
        bulletDot.layer?.backgroundColor = .clear
        bulletDot.layer?.borderWidth = 1.5
        bulletDot.layer?.borderColor = NSColor.tertiaryLabelColor.cgColor
        bulletDot.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(bulletDot)

        markdownView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        markdownView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        markdownView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(markdownView)

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

            bulletDot.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            bulletDot.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 5),
            bulletDot.widthAnchor.constraint(equalToConstant: 7),
            bulletDot.heightAnchor.constraint(equalToConstant: 7),

            markdownView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            markdownView.leadingAnchor.constraint(equalTo: bulletDot.trailingAnchor, constant: 6),
            markdownView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
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
        guard let mask = shimmerMaskLayer else { return }
        mask.removeAllAnimations()
        titleLabel.layer?.mask = nil
        shimmerMaskLayer = nil
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
