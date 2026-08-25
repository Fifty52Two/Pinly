import UIKit
import GoogleMobileAds

/// Interstitial ürün politikasını SDK/presentation kodundan ayırır. Böylece 7 dakika ve
/// oturum başına 2 gösterim sınırı deterministik olarak test edilebilir.
struct InterstitialFrequencyPolicy {
    let minimumInterval: TimeInterval
    let maximumPerSession: Int

    static let v1 = InterstitialFrequencyPolicy(
        minimumInterval: 7 * 60,
        maximumPerSession: 2
    )

    func allowsPresentation(now: Date, lastShownAt: Date?, shownThisSession: Int) -> Bool {
        guard shownThisSession < maximumPerSession else { return false }
        guard let lastShownAt else { return true }
        return now.timeIntervalSince(lastShownAt) >= minimumInterval
    }
}

final class AdManager: NSObject, AdPresenting {
    static let shared = AdManager()

    // DEBUG'da Google'ın resmi test interstitial ID'si kullanılır — kendi cihazında
    // canlı reklamlara tıklayıp/gösterim aldırmak AdMob politikasına aykırı (invalid
    // traffic riski, hesap askıya alınabilir) ve Simulator zaten canlı reklamları
    // güvenilir şekilde yüklemiyor. Gerçek ID sadece Release build'de devrede.
    private static let interstitialAdUnitID: String? = {
        #if DEBUG
        return "ca-app-pub-3940256099942544/4411468910"
        #else
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "PinlyInterstitialAdUnitID") as? String else {
            return nil
        }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
        #endif
    }()

    /// Gösterim sıklığı sınırı. Öncesinde HİÇBİR sınır yoktu: reklam hazırsa her çağrıda
    /// gösteriliyordu, yani art arda iki kullanıcı eylemi iki tam ekran reklam çıkarabiliyordu.
    /// Bunlar AdMob'un teknik kuralı değil, ürün kararı — erken aşamada retention, eCPM'den
    /// çok daha değerli.
    private let entitlements: EntitlementProviding
    private let frequencyPolicy: InterstitialFrequencyPolicy
    private let now: () -> Date
    private var interstitial: InterstitialAd?
    private var onDismissCompletion: (() -> Void)?
    private var lastShownAt: Date?
    private var shownThisSession = 0

    init(
        entitlements: EntitlementProviding = LocalEntitlementService.shared,
        frequencyPolicy: InterstitialFrequencyPolicy = .v1,
        now: @escaping () -> Date = Date.init
    ) {
        self.entitlements = entitlements
        self.frequencyPolicy = frequencyPolicy
        self.now = now
        super.init()
    }

    /// Sıklık sınırı içinde miyiz? (Pro/hazır-değil kontrolü çağıranda ayrıca yapılır.)
    private var isWithinFrequencyCap: Bool {
        frequencyPolicy.allowsPresentation(
            now: now(),
            lastShownAt: lastShownAt,
            shownThisSession: shownThisSession
        )
    }

    /// UMP/ATT rıza akışı tamamlandıktan SONRA çağrılmalı (bkz. `ConsentManager`) —
    /// reklam SDK'sı rıza alınmadan istek atmamalı.
    func beginLoadingAds() {
        guard Self.interstitialAdUnitID != nil else { return }
        loadInterstitial()
    }

    private func loadInterstitial() {
        guard let interstitialAdUnitID = Self.interstitialAdUnitID else { return }
        let request = Request()
        InterstitialAd.load(
            with: interstitialAdUnitID,
            request: request
        ) { [weak self] ad, _ in
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
        }
    }

    // Pro kullanıcılara reklam gösterilmez.
    // Reklam hazır değilse veya Pro ise completion hemen çağrılır.
    func showInterstitialIfNeeded(then completion: @escaping () -> Void) {
        guard !entitlements.isPro, interstitial != nil, isWithinFrequencyCap else {
            completion()
            return
        }
        // Çağıran taraf (rota tamamlandıktan sonra) zaten bir fullScreenCover'ın içinde —
        // yani rootVC'nin kendisi değil, o cover'ın en
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
            self.lastShownAt = self.now()
            self.shownThisSession += 1
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
