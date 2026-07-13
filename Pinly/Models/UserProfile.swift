import Foundation
import UIKit

struct UserProfile: Codable {
    var firstName: String
    var lastName: String
    var birthYear: Int

    private static let key = "pinly.userProfile"

    static func load() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: UserProfile.key)
    }

    var age: Int {
        Calendar.current.component(.year, from: Date()) - birthYear
    }

    var fullName: String { "\(firstName) \(lastName)" }

    var initials: String {
        let f = firstName.first.map(String.init) ?? ""
        let l = lastName.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }

    // MARK: Profil fotoğrafı (Documents/profile_photo.jpg)

    private static var photoURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile_photo.jpg")
    }

    static func loadPhoto() -> UIImage? {
        guard let data = try? Data(contentsOf: photoURL) else { return nil }
        return UIImage(data: data)
    }

    /// Fotoğrafı küçültüp JPEG olarak kaydeder (maks. 800px kenar)
    static func savePhoto(_ image: UIImage) {
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

    static func deletePhoto() {
        try? FileManager.default.removeItem(at: photoURL)
    }
}
