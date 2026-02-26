import AppKit

private let dashboardDragType = NSPasteboard.PasteboardType("com.pluk.dashboard.block")

final class DashboardGridController: NSViewController {

    private let dataController: NotebookDataController
    private var collectionView: NSCollectionView!
    private var scrollView: NSScrollView!
    private var isDragging = false
    private var scrollBoundsObserver: Any?

    var onScrollOffsetChanged: ((CGFloat) -> Void)?

    init(dataController: NotebookDataController) {
        self.dataController = dataController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        self.view = root

        setupCollectionView()
        observeBlocks()
        observePublishedState()
    }

    // MARK: - Setup

    private func setupCollectionView() {
        let layout = NSCollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 16
        layout.sectionInset = NSEdgeInsets(top: 16, left: 20, bottom: 32, right: 20)

        collectionView = NSCollectionView()
        collectionView.collectionViewLayout = layout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.register(DashboardChartItem.self, forItemWithIdentifier: DashboardChartItem.identifier)
        collectionView.register(DashboardTextItem.self, forItemWithIdentifier: DashboardTextItem.identifier)
        collectionView.registerForDraggedTypes([dashboardDragType])
        collectionView.setDraggingSourceOperationMask(.move, forLocal: true)

        scrollView = NSScrollView()
        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true
        scrollBoundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let offset = max(0, self.scrollView.contentView.bounds.origin.y)
            self.onScrollOffsetChanged?(offset)
        }
    }

    // MARK: - Resize

    private func handleBlockResize(block: NotebookBlock, newHeight: CGFloat) {
        block.blockHeight = newHeight
        dataController.updateBlock(block)
        collectionView.collectionViewLayout?.invalidateLayout()
    }

    // MARK: - Observation

    private func observeBlocks() {
        withObservationTracking {
            _ = self.dataController.dashboardBlocks.map(\.id)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, !self.isDragging else {
                    self?.observeBlocks()
                    return
                }
                self.collectionView.reloadData()
                self.observeBlocks()
            }
        }
    }

    private func observePublishedState() {
        withObservationTracking {
            _ = self.dataController.isDashboardPublished
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.collectionView.reloadData()
                self.observePublishedState()
            }
        }
    }
}

// MARK: - NSCollectionViewDataSource

extension DashboardGridController: NSCollectionViewDataSource {

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        dataController.dashboardBlocks.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let block = dataController.dashboardBlocks[indexPath.item]
        let published = dataController.isPublished

        switch block.blockType {
        case .chart:
            let item = collectionView.makeItem(withIdentifier: DashboardChartItem.identifier, for: indexPath) as! DashboardChartItem
            let vm = dataController.chartViewModel(for: block)
            item.configure(block: block, viewModel: vm, isPublished: published)
            item.onResize = { [weak self] block, newHeight in
                self?.handleBlockResize(block: block, newHeight: newHeight)
            }
            return item
        case .text:
            let item = collectionView.makeItem(withIdentifier: DashboardTextItem.identifier, for: indexPath) as! DashboardTextItem
            item.configure(block: block, isPublished: published)
            item.onResize = { [weak self] block, newHeight in
                self?.handleBlockResize(block: block, newHeight: newHeight)
            }
            return item
        }
    }
}

// MARK: - NSCollectionViewDelegateFlowLayout

extension DashboardGridController: NSCollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: NSCollectionView,
        layout collectionViewLayout: NSCollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> NSSize {
        let block = dataController.dashboardBlocks[indexPath.item]
        let insets = (collectionViewLayout as? NSCollectionViewFlowLayout)?.sectionInset ?? NSEdgeInsets()
        let itemWidth = collectionView.bounds.width - insets.left - insets.right
        let published = dataController.isPublished
        let titleHeight: CGFloat = published ? 0 : 18
        let resizeHandleHeight: CGFloat = published ? 0 : 12
        let itemHeight: CGFloat

        switch block.blockType {
        case .chart:
            itemHeight = titleHeight + max(280, block.blockHeight) + resizeHandleHeight
        case .text:
            itemHeight = titleHeight + max(80, block.blockHeight) + resizeHandleHeight
        }

        return NSSize(width: max(200, itemWidth), height: itemHeight)
    }

    // MARK: - Drag Source

    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> (any NSPasteboardWriting)? {
        guard !dataController.isDashboardPublished else { return nil }
        let item = NSPasteboardItem()
        item.setString(String(indexPath.item), forType: dashboardDragType)
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItemsAt indexPaths: Set<IndexPath>) {
        isDragging = true
    }

    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, dragOperation operation: NSDragOperation) {
        isDragging = false
    }

    // MARK: - Drop Target

    func collectionView(_ collectionView: NSCollectionView, validateDrop draggingInfo: any NSDraggingInfo, proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>, dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        proposedDropOperation.pointee = .before
        return .move
    }

    func collectionView(_ collectionView: NSCollectionView, acceptDrop draggingInfo: any NSDraggingInfo, indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation) -> Bool {
        guard let item = draggingInfo.draggingPasteboard.pasteboardItems?.first,
              let indexStr = item.string(forType: dashboardDragType),
              let dashSourceIndex = Int(indexStr) else { return false }

        let dashDestIndex = indexPath.item
        guard dashSourceIndex != dashDestIndex else { return false }

        let dashBlocks = dataController.dashboardBlocks
        let sourceBlock = dashBlocks[dashSourceIndex]
        guard let realSourceIndex = dataController.blocks.firstIndex(where: { $0.id == sourceBlock.id }) else { return false }

        let realDestIndex: Int
        if dashDestIndex < dashBlocks.count {
            let destBlock = dashBlocks[dashDestIndex]
            realDestIndex = dataController.blocks.firstIndex(where: { $0.id == destBlock.id }) ?? dataController.blocks.count
        } else {
            realDestIndex = dataController.blocks.count
        }

        collectionView.animator().performBatchUpdates {
            dataController.moveBlock(from: realSourceIndex, to: realDestIndex)
            let adjustedDash = dashDestIndex > dashSourceIndex ? dashDestIndex - 1 : dashDestIndex
            collectionView.moveItem(at: IndexPath(item: dashSourceIndex, section: 0), to: IndexPath(item: adjustedDash, section: 0))
        }

        return true
    }
}
