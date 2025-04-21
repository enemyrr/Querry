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
                    environment: instance.connection.environment)
                
                VStack(spacing: 0) {
                    DatabaseHeader(
                        viewModel: viewModel,
                        database: instance.database
                    )
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    
                    SoftSeparator()
                        .opacity(isScrolled ? 1 : 0)
                }
                .animation(.easeOut(duration: 0.15), value: isScrolled)
            }
            
            // Scrollable content with scroll detection
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
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.separator)
        }
        .task(id: viewModel.activeSidebarItem.hashValue) {
            await viewModel.loadActiveConnection()
        }
    }
}
