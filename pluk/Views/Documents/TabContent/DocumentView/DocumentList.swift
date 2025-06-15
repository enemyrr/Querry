
import SwiftUI
import AppKit
import MongoKitten

struct DocumentList: View {
    let selectedTab: DatabaseTab
    @Environment(ConnectionInstance.self) private var instance
    
    @State private var viewState: TableListViewState = .loading
    @State private var searchFilter: String = ""
    
    @State private var cachedQueryResult: QueryResult?
    @State private var cachedTabName: String?
    
    let schemaToUse = DatabaseSchemaResult(tableName: "", schemaName: "", columns: [], totalCount: 0)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    if let cachedQueryResult = cachedQueryResult {
                        DocumentListScrollView(queryResult: cachedQueryResult)
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.separator, lineWidth: 1)
                }
                .cornerRadius(10)
            }
            .task(id: selectedTab.name) {
                await loadDocumentsIfNeeded()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    /// Load documents only if they don't exist in cache or tab has changed
    private func loadDocumentsIfNeeded() async {
        let shouldFetch = cachedTabName != selectedTab.name || cachedQueryResult == nil
        
        if shouldFetch {
            await loadDocuments(forceFetch: true, page: 1, limit: 300)
        } else {
            // Use cached data
            if let queryResult = cachedQueryResult {
                viewState = .loaded(queryResult, schemaToUse)
            }
        }
    }
    
    /// Load documents with options to force fetch and control schema fetching
    private func loadDocuments(forceFetch: Bool = false, page: Int = 1, limit: Int = 300) async {
        guard let driver = instance.databaseService else {
            viewState = .error("Driver not set")
            return
        }
        
        if !forceFetch &&
            cachedTabName == selectedTab.name,
           let queryResult = cachedQueryResult {
            viewState = .loaded(queryResult, schemaToUse)
            return
        }
        
        do {
            viewState = .loading
            
            let queryResult = try await driver.findDocuments(
                in: selectedTab.name,
                filter: searchFilter,
                skip: (page - 1) * limit,
                limit: limit
            )
            
            cachedQueryResult = queryResult
            cachedTabName = selectedTab.name
            
            viewState = .loaded(queryResult, schemaToUse)
        } catch {
            print(error.localizedDescription)
            viewState = .error(error.localizedDescription)
        }
    }
}

struct DocumentListScrollView: View {
    let queryResult: QueryResult
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(queryResult.rows.enumerated()), id: \.offset) { index, document in
                    DocumentRowView(
                        document: document,
                        index: index
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                }
            }
            .padding(.top)
            .padding(.bottom, 24)
            
            Spacer()
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if queryResult.rows.isEmpty {
                ContentUnavailableView {
                    Label("No Documents Available", systemImage: "tray")
                        .font(.title2)
                } description: {
                    Text("This collection doesn't contain any documents yet.\nAdd your first document or import data to get started.")
                } actions: {
                    Button("Refresh") {
                        // Add refresh action
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
