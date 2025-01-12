//
//  DocumentFormatter.swift
//  DocumentPlus
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
}

extension Document {
    // Format a single value
    func formatValue(_ value: Primitive?) -> FormattedPrimitive {
        guard let value = value else {
            return FormattedPrimitive(
                value: "null",
                color: .gray,
                isExpandable: false
            )
        }
        
        switch value {
        case let objectId as ObjectId:
            return FormattedPrimitive(
                value: "ObjectId('\(objectId.hexString)')",
                color: .orange,
                isExpandable: false
            )
            
        case let array as [Primitive]:
            return FormattedPrimitive(
                value: "Array (\(array.count))",
                color: .gray,
                isExpandable: !array.isEmpty
            )
            
        case let date as Date:
            return FormattedPrimitive(
                value: date.ISO8601Format(),
                color: .blue,
                isExpandable: false
            )
            
        case let bool as Bool:
            return FormattedPrimitive(
                value: bool.description,
                color: .green,
                isExpandable: false
            )
            
        case let doc as Document:
            if doc.isArray {
                let arrayItems = (0..<doc.count).compactMap { index in
                    formatValue(doc[String(index)])
                }
                
                return FormattedPrimitive(
                    value: "Array (\(doc.count))",
                    color: .gray,
                    isExpandable: !doc.isEmpty
                )
            } else {
                return FormattedPrimitive(
                    value: "Object",
                    color: .white.opacity(0.5),
                    isExpandable: !doc.isEmpty
                )
            }
            
        case let string as String:
            return FormattedPrimitive(
                value: "\"\(string)\"",
                color: Color(red: 97/255, green: 193/255, blue: 119/255),
                isExpandable: false
            )
            
        case let number as Int: return numberFormatted(number, value: value)
        case let number as Int32: return numberFormatted(number, value: value)
        case let number as Int64: return numberFormatted(number, value: value)
        case let number as Double: return numberFormatted(number, value: value)
        case let number as BSON.Decimal128:
            return FormattedPrimitive(
                value: String(describing: number.toString),
                color: .blue,
                isExpandable: false
            )
        default:
            return FormattedPrimitive(
                value: String(describing: value),
                color: .white,
                isExpandable: false
            )
        }
    }
    
    private func numberFormatted(_ number: Any, value: Primitive) -> FormattedPrimitive {
        return FormattedPrimitive(
            value: String(describing: number),
            color: .blue,
            isExpandable: false
        )
    }
    
}

