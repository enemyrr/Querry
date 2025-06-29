//
//  CollectionDetails.swift
//  Collection
//
//  Created by Fauzaan on 3/23/25.
//

import SwiftUI

// MARK: - ConnectionDetailsSidebar
struct ConnectionDetailsSidebar: View {
    @Environment(SidebarViewModel.self) var viewModel: SidebarViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var isScrolled = false
    
    var body: some View {
        VStack(spacing: 0) {
            if let instance = viewModel.activeConnection {
                ConnectionHeader(
                    name: instance.connection.name,
                    status: instance.connectionStatus,
                    version: instance.connectionVersion,
                    databaseType: instance.connection.databaseType,
                    environment: instance.connection.environment)
                
                VStack(spacing: 4) {
                    DatabaseHeader(
                        viewModel: viewModel,
                    )
                    
                    SoftSeparator()
                        .opacity(isScrolled ? 1 : 0)
                }
                .animation(.easeOut(duration: 0.15), value: isScrolled)
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        // Invisible marker view to detect when scrolled past
                        Color.clear
                            .frame(height: 1)
                            .id("scrollMarker")
                            .onAppear {
                                isScrolled = false
                            }
                            .onDisappear {
                                isScrolled = true
                            }
                        
                        DatabaseList(viewModel: viewModel)
                    }
                }
            }
        }
        .padding()
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.separator)
        }
        .cornerRadius(16)
        .task(id: viewModel.activeSidebarItem.hashValue) {
            do {
                try await viewModel.activeConnection?.connect()
            } catch {
                
            }
        }
    }
}

