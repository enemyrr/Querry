//
//  DocumentView.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/2/25.
//
import SwiftUI
import AppKit
import MongoKitten

struct DocumentView: View {
    @Environment(\.self) private var viewContext
    @State private var documents: [Document] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var vibrateOnRing = false
    @State private var selectField: Fields = .raw
    @State private var filterQuery:  String = ""
    @State private var filterOperator: FilterOperators = .eq
    
    private var collectionName: String
    
    enum Fields: String, CaseIterable, Identifiable {
        case _id, name, raw
        var id: Self { self }
    }
    enum FilterOperators: String, CaseIterable, Identifiable {
        case eq, ne, gt, lt, gte, lte
        var id: Self { self }
    }
    
    
    init(collection: String) {
        self.collectionName = collection
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
                    ForEach(documents, id: \.self) { document in
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
            guard let queryBuilder = DatabaseProvider.shared
                .findQueryBuilder(byCollectionName: collectionName)
            else {
                return
            }
            
            var loadedDocuments: [Document] = []
            
            // Now queryBuilder is unwrapped
            for try await document in queryBuilder {
                loadedDocuments.append(document)
                
                // Update UI in small batches for smoother experience
                if loadedDocuments.count % 20 == 0 {
                    await MainActor.run {
                        self.documents = loadedDocuments
                    }
                }
            }
            
            // Final update for any remaining documents
            await MainActor.run {
                self.documents = loadedDocuments
            }
        } catch {
            self.error = error
        }
    }
}
