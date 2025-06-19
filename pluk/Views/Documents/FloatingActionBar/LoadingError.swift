//
//  LoadingAnimation.swift
//  Pluk
//
//  Created by Fauzaan on 4/12/25.
//
//
//  LoadingErrorIndicator.swift
//  Pluk
//
//  Created by Fauzaan on 4/12/25.
//
import SwiftUI

struct LoadingErrorIndicator: View {
    let cornerRadius: CGFloat
    var statusColor: Color = .red
    var height: CGFloat = 6
    var animationDuration: Double = 1.5
    
    // Trigger to start each animation cycle
    @State private var animationTrigger = UUID()
    @State private var bubbleOffset = CGSize.zero
    @State private var pulseEffect: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        Color.clear
            .background(
                ZStack {
                    // Base background with increased opacity
                    statusColor.opacity(0.12)
                    
                    // Enhanced inner glow layer
                    Group {
                        ForEach(0..<6) { i in
                            RoundedRectangle(cornerRadius: 8)
                                .inset(by: Double(i) * 0.5)
                                .stroke(
                                    statusColor.opacity(0.08 + Double(i) * 0.01),
                                    lineWidth: 1.2
                                )
                        }
                    }
                    .blur(radius: 3)
                    .blendMode(.plusLighter)
                    
                    // Enhanced moving bubble with dynamic color
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(stops: [
                                    .init(color: statusColor.opacity(0.6), location: 0),  // Increased opacity
                                    .init(color: statusColor.opacity(0.3), location: 0.5), // Increased opacity
                                    .init(color: .clear, location: 1)
                                ]),
                                center: .leading,
                                startRadius: 1,
                                endRadius: 140 // Increased radius
                            )
                        )
                        .frame(width: 280, height: 280) // Increased size
                        .blur(radius: 25) // Slightly reduced blur for more definition
                        .scaleEffect(pulseEffect)
                        .offset(bubbleOffset)
                        .rotationEffect(.degrees(rotationAngle))
                    
                    // Additional glow elements for intensity
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(stops: [
                                    .init(color: statusColor.opacity(0.4), location: 0),
                                    .init(color: statusColor.opacity(0.1), location: 0.6),
                                    .init(color: .clear, location: 1)
                                ]),
                                center: .trailing,
                                startRadius: 5,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)
                        .offset(x: -bubbleOffset.width * 0.7, y: bubbleOffset.height * 0.5)
                        .blendMode(.plusLighter)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        statusColor.opacity(0.65)) // Increased border opacity
                    .blendMode(.plusLighter)
            )
            .onAppear {
                // Enhanced animations with faster timing
                withAnimation(
                    .easeInOut(duration: 6)
                    .repeatForever(autoreverses: true)
                ) {
                    bubbleOffset = CGSize(width: 60, height: 25) // Increased movement range
                }
                
                withAnimation(
                    .easeInOut(duration: 5)
                    .repeatForever(autoreverses: true)
                    .delay(0.5)
                ) {
                    bubbleOffset.height = -25
                }
                
                // Add pulsing effect
                withAnimation(
                    .easeInOut(duration: 3)
                    .repeatForever(autoreverses: true)
                ) {
                    pulseEffect = 1.15 // Pulse between 1.0 and 1.15
                }
                
                // Add subtle rotation
                withAnimation(
                    .linear(duration: 12)
                    .repeatForever(autoreverses: false)
                ) {
                    rotationAngle = 360
                }
            }
    }
}

