//
//  EnvironmentTag.swift
//  Collection
//
//  Created by Fauzaan on 2/9/25.
//

import SwiftUI

extension ConnectionEnvironment {
    var color: Color {
        switch self {
        case .local:
            return .green
        case .testing:
            return .blue
        case .development:
            return .purple
        case .staging:
            return .orange
        case .production:
            return .red
        }
    }
}


struct EnvironmentTag: View {
    let environment: ConnectionEnvironment
    
    var body: some View {
        Text(environment.rawValue)
            .font(.system(size: 10))
            .fontWeight(.medium)
            .foregroundColor(environment.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(environment.color.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(environment.color.opacity(0.3), lineWidth: 1)
            )
    }
}
