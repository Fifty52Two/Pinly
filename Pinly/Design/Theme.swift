import SwiftUI
import UIKit

// MARK: - Pinly Tasarım Sistemi
//
// Tek tema: "seigaiha" — katmanlı dağ/tepe illüstrasyonundan esinlenen krem-kağıt
// zemin + sage yeşili + toz mavi-gri + koyu lacivert paleti, açık/koyu moda otomatik uyar.
// Renkler UIColor dynamic provider ile açık/koyu moda kendiliğinden uyum sağlar
// (kullanıcı tercihi `pinly.appearance` üzerinden pencere seviyesinde uygulanır).
//
// KURALLAR (tasarım kararları — bilinçli, değiştirme):
// - Gölge yerine ince kontur (`hairline`). Tek istisna: PinlyTabBar'ın yüzen bar gölgesi.
// - Arayüzde emoji kullanılmaz; SF Symbols tercih edilir.
// - Yeni bileşenler renkleri BURADAN alır; view içinde renk hardcode edilmez.

// MARK: - Ana Tema Tokenları (PinlyTheme)

enum PinlyTheme {
    /// Ana aksan — toz mavi-gri
    static let primary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.616, green: 0.690, blue: 0.761, alpha: 1) // #9DB0C2
            : UIColor(red: 0.259, green: 0.314, blue: 0.369, alpha: 1) // #42505E
    })

    /// Birincil aksanın açık tonu
    static let primaryWarm = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.706, green: 0.769, blue: 0.824, alpha: 1) // #B4C4D2
            : UIColor(red: 0.455, green: 0.518, blue: 0.588, alpha: 1) // #748496
    })

    /// İkincil aksan — toprak/terracotta
    static let accent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.851, green: 0.478, blue: 0.384, alpha: 1) // #D97A62
            : UIColor(red: 0.710, green: 0.325, blue: 0.247, alpha: 1) // #B5533F
    })

    /// Nötr altın tonu
    static let gold = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.788, green: 0.678, blue: 0.431, alpha: 1) // #C9AD6E
            : UIColor(red: 0.659, green: 0.545, blue: 0.290, alpha: 1) // #A88B4A
    })

    /// Sage / çamurlu yeşil nötr tonu
    static let slate = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.608, green: 0.686, blue: 0.576, alpha: 1) // #9BAF93
            : UIColor(red: 0.353, green: 0.431, blue: 0.329, alpha: 1) // #5A6E54
    })

    // MARK: - Anlamsal Durum Renkleri

    /// Başarı / tamamlandı / ziyaret edildi — sage yeşili
    static let success = slate
    /// Uyarı / dikkat gerektiren durum
    static let warning = gold
    /// Tehlike / silme / hata
    static let danger = accent
    /// Puan yıldızları
    static let ratingStar = gold
    /// Haritada tamamlanmış rota segmenti çizgisi
    static let routeCompleted = slate
    /// Haritada aktif/önümüzdeki rota segmenti çizgisi
    static let routeActive = primary

    // MARK: - Yüzey Yardımcıları

    /// systemGray5/6 yerine kullanılacak kısık dolgu (chip/satır zeminleri)
    static let fillMuted = Color(uiColor: .secondarySystemFill)
    /// İnce kart kenarlığı — "gölge değil kenarlık" kuralının tek kaynağı
    static let hairline = Color.primary.opacity(0.07)

    /// `primary`/`accent`/`gold`/`slate` SOLID dolgu üzerine yazılan metin/ikon rengi.
    /// Bu dört token karanlık modda AÇILIR (bkz. yukarıdaki tanımlar) — üzerlerine sabit
    /// `.white` yazmak WCAG kontrastını kırar (ör. karanlık modda `primary` #9DB0C2
    /// üzerinde beyaz metin ~2.2:1 — 4.5:1 eşiğinin altında). Açık modda bu token'lar
    /// koyu olduğu için orada beyaz kalır; karanlık modda koyu (navy) metne döner.
    static let onAccent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.133, green: 0.118, blue: 0.169, alpha: 1) // #221E2B (navy)
            : .white
    })

    // MARK: - Zemin Renkleri

    /// Sayfa zemini — krem/kağıt (açık) / koyu lacivert-antrasit (koyu)
    static let ground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.110, green: 0.102, blue: 0.133, alpha: 1) // #1C1A22
            : UIColor(red: 0.941, green: 0.914, blue: 0.863, alpha: 1) // #F0E9DC
    })

    /// Kart yüzeyi
    static let surface = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.180, green: 0.165, blue: 0.220, alpha: 1) // #2E2A38
            : UIColor(red: 0.969, green: 0.949, blue: 0.910, alpha: 1) // #F7F2E8
    })

    /// Gradyan üst durağı
    static let groundTop = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.165, green: 0.153, blue: 0.200, alpha: 1) // #2A2733
            : UIColor(red: 0.965, green: 0.945, blue: 0.906, alpha: 1) // #F6F1E7
    })

    /// Gradyan orta durağı
    static let groundMid = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.133, green: 0.118, blue: 0.169, alpha: 1) // #221E2B
            : UIColor(red: 0.894, green: 0.851, blue: 0.769, alpha: 1) // #E4D9C4
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

    // MARK: - Sabit Renkler (mod bağımsız)

    static let navy      = Color(red: 0.133, green: 0.118, blue: 0.169) // #221E2B
    static let navyLight = Color(red: 0.200, green: 0.180, blue: 0.251) // #332E40

    // MARK: - Hero Kart Gradyanı

    private static let heroTop = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.259, green: 0.314, blue: 0.369, alpha: 1) // #42505E düz
            : UIColor(red: 0.165, green: 0.200, blue: 0.239, alpha: 1) // #2A333D
    })

    private static let heroBottom = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.259, green: 0.314, blue: 0.369, alpha: 1)
            : UIColor(red: 0.220, green: 0.275, blue: 0.329, alpha: 1) // #384654
    })

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [heroTop, heroBottom], startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Sıcak Hero Gradyanı (Ana sekme "Rota Planla" kartı)

    static let heroWarmHighlight = Color(red: 0.910, green: 0.573, blue: 0.365) // #E8925D açık turuncu, üst katman
    static let heroWarmTop       = Color(red: 0.851, green: 0.420, blue: 0.212) // #D96B36 canlı yanık turuncu
    static let heroWarmMid       = Color(red: 0.788, green: 0.353, blue: 0.161) // #C95A29 orta ton
    static let heroWarmBottom    = Color(red: 0.659, green: 0.267, blue: 0.102) // #A8441A koyu yanık turuncu, alt uç

    static var heroWarmGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: heroWarmHighlight, location: 0.0),
                .init(color: heroWarmTop,       location: 0.35),
                .init(color: heroWarmMid,       location: 0.68),
                .init(color: heroWarmBottom,    location: 1.0),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    static var nightGradient: LinearGradient {
        LinearGradient(colors: [navy, navyLight], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Buton Stilleri

/// ButtonStyle'ın yaşam döngüsü olmadığı için basma haptic'i bu küçük
/// modifier üzerinden verilir — tüm birincil CTA'lar otomatik kazanır.
private struct HapticPressModifier: ViewModifier {
    let isPressed: Bool

    func body(content: Content) -> some View {
        content.onChange(of: isPressed) { _, pressed in
            if pressed {
                HapticPlayer.impact(.light)
            }
        }
    }
}

struct PinlyPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(PinlyTheme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(PinlyTheme.primary)
            .cornerRadius(14)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .modifier(HapticPressModifier(isPressed: configuration.isPressed))
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
                            .strokeBorder(PinlyTheme.hairline, lineWidth: 1)
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
                .accessibilityHidden(true)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        // VoiceOver'da "1 Mekan" gibi tek okuma; dekoratif ikon SF Symbol adıyla
        // okunacağı için gizlendi (yukarıda).
        .accessibilityElement(children: .combine)
    }
}
