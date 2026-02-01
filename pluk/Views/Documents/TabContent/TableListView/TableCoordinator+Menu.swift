//
//  TableCoordinator+Menu.swift
//  Pluk
//
//  Created by Fauzaan on 7/10/25.
//

import Foundation
import AppKit
import Combine

// MARK: - Menu Actions Extension
extension TableCoordinator {
    @objc func refreshCurrentTable() {
        NotificationCenter.default.post(
            name: .tableRefresh,
            object: nil,
            userInfo: ["tableName": tableName]
        )
    }
    
    @objc func addRow() {
        NotificationCenter.default.post(
            name: .addNewRecord,
            object: self,
            userInfo: ["tableName": tableName]
        )
    }
    
    @objc func editItem() {
        // Get the currently selected cell (which was updated by right-click)
        guard let currentCell = tableView.getCurrentSelectedCell() else {
            return
        }
        
        let row = currentCell.row
        let column = currentCell.column
        
        guard row >= 0 && column >= 0 else {
            return
        }
        
        tableView.enterEditModeForCell(row: row, column: column)
    }
    
    @objc func deleteItem() {
        let selectedRows = tableView.selectedRowIndexes

        guard !selectedRows.isEmpty else {
            return
        }

        NotificationCenter.default.post(
            name: .didRequestDelete,
            object: self,
            userInfo: ["rows": selectedRows, "tableView": tableView]
        )
    }

    @objc func quickLookItem() {
        guard let currentCell = tableView.getCurrentSelectedCell() else {
            return
        }

        let row = currentCell.row
        let column = currentCell.column

        guard row >= 0 && column >= 0 else {
            return
        }

        showQuickLook(row: row, column: column)
    }

    @objc func handleQuickLookRequest(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let row = userInfo["row"] as? Int,
              let column = userInfo["column"] as? Int,
              let notificationTableView = userInfo["tableView"] as? CustomTableView,
              notificationTableView === self.tableView else {
            return
        }

        showQuickLook(row: row, column: column)
    }

    private func showQuickLook(row: Int, column: Int) {
        guard let queryResult = queryResult,
              row < queryResult.rows.count,
              column < tableView.tableColumns.count else {
            return
        }

        let tableColumn = tableView.tableColumns[column]
        let columnName = tableColumn.identifier.rawValue

        guard let queryRowInfo = queryResult.value(row: row, column: columnName) else {
            return
        }

        let columnInfo = queryResult.column(named: columnName)
        let dataType = columnInfo?.dataType ?? "unknown"

        let originalValue = formatValueForQuickLook(queryRowInfo.value)

        guard let cellView = tableView.view(atColumn: column, row: row, makeIfNecessary: false) else {
            return
        }

        let cellRect = cellView.bounds

        Task { @MainActor in
            QuickLookPopoverController.shared.showQuickLook(
                for: originalValue,
                fieldName: columnName,
                dataType: dataType,
                relativeTo: cellRect,
                of: cellView,
                onSave: { [weak self] newValue in
                    self?.handleQuickLookSave(
                        row: row,
                        columnName: columnName,
                        dataType: dataType,
                        originalValue: originalValue,
                        newValue: newValue
                    )
                }
            )
        }
    }

