import XCTest
import UIKit
@testable import Pinly

final class RouteMemoryServiceTests: XCTestCase {
    private func makeTestImage(size: CGSize = CGSize(width: 40, height: 40)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    func test_save_returnsFileNameAndPersistsLoadableImage() throws {
        let store = DefaultRouteMemoryStore()
        let historyID = UUID()
        let image = makeTestImage()

        let fileName = try store.save(image, historyID: historyID, stopIndex: 0)

        XCTAssertTrue(fileName.hasPrefix(historyID.uuidString))
        XCTAssertTrue(fileName.hasSuffix(".jpg"))
        XCTAssertNotNil(store.load(fileName: fileName))

        store.deleteAll(historyID: historyID)
    }

    func test_load_returnsNil_forUnknownFileName() {
        let store = DefaultRouteMemoryStore()
        XCTAssertNil(store.load(fileName: "\(UUID().uuidString)/0_olmayan.jpg"))
    }

    func test_deleteAll_removesEntireHistoryFolder() throws {
        let store = DefaultRouteMemoryStore()
        let historyID = UUID()
        let image = makeTestImage()

        let file1 = try store.save(image, historyID: historyID, stopIndex: 0)
        let file2 = try store.save(image, historyID: historyID, stopIndex: 1)
        XCTAssertNotNil(store.load(fileName: file1))
        XCTAssertNotNil(store.load(fileName: file2))

        store.deleteAll(historyID: historyID)

        XCTAssertNil(store.load(fileName: file1))
        XCTAssertNil(store.load(fileName: file2))
    }

    func test_deleteAll_doesNotAffectOtherHistoryFolders() throws {
        let store = DefaultRouteMemoryStore()
        let historyA = UUID()
        let historyB = UUID()
        let image = makeTestImage()

        let fileA = try store.save(image, historyID: historyA, stopIndex: 0)
        let fileB = try store.save(image, historyID: historyB, stopIndex: 0)

        store.deleteAll(historyID: historyA)

        XCTAssertNil(store.load(fileName: fileA))
        XCTAssertNotNil(store.load(fileName: fileB))

        store.deleteAll(historyID: historyB)
    }

    /// Büyük görsel 1200px uzun kenarı aşmamalı — PlacePhotoStore ile paylaşılan
    /// `ImageDownscaler` sabitleri burada da geçerli.
    func test_save_downscalesLargeImage() throws {
        let store = DefaultRouteMemoryStore()
        let historyID = UUID()
        let large = makeTestImage(size: CGSize(width: 3000, height: 1500))

        let fileName = try store.save(large, historyID: historyID, stopIndex: 0)
        guard let loaded = store.load(fileName: fileName) else {
            XCTFail("load başarısız olmamalı")
            return
        }

        XCTAssertLessThanOrEqual(max(loaded.size.width, loaded.size.height), 1200)
        store.deleteAll(historyID: historyID)
    }
}
