import SwiftUI

extension Color {
    static let bloomLavender = Color(BloomPalette.lavender)
    static let bloomLavenderInk = Color(BloomPalette.lavenderInk)
    static let bloomCream = Color(BloomPalette.cream)
    static let bloomCanvas = Color(BloomPalette.canvas)
    static let bloomSurface = Color(BloomPalette.surface)
    static let bloomInk = Color(BloomPalette.ink)
    static let bloomInkSecondary = Color(BloomPalette.inkSecondary)
    static let bloomOnAccent = Color(BloomPalette.onAccent)
    static let bloomHairline = Color(BloomPalette.ink).opacity(0.18)
}

/// Poppins SemiBold for headings, per the guidelines. Canva Sans (the body face) is only licensed
/// inside Canva, so body text uses the system font, which has a similar neutral, open feel.
extension Font {
    static func bloomDisplay(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("Poppins-SemiBold", size: size, relativeTo: style)
    }

    static func bloomHeading(_ size: CGFloat, relativeTo style: Font.TextStyle = .title3) -> Font {
        .custom("Poppins-SemiBold", size: size, relativeTo: style)
    }

    static func bloomLabel(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Poppins-Medium", size: size, relativeTo: style)
    }

    static func bloomBody(_ style: Font.TextStyle = .body) -> Font {
        .system(style)
    }
}

enum BloomRadius {
    static let card: CGFloat = 32
    static let control: CGFloat = 20
    static let chip: CGFloat = 14
}
