import DeviceActivity
import SwiftUI

@main
struct BloomReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        DashboardReport { model in
            DashboardReportView(model: model)
        }
    }
}
