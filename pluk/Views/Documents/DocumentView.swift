//
//  DatabaseView.swift
//  Collection
//
//  Created by Fauzaan on 1/17/25.
//

import Foundation
import SwiftUI

struct DocumentView: View {
    var instance: ConnectionInstance
    
    var body: some View {
        VStack(spacing: 0) {
            TabBar(instance: instance)
                .zIndex(1)
            
            VStack {
                if let selectedTab = instance.selectedTab {
                    switch instance.connection.databaseType {
                    case .postgres:
                                TableListView(viewModel: instance.viewModel(for: selectedTab))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .id(selectedTab.id)
                            case .mongodb:
                        DocumentList(viewModel: instance.viewModel(for: selectedTab))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .id(selectedTab.id)
                    default:
                        Text("No collection selected")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                } else {
                    Text("No collection selected")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding([.leading, .trailing, .bottom], 8)
            .zIndex(-1)
        }
        .padding(.top, 8)
        .ignoresSafeArea(.all)
        .zIndex(-1)
    }
}

//import SwiftUI
//
//import SwiftUI
//
//struct DocumentView: View {
//    var instance: ConnectionInstance
//    @State private var selectedTab = 0
//    @State private var tabs = [
//        Tab(id: 0, title: "Personal", isClosable: true),
//        Tab(id: 1, title: "The Best Slack Alter...", isClosable: true),
//        Tab(id: 2, title: "COCOA - NSTableView", isClosable: true),
//        Tab(id: 3, title: "NSTableView sizeToFit", isClosable: true),
//        Tab(id: 4, title: "NSTableColumn", isClosable: true),
//        Tab(id: 5, title: "SwiftUI vs AppKit Te...", isClosable: true)
//    ]
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // Custom Tab Bar
//            TabBarView(
//                tabs: $tabs,
//                selectedTab: $selectedTab
//            )
//            
//            // Main Content Area
//            TabContentView(selectedTab: selectedTab)
//        }
//    }
//}
//
//struct TabShape: Shape {
//    let isSelected: Bool
//    
//    func path(in rect: CGRect) -> Path {
//        var path = Path()
//        
//        if isSelected {
//            // Start from bottom left
//            path.move(to: CGPoint(x: 0, y: rect.height))
//            // Line to top left with rounded corner
//            path.addLine(to: CGPoint(x: 0, y: 8))
//            path.addQuadCurve(to: CGPoint(x: 8, y: 0), control: CGPoint(x: 0, y: 0))
//            // Top line
//            path.addLine(to: CGPoint(x: rect.width - 8, y: 0))
//            // Top right rounded corner
//            path.addQuadCurve(to: CGPoint(x: rect.width, y: 8), control: CGPoint(x: rect.width, y: 0))
//            // Line to bottom right
//            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
//            // Close the path at bottom
//            path.addLine(to: CGPoint(x: 0, y: rect.height))
//        }
//        
//        return path
//    }
//}
//
//struct Tab: Identifiable, Hashable {
//    let id: Int
//    var title: String
//    var isClosable: Bool = true
//}
//
//struct TabBarView: View {
//    @Binding var tabs: [Tab]
//    @Binding var selectedTab: Int
//    @State private var hoveredTab: Int? = nil
//    
//    var body: some View {
//        HStack(spacing: 0) {
//            // Tab buttons
//            ForEach(tabs) { tab in
//                TabButtonView(
//                    tab: tab,
//                    isSelected: selectedTab == tab.id,
//                    isHovered: hoveredTab == tab.id,
//                    onSelect: { selectedTab = tab.id },
//                    onClose: { closeTab(tab.id) },
//                    onHover: { isHovered in
//                        hoveredTab = isHovered ? tab.id : nil
//                    }
//                )
//            }
//            
//            // Add new tab button
//            Button(action: addNewTab) {
//                Image(systemName: "plus")
//                    .font(.system(size: 11, weight: .medium))
//                    .foregroundColor(.secondary)
//                    .frame(width: 24, height: 32)
//            }
//            .buttonStyle(PlainButtonStyle())
//            .contentShape(Rectangle())
//            
//            Spacer()
//            
//            // Right side controls
//            HStack(spacing: 8) {
//                Button(action: {}) {
//                    Text("Personalize")
//                        .font(.system(size: 11))
//                        .foregroundColor(.secondary)
//                }
//                .buttonStyle(PlainButtonStyle())
//                
//                Text("Off")
//                    .font(.system(size: 11))
//                    .foregroundColor(.secondary)
//            }
//            .padding(.trailing, 16)
//        }
//        .frame(height: 40)
//        .background(Color.clear)
//    }
//    
//    private func closeTab(_ tabId: Int) {
//        tabs.removeAll { $0.id == tabId }
//        if selectedTab == tabId && !tabs.isEmpty {
//            selectedTab = tabs.first?.id ?? 0
//        }
//    }
//    
//    private func addNewTab() {
//        let newId = (tabs.map(\.id).max() ?? -1) + 1
//        tabs.append(Tab(id: newId, title: "New Tab", isClosable: true))
//        selectedTab = newId
//    }
//}
//
//struct TabButtonView: View {
//    let tab: Tab
//    let isSelected: Bool
//    let isHovered: Bool
//    let onSelect: () -> Void
//    let onClose: () -> Void
//    let onHover: (Bool) -> Void
//    
//    var body: some View {
//        HStack(spacing: 6) {
//            // Tab icon (colored circle)
//            Circle()
//                .fill(tabIconColor)
//                .frame(width: 8, height: 8)
//            
//            // Tab title
//            Text(tab.title)
//                .font(.system(size: 12))
//                .foregroundColor(isSelected ? .primary : .secondary)
//                .lineLimit(1)
//                .truncationMode(.tail)
//            
//            // Close button
//            if tab.isClosable && (isSelected || isHovered) {
//                Button(action: onClose) {
//                    Image(systemName: "xmark")
//                        .font(.system(size: 8, weight: .medium))
//                        .foregroundColor(.secondary)
//                        .frame(width: 12, height: 12)
//                }
//                .buttonStyle(PlainButtonStyle())
//                .contentShape(Rectangle())
//            }
//        }
//        .padding(.horizontal, 12)
//        .frame(height: 32)
//        .frame(maxWidth: 200)
//        .background(
//            TabShape(isSelected: isSelected)
//                .fill(isSelected ? Color(NSColor.textBackgroundColor).opacity(0.5) : Color.clear)
//        )
//        .contentShape(Rectangle())
//        .onTapGesture { onSelect() }
//        .onHover { hovering in
//            onHover(hovering)
//        }
//    }
//    
//    private var tabIconColor: Color {
//        // Different colors for different tabs to match the design
//        let colors: [Color] = [
//            .orange, .blue, .orange, .gray, .blue, .green
//        ]
//        return colors[tab.id % colors.count]
//    }
//}
//
//struct TabContentView: View {
//    let selectedTab: Int
//    
//    var body: some View {
//        ZStack {
//            Color(NSColor.textBackgroundColor).opacity(0.5)
//            
//            VStack {
//                Spacer()
//                
//                // Center content area with search
//                VStack(spacing: 20) {
//                    HStack {
//                        Image(systemName: "magnifyingglass")
//                            .foregroundColor(.secondary)
//                        Text("Mention a tab...")
//                            .foregroundColor(.secondary)
//                        Spacer()
//                    }
//                    .padding(.horizontal, 16)
//                    .frame(height: 44)
//                    .background(
//                        RoundedRectangle(cornerRadius: 8)
//                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
//                    )
//                    .frame(maxWidth: 400)
//                    
//                    HStack {
//                        Image(systemName: "plus")
//                            .foregroundColor(.secondary)
//                        Text("Add tabs or files")
//                            .foregroundColor(.secondary)
//                        Spacer()
//                        Button(action: {}) {
//                            Image(systemName: "mic")
//                                .foregroundColor(.secondary)
//                        }
//                        .buttonStyle(PlainButtonStyle())
//                    }
//                    .padding(.horizontal, 16)
//                    .frame(height: 44)
//                    .background(
//                        RoundedRectangle(cornerRadius: 8)
//                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
//                    )
//                    .frame(maxWidth: 400)
//                }
//                
//                Spacer()
//            }
//            .padding()
//        }
//    }
//}
