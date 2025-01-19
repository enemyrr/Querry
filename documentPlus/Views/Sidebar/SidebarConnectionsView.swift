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
            if appState.activeConnections.isEmpty {
                Text("Select a connection to get started")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            
            ForEach(appState.activeConnections, id: \.name) {
                activeConnection in
                Button(action: {
                    appState.changeActiveSidebarItem(
                        .database(activeConnection.name))
                    appState.changeActiveTab(.connection_details)
                }) {
                    HStack {
                        Image(systemName: "server.rack").opacity(0.7)
                        Text(activeConnection.name)
                        Spacer()
                    }
                    
                    // TODO: Add close logic
                    // Spacer()
                    // Image(systemName: "xmark").opacity(0.7).font(.footnote).fontWeight(.medium)
                }
                .buttonStyle(
                    SidebarButtonStyle(
                        isActive: appState.activeConnection?.id == activeConnection.id
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
