//
//  Header.swift
//  Collection
//
//  Created by Fauzaan on 3/23/25.
//
import SwiftUI

// MARK: - Connection Header
struct ConnectionHeader: View {
    let name: String
    let status: ConnectionStatus
    let version: String?
    let databaseType: DatabaseType
    let environment: ConnectionEnvironment
    
    @State private var isHovered = false
    @State private var bubbleOffset = CGSize.zero
    
    // Get color based on connection status
    private var statusColor: Color {
        switch status {
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
                    Text(name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    
                    HStack() {
                        ConnectionStatusBadge(status: status, onRetry: {})
                        
                        if let version = version {
                            Divider().frame(height: 10)
                            ViewThatFits(in: .horizontal) {
                                Text("\(databaseType.displayName) \(version)")
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
                EnvironmentTag(environment: environment)
                    .opacity(isHovered ? 1 : 0.8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                // Base background
                statusColor.opacity(0.06)
                
                // Inner glow layer
                Group {
                    ForEach(0..<4) { i in
                        RoundedRectangle(cornerRadius: 12)
                            .inset(by: Double(i) * 0.5)
                            .stroke(
                                statusColor.opacity(isHovered ? 0.1 : 0.05),
                                lineWidth: 1
                            )
                    }
                }
                .blur(radius: 4)
                .blendMode(.plusLighter)
                
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
                    statusColor.opacity(isHovered ? 0.3 : 0.15))
                .blendMode(.plusLighter)
        )
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.3), value: status)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hover in
            isHovered = hover
        }
        .padding([.horizontal, .top])
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
