//
//  FeedbackForm.swift
//  Pluk
//
//  Created by Fauzaan on 4/25/25.
//

import SwiftUI

struct FeedbackForm: View {
    @Bindable var viewModel: SidebarViewModel
    @State private var hoveredButton: String?
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading) {
                    Text("We’re here to help")
                        .font(.title3)
                    Text("Found a bug, have an idea, or just a question? We’d love to hear from you.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Bug Report Button
                Button(action: {
                    openGitHubIssue(type: "bug")
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Report a Bug")
                                .font(.system(size: 14, weight: .medium))
                            Text("Spotted something broken? Tell us and we’ll fix it.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(hoveredButton == "bug" ? Color(.controlColor).opacity(0.3) : Color.clear)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.separator, lineWidth: 0.5)
                    )
                    .onHover { isHovered in
                        hoveredButton = isHovered ? "bug" : nil
                    }
                }
                .buttonStyle(.plain)
                
                // Feature Request Button
                Button(action: {
                    openGitHubIssue(type: "feature")
                }) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Request a Feature")
                                .font(.system(size: 14, weight: .medium))
                            Text("Got an idea? Share it — we’re all ears.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(hoveredButton == "feature" ? Color(.controlColor).opacity(0.3) : Color.clear)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.separator, lineWidth: 0.5)
                    )
                    .onHover { isHovered in
                        hoveredButton = isHovered ? "feature" : nil
                    }
                }
                .buttonStyle(.plain)
                
                // General Feedback Button
                Button(action: {
                    openGitHubIssue(type: "general")
                }) {
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ask a Question")
                                .font(.system(size: 14, weight: .medium))
                            Text("Curious about something? Just ask.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(hoveredButton == "question" ? Color(.controlColor).opacity(0.3) : Color.clear)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.separator, lineWidth: 0.5)
                    )
                    .onHover { isHovered in
                        hoveredButton = isHovered ? "question" : nil
                    }
                }
                .buttonStyle(.plain)
                
                // Quick Help via Twitter Button
                Button(action: {
                    if let url = URL(string: "https://x.com/pluk_sh") {
                        NSWorkspace.shared.open(url)
                    }
                    viewModel.isShowingFeedback = false
                }) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quick Help")
                                .font(.system(size: 14, weight: .medium))
                            Text("Need help right now? Ping us on X")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(hoveredButton == "twitter" ? Color(.controlColor).opacity(0.3) : Color.clear)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.separator, lineWidth: 0.5)
                    )
                    .onHover { isHovered in
                        hoveredButton = isHovered ? "twitter" : nil
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
    
    private func openGitHubIssue(type: String) {
        var urlString: String
        
        switch type {
        case "bug":
            urlString = "https://github.com/pluk-inc/Pluk/issues/new?template=bug_report.md"
        case "feature":
            urlString = "https://github.com/pluk-inc/Pluk/issues/new?template=feature_request.md"
        case "general":
            urlString = "https://github.com/pluk-inc/Pluk/issues/new?template=question.md"
        default:
            urlString = "https://github.com/pluk-inc/Pluk/issues/new"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        
        // Close the feedback form
        viewModel.isShowingFeedback = false
    }
}


