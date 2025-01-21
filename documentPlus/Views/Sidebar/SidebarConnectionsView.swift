//
//  SidebarConnectionsView.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/18/25.
//

import SwiftUI

struct SidebarConnectionsView: View {
    @State private var appState = AppState.shared
    @State private var connectionManager: ConnectionManager = ConnectionManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if connectionManager.isEmpty() {
                Text("Select a connection to get started")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            ForEach(connectionManager.allInstances) { instance in
                Button(action: {
                    appState.changeActiveSidebarItem(.connection(instance.id))
                    appState.changeActiveTab(.connection_details)
                }) {
                    HStack {
                        Image(systemName: "server.rack").opacity(0.7)
                        Text(instance.connection.name)
                        Spacer()
                    }

                    Spacer()
                    Button(action: {
                        connectionManager.removeInstance(instance.id)
                    }) {
                        Image(systemName: "xmark")
                            .opacity(0.7)
                            .font(.footnote)
                            .fontWeight(.medium)
                    }.buttonStyle(ActionButtonStyle())
                }
                .buttonStyle(
                    SidebarButtonStyle(
                        isActive: appState.activeSidebarItem == .connection(instance.id)
                    ))
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SiderbarConnectionsHeader: View {
    @State private var appState = AppState.shared

    var body: some View {
        Text("Active Connections")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)

    }
}
