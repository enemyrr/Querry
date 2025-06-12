//
//  LoadingAnimation.swift
//  Pluk
//
//  Created by Fauzaan on 4/12/25.
//
import SwiftUI

struct GlowingBubbleLoader: View {
    var statusColor: Color = Color(red: 1.0, green: 0.6, blue: 0.0)
    var height: CGFloat = 6
    var animationDuration: Double = 1
    var isLoading: Bool
    
    // Trigger to start each animation cycle
    @State private var animationTrigger = UUID()
    @State private var shouldContinueAnimating = false
    @State private var currentCycleStarted = false
    
    var body: some View {
        Color.clear
            .keyframeAnimator(
                initialValue: LoaderAnimationValues(),
                trigger: animationTrigger
            ) { content, value in
                // The moving triangle gradient shape
                LongTailTriangleShape()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: statusColor, location: 0),
                                .init(color: statusColor.opacity(0.90), location: 0.5),
                                .init(color: statusColor.opacity(0.80), location: 0.8),
                                .init(color: statusColor.opacity(0.60), location: 1)
                            ]),
                            center: .trailing,
                            startRadius: 5,
                            endRadius: 100
                        )
                    )
                    .frame(width: 120, height: 50)
                    .blur(radius: 12)
                    .offset(y: value.verticalOffset)
                    .offset(x: value.horizontalPosition * (270 + 120) - 120)
                    .opacity(value.opacity)
                    .blendMode(.plusLighter)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } keyframes: { _ in
                // Horizontal position keyframes
                KeyframeTrack(\.horizontalPosition) {
                    CubicKeyframe(0, duration: 0)  // Start off-screen to the left
                    CubicKeyframe(1, duration: animationDuration)  // Animate to right edge
                }
                
                // Vertical floating effect
                KeyframeTrack(\.verticalOffset) {
                    CubicKeyframe(0, duration: 0)
                    CubicKeyframe(5, duration: animationDuration/2)
                    CubicKeyframe(0, duration: animationDuration/2)
                }
                
                // Opacity track for fading in/out
                KeyframeTrack(\.opacity) {
                    CubicKeyframe(1, duration: animationDuration)
                }
            }
            .frame(height: max(height * 6, 40))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onChange(of: isLoading) { _, newValue in
                if newValue && !shouldContinueAnimating {
                    // Start loading
                    shouldContinueAnimating = true
                    startNextCycle()
                } else if !newValue {
                    // Stop loading after current cycle
                    shouldContinueAnimating = false
                }
            }
            .onAppear {
                if isLoading {
                    shouldContinueAnimating = true
                    startNextCycle()
                }
            }
            .onReceive(Timer.publish(every: animationDuration + 0.1, on: .main, in: .common).autoconnect()) { _ in
                // Only process timer if we have a cycle running
                if currentCycleStarted {
                    currentCycleStarted = false
                    
                    // Start next cycle if still loading
                    if shouldContinueAnimating {
                        startNextCycle()
                    }
                }
            }
    }
    
    private func startNextCycle() {
        guard !currentCycleStarted else { return }
        currentCycleStarted = true
        
        // Small delay before starting next cycle for smooth continuous animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            animationTrigger = UUID()
        }
    }
}

// Animation values structure
struct LoaderAnimationValues {
    var horizontalPosition: Double = 0
    var verticalOffset: Double = 0
    var opacity: Double = 1.0
}

// Triangle shape with long tail
struct LongTailTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start at the top-right (flat edge of triangle)
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        
        // Bottom-right (flat edge of triangle)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        
        // Point (back of triangle) - moved further left for longer tail
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        
        // Back to start
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Preview
struct GlowingBubbleLoader_Previews: PreviewProvider {
    @State static var isLoading = true
    
    static var previews: some View {
        VStack(spacing: 20) {
            GlowingBubbleLoader(isLoading: isLoading)
            
            Button(isLoading ? "Stop Loading" : "Start Loading") {
                isLoading.toggle()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color.black)
    }
}
