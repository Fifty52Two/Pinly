import SwiftUI
import UIKit

// MARK: - Pinly Tasarım Sistemi — "Doğal" palet
// Yön: AllTrails/Airbnb tarzı — ılık nötr zeminler, tek ve kısık aksan (çam yeşili),
// gradient yok, flat yüzeyler. Tüm bileşenler renkleri BURADAN alır.

enum PinlyTheme {
    /// Ana aksan — çam yeşili (dark mode'da bir ton açılır)
    static let primary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.42, green: 0.66, blue: 0.52, alpha: 1)   // #6BA885
            : UIColor(red: 0.20, green: 0.41, blue: 0.31, alpha: 1)   // #33684E
    })

    /// Ana aksanın açık tonu (vurgu metinleri, ikincil dolgular)
    static let primaryWarm = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.55, green: 0.76, blue: 0.63, alpha: 1)   // #8CC2A1
            : UIColor(red: 0.29, green: 0.53, blue: 0.41, alpha: 1)   // #4A8768
    })

    /// İkincil aksan — kil/toprak (seri, küçük vurgular; az kullan)
    static let accent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.81, green: 0.54, blue: 0.39, alpha: 1)   // #CE8A64
            : UIColor(red: 0.71, green: 0.42, blue: 0.28, alpha: 1)   // #B56A47
    })

    /// Nötr destek tonları — düşük doygunluk, doğal
    static let gold = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.76, green: 0.63, blue: 0.37, alpha: 1)   // #C2A05E
            : UIColor(red: 0.64, green: 0.50, blue: 0.24, alpha: 1)   // #A3803C
    })
    static let slate = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.50, green: 0.64, blue: 0.71, alpha: 1)   // #7FA3B5
            : UIColor(red: 0.31, green: 0.45, blue: 0.53, alpha: 1)   // #4E7286
    })

    /// Sayfa zemini — ılık kâğıt (dark'ta ılık is)
    static let ground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.088, blue: 0.078, alpha: 1) // #171614
            : UIColor(red: 0.965, green: 0.955, blue: 0.935, alpha: 1) // #F6F4EF
    })

    /// Kart yüzeyi
    static let surface = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.132, green: 0.126, blue: 0.112, alpha: 1) // #22201D
            : UIColor.white
    })

    /// Koyu zemin (paylaşım kartı gibi her modda koyu kalan yüzeyler) — çam isi
    static let navy = Color(red: 0.078, green: 0.106, blue: 0.090)      // #141B17
    static let navyLight = Color(red: 0.118, green: 0.165, blue: 0.137) // #1E2A23

    /// Dolgun yüzey "gradyanı" — aslında tek ailede iki komşu ton; flat okunur
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.17, green: 0.36, blue: 0.27),  // #2C5C45
                Color(red: 0.21, green: 0.43, blue: 0.32),  // #366E52
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var nightGradient: LinearGradient {
        LinearGradient(colors: [navy, navyLight], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Buton Stilleri

/// Dolgun ana buton — flat çam yeşili
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

/// Hafif zeminli ikincil buton
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
// Gölge yerine ince kontur — kâğıt üzerinde kart hissi, daha doğal

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

// MARK: - İstatistik Rozeti (ana ekran şeridi + profil)

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
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
