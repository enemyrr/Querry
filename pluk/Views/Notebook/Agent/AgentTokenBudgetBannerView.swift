import AppKit

final class AgentTokenBudgetBannerView: NSView {
    static let preferredHeight: CGFloat = 62

    private let messageLabel: NSTextField

    override init(frame: NSRect) {
        messageLabel = NSTextField(wrappingLabelWithString: "")

        super.init(frame: frame)

        setupView()
        setupLabel()
        setupConstraints()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceChange),
            name: .appAppearanceDidChange,
            object: nil
        )
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.cornerCurve = .continuous
        toolTip = "Open Account settings"
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private func setupLabel() {
        messageLabel.backgroundColor = .clear
        messageLabel.isBordered = false
        messageLabel.isBezeled = false
        messageLabel.isEditable = false
        messageLabel.isSelectable = false
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 2
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(messageLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: topAnchor, constant: 15),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -15),

            heightAnchor.constraint(greaterThanOrEqualToConstant: Self.preferredHeight),
        ])
    }

    private func updateAppearance() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = Self.backgroundColor.cgColor
            messageLabel.attributedStringValue = Self.messageText
        }
    }

    @objc private func handleAppearanceChange() {
        updateAppearance()
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return }
        SettingsWindowController.shared.show(pane: .account, source: "notebook_agent_credit_limit")
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    private static var backgroundColor: NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.23, green: 0.13, blue: 0.14, alpha: 1.0)
                : NSColor(red: 0.98, green: 0.88, blue: 0.86, alpha: 1.0)
        }
    }

    private static var foregroundColor: NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.96, green: 0.80, blue: 0.84, alpha: 1.0)
                : NSColor(red: 0.42, green: 0.12, blue: 0.15, alpha: 1.0)
        }
    }

    private static var messageText: NSAttributedString {
        let text = "You've used all your available credits for this month. You can review your balance anytime."
        let baseFont = NSFont.preferredFont(forTextStyle: .callout)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: baseFont,
                .foregroundColor: foregroundColor,
                .paragraphStyle: paragraphStyle,
            ]
        )

        let balanceRange = (text as NSString).range(of: "balance")
        if balanceRange.location != NSNotFound {
            attributed.addAttributes([
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: foregroundColor,
            ], range: balanceRange)
        }
        return attributed
    }
}
