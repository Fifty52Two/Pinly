import Foundation

// MARK: - AdPresenting

/// Interstitial reklam sunumunun protokolü.
/// Call site'lar `@Environment(\.ads)` üzerinden bu protokole bağımlıdır;
/// somut implementasyon `AdManager`'dır (AdMob).
protocol AdPresenting: AnyObject {
    /// Pro kullanıcıya veya reklam hazır değilse completion hemen çağrılır.
    func showInterstitialIfNeeded(then completion: @escaping () -> Void)
}
