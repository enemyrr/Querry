//
//  Anything.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/3/25.
//

import SwiftUI

// Custom Tab Bar
struct TabBar: View {
    @Binding var tabs: [ContentItem]
    @Binding var selectedTab: ContentItem?
    
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
                        TabBarItem(tab: tab, isSelected: selectedTab?.id == tab.id, onSelect: {
                            selectedTab = tab
                            proxy.scrollTo(tab.title, anchor: nil)
                        }, onClose: {
                            removeTab(tab)
                        })
                        .id(tab.title)
                        
                        Divider()
                    }
                }
            }
            .frame(height: 30)
        }
    }
    
    private func removeTab(_ item: ContentItem) {
        if let index = tabs.firstIndex(where: { $0.id == item.id }) {
            tabs.remove(at: index)
            if selectedTab == item {
                selectedTab = tabs.last
            }
        }
    }
    
    private func nextTab(_ currentItem: ContentItem) {
        if let currentIndex = tabs.firstIndex(where: { $0.id == currentItem.id }) {
            // If we're at the last tab, do nothing
            if currentIndex == tabs.count - 1 {
                return
            } else {
                // Otherwise, move to the next tab
                selectedTab = tabs[currentIndex + 1]
            }
        }
    }
    private func previousTab(_ currentItem: ContentItem) {
        if let currentIndex = tabs.firstIndex(where: { $0.id == currentItem.id }) {
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

// Individual Tab Item
struct TabBarItem: View {
    let tab: ContentItem
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
                
                Text(tab.title.capitalized)
                    .foregroundColor(isSelected ? .white : Color(.gray))
                
                Spacer(minLength: 10)
            }
            .frame(alignment: .center)
            .padding(.horizontal, 4)
        }
        .padding(7)
        .background(isSelected ? Color(.darkGray) : .clear)
        .buttonStyle(.plain)
    }
}

struct ContentItem: Identifiable, Equatable {
    let id = UUID()
    var title: String
    
    static func == (lhs: ContentItem, rhs: ContentItem) -> Bool {
        return lhs.id == rhs.id && lhs.title == rhs.title
    }
}

// Content Detail View
struct ContentDetailView: View {
    @Binding var documents: [ProcessedDocument]
    
    init(documents: Binding<[ProcessedDocument]>) {
        _documents = documents
    }
    
    var body: some View {
        CollectionDetailView(documents: documents)
    }
}
