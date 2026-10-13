import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen shown in place of a blocked app or website.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(name: application.localizedDisplayName, reason: reason(app: application.token, category: nil, web: nil))
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: application.localizedDisplayName, reason: reason(app: application.token, category: category.token, web: nil))
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(name: webDomain.domain, reason: reason(app: nil, category: nil, web: webDomain.token))
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: webDomain.domain, reason: reason(app: nil, category: category.token, web: webDomain.token))
    }

    // MARK: - Private

    private enum Reason {
        case limit(minutes: Int)
        case downtime(until: String)
        case unknown
    }

    private func make(name: String?, reason: Reason) -> ShieldConfiguration {
        let subject = name ?? "This app"
        let title: String
        let subtitle: String
        switch reason {
        case .limit(let minutes):
            title = "\(subject) is resting"
            subtitle = "You've used today's \(DurationText.minutes(minutes)). Take a breath, it'll be here tomorrow."
        case .downtime(let until):
            title = "Downtime"
            subtitle = "\(subject) is paused until \(until). Time for something that helps you grow."
        case .unknown:
            title = "\(subject) is paused"
            subtitle = "Bloom is keeping this off for now."
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: BloomPalette.lavender.withAlphaComponent(0.92),
            icon: UIImage(named: "BloomMark"),
            title: .init(text: title, color: BloomPalette.onAccent),
            subtitle: .init(text: subtitle, color: BloomPalette.onAccent.withAlphaComponent(0.75)),
            primaryButtonLabel: .init(text: "Close", color: .white),
            primaryButtonBackgroundColor: BloomPalette.onAccent,
            secondaryButtonLabel: .init(text: "Unlock with PIN", color: BloomPalette.onAccent))
    }

    private func reason(app: ApplicationToken?, category: ActivityCategoryToken?, web: WebDomainToken?) -> Reason {
        let data = SharedStore.load()
        let now = Date()
        for block in Enforcer.activeBlocks(in: data, now: now) where block.unlockedUntil == nil {
            let s = block.selection
            let matches = (app.map { s.applicationTokens.contains($0) } ?? false)
                || (category.map { s.categoryTokens.contains($0) } ?? false)
                || (web.map { s.webDomainTokens.contains($0) } ?? false)
            guard matches else { continue }
            switch block.kind {
            case .limit:
                if let limit = data.limit(forStoreKey: block.storeKey) { return .limit(minutes: limit.minutesPerDay) }
            case .downtime:
                if let downtime = data.downtime(forStoreKey: block.storeKey) { return .downtime(until: downtime.end.formatted) }
            }
        }
        return .unknown
    }
}
