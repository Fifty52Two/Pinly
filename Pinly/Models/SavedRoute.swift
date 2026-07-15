import Foundation
import SwiftData

// MARK: - SavedPlaceSnapshot

struct SavedPlaceSnapshot: Codable {
    let name: String
    let category: String
    let address: String
    let notes: String
    let latitude: Double
    let longitude: Double
    let sortIndex: Int
    /// Kaynak Place'in kimliği — isimle eşleşme kırılganlığının kalıcı çözümü (FAZ 5.2).
    /// Eski kayıtlarda ve dışarıdan gelen rotalarda nil; o zaman isimle eşleşmeye düşülür.
    var placeId: UUID? = nil
}

// MARK: - SavedRoute Model

@Model
class SavedRoute {
    @Attribute(.unique) var id: UUID
    var name: String
    var categoryRaw: String?          // RouteCategory rawValue
    var createdAt: Date
    var centerLatitude: Double        // Rota merkezi — uzaklık uyarısı için
    var centerLongitude: Double
    var orderedPlaceSnapshotsData: Data   // [SavedPlaceSnapshot] JSON
    var isPublic: Bool                // Sosyal faz için hazır
    var supabaseId: String?           // Sosyal faz için

    var placeSnapshots: [SavedPlaceSnapshot] {
        (try? JSONDecoder().decode([SavedPlaceSnapshot].self, from: orderedPlaceSnapshotsData)) ?? []
    }

    var placeCount: Int {
        placeSnapshots.count
    }

    var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        fmt.locale = Locale.current
        return fmt.string(from: createdAt)
    }

    init(
        name: String,
        categoryRaw: String? = nil,
        createdAt: Date = .now,
        centerLatitude: Double,
        centerLongitude: Double,
        snapshots: [SavedPlaceSnapshot],
        isPublic: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.categoryRaw = categoryRaw
        self.createdAt = createdAt
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.orderedPlaceSnapshotsData = (try? JSONEncoder().encode(snapshots)) ?? Data()
        self.isPublic = isPublic
        self.supabaseId = nil
    }
}
