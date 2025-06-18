//
//  TwoPhaseLoader.swift
//  Pluk
//
//  Created by Fauzaan on 6/18/25.
//
import SwiftUI

struct TwoPhaseLoader: View {
    @State private var progress: CGFloat = 0
    let isLoading: Bool
    let cornerRadius: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Main progress bar with gradient and heat trail effect
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.3, blue: 0.0), // Bright red-orange
                                Color(red: 1.0, green: 0.5, blue: 0.0), // Orange
                                Color(red: 1.0, green: 0.6, blue: 0.2)  // Lighter orange
                            ]),
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 1.5)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.7),
                                .init(color: .black.opacity(0.8), location: 0.85),
                                .init(color: .black.opacity(0.4), location: 0.95),
                                .init(color: .clear, location: 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color(red: 1.0, green: 0.4, blue: 0.0).opacity(0.6), radius: 8, x: 0, y: 0)
                    .shadow(color: Color(red: 1.0, green: 0.4, blue: 0.0).opacity(0.3), radius: 16, x: 0, y: 0)
                
                // Heat trail glow effect
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .clear, location: 0.6),
                                .init(color: Color(red: 1.0, green: 0.4, blue: 0.0).opacity(0.3), location: 0.8),
                                .init(color: Color(red: 1.0, green: 0.5, blue: 0.0).opacity(0.15), location: 0.95),
                                .init(color: .clear, location: 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress + 0.3, height: 8)
                    .blur(radius: 3)
                if progress != 0 {
                    Rectangle()
                        .fill(.orange)
                        .opacity(0.05)
                        .frame(width: geometry.size.width)
                }
            }
        }
        .onAppear {
            // Phase 1: Initial load to 7%
            withAnimation(.easeOut(duration: 0.02)) {
                progress = 0.15
            }
        }
        .cornerRadius(cornerRadius)
        .onChange(of: isLoading) { oldValue, newValue in
            if !newValue {
                // Phase 2: Complete the loading (7% to 100%)
                withAnimation(.easeInOut(duration: 0.05)) {
                    progress = 1.0
                }
                
                // Optional: Hide the loader after completion
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    progress = 0
                }
            } else {
                // Reset to 7% when loading starts again
                withAnimation(.easeOut(duration: 0.2)) {
                    progress = 0.15
                }
            }
        }
    }
}

// MARK: - Usage Example
struct ContentView: View {
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Loader at the top
            TwoPhaseLoader(isLoading: isLoading, cornerRadius: 12)
            
            // Your main content
            VStack {
                Text("Your Content Here")
                    .font(.title)
                    .padding()
                
                Button(isLoading ? "Complete Loading" : "Start Loading") {
                    isLoading.toggle()
                }
                .padding()
                .cornerRadius(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ContentView()
}
