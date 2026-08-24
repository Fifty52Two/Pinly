import Foundation

// MARK: - PinlyLegal

/// Yasal doküman adreslerinin TEK kaynağı.
///
/// Otomatik yenilenen abonelik satan her paywall'da Gizlilik Politikası ve Kullanım
/// Koşulları bağlantıları fonksiyonel olmak ZORUNDA (App Store Guideline 3.1.2) — aynı
/// adresler App Store Connect'teki uygulama metadata'sına da girilir.
///
/// ⚠️ Yayın öncesi kontrol: `pinly.app` domain'i alınmış ve aşağıdaki iki sayfa GERÇEKTEN
/// yayında olmalı. Ölü bağlantı, bağlantının hiç olmaması kadar kesin ret sebebidir.
enum PinlyLegal {
    static let privacyPolicyURL = URL(string: "https://pinly.app/privacy")
    static let termsOfUseURL    = URL(string: "https://pinly.app/terms")
}
