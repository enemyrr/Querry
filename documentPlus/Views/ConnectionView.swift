//
//  ConnectionView.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/1/25.
//
import SwiftUI

struct ConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var connectionString = "mongodb://localhost:27017"
    @State private var database = "test"
    var onConnect: (String, String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Connection String", text: $connectionString)
                .textFieldStyle(.roundedBorder)
            
            TextField("Database", text: $database)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Button("Connect") {
                    onConnect(connectionString, database)
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: 400)
    }
}

