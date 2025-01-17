//
//  WelcomeWindow.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/4/25.
//

import SwiftUI
import SwiftData
import AppKit
import MongoKitten

enum NavigationItem: Hashable {
    case home
    case database(String)
}


struct SidebarButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    let isActive: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    (isActive || isHovering) ?
                    (colorScheme == .dark ? Color.black : Color.white).opacity(
                        (isActive && isHovering) ? 0.2 : 0.3
                    )
                    : Color.clear
                )
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct ActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isHovering ?
                    (colorScheme == .dark ? Color.black : Color.white).opacity(0.3)
                    : Color.clear
                )
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct HoverableMenu<MenuContent: View>: View {
    @State private var isHovering = false
    
    let content: MenuContent
    let label: AnyView
    
    init<Label: View>(
        @ViewBuilder content: () -> MenuContent,
        @ViewBuilder label: () -> Label
    ) {
        self.content = content()
        self.label = AnyView(label())
    }
    
    var body: some View {
        Menu {
            content
        } label: {
            HStack {
                label
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ? Color.white.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

struct WelcomeWindow: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var connections: [Connection]
    @State private var selectedItem: NavigationItem = .home
    let databases = ["admin", "config", "taxpool", "jurifyte"]
    
    var body: some View {
        CustomSplitView {
            VStack(spacing: 0) {
                Button(action: { selectedItem = .home }) {
                    Image(systemName: "house.fill").opacity(0.7)
                    Text("Home")
                }
                .buttonStyle(SidebarButtonStyle(isActive: selectedItem == .home))
                
                Button(action: {}) {
                    HStack {
                        Image(systemName: "plus.app").opacity(0.7)
                        Text("New Connection")
                        Spacer()
                    }
                }
                .buttonStyle(SidebarButtonStyle(isActive: false))
                
                Divider().padding(.vertical, 10)
                
                Button(action: {}) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                        Text("First Space")
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                }
                .buttonStyle(SidebarButtonStyle(isActive: false))
                
                HStack {
                    Text("Databases")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                    
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
                .padding(.bottom, 4)
                
                
                ForEach(databases, id: \.self) { database in
                    Button(action: { selectedItem = .database(database) }) {
                        HStack {
                            Image(systemName: "cylinder.split.1x2").opacity(0.7)
                            Text(database)
                            Spacer()
                        }
                    }
                    .buttonStyle(SidebarButtonStyle(
                        isActive: selectedItem == .database(database)
                    ))
                }
                
                Spacer()
                
                Divider().padding(.vertical, 10)
                Button(action: {}) {
                    HStack {
                        Image(systemName: "exclamationmark.bubble.fill").opacity(0.7)
                        Text("Feedback")
                        Spacer()
                    }
                }
                .buttonStyle(SidebarButtonStyle(isActive: false))
            }
            .padding(20)
        } detail: {
            switch selectedItem {
            case .home:
                HomeView()
            case .database(let name):
                DatabaseView(databaseName: name)
            }
        }
    }
}

#Preview {
    WelcomeWindow()
}
