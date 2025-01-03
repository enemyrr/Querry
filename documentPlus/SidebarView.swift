//
//  SidebarView.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/1/25.
//
import SwiftUI
import MongoKitten

struct SidebarView: View {
    @EnvironmentObject var databaseViewModel: DatabaseViewModel
    @State private var searchText = ""
    @State private var selection: String?
    @Binding var tabs: [ContentItem]
    @Binding var selectedTab: ContentItem?

    init(tabs: Binding<[ContentItem]>,
         selectedTab: Binding<ContentItem?>
    ) {
        _tabs = tabs
        _selectedTab = selectedTab
        NSWindow.allowsAutomaticWindowFrame = true
    }
    
    var filteredCollections: [MongoCollection] {
        if searchText.isEmpty {
            return databaseViewModel.collections
        }
        return databaseViewModel.collections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        List(filteredCollections, id: \.name, selection: $selection) { collection in
            HStack {
                Image(systemName: "tablecells")
                Text(collection.name)
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search items...")
        .onChange(of: selection) { oldValue, newValue in
            if let selectedCollection = newValue {
                Task {
                    addTab(for: ContentItem(title: selectedCollection, databaseViewModel: databaseViewModel))
                }
            }
        }
    }
    
    
    private func addTab(for item: ContentItem) {
        if !tabs.contains(where: { $0.id == item.id }) {
            withAnimation {
                tabs.append(item)
            }
        }
        selectedTab = item
        
    }
}
