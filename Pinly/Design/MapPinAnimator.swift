import UIKit

// MARK: - MapPinAnimator
//
// Harita pin'lerinde kullanılan paylaşılan CALayer animasyonları (specs/FAZ6_UI_YON.md
// Wow #3-4). `NavigationMapView`'in "sonraki durak" pulse'ı ile `MapView`'in yeni pin
// drop + seçili pin nefes animasyonu AYNI mekanizmadan (bu dosya) geçer — kopyala-yapıştır
// yerine tek kaynak. Reduce Motion açıksa çağıran taraf animasyonu hiç tetiklememeli
// (`UIAccessibility.isReduceMotionEnabled` kontrolü çağrı noktasında yapılır).

enum MapPinAnimator {
    /// Yeni eklenen bir pin için 0→1.1→1 "pop" spring animasyonu.
    static func popIn(_ view: UIView) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let anim = CAKeyframeAnimation(keyPath: "transform.scale")
        anim.values = [0.01, 1.1, 1.0]
        anim.keyTimes = [0, 0.65, 1.0]
        anim.duration = 0.42
        anim.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
        ]
        view.layer.add(anim, forKey: "pinly.popIn")
    }

    /// Seçili/aktif pin için sürekli "nefes alma" (1.0↔1.06, 2sn, repeat).
    /// Reduce Motion açıksa hiç eklenmez (statik kalır).
    static func addBreathing(to view: UIView, key: String = "pinly.breathing") {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let anim = CABasicAnimation(keyPath: "transform.scale")
        anim.fromValue = 1.0
        anim.toValue = 1.06
        anim.duration = 2.0
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        view.layer.add(anim, forKey: key)
    }

    static func removeBreathing(from view: UIView, key: String = "pinly.breathing") {
        view.layer.removeAnimation(forKey: key)
    }

    /// Halka tabanlı "pulse" grubu — NavigationMapView'in sonraki durak göstergesi
    /// bunu kullanır; renk çağıran taraftan verilir. Reduce Motion açıksa nil döner
    /// (çağıran taraf halkayı hiç görünür yapmamalı).
    static func ringPulseAnimationGroup() -> CAAnimationGroup? {
        guard !UIAccessibility.isReduceMotionEnabled else { return nil }
        let scaleAnim = CAKeyframeAnimation(keyPath: "transform.scale")
        scaleAnim.values = [0.5, 1.2, 1.0]
        scaleAnim.keyTimes = [0, 0.7, 1.0]

        let opacityAnim = CAKeyframeAnimation(keyPath: "opacity")
        opacityAnim.values = [0.8, 0.3, 0.0]
        opacityAnim.keyTimes = [0, 0.7, 1.0]

        let group = CAAnimationGroup()
        group.animations = [scaleAnim, opacityAnim]
        group.duration = 1.5
        group.repeatCount = .infinity
        return group
    }
}
