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
    @Binding var documents: [Document]
    @State private var vibrateOnRing = false
    @State private var selectField: Fields = .raw
    @State private var filterQuery:  String = ""
    @State private var filterOperator: FilterOperators = .eq
    
    enum Fields: String, CaseIterable, Identifiable {
        case _id, name, raw
        var id: Self { self }
    }
    enum FilterOperators: String, CaseIterable, Identifiable {
        case eq, ne, gt, lt, gte, lte
        var id: Self { self }
    }
    
    
    init(documents: Binding<[Document]>) {
        _documents = documents
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
                    ForEach(Array(documents.enumerated()), id: \.offset) { index, document in
                        DocumentDetails(document: document)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                            .padding(.vertical, 3)
                            .id(index)
                    }
                }
                .padding(.vertical)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
