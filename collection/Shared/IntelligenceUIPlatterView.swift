//
//  IntelligenceUIPlatterView.swift
//  Collection
//
//  Created by Fauzaan on 3/4/25.
//

import SwiftUI
import AppKit

struct IntelligenceUIPlatterView: View {
    @State private var animateGradient = false
    @State private var glowIntensity: CGFloat = 0
    @State private var bloomSizes: [CGFloat] = [0, 0, 0, 0]
    @State private var isAnimating = false
    
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
            // Base border that will always be visible
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
            
            // Multiple bloom effects from different corners
            ForEach(0..<1) { i in
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
                    .opacity(0.6)
            }
        
                        // Outer glow layer
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(colors: animateGradient ? colors1 : colors2),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .blur(radius: 3.5)
                .opacity(0.35 * glowIntensity)
//                 Add drawing group to optimize compositing
                .drawingGroup()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: animateGradient ? colors1 : colors2),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .blur(radius: 4)
                .opacity(0.25 * glowIntensity)
                // Add drawing group to optimize compositing
                .drawingGroup()
        )
        // Apply drawing group to entire view to optimize rendering
        .drawingGroup()
        .onAppear {
            startOptimizedAnimations()
        }
        .onDisappear {
            isAnimating = false
        }
    }
    
    private func startOptimizedAnimations() {
        isAnimating = true
        
        // Initial animations (one-time)
        withAnimation(.easeOut(duration: 0.8)) {
            glowIntensity = 1.0
        }
        
        // Sequence the bloom animations
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
            bloomSizes[0] = 1.0
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.3)) {
            bloomSizes[1] = 1.0
        }
        
        // Start the optimized color animation cycle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            self.animateGradientWithTimer()
        }
    }
    
    private func animateGradientWithTimer() {
        guard isAnimating else { return }
        
        // Perform the animation with a normal animation instead of repeatForever
        withAnimation(.easeInOut(duration: 2.0)) {
            animateGradient.toggle()
        }
        
        // Schedule the next animation with a timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.animateGradientWithTimer()
        }
    }
}
