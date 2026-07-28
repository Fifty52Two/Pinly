import SwiftUI

// MARK: - WavePattern
//
// Yuvarlanan dalga çizgileri deseni (ukiyo-e dalga illüstrasyonundan esinli) —
// dekoratif zemin aksanı. Vektör tabanlı (Shape), raster/SVG YOK — bilinçli
// karar (bkz. CLAUDE.md commit 5a8e291: illüstrasyon seti kaldırılmıştı, stil
// tutarsızlığı + clipping). Statik, animasyonsuz. Renk/opaklık çağıran
// taraftan .fill/.stroke ile verilir. TÜM kullanım noktalarında (onboarding,
// hero kart, boş durumlar, ana sayfa zemini) aynı desen — tek kaynak.

struct WavePattern: Shape {
    var waveLength: CGFloat = 70
    var amplitude: CGFloat = 11
    var rowSpacing: CGFloat = 20
    // Yatay kayma — sadece onboarding'in canlı varyantı (bkz. OnboardingWavePattern)
    // bunu sıfırdan farklı verir; diğer tüm statik kullanımlar varsayılan 0'da kalır.
    var phase: CGFloat = 0

    // Shape'in path'i her karede yeniden hesaplanabildiği için `.animation` ile
    // `phase` değişimi SwiftUI tarafından enterpole edilir (bkz. OnboardingWavePattern).
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var row = 0
        var y: CGFloat = amplitude
        let drift = phase.truncatingRemainder(dividingBy: waveLength)
        while y < rect.height + amplitude {
            let rowOffset = row.isMultiple(of: 2) ? CGFloat(0) : waveLength / 2
            var x = -waveLength + rowOffset + drift
            path.move(to: CGPoint(x: x, y: y))
            while x < rect.width + waveLength {
                let nextX = x + waveLength
                path.addCurve(
                    to: CGPoint(x: nextX, y: y),
                    control1: CGPoint(x: x + waveLength * 0.25, y: y - amplitude),
                    control2: CGPoint(x: x + waveLength * 0.75, y: y + amplitude)
                )
                x = nextX
            }
            y += rowSpacing
            row += 1
        }
        return path
    }
}

// MARK: - OnboardingWavePattern
//
// WavePattern'in TEK canlı dalgalanan kullanım noktası (Wow #6, GROWTH_PLAN FAZ 6) —
// sadece OnboardingView. Diğer tüm kullanım yerleri (RouteShareCard, SavedRoutesView/
// RouteHistoryView/StatusViews boş durumları, MainTab) WavePattern'i doğrudan statik
// kullanmaya devam eder, buna DOKUNULMADI. TimelineView `.periodic(from:by:)` body'yi
// saniyede bir kez tetikler — aradaki yumuşak kayma `.animation(.linear)` ile Shape'in
// `animatableData`'sı üzerinden enterpole edilir (Core Animation tabanlı path
// interpolasyonu; SwiftUI body'si 60 fps'te yeniden çalışmaz, sadece path). Reduce
// Motion açıksa TimelineView hiç kurulmaz, statik `WavePattern`e düşülür (bkz.
// Pinly/Design/MapPinAnimator.swift ve NavigationTransitions.swift'teki aynı desen).
struct OnboardingWavePattern: View {
    var waveLength: CGFloat = 90
    var amplitude: CGFloat = 12
    var rowSpacing: CGFloat = 22
    var color: Color
    var opacity: Double
    var lineWidth: CGFloat = 1

    /// px/sn — yavaş ve zarif bir kayma (dikkat dağıtmasın diye düşük tutuldu).
    private let driftSpeed: CGFloat = 5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            WavePattern(waveLength: waveLength, amplitude: amplitude, rowSpacing: rowSpacing)
                .stroke(color.opacity(opacity), lineWidth: lineWidth)
        } else {
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let tick = Int(elapsed)
                WavePattern(
                    waveLength: waveLength,
                    amplitude: amplitude,
                    rowSpacing: rowSpacing,
                    phase: CGFloat(elapsed) * driftSpeed
                )
                .stroke(color.opacity(opacity), lineWidth: lineWidth)
                .animation(.linear(duration: 1.0), value: tick)
            }
        }
    }
}

// MARK: - SeigaihaPattern
//
// İç içe yarım daire (seigaiha) deseni — tuğla dizilimiyle tekrarlanan
// tam halkalar, kenarlarda doğal biçimde kırpılır (bir tiling desenin
// beklenen davranışı). Ana sayfa gibi geniş zeminlerde WavyHorizonMask
// ile birlikte kullanılır (bkz. görsel referans: sage desen + krem kıyı).

struct SeigaihaPattern: Shape {
    var radius: CGFloat = 22
    var ringCount: Int = 4
    var ringSpacing: CGFloat = 5

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = radius * 1.6
        let rowHeight = radius * 0.85

        var row = 0
        var y = -radius
        while y < rect.height + radius {
            let xOffset = row.isMultiple(of: 2) ? 0 : step / 2
            var x = -radius + xOffset
            while x < rect.width + radius {
                for i in 0..<ringCount {
                    let r = radius - CGFloat(i) * ringSpacing
                    guard r > 2 else { continue }
                    path.addArc(center: CGPoint(x: x, y: y), radius: r,
                                startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                }
                x += step
            }
            y += rowHeight
            row += 1
        }
        return path
    }
}

// MARK: - WavyHorizonMask
//
// Düzensiz, elle çizilmiş hissi veren dalgalı bir sınır çizgisi — bu çizginin
// ALTINDA kalan bölgeyi döndürür. WavePattern'i düz dikdörtgen bir şerit yerine
// doğal/kıvrımlı bir kıyı çizgisiyle sınırlamak için .clipShape ile kullanılır.

struct WavyHorizonMask: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h * 0.15))
        p.addCurve(to: CGPoint(x: w * 0.35, y: h * 0.45),
                   control1: CGPoint(x: w * 0.12, y: h * 0.42),
                   control2: CGPoint(x: w * 0.22, y: h * 0.50))
        p.addCurve(to: CGPoint(x: w * 0.62, y: h * 0.30),
                   control1: CGPoint(x: w * 0.45, y: h * 0.38),
                   control2: CGPoint(x: w * 0.52, y: h * 0.22))
        p.addCurve(to: CGPoint(x: w * 0.85, y: h * 0.72),
                   control1: CGPoint(x: w * 0.72, y: h * 0.42),
                   control2: CGPoint(x: w * 0.78, y: h * 0.68))
        p.addCurve(to: CGPoint(x: w, y: h * 0.62),
                   control1: CGPoint(x: w * 0.90, y: h * 0.78),
                   control2: CGPoint(x: w * 0.95, y: h * 0.58))
        p.addLine(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
        return p
    }
}
