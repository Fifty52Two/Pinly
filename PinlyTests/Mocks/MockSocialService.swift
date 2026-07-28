import Foundation
@testable import Pinly

/// `RouteFeedProviding` + `ProfileSyncing` sahtesi — ağa hiç çıkmaz, davranışı testin
/// ayarladığı `stub*`/`*Result` alanlarından okunur (diğer Mock'ların deseninin devamı).
final class MockSocialService: RouteFeedProviding, ProfileSyncing {
    // MARK: - Stub veriler
    var feedResult: [PublicRouteDTO] = []
    var publishResult: String = "stub-route-id"
    var publishError: Error?
    var myFavoritesResult: [PublicRouteDTO] = []
    var myPublishedRoutesResult: [PublicRouteDTO] = []
    var myProfileResult: SocialProfileDTO?
    var favoriteError: Error?
    var setUsernameError: Error?

    // MARK: - Çağrı sayaçları / son parametreler
    var publishCallCount = 0
    var favoriteCallCount = 0
    var unfavoriteCallCount = 0
    var reportCallCount = 0
    var lastReportReason: ReportReason?
    var lastReportNote: String?
    var blockCallCount = 0
    var lastBlockedUserId: String?
    var setUsernameCallCount = 0
    var lastSetUsername: String?
    var lastFetchFeedCity: String?

    func fetchFeed(city: String, cursor: Date?) async throws -> [PublicRouteDTO] {
        lastFetchFeedCity = city
        return feedResult
    }

    @discardableResult
    func publish(_ route: SavedRoute) async throws -> String {
        publishCallCount += 1
        if let publishError { throw publishError }
        return publishResult
    }

    func favorite(routeId: String) async throws {
        favoriteCallCount += 1
        if let favoriteError { throw favoriteError }
    }

    func unfavorite(routeId: String) async throws {
        unfavoriteCallCount += 1
    }

    func myFavorites() async throws -> [PublicRouteDTO] {
        myFavoritesResult
    }

    func myPublishedRoutes() async throws -> [PublicRouteDTO] {
        myPublishedRoutesResult
    }

    func report(routeId: String, reason: ReportReason, note: String?) async throws {
        reportCallCount += 1
        lastReportReason = reason
        lastReportNote = note
    }

    func block(userId: String) async throws {
        blockCallCount += 1
        lastBlockedUserId = userId
    }

    func myProfile() async throws -> SocialProfileDTO? {
        myProfileResult
    }

    func publicProfile(id: String) async throws -> SocialProfileDTO? {
        myProfileResult
    }

    func setUsername(_ username: String) async throws {
        setUsernameCallCount += 1
        lastSetUsername = username
        if let setUsernameError { throw setUsernameError }
    }
}
