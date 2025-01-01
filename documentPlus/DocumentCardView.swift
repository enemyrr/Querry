//
//  DocumentView.swift
//  documentPlus
//
//  Created by Fauzaan on 12/31/24.
//
import SwiftUI
import SwiftData

struct DocumentCardView: View {
    @State private var isCardHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Document content
            Group {
                HStack {
                    Text("_id:").foregroundColor(.white)
                    Text("ObjectId('6736b841f9a6974faf8f9c11')")
                        .foregroundColor(.orange)
                }
                
                HStack {
                    Text("taxYear:").foregroundColor(.white)
                    Text("2023").foregroundColor(.blue)
                }
                
                HStack {
                    Text("isActive:").foregroundColor(.white)
                    Text("true").foregroundColor(.blue)
                }
                
                HStack {
                    Text("reliefs:").foregroundColor(.white)
                    Text("Array (17)").foregroundColor(.gray)
                }
                
                HStack {
                    Text("createdAt:").foregroundColor(.white)
                    Text("2024-11-05T11:27:32.688+00:00").foregroundColor(.blue)
                }
                
                HStack {
                    Text("updatedAt:").foregroundColor(.white)
                    Text("2024-11-12T07:18:51.177+00:00").foregroundColor(.blue)
                }
            }
            .font(.system(.body, design: .monospaced))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
        .overlay(
            // Floating action buttons
            HStack(spacing: 8) {
                Button(action: { /* Edit action */ }) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                
                Button(action: { /* Clone action */ }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                
                Button(action: { /* Delete action */ }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            .opacity(isCardHovered ? 1 : 0)
            .transition(.opacity)
            .padding(8)
            , alignment: .topTrailing // Align to top-right corner
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isCardHovered = hovering
            }
        }
    }
}

#Preview {
    DocumentCardView()
        .preferredColorScheme(.dark)
}
