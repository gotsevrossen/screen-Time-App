import Combine
import FamilyControls
import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var data = SharedStore.load()
    @Published private(set) var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @Published var hasOnboarded: Bool {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: "bloom.hasOnboarded") }
    }
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        hasOnboarded = UserDefaults.standard.bool(forKey: "bloom.hasOnboarded")
        AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.authorizationStatus = $0 }
            .store(in: &cancellables)
    }

    var isAuthorized: Bool { authorizationStatus == .approved }

    var activeBlocks: [ActiveBlock] { Enforcer.activeBlocks(in: data) }

    // MARK: - Lifecycle

    /// Re-reads shared state (extensions may have changed it) and re-applies every rule.
    func refresh() {
        Enforcer.reconcile()
        data = SharedStore.load()
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            errorMessage = "Bloom needs Screen Time access to set limits. You can allow it in Settings > Screen Time."
        }
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func requestNotifications() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    func completeOnboarding() {
        hasOnboarded = true
        apply()
    }

    // MARK: - Limits

    func save(_ limit: AppLimit) {
        var limit = limit
        limit.minutesPerDay = limit.clampedMinutes
        mutate { data in
            if let index = data.limits.firstIndex(where: { $0.id == limit.id }) {
                data.limits[index] = limit
                // The limit changed, so let the monitor re-check today's usage against the new budget.
                data.limitsReached[limit.storeKey] = nil
            } else {
                data.limits.append(limit)
            }
        }
    }

    func deleteLimit(_ limit: AppLimit) {
        mutate { data in
            data.limits.removeAll { $0.id == limit.id }
            data.limitsReached[limit.storeKey] = nil
            data.unlockGrants[limit.storeKey] = nil
        }
        Enforcer.clear(storeKey: limit.storeKey)
    }

    // MARK: - Downtime

    func save(_ downtime: DowntimeSchedule) {
        mutate { data in
            if let index = data.downtimes.firstIndex(where: { $0.id == downtime.id }) {
                data.downtimes[index] = downtime
            } else {
                data.downtimes.append(downtime)
            }
        }
    }

    func deleteDowntime(_ downtime: DowntimeSchedule) {
        mutate { data in
            data.downtimes.removeAll { $0.id == downtime.id }
            data.unlockGrants[downtime.storeKey] = nil
        }
        Enforcer.clear(storeKey: downtime.storeKey)
    }

    // MARK: - Unlocking rules

    /// Lifts one rule for `minutes`. Callers must have checked the PIN first.
    func unlock(_ block: ActiveBlock, minutes: Int) {
        let until = Date().addingTimeInterval(TimeInterval(minutes * 60))
        do {
            try Scheduler.scheduleWakeUp(BloomKeys.unlockPrefix + block.storeKey, at: until)
        } catch {
            errorMessage = "Couldn't schedule the unlock to end, so it wasn't started. \(error.localizedDescription)"
            return
        }
        mutate(sync: false) { $0.unlockGrants[block.storeKey] = until }
    }

    func relock(_ block: ActiveBlock) {
        Scheduler.cancel([BloomKeys.unlockPrefix + block.storeKey])
        mutate(sync: false) { $0.unlockGrants[block.storeKey] = nil }
    }

    // MARK: - Web filter

    var webPhase: WebFilterState.Phase { data.web.phase(at: Date()) }

    /// Starts the countdown to a temporary unlock. Callers must have checked the PIN first.
    func startWebUnlock(minutes: Int) {
        guard BloomConfig.webUnlockDurations.contains(minutes) else { return }
        let start = Date().addingTimeInterval(TimeInterval(BloomConfig.webUnlockCountdownMinutes * 60))
        let end = start.addingTimeInterval(TimeInterval(minutes * 60))
        do {
            try Scheduler.scheduleWakeUp(BloomKeys.webCountdownActivity, at: start)
            try Scheduler.scheduleWakeUp(BloomKeys.webRelockActivity, at: end)
        } catch {
            Scheduler.cancel([BloomKeys.webCountdownActivity, BloomKeys.webRelockActivity])
            errorMessage = "Couldn't start the timer. \(error.localizedDescription)"
            return
        }
        mutate(sync: false) { data in
            data.web.unlockStartsAt = start
            data.web.unlockEndsAt = end
        }
    }

    /// Cancels a countdown, or ends an unlock early. Making things stricter never needs the PIN.
    func lockWebNow() {
        Scheduler.cancel([BloomKeys.webCountdownActivity, BloomKeys.webRelockActivity])
        mutate(sync: false) { data in
            data.web.unlockStartsAt = nil
            data.web.unlockEndsAt = nil
        }
    }

    @discardableResult
    func addBlockedDomain(_ input: String) -> Bool {
        guard let domain = Self.normalizedDomain(input) else { return false }
        guard !data.web.customBlockedDomains.contains(domain) else { return true }
        mutate(sync: false) { $0.web.customBlockedDomains.append(domain) }
        return true
    }

    func removeBlockedDomain(_ domain: String) {
        mutate(sync: false) { $0.web.customBlockedDomains.removeAll { $0 == domain } }
    }

    static func normalizedDomain(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let url = URL(string: text.contains("://") ? text : "https://\(text)"), let host = url.host {
            text = host
        }
        if text.hasPrefix("www.") { text.removeFirst(4) }
        let valid = text.contains(".") && !text.hasPrefix(".") && !text.hasSuffix(".")
            && text.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" }
        return valid ? text : nil
    }

    // MARK: - Settings

    /// Removes every limit and downtime. The adult filter stays on.
    func resetRules() {
        let keys = data.limits.map(\.storeKey) + data.downtimes.map(\.storeKey)
        Scheduler.stopEverything()
        keys.forEach { Enforcer.clear(storeKey: $0) }
        mutate { data in
            let web = data.web
            data = BloomData()
            data.web = web
        }
        // stopEverything also cancelled any pending web timers, so end any unlock in progress.
        lockWebNow()
    }

    // MARK: - Private

    private func mutate(sync: Bool = true, _ body: (inout BloomData) -> Void) {
        SharedStore.update(body)
        if sync {
            do {
                try Scheduler.sync(SharedStore.load())
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        apply()
    }

    private func apply() {
        Enforcer.reconcile()
        data = SharedStore.load()
    }
}
