//
//  QueryOperators.swift
//  Pluk
//
//  Created by Fauzaan on 4/15/25.
//

import Foundation
import MongoKitten

struct MongoKittenQueryHandler {
    
    /// Main entry point for handling MongoDB Extended JSON and query operators
    /// - Parameters:
    ///   - key: The operator or type key (e.g., "$numberInt", "$eq")
    ///   - value: The value associated with the key
    ///   - keyPath: The current path in the document
    /// - Returns: A BSON Primitive representing the parsed value
    static func handleExtendedJSON(key: String, value: Any, keyPath: [String]) -> Primitive {
        // If this is a query operator and the value contains Extended JSON
       if key.hasPrefix("$") && !isExtendedJSONType(key) {
           // Handle value as potentially containing Extended JSON
           return convertQueryValue(value)
       }
        
        // First try handling as a standard Extended JSON data type
        if let extendedJSONResult = handleExtendedJSONDataType(key: key, value: value, keyPath: keyPath) {
            return extendedJSONResult
        }
        
        // If not a data type, handle all query operators directly - MongoKitten uses raw operators
        return convertValueToBSON(value)
    }
    
    static func convertQueryValue(_ value: Any) -> Primitive {
        // If the value is a dictionary that might contain Extended JSON types
        if let dict = value as? [String: Any], dict.count == 1, let (key, subValue) = dict.first, key.hasPrefix("$") {
            if isExtendedJSONType(key) {
                // This is an Extended JSON type within a query operator
                if let result = handleExtendedJSONDataType(key: key, value: subValue, keyPath: []) {
                    return result
                }
            }
        } else if let dict = value as? [String: Any] {
            // Process each value in the dictionary to convert any Extended JSON
            var processedDict = Document()
            for (key, subValue) in dict {
                processedDict[key] = convertQueryValue(subValue)
            }
            return processedDict
        } else if let tupleArray = value as? [(key: String, value: Any)], tupleArray.count == 1,
                  let first = tupleArray.first, first.key.hasPrefix("$"), isExtendedJSONType(first.key) {
            // Handle tuple array that represents an Extended JSON type
            if let result = handleExtendedJSONDataType(key: first.key, value: first.value, keyPath: []) {
                return result
            }
        } else if let array = value as? [Any] {
            // Process each element in the array
            var processedArray = Document()
            for (i, element) in array.enumerated() {
                processedArray["\(i)"] = convertQueryValue(element)
            }
            return processedArray
        }
        
        // Default conversion
        return convertValueToBSON(value)
    }
    
    static func handleQueryOperator(key: String, value: Any, keyPath: [String]) -> Primitive? {
        // Process operators by category
        if let result = handleComparisonOperator(key: key, value: value) {
            return result
        }
        
        if let result = handleLogicalOperator(key: key, value: value) {
            return result
        }
        
        if let result = handleElementOperator(key: key, value: value) {
            return result
        }
        
        if let result = handleArrayOperator(key: key, value: value) {
            return result
        }
        
        if let result = handleEvaluationOperator(key: key, value: value) {
            return result
        }
        
        if let result = handleGeospatialOperator(key: key, value: value) {
            return result
        }
        
        if let result = handleBitwiseOperator(key: key, value: value) {
            return result
        }
        
        if isAggregationOperator(key) {
            return handleAggregationOperator(key: key, value: value)
        }
        
        // No matching operator found
        return nil
    }
    
    static func isExtendedJSONType(_ key: String) -> Bool {
        let extendedJSONTypes = [
            "$numberInt", "$numberLong", "$numberDouble", "$numberDecimal",
            "$oid", "$date", "$timestamp", "$binary", "$regex",
            "$minKey", "$maxKey", "$code", "$undefined", "$symbol"
        ]
        return extendedJSONTypes.contains(key)
    }
    
    // MARK: - Comparison Operators
    
