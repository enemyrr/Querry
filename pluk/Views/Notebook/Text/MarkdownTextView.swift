import AppKit

@MainActor
protocol MarkdownTextViewDelegate: AnyObject {
    func markdownTextViewDidChange(_ textView: MarkdownTextView)
    func markdownTextViewDidChangeHeight(_ textView: MarkdownTextView)
}

@MainActor
final class MarkdownTextView: NSView, NSTextViewDelegate {

    weak var delegate: MarkdownTextViewDelegate?

    private let textView: NSTextView
    private let codeBlockTracker = MarkdownCodeBlockTracker()
    private var heightConstraint: NSLayoutConstraint!
    private var lastKnownHeight: CGFloat = 0
    private var isUpdatingText = false
    private var activeLine: Int = -1

    private let defaultFont = NSFont.systemFont(ofSize: 14)
    private let defaultTextColor = NSColor.labelColor
    private let defaultParagraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 6
        return style
    }()

    var string: String {
        get { textView.string }
        set {
            guard newValue != textView.string else { return }
            isUpdatingText = true
            textView.string = newValue
            applyMarkdownStyling()
            isUpdatingText = false
            updatePlaceholder()
            recalculateHeight()
        }
    }

    override init(frame: NSRect) {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)

        textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 16, height: 12)
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false

        super.init(frame: frame)

        textView.delegate = self
        wantsLayer = true

        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)

        heightConstraint = heightAnchor.constraint(equalToConstant: 44)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightConstraint,
        ])

        setupPlaceholder()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Scroll Override

    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }

    // MARK: - Focus

    func focus() {
        window?.makeFirstResponder(textView)
    }

    // MARK: - Height

    override func layout() {
        super.layout()

        if let textContainer = textView.textContainer {
            let insets = textView.textContainerInset
            let containerWidth = max(0, bounds.width - insets.width * 2)
            if abs(textContainer.containerSize.width - containerWidth) > 1 {
                textContainer.containerSize = NSSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude)
            }
        }

        recalculateHeight()
    }

    private func recalculateHeight() {
        guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let insets = textView.textContainerInset
        let newHeight = max(44, ceil(usedRect.height + insets.height * 2))

        guard abs(newHeight - lastKnownHeight) > 0.5 else { return }
        lastKnownHeight = newHeight
        heightConstraint.constant = newHeight
        textView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: newHeight)
        delegate?.markdownTextViewDidChangeHeight(self)
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard !isUpdatingText else { return }
        applyMarkdownStyling()
        updatePlaceholder()
        recalculateHeight()
        delegate?.markdownTextViewDidChange(self)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard !isUpdatingText else { return }
        let cursorLine = currentCursorLine()
        if cursorLine != activeLine {
            activeLine = cursorLine
            applyMarkdownStyling()
            recalculateHeight()
        }
    }

    // MARK: - Cursor Line Detection

    private func currentCursorLine() -> Int {
        let text = textView.string as NSString
        guard text.length > 0 else { return 0 }

        let cursorLocation = textView.selectedRange().location
        var lineIndex = 0
        var lineStart = 0

        while lineStart < text.length {
            var lineEnd = 0
            var contentsEnd = 0
            text.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: lineStart, length: 0))

            // Cursor is on this line if it's within [lineStart, lineEnd)
            // or at contentsEnd (end of line content)
            if cursorLocation >= lineStart && cursorLocation < lineEnd {
                return lineIndex
            }

            lineIndex += 1
            lineStart = lineEnd
        }

        // Cursor is at the very end
        return max(0, lineIndex - 1)
    }

    // MARK: - Styling

    private func applyMarkdownStyling() {
        guard let textStorage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        guard fullRange.length > 0 else { return }

        let selectedRanges = textView.selectedRanges

        textStorage.beginEditing()

        // Reset to default
        textStorage.setAttributes([
            .font: defaultFont,
            .foregroundColor: defaultTextColor,
            .paragraphStyle: defaultParagraphStyle,
        ], range: fullRange)

        // Track code blocks
        codeBlockTracker.update(text: textStorage.string)

        // Apply code block body styling first
        applyCodeBlockBodyStyling(textStorage)

        // Get styled ranges from parser
        let styledRanges = MarkdownParser.styledRanges(for: textStorage.string, defaultFont: defaultFont)
        let text = textStorage.string as NSString

        for styled in styledRanges {
            guard styled.range.location + styled.range.length <= textStorage.length else { continue }

            let lineIndex = lineIndexForLocation(styled.range.location, in: text)

            // Skip inline styling inside code blocks
            if codeBlockTracker.isInsideCodeBlock(lineIndex: lineIndex) { continue }

            if styled.isMarker && lineIndex != activeLine {
                // Hide markers on non-active lines
                textStorage.addAttributes(MarkdownParser.hiddenMarkerAttributes, range: styled.range)
            } else {
                textStorage.addAttributes(styled.attributes, range: styled.range)
            }
        }

        textStorage.endEditing()
        textView.selectedRanges = selectedRanges
    }

    private func lineIndexForLocation(_ location: Int, in text: NSString) -> Int {
        var lineIndex = 0
        var lineStart = 0
        while lineStart < text.length && lineStart < location {
            var lineEnd = 0
            text.getLineStart(nil, end: &lineEnd, contentsEnd: nil, for: NSRange(location: lineStart, length: 0))
            if lineEnd <= location {
                lineIndex += 1
                lineStart = lineEnd
            } else {
                break
            }
        }
        return lineIndex
    }

    private func applyCodeBlockBodyStyling(_ textStorage: NSTextStorage) {
        let text = textStorage.string as NSString
        var lineIndex = 0
        var lineStart = 0
        let codeFont = NSFont.monospacedSystemFont(ofSize: defaultFont.pointSize - 1, weight: .regular)
        let codeAttrs: [NSAttributedString.Key: Any] = [
            .font: codeFont,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        while lineStart < text.length {
            var lineEnd = 0
            var contentsEnd = 0
            text.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: lineStart, length: 0))

            if codeBlockTracker.isInsideCodeBlock(lineIndex: lineIndex) {
                let lineRange = NSRange(location: lineStart, length: contentsEnd - lineStart)
                if lineRange.length > 0 {
                    textStorage.addAttributes(codeAttrs, range: lineRange)
                }
            }

            lineIndex += 1
            lineStart = lineEnd
        }
    }

    // MARK: - Placeholder

    private var placeholderField: NSTextField?

    private func setupPlaceholder() {
        let field = NSTextField(labelWithString: "Write something...")
        field.font = defaultFont
        field.textColor = .placeholderTextColor
        field.backgroundColor = .clear
        field.isBordered = false
        field.isBezeled = false
        field.isEditable = false
        field.translatesAutoresizingMaskIntoConstraints = false
        addSubview(field)

        let insets = textView.textContainerInset
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: topAnchor, constant: insets.height),
            field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.width),
        ])

        placeholderField = field
    }

    private func updatePlaceholder() {
        placeholderField?.isHidden = !textView.string.isEmpty
    }
}
