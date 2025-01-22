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
    var instance: ConnectionInstance
    
    var body: some View {
        VStack(spacing: 0) {
            TabBar(instance: instance)
            
            VStack {
                if let selectedTab = instance.selectedTab {
                    DocumentView(
                        instance: instance,
                        selectedTab: selectedTab
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(selectedTab.id)
                } else {
                    VStack {
                        Text("No database selected")
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
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

