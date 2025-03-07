//
//  LoadingView.swift
//  Collection
//
//  Created by Fauzaan on 2/19/25.
//

import SwiftUI

//struct DocumentLoadingView: View {
//    var body: some View {
//        VStack(spacing: 10) {
//            PulsingLineLoader(
//                isLoading: true,
//                color: .white,
//                lineWidth: 40,
//                lineHeight: 3
//            ).padding(.top, -14)
//            Spacer()
//            ProgressView()
//                .controlSize(.small)
//            Text("Loading Documents...")
//                .font(.subheadline)
//                .foregroundColor(.secondary)
//            
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(.clear)
//                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
//        )
//        .padding()
//    }
//}
//
//// MARK: - Pulsing Line Animation
//struct PulsingLineLoader: View {
//    var isLoading: Bool
//    var color: Color = .white
//    var lineWidth: CGFloat = 40  // Width of the line
//    var lineHeight: CGFloat = 3  // Height/thickness of the line
//    var glowRadius: CGFloat = 4
//    var glowOpacity: Double = 0.8
//    
//    // Animation states
//    @State private var opacity: Double = 0.4
//    @State private var scale: CGFloat = 0.8
//    
//    var body: some View {
//        ZStack {
//            if isLoading {
//                // The pulsing line
//                Capsule()
//                    .fill(color)
//                    .frame(width: lineWidth, height: lineHeight)
//                    .shadow(
//                        color: color.opacity(glowOpacity),
//                        radius: glowRadius
//                    )
//                    .opacity(opacity)
//                    .scaleEffect(x: scale, y: 1.0, anchor: .center)
//            }
//        }
//        .frame(height: lineHeight * 2)
//        .frame(maxWidth: .infinity)
//        .onAppear {
//            if isLoading {
//                startPulseAnimation()
//            }
//        }
//        .onChange(of: isLoading) { newValue in
//            if newValue {
//                startPulseAnimation()
//            }
//        }
//    }
//    
//    private func startPulseAnimation() {
//        // Reset animation state
//        opacity = 0.4
//        scale = 0.8
//        
//        // Create a continuous pulsing animation
//        withAnimation(
//            Animation.easeInOut(duration: 1.0)
//                .repeatForever(autoreverses: true)
//        ) {
//            opacity = 0.6
//            scale = 1.2
//        }
//    }
//}


// MARK: - Reusable Modifier
struct PulsingLineModifier: ViewModifier {
    var isLoading: Bool
    var color: Color = .white
    var lineWidth: CGFloat = 40
    var lineHeight: CGFloat = 3
    var glowRadius: CGFloat = 4
    var glowOpacity: Double = 0.8
    
    func body(content: Content) -> some View {
        content
            .overlay(
                PulsingLineLoader(
                    isLoading: isLoading,
                    color: color,
                    lineWidth: lineWidth,
                    lineHeight: lineHeight,
                    glowRadius: glowRadius,
                    glowOpacity: glowOpacity
                ),
                alignment: .top
            )
    }
}

extension View {
    func topPulsingLine(
        isLoading: Bool,
        color: Color = .white,
        lineWidth: CGFloat = 40,
        lineHeight: CGFloat = 3,
        glowRadius: CGFloat = 4,
        glowOpacity: Double = 0.8
    ) -> some View {
        modifier(
            PulsingLineModifier(
                isLoading: isLoading,
                color: color,
                lineWidth: lineWidth,
                lineHeight: lineHeight,
                glowRadius: glowRadius,
                glowOpacity: glowOpacity
            )
        )
    }
}
