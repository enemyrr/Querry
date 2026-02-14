//
//  KeychainHelper.swift
//  Pluk
//
//  Created by Fauzaan on 8/2/25.
//

import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()

    private init() {}

    // MARK: - Store Password
    @discardableResult
    func store(password: String, for connectionId: String) -> Bool {
        let data = password.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Pluk",
            kSecAttrAccount as String: connectionId,
            kSecUseDataProtectionKeychain as String: true,
            kSecValueData as String: data
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Retrieve Password
    func retrieve(for connectionId: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Pluk",
            kSecAttrAccount as String: connectionId,
            kSecUseDataProtectionKeychain as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let password = String(data: data, encoding: .utf8) {
            return password
        }

        // Migration: try the legacy keychain (without Data Protection)
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Pluk",
            kSecAttrAccount as String: connectionId,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var legacyRef: AnyObject?
        let legacyStatus = SecItemCopyMatching(legacyQuery as CFDictionary, &legacyRef)

        if legacyStatus == errSecSuccess,
           let data = legacyRef as? Data,
           let password = String(data: data, encoding: .utf8) {
            store(password: password, for: connectionId)

            let deleteLegacy: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "Pluk",
                kSecAttrAccount as String: connectionId
            ]
            SecItemDelete(deleteLegacy as CFDictionary)

            return password
        }

        return nil
    }

    // MARK: - Delete Password
    @discardableResult
    func delete(for connectionId: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Pluk",
            kSecAttrAccount as String: connectionId,
            kSecUseDataProtectionKeychain as String: true
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Update Password
    @discardableResult
    func update(password: String, for connectionId: String) -> Bool {
        let data = password.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Pluk",
            kSecAttrAccount as String: connectionId,
            kSecUseDataProtectionKeychain as String: true
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        // If item doesn't exist, create it
        if status == errSecItemNotFound {
            return store(password: password, for: connectionId)
        }

        return status == errSecSuccess
    }

    // MARK: - Check if Password Exists
    func passwordExists(for connectionId: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Pluk",
            kSecAttrAccount as String: connectionId,
            kSecUseDataProtectionKeychain as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}
