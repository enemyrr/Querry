//
//  SchemaModificationService.swift
//  Pluk
//
//  Service for handling schema modifications (columns and indexes)
//

import Foundation

actor SchemaModificationService {
    private let databaseDriver: any DatabaseDriver

    init(databaseDriver: any DatabaseDriver) {
        self.databaseDriver = databaseDriver
    }

    // MARK: - Column Operations

    /// Add a new column to a table
    func addColumn(
        to tableName: String,
        schema: String?,
        column: DatabaseSchemaInfo
    ) async throws {
        try await databaseDriver.addColumn(to: tableName, schema: schema, column: column)
    }

    /// Modify an existing column
    func modifyColumn(
        in tableName: String,
        schema: String?,
        columnName: String,
        newColumn: DatabaseSchemaInfo
    ) async throws {
        try await databaseDriver.modifyColumn(
            in: tableName,
            schema: schema,
            columnName: columnName,
            newColumn: newColumn
        )
    }

    /// Drop a column from a table
    func dropColumn(
        from tableName: String,
        schema: String?,
        columnName: String
    ) async throws {
        try await databaseDriver.dropColumn(from: tableName, schema: schema, columnName: columnName)
    }

    // MARK: - Index Operations

    /// Create a new index
    func createIndex(
        on tableName: String,
        schema: String?,
        index: DatabaseIndexInfo
    ) async throws {
        try await databaseDriver.createIndex(on: tableName, schema: schema, index: index)
    }

    /// Drop an index
    func dropIndex(
        indexName: String,
        tableName: String,
        schema: String?
    ) async throws {
        try await databaseDriver.dropIndex(
            indexName: indexName,
            tableName: tableName,
            schema: schema
        )
    }

    // MARK: - Batch Operations with Transaction Support

    /// Execute multiple schema modifications in a transaction
    func executeModifications(
        tableName: String,
        schema: String?,
        modifications: SchemaModificationTracker
    ) async throws {
        // Validate modifications first
        let validationErrors = modifications.validateModifications()
        guard validationErrors.isEmpty else {
            throw DatabaseError.operationFailed(
                "Validation failed: \(validationErrors.joined(separator: ", "))"
            )
        }

        // Begin transaction
        try await databaseDriver.executeRawQuery("BEGIN", databaseSchema: schema)

        do {
            // Execute modifications in dependency order

            // 1. Drop constraints first (if needed)
            // Note: Constraints are handled within column/index operations

            // 2. Drop columns
            for modification in modifications.columnDeletions {
                guard let columnName = modification.columnName else { continue }
                try await dropColumn(from: tableName, schema: schema, columnName: columnName)
            }

            // 3. Drop indexes
            for modification in modifications.indexDeletions {
                guard let indexName = modification.indexName else { continue }
                try await dropIndex(indexName: indexName, tableName: tableName, schema: schema)
            }

            // 4. Add columns
            for modification in modifications.columnAdditions {
                guard let column = modification.column else { continue }
                try await addColumn(to: tableName, schema: schema, column: column)
            }

            // 5. Modify columns
            for modification in modifications.columnUpdates {
                guard let columnName = modification.columnName,
                      let newColumn = modification.column else { continue }
                try await modifyColumn(
                    in: tableName,
                    schema: schema,
                    columnName: columnName,
                    newColumn: newColumn
                )
            }

            // 6. Modify indexes (drop old, create new - indexes can't be modified in place)
            for modification in modifications.indexUpdates {
                guard let originalIndex = modification.originalIndex,
                      let newIndex = modification.index else { continue }
                // Drop the old index first
                try await dropIndex(indexName: originalIndex.name, tableName: tableName, schema: schema)
                // Create the new index
                try await createIndex(on: tableName, schema: schema, index: newIndex)
            }

            // 7. Create indexes
            for modification in modifications.indexAdditions {
                guard let index = modification.index else { continue }
                try await createIndex(on: tableName, schema: schema, index: index)
            }

            // Commit transaction
            try await databaseDriver.executeRawQuery("COMMIT", databaseSchema: schema)

            // Clear schema cache after successful modifications
            await databaseDriver.clearSchemaCache(for: tableName, schema: schema)

        } catch {
            // Rollback on any error
            try await databaseDriver.executeRawQuery("ROLLBACK", databaseSchema: schema)
            throw error
        }
    }

    // MARK: - Schema Refresh

    /// Refresh schema information after modifications
    func refreshSchema(
        for tableName: String,
        schema: String?
    ) async throws -> DatabaseSchemaResult? {
        return try await databaseDriver.getSchema(for: tableName, schema: schema)
    }

    /// Refresh index information after modifications
    func refreshIndexes(
        for tableName: String,
        schema: String?
    ) async throws -> [DatabaseIndexInfo] {
        return try await databaseDriver.getIndexes(for: tableName, schema: schema)
    }
}
