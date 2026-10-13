import SwiftUI

/// PIN, then pick how long, for an app limit or downtime that is blocking right now.
struct RuleUnlockFlow: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let block: ActiveBlock
    @State private var verified = false
    @State private var minutes = BloomConfig.ruleUnlockDurations[0]

    var body: some View {
        if !verified {
            PINPadView(mode: .verify, message: "Unlock \(block.name)", onComplete: {
                withAnimation { verified = true }
            }, onCancel: { dismiss() })
        } else {
            DurationChooser(
                eyebrow: block.name,
                title: "How much more time?",
                message: "\(block.name) blocks again by itself when this runs out.",
                options: BloomConfig.ruleUnlockDurations,
                selection: $minutes,
                confirmTitle: "Unlock for \(DurationText.minutes(minutes))",
                onConfirm: {
                    model.unlock(block, minutes: minutes)
                    dismiss()
                },
                onCancel: { dismiss() })
        }
    }
}

/// PIN, then pick 5 to 30 minutes, then a 10 minute countdown before the adult filter turns off.
struct WebUnlockFlow: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var verified = false
    @State private var minutes = BloomConfig.webUnlockDurations[0]

    var body: some View {
        if !verified {
            PINPadView(mode: .verify, message: "Enter your PIN to start the unlock timer.", onComplete: {
                withAnimation { verified = true }
            }, onCancel: { dismiss() })
        } else {
            DurationChooser(
                eyebrow: "Adult filter",
                title: "Unlock for how long?",
                message: "The filter stays on for a \(BloomConfig.webUnlockCountdownMinutes) minute countdown first. You can cancel any time, and it turns back on by itself afterwards.",
                options: BloomConfig.webUnlockDurations,
                selection: $minutes,
                confirmTitle: "Start \(BloomConfig.webUnlockCountdownMinutes) minute timer",
                onConfirm: {
                    model.startWebUnlock(minutes: minutes)
                    dismiss()
                },
                onCancel: { dismiss() })
        }
    }
}

private struct DurationChooser: View {
    let eyebrow: String
    let title: String
    let message: String
    let options: [Int]
    @Binding var selection: Int
    let confirmTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button("Cancel", action: onCancel).font(.bloomLabel(16))
                Spacer()
            }
            .frame(height: 44)

            Text(eyebrow.uppercased())
                .font(.bloomLabel(13, relativeTo: .caption))
                .foregroundStyle(Color.bloomLavenderInk)
            Text(title)
                .font(.bloomDisplay(34, relativeTo: .title))
                .foregroundStyle(Color.bloomInk)
            Text(message)
                .font(.bloomBody(.subheadline))
                .foregroundStyle(Color.bloomInkSecondary)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(options, id: \.self) { minutes in
                    Button { selection = minutes } label: {
                        VStack(spacing: 0) {
                            Text("\(minutes)").font(.bloomDisplay(40))
                            Text("minutes").font(.bloomBody(.caption))
                        }
                        .frame(maxWidth: .infinity, minHeight: 110)
                        .foregroundStyle(selection == minutes ? Color.bloomOnAccent : Color.bloomInk)
                        .background(selection == minutes ? Color.bloomLavender : Color.bloomSurface,
                                    in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(minutes) minutes")
                    .accessibilityAddTraits(selection == minutes ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: selection)

            Spacer()

            Button(confirmTitle, action: onConfirm).buttonStyle(.bloomPrimary)
        }
        .padding(24)
        .background(Color.bloomCanvas.ignoresSafeArea())
    }
}
