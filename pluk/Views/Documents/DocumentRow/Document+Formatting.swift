//
//  DocumentFormatter.swift
//  Collection
//
//  Created by Fauzaan on 1/5/25.
//
import MongoKitten
import SwiftUI
import UInt128

struct FormattedPrimitive {
    let value: String
    let color: Color
    let isExpandable: Bool
    let type: String
}

extension Document {
    func formatValue(_ value: Primitive?) -> FormattedPrimitive {
        guard let value = value else {
            return FormattedPrimitive(
                value: "null",
                color: .gray,
                isExpandable: false,
                type: "Null"
            )
        }
        
        switch value {
        case let objectId as ObjectId:
            return FormattedPrimitive(
                value: "ObjectId(\"\(objectId.hexString)\")",
                color: .orange,
                isExpandable: false,
                type: "ObjectId"
            )
            
        case let array as [Primitive]:
            return FormattedPrimitive(
                value: "Array (\(array.count))",
                color: .secondary,
                isExpandable: !array.isEmpty,
                type: "Array"
            )
            
        case is Null:
            return FormattedPrimitive(
                value: "null",
                color: .gray,
                isExpandable: false,
                type: "Null"
            )
            
        case let value as Timestamp:
            return FormattedPrimitive(
                value: "\(value)",
                color: .purple,
                isExpandable: false,
                type: "Timestamp"
            )
            
        case let value as JavaScriptCode:
            return FormattedPrimitive(
                value: "\(value)",
                color: .cyan,
                isExpandable: false,
                type: "JavaScriptCode"
            )
            
        case let binary as Binary:
            if binary.subType == .uuid {
                return FormattedPrimitive(
                    value: extractUUIDFromBinary(binary)?.uuidString ?? "Invalid UUID",
                    color: .cyan,
                    isExpandable: false,
                    type: "Binary"
                )
            }
            
            return FormattedPrimitive(
                value: "Binary.createFromBase64(\(binary.data.base64EncodedString()),  \(binary.subType))",
                color: .cyan,
                isExpandable: false,
                type: "Binary"
            )
            
        case let date as Date:
            return FormattedPrimitive(
                value: date.ISO8601Format(),
                color: .purple,
                isExpandable: false,
                type: "Date"
            )
            
        case let bool as Bool:
            return FormattedPrimitive(
                value: bool.description,
                color: .green,
                isExpandable: false,
                type: "Boolean"
            )
            
        case let doc as Document:
            if doc.isArray {
                _ = (0..<doc.count).compactMap { index in
                    formatValue(doc[String(index)])
                }
                
                return FormattedPrimitive(
                    value: "Array (\(doc.count))",
                    color: .secondary,
                    isExpandable: !doc.isEmpty,
                    type: "Array"
                )
            } else {
                return FormattedPrimitive(
                    value: "Object",
                    color: .secondary,
                    isExpandable: !doc.isEmpty,
                    type: "Array"
                )
            }
            
        case let string as String:
            return FormattedPrimitive(
                value: "\"\(string)\"",
                color: .green,
                isExpandable: false,
                type: "String"
            )
            
        case let number as Int: return numberFormatted(number, value: value, type: "Int")
        case let number as Int32: return numberFormatted(number, value: value, type: "Int32")
        case let number as Double: return numberFormatted(number, value: value, type: "Double")
        case let number as BSON.Decimal128:
            return FormattedPrimitive(
                value: String(describing: number.toString),
                color: .blue,
                isExpandable: false,
                type: "Number"
            )
        default:
            return FormattedPrimitive(
                value: String(describing: value),
                color: .white,
                isExpandable: false,
                type: "String"
            )
        }
    }
    
    private func numberFormatted(_ number: Any, value: Primitive, type: String) -> FormattedPrimitive {
        return FormattedPrimitive(
            value: String(describing: number),
            color: .blue,
            isExpandable: false,
            type: type
        )
    }
    
    func extractUUIDFromBinary(_ binary: Binary) -> UUID? {
        guard binary.subType == .uuid, binary.count == 16 else {
            return nil
        }
        
        return binary.storage.withUnsafeReadableBytes { buffer in
            guard buffer.count == 16 else { return nil }
            let bytes = buffer.bindMemory(to: UInt8.self)
            return UUID(uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            ))
        }
    }
}


extension Document {
    struct FormattedDocument: Hashable {
        let id: String
        let fields: [FormattedField]
        let rawDocument: Document
        
        struct FormattedField: Hashable {
            let key: String
            let formattedValue: FormattedPrimitive
            let rawValue: Primitive
            let nestedFields: [FormattedField]?
            
            // Implement Hashable
            func hash(into hasher: inout Hasher) {
                hasher.combine(key)
                hasher.combine(formattedValue.value)
            }
            
            static func == (lhs: FormattedField, rhs: FormattedField) -> Bool {
                return lhs.key == rhs.key && lhs.formattedValue.value == rhs.formattedValue.value
            }
        }
        
        // Implement Hashable
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: FormattedDocument, rhs: FormattedDocument) -> Bool {
            return lhs.id == rhs.id
        }
    }
}



    extension Binary.SubType {
        public static func == (lhs: Binary.SubType, rhs: Binary.SubType) -> Bool {
            switch (lhs, rhs) {
            case (.generic, .generic), (.function, .function), (.uuid, .uuid), (.md5, .md5):
                return true
            case (.userDefined(let lhsByte), .userDefined(let rhsByte)):
                return lhsByte == rhsByte
            default:
                return false
            }
        }
    }
