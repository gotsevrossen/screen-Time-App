import Charts
import FamilyControls
import SwiftUI

struct DashboardReportView: View {
    let model: DashboardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            summary
            chart
            Rectangle().fill(Color.bloomHairline).frame(height: 1)
            topApps
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.isHourly ? "Screen time today" : "Daily average")
                    .font(.bloomBody(.subheadline))
                    .foregroundStyle(Color.bloomInkSecondary)
                Text(DurationText.interval(headlineDuration))
                    .font(.bloomDisplay(44))
                    .foregroundStyle(Color.bloomInk)
                    .contentTransition(.numericText())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Pickups")
                    .font(.bloomBody(.subheadline))
                    .foregroundStyle(Color.bloomInkSecondary)
                Text("\(model.pickups)")
                    .font(.bloomHeading(24))
                    .foregroundStyle(Color.bloomInk)
            }
        }
    }

    private var headlineDuration: TimeInterval {
        guard !model.isHourly else { return model.total }
        let days = max(1, model.buckets.filter { $0.duration > 0 }.count)
        return model.total / Double(days)
    }

    private var chart: some View {
        Chart(model.buckets) { bucket in
            BarMark(
                x: .value("Time", bucket.start, unit: model.isHourly ? .hour : .day),
                y: .value("Minutes", bucket.duration / 60))
            .foregroundStyle(Color.bloomLavender)
            .cornerRadius(4)
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine().foregroundStyle(Color.bloomHairline)
                AxisValueLabel {
                    if let minutes = value.as(Double.self) { Text("\(Int(minutes))m") }
                }
            }
        }
        .chartXAxis {
            if model.isHourly {
                AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                    AxisValueLabel(format: .dateTime.hour())
                }
            } else {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
        }
        .frame(height: 150)
        .accessibilityLabel("Screen time chart")
    }

    @ViewBuilder
    private var topApps: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Most used")
                .font(.bloomHeading(18))
                .foregroundStyle(Color.bloomInk)

            if model.topApps.isEmpty {
                Text("Nothing yet. Usage shows up here as you use your phone.")
                    .font(.bloomBody(.subheadline))
                    .foregroundStyle(Color.bloomInkSecondary)
            }

            let longest = model.topApps.first?.duration ?? 1
            ForEach(model.topApps) { app in
                HStack(spacing: 12) {
                    Group {
                        if let token = app.token {
                            Label(token).labelStyle(.iconOnly)
                        } else {
                            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.bloomLavender)
                        }
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(app.name)
                                .font(.bloomBody(.subheadline).weight(.medium))
                                .foregroundStyle(Color.bloomInk)
                                .lineLimit(1)
                            Spacer()
                            Text(DurationText.interval(app.duration))
                                .font(.bloomBody(.subheadline).monospacedDigit())
                                .foregroundStyle(Color.bloomInkSecondary)
                        }
                        GeometryReader { proxy in
                            Capsule()
                                .fill(Color.bloomLavender)
                                .frame(width: max(6, proxy.size.width * app.duration / longest))
                        }
                        .frame(height: 6)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
