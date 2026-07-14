import Foundation

// MARK: - ReviewPromptDeciding

/// App Store değerlendirme isteminin eşik mantığı.
///
/// Kural: en az 2 tamamlanmış rota + bu sürümde daha önce istenmemiş olma.
/// Neden: ilk rotada istemek erken (kullanıcı henüz değeri tatmadı);
/// sürüm başına tek istem Apple'ın requestReview politikasına saygılıdır.
/// Gerçek istem SwiftUI'ın `@Environment(\.requestReview)`'ı ile yapılır —
/// bu servis yalnızca "istenmeli mi" kararını verir (test edilebilir).
protocol ReviewPromptDeciding: AnyObject {
    func recordRouteCompletion()
    func shouldPromptForReview(currentVersion: String) -> Bool
    func markPrompted(version: String)
}

// MARK: - DefaultReviewPromptService

final class DefaultReviewPromptService: ReviewPromptDeciding {
    static let shared = DefaultReviewPromptService()

    private let completedCountKey = "pinly.review.completedRouteCount"
    private let lastPromptedVersionKey = "pinly.review.lastPromptedVersion"
    private let minimumCompletions = 2

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func recordRouteCompletion() {
        defaults.set(defaults.integer(forKey: completedCountKey) + 1, forKey: completedCountKey)
    }

    func shouldPromptForReview(currentVersion: String) -> Bool {
        guard defaults.integer(forKey: completedCountKey) >= minimumCompletions else { return false }
        return defaults.string(forKey: lastPromptedVersionKey) != currentVersion
    }

    func markPrompted(version: String) {
        defaults.set(version, forKey: lastPromptedVersionKey)
    }
}
