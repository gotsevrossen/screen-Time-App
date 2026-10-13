import FamilyControls
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step = Step.welcome

    enum Step { case welcome, access, pin, notifications, done }

    var body: some View {
        ZStack {
            Color.bloomCanvas.ignoresSafeArea()
            switch step {
            case .welcome: welcome
            case .access: access
            case .pin:
                PINPadView(mode: .create) { advance(to: .notifications) }
                    .transition(.move(edge: .trailing))
            case .notifications: notifications
            case .done: done
            }
        }
        .animation(.smooth(duration: 0.35), value: step)
    }

    private func advance(to next: Step) { step = next }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            BloomCard(style: .lavender, showsArrow: true) {
                Spacer(minLength: 120)
                Image("BloomMark")
                    .resizable()
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)
                Text("GROW\nYOUR\nTIME")
                    .font(.bloomDisplay(64))
                    .tracking(-1.5)
                    .lineSpacing(-12)
                    .foregroundStyle(.white)
                    .accessibilityLabel("Grow your time")
                Text("Daily limits, quiet hours and a safer web. All on your terms.")
                    .font(.bloomBody(.headline))
                    .foregroundStyle(.white)
            }
            .frame(maxHeight: .infinity)

            Button("Get started") { advance(to: .access) }
                .buttonStyle(.bloomDark)
                .padding(.top, 20)
        }
        .padding(20)
    }

    private var access: some View {
        StepLayout(
            number: "01",
            title: "Screen Time access",
            message: "Bloom uses Apple's Screen Time tools to block apps and filter websites. Apple never shares which apps you use with Bloom, and nothing leaves your phone.",
            primary: model.isAuthorized ? "Continue" : "Allow access",
            action: {
                if model.isAuthorized { advance(to: .pin); return }
                Task {
                    await model.requestAuthorization()
                    if model.isAuthorized { advance(to: .pin) }
                }
            })
    }

    private var notifications: some View {
        StepLayout(
            number: "03",
            title: "Gentle reminders",
            message: "Get a heads-up when a limit runs out, when an unlock timer finishes and when your web filter turns back on.",
            primary: "Allow notifications",
            secondary: "Not now",
            action: {
                Task {
                    await model.requestNotifications()
                    advance(to: .done)
                }
            },
            secondaryAction: { advance(to: .done) })
    }

    private var done: some View {
        StepLayout(
            number: "✓",
            title: "You're all set",
            message: "Adult websites are now blocked. Next, add a daily limit for the apps that pull you in the most.",
            primary: "Start blooming",
            action: { model.completeOnboarding() })
    }
}

private struct StepLayout: View {
    let number: String
    let title: String
    let message: String
    let primary: String
    var secondary: String? = nil
    let action: () -> Void
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(number)
                .font(.bloomDisplay(96))
                .foregroundStyle(Color.bloomLavender)
                .accessibilityHidden(true)
            Text(title.uppercased())
                .font(.bloomDisplay(40))
                .tracking(-1)
                .foregroundStyle(Color.bloomInk)
            Rectangle().fill(Color.bloomHairline).frame(height: 1)
            Text(message)
                .font(.bloomBody(.title3))
                .foregroundStyle(Color.bloomInkSecondary)
            Spacer()
            Button(primary, action: action).buttonStyle(.bloomPrimary)
            if let secondary, let secondaryAction {
                Button(secondary, action: secondaryAction).buttonStyle(.bloomSecondary)
            }
        }
        .padding(24)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
}
