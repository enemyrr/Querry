//
//  CustomSplitView.swift
//  Pluk
//

import SwiftUI

struct CustomSplitView<SidebarContent: View, DetailContent: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    private let sidebarContent: SidebarContent
    private let detailContent: DetailContent
    private let isFixedSidebar: Bool

    @State private var isSidebarVisible = true

    init(
        @ViewBuilder sidebar: () -> SidebarContent,
        @ViewBuilder detail: () -> DetailContent,
        isFixedSidebar: Bool = false
    ) {
        self.sidebarContent = sidebar()
        self.detailContent = detail()
        self.isFixedSidebar = isFixedSidebar
    }

    var body: some View {
        Group {
            if isFixedSidebar {
                FixedSidebarLayout(sidebar: sidebarContent, detail: detailContent)
            } else {
                SidebarSplitViewBridge(
                    sidebar: sidebarContent
                        .frame(minWidth: 330)
                        .ignoresSafeArea(.container, edges: .top),
                    content: detailContent.ignoresSafeArea(),
                    minSidebarWidth: 330
                )
                .ignoresSafeArea(.container, edges: .top)
            }
        }
        .background(
            BackgroundPanel(
                colorScheme: colorScheme,
                leadingPadding: sidebarLeadingPadding,
                isSidebarVisible: isSidebarVisible
            )
        )
        .onReceive(NotificationCenter.default.publisher(for: .sidebarAnimationWillStart)) { notification in
            let isCollapsing = notification.userInfo?["isCollapsing"] as? Bool ?? false
            withAnimation(.easeOut(duration: 0.2)) {
                isSidebarVisible = !isCollapsing
            }
        }
    }

    private var sidebarLeadingPadding: CGFloat {
        if isFixedSidebar || isSidebarVisible {
            return 44
        }
        return 2
    }
}

private struct FixedSidebarLayout<Sidebar: View, Detail: View>: View {
    let sidebar: Sidebar
    let detail: Detail

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 50)
                .ignoresSafeArea(.container, edges: .top)
            detail
                .ignoresSafeArea()
        }
    }
}

private struct BackgroundPanel: View {
    let colorScheme: ColorScheme
    let leadingPadding: CGFloat
    let isSidebarVisible: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(backgroundColor)
            .padding(.top, 6)
            .padding(.leading, leadingPadding)
            .padding([.horizontal, .bottom], 6)
            .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.10), radius: 4)
            .animation(.easeInOut(duration: 0.2), value: isSidebarVisible)
    }

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(.black).opacity(0.40)
            : Color(.controlBackgroundColor).opacity(0.86)
    }
}
