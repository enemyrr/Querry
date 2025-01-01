//
//  SidebarView.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/1/25.
//
import SwiftUI
import MongoKitten

struct SidebarView: View {
    @State private var searchText = ""
    @ObservedObject var viewModel: DatabaseViewModel
    @State private var selection: String?
    
    
    init(viewModel: DatabaseViewModel) {
        self.viewModel = viewModel
        NSWindow.allowsAutomaticWindowFrame = true
    }
    
    var filteredCollections: [MongoCollection] {
        if searchText.isEmpty {
            return viewModel.collections
        }
        return viewModel.collections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        List(filteredCollections, id: \.name, selection: $selection) { collection in
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.white)
                Text(collection.name)
                    .foregroundColor(.white)
            }
        }
        .listStyle(.sidebar)
        .onChange(of: selection) { oldValue, newValue in
            if let selectedCollection = newValue {
                Task {
                    await viewModel.getDocuments(collectionName: selectedCollection)
                }
            }
        }.frame(idealWidth: 250)
    }
}


#Preview {
    SidebarView(viewModel: DatabaseViewModel())
        .modelContainer(for: Item.self, inMemory: true)
}
