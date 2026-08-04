import SwiftUI

// MARK: - Pinly Gooey Tab Bar
//
// Yüzen "gooey" tab bar: stadyum biçimli koyu bar, seçili sekmenin altında
// akışkan bir Bezier çukuru; seçili ikon barın içinden yukarı, yüzen
// baloncuğa fırlar (dikey offset + spring). Çukur pozisyonu animatableData
// ile sürülür — sekme değişince çukur, baloncuk ve ikonlar birlikte
// yaylanarak kayar (sıvı yüzey gerilimi hissi).

struct PinlyTabItem {
    let icon: String   // outline ikon — hem barda hem baloncukta kullanılır
    let title: String  // erişilebilirlik etiketi
}

struct PinlyTabBar: View {
    @Binding var selection: Int
    let items: [PinlyTabItem]

    // MARK: Palet — tek yerden değiştir
    // Bar açık renk (light'ta beyaz, dark'ta zeminden bir ton açık slate) —
    // zeminle aynılaşmasın diye koyu navy'den vazgeçildi (kullanıcı kararı)
    private var barColor: Color { PinlyTheme.surface }
    // Claude Design "Pinly Seigaiha Uygulama" mockup'ındaki (17 · Ana sekme) sabit
    // navy baloncuk — primary'nin aksine mod bağımsız, HER modda koyu kalır (CLAUDE.md
    // "navy... tab bar... sabit" kararıyla birebir). İkon de onunla eşleşen sabit krem.
    private var bubbleColor: Color { PinlyTheme.navy }
    private var haloColor: Color { PinlyTheme.ground }
    private var activeIconColor: Color { PinlyTheme.cream }
    private var inactiveIconColor: Color { Color.primary.opacity(0.45) }

    // MARK: Geometri
    private let barHeight: CGFloat = 55
    private let circleSize: CGFloat = 46
    private let haloWidth: CGFloat = 1       // baloncuğun hemen etrafındaki zemin renkli halka
    private let gapClearance: CGFloat = 4   // baloncuk (halo dahil) ile çukur duvarı arası boşluk
    private let circleCenterY: CGFloat = 8   // bar üst kenarına göre baloncuk merkezi (büyüdükçe gömülür)
    private let notchHalfWidth: CGFloat = 47 // çukurun üst kenardaki yarı genişliği
    /// Slotlar bar kenarlarından bu kadar içeriden dağıtılır
    private let edgeInset: CGFloat = 50

    // Çukurun ortası baloncuğu bu yarıçapla saran gerçek bir daire yayı —
    // ikonun etrafından eşit boşlukla süzülür, asla değmez
    private var scoopRadius: CGFloat { circleSize / 2 + haloWidth + gapClearance }

    // MARK: Animasyon — düşük sürtünmeli, hafif sekmeli yay
    private let gooeySpring = Animation.spring(response: 0.42, dampingFraction: 0.7)

    private var stadiumRadius: CGFloat { barHeight / 2 }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let slotWidth = (w - edgeInset * 2) / CGFloat(items.count)
            let slotCenter = edgeInset + slotWidth * (CGFloat(selection) + 0.5)
            // Çukur stadyum uçlarına taşmasın; baloncuk da çukurla hizalı kalsın
            let notchX = min(max(slotCenter, stadiumRadius + notchHalfWidth),
                             w - stadiumRadius - notchHalfWidth)

