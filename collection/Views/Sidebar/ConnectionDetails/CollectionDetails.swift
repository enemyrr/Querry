//
//  CollectionDetails.swift
//  Collection
//
//  Created by Fauzaan on 3/23/25.
//

import SwiftUI

// MARK: - ConnectionDetailsSidebar
struct ConnectionDetailsSidebar: View {
    var model: SidebarViewModel
    
    @State private var isScrolled = false
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var scrollSpace
    
    var body: some View {
        VStack(spacing: 0) {
            if let instance = model.activeInstance {
                ConnectionHeader(instance: instance)
                
                VStack(spacing: 0) {
                    DatabaseHeader(instance: instance)
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
                        
                        DatabaseList()
                    }
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.separator, lineWidth: 1)
        }
        .task(id: model.activeSidebarItem.hashValue) {
            await model.loadActiveConnection()
        }
    }
}
