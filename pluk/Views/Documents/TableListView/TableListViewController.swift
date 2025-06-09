//
//  TableListViewController.swift
//  Pluk
//
//  Created by Fauzaan on 6/2/25.
//
import Foundation
import SwiftUI
import AppKit

class ExtendedClipView: NSClipView {
    var bottomExtension: CGFloat = 50
    
    override var documentRect: NSRect {
        var rect = super.documentRect
        rect.size.height += bottomExtension
        return rect
    }
}

struct TableListViewController: NSViewRepresentable {
    let rows: PostgreSQLQueryResult?
    let schema: DatabaseSchemaResult?
    
    init(rows: PostgreSQLQueryResult? = nil, schema: DatabaseSchemaResult? = nil) {
        self.rows = rows
        self.schema = schema
    }
    
    class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var rows: PostgreSQLQueryResult?
        var schema: DatabaseSchemaResult?
        
        private let containerView = NSView()
        private let scrollView = NSScrollView()
        private let tableView = NSTableView()
        
        private enum CellIdentifier {
            static let checkbox = NSUserInterfaceItemIdentifier("CheckboxCell")
            static let textCell = NSUserInterfaceItemIdentifier("TextCell")
            static let rowView = NSUserInterfaceItemIdentifier("CustomRowView")
        }
        
        init(rows: PostgreSQLQueryResult?, schema: DatabaseSchemaResult?) {
            self.rows = rows
            self.schema = schema
            super.init()
        }
        
        func setupTableView() -> NSView {
            setupUI()
            setupTable()
            
            return containerView
        }
        
        func updateRows(_ newRows: PostgreSQLQueryResult?, schema: DatabaseSchemaResult? = nil) {
                // Store the new data
                self.rows = newRows
                self.tableView.reloadData()
        }
        
        @objc private func handleHeaderSort(_ notification: Notification) {
            guard let columnTitle = notification.userInfo?["column"] as? String else { return }
            print("Sorting by column: \(columnTitle)")
            
            // Implement your sorting logic here
            sortTableData(by: columnTitle)
        }
        
        private func sortTableData(by columnTitle: String) {
            // Your sorting implementation
            print("Implementing sort for: \(columnTitle)")
            
            // Example: Toggle sort order for the column
            // You would implement actual data sorting here
            tableView.reloadData()
        }
        
        private func createColumn(identifier: String, title: String, icon: NSImage?) {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            
            // Then add custom header
            let customHeaderCell = CustomTableHeaderCell(textCell: identifier)
            customHeaderCell.configure(title: title, icon: icon, showSortButton: false)
            column.headerCell = customHeaderCell
            column.sizeToFit()
            
            tableView.addTableColumn(column)
        }
        
        private func setupUI() {
            containerView.wantsLayer = true
            
            // Create custom clip view
            let customClipView = ExtendedClipView()
            customClipView.bottomExtension = 80 // Your floating bar height
            
            scrollView.contentView = customClipView
            
            // Scroll view setup
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = true
            scrollView.autohidesScrollers = true
            scrollView.borderType = .noBorder
            scrollView.drawsBackground = false
            scrollView.backgroundColor = NSColor.clear
            
            scrollView.documentView = tableView
            containerView.addSubview(scrollView)
            
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                // Scroll view fills the entire container
                scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
        }
        
