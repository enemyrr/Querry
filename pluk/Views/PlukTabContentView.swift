//
//  TabContentView.swift
//  Pluk
//
//  Created by Claude on 6/14/25.
//

import SwiftUI

struct PlukTabContentView: View {
    @Environment(TabManager.self) private var tabManager
    
    var body: some View {
        Group {
            if let activeTab = tabManager.activeTab {
                switch activeTab.type {
                case .home:
                    HomeView()
                case .connection(let instanceId):
                    if let connectionInstance = ConnectionService.shared.getInstance(instanceId) {
                        DocumentView()
                            .environment(connectionInstance)
                    } else {
                        ConnectionErrorView()
                    }
                }
            } else {
                HomeView()
            }
        }
    }
}

struct ConnectionErrorView: View {
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Connection Error")
                .font(.headline)
            Text("Unable to load this connection")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
