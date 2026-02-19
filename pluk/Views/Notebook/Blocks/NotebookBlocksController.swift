import AppKit

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class NotebookBlocksController: NSViewController {

    private let dataController: NotebookDataController

    var onScrollOffsetChanged: ((CGFloat) -> Void)?

    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var blockControllers: [UUID: ChartBlockController] = [:]
    private var actionBarView: NotebookActionBarView?
    private var scrollBoundsObserver: NSObjectProtocol?

    init(dataController: NotebookDataController) {
        self.dataController = dataController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        if let scrollBoundsObserver {
            NotificationCenter.default.removeObserver(scrollBoundsObserver)
        }
    }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        self.view = root

        setupScrollView()
        rebuildBlocks()
        observeBlocks()
    }

    // MARK: - Setup

    private func setupScrollView() {
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 32, right: 0)

        let documentView = FlippedView()
        documentView.wantsLayer = true
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stackView)

        scrollView = NSScrollView()
        scrollView.documentView = documentView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true
        scrollBoundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            self?.notifyScrollOffsetChanged()
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: documentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),

            documentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        notifyScrollOffsetChanged()
    }

    // MARK: - Block Management

    private func rebuildBlocks() {
        let currentIds = Set(dataController.blocks.map(\.id))

        // Clean up stale controllers
        for (id, controller) in blockControllers where !currentIds.contains(id) {
            controller.cleanupSession()
            controller.view.removeFromSuperview()
            controller.removeFromParent()
            blockControllers.removeValue(forKey: id)
        }

        // Remove all from stack and re-add in order
        for arrangedView in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(arrangedView)
            arrangedView.removeFromSuperview()
        }

        let blocks = dataController.blocks

        for (index, block) in blocks.enumerated() {
            let controller: ChartBlockController
            if let existing = blockControllers[block.id] {
                controller = existing
            } else {
                controller = ChartBlockController(block: block, dataController: dataController)
                addChild(controller)
                blockControllers[block.id] = controller
            }

            controller.view.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(controller.view)

            NSLayoutConstraint.activate([
                controller.view.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
                controller.view.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            ])

            // Add insertion view between blocks (not after the last one)
            if index < blocks.count - 1 {
                let insertionView = BlockInsertionView(
                    insertionIndex: index + 1,
                    dataController: dataController
                )
                insertionView.translatesAutoresizingMaskIntoConstraints = false
                stackView.addArrangedSubview(insertionView)

                NSLayoutConstraint.activate([
                    insertionView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
                    insertionView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
                ])
            }
        }

        // Append action bar at the bottom
        if actionBarView == nil {
            actionBarView = NotebookActionBarView(dataController: dataController)
        }
        if let bar = actionBarView {
            bar.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(bar)

            NSLayoutConstraint.activate([
                bar.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
                bar.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            ])
        }

        notifyScrollOffsetChanged()
    }

    // MARK: - Observation

    private func observeBlocks() {
        withObservationTracking {
            _ = self.dataController.blocks.map(\.id)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.rebuildBlocks()
                self.observeBlocks()
            }
        }
    }

    private func notifyScrollOffsetChanged() {
        let offset = max(0, scrollView?.contentView.bounds.origin.y ?? 0)
        onScrollOffsetChanged?(offset)
    }

}
