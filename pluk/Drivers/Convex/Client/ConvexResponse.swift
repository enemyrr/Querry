import Foundation

// MARK: - Convex Response Structure

struct ConvexResponse {
    let status: String?
    let value: Any?
    let error: String?
    let rawData: Data
    
    init(data: Data) throws {
        self.rawData = data
        
        // First check if we have any data
        guard !data.isEmpty else {
            throw ConvexError.invalidResponse("Empty response received")
        }
        
        // Try to parse as JSON with better error information
        let parsedJson: Any
        do {
            parsedJson = try JSONSerialization.jsonObject(with: data)
        } catch let jsonError {
            // Get string representation for debugging
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response as UTF-8"
            throw ConvexError.invalidResponse("Failed to parse JSON: \(jsonError.localizedDescription). Response: \(responseString)")
        }
        
        // Handle different response types
        if let jsonObject = parsedJson as? [String: Any] {
            // JSON object response
            self.status = jsonObject["status"] as? String
            self.error = jsonObject["error"] as? String
            
            // Handle different response formats
            if let status = self.status {
                // Response has status field - check for errors
                if status != "success" {
                    let errorMessage = error ?? "Unknown error occurred"
                    throw ConvexError.apiError(errorMessage, nil)
                }
                self.value = jsonObject["value"]
            } else {
                // No status field - treat the entire response as the value
                // This is common for API endpoints like token_details
                self.value = jsonObject
            }
        } else if let jsonArray = parsedJson as? [Any] {
            // JSON array response (e.g., list_deployments)
            self.status = nil
            self.error = nil
            self.value = jsonArray
        } else {
            // Other JSON types (string, number, etc.)
            self.status = nil
            self.error = nil
            self.value = parsedJson
        }
    }
    
    // Type-safe value extraction
    func getValue<T>() throws -> T {
        guard let value = value as? T else {
            throw ConvexError.decodingError("Expected value of type \(T.self), got \(type(of: value))")
        }
        return value
    }
    
    // Helper for common response patterns
    func getValueDictionary() throws -> [String: Any] {
        return try getValue()
    }
    
    func getValueArray() throws -> [Any] {
        return try getValue()
    }
    
    func getValueString() throws -> String {
        return try getValue()
    }
}

// MARK: - Specific Response Types

struct ConvexTablesResponse {
    let tables: [ConvexTableInfo]
    let continueCursor: String?
    let isDone: Bool
    
    init(response: ConvexResponse) throws {
        let valueDict = try response.getValueDictionary()
        
        guard let page = valueDict["page"] as? [[String: Any]] else {
            throw ConvexError.decodingError("Expected 'page' array in tables response")
        }
        
        self.tables = try page.map { tableDict in
            guard let tableName = tableDict["name"] as? String else {
                throw ConvexError.decodingError("Expected 'name' field in table info")
            }
            return ConvexTableInfo(name: tableName)
        }
        
        self.continueCursor = valueDict["continueCursor"] as? String
        self.isDone = valueDict["isDone"] as? Bool ?? true
    }
}

struct ConvexTableInfo {
    let name: String
}

struct ConvexTableDataResponse {
    let documents: [[String: Any]]
    let continueCursor: String?
    let isDone: Bool
    let totalCount: Int
    
    init(response: ConvexResponse) throws {
        let valueDict = try response.getValueDictionary()
        
        guard let page = valueDict["page"] as? [[String: Any]] else {
            throw ConvexError.decodingError("Expected 'page' array in table data response")
        }
        
        self.documents = page
        self.totalCount = page.count
        self.continueCursor = valueDict["continueCursor"] as? String
        self.isDone = valueDict["isDone"] as? Bool ?? true
    }
}

struct ConvexSchemasResponse {
    let schemas: ConvexSchemaInfo
    
    init(response: ConvexResponse) throws {
        let valueDict = try response.getValueDictionary()
        
        guard let activeSchema = valueDict["active"] as? String else {
            throw ConvexError.decodingError("Expected 'active' schema string")
        }
        
        guard let activeData = activeSchema.data(using: .utf8),
              let activeJson = try JSONSerialization.jsonObject(with: activeData) as? [String: Any],
              let tables = activeJson["tables"] as? [[String: Any]] else {
            throw ConvexError.decodingError("Failed to parse active schema JSON")
        }
        
        self.schemas = ConvexSchemaInfo(tables: tables)
    }
}

struct ConvexSchemaInfo {
    let tables: [[String: Any]]
    
    func findTable(named tableName: String) -> [String: Any]? {
        return tables.first { table in
            (table["tableName"] as? String) == tableName
        }
    }
}

// MARK: - Deployments
struct ConvexDeployment: Decodable {
    let name: String
    let createTime: Int64
    let deploymentType: String
    let projectId: Int64
    let previewIdentifier: String?
}
