//
//  Sidebar.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/1/25.
//
import SwiftUI
import MongoKitten

struct RedBorderMenuStyle: MenuStyle {
    func makeBody(configuration: Configuration) -> some View {
        Menu(configuration)
            .border(Color.red)
    }
}

struct Sidebar: View {
    @State private var searchText = ""
    @State private var selection: String?
    @State private var isMenuActive = false
    
    @Binding var collections: [MongoCollection]
    @Binding var databases: [MongoDatabase]
    @Binding var tabs: [String]
    @Binding var selectedTab: String?
    @State private var selectedDatabase: MongoDatabase?
    
    init(tabs: Binding<[String]>,
         selectedTab: Binding<String?>,
         collections: Binding<[MongoCollection]>,
         databases: Binding<[MongoDatabase]>
    ) {
        _tabs = tabs
        _selectedTab = selectedTab
        _collections = collections
        _databases = databases
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
            Image(systemName: "folder").foregroundColor(Color(NSColor.controlAccentColor))
            Image(systemName: "clock").foregroundColor(Color.white.opacity(0.5))
            Image(systemName: "magnifyingglass").foregroundColor(Color.white.opacity(0.5))
        }.frame(height: 14)
        Divider()
        
        HStack {
            Menu {
                ForEach(databases, id: \.name) { database in
                    Button(database.name) {
                        Task {
                            await selectDatabase(database)
                        }
                    }
                }
                Divider()
                Button("Manage database") {
                    // Action
                }
            } label: {
                Text(selectedDatabase?.name ?? "Select database")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .tint(.secondary)
            .fixedSize()
            
            Spacer()
            Button(action: {
            }, label: {
                Image(systemName: "plus.circle.fill")
            }).buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        
        Divider()
        
        List(filteredCollections, id: \.name, selection: $selection) { collection in
            HStack {
                Image(systemName: "folder").opacity(0.5)
                Text(collection.name)
            }
        }
        .frame(minWidth: 250, maxWidth: 750)
        .frame(idealWidth: 250)
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
    
    private func selectDatabase(_ database: MongoDatabase) async {
        selectedDatabase = database
        do {
            collections = try await database.listCollections()
        } catch {
            print("Error loading collections: \(error)")
        }
    }
}
