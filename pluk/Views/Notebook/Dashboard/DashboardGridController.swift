import AppKit

private extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            switch element(at: i, associatedPoints: &points) {
            case .moveTo: path.move(to: points[0])
            case .lineTo: path.addLine(to: points[0])
            case .curveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath: path.closeSubpath()
            case .cubicCurveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo: path.addQuadCurve(to: points[1], control: points[0])
            @unknown default: break
            }
        }
        return path
    }
}

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
    private var dropIndicatorLayer: CAShapeLayer?
    private var itemHighlightLayers: [CAShapeLayer] = []
    private var lastDragPoint: NSPoint = .zero
    private var dimOverlayLayer: CALayer?
    private var divisionPreviewLayers: [CAShapeLayer] = []
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
        scrollView.contentView.drawsBackground = false
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
        case insertInRow(rowIndex: Int, hoveredItemIndex: Int)
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

        let dashBlocks = dataController.dashboardBlocks
        let block = dashBlocks[itemIndex]

        // Compact drag card
        let title = block.title.isEmpty
            ? (block.blockType == .chart ? "Untitled Chart" : "Untitled Text")
            : block.title
        let iconName = block.blockType == .chart ? "chart.bar.fill" : "doc.text.fill"
        let card = createDragCard(title: title, iconName: iconName)

        let locationInCollection = collectionView.convert(event.locationInWindow, from: nil)
        card.frame.origin = NSPoint(
            x: locationInCollection.x - card.frame.width / 2,
            y: locationInCollection.y - card.frame.height / 2
        )

        collectionView.layer?.addSublayer(card)
        dragSnapshotLayer = card
        dragOffset = NSPoint(x: card.frame.width / 2, y: card.frame.height / 2)

        // Dim source
        if let item = collectionView.item(at: itemIndex) {
            item.view.alphaValue = 0.15
        }

        // Row overlay (shown per-row when intent is set)
        let overlay = CALayer()
        overlay.isHidden = true
        overlay.cornerRadius = 10
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            overlay.backgroundColor = isDark
                ? NSColor.black.withAlphaComponent(0.3).cgColor
                : NSColor.white.withAlphaComponent(0.4).cgColor
        }
        collectionView.layer?.addSublayer(overlay)
        dimOverlayLayer = overlay

        // Drop indicator
        let indicator = CAShapeLayer()
        indicator.isHidden = true
        collectionView.layer?.addSublayer(indicator)
        dropIndicatorLayer = indicator
    }

    private func createDragCard(title: String, iconName: String) -> CALayer {
        let card = CALayer()
        let cardWidth: CGFloat = 180
        let cardHeight: CGFloat = 36
        card.frame = NSRect(x: 0, y: 0, width: cardWidth, height: cardHeight)
        card.cornerRadius = 8
        card.masksToBounds = false

        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            card.backgroundColor = isDark
                ? NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
                : NSColor.white.withAlphaComponent(0.95).cgColor
        }

        card.shadowColor = NSColor.black.cgColor
        card.shadowOpacity = 0.2
        card.shadowOffset = CGSize(width: 0, height: -1)
        card.shadowRadius = 6

        // Icon
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            let configured = image.withSymbolConfiguration(config) ?? image
            let iconLayer = CALayer()
            iconLayer.frame = NSRect(x: 10, y: (cardHeight - 16) / 2, width: 16, height: 16)
            iconLayer.contents = configured.cgImage(forProposedRect: nil, context: nil, hints: nil)
            iconLayer.contentsGravity = .resizeAspect
            card.addSublayer(iconLayer)
        }

        // Title
        let textLayer = CATextLayer()
        textLayer.string = title
        textLayer.fontSize = 12
        textLayer.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        textLayer.truncationMode = .end
        textLayer.frame = NSRect(x: 32, y: (cardHeight - 16) / 2, width: cardWidth - 44, height: 16)

        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            textLayer.foregroundColor = NSColor.labelColor.cgColor
        }

        card.addSublayer(textLayer)
        return card
    }

    private func addItemHighlights(onlyRange: ClosedRange<Int>? = nil) {
        guard let layout = collectionView.collectionViewLayout as? DashboardGridLayout else { return }
        let accentColor = NSColor.controlAccentColor

        for i in 0..<dataController.dashboardBlocks.count {
            guard i != dragSourceIndex else { continue }
            if let only = onlyRange, !only.contains(i) { continue }
            guard let attrs = layout.layoutAttributesForItem(at: IndexPath(item: i, section: 0)) else { continue }

            // Inset to match the block container (skip title area and resize handle)
            let titleOffset: CGFloat = 21
            let resizeOffset: CGFloat = 12
            let rect = NSRect(
                x: attrs.frame.minX,
                y: attrs.frame.minY + titleOffset,
                width: attrs.frame.width,
                height: attrs.frame.height - titleOffset - resizeOffset
            ).insetBy(dx: 4, dy: 0.5)

            let shape = CAShapeLayer()
            let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
            shape.path = path.cgPath
            shape.fillColor = nil
            shape.strokeColor = accentColor.withAlphaComponent(0.25).cgColor
            shape.lineWidth = 1.5
            shape.lineDashPattern = [4, 3]

            collectionView.layer?.addSublayer(shape)
            itemHighlightLayers.append(shape)
        }
    }

    private func removeItemHighlights() {
        for layer in itemHighlightLayers {
            layer.removeFromSuperlayer()
        }
        itemHighlightLayers.removeAll()
    }

    private func removeDivisionPreview() {
        for layer in divisionPreviewLayers {
            layer.removeFromSuperlayer()
        }
        divisionPreviewLayers.removeAll()
    }

    private func updateDrag(event: NSEvent) {
        guard let snapshot = dragSnapshotLayer else { return }

        let locationInCollection = collectionView.convert(event.locationInWindow, from: nil)
        lastDragPoint = locationInCollection

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

            case .insertInRow(let rowIndex, let hoveredItemIndex):
                guard rowIndex < rows.count else { break }
                let row = rows[rowIndex]
                let sourceRowIndex = rows.firstIndex { sourceIndex >= $0.startIndex && sourceIndex <= $0.endIndex }
                let isSameRow = sourceRowIndex == rowIndex

                if !isSameRow {
                    let rowBlockRange = row.startIndex...row.endIndex
                    let usedFraction = rowBlockRange.reduce(0.0) { $0 + dashBlocks[$1].blockWidthFraction }
                    sourceBlock.blockWidthFraction = max(0.2, 1.0 - usedFraction)
                }

                // Same-row: move to hovered item's position
                // Cross-row: insert at cursor position within row
                let targetDashIndex: Int
                if isSameRow {
                    targetDashIndex = hoveredItemIndex
                } else {
                    let locationInCollection = collectionView.convert(event.locationInWindow, from: nil)
                    let hoveredAttrs = (collectionView.collectionViewLayout as? DashboardGridLayout)?
                        .layoutAttributesForItem(at: IndexPath(item: hoveredItemIndex, section: 0))
                    let insertBefore = locationInCollection.x < (hoveredAttrs?.frame.midX ?? 0)
                    targetDashIndex = insertBefore ? hoveredItemIndex : min(hoveredItemIndex + 1, row.endIndex + 1)
                }

                if targetDashIndex == row.startIndex {
                    sourceBlock.dashboardInline = false
                    dashBlocks[row.startIndex].dashboardInline = true
                } else {
                    sourceBlock.dashboardInline = true
                }

                let realDestIndex: Int
                if targetDashIndex <= row.endIndex, targetDashIndex < dashBlocks.count {
                    let destBlock = dashBlocks[targetDashIndex]
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
        // Close the row gap
        if let gridLayout = collectionView.collectionViewLayout as? DashboardGridLayout,
           gridLayout.insertRowGapBeforeIndex != nil {
            gridLayout.insertRowGapBeforeIndex = nil
            collectionView.collectionViewLayout?.invalidateLayout()
            collectionView.layoutSubtreeIfNeeded()
            updateCollectionHeight()
        }

        dimOverlayLayer?.removeFromSuperlayer()
        dimOverlayLayer = nil
        dragSnapshotLayer?.removeFromSuperlayer()
        dragSnapshotLayer = nil
        dropIndicatorLayer?.removeFromSuperlayer()
        dropIndicatorLayer = nil
        removeItemHighlights()
        removeDivisionPreview()
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

        // If cursor is within the active gap, keep the current insertRow intent
        if let gapFrame = layout.insertGapFrame, let gapIndex = layout.insertRowGapBeforeIndex {
            let expandedGap = gapFrame.insetBy(dx: 0, dy: -layout.lineSpacing / 2)
            if expandedGap.contains(point) {
                let intent = DashboardDropIntent.insertRow(beforeIndex: gapIndex)
                if isNoOp(intent, sourceIndex: sourceIndex, rows: rows) { return nil }
                return intent
            }
        }

        let lineSpacing = layout.lineSpacing

        for (rowIndex, row) in rows.enumerated() {
            // Check if in the gap above this row
            if point.y < row.frame.minY, point.y >= row.frame.minY - lineSpacing / 2 {
                let intent = DashboardDropIntent.insertRow(beforeIndex: rowIndex)
                if isNoOp(intent, sourceIndex: sourceIndex, rows: rows) { return nil }
                return intent
            }

            // Check if within the row
            if point.y >= row.frame.minY, point.y <= row.frame.maxY {
                let hoveredItem = findHoveredItemIndex(in: row, at: point.x, layout: layout)
                let intent = DashboardDropIntent.insertInRow(rowIndex: rowIndex, hoveredItemIndex: hoveredItem)
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

    private func findHoveredItemIndex(in row: DashboardRowInfo, at x: CGFloat, layout: DashboardGridLayout) -> Int {
        for i in row.startIndex...row.endIndex {
            guard let attrs = layout.layoutAttributesForItem(at: IndexPath(item: i, section: 0)) else { continue }
            if x >= attrs.frame.minX, x <= attrs.frame.maxX {
                return i
            }
        }
        return row.endIndex
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

        case .insertInRow(_, let hoveredItemIndex):
            if hoveredItemIndex == sourceIndex { return true }
            return false
        }
    }

    // MARK: - Drop Indicator

    private func updateDropIndicator(for intent: DashboardDropIntent?) {
        removeDivisionPreview()
        removeItemHighlights()
        guard let indicator = dropIndicatorLayer else { return }
        guard let layout = collectionView.collectionViewLayout as? DashboardGridLayout else { return }

        // Manage row gap — animate content apart for insertRow
        let newGapIndex: Int?
        if case .insertRow(let beforeIndex) = intent {
            newGapIndex = beforeIndex
        } else {
            newGapIndex = nil
        }

        if layout.insertRowGapBeforeIndex != newGapIndex {
            layout.insertRowGapBeforeIndex = newGapIndex
            collectionView.collectionViewLayout?.invalidateLayout()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.allowsImplicitAnimation = true
                self.collectionView.layoutSubtreeIfNeeded()
                self.updateCollectionHeight()
            }
        }

        let rows = layout.cachedRows
        let insets = layout.sectionInsets

        guard let intent else {
            indicator.isHidden = true
            dimOverlayLayer?.isHidden = true
            return
        }

        let accentColor = NSColor.controlAccentColor

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        switch intent {
        case .insertRow:
            if let gapFrame = layout.insertGapFrame {
                let rect = gapFrame.insetBy(dx: 0.75, dy: 0.75)
                let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
                indicator.path = path.cgPath
                indicator.fillColor = accentColor.withAlphaComponent(0.04).cgColor
                indicator.strokeColor = accentColor.withAlphaComponent(0.3).cgColor
                indicator.lineWidth = 1.5
                indicator.lineDashPattern = [4, 3]
                indicator.isHidden = false
            }
            dimOverlayLayer?.isHidden = true

        case .insertInRow(let rowIndex, let hoveredItemIndex):
            guard rowIndex < rows.count else {
                indicator.isHidden = true
                dimOverlayLayer?.isHidden = true
                break
            }
            let row = rows[rowIndex]
            guard let sourceIndex = dragSourceIndex else {
                indicator.isHidden = true
                dimOverlayLayer?.isHidden = true
                break
            }

            let sourceRowIndex = rows.firstIndex { sourceIndex >= $0.startIndex && sourceIndex <= $0.endIndex }
            let isSameRow = sourceRowIndex == rowIndex

            let titleOffset: CGFloat = 21
            let resizeOffset: CGFloat = 12

            // Position overlay on the target row
            let overlayRect = NSRect(
                x: row.frame.minX,
                y: row.frame.minY + titleOffset,
                width: row.frame.width,
                height: row.frame.height - titleOffset - resizeOffset
            )
            dimOverlayLayer?.frame = overlayRect
            dimOverlayLayer?.isHidden = false

            if isSameRow {
                // Highlight the hovered item's box + borders on row items
                addItemHighlights(onlyRange: row.startIndex...row.endIndex)

                guard let attrs = layout.layoutAttributesForItem(at: IndexPath(item: hoveredItemIndex, section: 0)) else {
                    indicator.isHidden = true; break
                }

                let rect = NSRect(
                    x: attrs.frame.minX,
                    y: attrs.frame.minY + titleOffset,
                    width: attrs.frame.width,
                    height: attrs.frame.height - titleOffset - resizeOffset
                ).insetBy(dx: 4, dy: 0.75)

                let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
                indicator.path = path.cgPath
                indicator.fillColor = accentColor.withAlphaComponent(0.06).cgColor
                indicator.strokeColor = accentColor.withAlphaComponent(0.35).cgColor
                indicator.lineWidth = 1.5
                indicator.lineDashPattern = [4, 3]
                indicator.isHidden = false
            } else {
                // Cross-row: show full division preview of the row
                indicator.isHidden = true

                guard let hoveredAttrs = layout.layoutAttributesForItem(at: IndexPath(item: hoveredItemIndex, section: 0)) else { break }

                let insertBefore = lastDragPoint.x < hoveredAttrs.frame.midX
                let insertionCol = insertBefore
                    ? hoveredItemIndex - row.startIndex
                    : hoveredItemIndex - row.startIndex + 1

                // Build predicted fractions
                let dashBlocks = dataController.dashboardBlocks
                var existingFractions: [Double] = []
                for i in row.startIndex...row.endIndex {
                    existingFractions.append(dashBlocks[i].blockWidthFraction)
                }
                let usedFraction = existingFractions.reduce(0, +)
                let newFraction = max(0.2, 1.0 - usedFraction)

                var predictedFractions = existingFractions
                predictedFractions.insert(newFraction, at: insertionCol)

                let totalFraction = predictedFractions.reduce(0, +)
                let normalized: [Double] = totalFraction > 1.0
                    ? predictedFractions.map { $0 / totalFraction }
                    : predictedFractions

                // Calculate column widths
                let handleWidth: CGFloat = 12
                let totalHandleWidth = handleWidth * CGFloat(normalized.count)
                let distributableWidth = (collectionView.bounds.width - insets.left - insets.right) - totalHandleWidth

                var xOffset = insets.left
                for (col, fraction) in normalized.enumerated() {
                    let colWidth = distributableWidth * fraction + handleWidth

                    let rect = NSRect(
                        x: xOffset,
                        y: row.frame.minY + titleOffset,
                        width: colWidth,
                        height: row.frame.height - titleOffset - resizeOffset
                    ).insetBy(dx: 4, dy: 0.75)

                    let shape = CAShapeLayer()
                    let colPath = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
                    shape.path = colPath.cgPath
                    shape.lineWidth = 1.5
                    shape.lineDashPattern = [4, 3]

                    if col == insertionCol {
                        shape.fillColor = accentColor.withAlphaComponent(0.04).cgColor
                        shape.strokeColor = accentColor.withAlphaComponent(0.3).cgColor
                    } else {
                        shape.fillColor = nil
                        shape.strokeColor = accentColor.withAlphaComponent(0.15).cgColor
                    }

                    collectionView.layer?.addSublayer(shape)
                    divisionPreviewLayers.append(shape)

                    xOffset += colWidth
                }
            }
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
