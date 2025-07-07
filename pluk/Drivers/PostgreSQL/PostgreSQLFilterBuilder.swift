import Foundation

// MARK: - Filter Models
enum FilterConjunction: String, CaseIterable {
    case whereClause = "where"
    case and = "and"
    case or = "or"
}

enum FilterOperator: String, CaseIterable {
    case equals = "equals"
    case notEquals = "not equals"
    case contains = "contains"
    case startsWith = "starts with"
    case endsWith = "ends with"
    case greaterThan = "greater than"
    case lessThan = "less than"
}

struct FilterCondition {
    var conjunction: FilterConjunction
    var field: String
    var filterOperator: FilterOperator
    var value: String
}

// MARK: - PostgreSQL Filter Builder Extension
extension PostgreSQLDriver {
    
    /// Generates a complete PostgreSQL SELECT query from filter conditions
    /// - Parameters:
    ///   - conditions: Array of filter conditions
    ///   - tableName: Name of the table to query
    /// - Returns: Complete SQL query string
    func generateFilterQuery(from conditions: [FilterCondition], tableName: String) -> String {
        let validConditions = conditions.filter { condition in
            !condition.field.isEmpty && !condition.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        guard !validConditions.isEmpty else { return "" }
        
        var sql = "SELECT * FROM \"\(tableName)\" "
        
        for (index, condition) in validConditions.enumerated() {
            if index == 0 {
                sql += "WHERE "
            } else {
                sql += " \(condition.conjunction.rawValue.uppercased()) "
            }
            
            let escapedField = "\"\(condition.field)\""
            let escapedValue = "'\(condition.value.replacingOccurrences(of: "'", with: "''"))'"
            
            switch condition.filterOperator {
            case .equals:
                sql += "\(escapedField) = \(escapedValue)"
            case .notEquals:
                sql += "\(escapedField) != \(escapedValue)"
            case .contains:
                sql += "\(escapedField) ILIKE '%\(condition.value.replacingOccurrences(of: "'", with: "''"))%'"
            case .startsWith:
                sql += "\(escapedField) ILIKE '\(condition.value.replacingOccurrences(of: "'", with: "''"))%'"
            case .endsWith:
                sql += "\(escapedField) ILIKE '%\(condition.value.replacingOccurrences(of: "'", with: "''"))'"
            case .greaterThan:
                sql += "\(escapedField) > \(escapedValue)"
            case .lessThan:
                sql += "\(escapedField) < \(escapedValue)"
            }
        }
        
        return sql
    }
}