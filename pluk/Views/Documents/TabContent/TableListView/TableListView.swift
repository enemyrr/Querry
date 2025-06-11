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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    Group {
                        if let selectedTabName = instance.selectedTab?.name,
                           let schemaResult = instance.schema[selectedTabName] {
                            TableListViewController(
                                rows: instance.documents[selectedTabName],
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
                    .task(id: instance.selectedTab?.id) {
                        guard let selectedTab = instance.selectedTab?.name else { return }
                        
                        do {
                            try await instance.getSchema(for: selectedTab)
                        } catch {
                            // TODO: Show error page to the user
                            print("Failed to get schema: \(error)")
                        }
                    }
                    .task(id: instance.selectedTab?.id) {
                        guard let selectedTab = instance.selectedTab?.name else { return }
                        
                        do {
                            try await instance.fetchDocuments(from: selectedTab)
                        } catch {
                            // TODO: Show error page to the user
                            print("Failed to get rows: \(error)")
                        }
                    }
                }
                
                VStack {
                    Spacer()
                    //                    FloatingActionBar(viewModel: viewModel, screenWidth: geometry.size.width)
                    //                        .padding(.bottom, 10)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
