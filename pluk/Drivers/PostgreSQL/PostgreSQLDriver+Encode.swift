//
//  PostgreSQLDriver+Encode.swift
//  Pluk
//
//  Created by Fauzaan on 7/4/25.
//
import PostgresNIO
import Foundation

extension PostgreSQLDriver {
    /// Generates a SET clause with proper type casting for PostgreSQL data types
    func buildSetClause(for columnName: String, parameterIndex: Int, columnType: PostgresDataType, enumTypeName: String? = nil) -> String {
        switch columnType {
        case .jsonb:
            return "\"\(columnName)\" = $\(parameterIndex)::jsonb"
        case .json:
            return "\"\(columnName)\" = $\(parameterIndex)::json"
        case .money:
            return "\"\(columnName)\" = $\(parameterIndex)::money"
        case .numeric:
            return "\"\(columnName)\" = $\(parameterIndex)::numeric"
        case .uuid:
            return "\"\(columnName)\" = $\(parameterIndex)::uuid"
        case .time:
            return "\"\(columnName)\" = $\(parameterIndex)::time"
        case .timestamp:
            return "\"\(columnName)\" = $\(parameterIndex)::timestamp"
        case .timestamptz:
            return "\"\(columnName)\" = $\(parameterIndex)::timestamptz"
        case .date:
            return "\"\(columnName)\" = $\(parameterIndex)::date"
        case .xml:
            return "\"\(columnName)\" = $\(parameterIndex)::xml"
        case .bytea:
            return "\"\(columnName)\" = $\(parameterIndex)::bytea"
        default:
            if columnType.isUserDefined {
                // For enums and other user-defined types, we need to cast to the specific type
                if let enumTypeName = enumTypeName {
                    return "\"\(columnName)\" = $\(parameterIndex)::\(enumTypeName)"
                } else {
                    // Fallback if enum type name is not provided
                    return "\"\(columnName)\" = $\(parameterIndex)"
                }
            } else {
                return "\"\(columnName)\" = $\(parameterIndex)"
            }
        }
    }
    
    func encode(_ value: Any, columnName: String, columnType: PostgresDataType) throws -> PostgresEncodable? {
        guard let stringValue = value as? String else {
            throw DatabaseError.operationFailed("Expected string value for column \(columnName)")
        }
        
        let cleanedValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanedValue.isEmpty else {
            return nil
        }
        
        switch columnType {
        case .bool:
            let lowercased = cleanedValue.lowercased()
            if ["true", "1", "yes", "on"].contains(lowercased) {
                return true
            } else if ["false", "0", "no", "off"].contains(lowercased) {
                return false
            } else {
                throw DatabaseError.operationFailed("Cannot convert '\(stringValue)' to boolean for column \(columnName)")
            }
            
        case .int2:
            guard let intValue = Int16(cleanedValue) else {
                throw DatabaseError.operationFailed("Cannot convert '\(stringValue)' to Int16 for column \(columnName)")
            }
            return intValue
            
        case .int4:
            guard let intValue = Int32(cleanedValue) else {
                throw DatabaseError.operationFailed("Cannot convert '\(stringValue)' to Int32 for column \(columnName)")
            }
            return intValue
            
        case .int8:
            guard let intValue = Int64(cleanedValue) else {
                throw DatabaseError.operationFailed("Cannot convert '\(stringValue)' to Int64 for column \(columnName)")
            }
            return intValue
            
        case .float4:
            guard let floatValue = Float(cleanedValue) else {
                throw DatabaseError.operationFailed("Cannot convert '\(stringValue)' to Float for column \(columnName)")
            }
            return floatValue
            
        case .float8, .numeric:
            guard let doubleValue = Double(cleanedValue) else {
                throw DatabaseError.operationFailed("Cannot convert '\(stringValue)' to Double for column \(columnName)")
            }
            return doubleValue
            
        case .uuid:
            guard let uuidValue = UUID(uuidString: cleanedValue) else {
                throw DatabaseError.operationFailed("Cannot convert '\(stringValue)' to UUID for column \(columnName)")
            }
            return uuidValue
    
        case .date:
            let date = try cleanedValue.toDate()
            return date
            
        case .timestamp:
            let normalizedDateString = try cleanedValue.toPostgreSQLDate()
            return normalizedDateString
        case .timestamp:
            let normalizedDateString = try cleanedValue.toPostgreSQLTimestampTZ()
            return normalizedDateString.date
        case .jsonb:
            // Your existing JSONB cleaning logic
            var cleanedString = cleanedValue
            
            while let firstChar = cleanedString.first, firstChar.asciiValue != nil && firstChar.asciiValue! < 32 {
                cleanedString = String(cleanedString.dropFirst())
            }
            
            while let lastChar = cleanedString.last, lastChar.asciiValue != nil && lastChar.asciiValue! < 32 {
                cleanedString = String(cleanedString.dropLast())
            }
            
            if cleanedString.hasPrefix("\"") && cleanedString.hasSuffix("\"") {
                cleanedString = String(cleanedString.dropFirst().dropLast())
            }
            
            if cleanedString.contains("\\\"") {
                cleanedString = cleanedString.replacingOccurrences(of: "\\\"", with: "\"")
            }
            
            return cleanedString
        
        case .anyenum:
            return cleanedValue
        case .json:
            return cleanedValue
            
        case .money:
            var cleanValue = cleanedValue
            cleanValue = cleanValue.replacingOccurrences(of: "$", with: "")
            cleanValue = cleanValue.replacingOccurrences(of: ",", with: "")
            cleanValue = cleanValue.replacingOccurrences(of: "€", with: "")
            cleanValue = cleanValue.replacingOccurrences(of: "£", with: "")
            
            guard let doubleValue = Double(cleanValue) else {
                throw DatabaseError.operationFailed("Cannot convert '\(stringValue)' to money value for column \(columnName)")
            }
            
            return String(format: "%.2f", doubleValue)
            
        case .text, .varchar, .bpchar:
            return cleanedValue
            
        default:
            return cleanedValue
        }
    }
}


extension String {
    func toDate() throws -> Date? {
        let formats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "dd/MM/yyyy",
            "dd-MM-yyyy",
            "dd.MM.yyyy",
            "MMM dd, yyyy",
            "MMMM dd, yyyy",
            "dd MMM yyyy",
            "dd MMMM yyyy",
            "EEEE, MMM dd, yyyy",
            "yyyy/MM/dd",
            "dd-MMM-yyyy",
            "MM/dd/yyyy HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "HH:mm:ss",
            "h:mm a",
            "MMM yyyy"
        ]
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: self) {
                return date
            }
        }
        
        throw DatabaseError.operationFailed("Unable to parse date string \(self)")
    }
}