    private func handleQuickLookSave(row: Int, columnName: String, dataType: String, originalValue: String, newValue: String) {
        guard let tracker = modificationTracker else { return }

        tracker.updateCell(
            rowIndex: row,
            columnName: columnName,
            newValue: newValue,
            originalValue: originalValue,
            dataType: dataType
        )

        tableView.reloadData(
            forRowIndexes: IndexSet(integer: row),
            columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns)
        )
    }

    private func formatValueForQuickLook(_ value: Any?) -> String {
        guard let value else { return "NULL" }

        switch value {
        case let string as String:
            return string.isEmpty ? "" : prettyPrintJSON(string)
        case let dict as [String: Any]:
            return prettyPrintJSON(dict)
        case let array as [Any]:
            return prettyPrintJSON(array)
        default:
            return String(describing: value)
        }
    }

    private func prettyPrintJSON(_ value: Any) -> String {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            let looksLikeJSON = (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
                                (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))
            guard looksLikeJSON, let data = string.data(using: .utf8) else {
                return string
            }
            guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
                  let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
                  let result = String(data: prettyData, encoding: .utf8) else {
                return string
            }
            return result
        }

        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: data, encoding: .utf8) else {
            return String(describing: value)
        }
        return result
    }

    // MARK: - Copy Rows As Actions

    @objc func copyRowsAsPlainText() {
        guard let (rowsData, columnNames) = getSelectedRowsData(),
              !rowsData.isEmpty,
              !columnNames.isEmpty else { return }

        var lines: [String] = []
        for rowData in rowsData {
            let values = columnNames.map { getRowValue(rowData, columnName: $0) }
            lines.append(values.joined(separator: "\t"))
        }

        copyToClipboard(lines.joined(separator: "\n"))
    }

    @objc func copyRowsAsJSON() {
        guard let (rowsData, columnNames) = getSelectedRowsData(),
              !rowsData.isEmpty,
              !columnNames.isEmpty else { return }

        var jsonArray: [[String: Any]] = []
        for rowData in rowsData {
            var jsonObject: [String: Any] = [:]
            for columnName in columnNames {
                jsonObject[columnName] = getRawValueForJSON(rowData, columnName: columnName)
            }
            jsonArray.append(jsonObject)
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonArray, options: [.prettyPrinted, .sortedKeys])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                copyToClipboard(jsonString)
            }
        } catch {
            debugLog("Failed to serialize JSON: \(error)")
        }
    }

    @objc func copyRowsAsHTML() {
        guard let (rowsData, columnNames) = getSelectedRowsData(),
              !rowsData.isEmpty,
              !columnNames.isEmpty else { return }

        var html = "<table>\n"
        html += "  <thead>\n    <tr>"
        for columnName in columnNames {
            html += "<th>\(escapeHTML(columnName))</th>"
        }
        html += "</tr>\n  </thead>\n"

        html += "  <tbody>\n"
        for rowData in rowsData {
            html += "    <tr>"
            for columnName in columnNames {
                let value = getRowValue(rowData, columnName: columnName)
                html += "<td>\(escapeHTML(value))</td>"
            }
            html += "</tr>\n"
        }
        html += "  </tbody>\n</table>"

        copyToClipboard(html)
    }

    @objc func copyRowsAsMarkdown() {
        guard let (rowsData, columnNames) = getSelectedRowsData(),
              !rowsData.isEmpty,
              !columnNames.isEmpty else { return }

        var markdown = "| " + columnNames.joined(separator: " | ") + " |\n"
        markdown += "| " + columnNames.map { _ in "---" }.joined(separator: " | ") + " |\n"

        for rowData in rowsData {
            let values = columnNames.map { getRowValue(rowData, columnName: $0).replacing("|", with: "\\|") }
            markdown += "| " + values.joined(separator: " | ") + " |\n"
        }

        copyToClipboard(markdown)
    }

    @objc func copyRowsAsCSV() {
        guard let (rowsData, columnNames) = getSelectedRowsData(),
              !rowsData.isEmpty,
              !columnNames.isEmpty else { return }

        var lines: [String] = []
        for rowData in rowsData {
            let values = columnNames.map { escapeCSV(getRowValue(rowData, columnName: $0)) }
            lines.append(values.joined(separator: ","))
        }

        copyToClipboard(lines.joined(separator: "\n"))
    }

    @objc func copyRowsAsCSVWithHeader() {
        guard let (rowsData, columnNames) = getSelectedRowsData(),
              !rowsData.isEmpty,
              !columnNames.isEmpty else { return }

        var lines: [String] = []
        lines.append(columnNames.map { escapeCSV($0) }.joined(separator: ","))

        for rowData in rowsData {
            let values = columnNames.map { escapeCSV(getRowValue(rowData, columnName: $0)) }
            lines.append(values.joined(separator: ","))
        }

        copyToClipboard(lines.joined(separator: "\n"))
    }

    @objc func copyRowsAsInsertStatement() {
        guard let (rowsData, columnNames) = getSelectedRowsData(),
              !rowsData.isEmpty,
              !columnNames.isEmpty else { return }

        let quotedColumns = columnNames.map { "\"\($0)\"" }.joined(separator: ", ")
        var statements: [String] = []

        for rowData in rowsData {
            let values = columnNames.map { columnName -> String in
                return getRawValueForSQL(rowData, columnName: columnName)
            }
            let valuesString = values.joined(separator: ", ")
            statements.append("INSERT INTO \"\(tableName)\" (\(quotedColumns)) VALUES (\(valuesString));")
        }

        copyToClipboard(statements.joined(separator: "\n"))
    }

    // MARK: - Helper Methods

    private func getSelectedRowsData() -> (rows: [[String: QueryRowInfo]], columnNames: [String])? {
        let selectedIndexes = tableView.selectedRowIndexes
        guard !selectedIndexes.isEmpty, let queryResult = queryResult else { return nil }

        var rowsData: [[String: QueryRowInfo]] = []
        for index in selectedIndexes {
            if index < queryResult.rows.count {
                rowsData.append(queryResult.rows[index])
            }
        }

        let columnNames = queryResult.columns.map { $0.name }
        return (rowsData, columnNames)
    }

    private func getRowValue(_ rowData: [String: QueryRowInfo], columnName: String) -> String {
        if let queryRowInfo = rowData[columnName] {
            return formatValue(queryRowInfo.value)
        }
        return "NULL"
    }

    private func getRawValueForSQL(_ rowData: [String: QueryRowInfo], columnName: String) -> String {
        if let queryRowInfo = rowData[columnName] {
            return formatValueForSQL(queryRowInfo.value)
        }
        return "NULL"
    }

    private func getRawValueForJSON(_ rowData: [String: QueryRowInfo], columnName: String) -> Any {
        if let queryRowInfo = rowData[columnName] {
            return convertToJSONSafeValue(queryRowInfo.value)
        }
        return NSNull()
    }

    private func formatValue(_ value: Any?) -> String {
        guard let value = value else { return "NULL" }

        if value is NSNull {
            return "NULL"
        }

        if let stringValue = value as? String {
            return stringValue
        }

        if let numberValue = value as? NSNumber {
            return numberValue.stringValue
        }

        if let boolValue = value as? Bool {
            return boolValue ? "true" : "false"
        }

        if let dateValue = value as? Date {
            return ISO8601DateFormatter().string(from: dateValue)
        }

        if let dataValue = value as? Data {
            return dataValue.base64EncodedString()
        }

        return String(describing: value)
    }

    private func convertToJSONSafeValue(_ value: Any?) -> Any {
        guard let value = value else { return NSNull() }

        if value is NSNull {
            return NSNull()
        }

        if let stringValue = value as? String {
            return stringValue
        }

        if let numberValue = value as? NSNumber {
            return numberValue
        }

        if let boolValue = value as? Bool {
            return boolValue
        }

        if let intValue = value as? Int {
            return intValue
        }

        if let doubleValue = value as? Double {
            return doubleValue
        }

        if let dateValue = value as? Date {
            return ISO8601DateFormatter().string(from: dateValue)
        }

        if let dataValue = value as? Data {
            return dataValue.base64EncodedString()
        }

        if let uuidValue = value as? UUID {
            return uuidValue.uuidString
        }

        if let arrayValue = value as? [Any] {
            return arrayValue.map { convertToJSONSafeValue($0) }
        }

        if let dictValue = value as? [String: Any] {
            var safeDict: [String: Any] = [:]
            for (key, val) in dictValue {
                safeDict[key] = convertToJSONSafeValue(val)
            }
            return safeDict
        }

        return String(describing: value)
    }

    private func formatValueForSQL(_ value: Any?) -> String {
        guard let value = value else { return "NULL" }

        if value is NSNull {
            return "NULL"
        }

        if let stringValue = value as? String {
            return "'\(escapeSQL(stringValue))'"
        }

        if let numberValue = value as? NSNumber {
            if CFGetTypeID(numberValue) == CFBooleanGetTypeID() {
                return numberValue.boolValue ? "TRUE" : "FALSE"
            }
            return numberValue.stringValue
        }

        if let boolValue = value as? Bool {
            return boolValue ? "TRUE" : "FALSE"
        }

        if let intValue = value as? Int {
            return String(intValue)
        }

        if let doubleValue = value as? Double {
            return String(doubleValue)
        }

        if let dateValue = value as? Date {
            return "'\(ISO8601DateFormatter().string(from: dateValue))'"
        }

        if let dataValue = value as? Data {
            return "'\(dataValue.base64EncodedString())'"
        }

        return "'\(escapeSQL(String(describing: value)))'"
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let escaped = value.replacing("\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    private func escapeSQL(_ value: String) -> String {
        return value.replacing("'", with: "''")
    }

    private func escapeHTML(_ value: String) -> String {
        return value
            .replacing("&", with: "&amp;")
            .replacing("<", with: "&lt;")
            .replacing(">", with: "&gt;")
            .replacing("\"", with: "&quot;")
            .replacing("'", with: "&#39;")
    }

    private func copyToClipboard(_ content: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }
}
