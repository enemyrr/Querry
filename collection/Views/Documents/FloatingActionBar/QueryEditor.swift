//
//  QueryEditor.swift
//  Collection
//
//  Created by Fauzaan on 3/16/25.
//

import SwiftUI

struct QueryEditor: View {
    @ObservedObject var viewModel: DocumentViewModel
    
    @State var showFilterView: Bool = true
    @State private var derivedFilter: String = "{ Users NOT NULL }"
    @State private var isFullQueryEditorOpen: Bool = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            VStack {
                if !isFullQueryEditorOpen {
                    filterSyntaxView(filter: derivedFilter)
                        .onTapGesture {
                            // Start the scale animation before opening the full editor
                            withAnimation(.spring(response: 0.15)) {
                                isFullQueryEditorOpen = true
                            }
                        }
                } else {
                    fullQueryEditorView()
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isFullQueryEditorOpen)
            .modifier(GlassBackgroundStyle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator, lineWidth: 1)
            )
            
            if !isFullQueryEditorOpen {
                Spacer()
                HStack(spacing: 4) {
                    Text("2 documents").font(.caption)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .modifier(GlassBackgroundStyle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.separator, lineWidth: 1)
                        )
                    
                    Button(action: {
                        // Enable inline editing
                        withAnimation {
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.caption)
                            
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    Color.black.opacity(0.3)
                                )
                        )
                        .modifier(GlassBackgroundStyle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.separator, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, isFullQueryEditorOpen ? -12 : 0)
        .frame(maxWidth: isFullQueryEditorOpen ? 750 : 450)
    }
    
    // Function to display filter syntax with highlighting
    private func filterSyntaxView(filter: String) -> some View {
        // Parse filter into highlighted components
        let components = parseFilterComponents(filter)
        
        return HStack(spacing: 2) {
            Image(systemName: "curlybraces.square.fill")
                .font(.caption)
                .padding(.trailing, 8)
            ForEach(components) { component in
                Text(component.text)
                    .font(.caption)
                    .foregroundColor(component.color)
            }
        }
    }
    
    // Parse filter into components for syntax highlighting
    private func parseFilterComponents(_ filter: String) -> [FilterComponent] {
        var components: [FilterComponent] = []
        
        let words = filter.split(separator: " ")
        for (index, word) in words.enumerated() {
            let text = String(word)
            
            if ["AND", "OR", "NOT"].contains(text.uppercased()) {
                components.append(FilterComponent(id: index, text: text, color: .blue))
            } else if ["=", ">", "<", ">=", "<=", "!=", "CONTAINS", "IN"].contains(text.uppercased()) {
                components.append(FilterComponent(id: index, text: text, color: .purple))
            } else if text.hasPrefix("'") && text.hasSuffix("'") {
                components.append(FilterComponent(id: index, text: text, color: .green))
            } else if let _ = Double(text) {
                components.append(FilterComponent(id: index, text: text, color: .orange))
            } else if ["true", "false"].contains(text.lowercased()) {
                components.append(FilterComponent(id: index, text: text, color: .orange))
            } else {
                components.append(FilterComponent(id: index, text: text, color: .primary))
            }
            
            if index < words.count - 1 {
                components.append(FilterComponent(id: index + 1000, text: " ", color: .primary))
            }
        }
        
        return components
    }
    
    // Full query editor view as a private function
    private func fullQueryEditorView() -> some View {
        VStack(spacing: 0) {
            // Query Editor Header
            HStack {
                Text("Query Editor")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("2 rows 0s")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                Button(action: {}) {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Text("23m ago")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                Button(action: {}) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    // Add a bounce-out effect when closing
                    withAnimation(.spring(response: 0.15)) {
                        isFullQueryEditorOpen = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            // SQL Editor area
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("1")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .trailing)
                        .padding(.trailing, 8)
                    
                    Group {
                        Text("SELECT ")
                            .foregroundColor(.blue)
                        Text("*")
                            .foregroundColor(.purple)
                        Text(" FROM ")
                            .foregroundColor(.blue)
                        Text("ANALYTICS.PROD.ORDER_DETAILS")
                            .foregroundColor(.green)
                        Text(" WHERE ")
                            .foregroundColor(.blue)
                        Text("ORDER_ID")
                            .foregroundColor(.primary)
                        Text(" = ")
                            .foregroundColor(.purple)
                        Text("1")
                            .foregroundColor(.orange)
                        Text(";")
                            .foregroundColor(.primary)
                    }
                    .font(.system(.body, design: .monospaced))
                    
                    Spacer()
                }
                .padding(.vertical, 4)
                
                // Add additional rows as needed
                HStack {
                    Text("2")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .trailing)
                        .padding(.trailing, 8)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .padding([.top, .horizontal, .bottom])
        }
    }
}
