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
    var errorMessage: String? = nil
    
    init(label: String, errorMessage: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
        self.errorMessage = errorMessage
    }
    
    var body: some View {
           VStack(alignment: .leading, spacing: 6) {
               HStack {
                   Text(label)
                       .foregroundColor(.secondary)
                       .font(.system(size: 13))
                   
                   Spacer()
                   
                   if let errorMessage = errorMessage, !errorMessage.isEmpty {
                       Text(errorMessage)
                           .foregroundColor(.red)
                           .font(.system(size: 12))
                   }
               }
               .padding(.leading, 2)
               
               content
           }
       }
}
