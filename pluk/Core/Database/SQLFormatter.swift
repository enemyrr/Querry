//
//  SQLFormatter.swift
//  Pluk
//
//  Created by Claude on 1/3/25.
//

import Foundation
import JavaScriptCore

class SQLFormatter {
    private static let shared = SQLFormatter()
    private let jsContext: JSContext
    
    private init() {
        jsContext = JSContext()
        setupJavaScriptEnvironment()
    }
    
    private func setupJavaScriptEnvironment() {
        // Load the sql-formatter JavaScript library
        guard let jsPath = Bundle.main.path(forResource: "sql-formatter.min", ofType: "js"),
              let jsContent = try? String(contentsOfFile: jsPath, encoding: .utf8) else {
            print("Error: Could not load sql-formatter.min.js")
            return
        }
        
        // Evaluate the JavaScript library
        jsContext.evaluateScript(jsContent)
        
        // Add console.log for debugging (optional)
        let consoleFn: @convention(block) (String) -> Void = { message in
            print("JS: \(message)")
        }
        jsContext.setObject(consoleFn, forKeyedSubscript: "consoleFn" as NSString)
        jsContext.evaluateScript("console = { log: consoleFn }")
        
        // Verify sql-formatter is loaded
        let isLoaded = jsContext.evaluateScript("typeof sqlFormatter !== 'undefined'")
        print("SQL Formatter loaded: \(isLoaded?.toBool() ?? false)")
    }
    
    static func format(_ sql: String, dialect: SQLDialect = .sqlite, options: SQLFormatOptions = SQLFormatOptions()) -> String {
        return shared.formatSQL(sql, dialect: dialect, options: options)
    }
    
    private func formatSQL(_ sql: String, dialect: SQLDialect, options: SQLFormatOptions) -> String {
        // Escape the SQL string for JavaScript
        let escapedSQL = sql.replacingOccurrences(of: "\\", with: "\\\\")
                           .replacingOccurrences(of: "\"", with: "\\\"")
                           .replacingOccurrences(of: "\n", with: "\\n")
                           .replacingOccurrences(of: "\r", with: "\\r")
        
        // Build the options object
        let jsOptions = """
        {
            language: '\(dialect.rawValue)',
            tabWidth: \(options.tabWidth),
            useTabs: \(options.useTabs),
            keywordCase: '\(options.keywordCase.rawValue)',
            dataTypeCase: '\(options.dataTypeCase.rawValue)',
            functionCase: '\(options.functionCase.rawValue)',
            linesBetweenQueries: \(options.linesBetweenQueries)
        }
        """
        
        // Format the SQL using sql-formatter
        let jsCode = """
        (function() {
            try {
                return sqlFormatter.format("\(escapedSQL)", \(jsOptions));
            } catch (error) {
                console.log('Formatting error: ' + error.message);
                return "\(escapedSQL)";
            }
        })()
        """
        
        guard let result = jsContext.evaluateScript(jsCode),
              let formattedSQL = result.toString() else {
            print("Error: Failed to format SQL")
            return sql
        }
        
        return formattedSQL
    }
}

// MARK: - Configuration Types

enum SQLDialect: String, CaseIterable {
    case sqlite = "sqlite"
    case postgresql = "postgresql"
    case mysql = "mysql"
    case mariadb = "mariadb"
    case bigquery = "bigquery"
    case redshift = "redshift"
    case spark = "spark"
    case snowflake = "snowflake"
    case tsql = "tsql"
    case plsql = "plsql"
    case transactsql = "transactsql"
    case hive = "hive"
    case n1ql = "n1ql"
    case db2 = "db2"
    case singlestoredb = "singlestoredb"
}

enum TextCase: String {
    case preserve = "preserve"
    case upper = "upper"
    case lower = "lower"
}

struct SQLFormatOptions {
    let tabWidth: Int
    let useTabs: Bool
    let keywordCase: TextCase
    let dataTypeCase: TextCase
    let functionCase: TextCase
    let linesBetweenQueries: Int
    
    init(
        tabWidth: Int = 2,
        useTabs: Bool = false,
        keywordCase: TextCase = .upper,
        dataTypeCase: TextCase = .upper,
        functionCase: TextCase = .upper,
        linesBetweenQueries: Int = 1
    ) {
        self.tabWidth = tabWidth
        self.useTabs = useTabs
        self.keywordCase = keywordCase
        self.dataTypeCase = dataTypeCase
        self.functionCase = functionCase
        self.linesBetweenQueries = linesBetweenQueries
    }
}