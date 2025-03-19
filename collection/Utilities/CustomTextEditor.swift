//
//  CustomTextEditor.swift
//  Collection
//
//  Created by Fauzaan on 3/18/25.
//

import SwiftUI

import SwiftUI

struct CustomTextEditor: View {
    @Binding var text: String
    @State private var height: CGFloat = 100
    @State private var lineCount: Int = 1
    
    // Constants for height calculation
    private let lineHeight: CGFloat = 22 // Approximate height per line
    private let minLines: Int = 4
    private let maxHeight: CGFloat = 200
    private let verticalPadding: CGFloat = 20 // Top + bottom padding
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Line numbers view
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(1...lineCount, id: \.self) { lineNumber in
                        Text("\(lineNumber)")
                            .monospacedStyle(color: .gray)
                            .padding(.horizontal, 5)
                            .frame(width: 30, alignment: .trailing)
                    }
                    Spacer()
                }
                .frame(height: calculatedHeight)

                // Text editor with dynamic height adjustment
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .monospacedStyle(color: .white)
                        .padding([.bottom], 5)
                        .cornerRadius(3)
                        .frame(width: geometry.size.width - 40, height: calculatedHeight)
                        .onChange(of: text) { _, newValue in
                            calculateLineCount(for: newValue)
                        }
                        .scrollContentBackground(.hidden)
                    
                    // Hidden text view for height measurement
                    Text(text.isEmpty ? " " : text)
                        .foregroundColor(.clear)
                        .frame(width: geometry.size.width - 50)
                        .hidden()
                        .monospacedStyle(color: .white)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(GeometryReader { proxy in
                            Color.clear
                                .onChange(of: text) { _, _ in
                                    updateHeight(textHeight: proxy.size.height)
                                }
                                .onAppear {
                                    updateHeight(textHeight: proxy.size.height)
                                }
                        })
                }
            }
            .padding([.top, .bottom], 10)
        }
        .background(Color(.controlBackgroundColor).opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.separator, lineWidth: 1)
        )
        .cornerRadius(10)
        .onAppear {
            calculateLineCount(for: text)
        }
    }
    
    // Calculated height based on content with min/max constraints
    private var calculatedHeight: CGFloat {
        let minHeight = lineHeight * CGFloat(minLines) + verticalPadding
        return min(max(height, minHeight), maxHeight)
    }
    
    // Update height based on text measurement
    private func updateHeight(textHeight: CGFloat) {
        // Add padding to the measured text height
        let newHeight = textHeight + verticalPadding
        height = newHeight
    }
    
    private func calculateLineCount(for text: String) {
        lineCount = max(minLines, text.components(separatedBy: "\n").count)
    }
}
