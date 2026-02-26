import AppKit
import SwiftUI

final class DashboardChartItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("DashboardChartItem")

    var onResize: ((NotebookBlock, CGFloat) -> Void)?

    private var titleLabel: NSTextField!
    private var blockContainer: NSView!
    private var resizeHandle: BlockResizeHandle!
    private var hostingView: NSHostingView<AnyView>?
    private weak var currentBlock: NotebookBlock?
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isPublished = false

    override func loadView() {
        let wrapper = NSView()
        wrapper.wantsLayer = true
        self.view = wrapper

        setupTitleLabel()
        setupBlockContainer()
        setupResizeHandle()
        setupConstraints()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceChange),
            name: .appAppearanceDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func configure(block: NotebookBlock, viewModel: ChartBlockViewModel, isPublished: Bool = false) {
        currentBlock = block
        self.isPublished = isPublished
        titleLabel.stringValue = block.title.isEmpty ? "Untitled Chart" : block.title
        titleLabel.isHidden = isPublished
        resizeHandle.isHidden = isPublished
        hostingView?.removeFromSuperview()

        let chartView = ChartPreviewView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: AnyView(chartView))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        blockContainer.addSubview(hosting)
        hostingView = hosting

        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: blockContainer.topAnchor),
            hosting.leadingAnchor.constraint(equalTo: blockContainer.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: blockContainer.trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: blockContainer.bottomAnchor),
        ])
    }

    // MARK: - Layout

    private func setupTitleLabel() {
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .tertiaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
    }

    private func setupBlockContainer() {
        blockContainer = NSView()
        blockContainer.wantsLayer = true
        blockContainer.layer?.cornerRadius = 10
        blockContainer.layer?.borderWidth = 1
        blockContainer.layer?.borderColor = NSColor.clear.cgColor
        blockContainer.layer?.masksToBounds = true
        blockContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blockContainer)
    }

    private func setupResizeHandle() {
        resizeHandle = BlockResizeHandle(onDrag: { [weak self] delta in
            guard let self, let block = self.currentBlock else { return }
            let newHeight = max(280, block.blockHeight + Double(delta))
            self.onResize?(block, newHeight)
        })
        resizeHandle.translatesAutoresizingMaskIntoConstraints = false
        resizeHandle.alphaValue = 0
        view.addSubview(resizeHandle)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),

            blockContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            blockContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blockContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            resizeHandle.topAnchor.constraint(equalTo: blockContainer.bottomAnchor),
            resizeHandle.leadingAnchor.constraint(equalTo: blockContainer.leadingAnchor),
            resizeHandle.trailingAnchor.constraint(equalTo: blockContainer.trailingAnchor),
            resizeHandle.heightAnchor.constraint(equalToConstant: 12),
            resizeHandle.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Hover Tracking

    override func viewDidLayout() {
        super.viewDidLayout()
        setupTrackingArea()
    }

    private func setupTrackingArea() {
        if let existing = trackingArea { view.removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        )
        view.addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        setHovered(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHovered(false)
    }

    private func setHovered(_ hovered: Bool) {
        guard hovered != isHovered else { return }
        isHovered = hovered
        guard !isPublished else { return }
        updateBorderColor()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            resizeHandle.animator().alphaValue = hovered ? 1 : 0
        }
    }

    // MARK: - Appearance

    private func updateBorderColor() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            if isHovered {
                let isDark = NSAppearance.currentDrawing().isDarkMode
                blockContainer.layer?.borderColor = isDark
                    ? NSColor.white.withAlphaComponent(0.1).cgColor
                    : NSColor.black.withAlphaComponent(0.08).cgColor
            } else {
                blockContainer.layer?.borderColor = NSColor.clear.cgColor
            }
        }
    }

    @objc private func handleAppearanceChange() {
        updateBorderColor()
    }
}
