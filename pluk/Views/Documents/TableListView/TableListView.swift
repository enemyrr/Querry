//
//  TableListView.swift
//  Pluk
//
//  Created by Fauzaan on 6/2/25.
//
import Foundation
import SwiftUI
import AppKit

struct TableListView: View {
    private let viewModel: DocumentListModel
    @State private var schema: DatabaseSchemaResult?
    
    init(viewModel: DocumentListModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        Group {
            if let rowDocuments = viewModel.rowDocuments, let schema = schema {
                TableListViewController(
                    rows: rowDocuments,
                    schema: schema
                )
                .padding(4)
                .background(Color(.controlColor).opacity(0.1))
                .cornerRadius(10)
                .background {
                    TabConnectedBorder()
                }
//                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                VStack {
                        ProgressView().controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.controlColor).opacity(0.1))
                .background {
                    TabConnectedBorder()
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .task {
            if let selectedTab = viewModel.instance.selectedTab {
                do {
                    let schemaResult = try await viewModel.databaseDriver.getSchema(for: selectedTab.name)
                    await MainActor.run {
                        self.schema = schemaResult
                    }
                } catch {
                    print("Failed to get schema: \(error)")
                }
            }
        }
        .task {
            if !viewModel.intialLoadComplete {
                await viewModel.loadDocuments()
            }
        }
    }
}

struct TabConnectedBorder: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let rect = geometry.frame(in: .local)
                let cornerRadius: CGFloat = 10
                let topBorderLength: CGFloat = 14
                
                // Start from top-right corner with short top border
                path.move(to: CGPoint(x: rect.width - topBorderLength, y: 0))
                
                // Short top border on the right
                path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: 0))
                
                // Top-right corner
                path.addQuadCurve(
                    to: CGPoint(x: rect.width, y: cornerRadius),
                    control: CGPoint(x: rect.width, y: 0)
                )
                
                // Right border
                path.addLine(to: CGPoint(x: rect.width, y: rect.height - cornerRadius))
                
                // Bottom-right corner
                path.addQuadCurve(
                    to: CGPoint(x: rect.width - cornerRadius, y: rect.height),
                    control: CGPoint(x: rect.width, y: rect.height)
                )
                
                // Bottom border
                path.addLine(to: CGPoint(x: cornerRadius, y: rect.height))
                
                // Bottom-left corner
                path.addQuadCurve(
                    to: CGPoint(x: 0, y: rect.height - cornerRadius),
                    control: CGPoint(x: 0, y: rect.height)
                )
                
                // Left border
                path.addLine(to: CGPoint(x: 0, y: cornerRadius))
                
                // Top-left corner
                path.addQuadCurve(
                    to: CGPoint(x: cornerRadius, y: 0),
                    control: CGPoint(x: 0, y: 0)
                )
                
                // Short top border on the left
                path.addLine(to: CGPoint(x: topBorderLength, y: 0))
            }
            .stroke(Color(.separatorColor), lineWidth: 1)
        }
    }
}
