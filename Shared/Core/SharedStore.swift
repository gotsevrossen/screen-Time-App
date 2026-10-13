import Foundation

/// Reads and writes `BloomData` in the App Group so the app and extensions see the same state.
enum SharedStore {
    private static let key = "bloom.data.v1"
    private static let signaturesKey = "bloom.activitySignatures.v1"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: BloomConfig.appGroup) ?? .standard
    }

    static func load() -> BloomData {
        guard let raw = defaults.data(forKey: key),
              let data = try? JSONDecoder().decode(BloomData.self, from: raw) else { return BloomData() }
        return data
    }

    static func save(_ data: BloomData) {
        guard let raw = try? JSONEncoder().encode(data) else { return }
        defaults.set(raw, forKey: key)
    }

    /// Load, mutate and save in one step. Always re-reads first so extension writes are not lost.
    @discardableResult
    static func update(_ body: (inout BloomData) -> Void) -> BloomData {
        var data = load()
        body(&data)
        save(data)
        return data
    }

    /// Fingerprints of what each monitored activity was started with, so unchanged ones are not restarted.
    static var activitySignatures: [String: String] {
        get { defaults.dictionary(forKey: signaturesKey) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: signaturesKey) }
    }
}
