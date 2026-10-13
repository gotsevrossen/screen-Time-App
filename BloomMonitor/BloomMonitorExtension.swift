import DeviceActivity
import Foundation
import UserNotifications

/// iOS wakes this extension at schedule boundaries and when usage thresholds are hit.
/// It never trusts the callback alone: it records what happened, then recomputes every rule.
final class BloomMonitorExtension: DeviceActivityMonitor {
    /// Callbacks can arrive a few seconds early; nudging "now" forward keeps edges from being missed.
    private var now: Date { Date().addingTimeInterval(45) }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        Enforcer.reconcile(now: now)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        handleWakeUp(activity)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        handleWakeUp(activity)
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        let key = activity.rawValue
        guard key.hasPrefix(BloomKeys.limitPrefix) else { return }

        let reachedAt = Date()
        let data = SharedStore.update { $0.limitsReached[key] = reachedAt.bloomDayKey }
        Enforcer.reconcile(now: reachedAt)

        if let limit = data.limit(forStoreKey: key) {
            notify(title: "Time's up for \(limit.name)",
                   body: "You've used your \(DurationText.minutes(limit.clampedMinutes)) for today. See you tomorrow.")
        }
    }

    // MARK: - Private

    private func handleWakeUp(_ activity: DeviceActivityName) {
        Enforcer.reconcile(now: now)
        let phase = SharedStore.load().web.phase(at: now)

        // Both the end warning and the interval end can fire for one wake-up, so these
        // notifications share an identifier and the second simply replaces the first.
        switch (activity.rawValue, phase) {
        case (BloomKeys.webCountdownActivity, .unlocked(let until)):
            let minutes = max(1, Int((until.timeIntervalSinceNow / 60).rounded()))
            notify(title: "Adult filter is off", body: "It turns back on by itself in \(minutes) min.", id: "bloom.web")
        case (BloomKeys.webRelockActivity, .locked):
            notify(title: "Adult filter is back on", body: "Your web protection is active again.", id: "bloom.web")
        default:
            break
        }
    }

    private func notify(title: String, body: String, id: String = UUID().uuidString) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
