import Foundation
import UIKit

// MARK: - PlacePhotoStoring

/// Mekan fotoğraflarının disk kalıcılığı (`Documents/PlacePhotos/<uuid>.jpg`).
/// `Place.photoFileName` sadece dosya adını taşır; IO tamamen burada.
/// View'lar `@Environment(\.placePhotos)` üzerinden erişir.
protocol PlacePhotoStoring: AnyObject {
    /// Fotoğrafı küçültüp kaydeder, dosya adını döndürür (başarısızsa nil).
    func save(_ image: UIImage) -> String?
    func load(fileName: String) -> UIImage?
    func delete(fileName: String)
}

// MARK: - DefaultPlacePhotoStore

final class DefaultPlacePhotoStore: PlacePhotoStoring {
    static let shared = DefaultPlacePhotoStore()

    private var directory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PlacePhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Fotoğrafı küçültüp JPEG olarak kaydeder (maks. 1200px kenar, 0.8 kalite).
    func save(_ image: UIImage) -> String? {
        let maxSide: CGFloat = 1200
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let newSize = CGSize(width: image.size.width * scale,
                             height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return nil }
        let fileName = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    func load(fileName: String) -> UIImage? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(fileName)) else {
            return nil
        }
        return UIImage(data: data)
    }

    func delete(fileName: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }
}
