//
//  PostgreSQLDriver+Encode.swift
//  Pluk
//
//  Created by Fauzaan on 7/4/25.
//
import PostgresNIO
import Foundation

extension PostgreSQLDriver {
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
            
        case .date, .timestamp, .timestamptz:
            // Your existing date parsing logic with proper error handling
            var normalizedDateString = cleanedValue
            
            let timezonePattern = #"([+-])(\d{2})$"#
            if let regex = try? NSRegularExpression(pattern: timezonePattern, options: []) {
                let range = NSRange(location: 0, length: normalizedDateString.count)
                normalizedDateString = regex.stringByReplacingMatches(
                    in: normalizedDateString,
                    options: [],
                    range: range,
                    withTemplate: "$1$2:00"
                )
            }
            
            let dateFormatters: [Any] = [
                ISO8601DateFormatter(),
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ssXXX"
                    return formatter
                }(),
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    return formatter
                }(),
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    return formatter
                }()
            ]
            
            for formatter in dateFormatters {
                if let formatter = formatter as? ISO8601DateFormatter {
                    if let date = formatter.date(from: normalizedDateString) {
                        return date
                    }
                } else if let formatter = formatter as? DateFormatter {
                    if let date = formatter.date(from: normalizedDateString) {
                        return date
                    }
                }
            }
            
            throw DatabaseError.operationFailed("Cannot convert '\(stringValue)' to Date for column \(columnName). Tried formats: ISO8601, yyyy-MM-dd HH:mm:ssXXX, yyyy-MM-dd HH:mm:ss, yyyy-MM-dd")
            
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

struct DynamicEnum: Equatable {
    let value: String
}

extension DynamicEnum: PostgresCodable {
    static var psqlType: PostgresDataType { .text }
    static var psqlFormat: PostgresFormat { .text }

    // Encoding
    func encode<JSONEncoder: PostgresJSONEncoder>(
        into buffer: inout ByteBuffer,
        context: PostgresEncodingContext<JSONEncoder>
    ) {
        buffer.writeString(value)
    }

    // Decoding
    init<JSONDecoder: PostgresJSONDecoder>(
        from byteBuffer: inout ByteBuffer,
        type: PostgresDataType,
        format: PostgresFormat,
        context: PostgresDecodingContext<JSONDecoder>
    ) throws {
        guard let string = byteBuffer.readString(length: byteBuffer.readableBytes) else {
            throw PostgresDecodingError.Code.typeMismatch
        }
        self.value = string
    }
}
