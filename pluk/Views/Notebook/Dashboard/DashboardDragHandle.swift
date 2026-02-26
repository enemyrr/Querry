import AppKit

final class DashboardDragHandle: NSView {

    var onDragBegan: ((NSEvent) -> Void)?
    var onDragMoved: ((NSEvent) -> Void)?
    var onDragEnded: ((NSEvent) -> Void)?

    private let imageView: NSImageView
    private var isDragging = false

    override init(frame frameRect: NSRect) {
        let image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "Drag to reorder")
        imageView = NSImageView(image: image ?? NSImage())
        imageView.contentTintColor = .tertiaryLabelColor
        imageView.translatesAutoresizingMaskIntoConstraints = false

        super.init(frame: frameRect)

        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        NSCursor.closedHand.push()
        onDragBegan?(event)
    }

    override func mouseDragged(with event: NSEvent) {
        onDragMoved?(event)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        NSCursor.pop()
        onDragEnded?(event)
    }
}
