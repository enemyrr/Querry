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
    @Environment(ConnectionInstance.self) var connectionInstance: ConnectionInstance
    @Environment(\.colorScheme) private var colorScheme
    @State private var isScrolled = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isLoadingCollections: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            ConnectionHeader(
                onDisconnect: {
                    await viewModel.disconnectConnectionInstance(connectionInstance.id)
                },
                onReconnect: {
                    Task {
                        try await connectionInstance.reconnect()
                    }
                })

            VStack(spacing: 4) {
                DatabaseHeader(viewModel: viewModel, isLoadingCollections: $isLoadingCollections)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                
                if viewModel.isSearchVisible {
                    SearchInput(viewModel: viewModel)
                        .padding(.bottom, 2)
                }
                
                SoftSeparator()
                    .opacity(isScrolled ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.15), value: isScrolled)
            
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    DatabaseList(viewModel: viewModel, isLoadingCollections: $isLoadingCollections)
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
        .padding(.bottom, 10)
        .padding(.leading, 4)
        .cornerRadius(16)
        .task {
            do {
                isLoadingCollections = true
                try await viewModel.activeConnection?.connect()
            } catch {
                
            }
        }
    }
}
