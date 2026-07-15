import UIKit
import GoogleMobileAds

final class AdManager: NSObject, AdPresenting {
    static let shared = AdManager()

    private static let interstitialAdUnitID = "ca-app-pub-7849418614739862/1594342756"

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
        guard !entitlements.isPro,
              let ad = interstitial,
              let windowScene = UIApplication.shared.connectedScenes
                  .compactMap({ $0 as? UIWindowScene })
                  .first(where: { $0.activationState == .foregroundActive })
                  ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController
        else {
            completion()
            return
        }
        onDismissCompletion = completion
        ad.present(from: rootVC)
        interstitial = nil
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
