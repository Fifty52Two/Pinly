import SwiftUI
// MARK: - SaveRouteSheet

struct SaveRouteSheet: View {
    @Binding var routeName: String
    @Binding var routeCategory: RouteCategory
    let places: [Place]
    let onSave: (String, RouteCategory) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(NSLocalizedString("Rota Bilgileri", comment: ""))) {
                    TextField(NSLocalizedString("Rota Adı", comment: ""), text: $routeName)
                    Picker(NSLocalizedString("Rota Türü", comment: ""), selection: $routeCategory) {
                        ForEach(RouteCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                }
                Section(header: Text(NSLocalizedString("Mekanlar", comment: ""))) {
                    ForEach(places) { place in
                        Label(place.name, systemImage: "mappin")
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Rotayı Kaydet", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("Kaydet", comment: "")) {
                        let name = routeName.trimmingCharacters(in: .whitespaces).isEmpty
                            ? NSLocalizedString("Rota", comment: "")
                            : routeName.trimmingCharacters(in: .whitespaces)
                        onSave(name, routeCategory)
                    }
                    .fontWeight(.semibold)
                    .disabled(routeName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
