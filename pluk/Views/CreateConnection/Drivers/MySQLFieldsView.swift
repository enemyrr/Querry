//
//  MySQLFieldsView.swift
//  Pluk
//
//  Created by Fauzaan on 8/18/25.
//

import SwiftUI

struct MySQLFieldsView: View {
    @Binding var hostname: String
    @Binding var port: String
    @Binding var username: String
    @Binding var password: String
    @Binding var defaultDatabase: String
    @Binding var sslMode: String
    @Binding var showURIImportSheet: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Database Connection")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Spacer()
                
                Button("Import from URI") {
                    showURIImportSheet = true
                }
                .font(.caption)
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    FormField(label: "Host") {
                        TextField("localhost", text: $hostname)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    FormField(label: "Port") {
                        TextField("3306", text: $port)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    .frame(width: 120)
                }
                
                HStack(spacing: 12) {
                    FormField(label: "Username") {
                        TextField("root", text: $username)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    FormField(label: "Password") {
                        SecureField("password", text: $password)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                }
                
                HStack(spacing: 12) {
                    FormField(label: "Database") {
                        TextField("mysql", text: $defaultDatabase)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    FormField(label: "SSL Mode") {
                        Menu {
                            Button(action: { sslMode = "disable" }) {
                                Text("disable")
                            }
                            Button(action: { sslMode = "prefer" }) {
                                Text("prefer")
                            }
                            Button(action: { sslMode = "require" }) {
                                Text("require")
                            }
                        } label: {
                            Text(sslMode)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Image(systemName: "chevron.compact.down")
                                .scaleEffect(CGSize(width: 0.7, height: 1.5))
                        }
                        .menuStyle(.button)
                        .buttonStyle(CustomMenuButtonStyle())
                    }
                }
            }
            .padding(16)
            .background(Color(.controlColor).opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.separator, lineWidth: 1)
            )
            .cornerRadius(16)
        }
    }
}

struct MySQLURIImportSheet: View {
    @Binding var uriInput: String
    let onImport: (String) -> Void
    let onCancel: () -> Void
    
    @FocusState private var uriFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Text("Import from URI")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                Text("Paste your MySQL connection URI to autofill the form fields")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            // URI Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Connection URI")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("mysql://username:password@host:port/database", text: $uriInput)
                    .textFieldStyle(CustomTextFieldStyle())
                    .focused($uriFieldFocused)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            uriFieldFocused = true
                        }
                    }
            }
            .padding(.horizontal, 24)
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .customMenuButtonStyle()
                
                Spacer()
                
                Button("Import") {
                    onImport(uriInput)
                }
                .primaryStyle()
                .disabled(uriInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .frame(width: 120)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 480)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }
}