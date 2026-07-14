import SwiftUI

// MARK: - ConfettiView
//
// Rota tamamlama kutlaması için tek seferlik konfeti patlaması.
// Saf SwiftUI (TimelineView + Canvas) — üçüncü parti bağımlılık YOK (bilinçli karar).
// Renkler tema paletinden gelir; yeşil-yasak kuralına doğal olarak uyar.

struct ConfettiView: View {
    private struct Particle {
        let angle: Double        // fırlatma açısı (üst yarıya doğru)
        let speed: Double        // pt/sn
        let size: CGFloat
        let color: Color
        let spin: Double         // rad/sn
        let isCircle: Bool
    }

    private static let palette: [Color] = [
        PinlyTheme.primary, PinlyTheme.primaryWarm,
        PinlyTheme.accent, PinlyTheme.gold, PinlyTheme.slate,
    ]

    private let particles: [Particle] = (0..<80).map { _ in
        Particle(
            angle: .random(in: (-Double.pi * 0.85)...(-Double.pi * 0.15)),
            speed: .random(in: 250...520),
            size: .random(in: 6...11),
            color: palette.randomElement() ?? PinlyTheme.primary,
            spin: .random(in: -6...6),
            isCircle: Bool.random()
        )
    }
    private let start = Date()
    private let duration: Double = 2.0

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            Canvas { ctx, size in
                guard t < duration else { return }
                let origin = CGPoint(x: size.width / 2, y: size.height * 0.42)
                let gravity = 900.0
                let fade = max(0, 1 - (t / duration))
                for p in particles {
                    let x = origin.x + cos(p.angle) * p.speed * t
                    let y = origin.y + sin(p.angle) * p.speed * t + 0.5 * gravity * t * t
                    var layer = ctx
                    layer.opacity = fade
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: .radians(p.spin * t))
                    let box = CGRect(x: -p.size / 2, y: -p.size / 2,
                                     width: p.size, height: p.size * 0.6)
                    let path = p.isCircle ? Path(ellipseIn: box) : Path(box)
                    layer.fill(path, with: .color(p.color))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
