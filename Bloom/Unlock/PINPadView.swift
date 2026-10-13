import SwiftUI

/// Full-screen 4-digit keypad, used both to create a PIN and to check it.
struct PINPadView: View {
    enum Mode {
        case verify
        case create
    }

    let mode: Mode
    var title: String? = nil
    var message: String? = nil
    let onComplete: () -> Void
    var onCancel: (() -> Void)? = nil

    @State private var entry = ""
    @State private var firstEntry: String?
    @State private var error: String?
    @State private var shake = 0
    @State private var lockedUntil = PINManager.shared.lockedUntil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let onCancel {
                    Button("Cancel", action: onCancel)
                        .font(.bloomLabel(16))
                        .foregroundStyle(Color.bloomOnAccent)
                }
                Spacer()
            }
            .frame(height: 44)

            Spacer(minLength: 12)

            Image("BloomMark")
                .resizable()
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)

            Text(heading)
                .font(.bloomDisplay(28, relativeTo: .title))
                .multilineTextAlignment(.center)
                .padding(.top, 20)

            Text(error ?? subheading)
                .font(.bloomBody(.subheadline))
                .multilineTextAlignment(.center)
                .opacity(0.75)
                .padding(.top, 8)
                .frame(minHeight: 40, alignment: .top)

            HStack(spacing: 18) {
                ForEach(0..<PINManager.length, id: \.self) { index in
                    Circle()
                        .strokeBorder(Color.bloomOnAccent, lineWidth: 1.5)
                        .background(Circle().fill(index < entry.count ? Color.bloomOnAccent : .clear))
                        .frame(width: 16, height: 16)
                }
            }
            .modifier(Shake(animatableData: CGFloat(shake)))
            .animation(.linear(duration: 0.35), value: shake)
            .padding(.vertical, 24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(entry.count) of \(PINManager.length) digits entered")

            Spacer(minLength: 12)

            keypad
                .disabled(isLocked)
                .opacity(isLocked ? 0.4 : 1)
        }
        .padding(24)
        .foregroundStyle(Color.bloomOnAccent)
        .background(Color.bloomLavender.ignoresSafeArea())
        .sensoryFeedback(.error, trigger: shake)
    }

    private var isLocked: Bool { (lockedUntil ?? .distantPast) > Date() }

    private var heading: String {
        if let title { return title }
        switch mode {
        case .verify: return "Enter your PIN"
        case .create: return firstEntry == nil ? "Create a PIN" : "Confirm your PIN"
        }
    }

    private var subheading: String {
        if let until = lockedUntil, until > Date() {
            return "Too many tries. Try again at \(until.formatted(date: .omitted, time: .shortened))."
        }
        if let message { return message }
        switch mode {
        case .verify: return " "
        case .create:
            return firstEntry == nil
                ? "You'll need it to loosen a limit or unlock anything early."
                : "Enter the same four digits again."
        }
    }

    private var keypad: some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
            ForEach(keys, id: \.self) { key in
                if key.isEmpty {
                    Color.clear.frame(height: 72)
                } else {
                    Button { tap(key) } label: {
                        Group {
                            if key == "⌫" {
                                Image(systemName: "delete.left").font(.system(size: 22, weight: .regular))
                            } else {
                                Text(key).font(.bloomDisplay(30, relativeTo: .title))
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(Color.white.opacity(key == "⌫" ? 0 : 0.35),
                                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(key == "⌫" ? "Delete" : key)
                }
            }
        }
    }

    private func tap(_ key: String) {
        if key == "⌫" {
            if !entry.isEmpty { entry.removeLast() }
            return
        }
        guard entry.count < PINManager.length else { return }
        entry.append(key)
        error = nil
        if entry.count == PINManager.length {
            // Let the last dot fill before reacting.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { submit() }
        }
    }

    private func submit() {
        switch mode {
        case .verify:
            switch PINManager.shared.verify(entry) {
            case .success:
                onComplete()
            case .wrong(let left):
                fail(left > 0 ? "Wrong PIN. \(left) tries left before a short wait." : "Wrong PIN.")
            case .lockedOut(let until):
                lockedUntil = until
                fail(nil)
            }
        case .create:
            if let first = firstEntry {
                if first == entry, PINManager.shared.setPIN(entry) {
                    onComplete()
                } else {
                    firstEntry = nil
                    fail("Those didn't match. Let's start again.")
                }
            } else {
                firstEntry = entry
                entry = ""
            }
        }
    }

    private func fail(_ message: String?) {
        error = message
        entry = ""
        shake += 1
    }
}

private struct Shake: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 4), y: 0))
    }
}

extension View {
    /// Shows the PIN pad as a sheet and runs `action` only if the PIN was right,
    /// after the sheet has finished closing (so `action` can present another sheet).
    func pinProtected(isPresented: Binding<Bool>, message: String? = nil, action: @escaping () -> Void) -> some View {
        modifier(PINProtected(isPresented: isPresented, message: message, action: action))
    }
}

private struct PINProtected: ViewModifier {
    @Binding var isPresented: Bool
    let message: String?
    let action: () -> Void
    @State private var verified = false

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: {
            if verified {
                verified = false
                action()
            }
        }) {
            PINPadView(mode: .verify, message: message, onComplete: {
                verified = true
                isPresented = false
            }, onCancel: {
                isPresented = false
            })
        }
    }
}
