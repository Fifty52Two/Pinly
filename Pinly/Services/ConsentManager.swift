import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

enum AdAudienceCategory: Equatable {
    case unknown
    case child
    case teen
    case adult
}

enum AdAudiencePolicy {
    /// EEA ülkelerinde dijital rıza yaşı ülkeye göre 13–16 arasında değişebilir.
    /// Ülke bilgisini güvenilir biçimde tutmadığımız için 16'yı korumacı üst sınır alıyoruz.
    static func category(profile: UserProfile?, currentYear: Int = Calendar.current.component(.year, from: Date())) -> AdAudienceCategory {
        guard let profile else { return .unknown }
        let age = currentYear - profile.birthYear
        guard age >= 0 else { return .unknown }
        if age < 13 { return .child }
        if age < 16 { return .teen }
        return .adult
    }
}

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

    func requestConsentAndTracking(audience: AdAudienceCategory, completion: @escaping () -> Void) {
        configureAdRequest(for: audience)
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = audience == .child || audience == .teen
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            guard error == nil else {
                DispatchQueue.main.async { completion() }
                return
            }
            self?.presentFormIfNeeded(audience: audience, completion: completion)
        }
    }

    /// Uygun bölgelerde Google'ın reklam gizlilik seçeneklerini yeniden açar. Formun gerekli
    /// olmadığı bölgelerde SDK hata döndürebilir; kullanıcıya anlaşılır mesajı çağıran gösterir.
    func presentPrivacyOptions(completion: @escaping (Error?) -> Void) {
        guard let rootViewController = Self.rootViewController() else {
            completion(ConsentManagerError.presenterUnavailable)
            return
        }
        ConsentForm.presentPrivacyOptionsForm(from: rootViewController) { error in
            DispatchQueue.main.async { completion(error) }
        }
    }

    private func presentFormIfNeeded(audience: AdAudienceCategory, completion: @escaping () -> Void) {
        guard let rootViewController = Self.rootViewController() else {
            DispatchQueue.main.async { completion() }
            return
        }
        ConsentForm.loadAndPresentIfRequired(from: rootViewController) { [weak self] _ in
            self?.requestTrackingAuthorization(audience: audience, completion: completion)
        }
    }

    private func requestTrackingAuthorization(audience: AdAudienceCategory, completion: @escaping () -> Void) {
        // Çocuk/ergen kullanıcı için kişiselleştirilmiş reklam ve IDFA yolu kapalıdır.
        guard audience != .child, audience != .teen else {
            DispatchQueue.main.async { completion() }
            return
        }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            DispatchQueue.main.async { completion() }
            return
        }
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async { completion() }
        }
    }

    private func configureAdRequest(for audience: AdAudienceCategory) {
        let configuration = MobileAds.shared.requestConfiguration
        configuration.maxAdContentRating = GADMaxAdContentRating.general
        switch audience {
        case .child:
            configuration.tagForChildDirectedTreatment = true
            configuration.tagForUnderAgeOfConsent = nil
        case .teen:
            configuration.tagForChildDirectedTreatment = nil
            configuration.tagForUnderAgeOfConsent = true
        case .adult:
            configuration.tagForChildDirectedTreatment = false
            configuration.tagForUnderAgeOfConsent = false
        case .unknown:
            configuration.tagForChildDirectedTreatment = nil
            configuration.tagForUnderAgeOfConsent = nil
        }
    }

    private static func rootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        return scene?.windows.first(where: \.isKeyWindow)?.rootViewController
    }
}

enum ConsentManagerError: LocalizedError {
    case presenterUnavailable

    var errorDescription: String? {
        NSLocalizedString("Gizlilik seçenekleri şu anda açılamıyor. Lütfen tekrar dene.", comment: "")
    }
}
