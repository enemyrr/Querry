//
//  DocumentView.swift
//  Collection
//
//  Created by Fauzaan on 1/2/25.
//
import SwiftUI
import AppKit
import MongoKitten

struct DocumentView: View {
    var instance: ConnectionInstance
    @Environment(\.self) private var viewContext
    @State private var documents: [Document] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var vibrateOnRing = false
    @State private var selectField: Fields = .raw
    @State private var filterQuery:  String = ""
    @State private var filterOperator: FilterOperators = .eq
    @State private var formattedDocuments: [FormattedDocument] = []
    
    var selectedTab: DatabaseTab
    
    enum Fields: String, CaseIterable, Identifiable {
        case _id, name, raw
        var id: Self { self }
    }
    enum FilterOperators: String, CaseIterable, Identifiable {
        case eq, ne, gt, lt, gte, lte
        var id: Self { self }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // TODO: Add filter component
            //            VStack {
            //                HStack {
            //                    Toggle(isOn: $vibrateOnRing) {}
            //                    Picker("Fields", selection: $selectField) {
            //                        Text("_id").tag(Fields._id)
            //                        Text("name").tag(Fields.name)
            //                        Text("Raw Query").tag(Fields.raw)
            //                    }
            //                    .pickerStyle(.menu)
            //                    .labelsHidden()
            //
            //                    Picker("Operators", selection: $filterOperator) {
            //                        Text("==").tag(FilterOperators.eq)
            //                        Text("!=").tag(FilterOperators.ne)
            //                        Text("<").tag(FilterOperators.lt)
            //                        Text("<=").tag(FilterOperators.lte)
            //                        Text(">").tag(FilterOperators.gt)
            //                        Text(">=").tag(FilterOperators.gte)
            //                    }
            //
            //                    .pickerStyle(.menu)
            //                    .labelsHidden()
            //
            //                    TextField(
            //                        "EMPTY",
            //                        text: $filterQuery
            //                    )
            //                    .textFieldStyle(.roundedBorder)
            //                }
            //            }
            //            .frame(maxWidth: .infinity, maxHeight: 30)
            //            Divider()
            
            ScrollView {
                LazyVStack {
                    ForEach(formattedDocuments, id: \.self) { document in
                        DocumentDetails(document: document)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                            .padding(.vertical, 3)
                    }
                }
                .padding(.vertical)
            }
        }
        .task {
            await loadDocuments()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
    
    private func loadDocuments() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let queryBuilder = try instance.findQueryBuilder(from: selectedTab.name)
            var loadedDocuments: [Document] = []
            
            // First load all documents
            for try await document in queryBuilder {
                loadedDocuments.append(document)
            }
            
            // Then format them on a background thread
            let formatted = await formatDocuments(loadedDocuments)
            
            // Update UI
            await MainActor.run {
                self.formattedDocuments = formatted
                instance.cacheDouments(tab: selectedTab, documents: loadedDocuments)
            }
        } catch {
            self.error = error
        }
    }
    
    private func formatDocuments(_ documents: [Document]) async -> [FormattedDocument] {
        // Process in chunks to avoid blocking the thread for too long
        let chunkSize = 50
        var formattedDocs: [FormattedDocument] = []
        
        for chunk in stride(from: 0, to: documents.count, by: chunkSize) {
            let end = min(chunk + chunkSize, documents.count)
            let documentChunk = Array(documents[chunk..<end])
            
            let formattedChunk = documentChunk.map { document in
                formatDocument(document)
            }
            
            formattedDocs.append(contentsOf: formattedChunk)
            
            // Yield to other tasks periodically
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
            rawValue: value ?? "nill",
            nestedFields: nestedFields
        )
    }
}
