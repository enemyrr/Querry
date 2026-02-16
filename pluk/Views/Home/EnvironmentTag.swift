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
        case .local: Color(red: 0.42, green: 0.65, blue: 0.52)
        case .testing: Color(red: 0.4, green: 0.56, blue: 0.75)
        case .development: Color(red: 0.58, green: 0.44, blue: 0.72)
        case .staging: Color(red: 0.82, green: 0.6, blue: 0.4)
        case .production: Color(red: 0.75, green: 0.42, blue: 0.42)
        }
    }
}

struct EnvironmentTag: View {
    let environment: ConnectionEnvironment

    var body: some View {
        Text(environment.rawValue)
            .font(.system(size: 10))
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(environment.color)
            )
    }
}
