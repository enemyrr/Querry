//
//  DatabaseView.swift
//  Collection
//
//  Created by Fauzaan on 1/17/25.
//

import Foundation
import SwiftUI
import AppKit

struct DocumentView: View {
    @Environment(ConnectionInstance.self) private var instance
    @Environment(\.colorScheme) var colorScheme
    @State private var commandFilter: String = ""
    @State private var isCommandBarVisible: Bool = false
    @State private var eventMonitor: Any?
    @Environment(AppViewModel.self) private var appViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            if instance.tabs.isEmpty  {
                ZStack {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                Color(Color(.black).opacity(0.25))
                            )
                            .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                Color(hex: "#FDFDFD")
                            )
                            .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 4)
                    }

                    VStack {
                        Spacer()

                        if isCommandBarVisible {
                            VStack(spacing: 0) {
                                CommandPalette.CollectionsList(
                                    searchText: $commandFilter,
                                    onBack: {},
                                )

                                CommandPalette(
                                    searchText: $commandFilter,
                                    onBack: {},
                                    isBackButtonEnabled: false
                                )
                                .modifier(GlassBackgroundStyle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(.separator)
                                )
                            }
                            .padding(.bottom, 10)
                        }

                        Spacer()
                    }
                }
                .padding([.trailing, .bottom], 12)
                .padding([.leading], appViewModel.isSidebarVisible ? 2 : 12)
                .padding(.top, 40)
                .animation(.spring(response: 0.35, dampingFraction: 1.0), value: appViewModel.isSidebarVisible)
               
                .background(
                    // Add hidden for new tab
                    Button(action: {
                        instance.createSQLEditorTab()
                    }) {
                        EmptyView()
                    }
                    .hidden()
                    .keyboardShortcut("t", modifiers: [.command])
                    .opacity(0)
                    .accessibilityHidden(true)
                )
                .onAppear {
                    setupEventMonitor()
                }
                .onDisappear {
                    removeEventMonitor()
                }
            } else {
                TabBar()
                    .padding(.top, {
                        if #available(macOS 26, *) {
                            return 0
                        } else {
                            return -2
                        }
                    }())

                HStack(spacing: 0) {
                    NSTabViewWrapper()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.08), radius: 4)

                    if appViewModel.isRightSidebarVisible {
                        RowDetailSidebar()
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                )
                            )
                            .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.08), radius: 4)
                    }
                }
                .padding([.trailing, .bottom], 12)
                .padding([.leading], appViewModel.isSidebarVisible ? 2 : 12)
                .padding(.top, 6)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: appViewModel.isRightSidebarVisible)
                .animation(.spring(response: 0.35, dampingFraction: 1.0), value: appViewModel.isSidebarVisible)
            }
        }
        .postHogScreenView("DocumentView")
        .onReceive(NotificationCenter.default.publisher(for: .toggleRightSidebar)) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                appViewModel.isRightSidebarVisible.toggle()
            }
        }
    }
    
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            switch event.keyCode {
            case 35: // 'p' key
                if event.modifierFlags.contains(.command) {
                    isCommandBarVisible.toggle()
                    // Clear search text when hiding
                    if !isCommandBarVisible {
                        commandFilter = ""
                    }
                    return nil // Consume the event
                }
                return event // Let it pass through if not Command+P

            case 53: // 'esc' key
                if isCommandBarVisible {
                    isCommandBarVisible = false
                    return nil
                }
                return event
            default:
                return event // Let other keys pass through
            }
        }
    }
    
    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}




class TabContentView: NSView {
    let tab: DatabaseTab
    let databaseType: DatabaseType
    private var contentView: NSView?

    init(tab: DatabaseTab, databaseType: DatabaseType) {
        self.tab = tab
        self.databaseType = databaseType
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        
        layer?.cornerRadius = 8.0
        
        switch databaseType {
        case .postgres, .sqlite, .mysql, .convex:
            setupTableView()
            
        case .mongodb:
            setupMongoDBView()
            
        default:
            setupDefaultView()
        }
    }
    
    private func setupTableView() {
        let hostingView: NSHostingView<AnyView>

        switch tab.type {
        case .browse, .aggregate, .schema, .indexes:
            let tableListView = TableListView(selectedTab: tab)
            hostingView = NSHostingView(rootView: AnyView(tableListView))
        case .sqlEditor:
            let sqlEditorView = SQLEditorView()
            hostingView = NSHostingView(rootView: AnyView(sqlEditorView))
        }

        setContentView(hostingView)
    }

    private func setupMongoDBView() {
        let documentList = DocumentList(selectedTab: tab)
        let hostingView = NSHostingView(rootView: documentList)
        setContentView(hostingView)
    }
    
    private func setupDefaultView() {
        let noSelectionView = NSView()
        let label = NSTextField(labelWithString: "No collection selected")
        label.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        label.textColor = NSColor.secondaryLabelColor
        label.alignment = .center
        
        noSelectionView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: noSelectionView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: noSelectionView.centerYAnchor)
        ])
        
        setContentView(noSelectionView)
    }
    
    private func setContentView(_ view: NSView) {
        // Remove existing content view if any
        contentView?.removeFromSuperview()

        // Set new content view
        contentView = view
        addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    // Method to update the content when tab data changes
    func updateContent() {
        setupView()
    }
}
