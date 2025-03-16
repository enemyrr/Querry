//
//  QueryEditor.swift
//  Collection
//
//  Created by Fauzaan on 3/16/25.
//

import SwiftUI

struct QueryEditor: View {
    @ObservedObject var viewModel: SearchQueryViewModel
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if !viewModel.derivedFilter.isEmpty {
                VStack {
                    if !viewModel.isFullQueryEditorOpen {
                        filterSyntaxView(filter: viewModel.derivedFilter)
                            .onTapGesture {
                                viewModel.toggleFullQueryEditor()
                            }
                    } else {
                        fullQueryEditorView()
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.isFullQueryEditorOpen)
                .modifier(GlassBackgroundStyle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.separator, lineWidth: 1)
                )
                
                if !viewModel.isFullQueryEditorOpen {
                    Spacer()
                    HStack(spacing: 4) {
                        Text("\(viewModel.matchingDocumentsCount) documents").font(.caption)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .modifier(GlassBackgroundStyle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(.separator, lineWidth: 1)
                            )
                        
                        Button(action: {
                            viewModel.executeQuery()
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
                        .disabled(viewModel.isProcessing)
                    }
                }
            }
        }
        .padding(.bottom, viewModel.isFullQueryEditorOpen ? -12 : 0)
        .frame(maxWidth: viewModel.isFullQueryEditorOpen ? 750 : 450)
    }
    
    // Function to display filter syntax with highlighting
    private func filterSyntaxView(filter: String) -> some View {
        // Parse filter into highlighted components using the ViewModel
        let components = viewModel.parseFilterComponents(filter)
        
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
    
    // Full query editor view as a private function
    private func fullQueryEditorView() -> some View {
        VStack(spacing: 0) {
            // Query Editor Header
            HStack {
                Text("Query Editor")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(viewModel.matchingDocumentsCount) rows \(viewModel.queryExecutionTime)")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                Button(action: {}) {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Text(viewModel.lastQueryTime)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                Button(action: {
                    viewModel.executeQuery()
                }) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isProcessing)
                
                Button(action: {
                    viewModel.toggleFullQueryEditor()
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
