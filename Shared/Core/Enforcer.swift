import Foundation
import FamilyControls
import ManagedSettings

/// Turns `BloomData` into actual restrictions. Every call recomputes everything from scratch,
/// so it is safe to call from the app and from any extension callback, as often as needed.
enum Enforcer {
    static func reconcile(now: Date = Date()) {
        let data = SharedStore.update { data in
            data.unlockGrants = data.unlockGrants.filter { $0.value > now }
            let today = now.bloomDayKey
            data.limitsReached = data.limitsReached.filter { $0.value == today }
            if case .locked = data.web.phase(at: now) {
                data.web.unlockStartsAt = nil
                data.web.unlockEndsAt = nil
            }
        }

        let today = now.bloomDayKey
        for limit in data.limits {
            let blocked = limit.isEnabled
                && data.limitsReached[limit.storeKey] == today
                && data.unlockGrants[limit.storeKey] == nil
            apply(blocked ? limit.selection : nil, toStore: limit.storeKey)
        }

        for downtime in data.downtimes {
            let blocked = downtime.isActive(at: now) && data.unlockGrants[downtime.storeKey] == nil
            apply(blocked ? downtime.selection : nil, toStore: downtime.storeKey)
        }

        applyWebFilter(data.web, now: now)
    }

    /// Removes every restriction a rule owns. Call when a rule is deleted.
    static func clear(storeKey: String) {
        store(storeKey).clearAllSettings()
    }

    static func activeBlocks(in data: BloomData, now: Date = Date()) -> [ActiveBlock] {
        var blocks: [ActiveBlock] = []
        let today = now.bloomDayKey
        for limit in data.limits where limit.isEnabled && data.limitsReached[limit.storeKey] == today {
            blocks.append(ActiveBlock(
                storeKey: limit.storeKey, kind: .limit, name: limit.name,
                detail: "Daily limit of \(DurationText.minutes(limit.clampedMinutes)) reached",
                selection: limit.selection, unlockedUntil: data.unlockGrants[limit.storeKey]))
        }
        for downtime in data.downtimes where downtime.isActive(at: now) {
            blocks.append(ActiveBlock(
                storeKey: downtime.storeKey, kind: .downtime, name: downtime.name,
                detail: "Downtime until \(downtime.end.formatted)",
                selection: downtime.selection, unlockedUntil: data.unlockGrants[downtime.storeKey]))
        }
        return blocks
    }

    // MARK: - Private

    private static func store(_ key: String) -> ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(key))
    }

    private static func apply(_ selection: FamilyActivitySelection?, toStore key: String) {
        let store = store(key)
        guard let selection else {
            store.clearAllSettings()
            return
        }
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        let domains = selection.webDomainTokens
        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomains = domains.isEmpty ? nil : domains
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
    }

    private static func applyWebFilter(_ web: WebFilterState, now: Date) {
        let store = store(BloomKeys.webStore)
        if case .unlocked = web.phase(at: now) {
            store.webContent.blockedByFilter = nil
            return
        }
        let blocked = Set(web.customBlockedDomains.map { WebDomain(domain: $0) })
        store.webContent.blockedByFilter = .auto(blocked)
    }
}

enum DurationText {
    static func minutes(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "\(m) min"
        case (_, 0): return "\(h) hr"
        default: return "\(h) hr \(m) min"
        }
    }

    static func interval(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600, m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    static func countdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
