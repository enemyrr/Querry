//
//  DatabaseView.swift
//  DocumentPlus
//
//  Created by Fauzaan on 1/17/25.
//

import Foundation
import SwiftUI

struct DatabaseView: View {
    @State private var appState = AppState.shared
    let databaseName: String
    
    var body: some View {
        VStack(spacing: 0) {
            TabBar(tabs: $appState.tabs, selectedTab: $appState.selectedTab)
            
            VStack {
                if let selectedTab = appState.selectedTab {
                    DocumentView(
                        collection: selectedTab
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(selectedTab)
                } else {
                    Text("No item found")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                }
            }
            .background(Color(.controlBackgroundColor).opacity(0.6))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator, lineWidth: 1)
            )
            .cornerRadius(10)
            .padding(8)
        }
        .padding(.top, 12)
        .ignoresSafeArea(.all)
    }
}

