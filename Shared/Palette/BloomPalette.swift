import UIKit

/// Brand palette from the Bloom guidelines: lavender #D1A0F3, white, cream, on a soft gray canvas.
enum BloomPalette {
    static let lavender = UIColor(hex: 0xD1A0F3)
    /// Lavender darkened for small text and icons, which need more contrast than the brand tint gives.
    static let lavenderInk = UIColor.dynamic(light: 0x7A45B0, dark: 0xD9B3F6)
    static let cream = UIColor(hex: 0xEDE1B6)
    static let canvas = UIColor.dynamic(light: 0xE8E8E8, dark: 0x0F0E12)
    static let surface = UIColor.dynamic(light: 0xFFFFFF, dark: 0x1D1B22)
    static let ink = UIColor.dynamic(light: 0x0B0B0C, dark: 0xF6F4F8)
    static let inkSecondary = UIColor.dynamic(light: 0x55545C, dark: 0xADAAB6)
    /// Text that sits on lavender or cream, which stay light in both modes.
    static let onAccent = UIColor(hex: 0x0B0B0C)
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }
}
