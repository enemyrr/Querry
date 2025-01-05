//
//  Sidebar.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/1/25.
//
import SwiftUI
import MongoKitten

struct Sidebar: View {
    @State private var searchText = ""
    @State private var selection: String?
    
    @Binding var collections: [MongoCollection]
    @Binding var tabs: [String]
    @Binding var selectedTab: String?
    
    init(tabs: Binding<[String]>,
         selectedTab: Binding<String?>,
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
        Divider()
        HStack(spacing: 20) {
            Image(systemName: "tablecells").foregroundColor(Color(NSColor.controlAccentColor))
            Image(systemName: "folder").foregroundColor(Color.white.opacity(0.5))
            Image(systemName: "clock").foregroundColor(Color.white.opacity(0.5))
            Image(systemName: "magnifyingglass").foregroundColor(Color.white.opacity(0.5))
        }.frame(height: 14)
        Divider()
        
        List(filteredCollections, id: \.name, selection: $selection) { collection in
            HStack {
                Image(systemName: "tablecells").opacity(0.5)
                Text(collection.name)
            }
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search items...")
        .onChange(of: selection) { oldValue, newValue in
            if let selectedCollection = newValue {
                Task {
                    addTab(for: selectedCollection)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    toggleSidebar()
                }, label: {
                    Image(systemName: "sidebar.left")
                })
                .help("Toggle Sidebar")
            }
        }
    }
    
    
    func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
    
    private func addTab(for item: String) {
        if !tabs.contains(where: { $0 == item }) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                tabs.append(item)
            }
        }
        
        selectedTab = item
    }
}
