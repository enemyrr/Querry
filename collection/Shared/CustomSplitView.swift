//
//  CustomSidebar.swift
//  Collection
//
//  Created by Fauzaan on 1/16/25.
//

import SwiftUI
import AppKit

struct CustomSplitView<SidebarContent: View, DetailContent: View>: View {
    private let minSidebarWidth: CGFloat = 200
    private let maxSidebarWidth: CGFloat = 400
    private let defaultSidebarWidth: CGFloat = 260
    @Namespace private var animation
    

    @AppStorage("sidebarWidth") private var sidebarWidth: Double = 260
    @State private var isResizing: Bool = false
    @State private var previousWidth: CGFloat = 260
    @State private var dragOffset: CGFloat = 0
    
    private let sidebarContent: SidebarContent
    private let detailContent: DetailContent
    private let isFullScreenView: Bool
    @Binding var isSidebarVisible: Bool

    init(@ViewBuilder sidebar: () -> SidebarContent,
         @ViewBuilder detail: () -> DetailContent,
         isFullScreenView: Bool = false,
         isSidebarVisible: Binding<Bool>
    ) {
        self.sidebarContent = sidebar()
        self.detailContent = detail()
        self.isFullScreenView = isFullScreenView
        _isSidebarVisible = isSidebarVisible
        
        _sidebarWidth = AppStorage(wrappedValue: defaultSidebarWidth, "sidebarWidth")
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                sidebarContainer
            }
            
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                        .imageScale(.large)
                }
                .padding(.top, 6)
                .keyboardShortcut("[", modifiers: [.command])
                .customHelp("Toggle Sidebar", position: .bottom, shortcut: KeyboardShortcut(
                    modifiers: [.command],
                    key: "["
                ))
            }
        }
    }
    
    private var sidebarContainer: some View {
        ZStack(alignment: .trailing) {
            let finalSidebarWidth = isFullScreenView ? 50 : sidebarWidth
            
            sidebarContent
                .frame(width: isResizing ?
                       max(minSidebarWidth, min(sidebarWidth + dragOffset, maxSidebarWidth)) : finalSidebarWidth)
                .padding(.trailing, isFullScreenView ? -8 : 0)
            
            // TODO: Enable when stable
//            if (!isFullScreenView) {
//                resizeHandle
//            }
        }
        .transition(.move(edge: .leading).combined(with: .opacity))
        .matchedGeometryEffect(id: "sidebar", in: animation)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSidebarVisible)
    }
    
    private var resizeHandle: some View {
        Rectangle()
            .offset(x: 20)
            .fill(Color(.clear))
            .frame(width: 4)
            .contentShape(Rectangle())
            .opacity(0)
            .onHover { inside in
                if inside {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { gesture in
                        dragOffset = gesture.translation.width
                        isResizing = true
                    }
                    .onEnded { gesture in
                        sidebarWidth = max(minSidebarWidth, min(sidebarWidth + dragOffset, maxSidebarWidth))
                        dragOffset = 0
                        isResizing = false
                    }
            )
    }
    
    private func toggleSidebar() {
        if isSidebarVisible {
            previousWidth = sidebarWidth
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSidebarVisible.toggle()
            if isSidebarVisible {
                sidebarWidth = previousWidth
            }
        }
    }
}
