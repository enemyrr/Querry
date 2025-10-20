//
//  IndexTableView.swift
//  Pluk
//
//  Created by Fauzaan on 10/20/25.
//

import SwiftUI
import Foundation

struct IndexTableView: View {
    let indexes: [DatabaseIndexInfo]?
    let tableName: String
    let searchText: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if let indexes = indexes, !indexes.isEmpty {
            IndexTableContentView(
                indexes: filteredIndexes(indexes),
                colorScheme: colorScheme
            )
        } else {
            VStack(spacing: 12) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.5))

                Text("No indexes")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func filteredIndexes(_ indexes: [DatabaseIndexInfo]) -> [DatabaseIndexInfo] {
        if searchText.isEmpty {
            return indexes
        }
        return indexes.filter { index in
            index.name.localizedCaseInsensitiveContains(searchText) ||
            index.columnsDisplay.localizedCaseInsensitiveContains(searchText) ||
            index.indexType.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Index Table Content View
struct IndexTableContentView: NSViewRepresentable {
    let indexes: [DatabaseIndexInfo]
    let colorScheme: ColorScheme

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        let tableView = NSTableView()
        tableView.style = .fullWidth
        tableView.rowSizeStyle = .default
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.backgroundColor = .clear
        tableView.gridStyleMask = []

        tableView.headerView = NSTableHeaderView()
        tableView.allowsColumnReordering = false
        tableView.allowsColumnResizing = true

        // Number column
        let numberColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("number"))
        numberColumn.title = "#"
        numberColumn.width = 40
        numberColumn.minWidth = 40
        numberColumn.maxWidth = 60
        numberColumn.headerCell = SchemaTableHeaderCellView(textCell: numberColumn.title)
        numberColumn.headerCell.alignment = .center
        tableView.addTableColumn(numberColumn)

        // Name column
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 150
        nameColumn.headerCell = SchemaTableHeaderCellView(textCell: nameColumn.title)
        tableView.addTableColumn(nameColumn)

        // Type column
        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "Type"
        typeColumn.headerCell = SchemaTableHeaderCellView(textCell: typeColumn.title)
        tableView.addTableColumn(typeColumn)

        // Columns column
        let columnsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("columns"))
        columnsColumn.title = "Columns"
        columnsColumn.width = 150
        columnsColumn.headerCell = SchemaTableHeaderCellView(textCell: columnsColumn.title)
        tableView.addTableColumn(columnsColumn)

        // Unique column
        let uniqueColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("unique"))
        uniqueColumn.title = "Unique"
        uniqueColumn.width = 60
        uniqueColumn.minWidth = 60
        uniqueColumn.headerCell = SchemaTableHeaderCellView(textCell: uniqueColumn.title)
        uniqueColumn.headerCell.alignment = .center
        tableView.addTableColumn(uniqueColumn)

        // Condition column
        let conditionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("condition"))
        conditionColumn.title = "Condition"
        conditionColumn.width = 150
        conditionColumn.headerCell = SchemaTableHeaderCellView(textCell: conditionColumn.title)
        tableView.addTableColumn(conditionColumn)

        // Include column
        let includeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("include"))
        includeColumn.title = "Include"
        includeColumn.width = 150
        includeColumn.headerCell = SchemaTableHeaderCellView(textCell: includeColumn.title)
        tableView.addTableColumn(includeColumn)

        // Comment column
        let commentColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("comment"))
        commentColumn.title = "Comment"
        commentColumn.width = 150
        commentColumn.headerCell = SchemaTableHeaderCellView(textCell: commentColumn.title)
        tableView.addTableColumn(commentColumn)

        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator

        scrollView.documentView = tableView
        context.coordinator.tableView = tableView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.indexes = indexes
        context.coordinator.colorScheme = colorScheme

        if let tableView = scrollView.documentView as? NSTableView {
            tableView.reloadData()
        }
    }

    func makeCoordinator() -> IndexTableCoordinator {
        IndexTableCoordinator(indexes: indexes, colorScheme: colorScheme)
    }
}

