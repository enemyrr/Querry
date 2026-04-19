//
//  WorkOSUser.swift
//  Pluk
//

import Foundation

struct WorkOSUser: Codable, Sendable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let profilePictureURL: String?
    let emailVerified: Bool

    var displayName: String {
        [firstName, lastName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
            .isEmpty
            ? email
            : [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case profilePictureURL = "profile_picture_url"
        case emailVerified = "email_verified"
    }
}