            ZStack {
                GooeyTabBarShape(
                    notchCenterX: notchX,
                    notchHalfWidth: notchHalfWidth,
                    scoopRadius: scoopRadius,
                    scoopCenterY: circleCenterY,
                    cornerRadius: stadiumRadius
                )
                .fill(.ultraThinMaterial)
                .overlay(
                    GooeyTabBarShape(
                        notchCenterX: notchX,
                        notchHalfWidth: notchHalfWidth,
                        scoopRadius: scoopRadius,
                        scoopCenterY: circleCenterY,
                        cornerRadius: stadiumRadius
                    )
                    .fill(barColor.opacity(0.72))
                )
                .overlay(
                    // Dark mode'da zeminle ayrışsın diye ince kontur
                    GooeyTabBarShape(
                        notchCenterX: notchX,
                        notchHalfWidth: notchHalfWidth,
                        scoopRadius: scoopRadius,
                        scoopCenterY: circleCenterY,
                        cornerRadius: stadiumRadius
                    )
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

                // Yüzen baloncuk (halo + disk) — ikonların ALTINDA, yatayda kayar
                ZStack {
                    Circle()
                        .fill(haloColor)
                        .frame(width: circleSize + haloWidth * 2,
                               height: circleSize + haloWidth * 2)
                    Circle()
                        .fill(bubbleColor)
                        .frame(width: circleSize, height: circleSize)
                }
                .position(x: notchX, y: circleCenterY)
                .allowsHitTesting(false)

                // İkon sırası — seçili ikon dikeyde baloncuğun içine yükselir,
                // eski seçili ikon bara geri düşer (spring)
                HStack(spacing: 0) {
                    ForEach(items.indices, id: \.self) { index in
                        let isSelected = index == selection
                        Button {
                            select(index)
                        } label: {
                            Image(systemName: items[index].icon)
                                .font(.system(size: 20, weight: isSelected ? .semibold : .medium))
                                .foregroundColor(isSelected ? activeIconColor : inactiveIconColor)
                                .offset(y: isSelected ? -(barHeight / 2 - circleCenterY) : 0)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(items[index].title)
                        .accessibilityAddTraits(index == selection ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, edgeInset)
            }
        }
        .frame(height: barHeight)
        // Üst kenara yumuşak geçiş — içerik bara sert kesilmeden, bulanıklaşarak ulaşır
        .background(
            LinearGradient(colors: [.clear, barColor.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                .frame(height: 22)
                .frame(maxHeight: .infinity, alignment: .top)
                .offset(y: -22)
                .allowsHitTesting(false)
        )
        // Yüzen baloncuk bar'ın üst kenarından ~16pt taşıyor (circleCenterY - circleSize/2);
        // bu taşma barHeight'a dahil değil, safeAreaInset onu rezerve etmez — üstteki
        // içerik baloncuğun altında kalıp örtülebilir. Bu boşluk o taşmayı telafi eder.
        .padding(.top, 16)
        // Sabit/opak dock bar: kenar boşluğu yok, home indicator bölgesine kadar
        // bulanık malzemeyle devam eder — içerik asla altına sızamaz (kullanıcı kararı,
        // "yüzen" tasarımdan vazgeçildi), alt kısım da (home indicator) aynı blur ile bitişik.
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(barColor.opacity(0.72))
            }
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func select(_ index: Int) {
        guard index != selection else { return }
        HapticPlayer.selectionChanged()
        withAnimation(gooeySpring) {
            selection = index
        }
    }
}

// MARK: - Gooey Bar Şekli
//
// Stadyum (tam yuvarlak uçlu) bar + baloncuğu saran çukur: ortası gerçek
// bir daire yayı (baloncuğun konturunu eşit boşlukla takip eder — V değil O),
// kenarlara teğet uyumlu quad eğrilerle akışkan biçimde bağlanır.

struct GooeyTabBarShape: Shape {
    var notchCenterX: CGFloat
    var notchHalfWidth: CGFloat = 47
    var scoopRadius: CGFloat = 31
    /// Sarılan dairenin (baloncuğun) merkezi — bar üst kenarına göre
    var scoopCenterY: CGFloat = 3
    var cornerRadius: CGFloat = 30

    var animatableData: CGFloat {
        get { notchCenterX }
        set { notchCenterX = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let r = min(cornerRadius, h / 2)
        let hw = notchHalfWidth
        let R = scoopRadius
        let cy = scoopCenterY
        // Çukur stadyum uçlarına taşmasın
        let cx = min(max(notchCenterX, r + hw), w - r - hw)

        // Yay, dairenin alt (180-2θ)°'lik bölümünü sarar; üstteki θ°'lik
        // kısımlar quad dudaklara bırakılır. θ küçüldükçe sarma artar.
        let lipDeg: CGFloat = 30
        let aStartDeg = 180 - lipDeg   // sol duvar
        let aEndDeg   = lipDeg         // sağ duvar

        func rad(_ deg: CGFloat) -> CGFloat { deg * .pi / 180 }
        let arcStart = CGPoint(x: cx + R * cos(rad(aStartDeg)), y: cy + R * sin(rad(aStartDeg)))
        let arcEnd   = CGPoint(x: cx + R * cos(rad(aEndDeg)),   y: cy + R * sin(rad(aEndDeg)))
        // Dudak kontrol noktaları: yayın giriş/çıkış teğetinin y=0 ile kesişimi —
        // düz kenardan yaya kırılmasız (G1) geçiş
        let tanShift = 1 / tan(rad(90 - lipDeg))  // teğet doğrusunun y başına x kayması
        let ctrlL = CGPoint(x: arcStart.x - arcStart.y * tanShift, y: 0)
        let ctrlR = CGPoint(x: arcEnd.x + arcEnd.y * tanShift, y: 0)

        var p = Path()
        p.move(to: CGPoint(x: r, y: 0))

        // Çukura kadar üst kenar + sol dudak (teğet uyumlu)
        p.addLine(to: CGPoint(x: cx - hw, y: 0))
        p.addQuadCurve(to: arcStart, control: ctrlL)

        // Baloncuğu saran yay: sol duvar → taban → sağ duvar
        p.addArc(
            center: CGPoint(x: cx, y: cy),
            radius: R,
            startAngle: .degrees(Double(aStartDeg)),
            endAngle: .degrees(Double(aEndDeg)),
            clockwise: true
        )

        // Sağ dudak
        p.addQuadCurve(to: CGPoint(x: cx + hw, y: 0), control: ctrlR)

        // Kalan üst kenar + sadece üst köşeler yuvarlak (sabit/opak dock bar —
        // alt köşeler ekran kenarına yapışık, düz)
        p.addLine(to: CGPoint(x: w - r, y: 0))
        p.addArc(center: CGPoint(x: w - r, y: r), radius: r,
                 startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addArc(center: CGPoint(x: r, y: r), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selection = 1
        var body: some View {
            VStack {
                Spacer()
                PinlyTabBar(selection: $selection, items: [
                    PinlyTabItem(icon: "house", title: "Ana"),
                    PinlyTabItem(icon: "square.grid.2x2", title: "Keşfet"),
                    PinlyTabItem(icon: "map", title: "Rotalar"),
                    PinlyTabItem(icon: "ellipsis.circle", title: "Daha Fazla"),
                ])
            }
            .background(PinlyTheme.groundGradient)
        }
    }
    return PreviewWrapper()
}
