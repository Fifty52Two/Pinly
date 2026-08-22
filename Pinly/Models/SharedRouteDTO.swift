import Foundation

// MARK: - SharedRouteDTO

/// Supabase `shared_routes` satırının Swift karşılığı — iki kişinin BİRLİKTE, gerçek zamanlı
/// düzenlediği rota. `PublicRouteDTO` deseniyle aynı: CodingKeys sütun adlarıyla birebir.
struct SharedRouteDTO: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var category: String
    var places: [SavedPlaceSnapshot]
    let owner: String
    var collaborator: String?
    var updatedBy: String?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, category, places, owner, collaborator
        case updatedBy = "updated_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SharedRouteInsert: Encodable {
    let name: String
    let category: String
    let places: [SavedPlaceSnapshot]
    let owner: String
    let updatedBy: String

    enum CodingKeys: String, CodingKey {
        case name, category, places, owner
        case updatedBy = "updated_by"
    }
}

/// Yalnızca yeri/isim/kategori değişebildiği için PATCH payload'ı ayrı — `owner`/`collaborator`
/// asla client'tan yazılmaz (owner INSERT'te sabitlenir, collaborator SADECE `join_shared_route`
/// RPC'siyle değişir).
struct SharedRouteUpdate: Encodable {
    var name: String?
    var places: [SavedPlaceSnapshot]?
    let updatedBy: String

    enum CodingKeys: String, CodingKey {
        case name, places
        case updatedBy = "updated_by"
    }
}
