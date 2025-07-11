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
    
    var body: some View {
        VStack(spacing: 0) {
            TabBar()
            
            if instance.tabs.isEmpty  {
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
                                    .stroke(.separator, lineWidth: 1)
                            )
                    }
                    .padding(.bottom, 10)
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center
                )
                .background(
                    Color(colorScheme == .dark ? .black : .white).opacity(0.6)
                )
                .cornerRadius(16)
                .padding(.top, 0)
                .padding([.horizontal, .bottom], 8)
                .onAppear {
                    setupEventMonitor()
                }
                .onDisappear {
                    removeEventMonitor()
                }
            } else {
                NSTabViewWrapper()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding([.leading, .trailing, .bottom], 8)
            }
        }
        
        .id(instance.id)
        .padding(.top, 8)
        .ignoresSafeArea(.all)
        .postHogScreenView("DocumentView")
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
    let selectedTab: DatabaseTab?
    private var contentView: NSView?
    
    init(tab: DatabaseTab, databaseType: DatabaseType, selectedTab: DatabaseTab?) {
        self.tab = tab
        self.databaseType = databaseType
        self.selectedTab = selectedTab
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        
        // Add simple border around content
//        layer?.borderWidth = 1.0
//        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.cornerRadius = 16.0
        
        switch databaseType {
        case .postgres:
            setupPostgresView()
            
        case .mongodb:
            setupMongoDBView()
            
        default:
            setupDefaultView()
        }
    }
    
    private func setupPostgresView() {
        if let selectedTab = selectedTab {
            let tableListView = TableListView(
                selectedTab: selectedTab
            )
            let hostingView = NSHostingView(rootView: tableListView)
            setContentView(hostingView)
        }
    }
    
    private func setupMongoDBView() {
        if let selectedTab = selectedTab {
            let documentList = DocumentList(selectedTab: selectedTab)
            let hostingView = NSHostingView(rootView: documentList)
            setContentView(hostingView)
        }
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
