//
//  NotebookCard.swift
//  Pluk
//

import SwiftUI

struct NotebookIcon: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(red: 0.6, green: 0.4, blue: 0.1))
            .frame(width: 28, height: 28)
            .overlay(
                Image(systemName: "doc.text")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
            )
    }
}

struct NotebookStatusTag: View {
    let status: NotebookStatus

    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 10))
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(status.color)
            )
    }
}
