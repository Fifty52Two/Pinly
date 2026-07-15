import Foundation

// MARK: - FeatureFlags

/// Derleme/dağıtım kanalına bağlı davranış anahtarları.
enum FeatureFlags {
    /// Gerçek TestFlight beta build'i mi (Release + sandbox receipt)?
    /// DEBUG'da bilinçli olarak false: geliştirme ve unit testlerde freemium/paywall
    /// davranışı normal çalışmalı. App Store sürümünde de false — receipt adı "receipt".
    static var isTestFlightBuild: Bool {
        #if DEBUG
        return false
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }

    /// TestFlight betasında freemium limiti uygulanmaz, paywall hiç görünmez (FAZ 6.1).
    /// Gerçek satın alma RevenueCat entegrasyonuyla (FAZ 6.4) açılacak;
    /// o zaman bu bayrak kaldırılır veya false'a sabitlenir.
    static var unlimitedPlacesInBeta: Bool { isTestFlightBuild }
}
