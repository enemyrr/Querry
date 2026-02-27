import Foundation

@MainActor
enum ToolMetadata {

    static func groupKey(for toolName: String) -> String {
        switch toolName {
        case "create_chart_block", "create_text_block", "create_single_value_block": return "create_block"
        default: return toolName
        }
    }

    static func pillIcon(for toolName: String) -> String {
        switch toolName {
        case "run_query": return "magnifyingglass"
        default: return icon(for: toolName)
        }
    }

    static func icon(for toolName: String) -> String {
        switch toolName {
        case "list_tables": return "tablecells"
        case "get_table_schema": return "square.stack.3d.up"
        case "run_query": return "rectangle.and.text.magnifyingglass"
        case "create_chart_block": return "chart.bar"
        case "create_single_value_block": return "numbers.rectangle"
        case "create_text_block": return "text.append"
        case "create_block": return "chart.bar"
        default: return "gearshape"
        }
    }

    static func groupHeader(for toolName: String) -> String {
        switch toolName {
        case "list_tables": return "Exploring database"
        case "get_table_schema": return "Reading schema"
        case "run_query": return "Querying data"
        case "create_chart_block", "create_text_block", "create_single_value_block", "create_block": return "Building visualizations"
        default: return "Processing"
        }
    }

    static func displayInfo(for name: String, arguments: String = "") -> (text: String, icon: String) {
        let json = parseToolArguments(arguments)

        switch name {
        case "list_tables":
            let schema = json["schema_name"] as? String
            let label = schema != nil ? "Listing tables in \(schema!)" : "Listing all tables"
            return (label, icon(for: name))

        case "get_table_schema":
            let table = json["table_name"] as? String
            let label = table != nil ? "Reading \(table!) schema" : "Reading table schema"
            return (label, icon(for: name))

        case "run_query":
            let query = json["query"] as? String ?? ""
            let preview = queryPreview(query)
            return (preview.isEmpty ? "Running query" : preview, icon(for: name))

        case "create_chart_block":
            let title = json["title"] as? String
            return (title ?? "Chart", icon(for: name))

        case "create_single_value_block":
            let title = json["title"] as? String
            return (title ?? "Single Value", icon(for: name))

        case "create_text_block":
            return ("Text block", icon(for: name))

        default:
            return (name.replacing("_", with: " ").capitalized, icon(for: name))
        }
    }

    // MARK: - Private

    private static func parseToolArguments(_ arguments: String) -> [String: Any] {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    private static func queryPreview(_ query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let oneLine = trimmed.replacing(/\s+/, with: " ")
        if oneLine.count <= 60 { return oneLine }
        return String(oneLine.prefix(57)) + "..."
    }
}
