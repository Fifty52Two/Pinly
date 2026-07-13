import Foundation

struct UserProfile: Codable {
    var firstName: String
    var lastName: String
    var birthYear: Int

    var age: Int {
        Calendar.current.component(.year, from: Date()) - birthYear
    }

    var fullName: String { "\(firstName) \(lastName)" }

    var initials: String {
        let f = firstName.first.map(String.init) ?? ""
        let l = lastName.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }
}
