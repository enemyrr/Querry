//
//  DocumentViewSkelton.swift
//  Collection
//
//  Created by Fauzaan on 3/6/25.
//

import SwiftUI

// MARK: - Multi-Document Loading View
struct DocumentsLoadingView: View {
    let cardCount = 3 // Number of document cards to display
    
    var body: some View {
        VStack {
            // Pulsing line at the top edge of the screen
            PulsingLineLoader(isLoading: true)
                .padding(.top, 6) // Position it at the very top
        }
    }
}

// MARK: - Document Card Skeleton
struct DocumentCardSkeleton: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main card content
            VStack(alignment: .leading, spacing: 8) {
                SkeletonKeyValueList(
                    itemCount: Int.random(in: 4...8), // Random number of fields per card
                    includeNested: true
                )
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    Color(.controlColor).opacity(0.15)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            .linearGradient(
                                colors: [
                                    Color(.controlColor).opacity(0.1),
                                    Color(.controlColor).opacity(0.05),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.plusLighter)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator, lineWidth: 1)
            )
            .cornerRadius(8)
        }
    }
}

// MARK: - Skeleton Key-Value List
struct SkeletonKeyValueList: View {
    let itemCount: Int
    var includeNested: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<itemCount, id: \.self) { index in
                if index % 4 == 0 && includeNested { // Every fourth item is an expandable field
                    SkeletonExpandableRow()
                } else {
                    SkeletonKeyValueRow()
                }
            }
        }
    }
}

// MARK: - Skeleton Key-Value Row
struct SkeletonKeyValueRow: View {
    var body: some View {
        HStack(spacing: 8) {
            // Key placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: CGFloat.random(in: 40...120), height: 14)
            
            // Value placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(width: CGFloat.random(in: 80...180), height: 14)
        }
        .shimmerEffect()
    }
}

// MARK: - Skeleton Expandable Row
struct SkeletonExpandableRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Chevron placeholder
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
                
                // Key placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: CGFloat.random(in: 60...120), height: 14)
                
                // Value placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: CGFloat.random(in: 40...80), height: 14)
            }
            .shimmerEffect()
            
            // Nested fields (sometimes show nested items)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<Int.random(in: 1...3), id: \.self) { _ in
                    HStack(spacing: 8) {
                        // Indentation space
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 16)
                        
                        // Nested key placeholder
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.25))
                            .frame(width: CGFloat.random(in: 40...90), height: 12)
                        
                        // Nested value placeholder
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: CGFloat.random(in: 60...120), height: 12)
                    }
                    .shimmerEffect()
                }
            }
            .padding(.leading, 10)
        }
    }
}

// MARK: - Skeleton Action Buttons
struct SkeletonActionButtons: View {
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { _ in
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 14, height: 14)
                    .padding(.horizontal, 2)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.separator, lineWidth: 1)
                )
        )
        .shimmerEffect()
    }
}

// MARK: - Pulsing Line Animation
struct PulsingLineLoader: View {
    var isLoading: Bool
    var color: Color = .white
    var lineWidth: CGFloat = 80
    var lineHeight: CGFloat = 3
    var glowRadius: CGFloat = 4
    var glowOpacity: Double = 0.8
    
    @State private var opacity: Double = 0.4
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        ZStack {
            if isLoading {
                Capsule()
                    .fill(color)
                    .frame(width: lineWidth, height: lineHeight)
                    .shadow(color: color.opacity(glowOpacity), radius: glowRadius)
                    .opacity(opacity)
                    .scaleEffect(x: scale, y: 1.0, anchor: .center)
            }
        }
        .frame(height: lineHeight)
        .frame(maxWidth: .infinity)
        .onAppear {
            if isLoading {
                startPulseAnimation()
            }
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(
            Animation.easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
        ) {
            opacity = 0.5
            scale = 1.2
        }
    }
}

// MARK: - Shimmer Effect
struct ShimmerEffect: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .mask(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white, location: 0.3),
                            .init(color: .white, location: 0.7),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .position(
                        x: isAnimating ?
                            geometry.size.width + 100 :
                            -100,
                        y: geometry.size.height / 2
                    )
                }
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 2)
                        .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

extension View {
    func shimmerEffect() -> some View {
        modifier(ShimmerEffect())
    }
}
