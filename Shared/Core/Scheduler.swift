import Foundation
import CryptoKit
import DeviceActivity
import FamilyControls

/// Registers DeviceActivity schedules so the monitor extension wakes up at the right moments,
/// even when Bloom is not running.
enum Scheduler {
    enum SchedulerError: LocalizedError {
        case tooManyActivities(Int)

        var errorDescription: String? {
            switch self {
            case .tooManyActivities(let n):
                return "iOS lets Bloom track up to \(BloomConfig.maxMonitoredActivities) schedules at once, and these rules need \(n). Try combining limits or using \"Every day\" for downtime."
            }
        }
    }

    private static var center: DeviceActivityCenter { DeviceActivityCenter() }

    private struct Planned {
        let schedule: DeviceActivitySchedule
        let events: [DeviceActivityEvent.Name: DeviceActivityEvent]
        let signature: String
    }

    /// Makes the monitored limit and downtime activities match `data`.
    static func sync(_ data: BloomData) throws {
        var planned: [String: Planned] = [:]

        for limit in data.limits where limit.isEnabled && !limit.selection.isEmpty {
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
                intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
                repeats: true)
            planned[limit.storeKey] = Planned(
                schedule: schedule,
                events: [DeviceActivityEvent.Name(BloomKeys.thresholdEvent): thresholdEvent(for: limit)],
                signature: signature(limit.selection, extra: "\(limit.minutesPerDay)"))
        }

        for downtime in data.downtimes where downtime.isEnabled && !downtime.weekdays.isEmpty {
            let sig = signature(downtime.selection, extra: "\(downtime.start)\(downtime.end)\(downtime.weekdays.sorted())")
            if downtime.runsEveryDay {
                let schedule = DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: downtime.start.hour, minute: downtime.start.minute),
                    intervalEnd: DateComponents(hour: downtime.end.hour, minute: downtime.end.minute),
                    repeats: true)
                planned[downtime.storeKey] = Planned(schedule: schedule, events: [:], signature: sig)
            } else {
                for weekday in downtime.weekdays {
                    let endWeekday = downtime.crossesMidnight ? weekday % 7 + 1 : weekday
                    let schedule = DeviceActivitySchedule(
                        intervalStart: DateComponents(hour: downtime.start.hour, minute: downtime.start.minute, weekday: weekday),
                        intervalEnd: DateComponents(hour: downtime.end.hour, minute: downtime.end.minute, weekday: endWeekday),
                        repeats: true)
                    planned["\(downtime.storeKey).\(weekday)"] = Planned(schedule: schedule, events: [:], signature: sig)
                }
            }
        }

        let ruleActivities = center.activities.filter {
            $0.rawValue.hasPrefix(BloomKeys.limitPrefix) || $0.rawValue.hasPrefix(BloomKeys.downtimePrefix)
        }
        let otherActivities = center.activities.count - ruleActivities.count
        if planned.count + otherActivities > BloomConfig.maxMonitoredActivities {
            throw SchedulerError.tooManyActivities(planned.count + otherActivities)
        }

        let stale = ruleActivities.filter { planned[$0.rawValue] == nil }
        if !stale.isEmpty { center.stopMonitoring(stale) }

        var signatures = SharedStore.activitySignatures.filter { planned[$0.key] != nil }
        let running = Set(ruleActivities.map(\.rawValue))
        for (name, plan) in planned where signatures[name] != plan.signature || !running.contains(name) {
            let activity = DeviceActivityName(name)
            center.stopMonitoring([activity])
            try center.startMonitoring(activity, during: plan.schedule, events: plan.events)
            signatures[name] = plan.signature
        }
        SharedStore.activitySignatures = signatures
    }

    /// Wakes the monitor extension at `date`.
    ///
    /// DeviceActivity intervals must be at least 15 minutes long, so for shorter waits the interval
    /// runs a little past `date` and its end warning is set to fire exactly at `date`.
    static func scheduleWakeUp(_ name: String, at date: Date) throws {
        let now = Date()
        let minimumEnd = now.addingTimeInterval(16 * 60)
        let end = max(date, minimumEnd)
        let lead = end.timeIntervalSince(date)
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(parts, from: now),
            intervalEnd: Calendar.current.dateComponents(parts, from: end),
            repeats: false,
            warningTime: lead >= 1 ? DateComponents(second: Int(lead.rounded())) : nil)
        let activity = DeviceActivityName(name)
        center.stopMonitoring([activity])
        try center.startMonitoring(activity, during: schedule)
    }

    static func cancel(_ names: [String]) {
        center.stopMonitoring(names.map { DeviceActivityName($0) })
    }

    static func stopEverything() {
        center.stopMonitoring()
        SharedStore.activitySignatures = [:]
    }

    // MARK: - Private

    private static func thresholdEvent(for limit: AppLimit) -> DeviceActivityEvent {
        let threshold = DateComponents(minute: limit.minutesPerDay)
        if #available(iOS 17.4, *) {
            // Count usage from earlier today too, so a limit created at 3pm still knows about the morning.
            return DeviceActivityEvent(
                applications: limit.selection.applicationTokens,
                categories: limit.selection.categoryTokens,
                webDomains: limit.selection.webDomainTokens,
                threshold: threshold,
                includesPastActivity: true)
        }
        return DeviceActivityEvent(
            applications: limit.selection.applicationTokens,
            categories: limit.selection.categoryTokens,
            webDomains: limit.selection.webDomainTokens,
            threshold: threshold)
    }

    private static func signature(_ selection: FamilyActivitySelection, extra: String) -> String {
        // Stable across launches (unlike hashValue), so unchanged rules are not restarted.
        let encoded = (try? JSONEncoder().encode(selection)) ?? Data()
        let digest = SHA256.hash(data: Data(extra.utf8) + encoded)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension FamilyActivitySelection {
    var isEmpty: Bool {
        applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty
    }

    var itemCount: Int {
        applicationTokens.count + categoryTokens.count + webDomainTokens.count
    }
}
