import XCTest
@testable import Pinly

final class RouteMemoryPhotoTests: XCTestCase {
    private func makeHistory(memoryPhotosData: Data? = nil) -> RouteHistory {
        RouteHistory(
            routeName: "Kadıköy Turu",
            placeNames: ["Moda", "Bahariye"],
            totalDistanceMeters: 1200,
            durationSeconds: 900,
            stepCount: 1500,
            memoryPhotosData: memoryPhotosData
        )
    }

    func test_memoryPhotos_oldRecordWithNilData_returnsEmptyArray() {
        let history = makeHistory(memoryPhotosData: nil)
        XCTAssertEqual(history.memoryPhotos, [])
    }

    func test_setMemoryPhotos_thenRead_roundTrips() {
        let history = makeHistory()
        let photos = [
            RouteMemoryPhoto(stopIndex: 0, stopName: "Moda", fileName: "a.jpg"),
            RouteMemoryPhoto(stopIndex: 1, stopName: "Bahariye", fileName: "b.jpg"),
        ]

        history.setMemoryPhotos(photos)

        XCTAssertNotNil(history.memoryPhotosData)
        XCTAssertEqual(history.memoryPhotos, photos)
    }

    func test_setMemoryPhotos_emptyArray_normalizesToNilData() {
        let history = makeHistory()
        history.setMemoryPhotos([RouteMemoryPhoto(stopIndex: 0, stopName: "Moda", fileName: "a.jpg")])
        XCTAssertNotNil(history.memoryPhotosData)

        history.setMemoryPhotos([])

        XCTAssertNil(history.memoryPhotosData)
        XCTAssertEqual(history.memoryPhotos, [])
    }

    func test_memoryPhotos_corruptData_returnsEmptyArrayInsteadOfCrashing() {
        let history = makeHistory(memoryPhotosData: "not json".data(using: .utf8))
        XCTAssertEqual(history.memoryPhotos, [])
    }
}
