import UIKit

/// Merkezi haptic yardımcı — tüm UIKit feedback generator'ları tek seferlik
/// oluşturulup (`static let`) `.prepare()` ile önceden hazır tutulur. Her çağrıda
/// yeni bir `UIImpactFeedbackGenerator(...)` allocate etmek (eski ad-hoc desen)
/// Taptic Engine'i soğuk başlatır ve gecikmeye yol açar — bu yüzden tüm haptic
/// tetiklemeleri BURADAN geçmeli, doğrudan `UI*FeedbackGenerator` kullanma.
///
/// Semantik olay haritası (specs/FAZ6_UI_YON.md):
///   durak varışı        → `.success`
///   rozet açılması       → `.success` + 0.1sn sonra `.impact(.rigid)`
///   favorileme (varsa)   → `.impact(.light)`
///   seçim toggle         → `.selection`
///   rota başlatma        → `.impact(.medium)`
///   rota tamamlama       → `.success` + 0.1sn sonra `.impact(.soft)`
enum HapticPlayer {
    private static let notification = UINotificationFeedbackGenerator()
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let impactSoft = UIImpactFeedbackGenerator(style: .soft)

    /// Uygulama açılışında (`PinlyApp.init`) bir kez çağrılır — generator'lar
    /// ilk gerçek haptic'ten önce ısıtılmış olur.
    static func prepareAll() {
        notification.prepare()
        selectionGenerator.prepare()
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        impactRigid.prepare()
        impactSoft.prepare()
    }

    // MARK: - Semantik olaylar (haptic haritası)

    /// Durak varışı.
    static func stopArrival() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    /// Rozet açılması — başarı bildirimi + 0.1sn sonra sert dokunuş.
    static func badgeUnlocked() {
        notification.notificationOccurred(.success)
        notification.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            impactRigid.impactOccurred()
            impactRigid.prepare()
        }
    }

    /// Favorileme / hafif olumlu aksiyon.
    static func favorited() {
        impactLight.impactOccurred()
        impactLight.prepare()
    }

    /// Kategori/mekan seçimi gibi toggle etkileşimleri.
    static func selectionChanged() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    /// Navigasyon/rota başlatma.
    static func routeStarted() {
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }

    /// Rota tamamlama kutlaması (Wow #1'in parçası) — başarı bildirimi + 0.1sn
    /// sonra yumuşak dokunuş. `RouteCompletionOverlay` sekansının son adımında,
    /// hikaye/paylaşım kartı yükselirken çağrılır.
    static func routeCompleted() {
        notification.notificationOccurred(.success)
        notification.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            impactSoft.impactOccurred()
            impactSoft.prepare()
        }
    }

    // MARK: - Genel amaçlı (haritada özel olarak listelenmeyen ama merkezi kalması gereken çağrılar)

    /// Haritada karşılığı olmayan genel başarı bildirimleri (ör. not kaydetme).
    static func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    /// Haritada özel karşılığı olmayan genel dokunuşlar (ör. pin bırakma/onaylama).
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light: impactLight.impactOccurred(); impactLight.prepare()
        case .medium: impactMedium.impactOccurred(); impactMedium.prepare()
        case .heavy: impactHeavy.impactOccurred(); impactHeavy.prepare()
        case .rigid: impactRigid.impactOccurred(); impactRigid.prepare()
        case .soft: impactSoft.impactOccurred(); impactSoft.prepare()
        @unknown default: impactMedium.impactOccurred(); impactMedium.prepare()
        }
    }
}
