import AppKit

final class ThinkingBlockView: NSView {

    private let headerButton: NSButton
    private let contentField: NSTextField
    private var contentHeightConstraint: NSLayoutConstraint?
    private var isExpanded = false

    init(text: String) {
        headerButton = NSButton(title: "Thinking", target: nil, action: nil)
        contentField = NSTextField(wrappingLabelWithString: text)
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(text: String) {
        contentField.stringValue = text
        invalidateIntrinsicContentSize()
    }

    private func setupViews() {
        headerButton.bezelStyle = .inline
        headerButton.isBordered = false
        headerButton.contentTintColor = .secondaryLabelColor
        headerButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        headerButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        headerButton.imagePosition = .imageLeading
        headerButton.target = self
        headerButton.action = #selector(toggleExpanded)
        headerButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerButton)

        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let italicDescriptor = font.fontDescriptor.withSymbolicTraits(.italic)
        let italicFont = NSFont(descriptor: italicDescriptor, size: font.pointSize) ?? font

        contentField.font = italicFont
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
        contentField.isHidden = true
        addSubview(contentField)

        let heightConstraint = contentField.heightAnchor.constraint(equalToConstant: 0)
        self.contentHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            headerButton.topAnchor.constraint(equalTo: topAnchor),
            headerButton.leadingAnchor.constraint(equalTo: leadingAnchor),

            contentField.topAnchor.constraint(equalTo: headerButton.bottomAnchor, constant: 4),
            contentField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            contentField.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentField.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightConstraint,
        ])
    }

    @objc private func toggleExpanded() {
        isExpanded.toggle()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.allowsImplicitAnimation = true

            if isExpanded {
                contentField.isHidden = false
                contentHeightConstraint?.isActive = false
                headerButton.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)
            } else {
                contentHeightConstraint?.isActive = true
                headerButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
            }

            superview?.layoutSubtreeIfNeeded()
        } completionHandler: { [weak self] in
            guard let self else { return }
            if !self.isExpanded {
                self.contentField.isHidden = true
            }
        }
    }
}
