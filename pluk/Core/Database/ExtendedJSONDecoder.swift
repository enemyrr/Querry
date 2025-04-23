//
//  ExtendedJSONDecoder.swift
//  Pluk
//
//  Created by Fauzaan on 4/5/25.
//

import Foundation
import NIOCore
import BSON
import MongoKitten

/// Facilitates the decoding of ExtendedJSON values into BSON Document objects.
struct ExtendedJSONDecoder {
    internal static var extJSONDateFormatterSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    internal static var extJSONDateFormatterMilliseconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    /// Decodes a Document directly from Extended JSON data
    /// - Parameter data: The JSON data in Extended JSON format
    /// - Returns: A BSON Document
    /// - Throws: Error if JSON cannot be parsed or is invalid Extended JSON
    public func decodeDocument(from data: Data) throws -> Document {
        let decoder = JSONDecoder(data: data)
        let json = try decoder.jsonKeyValuePairs()
        return try convertJSONToDocument(json, keyPath: [])
    }
    
    private func convertJSONToDocument(_ jsonData: [(key: String, value: Any)], keyPath: [String] = []) throws -> Document {
        // Create a new document
        var document = Document()
        
        // Process each key-value pair in the ordered array
        for (key, value) in jsonData {
            document[key] = try convertToPrimitive(value, keyPath: keyPath + [key])
        }
        
        return document
    }
    
    /// Converts Swift type to BSON Primitive
    /// - Parameters:
    ///   - value: The Swift value to convert
    ///   - keyPath: The current path in the JSON structure (for error reporting)
    /// - Returns: A BSON Primitive
    /// - Throws: DecodingError if conversion fails
    /// Converts Swift type to BSON Primitive
    /// - Parameters:
    ///   - value: The Swift value to convert
    ///   - keyPath: The current path in the JSON structure (for error reporting)
    /// - Returns: A BSON Primitive
    /// - Throws: DecodingError if conversion fails
    private func convertToPrimitive(_ value: Any, keyPath: [String]) throws -> Primitive {
        switch value {
        case is NSNull:
            return Null()
            
        case let stringValue as String:
            return stringValue
            
        case let boolValue as Bool:
            return boolValue
            
        case let intValue as UInt64:
            if intValue <= UInt64(Int32.max) {
                return Int32(intValue)
            } else if intValue <= UInt64(Int64.max) {
                #if (arch(i386) || arch(arm)) && BSONInt64Primitive
                // Int64 conforms to Primitive here
                return Int64(intValue)
                #else
                // Int conforms to Primitive, but Int64 doesn't
                if intValue <= UInt64(Int.max) {
                    return Int(intValue)
                } else {
                    return Int.max // Or handle overflow differently
                }
                #endif
            } else {
                #if (arch(i386) || arch(arm)) && BSONInt64Primitive
                return Int64.max
                #else
                return Int.max
                #endif
            }
            
        case let doubleValue as Double:
            return doubleValue
            
        case let tupleArray as [(key: String, value: Any)]:
            return try convertJSONToDocument(tupleArray, keyPath: keyPath)
            
        case let dictionary as [String: Any]:
            // Regular document - convert to array of tuples to maintain consistency
            let tuples = dictionary.map { (key: $0.key, value: $0.value) }
            return try convertJSONToDocument(tuples, keyPath: keyPath)
            
        case let arrayValue as [Any]:
            // Process array elements into a BSON array
            var bsonArray = [] as Document
            for (index, element) in arrayValue.enumerated() {
                let key = "\(index)" // BSON arrays use string indices as keys
                bsonArray[key] = try convertToPrimitive(element, keyPath: keyPath + [key])
            }
            return bsonArray
            
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: keyPath.map { AnyCodingKey(stringValue: $0)! },
                    debugDescription: "Unsupported type: \(type(of: value))"
                )
            )
        }
    }
}


// Extension to Document to add fromJSON initializer
extension Document {
    /// Initialize a Document from Extended JSON
    /// - Parameter json: The JSON data in Extended JSON format
    /// - Throws: Error if JSON cannot be parsed or is invalid Extended JSON
    public init(fromJSON json: Data) throws {
        let decoder = ExtendedJSONDecoder()
        let document = try decoder.decodeDocument(from: json)
        self = document
    }
    
    /// Initialize a Document from Extended JSON string
    /// - Parameter jsonString: The JSON string in Extended JSON format
    /// - Throws: Error if JSON cannot be parsed or is invalid Extended JSON
    public init(fromJSON jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Failed to convert JSON string to data"
                )
            )
        }
        try self.init(fromJSON: data)
    }
}

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
