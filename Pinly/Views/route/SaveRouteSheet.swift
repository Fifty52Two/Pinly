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
                // Claude Design "Pinly Seigaiha Uygulama" mockup'ındaki (30 · Rota kaydet)
                // dolu sage pin rozeti — Form'un üstüne, sistem large-title yerine.
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(PinlyTheme.success)
                                    .frame(width: 56, height: 56)
                                    .shadow(color: PinlyTheme.success.opacity(0.3), radius: 8, y: 4)
                                Image(systemName: "mappin")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text(NSLocalizedString("Rotayı Kaydet", comment: ""))
                                .font(.headline)
                                .fontWeight(.heavy)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

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
            .scrollContentBackground(.hidden)
            .background(PinlyTheme.groundGradient)
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
