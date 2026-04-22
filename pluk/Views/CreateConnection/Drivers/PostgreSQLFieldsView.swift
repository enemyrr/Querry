//
//  PostgreSQLFieldsView.swift
//  Pluk
//
//  Created by Fauzaan on 8/16/25.
//

import SwiftUI

struct PostgreSQLFieldsView: View {
    @Binding var hostname: String
    @Binding var port: String
    @Binding var username: String
    @Binding var password: String
    @Binding var defaultDatabase: String
    @Binding var sslMode: String
    let onImportURI: (String) -> Void

    @State private var showURIImportPopover = false

    var body: some View {
        Group {
            Section {
                LabeledContent("Host") {
                    HStack(spacing: 4) {
                        TextField("", text: $hostname, prompt: Text("localhost"))
                            .multilineTextAlignment(.trailing)
                            .labelsHidden()
                            .frame(width: 180)

                        Text(":")
                            .foregroundStyle(.tertiary)

                        TextField("", text: $port, prompt: Text("5432"))
                            .multilineTextAlignment(.trailing)
                            .labelsHidden()
                            .frame(width: 50)
                    }
                }
                TextField("Database", text: $defaultDatabase, prompt: Text("postgres"))
            } header: {
                HStack {
                    Text("Connection")
                    Spacer()
                    Button("Import from URI") {
                        showURIImportPopover.toggle()
                    }
                    .popover(isPresented: $showURIImportPopover, arrowEdge: .top) {
                        URIImportPopover(
                            placeholder: "postgresql://username:password@host:port/database"
                        ) { uri in
                            onImportURI(uri)
                            showURIImportPopover = false
                        }
                    }
                }
                .padding(.trailing, -8)
            }

            Section {
                TextField("Username", text: $username, prompt: Text("postgres"))
                SecureField("Password", text: $password, prompt: Text("password"))
            }

            Section {
                Picker("SSL Mode", selection: $sslMode) {
                    Text("disable").tag("disable")
                    Text("prefer").tag("prefer")
                    Text("require").tag("require")
                }
            }
        }
    }
}

struct URIImportPopover: View {
    let placeholder: String
    let onImport: (String) -> Void

    @State private var uriInput: String = ""
    @FocusState private var uriFieldFocused: Bool

    private var trimmedInput: String {
        uriInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedInput.isEmpty
    }

    var body: some View {
        VStack(spacing: 10) {
            TextField(placeholder, text: $uriInput)
                .textFieldStyle(CustomTextFieldStyle())
                .font(.system(size: 12))
                .focused($uriFieldFocused)
                .onSubmit(submit)

            HStack {
                Spacer()

                Button(action: submit) {
                    HStack(spacing: 5) {
                        Text("Import")
                            .font(.system(size: 11, weight: .semibold))

                        Text("⏎")
                            .font(.system(size: 10, weight: .semibold))
                            .opacity(0.7)
                    }
                    .foregroundStyle(canSubmit ? Color(.textBackgroundColor) : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(canSubmit ? Color.primaryButton : Color.primaryButton.opacity(0.35))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(12)
        .frame(width: 360)
        .task {
            try? await Task.sleep(for: .milliseconds(80))
            uriFieldFocused = true
        }
    }

    private func submit() {
        guard canSubmit else { return }
        onImport(trimmedInput)
    }
}
