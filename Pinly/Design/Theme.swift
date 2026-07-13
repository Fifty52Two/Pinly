import SwiftUI
import UIKit

// MARK: - Pinly Tasarım Sistemi
// İki tema: "slate" (koyu/mavi, dinamik) ve "lavender" (temiz lavanta-beyaz, indigo aksan).
// ThemeManager.shared.themeKey hangi temayı seçtiğini tutar.
// ContentView'daki .id(themeKey) root yeniden kurulduğunda tüm renkler taze okunur.

// MARK: - Ana Tema Tokenları (PinlyTheme)

enum PinlyTheme {
    /// Ana aksan
    static let primary = Color(uiColor: UIColor { trait in
        let lavender = ThemeManager.shared.style == .lavender
        let dark  = trait.userInterfaceStyle == .dark
        switch (lavender, dark) {
        case (true,  true):  return UIColor(red: 0.482, green: 0.557, blue: 0.941, alpha: 1) // #7B8EF0
        case (true,  false): return UIColor(red: 0.290, green: 0.365, blue: 0.831, alpha: 1) // #4A5DD4
        case (false, true):  return UIColor(red: 0.550, green: 0.640, blue: 0.820, alpha: 1) // #8CA3D1
        case (false, false): return UIColor(red: 0.270, green: 0.350, blue: 0.540, alpha: 1) // #45598A
        }
    })

    /// Birincil aksanın açık tonu
    static let primaryWarm = Color(uiColor: UIColor { trait in
        let lavender = ThemeManager.shared.style == .lavender
        let dark  = trait.userInterfaceStyle == .dark
        switch (lavender, dark) {
        case (true,  true):  return UIColor(red: 0.608, green: 0.667, blue: 1.000, alpha: 1) // #9BAAFF
        case (true,  false): return UIColor(red: 0.420, green: 0.498, blue: 0.894, alpha: 1) // #6B7FE4
        case (false, true):  return UIColor(red: 0.650, green: 0.730, blue: 0.880, alpha: 1) // #A6BAE0
        case (false, false): return UIColor(red: 0.360, green: 0.440, blue: 0.630, alpha: 1) // #5C70A1
        }
    })

