//
//  DocumentViewModel.swift
//  Collection
//
//  Created by Fauzaan on 2/19/25.
//

import Foundation
import MongoKitten

@MainActor
class DocumentViewModel: ObservableObject {
    private let instance: ConnectionInstance
    private let selectedTab: DatabaseTab
    
    // Pagination state
    @Published private(set) var currentPage: Int = 1
    @Published private(set) var itemsPerPage: Int = 25
    @Published private(set) var totalItems: Int = 0
    
    // Computed property for total pages
    var totalPages: Int {
        return max(1, Int(ceil(Double(totalItems) / Double(itemsPerPage))))
    }
    
    @Published private(set) var formattedDocuments: [FormattedDocument] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var filterText = "" // Add this
    
    init(instance: ConnectionInstance, selectedTab: DatabaseTab) {
        self.instance = instance
        self.selectedTab = selectedTab
    }
    
    func loadDocuments() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // First get the total count for pagination
            totalItems = try await instance.getDocumentCount(for: selectedTab.name)
            
            // Calculate skip based on current page
            let skip = (currentPage - 1) * itemsPerPage
            
            // Get query builder and apply pagination
            let queryBuilder = try instance.findQueryBuilder(from: selectedTab.name)
                .skip(skip)
                .limit(itemsPerPage)
            
            var loadedDocuments: [Document] = []
            
            for try await document in queryBuilder {
                loadedDocuments.append(document)
            }
            
            let formatted = await formatDocuments(loadedDocuments)
            self.formattedDocuments = formatted
            instance.cacheDouments(tab: selectedTab, documents: loadedDocuments)
        } catch {
            self.error = error
        }
    }
    
    func nextPage() {
        if currentPage < totalPages {
            currentPage += 1
            Task {
                await loadDocuments()
            }
        }
    }
    
    func previousPage() {
        if currentPage > 1 {
            currentPage -= 1
            Task {
                await loadDocuments()
            }
        }
    }
    
    func goToPage(_ page: Int) {
        if page >= 1 && page <= totalPages {
            currentPage = page
            Task {
                await loadDocuments()
            }
        }
    }
    
    private func formatDocuments(_ documents: [Document]) async -> [FormattedDocument] {
        let chunkSize = 50
        var formattedDocs: [FormattedDocument] = []
        
        for chunk in stride(from: 0, to: documents.count, by: chunkSize) {
            let end = min(chunk + chunkSize, documents.count)
            let documentChunk = Array(documents[chunk..<end])
            
            let formattedChunk = documentChunk.map { document in
                formatDocument(document)
            }
            
            formattedDocs.append(contentsOf: formattedChunk)
            await Task.yield()
        }
        
        return formattedDocs
    }
    
    private func formatDocument(_ document: Document) -> FormattedDocument {
        let id = (document["_id"] as? ObjectId)?.hexString ?? UUID().uuidString
        let fields = document.keys.sorted().map { key in
            formatField(key: key, value: document[key])
        }
        
        return FormattedDocument(id: id, fields: fields)
    }
    
    private func formatField(key: String, value: Primitive?) -> FormattedDocument.FormattedField {
        let formatted = Document().formatValue(value)
        
        var nestedFields: [FormattedDocument.FormattedField]?
        if let doc = value as? Document {
            nestedFields = doc.keys.sorted().map { key in
                formatField(key: key, value: doc[key])
            }
        }
        
        return FormattedDocument.FormattedField(
            key: key,
            formattedValue: formatted,
            rawValue: value ?? "nil",
            nestedFields: nestedFields
        )
    }
    
    func updateFilteredDocuments() {}
}
