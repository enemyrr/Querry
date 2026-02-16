//
//  Notebook.swift
//  Pluk
//

import SwiftData
import SwiftUI

enum NotebookStatus: String, Codable, CaseIterable {
    case exploratory = "Exploratory"
    case inProgress = "In Progress"
    case approved = "Approved"
    case endorsed = "Endorsed"
    case production = "Production"

    var color: Color {
        switch self {
        case .exploratory: Color(red: 0.58, green: 0.44, blue: 0.72)
        case .inProgress: Color(red: 0.4, green: 0.56, blue: 0.75)
        case .approved: Color(red: 0.42, green: 0.65, blue: 0.52)
        case .endorsed: Color(red: 0.82, green: 0.6, blue: 0.4)
        case .production: Color(red: 0.75, green: 0.42, blue: 0.42)
        }
    }
}

@Model
final class Notebook {
    var id: UUID = UUID()
    var title: String = "Untitled Notebook"
    var descriptionText: String = ""
    var status: NotebookStatus = NotebookStatus.exploratory
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(title: String = "Untitled Notebook", description: String = "", status: NotebookStatus = .exploratory) {
        self.title = title
        self.descriptionText = description
        self.status = status
    }
}
