//
//  SidebarSplitViewBridge.swift
//  Pluk
//

import AppKit
import SwiftUI

struct SidebarSplitViewBridge<Sidebar: View, Content: View>: NSViewControllerRepresentable {
    let sidebar: Sidebar
    let content: Content
    let minSidebarWidth: CGFloat

    init(
        sidebar: Sidebar,
        content: Content,
        minSidebarWidth: CGFloat = 330
    ) {
        self.sidebar = sidebar
        self.content = content
        self.minSidebarWidth = minSidebarWidth
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSViewController(context: Context) -> SidebarSplitViewController {
        let sidebarHost = NSHostingController(rootView: sidebar)
        let contentHost = NSHostingController(rootView: content)

        let config = SidebarSplitViewController.Configuration(
            minWidth: minSidebarWidth,
            autosaveName: "PlukSidebarSplitView"
        )

        let controller = SidebarSplitViewController(
            sidebarController: sidebarHost,
            contentController: contentHost,
            configuration: config
        )

        context.coordinator.sidebarHost = sidebarHost
        context.coordinator.contentHost = contentHost

        return controller
    }

    func updateNSViewController(_ controller: SidebarSplitViewController, context: Context) {
        if let sidebarHost = context.coordinator.sidebarHost as? NSHostingController<Sidebar> {
            sidebarHost.rootView = sidebar
        }
        if let contentHost = context.coordinator.contentHost as? NSHostingController<Content> {
            contentHost.rootView = content
        }
    }

    final class Coordinator {
        weak var sidebarHost: NSViewController?
        weak var contentHost: NSViewController?
    }
}
