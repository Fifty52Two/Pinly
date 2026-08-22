import SwiftUI
import MapKit

// MARK: - SharedRoutesListSheet

/// "Ortak Rotalarım" — sahibi olduğum + davetle katıldığım tüm ortak rotalar. Önceden bu
/// liste hiç yoktu: linkini paylaşmadan/kaydetmeden editor'ü kapatan kullanıcı rotasına bir
/// daha ASLA geri dönemiyordu (tek giriş yolu paylaşım linkiydi). Artık Rotalar sekmesindeki
/// menüden her zaman erişilebilir.
struct SharedRoutesListSheet: View {
    let onSelect: (String) -> Void

    @Environment(\.sharedRoutes) private var sharedRoutes
    @Environment(\.dismiss) private var dismiss
    @State private var routes: [SharedRouteDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.slash").font(.system(size: 40)).foregroundColor(.secondary)
                        Text(errorMessage).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else if routes.isEmpty {
                    VStack(spacing: 14) {
                        EmptyStateMedallion(icon: "person.2.fill", badgeColor: PinlyTheme.slate)
                        Text(NSLocalizedString("Henüz ortak rotan yok", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("Ortak Rota Oluştur ile başlat, linki arkadaşınla paylaş.", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(routes) { route in
                        Button {
                            onSelect(route.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(route.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                Text(route.collaborator == nil
                                     ? NSLocalizedString("Katılım bekleniyor", comment: "")
                                     : String(format: NSLocalizedString("%lld mekan", comment: ""), route.places.count))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(NSLocalizedString("Ortak Rotalarım", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("Kapat", comment: "")) { dismiss() }
                }
            }
        }
        .task {
            do {
                routes = try await sharedRoutes.myRoutes()
            } catch {
                errorMessage = NSLocalizedString("Rota yüklenemedi. Bağlantını kontrol edip tekrar dene.", comment: "")
            }
            isLoading = false
        }
    }
}

// MARK: - CreateSharedRouteSheet

/// Ortak rota oluşturma girişi — sadece isim ister, boş bir rota yaratıp editor'ü açar
/// (mekanlar editor içinden eklenir). Giriş yapılmamışsa (Apple ile) önce girişe yönlendirir.
struct CreateSharedRouteSheet: View {
    let onCreated: (String) -> Void

    @Environment(\.sharedRoutes) private var sharedRoutes
    @Environment(\.social) private var social
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appleAuth = AppleAuthService.shared
    @State private var name = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showUsernameSetup = false

    var body: some View {
        NavigationStack {
            Form {
                if !appleAuth.isSignedIn {
                    Section {
                        Text(NSLocalizedString("Ortak rota için önce Apple ile giriş yapmalısın (Profil sekmesi).", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section {
                        TextField(NSLocalizedString("Rota adı", comment: ""), text: $name)
                    }
                    if let errorMessage {
                        Text(errorMessage).font(.caption).foregroundColor(PinlyTheme.danger)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Ortak Rota Oluştur", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("İptal", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button(NSLocalizedString("Oluştur", comment: "")) {
                            Task { await createGated() }
                        }
                        .disabled(!appleAuth.isSignedIn || name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showUsernameSetup) {
            UsernameSetupSheet {
                showUsernameSetup = false
                Task { await create() }
            }
        }
    }

    /// `shared_routes.owner` Supabase'de `profiles(id)`'e foreign key — Apple ile YENİ giriş
    /// yapmış bir kullanıcının `profiles` satırı henüz YOKTUR (otomatik oluşturan bir trigger
    /// yok, satır SADECE kullanıcı adı belirlenince upsert'lenir, bkz. `SavedRoutesViewModel.
    /// publishAsync`'teki aynı gate). Bu kontrol olmadan INSERT sessizce foreign-key hatasıyla
    /// başarısız oluyordu — "ortak rota oluşturulamıyor" şikayetinin kök nedeni buydu.
    private func createGated() async {
        if let profile = try? await social.myProfile(), profile.username != nil {
            await create()
        } else {
            showUsernameSetup = true
        }
    }

    private func create() async {
        isCreating = true
        errorMessage = nil
        do {
            let route = try await sharedRoutes.create(name: name, category: RouteCategory.city.rawValue, places: [])
            onCreated(route.id)
        } catch {
            errorMessage = NSLocalizedString("Oluşturulamadı, tekrar dene.", comment: "")
        }
        isCreating = false
    }
}

// MARK: - SharedRouteEditorViewModel

/// İki kişinin birlikte düzenlediği rota — ekleme/çıkarma/sıra değiştirme yerelde ANINDA
/// uygulanır (iyimser güncelleme), sonra sunucuya yazılır; karşı taraftaki değişiklikler
/// Realtime abonelikle otomatik gelir. Basit "son yazan kazanır" — iki kişilik küçük bir
/// liste için tam CRDT/OT gerekmiyor, çakışma pratikte nadir.
@MainActor
final class SharedRouteEditorViewModel: ObservableObject {
    @Published var route: SharedRouteDTO?
    @Published var isLoading = true
    @Published var errorMessage: String?
    /// Katılan (autoJoin) kişinin `profiles` satırı yok — `collaborator` sütunu da
    /// `profiles(id)`'e foreign key olduğu için kullanıcı adı belirlenmeden `join` RPC'si
    /// FK ihlaliyle sessizce patlıyordu (view sonsuza kadar "yükleniyor" gibi takılı
    /// kalıyor/çöküyordu — gerçek cihazda görülen "dondu kaldı" şikayetinin kaynağı).
    @Published var needsUsernameSetup = false

    private var service: SharedRouteServicing
    private var social: SocialServicing
    private var subscription: SharedRouteSubscription?
    private var pendingLoad: (id: String, autoJoin: Bool)?
    /// Kendi gönderdiğimiz güncellemeyi Realtime'dan geri gelince tekrar uygulayıp
    /// listeyi "geri sıçratmamak" için — kendi son yazdığımız `updated_at`'i tutuyoruz.
    private var lastLocalWrite: Date?

    init(service: SharedRouteServicing, social: SocialServicing) {
        self.service = service
        self.social = social
    }

    /// `@Environment` init anında okunamadığı için gerçek servisler View'in `.task`'ında,
    /// `load` çağrılmadan HEMEN önce burada takılır (view yaşam döngüsü boyunca TEK sefer).
    func configure(service: SharedRouteServicing, social: SocialServicing) {
        self.service = service
        self.social = social
    }

    func load(id: String, autoJoin: Bool) async {
        isLoading = true
        errorMessage = nil
        if autoJoin {
            let profile = try? await social.myProfile()
            guard profile?.username != nil else {
                pendingLoad = (id, autoJoin)
                needsUsernameSetup = true
                isLoading = false
                return
            }
        }
        await performLoad(id: id, autoJoin: autoJoin)
    }

    /// `UsernameSetupSheet` başarıyla kapandıktan sonra çağrılır — `profiles` satırı artık
    /// var, bekleyen `join`/`fetch` işlemine devam edilir.
    func retryPendingLoad() async {
        guard let pending = pendingLoad else { return }
        pendingLoad = nil
        needsUsernameSetup = false
        isLoading = true
        await performLoad(id: pending.id, autoJoin: pending.autoJoin)
    }

    private func performLoad(id: String, autoJoin: Bool) async {
        do {
            route = autoJoin ? try await service.join(id: id) : try await service.fetch(id: id)
            subscription = service.subscribe(id: id) { [weak self] updated in
                guard let self else { return }
                // Kendi yazdığımız satır zaten yerelde uygulanmış durumda — aynısını
                // tekrar yazıp gereksiz re-render/flicker yaratmayalım.
                if let last = self.lastLocalWrite, abs(updated.updatedAt.timeIntervalSince(last)) < 0.5 { return }
                self.route = updated
            }
        } catch {
            errorMessage = NSLocalizedString("Rota yüklenemedi. Bağlantını kontrol edip tekrar dene.", comment: "")
        }
        isLoading = false
    }

    func addPlace(_ item: MKMapItem) {
        guard var route else { return }
        let snapshot = SavedPlaceSnapshot(
            name: item.name ?? NSLocalizedString("Mekan", comment: ""),
            category: PlaceCategory.general.rawValue,
            address: item.placemark.title ?? "",
            notes: "",
            latitude: item.placemark.coordinate.latitude,
            longitude: item.placemark.coordinate.longitude,
            sortIndex: route.places.count
        )
        route.places.append(snapshot)
        self.route = route
        push(places: route.places)
    }

    func removePlace(at offsets: IndexSet) {
        guard var route else { return }
        route.places.remove(atOffsets: offsets)
        reindex(&route.places)
        self.route = route
        push(places: route.places)
    }

    func movePlace(from source: IndexSet, to destination: Int) {
        guard var route else { return }
        route.places.move(fromOffsets: source, toOffset: destination)
        reindex(&route.places)
        self.route = route
        push(places: route.places)
    }

    private func reindex(_ places: inout [SavedPlaceSnapshot]) {
        for index in places.indices { places[index].sortIndex = index }
    }

    private func push(places: [SavedPlaceSnapshot]) {
        guard let id = route?.id else { return }
        let writeTime = Date()
        lastLocalWrite = writeTime
        Task {
            try? await service.update(id: id, name: nil, places: places)
        }
    }

    var shareURL: URL? {
        guard let id = route?.id else { return nil }
        return URL(string: "pinly://sharedroute?id=\(id)")
    }
}

// MARK: - SharedRouteEditorView

struct SharedRouteEditorView: View {
    let routeId: String
    /// Deep link'ten (paylaşım linkini açan ikinci kişi) mi geldi — evetse `join` RPC'si
    /// çağrılır; oluşturan kişi zaten owner olduğu için sadece `fetch` yeterli.
    let autoJoin: Bool

    @Environment(\.sharedRoutes) private var sharedRoutes
    @Environment(\.social) private var social
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SharedRouteEditorViewModel
    @State private var showAddPlace = false

    init(routeId: String, autoJoin: Bool) {
        self.routeId = routeId
        self.autoJoin = autoJoin
        // sharedRoutes/social environment'ı init anında henüz yok — gerçek servisler .task'ta set edilir.
        _viewModel = StateObject(wrappedValue: SharedRouteEditorViewModel(
            service: NoOpSharedRouteService.shared,
            social: NoOpSocialService.shared
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.slash").font(.system(size: 40)).foregroundColor(.secondary)
                        Text(error).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else if let route = viewModel.route {
                    content(route: route)
                }
            }
            .navigationTitle(viewModel.route?.name ?? NSLocalizedString("Ortak Rota", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("Kapat", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button { showAddPlace = true } label: {
                            Image(systemName: "plus")
                        }
                        if let url = viewModel.shareURL {
                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddPlace) {
            SharedRoutePlaceSearchSheet { item in
                viewModel.addPlace(item)
                showAddPlace = false
            }
        }
        .sheet(isPresented: $viewModel.needsUsernameSetup) {
            UsernameSetupSheet {
                Task { await viewModel.retryPendingLoad() }
            }
        }
        .task {
            // Gerçek Supabase servisleri environment'tan burada alınıp ViewModel'e takılır —
            // init sırasında @Environment henüz okunabilir değildi.
            viewModel.configure(service: sharedRoutes, social: social)
            await viewModel.load(id: routeId, autoJoin: autoJoin)
        }
    }

    @ViewBuilder
    private func content(route: SharedRouteDTO) -> some View {
        VStack(spacing: 0) {
            collaboratorBanner(route: route)
            List {
                ForEach(route.places.sorted { $0.sortIndex < $1.sortIndex }, id: \.sortIndex) { place in
                    HStack(spacing: 12) {
                        let category = PlaceCategory.from(place.category)
                        ZStack {
                            Circle().fill(category.color.opacity(0.15)).frame(width: 36, height: 36)
                            Image(systemName: category.icon).font(.callout).foregroundColor(category.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name).font(.subheadline).fontWeight(.semibold)
                            if !place.address.isEmpty {
                                Text(place.address).font(.caption).foregroundColor(.secondary).lineLimit(1)
                            }
                        }
                    }
                }
                .onDelete { viewModel.removePlace(at: $0) }
                .onMove { viewModel.movePlace(from: $0, to: $1) }

                if route.places.isEmpty {
                    Text(NSLocalizedString("Henüz mekan yok — sağ üstten ekle.", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))
        }
    }

    @ViewBuilder
    private func collaboratorBanner(route: SharedRouteDTO) -> some View {
        if route.collaborator == nil {
            HStack(spacing: 8) {
                Image(systemName: "person.badge.clock")
                Text(NSLocalizedString("Katılım bekleniyor — linki paylaş, açan kişi otomatik katılır.", comment: ""))
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(PinlyTheme.fillMuted)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                Text(NSLocalizedString("İkiniz de canlı düzenliyorsunuz.", comment: ""))
                    .font(.caption)
            }
            .foregroundColor(PinlyTheme.success)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(PinlyTheme.success.opacity(0.1))
        }
    }
}

// MARK: - SharedRoutePlaceSearchSheet

/// Basit MKLocalSearch tabanlı arama — sonuca dokununca seçilip kapanır.
private struct SharedRoutePlaceSearchSheet: View {
    let onPick: (MKMapItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            List(results, id: \.self) { item in
                Button {
                    onPick(item)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name ?? "").font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                        if let address = item.placemark.title {
                            Text(address).font(.caption).foregroundColor(.secondary).lineLimit(1)
                        }
                    }
                }
            }
            .overlay {
                if isSearching { ProgressView() }
                else if results.isEmpty && !query.isEmpty {
                    Text(NSLocalizedString("Sonuç bulunamadı", comment: "")).foregroundColor(.secondary)
                }
            }
            .searchable(text: $query, prompt: NSLocalizedString("Mekan ara", comment: ""))
            .onSubmit(of: .search) { Task { await search() } }
            .navigationTitle(NSLocalizedString("Mekan Ekle", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("İptal", comment: "")) { dismiss() }
                }
            }
        }
    }

    private func search() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let response = try? await MKLocalSearch(request: request).start()
        results = response?.mapItems ?? []
        isSearching = false
    }
}
