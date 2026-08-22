import UIKit
import GoogleMobileAds

final class AdManager: NSObject, AdPresenting {
    static let shared = AdManager()

    // DEBUG'da Google'ın resmi test interstitial ID'si kullanılır — kendi cihazında
    // canlı reklamlara tıklayıp/gösterim aldırmak AdMob politikasına aykırı (invalid
    // traffic riski, hesap askıya alınabilir) ve Simulator zaten canlı reklamları
    // güvenilir şekilde yüklemiyor. Gerçek ID sadece Release build'de devrede.
    private static let interstitialAdUnitID: String = {
        #if DEBUG
        return "ca-app-pub-3940256099942544/4411468910"
        #else
        return "ca-app-pub-7849418614739862/1594342756"
        #endif
    }()

    private let entitlements: EntitlementProviding
    private var interstitial: InterstitialAd?
    private var onDismissCompletion: (() -> Void)?

    init(entitlements: EntitlementProviding = LocalEntitlementService.shared) {
        self.entitlements = entitlements
        super.init()
    }

    /// UMP/ATT rıza akışı tamamlandıktan SONRA çağrılmalı (bkz. `ConsentManager`) —
    /// reklam SDK'sı rıza alınmadan istek atmamalı.
    func beginLoadingAds() {
        loadInterstitial()
    }

    private func loadInterstitial() {
        let request = Request()
        InterstitialAd.load(
            with: Self.interstitialAdUnitID,
            request: request
        ) { [weak self] ad, _ in
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
        }
    }

    // Pro kullanıcılara reklam gösterilmez.
    // Reklam hazır değilse veya Pro ise completion hemen çağrılır.
    func showInterstitialIfNeeded(then completion: @escaping () -> Void) {
        guard !entitlements.isPro, interstitial != nil else {
            completion()
            return
        }
        // Çağıran taraflar (RouteSummaryView içindeki "Rotayı Kaydet"/"Navigasyonu Başlat")
        // ZATEN bir fullScreenCover'ın İÇİNDE — yani rootVC'nin kendisi değil, o cover'ın en
        // ÜSTTEKİ (varsa üstüne binmiş sheet/alert dahil) view controller'ı sunucu olmalı.
        // Önceki sürüm `rootVC.presentedViewController == nil` kontrolü yapıyordu; bu HER ZAMAN
        // false dönüyordu (RouteSummaryView zaten sunulu olduğu için) ve reklam asla gösterilmiyordu.
        // Ayrıca bir önceki sheet/alert'in kapanma animasyonu henüz bitmemiş olabileceğinden
        // (ör. Kaydet başarı alert'i kapanırken hemen Başlat'a basılması) kısa bir gecikme veriyoruz.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, let ad = self.interstitial, let presenter = Self.topMostViewController() else {
                completion()
                return
            }
            self.onDismissCompletion = completion
            ad.present(from: presenter)
            self.interstitial = nil
        }
    }

    /// Şu an ekranda gerçekten en üstte olan view controller — varsa iç içe geçmiş
    /// fullScreenCover/sheet zincirinin sonuna kadar iner.
    private static func topMostViewController() -> UIViewController? {
        guard
            let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
            var top = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController
        else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

extension AdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        onDismissCompletion?()
        onDismissCompletion = nil
        loadInterstitial() // sonraki gösterim için önceden yükle
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        onDismissCompletion?()
        onDismissCompletion = nil
        loadInterstitial()
    }
}
