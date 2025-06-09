//
//  Background.swift
//  Collection
//
//  Created by Fauzaan on 2/23/25.
//

import SwiftUI

struct GlassBackgroundStyle: ViewModifier {
    var cornerRadius: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.thinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius + 2)
                        .fill(
                            .linearGradient(
                                colors: [
                                    Color(.controlBackgroundColor).opacity(0.05),
                                    .clear,
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.plusLighter)
                }
            }
    }
}

struct GlassBackgroundStyleRoundedTop: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedCorners(tl: 8, tr: 8, bl: 0, br: 0)
                        .fill(.thinMaterial)
                    RoundedCorners(tl: 8 + 2, tr: 8 + 2, bl: 0, br: 0)
                        .fill(
                            .linearGradient(
                                colors: [
                                    Color(.controlColor).opacity(0.1),
                                    Color(.controlColor).opacity(0.05),
                                    .clear,
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.plusLighter)
                }
            }
    }
}

// MARK: - View Extension
extension View {
    func glassBackground(cornerRadius: CGFloat = 6) -> some View {
        modifier(GlassBackgroundStyle(cornerRadius: cornerRadius))
    }
    
    func glassBackgroundRoundedTop() -> some View {
        modifier(GlassBackgroundStyleRoundedTop())
    }
}
