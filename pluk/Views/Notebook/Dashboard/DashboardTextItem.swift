import AppKit

final class DashboardTextItem: DashboardBaseItem {

    static let identifier = NSUserInterfaceItemIdentifier("DashboardTextItem")

    private var textView: NSTextView!

    private let defaultParagraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 6
        return style
    }()

    override func setupContent() {
        textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 16, height: 12)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.translatesAutoresizingMaskIntoConstraints = false
        blockContainer.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: blockContainer.topAnchor),
            textView.leadingAnchor.constraint(equalTo: blockContainer.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: blockContainer.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: blockContainer.bottomAnchor),
        ])
    }

    func configure(block: NotebookBlock, isPublished: Bool = false) {
        configureBase(block: block, isPublished: isPublished)

        let text = block.textContent
        let defaultFont = NSFont.systemFont(ofSize: 14)
        let attrString = NSMutableAttributedString(string: text, attributes: [
            .font: defaultFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: defaultParagraphStyle,
        ])

        let styledRanges = MarkdownParser.styledRanges(for: text, defaultFont: defaultFont)
        for styled in styledRanges {
            if styled.isMarker {
                attrString.addAttributes(MarkdownParser.hiddenMarkerAttributes, range: styled.range)
            } else {
                attrString.addAttributes(styled.attributes, range: styled.range)
            }
        }

        textView.textStorage?.setAttributedString(attrString)
    }
}
