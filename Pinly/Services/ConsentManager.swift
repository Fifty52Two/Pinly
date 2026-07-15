import UIKit
import AppTrackingTransparency
import UserMessagingPlatform

/// UMP (Google User Messaging Platform) rıza akışı + App Tracking Transparency izni.
/// AdMob reklam SDK'sı ve interstitial yüklemesi bu akış tamamlanmadan başlamamalı
/// (AEE/UK'de GDPR zorunluluğu, iOS'ta ATT zorunluluğu). Her açılışta çağrılabilir —
/// UMP formu sadece gerektiğinde gösterilir, ATT diyaloğu sadece `.notDetermined` iken çıkar.
/// NOT: Bu SDK sürümünde tipler prefix'siz (eski `UMPConsentInformation` → yeni `ConsentInformation`
/// gibi) ama hâlâ ayrı `UserMessagingPlatform` paketinden geliyor — `GoogleMobileAds` içinde DEĞİL.
final class ConsentManager {
    static let shared = ConsentManager()

    private init() {}

    var canRequestAds: Bool {
        ConsentInformation.shared.canRequestAds
    }

    func requestConsentAndTracking(completion: @escaping () -> Void) {
        let parameters = RequestParameters()
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            guard error == nil else {
                DispatchQueue.main.async { completion() }
                return
            }
            self?.presentFormIfNeeded(completion: completion)
        }
    }

    private func presentFormIfNeeded(completion: @escaping () -> Void) {
        guard let rootViewController = Self.rootViewController() else {
            DispatchQueue.main.async { completion() }
            return
        }
        ConsentForm.loadAndPresentIfRequired(from: rootViewController) { [weak self] _ in
            self?.requestTrackingAuthorization(completion: completion)
        }
    }

    private func requestTrackingAuthorization(completion: @escaping () -> Void) {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            DispatchQueue.main.async { completion() }
            return
        }
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async { completion() }
        }
    }

    private static func rootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        return scene?.windows.first(where: \.isKeyWindow)?.rootViewController
    }
}
