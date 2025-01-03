//
//  DocumentDetailView.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/2/25.
//
import SwiftUI
import AppKit
import MongoKitten

struct CollectionDetailView: View {
    var documents: [ProcessedDocument]
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack {
                    ForEach(Array(documents.enumerated()), id: \.offset) { index, document in
                        DocumentCardView(processedDoc: document)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all) // This will make it extend to the edges
        .background(Color(NSColor.controlBackgroundColor)) // Optional: Add window background color
    }
}
