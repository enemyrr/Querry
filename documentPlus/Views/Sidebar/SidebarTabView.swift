
//
//  SidebarCollectionView.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/17/25.
//
import SwiftUI

struct SidebarTabView: View {
    @State private var appState = AppState.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ScrollView {
                    SidebarConnectionsView()
                }
                .frame(maxWidth: .infinity)
                .offset(x: appState.activeSiderbarTabOffset)
                .zIndex(appState.activeSidebarTab == .connections ? 1 : 0)
                
                ScrollView {
                    SidebarConnectionDetailsView()
                }
                .frame(maxWidth: .infinity)
                .offset(x: geometry.size.width + appState.activeSiderbarTabOffset)
                .zIndex(appState.activeSidebarTab == .connection_details ? 1 : 0)
            }
            .onAppear {
                appState.setSidebarWidth(geometry.size.width)
            }
            .onChange(of: geometry.size.width) { oldValue, newValue in
                appState.setSidebarWidth(geometry.size.width)
            }
            .clipped()
            .overlay(alignment: .bottom) {
                SwipePageIndicator(
                    scrollOffset: appState.activeSiderbarTabOffset,
                    width: geometry.size.width,
                    onPageChange: { page in
                        withAnimation(.spring(duration: 0.3)) {
                            if page == 0 {
                                appState.activeSiderbarTabOffset = 0
                                appState.activeSidebarTab = .connections
                            } else {
                                appState.activeSiderbarTabOffset = -geometry.size.width
                                appState.activeSidebarTab = .connection_details
                            }
                        }
                    }
                )
                .padding(.bottom, 8)
            }
            .overlay(
                SwipeDetectionView(
                    sidebarActiveTab: $appState.activeSidebarTab,
                    scrollOffset: $appState.activeSiderbarTabOffset,
                    viewWidth: geometry.size.width
                )
                .allowsHitTesting(false)
            )
        }
    }
}
