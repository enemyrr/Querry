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
import MongoCore
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
    @State private var defaultDatabase = ""
    @State private var color: Optional<ConnectionColor> = nil
    @State private var selectedEnvironment: ConnectionEnvironment = .local
    @State private var uriError: String? = nil
    @State private var showDatabaseField = false

    @FocusState private var uriFieldIsFocused: Bool
    
    private let connectionId: PersistentIdentifier?
    
    init(connectionId: PersistentIdentifier? = nil) {
        self.connectionId = connectionId
        
        _uri = State(initialValue: "")
        _name = State(initialValue: "")
        _color = State(initialValue: .blue)
        _selectedEnvironment = State(initialValue: .local)
        _defaultDatabase = State(initialValue: "")
    }
    
    private var isFormValid: Bool {
        !uri.isEmpty &&
          !name.isEmpty &&
          uriError == nil &&
          (!showDatabaseField || !defaultDatabase.isEmpty)
    }
    
    private func validateMongoUri(_ uri: String) {
        guard !uri.isEmpty else {
            uriError = nil
            return
        }
        
        do {
            let connectionSettings = try ConnectionSettings(uri)
            
            if let database = connectionSettings.targetDatabase {
                defaultDatabase = database
                showDatabaseField = false
            } else {
                defaultDatabase = ""
                showDatabaseField = true
            }
        } catch let error as MongoInvalidUriError {
            uriError = error.description
        } catch {
            uriError = "The given MongoDB connection URI is invalid"
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
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                           Text("URI")
                               .font(.subheadline)
                               .foregroundColor(.secondary)
                           
                           Spacer()
                           
                           if let error = uriError {
                               Text(error)
                                   .font(.caption)
                                   .foregroundColor(.red)
                                   .lineLimit(1)
                                   .truncationMode(.tail)
                           }
                       }
                       
                    
                    HStack(spacing: 8) {
                        TextField("e.g mongodb+srv://user:password@cluster.mongodb.net", text: $uri)
                            .textFieldStyle(CustomTextFieldStyle())
                            .focused($uriFieldIsFocused)
                            .onChange(of: uri) { oldValue, newValue in
                                if (uriFieldIsFocused) {
                                    validateMongoUri(newValue)
                                }
                            }
                        
                        if showDatabaseField {
                            Text("/")
                                .foregroundColor(.secondary)
                            
                            TextField("database", text: $defaultDatabase)
                                .textFieldStyle(CustomTextFieldStyle())
                                .frame(width: 100)
                        }
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
            loadExistingConnectionData()
        }
        .padding(20)
    }
    
    private func loadExistingConnectionData() {
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
                
                if connection.defaultDatabase != nil {
                    showDatabaseField = true
                    defaultDatabase = connection.defaultDatabase ?? ""
                }
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
            existing.defaultDatabase = defaultDatabase
            try? modelContext.save()
        } else {
            let connection = Connection(
                databaseType: .mongodb,
                url: uri,
                name: name,
                color: color.unsafelyUnwrapped,
                environment: selectedEnvironment,
                defaultDatabase: defaultDatabase
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
