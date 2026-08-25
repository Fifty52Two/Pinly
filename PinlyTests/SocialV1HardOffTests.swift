import XCTest
@testable import Pinly

final class SocialV1HardOffTests: XCTestCase {
    func test_v1PolicyAlwaysResolvesNoOpServices() {
        XCTAssertFalse(SocialFeaturePolicy.isEnabledInV1)
        XCTAssertTrue(SocialFeaturePolicy.socialService is NoOpSocialService)
        XCTAssertTrue(SocialFeaturePolicy.sharedRouteService is NoOpSharedRouteService)
    }

    func test_socialReadsAreEmptyAndDoNotCreateSession() async throws {
        let service = NoOpSocialService.shared
        let feed = try await service.fetchFeed(city: "istanbul", cursor: nil)
        let favorites = try await service.myFavorites()
        let publishedRoutes = try await service.myPublishedRoutes()
        let profile = try await service.myProfile()

        XCTAssertFalse(service.hasLocalSession)
        XCTAssertTrue(feed.isEmpty)
        XCTAssertTrue(favorites.isEmpty)
        XCTAssertTrue(publishedRoutes.isEmpty)
        XCTAssertNil(profile)
    }

    func test_socialMutationFailsClosed() async {
        do {
            try await NoOpSocialService.shared.setUsername("gezgin")
            XCTFail("V1 sosyal mutasyonu başarılı görünmemeli")
        } catch SocialServiceError.disabled {
            // Beklenen fail-closed davranış.
        } catch {
            XCTFail("Beklenmeyen hata: \(error)")
        }
    }

    func test_sharedRouteNoOpSubscriptionDoesNotInitializeSupabase() {
        let subscription = NoOpSharedRouteService.shared.subscribe(id: "disabled") { _ in
            XCTFail("NoOp abonelik callback çağırmamalı")
        }
        subscription.cancel()
    }

    func test_sharedRouteMutationFailsClosed() async {
        do {
            _ = try await NoOpSharedRouteService.shared.create(name: "Kapalı", category: "city", places: [])
            XCTFail("V1 ortak rota mutasyonu başarılı görünmemeli")
        } catch SocialServiceError.disabled {
            // Beklenen fail-closed davranış.
        } catch {
            XCTFail("Beklenmeyen hata: \(error)")
        }
    }
}
