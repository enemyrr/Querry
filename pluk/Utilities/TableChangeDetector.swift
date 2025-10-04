import Foundation

struct TableChangeDetector {
    private(set) var lastHash: Int?
    
    struct ChangeResult {
        let changedFields: Set<String>
        let changedRows: Set<Int>
        let changedCells: [Int: Set<String>] // rowIndex -> set of field names
        let isDifferent: Bool
    }
    
    mutating func detect(old oldResult: QueryResult?, new newResult: QueryResult) -> ChangeResult {
        let newHash = Self.calculateHash(for: newResult)
        let isDifferent = (newHash != lastHash)
        
        // If we have no previous data, everything is new
        guard let oldResult = oldResult else {
            lastHash = newHash
            let allFields = Set(newResult.columns.map { $0.name })
            let allRows = Set(0..<newResult.rawRows.count)
            var mapping: [Int: Set<String>] = [:]
            for (index, row) in newResult.rawRows.enumerated() {
                mapping[index] = Set(row.keys)
            }
            return ChangeResult(changedFields: allFields, changedRows: allRows, changedCells: mapping, isDifferent: true)
        }
        
        // If hash hasn't changed, we can early-out without computing diffs
        if !isDifferent {
            return ChangeResult(changedFields: [], changedRows: [], changedCells: [:], isDifferent: false)
        }
        
        var changedFields = Set<String>()
        var changedRows = Set<Int>()
        var changedCells: [Int: Set<String>] = [:]
        
        // Build old rows map by ID (fallback to index when missing)
        var oldRowsByID: [String: [String: Any?]] = [:]
        for (index, row) in oldResult.rawRows.enumerated() {
            if let id = row["_id"] as? String {
                oldRowsByID[id] = row
            } else {
                oldRowsByID["index_\(index)"] = row
            }
        }
        
        // Compare new against old
        for (index, row) in newResult.rawRows.enumerated() {
            let id = (row["_id"] as? String) ?? "index_\(index)"
            if let oldRow = oldRowsByID[id] {
                let allFieldNames = Set(oldRow.keys).union(Set(row.keys))
                var rowHasChanges = false
                var cellSet: Set<String> = []
                
                for fieldName in allFieldNames {
                    let oldValue = oldRow[fieldName]
                    let newValue = row[fieldName]
                    if let oldValue, let newValue = newValue {
                        if !Self.areValuesEqual(oldValue, newValue) {
                            changedFields.insert(fieldName)
                            rowHasChanges = true
                            cellSet.insert(fieldName)
                        }
                    } else if (oldValue == nil) != (newValue == nil) {
                        changedFields.insert(fieldName)
                        rowHasChanges = true
                        cellSet.insert(fieldName)
                    }
                }
                if rowHasChanges {
                    changedRows.insert(index)
                    changedCells[index] = cellSet
                }
            } else {
                // Entirely new row - consider all its fields changed
                changedRows.insert(index)
                let cellSet = Set(row.keys)
                changedCells[index] = cellSet
                changedFields.formUnion(cellSet)
            }
        }
        
        // Update the stored hash last
        lastHash = newHash
        return ChangeResult(changedFields: changedFields, changedRows: changedRows, changedCells: changedCells, isDifferent: true)
    }
    
    // Exclusive variant: ignore added/removed rows; highlight only value changes for IDs present in both
    mutating func detectExclusive(old oldResult: QueryResult?, new newResult: QueryResult) -> ChangeResult {
        let newHash = Self.calculateHash(for: newResult)
        let isDifferent = (newHash != lastHash)
        
        // If no previous baseline, set baseline and return no highlights
        guard let oldResult = oldResult else {
            lastHash = newHash
            return ChangeResult(changedFields: [], changedRows: [], changedCells: [:], isDifferent: true)
        }
        
        if !isDifferent {
            return ChangeResult(changedFields: [], changedRows: [], changedCells: [:], isDifferent: false)
        }
        
        // Build id maps
        var oldByID: [String: [String: Any?]] = [:]
        for row in oldResult.rawRows {
            if let id = row["_id"] as? String {
                oldByID[id] = row
            }
        }
        var newByID: [String: [String: Any?]] = [:]
        var newIndexByID: [String: Int] = [:]
        for (index, row) in newResult.rawRows.enumerated() {
            if let id = row["_id"] as? String {
                newByID[id] = row
                newIndexByID[id] = index
            }
        }
        
        let commonIDs = Set(oldByID.keys).intersection(Set(newByID.keys))
        var changedFields = Set<String>()
        var changedRows = Set<Int>()
        var changedCells: [Int: Set<String>] = [:]
        
        for id in commonIDs {
            guard let oldRow = oldByID[id], let newRow = newByID[id], let newIndex = newIndexByID[id] else { continue }
            let allFieldNames = Set(oldRow.keys).union(Set(newRow.keys))
            var rowHasChanges = false
            var cellSet: Set<String> = []
            for fieldName in allFieldNames {
                let oldValue = oldRow[fieldName]
                let newValue = newRow[fieldName]
                if let oldValue, let newValue = newValue {
                    if !Self.areValuesEqual(oldValue, newValue) {
                        changedFields.insert(fieldName)
                        rowHasChanges = true
                        cellSet.insert(fieldName)
                    }
                } else if (oldValue == nil) != (newValue == nil) {
                    changedFields.insert(fieldName)
                    rowHasChanges = true
                    cellSet.insert(fieldName)
                }
            }
            if rowHasChanges {
                changedRows.insert(newIndex)
                changedCells[newIndex] = cellSet
            }
        }
        
        lastHash = newHash
        return ChangeResult(changedFields: changedFields, changedRows: changedRows, changedCells: changedCells, isDifferent: true)
    }
    
    mutating func baseline(with result: QueryResult) {
        lastHash = Self.calculateHash(for: result)
    }
    
    static func calculateHash(for result: QueryResult) -> Int {
        var hasher = Hasher()
        hasher.combine(result.totalCount)
        for row in result.rawRows {
            for (key, value) in row.sorted(by: { $0.key < $1.key }) {
                hasher.combine(key)
                if let stringValue = value as? String {
                    hasher.combine(stringValue)
                } else if let numberValue = value as? NSNumber {
                    hasher.combine(numberValue.description)
                } else if let boolValue = value as? Bool {
                    hasher.combine(boolValue)
                } else if value == nil {
                    hasher.combine("null")
                } else {
                    hasher.combine(String(describing: value))
                }
            }
        }
        return hasher.finalize()
    }
    
    private static func areValuesEqual(_ value1: Any?, _ value2: Any?) -> Bool {
        if value1 == nil && value2 == nil { return true }
        if value1 == nil || value2 == nil { return false }
        return String(describing: value1!) == String(describing: value2!)
    }
}
