//
//  IntelligenceUIPlatterView.swift
//  Collection
//
//  Created by Fauzaan on 3/4/25.
//

// TODO: High CPU USAGE: FIX THIS 
import SwiftUI
import AppKit
import Combine

struct IntelligenceUIPlatterView: View {
    @State private var animateGradient = false
    @State private var glowIntensity: CGFloat = 0
    @State private var bloomSizes: [CGFloat] = [0, 0, 0, 0]
    
    private let colors1: [Color] = [.orange, .yellow, .blue, .purple, .pink]
    private let colors2: [Color] = [.pink, .purple, .orange, .yellow, .blue]
    
    // Points where the glow will originate
    private let bloomPoints = [
        UnitPoint(x: 0, y: 0),      // Top-left
        UnitPoint(x: 1, y: 0),      // Top-right
        UnitPoint(x: 0, y: 1),      // Bottom-left
        UnitPoint(x: 1, y: 1)       // Bottom-right
    ]
    
    var body: some View {
        ZStack {
            // Main content with glass background
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.clear)
                .modifier(GlassBackgroundStyle(cornerRadius: 6))
            
            // Base border that will always be visible - reduced to 1 as requested
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(colors: animateGradient ? colors1 : colors2),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .opacity(glowIntensity)
            
            // Multiple bloom effects from different corners - adjusted lineWidth to 1
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                (animateGradient ? colors1[i % colors1.count] : colors2[i % colors2.count]),
                                Color.clear
                            ]),
                            center: bloomPoints[i],
                            startRadius: 0,
                            endRadius: 150 * bloomSizes[i]
                        ),
                        lineWidth: 1
                    )
                    .opacity(0.6) // Slightly reduced opacity
            }
            
            // Outer glow layer - making it more faded
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(colors: animateGradient ? colors1 : colors2),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2 // Reduced from 3
                )
                .blur(radius: 3.5) // Slightly increased blur
                .opacity(0.35 * glowIntensity) // Reduced opacity for a more faded look
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: animateGradient ? colors1 : colors2),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2 // Reduced from 3
                )
                .blur(radius: 4) // Increased blur
                .opacity(0.25 * glowIntensity) // Further reduced opacity for a subtle effect
        )
        .onAppear {
            // Animate the blooms with slightly different timing
            withAnimation(.easeOut(duration: 0.8)) {
                glowIntensity = 1.0
            }
            
            // Sequence the bloom animations for an organic feel
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                bloomSizes[0] = 1.0
            }
            withAnimation(.easeOut(duration: 0.7).delay(0.2)) {
                bloomSizes[1] = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                bloomSizes[2] = 1.0
            }
            withAnimation(.easeOut(duration: 0.65).delay(0.25)) {
                bloomSizes[3] = 1.0
            }
            
            // Then start the color animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: true)) {
                    print("animte")
                    animateGradient.toggle()
                }
            }
        }
    }
}
