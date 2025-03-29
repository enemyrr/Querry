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
                value: "ObjectId('\(objectId.hexString)')",
                color: .orange,
                isExpandable: false,
                type: "ObjectId"
            )
            
        case let array as [Primitive]:
            return FormattedPrimitive(
                value: "Array (\(array.count))",
                color: .gray,
                isExpandable: !array.isEmpty,
                type: "Array"
            )
            
        case let date as Date:
            return FormattedPrimitive(
                value: date.ISO8601Format(),
                color: .blue,
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
                    color: .gray,
                    isExpandable: !doc.isEmpty,
                    type: "Array"
                )
            } else {
                return FormattedPrimitive(
                    value: "Object",
                    color: .white.opacity(0.5),
                    isExpandable: !doc.isEmpty,
                    type: "Array"
                )
            }
            
        case let string as String:
            return FormattedPrimitive(
                value: "\"\(string)\"",
                color: Color(red: 97/255, green: 193/255, blue: 119/255),
                isExpandable: false,
                type: "String"
            )
            
        case let number as Int: return numberFormatted(number, value: value, type: "Int")
        case let number as Int32: return numberFormatted(number, value: value, type: "Int32")
        case let number as Int64: return numberFormatted(number, value: value, type: "Int64")
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
}


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
