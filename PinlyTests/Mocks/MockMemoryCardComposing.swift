import Foundation
import UIKit
@testable import Pinly

final class MockMemoryCardComposing: MemoryCardComposing {
    var composeStoryCallCount = 0
    var composePostCallCount = 0
    var lastPhotos: [UIImage] = []
    var lastMapSnapshot: UIImage?
    var imageToReturn = UIImage()

    func composeStory(history: RouteHistory, photos: [UIImage], mapSnapshot: UIImage?) -> UIImage {
        composeStoryCallCount += 1
        lastPhotos = photos
        lastMapSnapshot = mapSnapshot
        return imageToReturn
    }

    func composePost(history: RouteHistory, photos: [UIImage], mapSnapshot: UIImage?) -> UIImage {
        composePostCallCount += 1
        lastPhotos = photos
        lastMapSnapshot = mapSnapshot
        return imageToReturn
    }
}