    static func handleComparisonOperator(key: String, value: Any) -> Primitive? {
        switch key {
        case "$eq", "$ne", "$gt", "$gte", "$lt", "$lte":
            // For simple comparison operators, just return the value directly
            return convertValueToBSON(value)
            
        case "$in", "$nin":
            if let array = value as? [Any] {
                // Convert array to BSON array document
                var values = Document()
                for (i, val) in array.enumerated() {
                    values["\(i)"] = convertValueToBSON(val)
                }
                return values
            }
            
        default:
            return nil
        }
        
        return nil
    }
    
    // MARK: - Logical Operators
    
    static func handleLogicalOperator(key: String, value: Any) -> Primitive? {
        var opDoc = Document()
        opDoc["type"] = "logicalOperator"
        opDoc["operator"] = key
        
        switch key {
        case "$and", "$or", "$nor":
            if let array = value as? [Any] {
                var expressions = Document()
                for (i, expr) in array.enumerated() {
                    expressions["\(i)"] = convertValueToBSON(expr)
                }
                opDoc["expressions"] = expressions
                return opDoc
            }
        case "$not":
            opDoc["expression"] = convertValueToBSON(value)
            return opDoc
        default:
            return nil
        }
        
        return nil
    }
    
    // MARK: - Element Operators
    
    static func handleElementOperator(key: String, value: Any) -> Primitive? {
        var opDoc = Document()
        opDoc["type"] = "elementOperator"
        opDoc["operator"] = key
        
        switch key {
        case "$exists":
            if let boolValue = value as? Bool {
                opDoc["value"] = boolValue
                return opDoc
            }
        case "$type":
            if let typeValue = value as? String {
                opDoc["typeValue"] = typeValue
                return opDoc
            } else if let typeArray = value as? [String] {
                var types = Document()
                for (i, type) in typeArray.enumerated() {
                    types["\(i)"] = type
                }
                opDoc["typeValues"] = types
                return opDoc
            } else if let typeCode = value as? Int {
                opDoc["typeCode"] = typeCode
                return opDoc
            }
        default:
            return nil
        }
        
        return nil
    }
    
    // MARK: - Array Operators
    
    static func handleArrayOperator(key: String, value: Any) -> Primitive? {
        var opDoc = Document()
        opDoc["type"] = "arrayOperator"
        opDoc["operator"] = key
        
        switch key {
        case "$all":
            if let array = value as? [Any] {
                var values = Document()
                for (i, val) in array.enumerated() {
                    values["\(i)"] = convertValueToBSON(val)
                }
                opDoc["values"] = values
                return opDoc
            }
        case "$elemMatch":
            opDoc["condition"] = convertValueToBSON(value)
            return opDoc
        case "$size":
            if let sizeValue = value as? Int {
                opDoc["value"] = sizeValue
                return opDoc
            }
        default:
            return nil
        }
        
        return nil
    }
    
    // MARK: - Evaluation Operators
    
    static func handleEvaluationOperator(key: String, value: Any) -> Primitive? {
        var opDoc = Document()
        opDoc["type"] = "evaluationOperator"
        opDoc["operator"] = key
        
        switch key {
        case "$expr":
            opDoc["expression"] = convertValueToBSON(value)
            return opDoc
        case "$jsonSchema":
            opDoc["schema"] = convertValueToBSON(value)
            return opDoc
        case "$text":
            if let textSearch = value as? Document {
                opDoc["search"] = textSearch
            } else {
                opDoc["search"] = convertValueToBSON(value)
            }
            return opDoc
        case "$where":
            if let whereString = value as? String {
                return JavaScriptCode(whereString) // Return directly as JavaScript code
            }
            opDoc["expression"] = convertValueToBSON(value)
            return opDoc
        case "$regex":
            if let regexString = value as? String {
                return RegularExpression(pattern: regexString, options: "")
            } else if let regexDoc = value as? Document,
                      let pattern = regexDoc["pattern"] as? String,
                      let options = regexDoc["options"] as? String {
                return RegularExpression(pattern: pattern, options: options)
            }
        case "$options":
            // This is handled alongside $regex and shouldn't appear standalone
            opDoc["regexOptions"] = value as? String
            return opDoc
        default:
            return nil
        }
        
        return nil
    }
    
