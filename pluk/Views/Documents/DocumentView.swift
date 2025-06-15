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
    var body: some View {
        VStack(spacing: 0) {
            TabBar()
                .padding(.bottom, -1)
                .zIndex(1)
            
            NSTabViewWrapper()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding([.leading, .trailing, .bottom], 8)
                .zIndex(-1)
        }
        .id(instance.id)
        .padding(.top, 8)
        .ignoresSafeArea(.all)
        .zIndex(-1)
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
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor.separatorColor.cgColor
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
