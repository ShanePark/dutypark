import Foundation
import Security

@MainActor
protocol AccountDeletionReceiptTokenStoring {
    /// Throws when secure storage is temporarily unavailable (for example,
    /// before the first device unlock). `nil` is reserved for a confirmed
    /// missing item so its metadata can be cleaned up safely.
    func loadToken() throws -> String?
    func saveToken(_ token: String) throws
    func clearToken()
}

nonisolated enum AccountDeletionReceiptStoreError: Error, Equatable, Sendable {
    case randomGenerationFailed
    case secureStorageFailed
    case receiptBelongsToAnotherAccount
}

nonisolated enum AccountDeletionReceiptTokenPolicy {
    static let encodedLength = 43

    static func isValid(_ token: String) -> Bool {
        guard token.utf8.count == encodedLength else { return false }
        return token.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x2D, 0x5F:
                true
            default:
                false
            }
        }
    }
}

/// Keeps the receipt token out of UserDefaults. The token is an opaque bearer
/// handle for the public status endpoint, so it receives the same device-only
/// protection as other short-lived credentials.
@MainActor
final class KeychainAccountDeletionReceiptTokenStore: AccountDeletionReceiptTokenStoring {
    private let service: String
    private let account: String

    init(
        service: String = Bundle.main.bundleIdentifier ?? "io.github.shanepark.dutypark",
        account: String = "account-deletion-receipt"
    ) {
        self.service = service
        self.account = account
    }

