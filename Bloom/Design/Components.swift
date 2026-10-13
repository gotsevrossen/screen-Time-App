import FamilyControls
import SwiftUI

/// Page scaffold: huge uppercase title, a hairline, and a short description on the right,
/// echoing the layout of the Bloom brand guidelines.
struct BloomPage<Content: View, Accessory: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        Text(title.uppercased())
                            .font(.bloomDisplay(46))
                            .tracking(-1)
                            .foregroundStyle(Color.bloomInk)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 12)
                        accessory()
                    }
                    Rectangle().fill(Color.bloomHairline).frame(height: 1)
                    Text(subtitle)
                        .font(.bloomBody(.subheadline))
                        .foregroundStyle(Color.bloomInkSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.top, 8)

                content()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Color.bloomCanvas.ignoresSafeArea())
    }
}

extension BloomPage where Accessory == EmptyView {
    init(title: String, subtitle: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, subtitle: subtitle, accessory: { EmptyView() }, content: content)
    }
}

enum BloomCardStyle {
    case lavender, cream, surface

    var background: Color {
        switch self {
        case .lavender: .bloomLavender
        case .cream: .bloomCream
        case .surface: .bloomSurface
        }
    }

    var foreground: Color {
        self == .surface ? .bloomInk : .bloomOnAccent
    }

    var secondary: Color {
        self == .surface ? .bloomInkSecondary : Color.bloomOnAccent.opacity(0.7)
    }
}

/// The big, softly rounded slab used throughout the brand.
struct BloomCard<Content: View>: View {
    var style: BloomCardStyle = .surface
    var showsArrow = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .foregroundStyle(style.foreground)
            .background(style.background, in: RoundedRectangle(cornerRadius: BloomRadius.card, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if showsArrow {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 26, weight: .ultraLight))
                        .foregroundStyle(style == .lavender ? Color.white : style.secondary)
                        .padding(22)
                        .accessibilityHidden(true)
                }
            }
    }
}

struct BloomPrimaryButtonStyle: ButtonStyle {
    var fill: Color = .bloomLavender
    var foreground: Color = .bloomOnAccent
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bloomLabel(17))
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(foreground)
            .background(fill, in: RoundedRectangle(cornerRadius: BloomRadius.control, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct BloomSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bloomLabel(17))
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(Color.bloomInk)
            .background(
                RoundedRectangle(cornerRadius: BloomRadius.control, style: .continuous)
                    .strokeBorder(Color.bloomInk.opacity(0.85), lineWidth: 1.5))
            .contentShape(RoundedRectangle(cornerRadius: BloomRadius.control, style: .continuous))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == BloomPrimaryButtonStyle {
    static var bloomPrimary: BloomPrimaryButtonStyle { .init() }
    static var bloomDark: BloomPrimaryButtonStyle { .init(fill: .bloomOnAccent, foreground: .white) }
}

extension ButtonStyle where Self == BloomSecondaryButtonStyle {
    static var bloomSecondary: BloomSecondaryButtonStyle { .init() }
}

/// Round "+" button for page headers.
struct AddButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.bloomOnAccent)
                .frame(width: 48, height: 48)
                .background(Color.bloomLavender, in: Circle())
        }
        .accessibilityLabel(label)
    }
}

/// Selectable pill used for durations and weekdays.
struct BloomChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.bloomLabel(15))
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, 10)
                .foregroundStyle(isSelected ? Color.bloomOnAccent : Color.bloomInk)
                .background(
                    RoundedRectangle(cornerRadius: BloomRadius.chip, style: .continuous)
                        .fill(isSelected ? Color.bloomLavender : Color.bloomSurface))
                .overlay(
                    RoundedRectangle(cornerRadius: BloomRadius.chip, style: .continuous)
                        .strokeBorder(isSelected ? Color.clear : Color.bloomHairline))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

struct StatusPill: View {
    let text: String
    var style: BloomCardStyle = .lavender

    var body: some View {
        Text(text)
            .font(.bloomLabel(12, relativeTo: .caption))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(style.foreground)
            .background(style.background, in: Capsule())
    }
}

/// A row of app, category and website icons for a selection.
struct SelectionIcons: View {
    let selection: FamilyActivitySelection
    var maxIcons = 6

    var body: some View {
        let apps = Array(selection.applicationTokens.prefix(maxIcons))
        let categories = Array(selection.categoryTokens.prefix(max(0, maxIcons - apps.count)))
        let shown = apps.count + categories.count
        let remaining = selection.itemCount - shown

        HStack(spacing: -6) {
            ForEach(apps, id: \.self) { token in
                Label(token).labelStyle(.iconOnly).iconFrame()
            }
            ForEach(categories, id: \.self) { token in
                Label(token).labelStyle(.iconOnly).iconFrame()
            }
            if remaining > 0 {
                Text("+\(remaining)")
                    .font(.bloomLabel(12, relativeTo: .caption))
                    .foregroundStyle(Color.bloomInk)
                    .frame(width: 30, height: 30)
                    .background(Color.bloomCanvas, in: Circle())
                    .padding(.leading, 10)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(selection.itemCount) apps, categories or websites")
    }
}

private extension View {
    func iconFrame() -> some View {
        self.frame(width: 30, height: 30)
            .background(Color.bloomSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.bloomSurface, lineWidth: 2))
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.bloomHeading(20))
            .foregroundStyle(Color.bloomInk)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

struct BloomTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.bloomBody())
            .padding(.horizontal, 18)
            .frame(minHeight: 56)
            .background(Color.bloomSurface, in: RoundedRectangle(cornerRadius: BloomRadius.control, style: .continuous))
    }
}
