import AppKit

final class MarkdownTextBlockView: NSView {

    enum Style {
        case paragraph
        case heading(level: Int)
    }

    private let textField: NSTextField

    init(text: String, style: Style) {
        textField = NSTextField(labelWithAttributedString: Self.attributedString(for: text, style: style))
        super.init(frame: .zero)
        setupTextField()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(text: String, style: Style) {
        textField.attributedStringValue = Self.attributedString(for: text, style: style)
        invalidateIntrinsicContentSize()
    }

    private func setupTextField() {
        textField.isEditable = false
        textField.isSelectable = true
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.lineBreakMode = .byWordWrapping
        textField.maximumNumberOfLines = 0
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textField)
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    private static func attributedString(for text: String, style: Style) -> NSAttributedString {
        switch style {
        case .paragraph:
            return MarkdownInlineRenderer.render(text)
        case .heading(let level):
            let (fontSize, weight) = headingStyle(for: level)
            let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
            return MarkdownInlineRenderer.render(text, font: font)
        }
    }

    private static func headingStyle(for level: Int) -> (CGFloat, NSFont.Weight) {
        switch level {
        case 1: return (24, .bold)
        case 2: return (20, .semibold)
        default: return (16, .semibold)
        }
    }
}
