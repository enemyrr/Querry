//
//  CreateConnection.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/31/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

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
    @State private var uri = ""
    @State private var name = ""
    @State private var color = ""
    @State private var selectedEnvironment: ConnectionEnvironment = .local
    @State private var selectedColor: Color = .blue
    @Environment(\.modelContext) private var modelContext
    
    private var isFormValid: Bool {
        !uri.isEmpty && !name.isEmpty && !color.isEmpty
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
                    TextField("e.g production", text: $name)
                        .textFieldStyle(CustomTextFieldStyle())
                }
                
                FormField(label: "URI") {
                    TextField("e.g mongodb+srv://user:password@cluster.mongodb.net/admin", text: $uri)
                        .textFieldStyle(CustomTextFieldStyle())
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
                
                Button("Connect") {
                    createConnection()
                }
                .primaryStyle()
                .disabled(!isFormValid)
                .frame(width: 200)
                
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
        }
        .padding(20)
    }
    
    func createConnection() {
        let connection = Connection(
            databaseType: .mongodb, url: uri, name: name, environment: selectedEnvironment
        )
        modelContext.insert(connection)
        
        // Close the sheet
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
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
