import Foundation
import UIKit
@testable import Pinly

final class MockPlacePhotoStoring: PlacePhotoStoring {
    var savedImages: [String: UIImage] = [:]
    var saveCallCount = 0
    var shouldFailSave = false

    func save(_ image: UIImage) -> String? {
        saveCallCount += 1
        if shouldFailSave { return nil }
        let fileName = "\(UUID().uuidString).jpg"
        savedImages[fileName] = image
        return fileName
    }

    func load(fileName: String) -> UIImage? {
        savedImages[fileName]
    }

    func delete(fileName: String) {
        savedImages.removeValue(forKey: fileName)
    }
}
