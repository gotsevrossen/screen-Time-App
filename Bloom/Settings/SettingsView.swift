import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var changePINStep: ChangePINStep?
    @State private var askResetPIN = false
    @State private var confirmReset = false
    @State private var notificationsAllowed: Bool?

    enum ChangePINStep: Identifiable {
        case verifyOld, createNew
        var id: Self { self }
    }

    var body: some View {
        BloomPage(title: "Settings", subtitle: "Your PIN, permissions and how Bloom works.") {
            BloomCard {
                row(icon: "lock", title: "Change PIN", detail: "Needs your current PIN") {
                    changePINStep = .verifyOld
                }
                Rectangle().fill(Color.bloomHairline).frame(height: 1)
                row(icon: "hourglass", title: "Screen Time access",
                    detail: model.isAuthorized ? "Allowed" : "Off, tap to allow") {
                    if !model.isAuthorized { Task { await model.requestAuthorization() } }
                }
                Rectangle().fill(Color.bloomHairline).frame(height: 1)
                row(icon: "bell", title: "Notifications", detail: notificationDetail) {
                    if notificationsAllowed == false, let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    } else {
                        Task {
                            await model.requestNotifications()
                            await loadNotificationStatus()
                        }
                    }
                }
            }

            SectionLabel(text: "How Bloom works")
            BloomCard(style: .cream) {
                explainer("Limits", "Count your time across the apps you pick. When the budget is used up they're blocked until midnight.")
                explainer("Downtime", "Blocks apps during the hours you set, every week.")
                explainer("Adult filter", "Uses Apple's own adult content filter, the same one built into Screen Time. It can only be paused with your PIN, after a 10 minute wait, for 30 minutes at most.")
                explainer("Your privacy", "Apple keeps app names and usage on your phone. Bloom never sees or sends them anywhere.")
            }

            Button("Remove all limits and downtime") { askResetPIN = true }
                .buttonStyle(.bloomSecondary)
                .padding(.top, 8)

            Text("Bloom \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                .font(.bloomBody(.caption))
                .foregroundStyle(Color.bloomInkSecondary)
                .frame(maxWidth: .infinity)
        }
        .task { await loadNotificationStatus() }
        .sheet(item: $changePINStep) { step in
            switch step {
            case .verifyOld:
                PINPadView(mode: .verify, message: "Enter your current PIN.", onComplete: {
                    changePINStep = .createNew
                }, onCancel: { changePINStep = nil })
            case .createNew:
                PINPadView(mode: .create, onComplete: { changePINStep = nil }, onCancel: { changePINStep = nil })
            }
        }
        .pinProtected(isPresented: $askResetPIN, message: "Enter your PIN to remove every rule.") {
            confirmReset = true
        }
        .confirmationDialog("Remove every limit and downtime?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Remove all", role: .destructive) { model.resetRules() }
        } message: {
            Text("The adult filter stays on.")
        }
    }

    private var notificationDetail: String {
        switch notificationsAllowed {
        case true?: "On"
        case false?: "Off, tap to open Settings"
        case nil: "Not set up"
        }
    }

    private func loadNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: notificationsAllowed = true
        case .denied: notificationsAllowed = false
        default: notificationsAllowed = nil
        }
    }

    private func row(icon: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(width: 40, height: 40)
                    .background(Color.bloomLavender.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.bloomLabel(16))
                    Text(detail).font(.bloomBody(.caption)).foregroundStyle(Color.bloomInkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.bloomInkSecondary)
            }
            .foregroundStyle(Color.bloomInk)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func explainer(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.bloomHeading(17))
            Text(text).font(.bloomBody(.subheadline)).opacity(0.8)
        }
    }
}
