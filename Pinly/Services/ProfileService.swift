import Foundation
import UIKit

// MARK: - ProfileProviding

/// Kullanıcı profili (ad/soyad/doğum yılı) + profil fotoğrafı kalıcılığının tek kaynağı.
/// View'lar `@Environment(\.profile)` üzerinden erişir.
protocol ProfileProviding: AnyObject {
    func load() -> UserProfile?
    func save(_ profile: UserProfile)
    func loadPhoto() -> UIImage?
    func savePhoto(_ image: UIImage)
    func deletePhoto()
}

// MARK: - DefaultProfileService

/// UserDefaults (`pinly.userProfile`) + Documents/profile_photo.jpg tabanlı yerel implementasyon.
final class DefaultProfileService: ProfileProviding {
    static let shared = DefaultProfileService()

    private let key = "pinly.userProfile"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> UserProfile? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    func save(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
    }

    // MARK: Profil fotoğrafı (Documents/profile_photo.jpg)

    private var photoURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile_photo.jpg")
    }

    func loadPhoto() -> UIImage? {
        guard let data = try? Data(contentsOf: photoURL) else { return nil }
        return UIImage(data: data)
    }

    /// Fotoğrafı küçültüp JPEG olarak kaydeder (maks. 800px kenar)
    func savePhoto(_ image: UIImage) {
        let maxSide: CGFloat = 800
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let newSize = CGSize(width: image.size.width * scale,
                             height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        guard let data = resized.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: photoURL, options: .atomic)
    }

    func deletePhoto() {
        try? FileManager.default.removeItem(at: photoURL)
    }
}
