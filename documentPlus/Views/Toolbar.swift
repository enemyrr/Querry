//
//  Toolbar.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/7/25.
//
import SwiftUI

struct Toolbar: CustomizableToolbarContent {
    @Binding var connection: Connection?
    @Binding var isConnecting: Bool
    @State private var showConnectionEditor = false
    
    init(connection: Binding<Connection?>, isConnecting: Binding<Bool>) {
        self._connection = connection
        self._isConnecting = isConnecting
    }
    
    var body: some CustomizableToolbarContent {
        // Connection Status Group
        ToolbarItem(id: "connectionStatus", placement: .navigation) {
            if let connection {
                ConnectionStatusView(connection: connection)
            }
        }
        
        // Database Path Group
        ToolbarItem(id: "databasePath", placement: .principal) {
            DatabasePathView(isConnecting: isConnecting)
        }
    }
}

// Separated into smaller components for better maintainability
struct ConnectionStatusView: View {
    let connection: Connection
    @Environment(\.openWindow) private var openWindow
    @Environment(\.self) private var environment
        
    var isWindowActive: Bool {
        NSApplication.shared.mainWindow?.isKeyWindow ?? true
    }
    
    var body: some View {
        VStack(alignment: .leading) {
//            Menu {
//                Button("New Connection...") {
//                    openWindow(id: "new-connection")
//                }
//                
//                Button("Edit Connection...") {
//                    openWindow(id: "edit-connection")
//                }
//                
//                Divider()
//                
//                Button("Reload Current Tab") {
//                    // Implement reload action
//                }
//                
//                Button("Reconnect") {
//                    // Implement reconnect action
//                }
//                
//                Divider()
//                
//                Button("Disconnect", role: .destructive) {
//                    // Implement disconnect action
//                }
//            } label: {
//                Text(connection.name)
//                    .font(.largeTitle)
//            }
//            .menuStyle(.borderlessButton)
            
            
            Text(connection.name)
                .font(.headline)
            Text("Staging")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}

struct DatabasePathView: View {
    let isConnecting: Bool
    
    var body: some View {
        HStack(alignment: .center) {
            // Database path with proper spacing
            Text("Mongo 8.0 : New Connection : test : teams")
                .font(.subheadline)
                .lineLimit(1)
                .padding(.leading, 4)
            
            Spacer()
            
            // Connection status indicator
            ConnectionStatusIndicator(isConnecting: isConnecting)
        }
        .frame(minWidth: 450)
        .padding(4)
        .background(Color(nsColor: .systemFill))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        }
        .cornerRadius(4)
    }
}

struct ConnectionStatusIndicator: View {
    let isConnecting: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnecting ? Color.orange : Color.green)
                .frame(width: 8, height: 8)
            
            Text(isConnecting ? "Connecting..." : "Connected")
                .font(.subheadline)
            
            if isConnecting {
                ProgressView()
                    .scaleEffect(0.5)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 4)
    }
}
