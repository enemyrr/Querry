//
//  TableListView.swift
//  Pluk
//
//  Created by Fauzaan on 6/2/25.
//
import Foundation
import SwiftUI
import AppKit

struct TableListView: View {
    let selectedTab: DatabaseTab
    @Environment(ConnectionInstance.self) private var instance
    
    @State private var isLoading = false
    @State private var loadingError: Error?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    Group {
                        if let selectedTab = instance.selectedTab,
                           let schemaResult = instance.schema[selectedTab.name] {
                            TableListViewController(
                                rows: instance.documents[selectedTab.name],
                                schema: schemaResult
                            )
                            .background(Color(.controlBackgroundColor).opacity(0.3))
                            .cornerRadius(10)
                        } else {
                            VStack {}
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(10)
                        }
                    }
                }
                
                VStack {
                    Spacer()
                    FloatingActionBar(screenWidth: geometry.size.width)
                        .padding(.bottom, 10)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .task(id: instance.selectedTab?.name) {
                await loadTabData()
            }
        }
    }
    
    @MainActor
    private func loadTabData() async {
        guard let selectedTabName = instance.selectedTab?.name else {
            return
        }
        
        // Prevent redundant loading
        let needsSchema = instance.schema[selectedTabName] == nil
        let needsDocuments =  instance.documents[selectedTabName] == nil
        
        guard needsSchema || needsDocuments else {
            return // Already loaded
        }
        
        isLoading = true
        loadingError = nil
        
        do {
            // Run both requests concurrently using async let
            if needsSchema && needsDocuments {
                async let schemaTask: Void = instance.getSchema(for: selectedTabName)
                async let documentsTask: Void = instance.fetchDocuments(from: selectedTabName)
                
                _ = try await schemaTask
                _ = try await documentsTask
                
            } else if needsSchema {
                try await instance.getSchema(for: selectedTabName)
                
            } else if needsDocuments {
                _ = try await instance.fetchDocuments(from: selectedTabName)
            }
            
        } catch {
            loadingError = error
            print("Failed to load tab data: \(error)")
        }
        
        isLoading = false
    }
}
