//
//  SidebarConnectionsView.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/18/25.
//

import SwiftUI

struct SidebarConnectionsView: View {
    @State private var appState = AppState.shared

    var body: some View {
        VStack(spacing: 0) {
            if appState.connectionInstances.isEmpty {
                Text("Select a connection to get started")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            ForEach(appState.connectionInstances) { connectionInstance in
                Button(action: {
                    appState.changeActiveSidebarItem(.connection(connectionInstance.id))
                    appState.changeActiveTab(.connection_details)
                }) {
                    HStack {
                        Image(systemName: "server.rack").opacity(0.7)
                        Text(connectionInstance.connection.name)
                        Spacer()
                    }

                    Spacer()
                    Button(action: {
                        appState.removeConnectionInstance(connectionInstance.id)
                    }) {
                        Image(systemName: "xmark")
                            .opacity(0.7)
                            .font(.footnote)
                            .fontWeight(.medium)
                    }.buttonStyle(ActionButtonStyle())
                }
                .buttonStyle(
                    SidebarButtonStyle(
                        isActive: appState.activeConnectionInstance?.id
                            == connectionInstance.id
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
