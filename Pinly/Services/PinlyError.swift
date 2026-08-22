import Foundation

/// Uygulama genelinde kullanilan hata tipleri.
/// View katmaninda `localizedDescription` ile kullaniciya gosterilebilir,
/// analytics'te event olarak izlenebilir.
enum PinlyError: LocalizedError {
    // Geocode
    case geocodeFailed(query: String)
    case reverseGeocodeFailed

    // Rota
    case routeCalculationFailed
    case noRoutablePlaces

    // Import/Export
    case importPayloadTooLarge
    case importInvalidFormat
    case exportFailed

    // Network
    case networkUnavailable
    case serverError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .geocodeFailed(let query):
            return String(format: NSLocalizedString("'%@' adresi bulunamadi.", comment: ""), query)
        case .reverseGeocodeFailed:
            return NSLocalizedString("Konum adresi cozumlenemedi.", comment: "")
        case .routeCalculationFailed:
            return NSLocalizedString("Rota hesaplanamadi. Lutfen internet baglantinizi kontrol edin.", comment: "")
        case .noRoutablePlaces:
            return NSLocalizedString("Rotaya eklenebilecek koordinatli mekan bulunamadi.", comment: "")
        case .importPayloadTooLarge:
            return NSLocalizedString("Icerik cok buyuk, lutfen daha kisa bir rota deneyin.", comment: "")
        case .importInvalidFormat:
            return NSLocalizedString("Gecersiz format — dosya okunamadi.", comment: "")
        case .exportFailed:
            return NSLocalizedString("Dosya olusturulamadi.", comment: "")
        case .networkUnavailable:
            return NSLocalizedString("Internet baglantisi bulunamadi.", comment: "")
        case .serverError:
            return NSLocalizedString("Sunucu hatasi olustu. Lutfen tekrar deneyin.", comment: "")
        }
    }
}
