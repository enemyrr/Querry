//
//  CollectionDetails.swift
//  Collection
//
//  Created by Fauzaan on 3/23/25.
//

import SwiftUI

// MARK: - ScrollOffsetPreferenceKey
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - ConnectionDetailsSidebar
struct ConnectionDetailsSidebar: View {
    @Environment(SidebarViewModel.self) var viewModel: SidebarViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var isScrolled = false
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            if let instance = viewModel.activeConnection {
                ConnectionHeader(
                    onDisconnect: {
                        await viewModel.disconnectConnectionInstance(instance.id)
                    },
                    onReconnect: {
                        Task {
                            try await instance.reconnect()
                        }
                    })
                
                VStack(spacing: 4) {
                    DatabaseHeader(viewModel: viewModel)
                        .padding(.top, 6)
                        .padding(.bottom, 2)

                    SoftSeparator()
                        .opacity(isScrolled ? 1 : 0)
                }
                .animation(.easeOut(duration: 0.15), value: isScrolled)
            }
            
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    if viewModel.isSearchVisible {
                        SearchInput(viewModel: viewModel)
                            .padding(.trailing, 16)
                            .padding(.bottom, 8)
                    }
                    
                    DatabaseList(viewModel: viewModel)
                        .padding(.trailing, 16)
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .onAppear {
                                        scrollOffset = geometry.frame(in: .global).minY
                                    }
                                    .onChange(of: geometry.frame(in: .global).minY) { _, newValue in
                                        let diff = scrollOffset - newValue
                                        withAnimation(.easeOut(duration: 0.15)) {
                                            isScrolled = diff > 20
                                        }
                                    }
                            }
                        )
                }
            }
            .padding(.trailing, -16)
        }
        .padding([.top, .horizontal], 16)
        .padding(.bottom, 0)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.separator)
        }
        .task(id: viewModel.activeSidebarItem.hashValue) {
            do {
                try await viewModel.activeConnection?.connect()
            } catch {
                
            }
        }
    }
}
