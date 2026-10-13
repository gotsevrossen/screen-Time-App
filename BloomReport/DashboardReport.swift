import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

struct DashboardModel {
    struct Bucket: Identifiable {
        let start: Date
        let duration: TimeInterval
        var id: Date { start }
    }

    struct AppUsage: Identifiable {
        let id: String
        let name: String
        let token: ApplicationToken?
        let duration: TimeInterval
        let pickups: Int
    }

    var total: TimeInterval = 0
    var pickups = 0
    var buckets: [Bucket] = []
    var topApps: [AppUsage] = []
    /// True when the buckets are hours of one day, false when they are days of a week.
    var isHourly = true
}

/// Apple only hands usage data to this extension, never to the app itself, so all the
/// aggregation happens here.
struct DashboardReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .dashboard
    let content: (DashboardModel) -> DashboardReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> DashboardModel {
        var model = DashboardModel()
        var bucketTotals: [Date: TimeInterval] = [:]
        var apps: [String: DashboardModel.AppUsage] = [:]
        var shortestSegment = TimeInterval.infinity

        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                shortestSegment = min(shortestSegment, segment.dateInterval.duration)
                bucketTotals[segment.dateInterval.start, default: 0] += segment.totalActivityDuration
                model.total += segment.totalActivityDuration

                for await category in segment.categories {
                    for await activity in category.applications {
                        let app = activity.application
                        let key = app.bundleIdentifier ?? app.localizedDisplayName ?? UUID().uuidString
                        let existing = apps[key]
                        apps[key] = .init(
                            id: key,
                            name: app.localizedDisplayName ?? "App",
                            token: app.token,
                            duration: (existing?.duration ?? 0) + activity.totalActivityDuration,
                            pickups: (existing?.pickups ?? 0) + activity.numberOfPickups)
                        model.pickups += activity.numberOfPickups
                    }
                }
            }
        }

        model.isHourly = shortestSegment <= 3600
        model.buckets = bucketTotals
            .map { DashboardModel.Bucket(start: $0.key, duration: $0.value) }
            .sorted { $0.start < $1.start }
        model.topApps = apps.values
            .filter { $0.duration >= 60 }
            .sorted { $0.duration > $1.duration }
            .prefix(8)
            .map { $0 }
        return model
    }
}
