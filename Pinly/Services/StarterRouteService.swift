import Foundation

// MARK: - StarterRoute Modelleri

struct StarterRoutePlace: Codable {
    let name: String
    let category: String
    let address: String
    let latitude: Double
    let longitude: Double
}

struct StarterRouteDefinition: Codable, Identifiable {
    var id: String { name }
    let name: String
    let routeCategory: String
    let places: [StarterRoutePlace]
}

// MARK: - StarterRoutesProviding

/// Bundle'a gömülü hazır rotaların tek kaynağı — boş uygulama problemi için.
protocol StarterRoutesProviding {
    func loadAll() -> [StarterRouteDefinition]
    func makeSavedRoute(from definition: StarterRouteDefinition) -> SavedRoute
}

struct DefaultStarterRoutesProvider: StarterRoutesProviding {
    func loadAll() -> [StarterRouteDefinition] {
        guard let url = Bundle.main.url(forResource: "StarterRoutes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let defs = try? JSONDecoder().decode([StarterRouteDefinition].self, from: data)
        else { return [] }
        return defs
    }

    func makeSavedRoute(from definition: StarterRouteDefinition) -> SavedRoute {
        let snapshots = definition.places.enumerated().map { index, place in
            SavedPlaceSnapshot(
                name: place.name,
                category: place.category,
                address: place.address,
                notes: "",
                latitude: place.latitude,
                longitude: place.longitude,
                sortIndex: index
            )
        }
        let count = Double(max(definition.places.count, 1))
        return SavedRoute(
            name: definition.name,
            categoryRaw: definition.routeCategory,
            centerLatitude: definition.places.map(\.latitude).reduce(0, +) / count,
            centerLongitude: definition.places.map(\.longitude).reduce(0, +) / count,
            snapshots: snapshots
        )
    }
}
