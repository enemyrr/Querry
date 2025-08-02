//
//  ConnectionDetailsPopover.swift
//  Pluk
//
//  Created by Fauzaan on 8/2/25.
//

import SwiftUI

struct ConnectionDetailsPopover: View {
    let connection: Connection?
    let databaseType: DatabaseType
    let environment: ConnectionEnvironment
    let version: String?
    let connectedDatabase: String?
    let onDisconnect: () async -> Void
    let onReconnect: () async -> Void
    let onEdit: () -> Void
    
    private var connectionURL: String {
        connection?.url ?? ""
    }
    
    private var hostname: String {
        guard let url = URL(string: connectionURL) else { return "Unknown" }
        return url.host ?? "Unknown"
    }
    
    private var port: String {
        guard let url = URL(string: connectionURL) else { return "Unknown" }
        if let port = url.port {
            return String(port)
        }
        // Default ports based on database type
        switch databaseType {
        case .postgres, .supabase, .neon:
            return "5432"
        case .mysql, .mariadb:
            return "3306"
        case .mongodb:
            return "27017"
        }
    }
    
    private var username: String {
        guard let url = URL(string: connectionURL) else { return "Unknown" }
        return url.user ?? "Unknown"
    }
    
    private var databaseName: String {
        connectedDatabase ?? connection?.defaultDatabase ?? "Default"
    }
    
    private var driverWithVersion: String {
        if let version = version {
            return "\(databaseType.displayName) \(version)"
        } else {
            return databaseType.displayName
        }
    }
    
    var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Header with database type info
                HStack(spacing: 12) {
                    Image(databaseType.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundStyle(databaseType.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connection Details")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(connection?.name ?? "Unknown Connection")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Server Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("SERVER")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    VStack(spacing: 8) {
//                        CompactDetailRow(label: "Server", value: hostname)
                        CompactDetailRow(label: "Host", value: hostname)
                        CompactDetailRow(label: "Port", value: port)
                    }
                    .padding(16)
                    .background(Color(.controlColor).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.separator, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                
                // Connection Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("CONNECTION")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    VStack(spacing: 8) {
                        CompactDetailRow(label: "Driver", value: driverWithVersion)
                        CompactDetailRow(label: "Database", value: databaseName)
                        CompactDetailRow(label: "Username", value: username)
                        CompactDetailRow(label: "Environment", value: environment.rawValue)
                    }
                    .padding(16)
                    .background(Color(.controlColor).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.separator, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                
                // Actions Section
                HStack(spacing: 8) {
                    Button("Disconnect") {
                        Task {
                            await onDisconnect()
                        }
                    }
                    .compactMenuButtonStyle()
                    
                    Spacer()
                    
                    Button("Reconnect") {
                        Task {
                            await onReconnect()
                        }
                    }
                    .compactPrimaryStyle()
                    
                    Button("Edit") {
                        onEdit()
                    }
                    .compactMenuButtonStyle()
                }
            }
            .padding(20)
            .frame(minWidth: 350)
            .textSelection(.enabled)
    }
}

// MARK: - Compact Detail Row
private struct CompactDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
        }
    }
}
