//
//  SchemaTableCoordinator.swift
//  Pluk
//
//  Created by Fauzaan on 10/18/25.
//

import Foundation
import AppKit
import SwiftUI

class SchemaTableCoordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
    var columns: [DatabaseSchemaInfo]
    var colorScheme: ColorScheme
    weak var tableView: NSTableView?

    init(columns: [DatabaseSchemaInfo], colorScheme: ColorScheme) {
        self.columns = columns
        self.colorScheme = colorScheme
    }

    // MARK: - Data Source
    func numberOfRows(in tableView: NSTableView) -> Int {
        return columns.count
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return SchemaNSTableRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < columns.count else { return nil }
        let column = columns[row]

        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")

        // Check if this is the last column
        let isLastColumn = tableColumn == tableView.tableColumns.last

        switch identifier.rawValue {
        case "number":
            return makeNumberCell(for: row, in: tableView, isLastColumn: isLastColumn)
        case "name":
            return makeNameCell(for: column, in: tableView, isLastColumn: isLastColumn)
        case "type":
            return makeTextCell(text: column.dataType, in: tableView, isLastColumn: isLastColumn)
        case "nullable":
            return makeCheckboxCell(isChecked: column.isNullable == "YES", in: tableView, isLastColumn: isLastColumn)
        case "default":
            return makeTextCell(text: column.columnDefault, in: tableView, isLastColumn: isLastColumn)
        case "constraints":
            let referenceText: String? = column.hasForeignKey && column.primaryForeignKeyConstraint != nil
                ? formatForeignKeyReference(column.primaryForeignKeyConstraint!)
                : nil
            return makeTextCell(text: referenceText, in: tableView, isLastColumn: isLastColumn)
        default:
            return nil
        }
    }

    // MARK: - Delegate
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 28
    }

    // MARK: - Cell Factories
    private func addCellBorders(to cell: NSView, isLastColumn: Bool = false) {
        // Right border (skip for last column)
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

        // Bottom border
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

    // MARK: - Custom cell types
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

    private func makeNameCell(for column: DatabaseSchemaInfo, in tableView: NSTableView, isLastColumn: Bool) -> NSView {
        let cell = NSTableCellView()

        let label = NSTextField(labelWithString: column.columnName)
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

    // Helper method to format the foreign key reference
    private func formatForeignKeyReference(_ constraint: ConstraintInfo) -> String {
        guard let refTable = constraint.referencedTable else {
            return ""
        }

        // Build schema.table if schema exists
        var reference = ""
        if let refSchema = constraint.referencedSchema, !refSchema.isEmpty {
            reference = "\(refSchema).\(refTable)"
        } else {
            reference = refTable
        }

        // Add column if available
        if let refColumn = constraint.referencedColumns?.first, !refColumn.isEmpty {
            reference += "(\(refColumn))"
        }

        return reference
    }
}

// MARK: - Custom Row styling
class SchemaNSTableRowView: NSTableRowView {
    override var isEmphasized: Bool {
        get { false }  // Always return false to prevent text color changes
        set {
            // Don't call super to prevent the emphasized state from changing
        }
    }
    
    override func drawSelection(in dirtyRect: NSRect) {
        drawFullRowSelection()
    }
    
    
    private func drawFullRowSelection() {
        // Subtle row selection color with different colors for light/dark theme
        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let customColor = isDarkMode
            ? NSColor.controlColor.withAlphaComponent(0.08)
            : NSColor.controlAccentColor.withAlphaComponent(0.08)
        customColor.setFill()

        // Apply bottom padding to the selection rectangle
        let paddedRect = NSRect(
            x: bounds.origin.x,
            y: bounds.origin.y,
            width: bounds.width,
            height: bounds.height - 1
        )
        paddedRect.fill()
    }
}

// MARK: - Schema table header cell view
class SchemaTableHeaderCellView: NSTableHeaderCell {
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(textCell: String) {
        super.init(textCell: textCell)
    }
    
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        // Create text attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = self.alignment

        let textColor = NSColor.secondaryLabelColor
        let fontWeight: NSFont.Weight = .regular

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: fontWeight),
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
        ]

        // Get the proper title rect
        var titleRect = self.titleRect(forBounds: cellFrame)
        titleRect = titleRect.insetBy(dx: 8, dy: 0)

        // Draw the text in the title rect
        let attributedTitle = NSAttributedString(string: title, attributes: attributes)
        attributedTitle.draw(in: titleRect)
    }
}
