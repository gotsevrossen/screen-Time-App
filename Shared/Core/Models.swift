import Foundation
import FamilyControls

struct TimeOfDay: Codable, Hashable, Comparable {
    var hour: Int
    var minute: Int

    var minutesSinceMidnight: Int { hour * 60 + minute }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init(date: Date) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        self.init(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }

    /// Today's date at this time, for DatePicker bindings.
    var date: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    var formatted: String { date.formatted(date: .omitted, time: .shortened) }
}

/// A daily time budget for a set of apps, categories and websites.
struct AppLimit: Codable, Identifiable {
    var id = UUID()
    var name: String
    var selection = FamilyActivitySelection()
    var minutesPerDay: Int = 30
    var isEnabled = true

    var storeKey: String { BloomKeys.limitPrefix + id.uuidString }
}

/// A recurring window when a set of apps is blocked.
struct DowntimeSchedule: Codable, Identifiable {
    var id = UUID()
    var name: String
    var selection = FamilyActivitySelection()
    var start = TimeOfDay(hour: 22, minute: 0)
    var end = TimeOfDay(hour: 7, minute: 0)
    /// Calendar weekdays, 1 = Sunday ... 7 = Saturday.
    var weekdays: Set<Int> = Set(1...7)
    var isEnabled = true

    var storeKey: String { BloomKeys.downtimePrefix + id.uuidString }
    var crossesMidnight: Bool { end <= start }
    var runsEveryDay: Bool { weekdays.count == 7 }

    func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled, !weekdays.isEmpty else { return false }
        let now = TimeOfDay(date: date).minutesSinceMidnight
        let today = calendar.component(.weekday, from: date)
        let yesterday = today == 1 ? 7 : today - 1
        if crossesMidnight {
            return (weekdays.contains(today) && now >= start.minutesSinceMidnight)
                || (weekdays.contains(yesterday) && now < end.minutesSinceMidnight)
        }
        return weekdays.contains(today)
            && now >= start.minutesSinceMidnight
            && now < end.minutesSinceMidnight
    }

    var weekdaySummary: String {
        if runsEveryDay { return "Every day" }
        if weekdays == Set(2...6) { return "Weekdays" }
        if weekdays == [1, 7] { return "Weekends" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return weekdays.sorted().map { symbols[$0 - 1] }.joined(separator: ", ")
    }
}

/// The adult content filter is always on. Unlocking takes the PIN, then a countdown,
/// then it is off for a short, fixed window and turns itself back on.
struct WebFilterState: Codable {
    var customBlockedDomains: [String] = []
    var unlockStartsAt: Date?
    var unlockEndsAt: Date?

    enum Phase: Equatable {
        case locked
        case countingDown(until: Date)
        case unlocked(until: Date)
    }

    func phase(at now: Date) -> Phase {
        guard let start = unlockStartsAt, let end = unlockEndsAt, now < end else { return .locked }
        return now < start ? .countingDown(until: start) : .unlocked(until: end)
    }

    var unlockMinutes: Int? {
        guard let start = unlockStartsAt, let end = unlockEndsAt else { return nil }
        return Int((end.timeIntervalSince(start) / 60).rounded())
    }
}

/// Everything Bloom persists, shared between the app and its extensions through the App Group.
struct BloomData: Codable {
    var limits: [AppLimit] = []
    var downtimes: [DowntimeSchedule] = []
    var web = WebFilterState()
    /// storeKey -> day key of the day the limit was reached.
    var limitsReached: [String: String] = [:]
    /// storeKey -> time a PIN unlock expires.
    var unlockGrants: [String: Date] = [:]
    /// Set by the shield's "Unlock with PIN" button so the app opens straight to unlocking.
    var pendingUnlockRequestAt: Date?

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        limits = try c.decodeIfPresent([AppLimit].self, forKey: .limits) ?? []
        downtimes = try c.decodeIfPresent([DowntimeSchedule].self, forKey: .downtimes) ?? []
        web = try c.decodeIfPresent(WebFilterState.self, forKey: .web) ?? WebFilterState()
        limitsReached = try c.decodeIfPresent([String: String].self, forKey: .limitsReached) ?? [:]
        unlockGrants = try c.decodeIfPresent([String: Date].self, forKey: .unlockGrants) ?? [:]
        pendingUnlockRequestAt = try c.decodeIfPresent(Date.self, forKey: .pendingUnlockRequestAt)
    }

    func limit(forStoreKey key: String) -> AppLimit? { limits.first { $0.storeKey == key } }
    func downtime(forStoreKey key: String) -> DowntimeSchedule? { downtimes.first { $0.storeKey == key } }
}

/// A rule that is blocking apps right now (or would be, if it were not unlocked).
struct ActiveBlock: Identifiable {
    enum Kind { case limit, downtime }

    let storeKey: String
    let kind: Kind
    let name: String
    let detail: String
    let selection: FamilyActivitySelection
    let unlockedUntil: Date?

    var id: String { storeKey }
}
