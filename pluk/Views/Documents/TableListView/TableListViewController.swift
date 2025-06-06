//
//  TableListViewController.swift
//  Pluk
//
//  Created by Fauzaan on 6/2/25.
//
import Foundation
import SwiftUI
import AppKit

class TableListViewController: NSViewController {
    private var postgresResult: PostgreSQLQueryResult?
    private let containerView = NSView()
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let schema: DatabaseSchemaResult

    private enum CellIdentifier {
        static let checkbox = NSUserInterfaceItemIdentifier("CheckboxCell")
        static let textCell = NSUserInterfaceItemIdentifier("TextCell")
        static let rowView = NSUserInterfaceItemIdentifier("CustomRowView")
    }
    
    init(rows: PostgreSQLQueryResult, schema: DatabaseSchemaResult) {
        self.postgresResult = rows
        self.schema = schema
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func updateRows(_ newRows: PostgreSQLQueryResult, isLoading: Bool = false, schema: DatabaseSchemaResult? = nil) {
           // Update on main thread since we're dealing with UI
           DispatchQueue.main.async { [weak self] in
               guard let self = self else { return }
               
               // Store the new data
               self.postgresResult = newRows
               
               print("📊 TableListViewController: Received \(newRows.rowCount) rows")
               print("🔄 Loading state: \(isLoading)")
               
               // If we're loading, you might want to show a loading state
               if isLoading {
//                   self.showLoadingState()
               } else {
//                   self.hideLoadingState()
                   
                   // ✅ Rebuild columns when data changes
                   self.setupDynamicColumns()
                   
                   // Reload the table with new data
                   self.tableView.reloadData()
               }
           }
       }
    
    private func setupDynamicColumns() {
            for columnInfo in schema.columns {
                createColumn(
                    identifier: columnInfo.columnName,
                    title: columnInfo.columnName.capitalized,
                    icon: nil
                )
            }
        }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHeaderSort(_:)),
            name: NSNotification.Name("HeaderSortClicked"),
            object: nil
        )
        
        setupUI()
        setupTable()
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
        // Create the table column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.minWidth = 40
        column.maxWidth = 400
        column.resizingMask = [.userResizingMask]
        
        // Create and configure the custom header cell
        let customHeaderCell = CustomTableHeaderCell(
            textCell: identifier
        )
        customHeaderCell.configure(title: title, icon: icon, showSortButton: false)
        
        column.resizingMask = [.userResizingMask]
        customHeaderCell.representedObject = column
        
        column.headerCell = customHeaderCell
        
        // Add the column to the table
        tableView.addTableColumn(column)
    }
    
    private func setupUI() {
        // Container with border (full width)
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 10
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Scroll view setup
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = NSColor.clear
        
        // ✅ Table view setup - make it size itself
        tableView.style = .inset
        tableView.backgroundColor = NSColor.clear
//        tableView.gridStyleMask = [.solidVerticalGridLineMask]
        tableView.gridColor = NSColor.separatorColor
        tableView.usesAutomaticRowHeights = false
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        
        if let headerView = tableView.headerView {
            let newHeight: CGFloat = 32
            headerView.frame.size.height = newHeight
            
            headerView.wantsLayer = true
            
            let visualEffectView = NSVisualEffectView()
            visualEffectView.frame = headerView.bounds
            visualEffectView.material = .sidebar
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.autoresizingMask = [.width, .height]
            
            // Force it to the background using zPosition
            visualEffectView.wantsLayer = true
            visualEffectView.layer?.zPosition = -1000
            
            headerView.addSubview(visualEffectView)
            tableView.headerView = headerView
        }
        
        // ✅ Put table directly in scroll view (revert to original)
        scrollView.documentView = tableView
        
        view.addSubview(containerView)
        containerView.addSubview(scrollView)
        
        setupConstraints()
    }
    private func setupTable() {
        // Create data columns with sorting keys
        let columnData = [
            ("Name", "id", 120.0, "id"),
            ("Type", "user_id", 120.0, "user_id"),
            ("Alias", "name", 120.0, "name"),
            ("Hotkey", "createdAt", 120.0, "createdAt")
        ]
        
        setupDynamicColumns()
//
//        
////        guard let result = postgresResult else { return }
//        
//        for (name, _, _, _) in columnData {
//            createColumn(
//                identifier: name,
//                title: name,
//                icon: nil
//            )
//        }
//        
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
        tableView.style = .plain
//        tableView.reloadData()
    }
    
    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Container fills the entire view (for scrollbar to reach edge)
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Scroll view fills the entire container
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
}


// MARK: - Table View Data Source
extension TableListViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return postgresResult?.rowCount ?? 0
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else { return }
        
        print("Sorting by: \(sortDescriptor.key ?? "unknown"), ascending: \(sortDescriptor.ascending)")
        tableView.reloadData()
    }
}

// MARK: - Table View Delegate
extension TableListViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn,
              let result = postgresResult,
              row < result.rowCount else { return nil }
        
        // Handle data columns with recycling
        var cellView = tableView.makeView(withIdentifier: CellIdentifier.textCell, owner: self) as? TextCellView
        
        if cellView == nil {
            // Create new text cell if none available for reuse
            cellView = TextCellView()
            cellView?.identifier = CellIdentifier.textCell
        }
        
        // Configure the cell with data
        let columnName = tableColumn.identifier.rawValue
        let value = result.value(row: row, column: columnName)
        let displayText = formatValueForDisplay(value)
        
        let isLastColumn = tableView.tableColumns.firstIndex(of: tableColumn) == tableView.tableColumns.count - 1
        
        cellView?.configure(
            text: displayText,
            isLastColumn: isLastColumn
        )
        
        return cellView
    }
//    
//    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
//        guard let tableColumn = tableColumn,
//              let result = postgresResult,
//              row < result.rowCount else { return nil }
//      
//      guard let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? NSTableCellView else { return nil }
//      
//        let columnName = tableColumn.identifier.rawValue
//        let value = result.value(row: row, column: columnName)
//        let displayText = formatValueForDisplay(value)
//        
//          cell.textField?.stringValue = displayText
//      
//      return cell
//    }
    
    private func formatValueForDisplay(_ value: Any?) -> String {
        guard let value = value else { return "NULL" }
        
        if let date = value as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else {
            return String(describing: value)
        }
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
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 28
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        // Get the current mouse location
        let mouseLocation = NSEvent.mouseLocation
        let windowLocation = tableView.window?.convertFromScreen(NSRect(origin: mouseLocation, size: .zero)).origin ?? .zero
        let tableLocation = tableView.convert(windowLocation, from: nil)
        
        let clickedColumn = tableView.column(at: tableLocation)
        
        print("About to select row: \(row)")
        print("Clicked column: \(clickedColumn)")
        
        if clickedColumn >= 0 && clickedColumn < tableView.tableColumns.count {
            let columnIdentifier = tableView.tableColumns[clickedColumn].identifier.rawValue
            print("Column: \(columnIdentifier)")
        }
        
        return true
    }
}

