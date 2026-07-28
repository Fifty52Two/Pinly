import XCTest
@testable import Pinly

@MainActor
final class CommunityFeedViewModelTests: XCTestCase {
    private func makeRoute(id: String = "r1", owner: String = "owner1", favCount: Int = 3) -> PublicRouteDTO {
        PublicRouteDTO(
            id: id, owner: owner, name: "Test Rota", description: nil,
            city: "istanbul", country: "tr", category: "Şehir İçi", places: [],
            centerLat: 41.0, centerLon: 29.0, distanceKm: 2.5, stopCount: 4,
            favCount: favCount, isOfficial: false, status: "active", createdAt: .now
        )
    }

    func test_loadInitial_populatesRoutesAndFavorites() async {
        let social = MockSocialService()
        let route = makeRoute()
        social.feedResult = [route]
        social.myFavoritesResult = [route]
        let vm = CommunityFeedViewModel(social: social)

        await vm.loadInitial(city: "istanbul")

        XCTAssertEqual(vm.routes.count, 1)
        XCTAssertEqual(social.lastFetchFeedCity, "istanbul")
        XCTAssertTrue(vm.favoritedRouteIds.contains(route.id))
        XCTAssertNil(vm.errorMessage)
    }

    func test_loadInitial_emptyCity_doesNothing() async {
        let social = MockSocialService()
        let vm = CommunityFeedViewModel(social: social)

        await vm.loadInitial(city: "")

        XCTAssertNil(social.lastFetchFeedCity)
        XCTAssertTrue(vm.routes.isEmpty)
    }

    func test_loadInitial_networkError_setsErrorMessage() async {
        struct DummyError: Error {}
        final class ThrowingSocial: RouteFeedProviding, ProfileSyncing {
            var hasLocalSession: Bool { true }
            func fetchFeed(city: String, cursor: Date?) async throws -> [PublicRouteDTO] { throw DummyError() }
            func publish(_ route: SavedRoute) async throws -> String { "" }
            func favorite(routeId: String) async throws {}
            func unfavorite(routeId: String) async throws {}
            func myFavorites() async throws -> [PublicRouteDTO] { [] }
            func myPublishedRoutes() async throws -> [PublicRouteDTO] { [] }
            func report(routeId: String, reason: ReportReason, note: String?) async throws {}
            func block(userId: String) async throws {}
            func myProfile() async throws -> SocialProfileDTO? { nil }
            func publicProfile(id: String) async throws -> SocialProfileDTO? { nil }
            func setUsername(_ username: String) async throws {}
        }
        let vm = CommunityFeedViewModel(social: ThrowingSocial())

        await vm.loadInitial(city: "istanbul")

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.routes.isEmpty)
    }

    func test_performToggleFavorite_addsFavoriteAndIncrementsCount() async {
        let social = MockSocialService()
        let route = makeRoute(favCount: 3)
        social.feedResult = [route]
        let vm = CommunityFeedViewModel(social: social)
        await vm.loadInitial(city: "istanbul")

        await vm.performToggleFavorite(route)

        XCTAssertTrue(vm.favoritedRouteIds.contains(route.id))
        XCTAssertEqual(vm.routes.first?.favCount, 4)
        XCTAssertEqual(social.favoriteCallCount, 1)
    }

    func test_performToggleFavorite_removesFavoriteAndDecrementsCount_whenAlreadyFavorited() async {
        let social = MockSocialService()
        let route = makeRoute(favCount: 3)
        social.feedResult = [route]
        social.myFavoritesResult = [route]
        let vm = CommunityFeedViewModel(social: social)
        await vm.loadInitial(city: "istanbul")
        XCTAssertTrue(vm.favoritedRouteIds.contains(route.id))

        await vm.performToggleFavorite(route)

        XCTAssertFalse(vm.favoritedRouteIds.contains(route.id))
        XCTAssertEqual(vm.routes.first?.favCount, 2)
        XCTAssertEqual(social.unfavoriteCallCount, 1)
    }

    func test_toggleFavoriteAsync_withoutUsername_showsSetupAndDoesNotCallFavorite() async {
        let social = MockSocialService()
        social.myProfileResult = nil
        let route = makeRoute()
        social.feedResult = [route]
        let vm = CommunityFeedViewModel(social: social)
        await vm.loadInitial(city: "istanbul")

        await vm.toggleFavoriteAsync(route)

        XCTAssertTrue(vm.showUsernameSetup)
        XCTAssertEqual(social.favoriteCallCount, 0)
    }

    func test_block_hidesRouteFromVisibleRoutes() async {
        let social = MockSocialService()
        let route = makeRoute(owner: "spammer")
        social.feedResult = [route]
        let vm = CommunityFeedViewModel(social: social)
        await vm.loadInitial(city: "istanbul")
        XCTAssertEqual(vm.visibleRoutes.count, 1)

        await vm.block(userId: "spammer")

        XCTAssertTrue(vm.visibleRoutes.isEmpty)
        XCTAssertEqual(social.blockCallCount, 1)
        XCTAssertEqual(social.lastBlockedUserId, "spammer")
    }

    func test_loadMoreIfNeeded_appendsWhenCurrentItemIsLast() async {
        let social = MockSocialService()
        let first = makeRoute(id: "r1")
        social.feedResult = [first]
        let vm = CommunityFeedViewModel(social: social)
        await vm.loadInitial(city: "istanbul")
        vm.hasMore = true // testte tek sayfalık feed <20 döner, sayfalamayı zorla aç

        let second = makeRoute(id: "r2")
        social.feedResult = [second]
        await vm.loadMoreIfNeeded(currentItem: first)

        XCTAssertEqual(vm.routes.map(\.id), ["r1", "r2"])
    }

    func test_loadMoreIfNeeded_doesNothing_whenCurrentItemIsNotLast() async {
        let social = MockSocialService()
        let first = makeRoute(id: "r1")
        let second = makeRoute(id: "r2")
        social.feedResult = [first, second]
        let vm = CommunityFeedViewModel(social: social)
        await vm.loadInitial(city: "istanbul")
        vm.hasMore = true

        social.feedResult = [makeRoute(id: "r3")]
        await vm.loadMoreIfNeeded(currentItem: first)

        XCTAssertEqual(vm.routes.map(\.id), ["r1", "r2"])
    }
}