    // MARK: - Geospatial Operators
    
    static func handleGeospatialOperator(key: String, value: Any) -> Primitive? {
        var opDoc = Document()
        opDoc["type"] = "geospatialOperator"
        opDoc["operator"] = key
        
        switch key {
        case "$geoWithin", "$geoIntersects":
            opDoc["geometry"] = convertValueToBSON(value)
            return opDoc
        case "$near", "$nearSphere":
            opDoc["point"] = convertValueToBSON(value)
            
            // Extract additional parameters if they exist
            if let geoDoc = value as? Document {
                if let maxDistance = geoDoc["$maxDistance"] {
                    opDoc["maxDistance"] = maxDistance
                }
                if let minDistance = geoDoc["$minDistance"] {
                    opDoc["minDistance"] = minDistance
                }
            }
            return opDoc
        default:
            return nil
        }
    }
    
    // MARK: - Bitwise Operators
    
    static func handleBitwiseOperator(key: String, value: Any) -> Primitive? {
        var opDoc = Document()
        opDoc["type"] = "bitwiseOperator"
        opDoc["operator"] = key
        
        switch key {
        case "$bitsAllSet", "$bitsAnySet", "$bitsAllClear", "$bitsAnyClear":
            opDoc["value"] = convertValueToBSON(value)
            return opDoc
        default:
            return nil
        }
    }
    
    // MARK: - Aggregation Operators
    
    static func handleAggregationOperator(key: String, value: Any) -> Primitive {
        var opDoc = Document()
        opDoc["type"] = "aggregationOperator"
        opDoc["operator"] = key
        opDoc["value"] = convertValueToBSON(value)
        return opDoc
    }
    
    // MARK: - Helper Functions
    
    static func isAggregationOperator(_ key: String) -> Bool {
        let aggregationOperators = Set<String>([
            "$match", "$project", "$group", "$sort", "$limit", "$skip",
            "$unwind", "$lookup", "$out", "$addFields", "$count",
            "$facet", "$bucket", "$bucketAuto", "$unionWith"
        ])
        return aggregationOperators.contains(key)
    }
    
    static func toInt32(_ value: Any) -> Int32? {
        if let int32 = value as? Int32 {
            return int32
        } else if let int64 = value as? Int64 {
            return Int32(truncatingIfNeeded: int64)
        } else if let int = value as? Int {
            return Int32(truncatingIfNeeded: int)
        } else if let string = value as? String, let int = Int32(string) {
            return int
        } else if let double = value as? Double {
            return Int32(double)
        }
        return nil
    }
    
    static func getBinarySubType(from code: UInt8) -> Binary.SubType {
        switch code {
        case 0x00: return .generic
        case 0x01: return .function
        case 0x04: return .uuid
        case 0x05: return .md5
        default: return .userDefined(code)
        }
    }
    
