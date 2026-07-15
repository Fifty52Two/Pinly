import XCTest
import UIKit
@testable import Pinly

final class PlacePhotoServiceTests: XCTestCase {
    private func makeTestImage(size: CGSize = CGSize(width: 40, height: 40)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    func test_save_returnsFileNameAndPersistsLoadableImage() {
        let store = DefaultPlacePhotoStore()
        let image = makeTestImage()

        guard let fileName = store.save(image) else {
            XCTFail("save nil döndürmemeli")
            return
        }

        XCTAssertTrue(fileName.hasSuffix(".jpg"))
        let loaded = store.load(fileName: fileName)
        XCTAssertNotNil(loaded)

        store.delete(fileName: fileName)
    }

    func test_load_returnsNil_forUnknownFileName() {
        let store = DefaultPlacePhotoStore()
        XCTAssertNil(store.load(fileName: "olmayan-dosya-\(UUID()).jpg"))
    }

    func test_delete_removesFile_subsequentLoadReturnsNil() {
        let store = DefaultPlacePhotoStore()
        let image = makeTestImage()
        guard let fileName = store.save(image) else {
            XCTFail("save nil döndürmemeli")
            return
        }

        store.delete(fileName: fileName)
        XCTAssertNil(store.load(fileName: fileName))
    }

    /// Büyük görsel 1200px uzun kenarı aşmamalı (maksimum küçültme kuralı).
    func test_save_downscalesLargeImage() {
        let store = DefaultPlacePhotoStore()
        let large = makeTestImage(size: CGSize(width: 3000, height: 1500))

        guard let fileName = store.save(large), let loaded = store.load(fileName: fileName) else {
            XCTFail("save/load başarısız olmamalı")
            return
        }

        XCTAssertLessThanOrEqual(max(loaded.size.width, loaded.size.height), 1200)
        store.delete(fileName: fileName)
    }
}