    func loadToken() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let token = String(data: data, encoding: .utf8)
        else {
            throw AccountDeletionReceiptStoreError.secureStorageFailed
        }
        return token
    }

    func saveToken(_ token: String) throws {
        guard AccountDeletionReceiptTokenPolicy.isValid(token) else {
            throw AccountDeletionReceiptStoreError.secureStorageFailed
        }
        let data = Data(token.utf8)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else {
            throw AccountDeletionReceiptStoreError.secureStorageFailed
        }
        var addQuery = baseQuery
        addQuery.merge(attributes) { _, new in new }
        guard SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess else {
            throw AccountDeletionReceiptStoreError.secureStorageFailed
        }
    }

    func clearToken() {
        _ = SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

/// The short-lived, opaque handle returned when account deletion is accepted.
/// It is intentionally kept separate from the authenticated session so the app
/// can ask for a terminal status after cookies and account-scoped caches are
/// removed.
@MainActor
final class AccountDeletionReceiptStore {
    static let shared = AccountDeletionReceiptStore()

    private static let key = "dp-account-deletion-receipt"
    private let defaults: UserDefaults
    private let tokenStore: any AccountDeletionReceiptTokenStoring

    init(
        defaults: UserDefaults = .standard,
        tokenStore: any AccountDeletionReceiptTokenStoring = KeychainAccountDeletionReceiptTokenStore()
    ) {
        self.defaults = defaults
        self.tokenStore = tokenStore
    }

    func load() -> AccountDeletionReceipt? {
        switch storedReceipt() {
        case .unavailable:
            // Preserve metadata when Keychain is temporarily unavailable. It
            // can become readable after the first device unlock.
            return nil
        case .missing:
            // Metadata without its token cannot be used to query status and
            // is safe to discard once Keychain confirmed the item is missing.
            defaults.removeObject(forKey: Self.key)
            return nil
        case .invalid:
            tokenStore.clearToken()
            defaults.removeObject(forKey: Self.key)
            return nil
        case .found(let receipt):
            return receipt
        }
    }

    func save(_ receipt: AccountDeletionReceipt) throws {
        guard receipt.ownerMemberID > 0,
              AccountDeletionReceiptTokenPolicy.isValid(receipt.receiptToken),
              !receipt.estimatedCompletionAt.isEmpty,
              let data = try? JSONEncoder().encode(PersistedMetadata(receipt: receipt))
        else { throw AccountDeletionReceiptStoreError.secureStorageFailed }

        switch storedReceipt() {
        case .unavailable:
            // Do not overwrite an existing receipt while Keychain access is
            // uncertain. This is especially important before first unlock.
            throw AccountDeletionReceiptStoreError.secureStorageFailed
        case .missing:
            defaults.removeObject(forKey: Self.key)
        case .invalid:
            tokenStore.clearToken()
            defaults.removeObject(forKey: Self.key)
        case .found(let existing):
            guard existing.ownerMemberID == receipt.ownerMemberID,
                  existing.receiptToken == receipt.receiptToken
            else {
                // Never replace an existing bearer handle—even when the
                // current account id happens to match—because the existing
                // request is the only status record we can still resolve.
                throw AccountDeletionReceiptStoreError.receiptBelongsToAnotherAccount
            }
        }

        try tokenStore.saveToken(receipt.receiptToken)
        defaults.set(data, forKey: Self.key)
    }

    /// Creates the token before the authenticated deletion request. Storing a
    /// five-minute provisional ETA also lets a process restart after the server
    /// accepted the request but before the response reached the app.
    func prepareReceiptToken(ownerMemberID: Int64, now: Date = .now) throws -> String {
        guard ownerMemberID > 0 else {
            throw AccountDeletionReceiptStoreError.secureStorageFailed
        }
        if let receipt = load() {
            guard receipt.ownerMemberID == ownerMemberID else {
                throw AccountDeletionReceiptStoreError.receiptBelongsToAnotherAccount
            }
            return receipt.receiptToken
        }

        let token = try Self.generateReceiptToken()
        let provisional = AccountDeletionReceipt(
            jobId: 0,
            status: "PENDING",
            ownerMemberID: ownerMemberID,
            receiptToken: token,
            estimatedCompletionAt: ISO8601DateFormatter().string(
                from: now.addingTimeInterval(5 * 60)
            )
        )
        try save(provisional)
        return token
    }

    func clear() {
        // Remove the bearer token first. If the process stops between these
        // operations, the next load observes a missing token and removes the
        // now-unusable metadata, so no orphaned secret is retained.
        tokenStore.clearToken()
        defaults.removeObject(forKey: Self.key)
    }

    private enum StoredReceipt {
        case found(AccountDeletionReceipt)
        case missing
        case invalid
        case unavailable
    }

    private func storedReceipt() -> StoredReceipt {
        let token: String?
        do {
            token = try tokenStore.loadToken()
        } catch {
            return .unavailable
        }

        guard let token, !token.isEmpty else { return .missing }
        guard AccountDeletionReceiptTokenPolicy.isValid(token) else { return .invalid }

        let metadata = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(PersistedMetadata.self, from: $0) }
            ?? PersistedMetadata.unknown
        return .found(AccountDeletionReceipt(
            jobId: 0,
            status: metadata.status,
            ownerMemberID: metadata.ownerMemberID ?? 0,
            receiptToken: token,
            estimatedCompletionAt: metadata.estimatedCompletionAt,
            receiptExpiresAt: metadata.receiptExpiresAt
        ))
    }

    private static func generateReceiptToken() throws -> String {
        var bytes = Data(repeating: 0, count: 32)
        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(
                kSecRandomDefault,
                buffer.count,
                buffer.baseAddress!
            )
        }
        guard status == errSecSuccess else {
            // SecRandomCopyBytes is backed by the system CSPRNG. Failing closed
            // avoids ever sending a predictable receipt handle.
            throw AccountDeletionReceiptStoreError.randomGenerationFailed
        }
        return bytes.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }

    private struct PersistedMetadata: Codable {
        let status: String
        let ownerMemberID: Int64?
        let estimatedCompletionAt: String
        let receiptExpiresAt: String?

        init(receipt: AccountDeletionReceipt) {
            self.status = receipt.status
            self.ownerMemberID = receipt.ownerMemberID
            self.estimatedCompletionAt = receipt.estimatedCompletionAt
            self.receiptExpiresAt = receipt.receiptExpiresAt
        }

        private init(
            status: String,
            ownerMemberID: Int64?,
            estimatedCompletionAt: String,
            receiptExpiresAt: String?
        ) {
            self.status = status
            self.ownerMemberID = ownerMemberID
            self.estimatedCompletionAt = estimatedCompletionAt
            self.receiptExpiresAt = receiptExpiresAt
        }

        static let unknown = PersistedMetadata(
            status: "PENDING",
            ownerMemberID: nil,
            estimatedCompletionAt: "",
            receiptExpiresAt: nil
        )
    }
}
