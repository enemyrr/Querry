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
    var instance: ConnectionInstance
    
    var body: some View {
        VStack(spacing: 0) {
            TabBar(instance: instance)
                .padding(.bottom, -1)
                .zIndex(1)
            
            NSTabViewWrapper(instance: instance)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding([.leading, .trailing, .bottom], 8)
            .zIndex(-1)
        }
        .padding(.top, 8)
        .ignoresSafeArea(.all)
        .zIndex(-1)
    }
}



class TabContentView: NSView {
    let tab: DatabaseTab
    let instance: ConnectionInstance
    private var contentView: NSView?
    
    init(tab: DatabaseTab, instance: ConnectionInstance) {
        self.tab = tab
        self.instance = instance
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
        layer?.cornerRadius = 8.0
        
        switch instance.connection.databaseType {
        case .postgres:
            setupPostgresView()
            
        case .mongodb:
            setupMongoDBView()
            
        default:
            setupDefaultView()
        }
    }
    
    private func setupPostgresView() {
        let viewModel = instance.viewModel(for: tab)
        let tableListView = TableListView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: tableListView)
        setContentView(hostingView)
    }
    
    private func setupMongoDBView() {
        let viewModel = instance.viewModel(for: tab)
        let documentList = DocumentList(viewModel: viewModel)
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
