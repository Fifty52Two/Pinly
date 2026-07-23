import XCTest
import UIKit
@testable import Pinly

@MainActor
final class MemoryCardComposingTests: XCTestCase {
    private func makeHistory() -> RouteHistory {
        RouteHistory(
            routeName: "Moda Sahili Turu",
            placeNames: ["Moda İskelesi", "Kadıköy Çarşı"],
            totalDistanceMeters: 2400,
            durationSeconds: 1800,
            stepCount: 3200
        )
    }

    private func makeTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 60, height: 60))
        return renderer.image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
        }
    }

    func test_composeStory_mapSnapshotNil_stillProducesNonEmptyImage() {
        let composer = DefaultMemoryCardComposer()
        let image = composer.composeStory(history: makeHistory(), photos: [], mapSnapshot: nil)
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }

    func test_composePost_mapSnapshotNil_stillProducesNonEmptyImage() {
        let composer = DefaultMemoryCardComposer()
        let image = composer.composePost(history: makeHistory(), photos: [], mapSnapshot: nil)
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }

    func test_composeStory_withPhotosAndMap_producesImage() {
        let composer = DefaultMemoryCardComposer()
        let photos = [makeTestImage(), makeTestImage(), makeTestImage()]
        let image = composer.composeStory(history: makeHistory(), photos: photos, mapSnapshot: makeTestImage())
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }
}
