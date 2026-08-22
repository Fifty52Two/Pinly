import SwiftUI

// MARK: - CommunityFeedView
//
// FAZ 5 V2: şehre göre topluluk rotaları feed'i. DiscoverView'ın "Topluluk Rotaları" mini
// şeridindeki "Tümünü Gör"den sheet olarak açılır (bkz. DiscoverView.communitySection) —
// var olan "Yakınımda → NearbyPlacesView" desenin aynısı. Varsayılan şehir
// `LocationManager.currentCity`; kullanıcı üstteki alandan başka bir şehir de arayabilir
// (ör. gitmeyi planladığı bir şehrin rotalarına önceden göz atmak için).
struct CommunityFeedView: View {
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var viewModel = CommunityFeedViewModel()

    @State private var cityInput = ""
    @State private var reportTargetId: String?
    @State private var blockCandidate: PublicRouteDTO?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                citySearchField

                Group {
                    if viewModel.isLoading && viewModel.routes.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.errorMessage, viewModel.routes.isEmpty {
                        errorState(error)
                    } else if viewModel.visibleRoutes.isEmpty {
                        emptyState
                    } else {
                        feedList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(PinlyTheme.groundGradient)
            .navigationTitle(NSLocalizedString("Topluluk Rotaları", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $viewModel.showUsernameSetup) {
            UsernameSetupSheet {
                viewModel.usernameSetupSucceeded()
            }
        }
        .sheet(isPresented: showReportSheetBinding) {
            if let routeId = reportTargetId {
                ReportRouteSheet(routeId: routeId)
            }
        }
        .alert(
            NSLocalizedString("Kullanıcıyı Engelle", comment: ""),
            isPresented: Binding(get: { blockCandidate != nil }, set: { if !$0 { blockCandidate = nil } })
        ) {
            Button(NSLocalizedString("Engelle", comment: ""), role: .destructive) {
                if let candidate = blockCandidate {
                    Task { await viewModel.block(userId: candidate.owner) }
                }
                blockCandidate = nil
            }
            Button(NSLocalizedString("İptal", comment: ""), role: .cancel) { blockCandidate = nil }
        } message: {
            Text(NSLocalizedString("Bu kullanıcının rotaları artık feed'inde görünmeyecek.", comment: ""))
        }
        .task {
            cityInput = locationManager.currentCity
            await viewModel.loadInitial(city: locationManager.currentCity)
        }
    }

    private var showReportSheetBinding: Binding<Bool> {
        Binding(get: { reportTargetId != nil }, set: { if !$0 { reportTargetId = nil } })
    }

    // MARK: - Şehir arama

    private var citySearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(NSLocalizedString("Şehir ara (ör. istanbul)", comment: ""), text: $cityInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit {
                    Task { await viewModel.loadInitial(city: cityInput) }
                }
            if viewModel.isLoading {
                ProgressView().controlSize(.small)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(PinlyTheme.fillMuted))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Liste

    private var feedList: some View {
        List {
            ForEach(viewModel.visibleRoutes) { route in
                CommunityRouteCard(
                    route: route,
                    isFavorited: viewModel.favoritedRouteIds.contains(route.id),
                    onToggleFavorite: { viewModel.toggleFavorite(route) },
                    onReport: { reportTargetId = route.id },
                    onBlock: { blockCandidate = route }
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .task {
                    await viewModel.loadMoreIfNeeded(currentItem: route)
                }
            }
            if viewModel.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.loadInitial(city: cityInput.isEmpty ? locationManager.currentCity : cityInput)
        }
    }

    // MARK: - Boş / hata durumları

    private var emptyState: some View {
        VStack(spacing: 14) {
            EmptyStateMedallion(icon: "person.3.sequence.fill", badgeColor: PinlyTheme.slate)
            Text(NSLocalizedString("Bu şehirde henüz paylaşılan rota yok", comment: ""))
                .font(.headline)
            Text(NSLocalizedString("İlk paylaşan sen ol — kayıtlı rotalarından birini topluluğa aç.", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(NSLocalizedString("Tekrar Dene", comment: "")) {
                Task { await viewModel.loadInitial(city: cityInput.isEmpty ? locationManager.currentCity : cityInput) }
            }
            .buttonStyle(PinlySecondaryButtonStyle())
            .padding(.horizontal, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - CommunityRouteCard

private struct CommunityRouteCard: View {
    let route: PublicRouteDTO
    let isFavorited: Bool
    let onToggleFavorite: () -> Void
    let onReport: () -> Void
    let onBlock: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var categoryIcon: String {
        RouteCategory(rawValue: route.category)?.icon ?? "map.fill"
    }

    var body: some View {
        // Claude Design "Pinly Seigaiha Uygulama" mockup'ındaki (16 · Topluluk akışı)
        // her kartın üstündeki sage + seigaiha dokulu, kart kenarlarına tam oturan
        // banner — mevcut içerik (isim/açıklama/mekanlar/favoriler) korunuyor,
        // sadece üste eklendi.
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                PinlyTheme.slate
                GeometryReader { geo in
                    Image(PinlyTheme.seigaihaLinesOnInk(colorScheme))
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipShape(Rectangle())
                }
                .opacity(0.4)
                .allowsHitTesting(false)
            }
            .frame(height: 80)

            innerContent
                .padding(14)
        }
        .background(PinlyTheme.surface)
        .cornerRadius(16)
        .clipped()
    }

    private var innerContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(route.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        if route.isOfficial {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(PinlyTheme.primary)
                        }
                    }
                    Label(route.city.capitalized, systemImage: categoryIcon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Menu {
                    Button(role: .destructive) {
                        onReport()
                    } label: {
                        Label(NSLocalizedString("Bildir", comment: ""), systemImage: "flag")
                    }
                    Button(role: .destructive) {
                        onBlock()
                    } label: {
                        Label(NSLocalizedString("Kullanıcıyı Engelle", comment: ""), systemImage: "hand.raised")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .padding(6)
                }
            }

            if let description = route.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            let names = route.places.sorted { $0.sortIndex < $1.sortIndex }.prefix(3).map(\.name)
            if !names.isEmpty {
                let suffix = route.stopCount > 3 ? " +\(route.stopCount - 3)" : ""
                Text(names.joined(separator: " → ") + suffix)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 16) {
                Label(
                    String(format: NSLocalizedString("%lld mekan", comment: ""), route.stopCount),
                    systemImage: "mappin.circle.fill"
                )
                .font(.caption)
                .foregroundColor(PinlyTheme.primary)

                if let km = route.distanceKm {
                    Label(String(format: "%.1f km", km), systemImage: "figure.walk")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onToggleFavorite) {
                    HStack(spacing: 4) {
                        Image(systemName: isFavorited ? "heart.fill" : "heart")
                        Text("\(route.favCount)")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(isFavorited ? PinlyTheme.danger : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
