import CryptoKit
import Foundation
import Security

/// Stores a salted hash of the 4-digit PIN in the Keychain and slows down guessing.
final class PINManager {
    static let shared = PINManager()
    static let length = 4

    enum VerifyResult: Equatable {
        case success
        case wrong(attemptsLeft: Int)
        case lockedOut(until: Date)
    }

    private let service = "bloom.pin"
    private let account = "owner"
    private let freeAttempts = 5
    private let attemptsKey = "bloom.pin.failedAttempts"
    private let lockoutKey = "bloom.pin.lockedUntil"
    private let defaults = UserDefaults.standard

    var hasPIN: Bool { readItem() != nil }

    var lockedUntil: Date? {
        guard let date = defaults.object(forKey: lockoutKey) as? Date, date > Date() else { return nil }
        return date
    }

    @discardableResult
    func setPIN(_ pin: String) -> Bool {
        guard pin.count == Self.length, pin.allSatisfy(\.isNumber) else { return false }
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard status == errSecSuccess else { return false }
        let stored = salt + hash(pin, salt: salt)
        deleteItem()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: stored,
        ]
        resetAttempts()
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    func verify(_ pin: String) -> VerifyResult {
        if let until = lockedUntil { return .lockedOut(until: until) }
        guard let stored = readItem(), stored.count > 16 else { return .wrong(attemptsLeft: 0) }
        let salt = stored.prefix(16)
        if hash(pin, salt: Data(salt)) == stored.dropFirst(16) {
            resetAttempts()
            return .success
        }

        let failed = defaults.integer(forKey: attemptsKey) + 1
        defaults.set(failed, forKey: attemptsKey)
        if failed >= freeAttempts {
            // 1 min, 2 min, 4 min ... capped at 1 hour.
            let minutes = min(60, 1 << min(6, failed - freeAttempts))
            let until = Date().addingTimeInterval(TimeInterval(minutes * 60))
            defaults.set(until, forKey: lockoutKey)
            return .lockedOut(until: until)
        }
        return .wrong(attemptsLeft: freeAttempts - failed)
    }

    func removePIN() {
        deleteItem()
        resetAttempts()
    }

    // MARK: - Private

    private func hash(_ pin: String, salt: Data) -> Data {
        Data(SHA256.hash(data: salt + Data(pin.utf8)))
    }

    private func resetAttempts() {
        defaults.removeObject(forKey: attemptsKey)
        defaults.removeObject(forKey: lockoutKey)
    }

    private func readItem() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private func deleteItem() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
