//
//  Connection.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/4/25.
//

import SwiftUI
import SwiftData

enum DatabaseType: String, Codable {
    case mongodb = "MongoDB"
}

@Model
final class Connection {
    var name: String
    var databaseType: DatabaseType
    var url: String
    var createdAt: Date = Date()
    var lastOpenedAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(name: String, databaseType: DatabaseType, url: String) {
        self.name = name
        self.databaseType = databaseType
        self.url = url
    }
}

