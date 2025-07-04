//
//  PostgresSQL+PostgresDataType.swift
//  Pluk
//
//  Created by Fauzaan on 7/4/25.
//

import Foundation
import PostgresNIO

extension PostgreSQLDriver {
    // Create a static mapping from SQL names to PostgresDataType
    private static let typeMapping: [String: PostgresDataType] = {
        let allTypes: [PostgresDataType] = [
            .bool, .bytea, .char, .name, .int8, .int2, .int4, .text, .oid,
            .json, .xml, .point, .lseg, .path, .box, .polygon, .line,
            .cidr, .float4, .float8, .circle, .macaddr8, .money, .macaddr,
            .inet, .date, .time, .timestamp, .timestamptz, .interval,
            .timetz, .bit, .varbit, .numeric, .uuid, .tsvector, .tsquery,
            .jsonb, .int4Range, .numrange, .tsrange, .tstzrange, .daterange,
            .int8Range, .varchar, .bpchar
        ]
        
        var mapping: [String: PostgresDataType] = [:]
        
        for type in allTypes {
            // Add the exact SQL name if it exists
            if let sqlName = type.knownSQLName {
                mapping[sqlName.uppercased()] = type
            }
            
            // Add PostgreSQL internal type names AND format type names
            switch type {
            case .bool:
                mapping["BOOL"] = type
                mapping["BOOLEAN"] = type
            case .int2:
                mapping["INT2"] = type
                mapping["SMALLINT"] = type
            case .int4:
                mapping["INT4"] = type
                mapping["INTEGER"] = type
                mapping["INT"] = type
            case .int8:
                mapping["INT8"] = type
                mapping["BIGINT"] = type
            case .float4:
                mapping["FLOAT4"] = type
                mapping["REAL"] = type
            case .float8:
                mapping["FLOAT8"] = type
                mapping["DOUBLE PRECISION"] = type
                mapping["DOUBLE"] = type
            case .text:
                mapping["TEXT"] = type
            case .varchar:
                mapping["VARCHAR"] = type
                mapping["CHARACTER VARYING"] = type  // This is the format_type name
            case .anyenum:
                mapping["USER-DEFINED"] = type
            case .bpchar:
                mapping["BPCHAR"] = type
                mapping["CHARACTER"] = type
                mapping["CHAR"] = type
            case .timestamp:
                mapping["TIMESTAMP"] = type
                mapping["TIMESTAMP WITHOUT TIME ZONE"] = type
            case .timestamptz:
                mapping["TIMESTAMPTZ"] = type
                mapping["TIMESTAMP WITH TIME ZONE"] = type
            case .numeric:
                mapping["NUMERIC"] = type
                mapping["DECIMAL"] = type
            case .jsonb:
                mapping["JSONB"] = type
            case .json:
                mapping["JSON"] = type
            case .uuid:
                mapping["UUID"] = type
            case .date:
                mapping["DATE"] = type
            case .time:
                mapping["TIME"] = type
                mapping["TIME WITHOUT TIME ZONE"] = type  // format_type variant
            case .timetz:
                mapping["TIMETZ"] = type
                mapping["TIME WITH TIME ZONE"] = type  // format_type variant
            case .money:
                mapping["MONEY"] = type
            case .bytea:
                mapping["BYTEA"] = type
            case .interval:
                mapping["INTERVAL"] = type
            case .bit:
                mapping["BIT"] = type
            case .varbit:
                mapping["VARBIT"] = type
                mapping["BIT VARYING"] = type  // format_type variant
            default:
                break
            }
        }
        
        return mapping
    }()
    
    func postgresDataType(from stringType: String) -> PostgresDataType {
        let normalized = stringType.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.typeMapping[normalized] ?? .text // Safe fallback to text
    }
}
