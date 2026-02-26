import AppKit

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class NotebookBlocksController: NSViewController {

    private let dataController: NotebookDataController
    private let headerView: NSView?

    var onScrollOffsetChanged: ((CGFloat) -> Void)?

    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var blockControllers: [UUID: NSViewController] = [:]
    private var actionBarView: NotebookActionBarView?
    private var scrollBoundsObserver: NSObjectProtocol?
    private var pendingFocusBlockId: UUID?
    private var initialLoadComplete = false

    init(dataController: NotebookDataController, headerView: NSView? = nil) {
        self.dataController = dataController
        self.headerView = headerView
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

        if let headerView {
            headerView.translatesAutoresizingMaskIntoConstraints = false
            documentView.addSubview(headerView)

            NSLayoutConstraint.activate([
                headerView.topAnchor.constraint(equalTo: documentView.topAnchor),
                headerView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
                headerView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            ])
        }

        let stackTopAnchor = headerView?.bottomAnchor ?? documentView.topAnchor

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: stackTopAnchor),
            stackView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),

            documentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        notifyScrollOffsetChanged()
    }

    private func rebuildBlocks() {
        let currentIds = Set(dataController.blocks.map(\.id))

        for (id, controller) in blockControllers where !currentIds.contains(id) {
            if let chartController = controller as? ChartBlockController {
                chartController.cleanupSession()
            }
            controller.view.removeFromSuperview()
            controller.removeFromParent()
            blockControllers.removeValue(forKey: id)
        }

        for arrangedView in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(arrangedView)
            arrangedView.removeFromSuperview()
        }

        let blocks = dataController.blocks

        for (index, block) in blocks.enumerated() {
            let controller: NSViewController
            if let existing = blockControllers[block.id] {
                controller = existing
            } else {
                switch block.blockType {
                case .chart:
                    controller = ChartBlockController(block: block, dataController: dataController)
                case .text:
                    controller = TextBlockController(block: block, dataController: dataController)
                    if initialLoadComplete {
                        pendingFocusBlockId = block.id
                    }
                }
                addChild(controller)
                blockControllers[block.id] = controller
            }

            addFullWidthArrangedSubview(controller.view)

            if index < blocks.count - 1 {
                let insertionView = BlockInsertionView(
                    insertionIndex: index + 1,
                    dataController: dataController
                )
                addFullWidthArrangedSubview(insertionView)
            }
        }

        if actionBarView == nil {
            actionBarView = NotebookActionBarView(dataController: dataController)
        }
        if let bar = actionBarView {
            addFullWidthArrangedSubview(bar)
        }

        notifyScrollOffsetChanged()
        initialLoadComplete = true

        if let focusId = pendingFocusBlockId, let textController = blockControllers[focusId] as? TextBlockController {
            pendingFocusBlockId = nil
            Task { @MainActor in
                textController.focusEditor()
            }
        }
    }

    private func addFullWidthArrangedSubview(_ subview: NSView) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(subview)
        NSLayoutConstraint.activate([
            subview.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
        ])
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
