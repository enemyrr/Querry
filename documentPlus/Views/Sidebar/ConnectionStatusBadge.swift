//
//  ConnectionStatusBadge.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/26/25.
//

import SwiftUI

struct ConnectionStatusBadge: View {
    let status: ConnectionStatus
      let onRetry: () -> Void
      
      @State private var isAnimating = false
      
      var body: some View {
          HStack(spacing: 6) {
              Circle()
                  .fill(statusColor.gradient)
                  .frame(width: 6, height: 6)
                  .shadow(color: statusColor.opacity(0.5), radius: 2)
              
//              Text(status.rawValue)
//                  .font(.system(size: 11, weight: .medium))
//                  .foregroundStyle(.secondary)
              
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
//          .padding(.horizontal, 8)
          .padding(4)
          .cornerRadius(6)
          .onAppear {
              startAnimationIfNeeded()
          }
      }
      
      private func startAnimationIfNeeded() {
          if status == .error {
              withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
                  isAnimating.toggle()
              }
          }
      }
      
      private var statusColor: Color {
          switch status {
          case .connected:
              return Color(red: 0.2, green: 0.8, blue: 0.4)
          case .connecting:
              return Color(red: 1.0, green: 0.6, blue: 0.0)
          case .disconnected, .error:
              return Color(red: 0.9, green: 0.3, blue: 0.3)
          }
      }
}


