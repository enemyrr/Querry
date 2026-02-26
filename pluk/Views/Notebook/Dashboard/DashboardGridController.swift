import AppKit

private final class DashboardFlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class DashboardGridController: NSViewController {

    private let dataController: NotebookDataController
    private let headerView: NSView?
    private var collectionView: NSCollectionView!
    private var scrollView: NSScrollView!
    private var collectionHeightConstraint: NSLayoutConstraint?
    private var isDragging = false
    private var scrollBoundsObserver: Any?

    // Drag state
    private var dragSourceIndex: Int?
    private var dragSnapshotLayer: CALayer?
    private var dragOffset: NSPoint = .zero
    private var currentDropIntent: DashboardDropIntent?
    private var dropIndicatorLayer: CALayer?
    private var autoScrollTimer: Timer?

    var onScrollOffsetChanged: ((CGFloat) -> Void)?

    init(dataController: NotebookDataController, headerView: NSView? = nil) {
        self.dataController = dataController
        self.headerView = headerView
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
        let layout = DashboardGridLayout()
        layout.dataController = dataController

        collectionView = NSCollectionView()
        collectionView.collectionViewLayout = layout
        collectionView.dataSource = self
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = false
        collectionView.register(DashboardChartItem.self, forItemWithIdentifier: DashboardChartItem.identifier)
        collectionView.register(DashboardTextItem.self, forItemWithIdentifier: DashboardTextItem.identifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        let documentView = DashboardFlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false

        if let headerView {
            headerView.translatesAutoresizingMaskIntoConstraints = false
            documentView.addSubview(headerView)

            NSLayoutConstraint.activate([
                headerView.topAnchor.constraint(equalTo: documentView.topAnchor),
                headerView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
                headerView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            ])
        }

        documentView.addSubview(collectionView)

        let collectionTopAnchor = headerView?.bottomAnchor ?? documentView.topAnchor
        let heightConstraint = collectionView.heightAnchor.constraint(equalToConstant: 0)
        collectionHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: collectionTopAnchor),
            collectionView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            heightConstraint,

            documentView.widthAnchor.constraint(equalTo: collectionView.widthAnchor),
        ])

        scrollView = NSScrollView()
        scrollView.documentView = documentView
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
            documentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
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

    private func updateCollectionHeight() {
        guard let layout = collectionView.collectionViewLayout else { return }
        collectionView.layoutSubtreeIfNeeded()
        let contentHeight = layout.collectionViewContentSize.height
        collectionHeightConstraint?.constant = contentHeight
    }

    // MARK: - Resize

    private var availableContentWidth: CGFloat {
        let insets = (collectionView.collectionViewLayout as? DashboardGridLayout)?.sectionInsets ?? NSEdgeInsets()
        return collectionView.bounds.width - insets.left - insets.right
    }

    private func invalidateLayoutAndHeight() {
        collectionView.collectionViewLayout?.invalidateLayout()
        updateCollectionHeight()
    }

    private func handleBlockResize(block: NotebookBlock, newHeight: CGFloat) {
        block.blockHeight = newHeight
        invalidateLayoutAndHeight()
    }

    private func handleBlockWidthResize(block: NotebookBlock, delta: CGFloat) {
        let availableWidth = availableContentWidth
        guard availableWidth > 0 else { return }

        let dashBlocks = dataController.dashboardBlocks
        guard let blockIndex = dashBlocks.firstIndex(where: { $0.id == block.id }) else { return }

        let rowBlocks = blocksInSameRow(as: blockIndex, in: dashBlocks)
        let others = rowBlocks.filter { $0.id != block.id }
        let fractionDelta = delta / availableWidth
        let minFraction = max(200 / availableWidth, 0.2)

        block.blockWidthFraction = min(max(block.blockWidthFraction + fractionDelta, minFraction), 1.0)

        if !others.isEmpty {
            let total = rowBlocks.reduce(0.0) { $0 + $1.blockWidthFraction }
            if total > 1.0 {
                let excess = total - 1.0
                let otherTotal = others.reduce(0.0) { $0 + $1.blockWidthFraction }
                let shrinkable = otherTotal - Double(others.count) * minFraction

                if shrinkable > 0 {
                    let shrinkAmount = min(excess, shrinkable)
                    for other in others {
                        let proportion = (other.blockWidthFraction - minFraction) / shrinkable
                        other.blockWidthFraction = max(minFraction, other.blockWidthFraction - shrinkAmount * proportion)
                    }
                }

                let remainingOther = others.reduce(0.0) { $0 + $1.blockWidthFraction }
                block.blockWidthFraction = min(block.blockWidthFraction, 1.0 - remainingOther)
            }
        }

        invalidateLayoutAndHeight()
    }

    private func blocksInSameRow(as blockIndex: Int, in dashBlocks: [NotebookBlock]) -> [NotebookBlock] {
        var start = blockIndex
        while start > 0, dashBlocks[start].dashboardInline {
            start -= 1
        }
        var end = blockIndex
        while end + 1 < dashBlocks.count, dashBlocks[end + 1].dashboardInline {
            end += 1
        }
        return Array(dashBlocks[start...end])
    }

    // MARK: - Observation

    override func viewDidLayout() {
        super.viewDidLayout()
        updateCollectionHeight()
    }

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
                self.updateCollectionHeight()
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
                self.updateCollectionHeight()
                self.observePublishedState()
            }
        }
    }

    // MARK: - Custom Drag

    private enum DashboardDropIntent: Equatable {
        case insertRow(beforeIndex: Int)
        case insertInRow(rowIndex: Int, beforeItemIndex: Int)
    }

    private func wireDragCallbacks(on item: DashboardChartItem, at index: Int) {
        item.onDragBegan = { [weak self] event in self?.beginDrag(itemIndex: index, event: event) }
        item.onDragMoved = { [weak self] event in self?.updateDrag(event: event) }
        item.onDragEnded = { [weak self] event in self?.endDrag(event: event) }
    }

    private func wireDragCallbacks(on item: DashboardTextItem, at index: Int) {
        item.onDragBegan = { [weak self] event in self?.beginDrag(itemIndex: index, event: event) }
        item.onDragMoved = { [weak self] event in self?.updateDrag(event: event) }
        item.onDragEnded = { [weak self] event in self?.endDrag(event: event) }
    }

    private func beginDrag(itemIndex: Int, event: NSEvent) {
        guard !dataController.isDashboardPublished else { return }

        isDragging = true
        dragSourceIndex = itemIndex

        guard let item = collectionView.item(at: itemIndex) else { return }
        let itemView = item.view

        let bitmapRep = itemView.bitmapImageRepForCachingDisplay(in: itemView.bounds)
        if let bitmapRep {
            itemView.cacheDisplay(in: itemView.bounds, to: bitmapRep)
        }

        let snapshot = CALayer()
        snapshot.contents = bitmapRep?.cgImage
        snapshot.frame = itemView.convert(itemView.bounds, to: collectionView)
        snapshot.opacity = 0.8
        snapshot.shadowColor = NSColor.black.cgColor
        snapshot.shadowOpacity = 0.3
        snapshot.shadowOffset = CGSize(width: 0, height: -2)
        snapshot.shadowRadius = 8
        snapshot.cornerRadius = 10

        collectionView.layer?.addSublayer(snapshot)
        dragSnapshotLayer = snapshot

        let locationInCollection = collectionView.convert(event.locationInWindow, from: nil)
        dragOffset = NSPoint(
            x: locationInCollection.x - snapshot.frame.origin.x,
            y: locationInCollection.y - snapshot.frame.origin.y
        )

        itemView.alphaValue = 0.15

        let indicator = CALayer()
        indicator.isHidden = true
        collectionView.layer?.addSublayer(indicator)
        dropIndicatorLayer = indicator
    }

    private func updateDrag(event: NSEvent) {
        guard let snapshot = dragSnapshotLayer else { return }

        let locationInCollection = collectionView.convert(event.locationInWindow, from: nil)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        snapshot.frame.origin = NSPoint(
            x: locationInCollection.x - dragOffset.x,
            y: locationInCollection.y - dragOffset.y
        )
        CATransaction.commit()

        autoScrollIfNeeded(event: event)

        guard let sourceIndex = dragSourceIndex else { return }
        let newIntent = computeDropIntent(at: locationInCollection, sourceIndex: sourceIndex)

        if newIntent != currentDropIntent {
            currentDropIntent = newIntent
            updateDropIndicator(for: newIntent)
        }
    }

    private func endDrag(event: NSEvent) {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil

        guard let sourceIndex = dragSourceIndex else {
            cleanupDrag()
            return
        }

        let dashBlocks = dataController.dashboardBlocks
        guard sourceIndex < dashBlocks.count else {
            cleanupDrag()
            return
        }

        let oldIds = dashBlocks.map(\.id)

        let sourceBlock = dashBlocks[sourceIndex]
        guard let realSourceIndex = dataController.blocks.firstIndex(where: { $0.id == sourceBlock.id }) else {
            cleanupDrag()
            return
        }

        // Orphan handling: if source starts a row and next block is inline, promote it
        if !sourceBlock.dashboardInline, sourceIndex + 1 < dashBlocks.count {
            let nextBlock = dashBlocks[sourceIndex + 1]
            if nextBlock.dashboardInline {
                nextBlock.dashboardInline = false
            }
        }

        if let intent = currentDropIntent {
            let layout = collectionView.collectionViewLayout as? DashboardGridLayout
            let rows = layout?.cachedRows ?? []

            switch intent {
            case .insertRow(let beforeIndex):
                sourceBlock.dashboardInline = false

                let realDestIndex: Int
                if beforeIndex < rows.count {
                    let destDashIndex = rows[beforeIndex].startIndex
                    if destDashIndex < dashBlocks.count {
                        let destBlock = dashBlocks[destDashIndex]
                        realDestIndex = dataController.blocks.firstIndex(where: { $0.id == destBlock.id }) ?? dataController.blocks.count
                    } else {
                        realDestIndex = dataController.blocks.count
                    }
                } else {
                    realDestIndex = dataController.blocks.count
                }

                dataController.moveBlock(from: realSourceIndex, to: realDestIndex)

            case .insertInRow(let rowIndex, let beforeItemIndex):
                guard rowIndex < rows.count else { break }
                let row = rows[rowIndex]
                let sourceRowIndex = rows.firstIndex { sourceIndex >= $0.startIndex && sourceIndex <= $0.endIndex }
                let isSameRow = sourceRowIndex == rowIndex

                if !isSameRow {
                    let rowBlockRange = row.startIndex...row.endIndex
                    let usedFraction = rowBlockRange.reduce(0.0) { $0 + dashBlocks[$1].blockWidthFraction }
                    sourceBlock.blockWidthFraction = max(0.2, 1.0 - usedFraction)
                }

                if beforeItemIndex == row.startIndex {
                    sourceBlock.dashboardInline = false
                    dashBlocks[row.startIndex].dashboardInline = true
                } else {
                    sourceBlock.dashboardInline = true
                }

                let realDestIndex: Int
                if beforeItemIndex <= row.endIndex, beforeItemIndex < dashBlocks.count {
                    let destBlock = dashBlocks[beforeItemIndex]
                    realDestIndex = dataController.blocks.firstIndex(where: { $0.id == destBlock.id }) ?? dataController.blocks.count
                } else {
                    let lastBlock = dashBlocks[row.endIndex]
                    let lastRealIndex = dataController.blocks.firstIndex(where: { $0.id == lastBlock.id }) ?? dataController.blocks.count
                    realDestIndex = lastRealIndex + 1
                }

                dataController.moveBlock(from: realSourceIndex, to: realDestIndex)
            }
        }

        let newIds = dataController.dashboardBlocks.map(\.id)

        collectionView.performBatchUpdates {
            for (oldIndex, id) in oldIds.enumerated() {
                guard let newIndex = newIds.firstIndex(of: id), oldIndex != newIndex else { continue }
                self.collectionView.moveItem(
                    at: IndexPath(item: oldIndex, section: 0),
                    to: IndexPath(item: newIndex, section: 0)
                )
            }
        } completionHandler: { [weak self] _ in
            self?.updateCollectionHeight()
        }

        cleanupDrag()
    }

    private func cleanupDrag() {
        dragSnapshotLayer?.removeFromSuperlayer()
        dragSnapshotLayer = nil
        dropIndicatorLayer?.removeFromSuperlayer()
        dropIndicatorLayer = nil
        currentDropIntent = nil

        if let sourceIndex = dragSourceIndex,
           let item = collectionView.item(at: sourceIndex) {
            item.view.alphaValue = 1
        }

        dragSourceIndex = nil
        isDragging = false
    }

    // MARK: - Drop Intent

    private func computeDropIntent(at point: NSPoint, sourceIndex: Int) -> DashboardDropIntent? {
        guard let layout = collectionView.collectionViewLayout as? DashboardGridLayout else { return nil }
        let rows = layout.cachedRows
        guard !rows.isEmpty else { return nil }

        let lineSpacing = layout.lineSpacing

        for (rowIndex, row) in rows.enumerated() {
            let gapTop = row.frame.minY - lineSpacing / 2
            let gapBottom = row.frame.minY + lineSpacing / 2

            // Check if in the gap above this row
            if point.y >= gapTop, point.y < row.frame.minY {
                let intent = DashboardDropIntent.insertRow(beforeIndex: rowIndex)
                if isNoOp(intent, sourceIndex: sourceIndex, rows: rows) { return nil }
                return intent
            }

            // Check if within the row
            if point.y >= row.frame.minY, point.y <= row.frame.maxY {
                let beforeItem = findInsertionIndex(in: row, at: point.x, layout: layout)
                let intent = DashboardDropIntent.insertInRow(rowIndex: rowIndex, beforeItemIndex: beforeItem)
                if isNoOp(intent, sourceIndex: sourceIndex, rows: rows) { return nil }
                return intent
            }

            // Check gap between this row and next
            if rowIndex + 1 < rows.count {
                let nextRow = rows[rowIndex + 1]
                if point.y > row.frame.maxY, point.y < nextRow.frame.minY {
                    let intent = DashboardDropIntent.insertRow(beforeIndex: rowIndex + 1)
                    if isNoOp(intent, sourceIndex: sourceIndex, rows: rows) { return nil }
                    return intent
                }
            }
        }

        // Below all rows
        if point.y > rows.last!.frame.maxY {
            let intent = DashboardDropIntent.insertRow(beforeIndex: rows.count)
            if isNoOp(intent, sourceIndex: sourceIndex, rows: rows) { return nil }
            return intent
        }

        // Above all rows
        if point.y < rows.first!.frame.minY {
            let intent = DashboardDropIntent.insertRow(beforeIndex: 0)
            if isNoOp(intent, sourceIndex: sourceIndex, rows: rows) { return nil }
            return intent
        }

        return nil
    }

    private func findInsertionIndex(in row: DashboardRowInfo, at x: CGFloat, layout: DashboardGridLayout) -> Int {
        for i in row.startIndex...row.endIndex {
            guard let attrs = layout.layoutAttributesForItem(at: IndexPath(item: i, section: 0)) else { continue }
            if x < attrs.frame.midX {
                return i
            }
        }
        return row.endIndex + 1
    }

    private func isNoOp(_ intent: DashboardDropIntent, sourceIndex: Int, rows: [DashboardRowInfo]) -> Bool {
        let sourceRow = rows.firstIndex { sourceIndex >= $0.startIndex && sourceIndex <= $0.endIndex }

        switch intent {
        case .insertRow(let beforeIndex):
            guard let srcRow = sourceRow else { return false }
            let isAlone = rows[srcRow].startIndex == rows[srcRow].endIndex
            if isAlone {
                // Dragging alone-item to adjacent insert position = no-op
                if beforeIndex == srcRow || beforeIndex == srcRow + 1 { return true }
            }
            return false

        case .insertInRow(_, let beforeItemIndex):
            if beforeItemIndex == sourceIndex || beforeItemIndex == sourceIndex + 1 { return true }
            return false
        }
    }

    // MARK: - Drop Indicator

    private func updateDropIndicator(for intent: DashboardDropIntent?) {
        guard let indicator = dropIndicatorLayer else { return }
        guard let layout = collectionView.collectionViewLayout as? DashboardGridLayout else { return }
        let rows = layout.cachedRows
        let insets = layout.sectionInsets

        guard let intent else {
            indicator.isHidden = true
            return
        }

        let lineColor = NSColor.separatorColor

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)

        switch intent {
        case .insertRow(let beforeIndex):
            let y: CGFloat
            if beforeIndex < rows.count {
                y = rows[beforeIndex].frame.minY - layout.lineSpacing / 2
            } else if let lastRow = rows.last {
                y = lastRow.frame.maxY + layout.lineSpacing / 2
            } else {
                y = insets.top
            }

            indicator.frame = NSRect(
                x: insets.left,
                y: y,
                width: collectionView.bounds.width - insets.left - insets.right,
                height: 1
            )
            indicator.cornerRadius = 0.5
            indicator.backgroundColor = lineColor.cgColor
            indicator.borderWidth = 0
            indicator.mask = nil
            indicator.isHidden = false

        case .insertInRow(let rowIndex, let beforeItemIndex):
            guard rowIndex < rows.count else {
                indicator.isHidden = true
                break
            }
            let row = rows[rowIndex]

            let x: CGFloat
            if beforeItemIndex <= row.endIndex,
               let attrs = layout.layoutAttributesForItem(at: IndexPath(item: beforeItemIndex, section: 0)) {
                x = attrs.frame.minX
            } else if let attrs = layout.layoutAttributesForItem(at: IndexPath(item: row.endIndex, section: 0)) {
                x = attrs.frame.maxX
            } else {
                x = insets.left
            }

            indicator.frame = NSRect(x: x - 6, y: row.frame.minY + 20, width: 2, height: row.frame.height - 34)
            indicator.cornerRadius = 1
            indicator.backgroundColor = lineColor.cgColor
            indicator.borderWidth = 0
            indicator.mask = nil
            indicator.isHidden = false
        }

        CATransaction.commit()
    }

    // MARK: - Auto-scroll

    private func autoScrollIfNeeded(event: NSEvent) {
        let locationInScroll = scrollView.convert(event.locationInWindow, from: nil)
        let visibleHeight = scrollView.bounds.height
        let edgeZone: CGFloat = 40
        var scrollDelta: CGFloat = 0

        if locationInScroll.y < edgeZone {
            scrollDelta = -((edgeZone - locationInScroll.y) / edgeZone) * 10
        } else if locationInScroll.y > visibleHeight - edgeZone {
            scrollDelta = ((locationInScroll.y - (visibleHeight - edgeZone)) / edgeZone) * 10
        }

        if abs(scrollDelta) > 0.5 {
            if autoScrollTimer == nil {
                autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                    guard let self else { return }
                    let clipView = self.scrollView.contentView
                    var origin = clipView.bounds.origin
                    let maxY = max(0, (self.scrollView.documentView?.frame.height ?? 0) - clipView.bounds.height)
                    origin.y = min(max(origin.y + scrollDelta, 0), maxY)
                    clipView.scroll(to: origin)
                    self.scrollView.reflectScrolledClipView(clipView)
                }
            }
        } else {
            autoScrollTimer?.invalidate()
            autoScrollTimer = nil
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
            item.onWidthResize = { [weak self] block, delta in
                self?.handleBlockWidthResize(block: block, delta: delta)
            }
            wireDragCallbacks(on: item, at: indexPath.item)
            return item
        case .text:
            let item = collectionView.makeItem(withIdentifier: DashboardTextItem.identifier, for: indexPath) as! DashboardTextItem
            item.configure(block: block, isPublished: published)
            item.onResize = { [weak self] block, newHeight in
                self?.handleBlockResize(block: block, newHeight: newHeight)
            }
            item.onWidthResize = { [weak self] block, delta in
                self?.handleBlockWidthResize(block: block, delta: delta)
            }
            wireDragCallbacks(on: item, at: indexPath.item)
            return item
        }
    }
}
