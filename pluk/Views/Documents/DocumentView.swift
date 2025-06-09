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
        
        // Add custom border (excluding top border for seamless tab integration)
        addCustomBorder()
        
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
    
    private func addCustomBorder() {
        // Remove any existing border layers
        layer?.sublayers?.removeAll { $0.name == "customBorder" }
        
        let borderLayer = CAShapeLayer()
        borderLayer.name = "customBorder"
        borderLayer.strokeColor = NSColor.separatorColor.cgColor
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.lineWidth = 1.0
        
        // Create path for container with top corners but no connecting top border
        let path = NSBezierPath()
        let cornerRadius: CGFloat = 8.0
        let rect = bounds
        
        // Start from bottom-left corner
        path.move(to: NSPoint(x: cornerRadius, y: 0))
        
        // Bottom border to bottom-right
        path.line(to: NSPoint(x: rect.width - cornerRadius, y: 0))
        
        // Bottom-right corner
        path.curve(to: NSPoint(x: rect.width, y: cornerRadius),
                  controlPoint1: NSPoint(x: rect.width - cornerRadius/2, y: 0),
                  controlPoint2: NSPoint(x: rect.width, y: cornerRadius/2))
        
        // Right border up
        path.line(to: NSPoint(x: rect.width, y: rect.height - cornerRadius))
        
        // Top-right corner
        path.curve(to: NSPoint(x: rect.width - cornerRadius, y: rect.height),
                  controlPoint1: NSPoint(x: rect.width, y: rect.height - cornerRadius/2),
                  controlPoint2: NSPoint(x: rect.width - cornerRadius/2, y: rect.height))
        
        // Start new path segment for left side (gap in between for tab)
        path.move(to: NSPoint(x: cornerRadius, y: rect.height))
        
        // Top-left corner
        path.curve(to: NSPoint(x: 0, y: rect.height - cornerRadius),
                  controlPoint1: NSPoint(x: cornerRadius/2, y: rect.height),
                  controlPoint2: NSPoint(x: 0, y: rect.height - cornerRadius/2))
        
        // Left border down
        path.line(to: NSPoint(x: 0, y: cornerRadius))
        
        // Bottom-left corner
        path.curve(to: NSPoint(x: cornerRadius, y: 0),
                  controlPoint1: NSPoint(x: 0, y: cornerRadius/2),
                  controlPoint2: NSPoint(x: cornerRadius/2, y: 0))
        
        borderLayer.path = path.cgPath
        layer?.addSublayer(borderLayer)
    }
    
    override func layout() {
        super.layout()
        // Update border when view bounds change
        addCustomBorder()
    }
}
