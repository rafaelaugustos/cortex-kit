import Foundation
import Security

/// A thin wrapper over the macOS keychain for generic password items, scoped to
/// a service string the caller provides.
///
/// The service is an instance property, so each app — and each kind of secret —
/// gets its own bucket:
///
/// ```swift
/// let store = Keychain(service: "db.cortex.connections")
/// store.set("hunter2", for: connectionID.uuidString)
/// let pw = store.get(connectionID.uuidString)
/// ```
///
/// Values are stored as UTF-8. Writing an empty string deletes the item (an
/// empty secret is treated as "no secret").
public struct Keychain: Sendable {
    public let service: String

    public init(service: String) {
        self.service = service
    }

    /// Stores `value` under `account`, replacing any existing item. An empty
    /// `value` removes the item instead.
    @discardableResult
    public func set(_ value: String, for account: String) -> Bool {
        delete(account)
        guard !value.isEmpty, let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    /// Reads the UTF-8 value stored under `account`, or `nil` if absent.
    public func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Removes the item under `account` (no-op if absent).
    public func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - UUID conveniences

    /// Convenience overloads keyed by `UUID` — a common case, where each saved
    /// record's secret is keyed by its id.
    @discardableResult
    public func set(_ value: String, for id: UUID) -> Bool { set(value, for: id.uuidString) }
    public func get(_ id: UUID) -> String? { get(id.uuidString) }
    public func delete(_ id: UUID) { delete(id.uuidString) }
}
