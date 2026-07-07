import SwiftUI

// MARK: - Color + Hex

extension Color {
    init(hex: Int, opacity: Double = 1.0) {
        self.init(
            red:     Double((hex >> 16) & 0xFF) / 255.0,
            green:   Double((hex >> 8)  & 0xFF) / 255.0,
            blue:    Double(hex         & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - Theme Colors

struct ThemeColors {
    let bg: Color
    let title: Color
    let subtitle: Color
    let primary: Color
    let accent: Color
    let buttonText: Color
    let card: Color
    let cardBorder: Color
    let inputBg: Color
    let separator: Color
    let destructive: Color

    static func make(_ stored: String) -> ThemeColors {
        if stored == "light" {
            return ThemeColors(
                bg:          Color(hex: 0xFBF9F6),
                title:       Color(hex: 0x1b1c1a),
                subtitle:    Color(hex: 0x4e453b),
                primary:     Color(hex: 0x735a36),
                accent:      Color(hex: 0xC8A97E),
                buttonText:  .white,
                card:        Color(hex: 0xF4F0EB),
                cardBorder:  Color(hex: 0xC8A97E).opacity(0.25),
                inputBg:     Color(hex: 0xEFECE7),
                separator:   Color(hex: 0x1b1c1a).opacity(0.07),
                destructive: Color(hex: 0xB85C4A)
            )
        } else {
            return ThemeColors(
                bg:          Color(hex: 0x1A1C19),
                title:       Color(hex: 0xE4E7DD),
                subtitle:    Color(hex: 0xC8CCC0),
                primary:     Color(hex: 0xC5C9A4),
                accent:      Color(hex: 0xDFE39C),
                buttonText:  Color(hex: 0x1A1C19),
                card:        Color(hex: 0x252822),
                cardBorder:  Color(hex: 0xC5C9A4).opacity(0.18),
                inputBg:     Color(hex: 0x2A2D27),
                separator:   Color(hex: 0xE4E7DD).opacity(0.07),
                destructive: Color(hex: 0xE8927A)
            )
        }
    }
}
