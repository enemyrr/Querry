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
            
            // NSTabView for content management (hidden tabs)
            NSTabViewWrapper(instance: instance)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding([.leading, .trailing, .bottom], 8)
            .zIndex(-1)
        }
        .padding(.top, 8)
        .ignoresSafeArea(.all)
        .zIndex(-1)
    }
}
