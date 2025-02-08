//
//  HomeView.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/17/25.
//

import AppKit
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(SidebarViewModel.self) private var sidebarViewModel
    @Query private var connections: [Connection]
    @State private var showDatabaseModal = false

    

    @Environment(\.openWindow) private var openWindow
    @State private var selectedConnectionId: PersistentIdentifier?
    

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("My Collections")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text(
                            "To get started, connect to an existing server or create a new one."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()
                    CreateConnection()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
                .padding(.bottom, 6)

                ConnectionList(
                    connections: connections,
                    selectedConnectionId: $selectedConnectionId,
                    onSelect: { connection in
                        selectedConnectionId = connection.persistentModelID
                    },
                    onOpen: { connection in
                        let instanceId = sidebarViewModel.createNewConnectionInstance(for: connection)
                        sidebarViewModel.changeActiveSidebarItem(.connection(instanceId))
                    }
                )

                Spacer()
            }
            .padding(20)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .leading
            )
            .background(Color(.controlColor).opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator, lineWidth: 1)
            )
            .cornerRadius(10)
            .padding(8)
        }
    }
}




struct ConnectionList: View {
    let connections: [Connection]
    @Binding var selectedConnectionId: PersistentIdentifier?
    let onSelect: (Connection) -> Void
    let onOpen: (Connection) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Name")
                    .frame(width: 200, alignment: .leading)

                Spacer()

                Text("Last Opened")
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
                    ForEach(connections) { connection in
                        ConnectionListItem(connection: connection, isSelected: connection.persistentModelID == selectedConnectionId, onSelect: self.onSelect, onOpen: self.onOpen)
                    }
                }
            }
        }
    }
}

struct ConnectionListItem: View {
    let connection: Connection
    let isSelected: Bool
    let onSelect: (Connection) -> Void
    let onOpen: (Connection) -> Void
    @State private var isHovering = false

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.name)
                        .foregroundStyle(.primary)

                    Text("taxpool")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                }
            }
            .frame(width: 200, alignment: .leading)

            Spacer()

            Text(
                Date().timeIntervalSince(connection.lastOpenedAt) < 60
                    ? "a moment ago"
                    : connection.lastOpenedAt.formatted(.relative(presentation: .named))
            )
            .foregroundStyle(.secondary)
            .frame(width: 120, alignment: .leading)

            Text(
                connection.createdAt
                    .formatted(date: .abbreviated, time: .omitted)
            )
            .foregroundStyle(.secondary)
            .frame(width: 120, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected || isHovering ? Color.black.opacity(0.3)  : Color.clear
                )
                .onTapGesture {
                    onSelect(connection)
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    onOpen(connection)
                    connection.lastOpenedAt = Date()
                }
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
