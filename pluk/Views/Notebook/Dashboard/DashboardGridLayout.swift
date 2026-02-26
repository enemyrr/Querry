import AppKit

struct DashboardRowInfo {
    let startIndex: Int
    let endIndex: Int
    let frame: NSRect
}

final class DashboardGridLayout: NSCollectionViewLayout {

    weak var dataController: NotebookDataController?

    var sectionInsets = NSEdgeInsets(top: 8, left: 20, bottom: 32, right: 20)
    var lineSpacing: CGFloat = 16
    var handleWidth: CGFloat = 12

    var insertRowGapBeforeIndex: Int?
    var insertRowGapHeight: CGFloat = 60

    private var cachedAttributes: [NSCollectionViewLayoutAttributes] = []
    private var cachedContentSize: NSSize = .zero
    private(set) var cachedRows: [DashboardRowInfo] = []
    private(set) var insertGapFrame: NSRect?

    override func prepare() {
        super.prepare()
        cachedAttributes.removeAll()
        cachedRows.removeAll()
        insertGapFrame = nil

        guard let collectionView, let dataController else {
            cachedContentSize = .zero
            return
        }

        let blocks = dataController.dashboardBlocks
        guard !blocks.isEmpty else {
            cachedContentSize = NSSize(width: collectionView.bounds.width, height: sectionInsets.top + sectionInsets.bottom)
            return
        }

        let isPublished = dataController.isPublished
        let totalWidth = collectionView.bounds.width
        let availableWidth = totalWidth - sectionInsets.left - sectionInsets.right

        let rows = buildRows(from: blocks)

        var yOffset = sectionInsets.top
        var globalIndex = 0

        for (rowIndex, row) in rows.enumerated() {
            if rowIndex == insertRowGapBeforeIndex {
                insertGapFrame = NSRect(x: sectionInsets.left, y: yOffset, width: availableWidth, height: insertRowGapHeight)
                yOffset += insertRowGapHeight + lineSpacing
            }

            let totalFraction = row.reduce(0.0) { $0 + $1.blockWidthFraction }
            let blockCount = row.count
            let isSingleItem = blockCount == 1
            let totalHandleWidth = isPublished ? 0 : handleWidth * CGFloat(blockCount)
            let distributableWidth = availableWidth - totalHandleWidth

            var xOffset = sectionInsets.left
            var maxHeight: CGFloat = 0

            let rowStartIndex = globalIndex

            for block in row {
                let itemHandleWidth: CGFloat = isPublished ? 0 : handleWidth
                let itemWidth: CGFloat
                if isSingleItem || totalFraction <= 1.0 {
                    itemWidth = distributableWidth * block.blockWidthFraction + itemHandleWidth
                } else {
                    let fraction = block.blockWidthFraction / totalFraction
                    itemWidth = distributableWidth * fraction + itemHandleWidth
                }

                let titleHeight: CGFloat = isPublished ? 0 : 18
                let resizeHandleHeight: CGFloat = isPublished ? 0 : 12
                let minContentHeight: CGFloat = block.blockType == .chart ? 280 : 80
                let itemHeight = titleHeight + max(minContentHeight, block.blockHeight) + resizeHandleHeight

                let attrs = NSCollectionViewLayoutAttributes(forItemWith: IndexPath(item: globalIndex, section: 0))
                attrs.frame = NSRect(x: xOffset, y: yOffset, width: itemWidth, height: itemHeight)
                cachedAttributes.append(attrs)

                xOffset += itemWidth
                maxHeight = max(maxHeight, itemHeight)
                globalIndex += 1
            }

            let rowFrame = NSRect(
                x: sectionInsets.left,
                y: yOffset,
                width: availableWidth,
                height: maxHeight
            )
            cachedRows.append(DashboardRowInfo(
                startIndex: rowStartIndex,
                endIndex: globalIndex - 1,
                frame: rowFrame
            ))

            yOffset += maxHeight + lineSpacing
        }

        if insertRowGapBeforeIndex == rows.count {
            insertGapFrame = NSRect(x: sectionInsets.left, y: yOffset, width: availableWidth, height: insertRowGapHeight)
            yOffset += insertRowGapHeight + lineSpacing
        }

        yOffset = yOffset - lineSpacing + sectionInsets.bottom
        cachedContentSize = NSSize(width: totalWidth, height: yOffset)
    }

    override var collectionViewContentSize: NSSize {
        cachedContentSize
    }

    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        cachedAttributes.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        guard indexPath.item < cachedAttributes.count else { return nil }
        return cachedAttributes[indexPath.item]
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool {
        guard let collectionView else { return true }
        return collectionView.bounds.width != newBounds.width
    }

    private func buildRows(from blocks: [NotebookBlock]) -> [[NotebookBlock]] {
        var rows: [[NotebookBlock]] = []
        for block in blocks {
            if block.dashboardInline, !rows.isEmpty {
                rows[rows.count - 1].append(block)
            } else {
                rows.append([block])
            }
        }
        return rows
    }
}
