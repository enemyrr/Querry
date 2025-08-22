//
//  Header.swift
//  Collection
//
//  Created by Fauzaan on 3/23/25.
//
import SwiftUI

// MARK: - Connection Header
struct ConnectionHeader: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(ConnectionInstance.self) private var instance
    let onDisconnect: () async -> Void
    let onReconnect: () async -> Void
    
    @State private var isHovered = false
    @State private var bubbleOffset = CGSize.zero
    @State private var showConnectionDetails = false
    @State private var showEditSheet = false
    @State private var showEditConfirmation = false
    
    @Environment(SidebarViewModel.self) private var sidebarViewModel
    
    // Get color based on connection status
    private var statusColor: Color {
        switch instance.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected:
            return .red
        case .error:
            return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Main content
            HStack(alignment: .center) {
                // Left side
                VStack(alignment: .leading, spacing: 4) {
                    Text(instance.connection.name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    
                    HStack() {
                        ConnectionStatusBadge(status: instance.connectionStatus, onRetry: {})
                        
                        if let version = instance.connectionVersion {
                            Divider().frame(height: 10)
                            ViewThatFits(in: .horizontal) {
                                Text("\(instance.connection.databaseType.displayName) \(version)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Text("v\(version)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                
                Spacer(minLength: 8)
                
                // Right side
                EnvironmentTag(environment: instance.connection.environment)
                    .opacity(isHovered ? 1 : 0.8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .modifier(GlassBackgroundStyle())
                .onTapGesture {
            showConnectionDetails = true
        }
        .background(
            ZStack {
                // Base background
                statusColor.opacity(0.06)
                
                // Moving bubble with dynamic color
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: statusColor.opacity(0.8), location: 0),
                                .init(color: statusColor.opacity(0.4), location: 0.5),
                                .init(color: .clear, location: 1)
                            ]),
                            center: .leading,
                            startRadius: 1,
                            endRadius: 120
                        )
                    )
                    .blendMode(.multiply)
                    .frame(width: 240, height: 240)
                    .blur(radius: 30)
                    .offset(bubbleOffset)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 8)
                            .repeatForever(autoreverses: true)
                        ) {
                            bubbleOffset = CGSize(width: 50, height: 20)
                        }
                        
                        withAnimation(
                            .easeInOut(duration: 6)
                            .repeatForever(autoreverses: true)
                            .delay(1)
                        ) {
                            bubbleOffset.height = -20
                        }
                    }
            }
        )
        
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    statusColor.opacity(
                        colorScheme == .dark ? (isHovered ? 0.3 : 0.15) : (isHovered ? 0.8 : 5))
                )
                .blendMode(colorScheme == .dark ? .plusLighter : .normal)
        )
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.3), value: instance.connectionStatus)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hover in
            isHovered = hover
        }
       .popover(isPresented: $showConnectionDetails, arrowEdge: .trailing) {
            ConnectionDetailsPopover(
                connection: instance.connection,
                databaseType: instance.connection.databaseType,
                environment: instance.connection.environment,
                version: instance.connectionVersion,
                connectedDatabase: instance.connectedDatabase?.name,
                onDisconnect: {
                    showConnectionDetails = false
                    // Add delay to allow popover to close smoothly
                    try? await Task.sleep(for: .milliseconds(200))
                    await onDisconnect()
                },
                onReconnect: {
                    showConnectionDetails = false
                    await onReconnect()
                },
                onEdit: {
                    showConnectionDetails = false
                    if instance.connectionStatus == .connected {
                        showEditConfirmation = true
                    } else {
                        showEditSheet = true
                    }
                }
            )
        }
        .sheet(isPresented: $showEditSheet) {
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .ignoresSafeArea()
                
                CreateConnectionForm(
                    connection: instance.connection,
                    onDisconnect: onDisconnect
                )
                .frame(width: 560)
            }
        }
        .alert("Edit Connection", isPresented: $showEditConfirmation) {
            Button("Continue") {
                showEditSheet = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to edit this active connection?")
        }
        .padding(.bottom, 6)
    }
}

// MARK: - Connection Status Page
private struct ConnectionStatusBadge: View {
    let status: ConnectionStatus
    let onRetry: () -> Void
    
    var body: some View {
        HStack(spacing: 3) {
            statusIcon
                .foregroundStyle(statusColor)
                .font(.system(size: 9))
                .if(status == .connecting) { view in
                    view.symbolEffect(.rotate.clockwise.byLayer, options: .repeat(.periodic(delay: 1)))
                }
            
            Text(statusText)
                .foregroundStyle(statusColor)
                .font(.caption)
            
            if status == .error {
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .background(.secondary.opacity(0.1))
                .clipShape(Circle())
            }
        }
    }
    
    private var statusIcon: Image {
        switch status {
        case .connected:
            return Image(systemName: "server.rack")
        case .connecting:
            return Image(systemName: "arrow.2.circlepath")
        case .disconnected, .error:
            return Image(systemName: "network.slash")
        }
    }
    
    private var statusText: String {
        switch status {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return "Disconnected"
        case .error:
            return "Retry"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected, .error:
            return .secondary
        }
    }
}
