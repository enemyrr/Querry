//
//  HomeView.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/17/25.
//

import Foundation
import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("My Collections")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("Your central hub for collection management")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(ActionButtonStyle())
                    .tint(.secondary)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
                .padding(.bottom, 6)
                
                CustomListView(items: [
                    ListItem(
                        icon: "hand.wave.fill",
                        name: "How to use mongodb",
                        itemCount: 3,
                        updatedAt: Date().addingTimeInterval(-3600),
                        createdAt: Date().addingTimeInterval(-72000)
                    ),
                    ListItem(
                        icon: "folder.fill",
                        name: "Documents",
                        itemCount: 5,
                        updatedAt: Date().addingTimeInterval(-1800),
                        createdAt: Date().addingTimeInterval(-86400)
                    )
                ])
                
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.blue.gradient.opacity(0.02))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator, lineWidth: 1)
            )
            .cornerRadius(10)
            .padding(8)
        }
    }
}


public struct ListItem: Identifiable {
    public let id = UUID()
     public let icon: String
     public let name: String
     public let itemCount: Int
     public let updatedAt: Date
     public let createdAt: Date
    
    public init(icon: String, name: String, itemCount: Int, updatedAt: Date, createdAt: Date) {
           self.icon = icon
           self.name = name
           self.itemCount = itemCount
           self.updatedAt = updatedAt
           self.createdAt = createdAt
       }
}

// Made struct internal (default access level)
struct ListRowView: View {
    let item: ListItem
    @State private var isHovering = false
    
    init(item: ListItem) {  // Add public initializer
        self.item = item
    }
    
    var body: some View {
        HStack {
            // Name column with icon
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .foregroundStyle(.yellow)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .foregroundStyle(.primary)
                    
                    Text("\(item.itemCount) items")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                }
            }
            .frame(width: 200, alignment: .leading)
            
            Spacer()
            
            // Updated time
            Text(item.updatedAt.formatted(date: .omitted, time: .shortened))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            
            // Created time
            Text(item.updatedAt.formatted(date: .omitted, time: .shortened))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.black.opacity(0.3) : Color.clear)
        )
        .onHover { hovering in
                   withAnimation(.easeInOut(duration: 0.15)) {  // Add smooth hover transition
                       isHovering = hovering
                   }
               }
    }
    
    private var relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}

struct CustomListView: View {
    let items: [ListItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header view
            HStack {
                Text("Name")
                    .frame(width: 200, alignment: .leading)
                
                Spacer()
                
                Text("Updated")
                    .frame(width: 120, alignment: .leading)
                
                Text("Created")
                    .frame(width: 120, alignment: .leading)
            }
            .foregroundStyle(.secondary)
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider().padding(.bottom, 6)
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        ListRowView(item: item)
                    }
                }
            }
        }
    }
}



// Preview
#Preview {
    CustomListView(items: [
        ListItem(
            icon: "hand.wave.fill",
            name: "How to use Craft",
            itemCount: 3,
            updatedAt: Date().addingTimeInterval(-3600),
            createdAt: Date().addingTimeInterval(-72000)
        ),
        ListItem(
            icon: "folder.fill",
            name: "Documents",
            itemCount: 5,
            updatedAt: Date().addingTimeInterval(-1800),
            createdAt: Date().addingTimeInterval(-86400)
        )
    ])
    .frame(width: 600, height: 400)
}
