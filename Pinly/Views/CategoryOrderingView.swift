import SwiftUI

struct CategoryOrderingView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @Environment(\.dismissRouteFlow) var dismissRouteFlow

    @State private var goToPicker = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(NSLocalizedString("Sırayı belirle", comment: ""))
                    .font(.title2)
                    .fontWeight(.bold)
                Text(NSLocalizedString("Hangi sırayla gitmek istiyorsun?", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 8)

            Text(NSLocalizedString("Sürükleyerek sırala", comment: ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)

            List {
                // Claude Design "Pinly Seigaiha Uygulama" mockup'ındaki (35 · Kategori
                // sırala) kart satırı — sol tutamaç + dolu renkli kare ikon + isim
                // (birebir); sıra numarası mockup'ta yok ama erişilebilirlik için
                // korunuyor (küçük, ikincil).
                ForEach(Array(routeManager.selectedCategories.enumerated()), id: \.element) { index, category in
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.6))

                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(color(for: category))
                                .frame(width: 28, height: 28)
                            Image(systemName: icon(for: category))
                                .font(.caption)
                                .foregroundColor(.white)
                        }

                        Text(category)
                            .font(.body)
                            .fontWeight(.semibold)

                        Spacer()

                        Text("\(index + 1)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(PinlyTheme.surface)
                }
                .onMove { from, to in
                    routeManager.selectedCategories.move(fromOffsets: from, toOffset: to)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))

            Button {
                goToPicker = true
            } label: {
                HStack {
                    Text(NSLocalizedString("Mekan Seçimine Geç", comment: ""))
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(PinlyTheme.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(PinlyTheme.primary)
                .cornerRadius(14)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .background(PinlyTheme.groundGradient)
        .navigationTitle(NSLocalizedString("Sıralama", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    routeManager.reset()
                    dismissRouteFlow()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .accessibilityLabel(NSLocalizedString("Kapat", comment: ""))
            }
        }
        .navigationDestination(isPresented: $goToPicker) {
            PlacePickerStepView(stepIndex: 0)
                .environmentObject(placeStore)
                .environmentObject(locationManager)
                .environmentObject(routeManager)
        }
    }

    func icon(for category: String) -> String { PlaceCategory.from(category).icon }
    func color(for category: String) -> Color { PlaceCategory.from(category).color }
}
