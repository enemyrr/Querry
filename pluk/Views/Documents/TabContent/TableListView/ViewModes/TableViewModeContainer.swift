//
//  TableViewModeContainer.swift
//  Pluk
//
//  Created by Fauzaan on 10/15/25.
//

import SwiftUI

struct TableViewModeContainer: View {
    let viewMode: DatabaseTab.ViewMode
    let schema: DatabaseSchemaResult?
    let indexes: [DatabaseIndexInfo]?
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

    var body: some View {
        Group {
            switch viewMode {
            case .content:
                ContentModeView(
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
                    highlightedRows: highlightedRows
                )

            case .schema:
                SchemaModeView(
                    schema: schema,
                    indexes: indexes,
                    tableName: tableName
                )

            case .definition:
                DefinitionModeView(
                    schema: schema,
                    tableName: tableName
                )
            }
        }
        .animation(.smooth(duration: 0.2), value: viewMode)
    }
}
