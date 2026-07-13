import UIKit
import GoogleMobileAds

// TODO: Yayına geçerken test ID'lerini gerçek ID'lerle değiştir:
// App ID     → Info.plist GADApplicationIdentifier
// Ad Unit ID → AdManager.interstitialAdUnitID

final class AdManager: NSObject, AdPresenting {
    static let shared = AdManager()

    // Test ID — gerçek ID: "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
    private static let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"

    private let entitlements: EntitlementProviding
    private var interstitial: InterstitialAd?
    private var onDismissCompletion: (() -> Void)?

    init(entitlements: EntitlementProviding = LocalEntitlementService.shared) {
        self.entitlements = entitlements
        super.init()
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
        loadInterstitial() // sonraki gösterim için önceden yükle
    }
}

extension AdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        onDismissCompletion?()
        onDismissCompletion = nil
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        onDismissCompletion?()
        onDismissCompletion = nil
        loadInterstitial()
    }
}
