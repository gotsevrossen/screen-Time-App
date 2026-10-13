import SwiftUI

struct WebFilterView: View {
    @EnvironmentObject private var model: AppModel
    @State private var unlocking = false
    @State private var newDomain = ""
    @State private var domainError: String?
    @State private var domainToRemove: String?
    @State private var askPIN = false

    var body: some View {
        BloomPage(title: "Web", subtitle: "Adult websites are always blocked in Safari and in apps that use Apple's web views.") {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                statusCard(now: context.date)
                    // Apply the change right away when a timer runs out while Bloom is open.
                    .onChange(of: model.data.web.phase(at: context.date)) { _, _ in model.refresh() }
            }

            SectionLabel(text: "Also block")
            Text("Add any site you want kept out, adult or not. Removing one needs your PIN.")
                .font(.bloomBody(.subheadline))
                .foregroundStyle(Color.bloomInkSecondary)

            HStack(spacing: 10) {
                BloomTextField(placeholder: "example.com", text: $newDomain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.done)
                    .onSubmit(add)
                AddButton(label: "Block site", action: add)
            }
            if let domainError {
                Text(domainError)
                    .font(.bloomBody(.caption))
                    .foregroundStyle(Color.bloomLavenderInk)
            }

            if !model.data.web.customBlockedDomains.isEmpty {
                BloomCard {
                    ForEach(Array(model.data.web.customBlockedDomains.enumerated()), id: \.element) { index, domain in
                        if index > 0 { Rectangle().fill(Color.bloomHairline).frame(height: 1) }
                        HStack {
                            Image(systemName: "nosign").foregroundStyle(Color.bloomLavenderInk)
                            Text(domain).font(.bloomBody())
                            Spacer()
                            Button {
                                domainToRemove = domain
                                askPIN = true
                            } label: {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.bloomInkSecondary)
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Stop blocking \(domain)")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $unlocking) { WebUnlockFlow() }
        .pinProtected(isPresented: $askPIN, message: "Enter your PIN to unblock \(domainToRemove ?? "this site").") {
            if let domainToRemove { model.removeBlockedDomain(domainToRemove) }
        }
    }

    @ViewBuilder
    private func statusCard(now: Date) -> some View {
        switch model.data.web.phase(at: now) {
        case .locked:
            BloomCard(style: .lavender, showsArrow: true) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.white)
                Text("ADULT SITES\nBLOCKED")
                    .font(.bloomDisplay(36))
                    .tracking(-0.5)
                    .foregroundStyle(.white)
                Text("Unlocking takes your PIN and a \(BloomConfig.webUnlockCountdownMinutes) minute wait, then lasts \(BloomConfig.webUnlockDurations.first ?? 5) to \(BloomConfig.webUnlockDurations.last ?? 30) minutes at most.")
                    .font(.bloomBody(.subheadline))
                Button("Unlock temporarily") { unlocking = true }
                    .buttonStyle(.bloomDark)
                    .padding(.top, 4)
            }

        case .countingDown(let until):
            BloomCard(style: .cream) {
                Text("UNLOCKING IN")
                    .font(.bloomLabel(13, relativeTo: .caption))
                    .opacity(0.7)
                Text(DurationText.countdown(until.timeIntervalSince(now)))
                    .font(.bloomDisplay(72))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                Text("Still blocked. Then off for \(DurationText.minutes(model.data.web.unlockMinutes ?? 0)), and back on by itself.")
                    .font(.bloomBody(.subheadline))
                Button("Cancel unlock") { model.lockWebNow() }
                    .buttonStyle(.bloomDark)
                    .padding(.top, 4)
            }

        case .unlocked(let until):
            BloomCard {
                Text("FILTER OFF")
                    .font(.bloomLabel(13, relativeTo: .caption))
                    .foregroundStyle(Color.bloomInkSecondary)
                Text(DurationText.countdown(until.timeIntervalSince(now)))
                    .font(.bloomDisplay(72))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                Text("Turns back on at \(until.formatted(date: .omitted, time: .shortened)).")
                    .font(.bloomBody(.subheadline))
                    .foregroundStyle(Color.bloomInkSecondary)
                Button("Turn it back on now") { model.lockWebNow() }
                    .buttonStyle(.bloomPrimary)
                    .padding(.top, 4)
            }
        }
    }

    private func add() {
        guard !newDomain.isEmpty else { return }
        if model.addBlockedDomain(newDomain) {
            newDomain = ""
            domainError = nil
        } else {
            domainError = "That doesn't look like a website. Try something like example.com."
        }
    }
}
