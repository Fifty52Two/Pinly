import Foundation
import UIKit
@testable import Pinly

final class MockRouteMemoryStoring: RouteMemoryStoring {
    var savedFiles: [String: UIImage] = [:]
    var saveCallCount = 0
    var deleteAllCallCount = 0
    var deletedHistoryIDs: [UUID] = []
    var shouldThrowOnSave = false

    func save(_ image: UIImage, historyID: UUID, stopIndex: Int) throws -> String {
        saveCallCount += 1
        if shouldThrowOnSave { throw RouteMemoryStoreError.encodingFailed }
        let fileName = "\(historyID.uuidString)/\(stopIndex)_\(UUID().uuidString).jpg"
        savedFiles[fileName] = image
        return fileName
    }

    func load(fileName: String) -> UIImage? {
        savedFiles[fileName]
    }

    func deleteAll(historyID: UUID) {
        deleteAllCallCount += 1
        deletedHistoryIDs.append(historyID)
        savedFiles = savedFiles.filter { !$0.key.hasPrefix(historyID.uuidString) }
    }
}
