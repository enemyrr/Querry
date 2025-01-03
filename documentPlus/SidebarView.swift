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
    @State private var selection: String?
    
    @Binding var collections: [MongoCollection]
    @Binding var tabs: [ContentItem]
    @Binding var selectedTab: ContentItem?
    
    init(tabs: Binding<[ContentItem]>,
         selectedTab: Binding<ContentItem?>,
         collections: Binding<[MongoCollection]>
    ) {
        _tabs = tabs
        _selectedTab = selectedTab
        _collections = collections
        NSWindow.allowsAutomaticWindowFrame = true
    }
    
    var filteredCollections: [MongoCollection] {
        if searchText.isEmpty {
            return self.collections
        }
        return self.collections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        List(filteredCollections, id: \.name, selection: $selection) { collection in
            HStack {
                Image(systemName: "tablecells")
                    .foregroundColor(Color(#colorLiteral(red: 0.9999999404, green: 1, blue: 1, alpha: 1)))
                Text(collection.name)
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search items...")
        .onChange(of: selection) { oldValue, newValue in
            if let selectedCollection = newValue {
                Task {
                    addTab(for: ContentItem(title: selectedCollection ))
                }
            }
        }
    }
    
    
    private func addTab(for item: ContentItem) {
        if !tabs.contains(where: { $0.title == item.title }) {
            withAnimation {
                tabs.append(item)
            }
        }
        
        selectedTab = item
    }
}
