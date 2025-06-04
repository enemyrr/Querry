//
//  DatabaseView.swift
//  Collection
//
//  Created by Fauzaan on 1/17/25.
//

import Foundation
import SwiftUI

struct DocumentView: View {
    var instance: ConnectionInstance
    
    var body: some View {
        VStack(spacing: 0) {
            TabBar(instance: instance)
                .zIndex(1)
            
            VStack {
                if let selectedTab = instance.selectedTab {
                    switch instance.connection.databaseType {
                    case .postgres:
                                TableListView(viewModel: instance.viewModel(for: selectedTab))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .id(selectedTab.id)
                            case .mongodb:
                        DocumentList(viewModel: instance.viewModel(for: selectedTab))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .id(selectedTab.id)
                    default:
                        Text("No collection selected")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                } else {
                    Text("No collection selected")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)
            .zIndex(-1)
        }
        .padding(.top, 8)
        .ignoresSafeArea(.all)
        .zIndex(-1)
    }
}

