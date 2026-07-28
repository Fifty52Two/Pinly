import Foundation

// MARK: - PublicRouteDTO

/// Supabase `public_routes` satırının Swift karşılığı. CodingKeys sütun adlarıyla birebir —
/// supabase-swift'in varsayılan encoder/decoder'ı snake_case dönüşümü YAPMAZ (yalnızca ISO8601
/// tarih için özel strateji var), o yüzden anahtarlar burada elle eşlenir.
struct PublicRouteDTO: Codable, Identifiable {
    let id: String
    let owner: String
    var name: String
    var description: String?
    var city: String
    var country: String
    var category: String
    var places: [SavedPlaceSnapshot]
    var centerLat: Double
    var centerLon: Double
    var distanceKm: Double?
    var stopCount: Int
    var favCount: Int
    var isOfficial: Bool
    var status: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, owner, name, description, city, country, category, places, status
        case centerLat = "center_lat"
        case centerLon = "center_lon"
        case distanceKm = "distance_km"
        case stopCount = "stop_count"
        case favCount = "fav_count"
        case isOfficial = "is_official"
        case createdAt = "created_at"
    }
}

/// `public_routes` INSERT payload'ı — fav_count/is_official/status/id/created_at sunucu
/// tarafında varsayılanla dolar; client'ın bunları yazma yetkisi zaten sütun grant'iyle
/// kısıtlı (bkz. specs/FAZ5_SUPABASE_MIMARI.md).
struct PublicRouteInsert: Encodable {
    let owner: String
    let name: String
    let description: String?
    let city: String
    let country: String
    let category: String
    let places: [SavedPlaceSnapshot]
    let centerLat: Double
    let centerLon: Double
    let distanceKm: Double?
    let stopCount: Int

    enum CodingKeys: String, CodingKey {
        case owner, name, description, city, country, category, places
        case centerLat = "center_lat"
        case centerLon = "center_lon"
        case distanceKm = "distance_km"
        case stopCount = "stop_count"
    }
}

// MARK: - SocialProfileDTO

struct SocialProfileDTO: Codable, Identifiable {
    let id: String
    var username: String?
    var displayName: String?
    var isCurator: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
        case isCurator = "is_curator"
        case createdAt = "created_at"
    }
}

// MARK: - ReportReason

enum ReportReason: String, Codable {
    case spam
    case inappropriate
    case wrongInfo = "wrong_info"
    case other
}
