//
//  Anything.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/3/25.
//
import SwiftUI

struct TabBar: View {
    @Binding var tabs: [String]
    @Binding var selectedTab: String?
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Button {
                            previousTab((selectedTab ?? tabs.first)!)
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 6, height: 12)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                        }
                        .disabled(
                            selectedTab == tabs.first
                        )
                        .buttonStyle(.plain)
                        
                        Button {
                            nextTab((selectedTab ?? tabs.first)!)
                        } label: {
                            HStack {
                                Image(systemName: "chevron.right")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 6, height: 12)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                        }
                        .disabled(
                            selectedTab == tabs.last
                        )
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    Divider()
                    
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        TabBarItem(tab: tab, isSelected: selectedTab == tab, onSelect: {
                            selectedTab = tab
                            proxy.scrollTo(tab, anchor: nil)
                        }, onClose: {
                            removeTab(tab)
                        })
                        .id(tab)
                        
                        Divider()
                    }
                }
            }
            .frame(height: 30)
        }
    }
    
    private func removeTab(_ item: String) {
        if let index = tabs.firstIndex(where: { $0 == item }) {
            tabs.remove(at: index)
            if selectedTab == item {
                selectedTab = tabs.last
            }
        }
    }
    
    private func nextTab(_ currentItem: String) {
        if let currentIndex = tabs.firstIndex(where: { $0 == currentItem }) {
            // If we're at the last tab, do nothing
            if currentIndex == tabs.count - 1 {
                return
            } else {
                // Otherwise, move to the next tab
                selectedTab = tabs[currentIndex + 1]
            }
        }
    }
    private func previousTab(_ currentItem: String) {
        if let currentIndex = tabs.firstIndex(where: { $0 == currentItem }) {
            // If we're at the first tab, wrap around to the last tab
            if currentIndex == 0 {
                return
            } else {
                // Otherwise, move to the previous tab
                selectedTab = tabs[currentIndex - 1]
            }
        }
    }
    
}

struct TabBarItem: View {
    let tab: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 8) {
                if isSelected {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .resizable()
                            .frame(width: 10, height: 10)
                            .foregroundColor(Color(.gray))
                    }.buttonStyle(.plain)
                } else {
                    Spacer(minLength: 10)
                }
                
                Text(tab)
                    .foregroundColor(isSelected ? .white : Color(.gray))
                
                Spacer(minLength: 10)
            }
            .frame(alignment: .center)
            .padding(.horizontal, 4)
        }
        .padding(7)
        .background(isSelected ? Color(NSColor.systemFill) : .clear)
        .buttonStyle(.plain)
    }
}