        private func setupTable() {
            guard let schema = schema else { return }
            
            for columnInfo in schema.columns {
                createColumn(
                    identifier: columnInfo.columnName,
                    title: columnInfo.columnName,
                    icon: nil
                )
            }
            
            // Enable column resizing
            tableView.allowsColumnResizing = true
            tableView.allowsColumnReordering = true
            tableView.columnAutoresizingStyle = .noColumnAutoresizing
            
            // Enable column selection only
            tableView.allowsColumnSelection = true
            tableView.allowsMultipleSelection = true
            tableView.allowsEmptySelection = true
            
            // Set data source and delegate
            tableView.dataSource = self
            tableView.delegate = self
            
            tableView.rowSizeStyle = .custom
            
            // Table view setup
            tableView.style = .plain
            tableView.backgroundColor = NSColor.clear
            tableView.usesAutomaticRowHeights = false
            
            if let headerView = tableView.headerView {
                headerView.frame.size.height = 32
                
                let visualEffectView = NSVisualEffectView()
                visualEffectView.frame = headerView.bounds
                visualEffectView.material = .hudWindow
                visualEffectView.blendingMode = .withinWindow
                visualEffectView.state = .active
                visualEffectView.autoresizingMask = [.width, .height]
                
                visualEffectView.wantsLayer = true
                visualEffectView.layer?.zPosition = -1000
                
                headerView.addSubview(visualEffectView)
                tableView.headerView = headerView
            }
        }
        
        // MARK: - NSTableViewDataSource
        func numberOfRows(in tableView: NSTableView) -> Int {
            return rows?.rowCount ?? 0
        }
        
        @objc private func onItemClicked() {
            print("row \(tableView.clickedRow), col \(tableView.clickedColumn) clicked")
        }
        
        // Row view recycling
        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            // Try to reuse existing row view
            var rowView = tableView.makeView(withIdentifier: CellIdentifier.rowView, owner: self) as? CustomTableRowView
            
            if rowView == nil {
                // Create new row view if none available for reuse
                rowView = CustomTableRowView()
                rowView?.identifier = CellIdentifier.rowView
            }
            
            return rowView
        }
        
        func tableView(_ tableView: NSTableView, sizeToFitWidthOfColumn column: Int) -> CGFloat {
            guard let tableColumn = tableView.tableColumns[safe: column],
                  let rows = self.rows else {
                return 100 // Default width
            }
            
            let columnIdentifier = tableColumn.identifier.rawValue
            
            // Calculate header width
            let headerTitle = tableColumn.title
            let headerFont = NSFont.systemFont(ofSize: 12, weight: .medium)
            let headerAttributes = [NSAttributedString.Key.font: headerFont]
            let headerWidth = (headerTitle as NSString).size(withAttributes: headerAttributes).width + 40 // padding
            
            // Calculate content width by sampling some rows
            var maxContentWidth: CGFloat = 0
            let sampleSize = min(100, rows.rowCount) // Sample first 100 rows for performance
            
            for row in 0..<sampleSize {
                if let value = rows.value(row: row, column: columnIdentifier) {
                    let contentString = String(describing: value)
                    let contentFont = NSFont.systemFont(ofSize: 13) // Match your cell font
                    let contentAttributes = [NSAttributedString.Key.font: contentFont]
                    let contentWidth = (contentString as NSString).size(withAttributes: contentAttributes).width + 20 // padding
                    maxContentWidth = max(maxContentWidth, contentWidth)
                }
            }
            
            // Return the larger of header width or content width, with reasonable bounds
            let calculatedWidth = max(headerWidth, maxContentWidth)
            return max(60, min(calculatedWidth, 300)) // Min 60px, max 300px
        }

        
        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            return 28
        } 
        
        // MARK: - NSTableViewDelegate
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let tableColumn = tableColumn,
                  let result = rows,
                  row < result.rowCount else {
                return NSTextField(labelWithString: "No data")
            }
            
            var cellView = tableView.makeView(withIdentifier: CellIdentifier.textCell, owner: self) as? TextCellView
            
            if cellView == nil {
                cellView = TextCellView()
                cellView?.identifier = CellIdentifier.textCell
            }
            
            // Use the new configure method with raw cell
            let columnName = tableColumn.identifier.rawValue
            let rawCell = result.rawCell(row: row, column: columnName)
            let columnInfo = result.column(named: columnName)
            
            cellView?.configure(rawCell: rawCell, columnInfo: columnInfo!)
            return cellView
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(rows: rows, schema: schema)
    }
    
    func makeNSView(context: Context) -> NSView {
        return context.coordinator.setupTableView()
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.updateRows(rows, schema: schema)
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
