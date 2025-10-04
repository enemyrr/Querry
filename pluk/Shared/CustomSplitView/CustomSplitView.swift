//
//  CustomSplitView.swift
//  Collection
//
//  Created by Fauzaan on 1/16/25.
//
import SwiftUI

struct CustomSplitView<SidebarContent: View, DetailContent: View>: View {
    @Environment(\.currentDatabaseType) private var currentDatabaseType
    @Environment(SidebarViewModel.self) private var sidebarViewModel

    @State private var overlayContentWidth: CGFloat = 0
    @State private var hostingWindow: NSWindow?

    private let sidebarContent: SidebarContent
    private let detailContent: DetailContent
    private let isFullScreenView: Bool
    private let connectionInstance: ConnectionInstance?
    @Binding var isSidebarVisible: Bool

    init(@ViewBuilder sidebar: () -> SidebarContent,
         @ViewBuilder detail: () -> DetailContent,
         isFullScreenView: Bool = false,
         isSidebarVisible: Binding<Bool>,
         connectionInstance: ConnectionInstance? = nil
    ) {
        self.sidebarContent = sidebar()
        self.detailContent = detail()
        self.isFullScreenView = isFullScreenView
        _isSidebarVisible = isSidebarVisible
        self.connectionInstance = connectionInstance
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            NativeAppKitSplitView(
                left: sidebarContent
                    .frame(minWidth: isFullScreenView ? 50 : 350)
                    .ignoresSafeArea(.container, edges: .top),
                right: detailContent
                    .environment(\.leadingOverlayWidth, overlayContentWidth)
                    .ignoresSafeArea(),
                isSidebarVisible: $isSidebarVisible,
                isFixedSidebar: isFullScreenView, // HomeView uses fixed sidebar
                fixedSidebarWidth: 50,
                minSidebarWidth: 350 // Minimum width for resizable sidebars
            )
            .ignoresSafeArea(.container, edges: .top)
            .background(WindowAccessor { win in
                if hostingWindow !== win { hostingWindow = win }
            })
        }
    }

    private func toggleSidebar() {
        isSidebarVisible.toggle()
    }

    private func currentEnvironmentTitle(_ instance: ConnectionInstance) -> String {
        instance.connectedDatabase?.name ?? "Select Environment"
    }

    private func openEnvironmentInNewTab(instance: ConnectionInstance, database: any DatabaseWrapper) {
        Task {
            if let instanceId = await ConnectionService.shared.openEnvironmentInNewTab(from: instance, databaseName: database.name) {
                // Sidebar change happens immediately - connection happens in background
                await MainActor.run {
                    sidebarViewModel.changeActiveSidebarItem(.connection(instanceId))
                }
            }
        }
    }
}


