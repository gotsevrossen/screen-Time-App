import Foundation

/// Values shared by the app and every extension.
enum BloomConfig {
    /// Read from Info.plist so the App Group only has to be set once, in project.yml.
    static let appGroup: String = {
        (Bundle.main.object(forInfoDictionaryKey: "BloomAppGroup") as? String) ?? "group.com.gotsevrossen.bloom"
    }()

    /// The adult filter countdown before an unlock starts.
    static let webUnlockCountdownMinutes = 10
    /// The only durations the adult filter may be unlocked for.
    static let webUnlockDurations = [5, 10, 15, 30]
    /// Durations offered when unlocking an app limit or downtime with the PIN.
    static let ruleUnlockDurations = [15, 30, 60]
    /// Apple caps each app at 20 monitored activities.
    static let maxMonitoredActivities = 20
}

/// Names used for ManagedSettings stores and DeviceActivity activities.
enum BloomKeys {
    static let webStore = "web"
    static let webCountdownActivity = "web.countdown"
    static let webRelockActivity = "web.relock"
    static let limitPrefix = "limit."
    static let downtimePrefix = "downtime."
    static let unlockPrefix = "unlock."
    static let thresholdEvent = "threshold"

    /// "downtime.<uuid>.3" -> "downtime.<uuid>"
    static func storeKey(forActivity name: String) -> String? {
        if name.hasPrefix(limitPrefix) { return name }
        if name.hasPrefix(downtimePrefix) {
            let parts = name.split(separator: ".")
            return parts.count >= 2 ? "\(parts[0]).\(parts[1])" : name
        }
        if name.hasPrefix(unlockPrefix) { return String(name.dropFirst(unlockPrefix.count)) }
        return nil
    }
}

extension Date {
    /// "2026-10-13" in the user's calendar, used to know whether a limit was reached today.
    var bloomDayKey: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: self)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
