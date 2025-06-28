
//
//  CommandPaletteView.swift
//  Pluk
//
//  Created by Fauzaan on 6/27/25.
//

import SwiftUI

struct CommandPaletteView: View {
    @Environment(ConnectionInstance.self) private var instance
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    
    private var filteredCollections: [any CollectionWrapper] {
        guard let collections = instance.collections[instance.connectedDatabase?.name ?? ""] else {
            return []
        }
        
        if searchText.isEmpty {
            return collections
        }
        
        return collections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search collections...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            .cornerRadius(8)
            
            List(filteredCollections, id: \.name) { collection in
                Button(action: {
                    instance.createNewTab(name: collection.name)
                    isPresented = false
                }) {
                    Text(collection.name)
                }
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}
