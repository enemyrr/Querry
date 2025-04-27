//
//  FeedbackForm.swift
//  Pluk
//
//  Created by Fauzaan on 4/25/25.
//

import SwiftUI

struct FeedbackForm: View {
    @Bindable var viewModel: SidebarViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading) {
                    Text("Send Feedback")
                        .font(.title3)
                    Text("We'd love to hear how we can make Pluk better")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Message field
            FormField(label: "Message") {
                TextEditorWithPlaceholder(
                     text: $viewModel.feedbackText,
                     placeholder: "Found a bug or missing a feature you really want to see?",
                     height: 120
                 )
            }
            
            FormField(label: "Email") {
                TextField("your@email.com", text: $viewModel.feedbackEmail)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            
            // Footer
            HStack {
                Spacer()
                
                
                Button {
                    Task {
                        await viewModel.submitFeedback()
                    }
                } label: {
                    if viewModel.isFeedbackSubmitting {
                        Text("Submitting...")
                    } else {
                        Text(viewModel.isFeedbackSubmitted ? "Thank you!" : "Send Feedback")
                    }
                }
                .primaryStyle()
                .disabled(
                    viewModel.feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    viewModel.feedbackEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    viewModel.isFeedbackSubmitting ||
                    viewModel.isFeedbackSubmitted
                )
                .frame(width: 200)
            }
            .padding(.top, 10)
        }
        .padding(20)
        .frame(width: 400)
    }
}


