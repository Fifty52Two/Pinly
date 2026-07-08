import Foundation

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
}
