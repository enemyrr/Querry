//
//  DatabaseView.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/17/25.
//

import Foundation
import SwiftUI

struct DatabaseView: View {
    let databaseName: String
    
    var body: some View {
        VStack(spacing: 0) {
            Text(databaseName)
                .font(.title)
            
            VStack {
                Text("Database Content for \(databaseName)")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator, lineWidth: 1)
            )
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .padding(8)
        }
        .padding(.top, 12)
        .ignoresSafeArea(.all)
    }
}

