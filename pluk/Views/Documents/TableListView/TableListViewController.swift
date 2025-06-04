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
    private var rows: [Any] = []
    private let containerView = NSView()
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    
    private var checkedRows: Set<Int> = []
    
    private enum CellIdentifier {
        static let checkbox = NSUserInterfaceItemIdentifier("CheckboxCell")
        static let textCell = NSUserInterfaceItemIdentifier("TextCell")
        static let rowView = NSUserInterfaceItemIdentifier("CustomRowView")
    }
    
    init(rows: [Any]) {
        self.rows = rows
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = NSView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHeaderSort(_:)),
            name: NSNotification.Name("HeaderSortClicked"),
            object: nil
        )
        
        //        setupTableWithCustomHeaders()
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
        column.width = 150
        column.minWidth = 100
        column.maxWidth = 300
        column.resizingMask = [.userResizingMask]
        
        // Create and configure the custom header cell
        let customHeaderCell = CustomTableHeaderCell(
            textCell: identifier
        )
        customHeaderCell.configure(title: title, icon: icon, showSortButton: false)
        //
        
        customHeaderCell.representedObject = column
        
        //        column.headerCell = NSTableHeaderCell(textCell: identifier)
        column.headerCell = customHeaderCell
        
        // Add the column to the table
        tableView.addTableColumn(column)
    }
    
    private func setupUI() {
        // Container with border
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
        scrollView.documentView = tableView
        
        // Table view setup
        tableView.style = .inset
        tableView.backgroundColor = NSColor.clear
        tableView.gridStyleMask = [.solidVerticalGridLineMask]
        tableView.gridColor = NSColor.separatorColor
        tableView.usesAutomaticRowHeights = false
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        
        view.addSubview(containerView)
        containerView.addSubview(scrollView)
        
        setupConstraints()
    }
    
    private func setupTable() {
        // Create checkbox column first
        //        let checkboxColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("checkbox"))
        //        checkboxColumn.title = ""
        //        checkboxColumn.width = 20.0
        //        checkboxColumn.resizingMask = []
        
        
        // Create data columns with sorting keys
        let columnData = [
            ("Name", "id", 120.0, "id"),
            ("Type", "user_id", 120.0, "user_id"),
            ("Alias", "name", 120.0, "name"),
            ("Hotkey", "createdAt", 120.0, "createdAt")
        ]
        
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
        
        for (identifier, title, width, sortKey) in columnData {
                                    // Add sort descriptor for this column
            //                        let sortDescriptor = NSSortDescriptor(key: sortKey, ascending: true)
            //                        column.sortDescriptorPrototype = sortDescriptor
            createColumn(identifier: identifier, title: title, icon: NSImage(systemSymbolName: "person.fill", accessibilityDescription: nil))
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
        tableView.style = .plain
        tableView.reloadData()
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
        
        // Set the table view's frame to limit its width
        let totalColumnWidth: CGFloat = 40.0 + (4 * 120.0)
        let padding: CGFloat = 20
        let tableWidth = totalColumnWidth + padding
        
        tableView.frame = NSRect(x: 0, y: 0, width: tableWidth, height: 0)
    }
    
    // MARK: - Checkbox Actions
    @objc private func checkboxToggled(_ sender: NSButton) {
        let row = sender.tag
        
        if sender.state == .on {
            checkedRows.insert(row)
        } else {
            checkedRows.remove(row)
        }
        
        print("Row \(row) checkbox state: \(sender.state == .on ? "checked" : "unchecked")")
        print("Currently checked rows: \(checkedRows)")
    }
    
    // Public methods
    func getCheckedRows() -> Set<Int> {
        return checkedRows
    }
    
    func clearAllCheckboxes() {
        checkedRows.removeAll()
        tableView.reloadData()
    }
    
    func checkAllRows() {
        checkedRows = Set(0..<tableView.numberOfRows)
        tableView.reloadData()
    }
}


// MARK: - Table View Data Source
extension TableListViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return 100 // Sample data
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
        guard let tableColumn = tableColumn else { return nil }
        
        // Handle checkbox column with recycling
        if tableColumn.identifier.rawValue == "checkbox" {
            // Try to reuse existing checkbox cell
            var cellView = tableView.makeView(withIdentifier: CellIdentifier.checkbox, owner: self) as? CheckboxCellView
            
            if cellView == nil {
                // Create new checkbox cell if none available for reuse
                cellView = CheckboxCellView()
                cellView?.identifier = CellIdentifier.checkbox
            }
            
            // Configure the cell
            cellView?.configure(
                isChecked: checkedRows.contains(row),
                row: row,
                target: self,
                action: #selector(checkboxToggled(_:))
            )
            
            return cellView
        }
        
        // Handle data columns with recycling
        var cellView = tableView.makeView(withIdentifier: CellIdentifier.textCell, owner: self) as? TextCellView
        
        if cellView == nil {
            // Create new text cell if none available for reuse
            cellView = TextCellView()
            cellView?.identifier = CellIdentifier.textCell
        }
        
        // Configure the cell with data
        let isLastColumn = tableView.tableColumns.firstIndex(of: tableColumn) == tableView.tableColumns.count - 1
        cellView?.configure(
            text: "Cell \(row + 1)",
            isLastColumn: isLastColumn
        )
        
        return cellView
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
    
    func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        print("table column")
        return true
    }
    
    //    func tableView(_ tableView: NSTableView, headerViewFor tableColumn: NSTableColumn?) -> NSTableHeaderView? {
    //        let headerView = NSTableHeaderView()
    //        return headerView
    //
    ////        let headerCell = NSTableHeaderCell(textCell: title)
    ////        headerCell.font = NSFont.boldSystemFont(ofSize: 11)
    ////        headerCell.backgroundStyle = .raised
    ////        headerCell.textColor = NSColor.labelColor.withAlphaComponent(0.7)
    //    }
}

