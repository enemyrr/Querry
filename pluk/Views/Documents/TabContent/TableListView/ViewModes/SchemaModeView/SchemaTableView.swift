//
//  SchemaTableView.swift
//  Pluk
//
//  Created by Fauzaan on 10/18/25.
//

import SwiftUI
import AppKit

// MARK: - SwiftUI Wrapper
struct SchemaTableView: NSViewRepresentable {
    let columns: [DatabaseSchemaInfo]
    let searchText: String
    @Environment(\.colorScheme) var colorScheme
    
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

        // Header
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
        
        // Column Name
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 200
        nameColumn.minWidth = 100
        nameColumn.headerCell = SchemaTableHeaderCellView(textCell: nameColumn.title)
        tableView.addTableColumn(nameColumn)
        
        // Type
        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "Type"
        typeColumn.width = 150
        typeColumn.minWidth = 100
        typeColumn.headerCell = SchemaTableHeaderCellView(textCell: typeColumn.title)
        tableView.addTableColumn(typeColumn)
        
        // Default
        let defaultColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("default"))
        defaultColumn.title = "Default"
        defaultColumn.width = 150
        defaultColumn.minWidth = 100
        defaultColumn.headerCell = SchemaTableHeaderCellView(textCell: defaultColumn.title)
        tableView.addTableColumn(defaultColumn)

        // Nullable
        let nullableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("nullable"))
        nullableColumn.title = "Null"
        nullableColumn.width = 50
        nullableColumn.minWidth = 50
        nullableColumn.headerCell = SchemaTableHeaderCellView(textCell: nullableColumn.title)
        nullableColumn.headerCell.alignment = .center
        tableView.addTableColumn(nullableColumn)
        
        // Constraints
        let constraintsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("constraints"))
        constraintsColumn.title = "Constraints"
        constraintsColumn.width = 250
        constraintsColumn.minWidth = 100
        constraintsColumn.headerCell = SchemaTableHeaderCellView(textCell: constraintsColumn.title)
        tableView.addTableColumn(constraintsColumn)
        
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        
        scrollView.documentView = tableView
        context.coordinator.tableView = tableView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.columns = filteredColumns()
        context.coordinator.colorScheme = colorScheme
        
        if let tableView = scrollView.documentView as? NSTableView {
            tableView.reloadData()
        }
    }
    
    func makeCoordinator() -> SchemaTableCoordinator {
        SchemaTableCoordinator(columns: filteredColumns(), colorScheme: colorScheme)
    }

    private func filteredColumns() -> [DatabaseSchemaInfo] {
        if searchText.isEmpty {
            return columns
        }
        return columns.filter { column in
            column.columnName.localizedCaseInsensitiveContains(searchText) ||
            column.dataType.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - ConstraintType Extension for NSColor
extension ConstraintType {
    var nsColor: NSColor {
        switch self {
        case .primaryKey: return .systemYellow
        case .foreignKey: return .systemBlue
        case .unique: return .systemPurple
        case .check: return .systemOrange
        case .exclusion: return .systemRed
        case .trigger: return .systemGreen
        }
    }
}
