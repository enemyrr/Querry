//
//  Sidebar.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/1/25.
//
import SwiftUI
import MongoKitten

struct Sidebar: View {
    @State private var appState = AppState.shared
    @State private var selectedDatabase: MongoDatabase?
    @State private var databases: [MongoDatabase] = []
    @State private var isFetchingDatabases = false
    @State private var connectionManager: ConnectionManager = ConnectionManager.shared
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 12) {
                Group {
                    IconButton(
                        systemName: "house.fill",
                        isSelected: appState.activeSidebarItem == .home,
                        action: { appState.activeSidebarItem = .home }
                    )
                    
                    Divider().padding(.horizontal, 12).padding(.bottom, -6)
                    
                    ForEach(connectionManager.allInstances) { instance in
                        DatabaseIcon(
                            color:  instance.accentColor,
                            letter: String(instance.connection.name.prefix(1).uppercased()),
                            isSelected: appState.activeSidebarItem == .connection(instance.id)
                        ) {
                            appState.changeActiveSidebarItem(.connection(instance.id))
                            appState.changeActiveTab(.connection_details)
                        }
                    }
                }.background(.clear)
                
                Spacer()
                
                // Bottom Icons
                Group {
                    IconButtonWithoutBorder(systemName: "exclamationmark.bubble.fill", isSelected: false) {}
                }
                .padding(.bottom, 16)
            }
            .frame(width: 50)
            
            VStack(spacing: 0) {
                Button(action: { appState.activeSidebarItem = .home }) {
                    Image(systemName: "house.fill").opacity(0.7)
                    Text("Home")
                }
                .buttonStyle(
                    SidebarButtonStyle(
                        isActive: appState.activeSidebarItem == .home))
                
                Button(action: {}) {
                    HStack {
                        Image(systemName: "plus.app").opacity(0.7)
                        Text("New Connection")
                        Spacer()
                    }
                }
                .buttonStyle(SidebarButtonStyle(isActive: false))
                
                Divider().padding(.vertical, 10)
                
                SiderbarConnectionDetailsHeader()
                    .frame(height: 40)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                
                ScrollView(.vertical) {
                    SidebarConnectionDetailsView()
                }
            }
            .padding(20)
            .padding(.vertical, 0)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator, lineWidth: 1)
            )
            .cornerRadius(10)
        }.padding(.top, 10)
            .padding(.bottom, 8)
    }
}

enum SidebarItem: Hashable {
    case home
    case connection(UUID)
}

enum SidebarTab: Equatable {
    case connections
    case connection_details
}

struct IconButton: View {
    let systemName: String
    let isSelected: Bool
    let action: () -> Void
    let withBorder: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 10).fill(
                isHovering || isSelected
                ? Color(red: 71/255, green: 186/255, blue: 127/255) : Color.clear
            )
            .frame(width: 28, height: 28)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 14))
                    .frame(width: 30, height: 30)
            )
            
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }
}

struct IconButtonWithoutBorder: View {
    let systemName: String
    let isSelected: Bool
    let action: () -> Void
    let withBorder: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12))
                .frame(width: 30, height: 30)
                .opacity(0.7)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 10).fill(
                isHovering
                ? (colorScheme == .dark ? Color.black : Color.white)
                    .opacity(0.3)
                : Color.clear
            )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }
}

struct DatabaseIcon: View {
    let color: Color
    let letter: String
    let isSelected: Bool
    @State private var isHovering = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(
                    (isHovering || isSelected) ? 1.0 : 0.3)
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Text(letter)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }
}
