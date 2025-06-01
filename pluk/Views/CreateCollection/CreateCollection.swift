//
//  CreateConnection.swift
//  Collection
//
//  Created by Fauzaan on 1/31/25.
//
import SwiftUI

struct CreateCollection: View {
    @State private var showSheet = false
    var viewModel: SidebarViewModel
    
    var body: some View {
        Button(action: {
            showSheet.toggle()
        }) {
            Image(systemName: "plus.circle").font(.title3).foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showSheet) {
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .ignoresSafeArea()
                CreateCollectionForm(viewModel: viewModel)
            }
        }
        .buttonStyle(ActionButtonStyle())
        .keyboardShortcut("N", modifiers: [.command, .shift])
        .customHelp("New collection", position: .top, shortcut: KeyboardShortcut(
            modifiers: [.command, .shift],
            key: "N"
        ))
    }
}

struct CreateCollectionForm: View {
    var viewModel: SidebarViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Form state
    @State private var name = ""
    @State private var nameError: String? = nil
    
    // Submission state
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert = false
    
    private var isFormValid: Bool {
        !name.isEmpty && nameError == nil
    }
    
    private func validateCollectionName(_ name: String) -> String? {
        // Check if empty
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Collection name cannot be empty"
        }
        
        // Check length (MongoDB has a maximum name length)
        if name.count > 64 {
            return "Collection name cannot exceed 64 characters"
        }
        
        // Check if name starts with 'system.' (reserved prefix)
        if name.hasPrefix("system.") {
            return "Collection names cannot start with 'system.'"
        }
        
        // Check for illegal characters
        // MongoDB doesn't allow $ in collection names or empty strings
        if name.contains("$") {
            return "Collection name cannot contain the '$' character"
        }
        
        // Check for null character
        if name.contains("\0") {
            return "Collection name cannot contain null characters"
        }
        
        // Check for valid first character (cannot start with a period)
        if name.hasPrefix(".") {
            return "Collection name cannot start with a period"
        }
        
        // Check for reserved characters in file systems
        let reservedChars = ["\\", "/", ":", "*", "\"", "<", ">", "|", "?"]
        for char in reservedChars {
            if name.contains(char) {
                return "Collection name cannot contain '\(char)'"
            }
        }
        
        return nil // Return nil if valid
    }
    
    private func createCollection() {
        guard !isSubmitting else { return }
        
        errorMessage = nil
        isSubmitting = true
        
        Task {
            do {
                try await viewModel.createCollection(withName: name)
                
                // Return to the main thread to update UI
                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                    
                    Task {
                        await viewModel.activeConnection?.loadCollectionsForCurrentDatabase()
                        
                        // Open a new tab
                        if let activeConnection = viewModel.activeConnection {
                            activeConnection.createNewTab(
                                name: name
                            )
                        }
                    }
                }
            } catch let error as NSError {
                await MainActor.run {
                    isSubmitting = false
                    // Provide more specific error messages based on error code/domain
                    if error.domain == "MongoKitten" && error.code == 48 {
                        errorMessage = "Collection '\(name)' already exists"
                    } else {
                        errorMessage = "Failed to create collection: \(error.localizedDescription)"
                    }
                    showErrorAlert = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Failed to create collection: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Create collection")
                    .font(.title3)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 0)
            
            VStack(alignment: .leading, spacing: 16) {
                FormField(label: "Name") {
                    TextField("e.g new-collection", text: $name)
                        .textFieldStyle(CustomTextFieldStyle())
                        .disabled(isSubmitting)
                        .onChange(of: name) { _, newValue in
                            nameError = validateCollectionName(newValue)
                        }
                }
            }
            .padding(15)
            .background(Color(.controlColor).opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator, lineWidth: 1)
            )
            .cornerRadius(10)
            
            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .customMenuButtonStyle()
                .disabled(isSubmitting)
                
                Spacer()
                
                Button(action: createCollection) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                                .padding(.trailing, 5)
                        }
                        Text(isSubmitting ? "Creating..." : "Create")
                    }
                }
                .primaryStyle()
                .disabled(!isFormValid || isSubmitting)
                .frame(width: 200)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
        }
        .padding(20)
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .disabled(isSubmitting) // Disable entire form during submission
    }
}
