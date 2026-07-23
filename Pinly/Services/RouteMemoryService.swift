import Foundation
import UIKit

// MARK: - RouteMemoryStoring
//
// Rota tamamlama anı fotoğraflarının disk kalıcılığı. Mekan fotoğrafından
// (`PlacePhotoStoring`) BİLİNÇLİ olarak AYRI depo: geçmiş kaydı, mekan silinse
// de bozulmamalı. İki sistem birbirinin dosyasına referans VERMEZ.
// `RouteHistory.memoryPhotosData` (bkz. RouteMemoryPhoto.swift) sadece dosya
// adını taşır; IO tamamen burada. View'lar `@Environment(\.routeMemories)`
// üzerinden erişir.
protocol RouteMemoryStoring: AnyObject {
    /// Fotoğrafı küçültüp `historyID/stopIndex` altına kaydeder, RouteMemories
    /// köküne göre GÖRECELİ dosya adını döner (örn. "<uuid>/0_<uuid>.jpg") —
    /// `load(fileName:)` tek başına bu adla dosyayı bulabilsin diye historyID
    /// dosya adının içine gömülür.
    @discardableResult
    func save(_ image: UIImage, historyID: UUID, stopIndex: Int) throws -> String
    func load(fileName: String) -> UIImage?
    /// Bir RouteHistory kaydına ait TÜM fotoğrafları (klasörü) siler.
    func deleteAll(historyID: UUID)
}

enum RouteMemoryStoreError: Error {
    case encodingFailed
}

// MARK: - DefaultRouteMemoryStore

final class DefaultRouteMemoryStore: RouteMemoryStoring {
    static let shared = DefaultRouteMemoryStore()

    /// `Documents/RouteMemories/` — her RouteHistory kendi `<historyID>/` alt
    /// klasörüne yazar (bkz. `deleteAll(historyID:)` — tek `removeItem` yeter).
    private var rootDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RouteMemories", isDirectory: true)
    }

    private func directory(for historyID: UUID) -> URL {
        rootDirectory.appendingPathComponent(historyID.uuidString, isDirectory: true)
    }

    @discardableResult
    func save(_ image: UIImage, historyID: UUID, stopIndex: Int) throws -> String {
        guard let data = ImageDownscaler.downscaledJPEGData(image) else {
            throw RouteMemoryStoreError.encodingFailed
        }
        let dir = directory(for: historyID)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let relativeName = "\(historyID.uuidString)/\(stopIndex)_\(UUID().uuidString).jpg"
        try data.write(to: rootDirectory.appendingPathComponent(relativeName), options: .atomic)
        return relativeName
    }

    func load(fileName: String) -> UIImage? {
        guard let data = try? Data(contentsOf: rootDirectory.appendingPathComponent(fileName)) else {
            return nil
        }
        return UIImage(data: data)
    }

    func deleteAll(historyID: UUID) {
        try? FileManager.default.removeItem(at: directory(for: historyID))
    }
}