    /// İkincil aksan — kısık gül/kızıl (her iki temada aynı)
    static let accent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.88, green: 0.44, blue: 0.47, alpha: 1) // #E07078
            : UIColor(red: 0.76, green: 0.31, blue: 0.35, alpha: 1) // #C14F5A
    })

    /// Nötr altın tonu
    static let gold = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.76, green: 0.63, blue: 0.37, alpha: 1)
            : UIColor(red: 0.61, green: 0.51, blue: 0.28, alpha: 1)
    })

    /// Slate-teal nötr tonu
    static let slate = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.50, green: 0.64, blue: 0.71, alpha: 1)
            : UIColor(red: 0.31, green: 0.45, blue: 0.53, alpha: 1)
    })

    // MARK: - Zemin Renkleri

    /// Sayfa zemini
    static let ground = Color(uiColor: UIColor { trait in
        let lavender = ThemeManager.shared.style == .lavender
        let dark  = trait.userInterfaceStyle == .dark
        switch (lavender, dark) {
        case (true,  true):  return UIColor(red: 0.082, green: 0.090, blue: 0.165, alpha: 1) // #151727
        case (true,  false): return UIColor(red: 0.906, green: 0.918, blue: 0.969, alpha: 1) // #E7EAF7
        case (false, true):  return UIColor(red: 0.075, green: 0.110, blue: 0.149, alpha: 1) // #131C26
        case (false, false): return UIColor(red: 0.686, green: 0.792, blue: 0.890, alpha: 1) // #AFCAE3
        }
    })

    /// Kart yüzeyi
    static let surface = Color(uiColor: UIColor { trait in
        let lavender = ThemeManager.shared.style == .lavender
        let dark  = trait.userInterfaceStyle == .dark
        switch (lavender, dark) {
        case (true,  true):  return UIColor(red: 0.145, green: 0.161, blue: 0.271, alpha: 1) // #252945
        case (true,  false): return UIColor.white
        case (false, true):  return UIColor(red: 0.196, green: 0.263, blue: 0.365, alpha: 1) // #32435D
        case (false, false): return UIColor(red: 0.937, green: 0.965, blue: 0.988, alpha: 1) // #EFF6FC
        }
    })

    /// Gradyan üst durağı
    static let groundTop = Color(uiColor: UIColor { trait in
        let lavender = ThemeManager.shared.style == .lavender
        let dark  = trait.userInterfaceStyle == .dark
        switch (lavender, dark) {
        case (true,  true):  return UIColor(red: 0.145, green: 0.157, blue: 0.251, alpha: 1) // #252840
        case (true,  false): return UIColor(red: 0.957, green: 0.961, blue: 0.992, alpha: 1) // #F5F5FD
        case (false, true):  return UIColor(red: 0.271, green: 0.337, blue: 0.424, alpha: 1) // #45566C
        case (false, false): return UIColor(red: 0.835, green: 0.902, blue: 0.961, alpha: 1) // #D5E6F5
        }
    })

    /// Gradyan orta durağı
    static let groundMid = Color(uiColor: UIColor { trait in
        let lavender = ThemeManager.shared.style == .lavender
        let dark  = trait.userInterfaceStyle == .dark
        switch (lavender, dark) {
        case (true,  true):  return UIColor(red: 0.098, green: 0.110, blue: 0.212, alpha: 1) // #191C36
        case (true,  false): return UIColor(red: 0.929, green: 0.937, blue: 0.980, alpha: 1) // #EDEFFA
        case (false, true):  return UIColor(red: 0.153, green: 0.200, blue: 0.263, alpha: 1) // #273343
        case (false, false): return UIColor(red: 0.765, green: 0.851, blue: 0.929, alpha: 1) // #C3D9ED
        }
    })

    /// TÜM ekran zeminleri bunu kullanır
    static var groundGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: groundTop, location: 0.0),
                .init(color: groundMid, location: 0.45),
                .init(color: ground,    location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Sabit Renkler (tema bağımsız)

    static let navy      = Color(red: 0.106, green: 0.153, blue: 0.200) // #1B2733
    static let navyLight = Color(red: 0.149, green: 0.208, blue: 0.278)

    // MARK: - Hero Kart Gradyanı

    private static let heroTop = Color(uiColor: UIColor { trait in
        let lavender = ThemeManager.shared.style == .lavender
        let dark  = trait.userInterfaceStyle == .dark
        switch (lavender, dark) {
        case (true,  true):  return UIColor(red: 0.145, green: 0.161, blue: 0.271, alpha: 1) // düz #252945
        case (true,  false): return UIColor(red: 0.220, green: 0.286, blue: 0.780, alpha: 1) // #3849C7
        case (false, true):  return UIColor(red: 0.227, green: 0.298, blue: 0.408, alpha: 1) // #3A4C68 düz
        case (false, false): return UIColor(red: 0.165, green: 0.227, blue: 0.322, alpha: 1) // #2A3A52
        }
    })

    private static let heroBottom = Color(uiColor: UIColor { trait in
        let lavender = ThemeManager.shared.style == .lavender
        let dark  = trait.userInterfaceStyle == .dark
        switch (lavender, dark) {
        case (true,  true):  return UIColor(red: 0.145, green: 0.161, blue: 0.271, alpha: 1)
        case (true,  false): return UIColor(red: 0.290, green: 0.365, blue: 0.831, alpha: 1) // #4A5DD4
        case (false, true):  return UIColor(red: 0.227, green: 0.298, blue: 0.408, alpha: 1)
        case (false, false): return UIColor(red: 0.227, green: 0.298, blue: 0.408, alpha: 1)
        }
    })

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [heroTop, heroBottom], startPoint: .top, endPoint: .bottom)
    }

    static var nightGradient: LinearGradient {
        LinearGradient(colors: [navy, navyLight], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Buton Stilleri

struct PinlyPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(PinlyTheme.primary)
            .cornerRadius(14)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct PinlySecondaryButtonStyle: ButtonStyle {
    var tint: Color = PinlyTheme.primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(tint.opacity(0.10))
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Kart Stili

struct PinlyCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(PinlyTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func pinlyCard() -> some View { modifier(PinlyCardModifier()) }
}

// MARK: - İstatistik Rozeti

struct StatChip: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