// MARK: - Index Table Coordinator
class IndexTableCoordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
    var indexes: [DatabaseIndexInfo]
    var colorScheme: ColorScheme
    weak var tableView: NSTableView?

    init(indexes: [DatabaseIndexInfo], colorScheme: ColorScheme) {
        self.indexes = indexes
        self.colorScheme = colorScheme
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return indexes.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return SchemaNSTableRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < indexes.count else { return nil }
        let index = indexes[row]

        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")
        let isLastColumn = tableColumn == tableView.tableColumns.last

        switch identifier.rawValue {
        case "number":
            return makeNumberCell(for: row, in: tableView, isLastColumn: isLastColumn)
        case "name":
            return makeNameCell(for: index, in: tableView, isLastColumn: isLastColumn)
        case "type":
            return makeTextCell(text: index.indexType.rawValue.uppercased(), in: tableView, isLastColumn: isLastColumn)
        case "columns":
            return makeTextCell(text: index.columnsDisplay, in: tableView, isLastColumn: isLastColumn)
        case "unique":
            return makeCheckboxCell(isChecked: index.isUnique, in: tableView, isLastColumn: isLastColumn)
        case "condition":
            return makeTextCell(text: index.condition, in: tableView, isLastColumn: isLastColumn)
        case "include":
            return makeTextCell(text: index.includeColumnsDisplay, in: tableView, isLastColumn: isLastColumn)
        case "comment":
            return makeTextCell(text: index.comment, in: tableView, isLastColumn: isLastColumn)
        default:
            return nil
        }
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 28
    }

    // MARK: - Cell Factories

    private func addCellBorders(to cell: NSView, isLastColumn: Bool = false) {
        if !isLastColumn {
            let rightBorderView = NSView()
            rightBorderView.wantsLayer = true
            rightBorderView.layer?.backgroundColor = NSColor.separatorColor.cgColor
            cell.addSubview(rightBorderView)
            rightBorderView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                rightBorderView.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: 0),
                rightBorderView.topAnchor.constraint(equalTo: cell.topAnchor),
                rightBorderView.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
                rightBorderView.widthAnchor.constraint(equalToConstant: 1.0)
            ])
        }

        let bottomBorderView = NSView()
        bottomBorderView.wantsLayer = true
        bottomBorderView.layer?.backgroundColor = NSColor.separatorColor.cgColor
        cell.addSubview(bottomBorderView)
        bottomBorderView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bottomBorderView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 0),
            bottomBorderView.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: 0),
            bottomBorderView.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: 0),
            bottomBorderView.heightAnchor.constraint(equalToConstant: 1.0)
        ])
    }

    private func makeNumberCell(for row: Int, in tableView: NSTableView, isLastColumn: Bool) -> NSView {
        let cell = NSTableCellView()
        let label = NSTextField(labelWithString: "\(row + 1)")
        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        addCellBorders(to: cell, isLastColumn: isLastColumn)
        return cell
    }

    private func makeNameCell(for index: DatabaseIndexInfo, in tableView: NSTableView, isLastColumn: Bool) -> NSView {
        let cell = NSTableCellView()

        let label = NSTextField(labelWithString: index.name)
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        addCellBorders(to: cell, isLastColumn: isLastColumn)
        return cell
    }

    // MARK: - Generic Cell Factories

    /// Generic text cell factory - reusable for all text-based fields
    private func makeTextCell(text: String?, in tableView: NSTableView, isLastColumn: Bool) -> NSView {
        let cell = NSTableCellView()
        let label = NSTextField()
        // Treat empty strings as nil for placeholder display
        let displayText = text?.isEmpty == true ? nil : text
        label.stringValue = displayText ?? ""
        label.placeholderString = "(NULL)"
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        addCellBorders(to: cell, isLastColumn: isLastColumn)
        return cell
    }

    /// Generic checkbox cell factory - reusable for all boolean fields
    private func makeCheckboxCell(isChecked: Bool, in tableView: NSTableView, isLastColumn: Bool) -> NSView {
        let cell = NSTableCellView()

        let icon = NSImageView()
        let symbolName = isChecked ? "checkmark.square.fill" : "square"
        icon.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        icon.contentTintColor = .controlTextColor
        icon.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(icon)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16)
        ])

        addCellBorders(to: cell, isLastColumn: isLastColumn)
        return cell
    }
}
