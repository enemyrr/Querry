//
//  MySQLDriver+Encode.swift
//  Pluk
//
//  Created by Fauzaan on 21/8/25.
//

import Foundation
import MySQLNIO
import NIOCore

extension MySQLDriver {
    /// Helper method to convert Swift types to MySQL bindable values
    func convertToMySQLBindable(_ value: Any) -> MySQLData {
        switch value {
        case let stringValue as String:
            return MySQLData(string: stringValue)
        case let intValue as Int:
            return MySQLData(int: intValue)
        case let doubleValue as Double:
            return MySQLData(double: doubleValue)
        case let floatValue as Float:
            return MySQLData(float: floatValue)
        case let boolValue as Bool:
            return MySQLData(bool: boolValue)
        case let dateValue as Date:
            return MySQLData(date: dateValue)
        case let mysqlData as MySQLData:
            // Create a fresh MySQLData with a fresh buffer
            if let originalBuffer = mysqlData.buffer {
                // Create a new buffer with the original data
                var freshBuffer = ByteBufferAllocator().buffer(capacity: originalBuffer.readableBytes)
                freshBuffer.writeImmutableBuffer(originalBuffer)
                return MySQLData(
                    type: mysqlData.type,
                    format: mysqlData.format,
                    buffer: freshBuffer,
                    isUnsigned: mysqlData.isUnsigned
                )
            } else {
                // Handle null case
                return MySQLData.null
            }
        case is NSNull:
            return MySQLData.null
        default:
            return MySQLData(string: String(describing: value))
        }
    }
}
