import Foundation

// MARK: - Convex Request Structure

struct ConvexRequest {
    let path: String
    let args: [String: Any]
    let format: String
    
    init(path: String, args: [String: Any] = [:], format: String = "json") {
        self.path = path
        self.args = args
        self.format = format
    }
    
    func toJSONData() throws -> Data {
        let requestBody: [String: Any] = [
            "path": path,
            "args": args,
            "format": format
        ]
        
        return try JSONSerialization.data(withJSONObject: requestBody)
    }
}

// MARK: - Convex Pagination

struct ConvexPagination: Codable {
    let numItems: Int
    let cursor: String?
    
    init(numItems: Int = 100, cursor: String? = nil) {
        self.numItems = numItems
        self.cursor = cursor
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["numItems": numItems]
        if let cursor = cursor {
            dict["cursor"] = cursor
        } else {
            dict["cursor"] = NSNull()
        }
        return dict
    }
}

// MARK: - Specific Request Types

extension ConvexRequest {
    // System requests
    static func listTables(pagination: ConvexPagination = ConvexPagination()) -> ConvexRequest {
        return ConvexRequest(
            path: "_system/cli/tables",
            args: ["paginationOpts": pagination.toDictionary()]
        )
    }
    
    static func getSchemas() -> ConvexRequest {
        return ConvexRequest(
            path: "_system/frontend/getSchemas",
            args: [:]
        )
    }
    
    static func tableData(table: String, order: String = "asc", pagination: ConvexPagination = ConvexPagination()) -> ConvexRequest {
        return ConvexRequest(
            path: "_system/cli/tableData",
            args: [
                "table": table,
                "order": order,
                "paginationOpts": pagination.toDictionary()
            ]
        )
    }
    
    // Custom query request
    static func query(path: String, args: [String: Any] = [:]) -> ConvexRequest {
        return ConvexRequest(path: path, args: args)
    }
}