    static func convertValueToBSON(_ value: Any) -> Primitive {
        switch value {
        case let str as String:
            return str
        case let num as NSNumber:
            // Handle numeric types based on the specific number type
            let type = CFNumberGetType(num as CFNumber)
            switch type {
            case .charType, .shortType, .intType:
                return Int32(num.intValue)
            case .longType, .longLongType:
                #if (arch(i386) || arch(arm)) && BSONInt64Primitive
                return Int64(num.int64Value)
                #else
                if num.int64Value <= Int64(Int.max) {
                    return Int(num.int64Value)
                } else {
                    return Int.max // Or handle overflow
                }
                #endif
            case .floatType, .float32Type, .float64Type, .doubleType:
                return num.doubleValue
            default:
                return num.doubleValue
            }
        case let bool as Bool:
            return bool
        case let array as [Any]:
            var doc = Document()
            for (i, item) in array.enumerated() {
                doc["\(i)"] = convertValueToBSON(item)
            }
            return doc
        case let dict as [String: Any]:
            var doc = Document()
            for (key, val) in dict {
                doc[key] = convertValueToBSON(val)
            }
            return doc
        case let doc as Document:
            return doc
        case is NSNull:
            return Null()
        default:
            return "\(value)" // Default to string representation
        }
    }
    
    
    static func handleExtendedJSONDataType(key: String, value: Any, keyPath: [String]) -> Primitive? {
        switch key {
        case "$numberInt", "$numberLong":
            if let stringValue = value as? String {
                if let intValue = Int32(stringValue) {
                    return intValue
                }
            }
            
        case "$numberDouble":
            if let stringValue = value as? String, let doubleValue = Double(stringValue) {
                return doubleValue
            }
            
        case "$oid":
            if let stringValue = value as? String, let objectId = ObjectId(stringValue) {
                return objectId
            }
            
        case "$date":
            if let dateString = value as? String {
                // First try with milliseconds precision
                if let date = ExtendedJSONDecoder.extJSONDateFormatterMilliseconds.date(from: dateString) {
                    return date
                }
                // Then try with seconds precision
                else if let date = ExtendedJSONDecoder.extJSONDateFormatterSeconds.date(from: dateString) {
                    return date
                }
            }
            // Handle nested $numberLong in $date
            else if let tupleArray = value as? [(key: String, value: Any)],
                    tupleArray.count == 1,
                    let first = tupleArray.first,
                    first.key == "$numberLong",
                    let millisString = first.value as? String,
                    let millis = Int64(millisString) {
                return Date(timeIntervalSince1970: Double(millis) / 1000)
            }
            
        case "$timestamp":
            if let timestampDoc = value as? Document {
                if let t = timestampDoc["t"] as? Int32,
                   let i = timestampDoc["i"] as? Int32 {
                    return Timestamp(increment: i, timestamp: t)
                }
            }
            
        case "$binary":
            if let tupleArray = value as? [(key: String, value: Any)] {
                var base64String: String? = nil
                var subTypeString: String? = nil
                
                for (subKey, subValue) in tupleArray {
                    if subKey == "base64", let str = subValue as? String {
                        base64String = str
                    } else if subKey == "subType", let str = subValue as? String {
                        subTypeString = str
                    }
                }
                
                if let base64 = base64String,
                   let subTypeHex = subTypeString,
                   let subTypeInt = UInt8(subTypeHex, radix: 16),
                   let data = Data(base64Encoded: base64) {
                    
                    // Create a ByteBuffer
                    let allocator = ByteBufferAllocator()
                    var buffer = allocator.buffer(capacity: data.count)
                    buffer.writeBytes(data)
                    
                    // Create SubType enum value
                    let subType: Binary.SubType
                    switch subTypeInt {
                    case 0x00: subType = .generic
                    case 0x01: subType = .function
                    case 0x04: subType = .uuid
                    case 0x05: subType = .md5
                    default: subType = .userDefined(subTypeInt)
                    }
                    
                    return Binary(subType: subType, buffer: buffer)
                }
            }
            
        case "$undefined":
            return Null()
            
        case "$regex":
            if let tupleArray = value as? [(key: String, value: Any)] {
                var pattern: String? = nil
                var options: String? = nil
                
                for (subKey, subValue) in tupleArray {
                    if subKey == "pattern", let str = subValue as? String {
                        pattern = str
                    } else if subKey == "options", let str = subValue as? String {
                        options = str
                    }
                }
                
                if let pat = pattern, let opt = options {
                    return RegularExpression(pattern: pat, options: opt)
                }
            }
            
        case "$minKey":
            return MinKey()
            
        case "$maxKey":
            return MaxKey()
            
        case "$code":
            if let codeString = value as? String {
                return JavaScriptCode(codeString)
            }
            
        default:
            break
        }
        
        return nil
    }
}
