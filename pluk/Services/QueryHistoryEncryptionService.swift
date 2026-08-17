//
//  QueryHistoryEncryptionService.swift
//  Pluk
//
//  Created by Claude on 1/23/26.
//

import Foundation
import CryptoKit

struct QueryHistoryEncryptionService {
    private static let appSalt = "PlukQueryHistorySecure2026"

    static func encrypt(query: String, connectionKeychainId: String) -> String? {
        guard !query.isEmpty else { return nil }

        let key = deriveKey(from: connectionKeychainId)

        guard let data = query.data(using: .utf8) else { return nil }

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else { return nil }
            return combined.base64EncodedString()
        } catch {
            debugLog("Encryption failed: \(error)")
            return nil
        }
    }

    static func decrypt(encryptedQuery: String, connectionKeychainId: String) -> String? {
        guard !encryptedQuery.isEmpty else { return nil }

        let key = deriveKey(from: connectionKeychainId)

        guard let data = Data(base64Encoded: encryptedQuery) else { return nil }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            debugLog("Decryption failed: \(error)")
            return nil
        }
    }

    private static func deriveKey(from connectionKeychainId: String) -> SymmetricKey {
        let keyMaterial = connectionKeychainId + appSalt
        let hash = SHA256.hash(data: Data(keyMaterial.utf8))
        return SymmetricKey(data: hash)
    }
}
