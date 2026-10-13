import DeviceActivity
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    @State private var range = Range.today

    enum Range: String, CaseIterable { case today = "Today", week = "Week" }

    var body: some View {
        BloomPage(title: "Today", subtitle: Date().formatted(.dateTime.weekday(.wide).month().day())) {
            if !model.isAuthorized {
                AccessBanner()
            }

            statusCard

            if !model.activeBlocks.isEmpty {
                SectionLabel(text: "Blocked right now")
                ForEach(model.activeBlocks) { block in
                    ActiveBlockRow(block: block)
                }
            }

            SectionLabel(text: "Screen time")
            BloomCard {
                Picker("Range", selection: $range) {
                    ForEach(Range.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)

                DeviceActivityReport(.dashboard, filter: filter)
                    .frame(height: 560)
            }
        }
    }

    private var statusCard: some View {
        let limits = model.data.limits.filter(\.isEnabled).count
        let downtimes = model.data.downtimes.filter(\.isEnabled).count
        return BloomCard(style: .lavender, showsArrow: true) {
            Text("BLOOMING")
                .font(.bloomDisplay(40))
                .tracking(-1)
                .foregroundStyle(.white)
            HStack(spacing: 0) {
                Stat(value: "\(limits)", label: limits == 1 ? "limit" : "limits")
                Divider().frame(height: 36).overlay(Color.bloomOnAccent.opacity(0.25))
                Stat(value: "\(downtimes)", label: "downtime")
                Divider().frame(height: 36).overlay(Color.bloomOnAccent.opacity(0.25))
                Stat(value: webStatus, label: "adult filter")
            }
        }
    }

    private var webStatus: String {
        if case .unlocked = model.webPhase { return "Off" }
        return "On"
    }

    private var filter: DeviceActivityFilter {
        let calendar = Calendar.current
        switch range {
        case .today:
            let interval = calendar.dateInterval(of: .day, for: Date()) ?? DateInterval(start: Date(), duration: 86_400)
            return DeviceActivityFilter(segment: .hourly(during: interval))
        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) ?? DateInterval(start: Date(), duration: 7 * 86_400)
            return DeviceActivityFilter(segment: .daily(during: interval))
        }
    }
}

private struct Stat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.bloomHeading(26))
            Text(label).font(.bloomBody(.caption)).opacity(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
        .accessibilityElement(children: .combine)
    }
}

struct ActiveBlockRow: View {
    @EnvironmentObject private var model: AppModel
    let block: ActiveBlock
    @State private var unlocking = false

    var body: some View {
        BloomCard(style: block.unlockedUntil == nil ? .cream : .surface) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.name).font(.bloomHeading(20))
                    Text(detail).font(.bloomBody(.subheadline)).opacity(0.75)
                }
                Spacer()
                SelectionIcons(selection: block.selection, maxIcons: 3)
            }
            if block.unlockedUntil == nil {
                Button("Unlock with PIN") { unlocking = true }
                    .buttonStyle(.bloomDark)
            } else {
                Button("Block again now") { model.relock(block) }
                    .buttonStyle(.bloomSecondary)
            }
        }
        .sheet(isPresented: $unlocking) {
            RuleUnlockFlow(block: block)
        }
    }

    private var detail: String {
        if let until = block.unlockedUntil {
            return "Unlocked until \(until.formatted(date: .omitted, time: .shortened))"
        }
        return block.detail
    }
}

private struct AccessBanner: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        BloomCard(style: .cream) {
            Text("Screen Time access is off").font(.bloomHeading(20))
            Text("Bloom can't block anything until you allow access again.")
                .font(.bloomBody(.subheadline))
            Button("Allow access") { Task { await model.requestAuthorization() } }
                .buttonStyle(.bloomDark)
        }
    }
}
