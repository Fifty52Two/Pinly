import Foundation

// MARK: - RouteMemoryPhoto
//
// Rota tamamlama anı fotoğrafı — durak indeksi + isim kopyası (Place silinse de
// günlük kartı ismi göstermeye devam eder; `SavedPlaceSnapshot` deseninin aynısı)
// + `RouteMemoryStoring`'in döndürdüğü dosya adı. `RouteHistory.memoryPhotosData`
// içinde JSON dizisi olarak saklanır (bkz. specs/FAZ3_ANI_GUNLUGU_SPEC.md).

struct RouteMemoryPhoto: Codable, Equatable {
    let stopIndex: Int
    let stopName: String
    let fileName: String
}

// MARK: - RouteHistory + memoryPhotos

extension RouteHistory {
    /// `memoryPhotosData`'yı çözer — eski kayıtlarda (nil) veya bozuk veride boş
    /// dizi döner, asla hata fırlatmaz.
    var memoryPhotos: [RouteMemoryPhoto] {
        guard let data = memoryPhotosData else { return [] }
        return (try? JSONDecoder().decode([RouteMemoryPhoto].self, from: data)) ?? []
    }

    /// Foto dizisini JSON'a serialize edip `memoryPhotosData`'ya yazar. Boş dizi
    /// nil'e normalize edilir — eski kayıt/fotosuz olan ile aynı temsil, ekstra
    /// dallanma gerektirmez.
    func setMemoryPhotos(_ photos: [RouteMemoryPhoto]) {
        memoryPhotosData = photos.isEmpty ? nil : try? JSONEncoder().encode(photos)
    }
}
