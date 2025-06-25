//
//  AboutView.swift
//  Pluk
//
//  Created by Fauzaan on 4/26/25.
//
import SwiftUI

struct AboutView: View {
    var body: some View {
        HStack(spacing: 20) {
            if let appIcon = NSApplication.shared.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 84, height: 84)
                    .cornerRadius(16)
                    .accessibilityLabel("Application icon")
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Pluk")
                    .font(.system(size: 28, weight: .regular))
                
                Text("Version \(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .foregroundColor(.secondary)
                
                Text("Copyright © 2025 Pluk, Inc. All rights reserved")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                    .padding(.top, 10)
            }
            .padding(.trailing, 30)
        }
        .padding(.top, 10)
        .padding([.horizontal, .bottom], 30)
    }
}
