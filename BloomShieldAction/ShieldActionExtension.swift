import ManagedSettings
import UserNotifications

/// Handles the two buttons on the block screen.
///
/// Extensions cannot open the app directly, so "Unlock with PIN" sends a notification that
/// opens Bloom on its unlock screen. The PIN is never entered on the shield itself.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    private func respond(to action: ShieldAction, _ completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)
        case .secondaryButtonPressed:
            SharedStore.update { $0.pendingUnlockRequestAt = Date() }
            let content = UNMutableNotificationContent()
            content.title = "Unlock in Bloom"
            content.body = "Tap here, then enter your PIN to get more time."
            content.userInfo = ["bloom.action": "unlock"]
            let request = UNNotificationRequest(identifier: "bloom.unlock-request", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { _ in
                completionHandler(.defer)
            }
        @unknown default:
            completionHandler(.close)
        }
    }
}
