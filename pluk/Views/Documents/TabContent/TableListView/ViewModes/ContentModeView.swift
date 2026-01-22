//
//  ContentModeView.swift
//  Pluk
//
//  Created by Fauzaan on 10/15/25.
//

import SwiftUI

struct ContentModeView: View {
    @Bindable var selectedTab: DatabaseTab
    let schema: DatabaseSchemaResult?
    let queryResult: QueryResult?
    let tableName: String
    let cacheNamespace: String?
    let onSort: ((String, Bool) -> Void)?
    let modificationTracker: TableModificationTracker?
    let needsToSelectLastRow: Bool
    let onDeleteNewRow: ((Int) -> Void)?
    let onForeignKeyNavigation: ((String, String, String) -> Void)?
    let highlightedFields: Set<String>
    let highlightedRows: Set<Int>
    let onRowSelected: (([String: QueryRowInfo]?) -> Void)?

    var body: some View {
        TableListViewController(
            selectedTab: selectedTab,
            schema: schema,
            queryResult: queryResult,
            tableName: tableName,
            cacheNamespace: cacheNamespace,
            onSort: onSort,
            modificationTracker: modificationTracker,
            needsToSelectLastRow: needsToSelectLastRow,
            onDeleteNewRow: onDeleteNewRow,
            onForeignKeyNavigation: onForeignKeyNavigation,
            highlightedFields: highlightedFields,
            highlightedRows: highlightedRows,
            onRowSelected: onRowSelected
        )
    }
}
