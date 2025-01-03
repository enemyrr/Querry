//
//  DatabaseProtocol.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/1/25.
//

import MongoKitten

protocol DatabaseManaging {
    func connect(connectionString: String, databaseName: String) async throws
    func getCollections() async throws -> [MongoCollection]
    func getDocuments(from collectionName: String) async throws -> [Document]
}

extension MongoManager: DatabaseManaging {}
