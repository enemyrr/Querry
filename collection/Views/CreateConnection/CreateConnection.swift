//
//  CreateConnection.swift
//  Collection
//
//  Created by Fauzaan on 1/31/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import MongoKitten
import SwiftData

struct CreateConnection: View {
    @State private var showSheet = false
    
    var body: some View {
        Button(action: {
            showSheet.toggle()
        }) {
            Image(systemName: "plus.circle").font(.title3).foregroundStyle(.secondary)
        }
        .buttonStyle(ActionButtonStyle())
        .sheet(isPresented: $showSheet) {
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .ignoresSafeArea()
                CreateConnectionForm()
                    .frame(width: 500)
            }
        }
    }
}

struct CreateConnectionForm: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var uri = ""
    @State private var name = ""
    @State private var color: Optional<ConnectionColor> = nil
    @State private var selectedEnvironment: ConnectionEnvironment = .local
    @State private var uriError: String? = nil
    
    private let connectionId: PersistentIdentifier?
    
    init(connectionId: PersistentIdentifier? = nil) {
        self.connectionId = connectionId
        
        _uri = State(initialValue: "")
        _name = State(initialValue: "")
        _color = State(initialValue: .blue)
        _selectedEnvironment = State(initialValue: .local)
    }
    
    private var isFormValid: Bool {
        !uri.isEmpty && !name.isEmpty && uriError == nil
    }
    
    private func validateMongoUri(_ uri: String) {
        guard !uri.isEmpty else {
            uriError = nil
            return
        }
        
        do {
            let connectionSettings = try ConnectionSettings(uri)
            
            if connectionSettings.targetDatabase == nil {
                uriError = "Include a default database name in the URI"
            } else{
                uriError = nil
            }
        } catch {
            uriError = error.localizedDescription
        }
    }
    
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading) {
                    Text("New Connection")
                        .font(.title3)
                        .foregroundColor(.white)
                    Text("Manage your connection settings")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }.padding(.horizontal, 10)
            
            // Form Fields
            VStack(alignment: .leading, spacing: 16) {
                FormField(label: "Name") {
                    TextField("e.g first connection", text: $name)
                        .textFieldStyle(CustomTextFieldStyle())
                }
                
                FormField(label: "URI") {
                    TextField("e.g mongodb+srv://user:password@cluster.mongodb.net/admin", text: $uri)
                        .textFieldStyle(CustomTextFieldStyle())
                        .onChange(of: uri) { oldValue, newValue in
                            validateMongoUri(newValue)
                        }
                    
                    if let error = uriError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
            }
            .padding(20)
            .background(Color(.controlColor).opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator, lineWidth: 1)
            )
            .cornerRadius(10)
            
            HStack(spacing: 16) {
                EnvironmentPicker(selectedEnvironment: $selectedEnvironment)
                ConnectionColorPicker(selectedColor: $color)
            }
            .padding(20)
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
                Spacer()
                
                Button(connectionId != nil ? "Update" : "Connect") {
                    saveConnection()
                }
                .primaryStyle()
                .disabled(!isFormValid)
                .frame(width: 200)
                
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
        }
        .onAppear {
//                    loadConnectionData()
                }
        .padding(20)
    }
    
    private func loadConnectionData() {
            guard let id = connectionId else { return }
            
            do {
                let connection = try modelContext.fetch(
                    FetchDescriptor<Connection>(
                        predicate: #Predicate { $0.persistentModelID == id }
                    )
                ).first
                
                if let connection = connection {
                    uri = connection.url
                    name = connection.name
                    color = connection.color
                    selectedEnvironment = connection.environment
                }
            } catch {
                print("Error loading connection: \(error)")
            }
        }
    
    private func saveConnection() {
        if let id = connectionId,
           let existing = try? modelContext.fetch(
                FetchDescriptor<Connection>(
                    predicate: #Predicate { $0.persistentModelID == id }
                )
            ).first {
            existing.url = uri
            existing.name = name
            existing.color = color.unsafelyUnwrapped
            existing.environment = selectedEnvironment
            try? modelContext.save()
        } else {
            let connection = Connection(
                databaseType: .mongodb,
                url: uri,
                name: name,
                color: color.unsafelyUnwrapped,
                environment: selectedEnvironment
            )
            modelContext.insert(connection)
        }
        
        dismiss()
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        
        if #available(macOS 10.14, *) {
            view.isEmphasized = false
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
