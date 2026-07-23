import SwiftUI
import SwiftData
import CoreLocation

// MARK: - FirstRouteSetupView
//
// FAZ 4 "İlk 30 Saniye": onboarding + konum izni verildikten SONRA, HomeView ilk kez
// boş bir mekan listesiyle açıldığında bir KERELİK gösterilen tam ekran akış. Konum
// izni burada İSTENMEZ (zaten PermissionView'de verilmiş olması gereken bir noktada
// sunulur) — sadece `LocationManager`'ın zaten yayınladığı `currentCity`/`userLocation`
// değerlerini okur ve bir öneri (şehir kataloğu ya da Yakınımda fallback) üretir.
//
// Sunan taraf (`HomeView`) tek seferlik `pinly.firstRouteFlowShown` bayrağını bu view
// kapandığında (kabul ya da atla, farketmez) yakar.

struct FirstRouteSetupView: View {
    let onRouteReady: (SavedRoute) -> Void
    let onSkip: () -> Void

    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = FirstRouteSetupViewModel()

    var body: some View {
        ZStack {
            PinlyTheme.groundGradient
                .ignoresSafeArea()

            WavePattern(waveLength: 90, amplitude: 12, rowSpacing: 22)
                .stroke(PinlyTheme.slate.opacity(0.08), lineWidth: 1)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 32)

                header

                Spacer(minLength: 24)

                content
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 24)

                actions
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
            }
        }
        .task {
            await waitForLocationThenLoad()
        }
    }

    // MARK: - Üst başlık

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PinlyTheme.primary.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(PinlyTheme.primary)
            }
            Text(NSLocalizedString("İlk Rotanı 30 Saniyede Kur", comment: ""))
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - İçerik (yükleniyor / öneri / boş durum)

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            VStack(spacing: 14) {
                ProgressView()
                Text(NSLocalizedString("Çevrendeki en iyi rotayı hazırlıyoruz…", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        } else {
            switch viewModel.suggestion {
            case .cityCatalog(let entry):
                cityCatalogCard(entry)
            case .nearby(let places):
                nearbyCard(places)
            case .none:
                emptyState
            }
        }
    }

    private func cityCatalogCard(_ entry: RouteCatalogEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(NSLocalizedString("Senin İçin Hazır Rota", comment: ""), systemImage: "map.fill")
                .font(.caption.weight(.semibold))
                .foregroundColor(PinlyTheme.primary)

            Text(entry.name.localized(for: languageManager.currentLanguage))
                .font(.title3.bold())

            Text(entry.description.localized(for: languageManager.currentLanguage))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider().padding(.vertical, 2)

            Text(entry.places.prefix(4).map(\.name).joined(separator: " → ")
                 + (entry.places.count > 4 ? " +\(entry.places.count - 4)" : ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Label(
                String(format: NSLocalizedString("%lld mekan", comment: ""), entry.places.count),
                systemImage: "mappin.circle.fill"
            )
            .font(.caption.weight(.semibold))
            .foregroundColor(PinlyTheme.slate)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(PinlyTheme.surface))
        .padding(.horizontal, 28)
    }

    private func nearbyCard(_ places: [NearbyPlace]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(NSLocalizedString("Çevrende Keşfedilecekler", comment: ""), systemImage: "location.fill")
                .font(.caption.weight(.semibold))
                .foregroundColor(PinlyTheme.primary)

            ForEach(places.prefix(5)) { place in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(place.category.color.opacity(0.14))
                            .frame(width: 30, height: 30)
                        Image(systemName: place.category.icon)
                            .font(.caption2)
                            .foregroundColor(place.category.color)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(place.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(place.formattedDistance)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(PinlyTheme.surface))
        .padding(.horizontal, 28)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "map")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text(NSLocalizedString(
                "Çevrende henüz hazır bir rota bulamadık. Mekanlarını istediğin zaman kendin ekleyebilirsin.",
                comment: ""
            ))
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Aksiyonlar

    @ViewBuilder
    private var actions: some View {
        if !viewModel.isLoading, viewModel.suggestion != .none {
            Button {
                adoptSuggestion()
            } label: {
                Text(NSLocalizedString("Bu Rotayla Başla", comment: ""))
            }
            .buttonStyle(PinlyPrimaryButtonStyle())

            Button(NSLocalizedString("Şimdi Değil", comment: ""), action: onSkip)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 12)
        } else {
            Button(NSLocalizedString("Şimdi Değil", comment: ""), action: onSkip)
                .buttonStyle(PinlySecondaryButtonStyle())
        }
    }

    private func adoptSuggestion() {
        switch viewModel.suggestion {
        case .cityCatalog(let entry):
            let route = viewModel.adoptCityRoute(entry, languageCode: languageManager.currentLanguage, context: modelContext)
            onRouteReady(route)
        case .nearby(let places):
            let route = viewModel.adoptNearbyPlaces(places, context: modelContext)
            onRouteReady(route)
        case .none:
            onSkip()
        }
    }

    // MARK: - Konum bekleme

    /// İzin onaylandıktan hemen sonra `userLocation`/`currentCity` genelde birkaç saniye
    /// içinde gelir (LocationManager `requestLocation()` + reverse geocode zinciri) — bu
    /// view'ı KENDİ izin isteği YAPMADAN, yalnızca zaten akan bu veriyi kısa bir süre bekler.
    /// Süre dolarsa elindeki neyse onunla (yalnızca koordinat, şehir boş) devam eder.
    private func waitForLocationThenLoad() async {
        for _ in 0..<10 {
            if locationManager.userLocation != nil { break }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        if locationManager.currentCity.isEmpty {
            try? await Task.sleep(nanoseconds: 700_000_000)
        }
        await viewModel.load(
            cityRaw: locationManager.currentCity,
            coordinate: locationManager.userLocation?.coordinate
        )
    }
}
