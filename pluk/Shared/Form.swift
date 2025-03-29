//
//  Form.swift
//  Collection
//
//  Created by Fauzaan on 2/5/25.
//

import SwiftUI

struct FormField<Content: View>: View {
    let label: String
    let content: Content
    
    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .foregroundColor(.white.opacity(0.7))
                .font(.system(size: 13))
            
            content
        }
    }
}
