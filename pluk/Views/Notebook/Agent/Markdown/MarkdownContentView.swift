import AppKit

final class MarkdownContentView: NSView {

    private let stackView: NSStackView
    private var currentBlocks: [MarkdownBlock] = []
    private var blockViews: [NSView] = []

    override init(frame: NSRect) {
        stackView = NSStackView()
        super.init(frame: frame)
        setupStack()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(content: String) {
        let newBlocks = MarkdownBlockParser.parse(content)

        guard !newBlocks.isEmpty else {
            removeAllBlockViews()
            currentBlocks = []
            return
        }

        // Find first divergent block
        var divergenceIndex = 0
        let minCount = min(currentBlocks.count, newBlocks.count)
        while divergenceIndex < minCount {
            if currentBlocks[divergenceIndex] == newBlocks[divergenceIndex] {
                divergenceIndex += 1
            } else {
                break
            }
        }

        // If only the last block's text changed and block count is the same, update in-place
        if divergenceIndex == newBlocks.count - 1
            && newBlocks.count == currentBlocks.count
            && divergenceIndex < blockViews.count
        {
            updateBlockView(blockViews[divergenceIndex], with: newBlocks[divergenceIndex])
            currentBlocks = newBlocks
            invalidateIntrinsicContentSize()
            return
        }

        // If new blocks were just appended
        if divergenceIndex == currentBlocks.count && newBlocks.count > currentBlocks.count {
            for i in divergenceIndex..<newBlocks.count {
                let view = makeBlockView(for: newBlocks[i])
                addBlockView(view)
            }
            currentBlocks = newBlocks
            invalidateIntrinsicContentSize()
            return
        }

        // Structure changed — rebuild from divergence point
        // Remove views from divergence point onward
        while blockViews.count > divergenceIndex {
            let view = blockViews.removeLast()
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        // Add new views
        for i in divergenceIndex..<newBlocks.count {
            let view = makeBlockView(for: newBlocks[i])
            addBlockView(view)
        }

        currentBlocks = newBlocks
        invalidateIntrinsicContentSize()
    }

    // MARK: - Setup

    private func setupStack() {
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    // MARK: - Block View Factory

    private func makeBlockView(for block: MarkdownBlock) -> NSView {
        switch block {
        case .paragraph(let text):
            return MarkdownTextBlockView(text: text, style: .paragraph)

        case .heading(let level, let text):
            return MarkdownTextBlockView(text: text, style: .heading(level: level))

        case .codeBlock(let code, let language):
            return CodeBlockView(code: code, language: language)

        case .unorderedList(let items):
            return MarkdownListView(items: items, ordered: false)

        case .orderedList(let items):
            return MarkdownListView(items: items, ordered: true)

        case .blockquote(let text):
            return BlockquoteView(text: text)

        case .table(let headers, let rows):
            return MarkdownTableView(headers: headers, rows: rows)

        case .horizontalRule:
            return HorizontalRuleView()

        case .thinkingBlock(let text):
            return ThinkingBlockView(text: text)
        }
    }

    private func updateBlockView(_ view: NSView, with block: MarkdownBlock) {
        switch block {
        case .paragraph(let text):
            (view as? MarkdownTextBlockView)?.update(text: text, style: .paragraph)

        case .heading(let level, let text):
            (view as? MarkdownTextBlockView)?.update(text: text, style: .heading(level: level))

        case .codeBlock(let code, let language):
            (view as? CodeBlockView)?.update(code: code, language: language)

        case .unorderedList(let items):
            (view as? MarkdownListView)?.update(items: items, ordered: false)

        case .orderedList(let items):
            (view as? MarkdownListView)?.update(items: items, ordered: true)

        case .blockquote(let text):
            (view as? BlockquoteView)?.update(text: text)

        case .table(let headers, let rows):
            (view as? MarkdownTableView)?.update(headers: headers, rows: rows)

        case .thinkingBlock(let text):
            (view as? ThinkingBlockView)?.update(text: text)

        case .horizontalRule:
            break
        }
    }

    // MARK: - Helpers

    private func addBlockView(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(view)
        view.leadingAnchor.constraint(equalTo: stackView.leadingAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: stackView.trailingAnchor).isActive = true
        blockViews.append(view)
    }

    private func removeAllBlockViews() {
        for view in blockViews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        blockViews.removeAll()
    }
}
