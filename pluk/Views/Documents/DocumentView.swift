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
    var isSidebarVisible: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            TabBar(instance: instance, isSidebarVisible: isSidebarVisible)
                .zIndex(1)
            
            VStack {
                if let selectedTab = instance.selectedTab {
                    DocumentList(
                        instance: instance,
                        selectedTab: selectedTab
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(selectedTab.id)
                } else {
                    VStack {
                        Text("No collection selected")
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
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

