import SwiftUI
import PhotosUI

// MARK: - Profil Sekmesi

struct ProfileTab: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.badges) private var badges
    @Environment(\.profile) private var profileService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @State private var showHistory = false
    @State private var showWeeklyReport = false
    @State private var showBadges = false
    @State private var showLanguagePicker = false
    @State private var showStats = false
    @State private var showEditProfile = false
    @State private var showDeleteAllConfirm = false
    @State private var showDiagnostics = false
    @State private var profile: UserProfile? = nil
    @State private var profilePhoto: UIImage? = nil
    @State private var pickerItem: PhotosPickerItem? = nil

    private var visitedCount: Int { placeStore.places.filter { $0.isVisited }.count }
    @AppStorage("pinly.appearance") private var appearance = "system"

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func settingsIcon(_ name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: name)
                .foregroundColor(color)
                .font(.headline)
        }
    }

    /// TAM sıfırlama: SwiftData modelleri + tüm UserDefaults (onboarding, isPro,
    /// rozetler dahil) + profil fotoğrafı. Kullanıcı onboarding'e döner —
    /// KVKK/GDPR "verilerimi sil" talebinin yerel karşılığı.
    private func deleteAllData() {
        try? modelContext.delete(model: Place.self)
        try? modelContext.delete(model: RouteHistory.self)
        try? modelContext.delete(model: SavedRoute.self)
        try? modelContext.save()
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        profileService.deletePhoto()
        placeStore.load(context: modelContext)
        profile = nil
        profilePhoto = nil
    }

    var body: some View {
        NavigationStack {
            List {
                // Profil başlığı — ortalanmış avatar + isim + mini istatistikler
                Section {
                    VStack(spacing: 14) {
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                profileAvatar
                                ZStack {
                                    Circle()
                                        .fill(PinlyTheme.primary)
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "camera.fill")
                                        .font(.footnote)
                                        .foregroundColor(.white)
                                }
                                .overlay(Circle().strokeBorder(PinlyTheme.surface, lineWidth: 3))
                            }
                        }
                        .buttonStyle(.plain)

                        VStack(spacing: 3) {
                            if let profile {
                                Text(profile.fullName)
                                    .font(.title3.bold())
                                Text(String(format: NSLocalizedString("%lld yaşında", comment: ""), profile.age))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                // Kurulumda "Şimdilik Atla" seçildiyse profil boş —
                                // nazikçe tamamlamaya davet et
                                Text(NSLocalizedString("Profilini tamamla", comment: ""))
                                    .font(.title3.bold())
                                Text(NSLocalizedString("Adını ekleyerek deneyimini kişiselleştir.", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack(spacing: 36) {
                            profileMiniStat(value: placeStore.places.count,
                                            label: NSLocalizedString("Mekan", comment: ""))
                            profileMiniStat(value: visitedCount,
                                            label: NSLocalizedString("Ziyaret", comment: ""))
                        }

                        Button {
                            showEditProfile = true
                        } label: {
                            Label(NSLocalizedString("Profili Düzenle", comment: ""),
                                  systemImage: "pencil")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(PinlyTheme.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(PinlyTheme.primary.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section {
                    MoreRow(icon: "chart.xyaxis.line", iconColor: PinlyTheme.primary,
                            title: NSLocalizedString("İstatistiklerim", comment: ""),
                            subtitle: NSLocalizedString("Toplam km, ziyaret ve daha fazlası", comment: "")) {
                        showStats = true
                    }
                    MoreRow(icon: "clock.arrow.circlepath", iconColor: PinlyTheme.slate,
                            title: NSLocalizedString("Rota Geçmişi", comment: ""),
                            subtitle: NSLocalizedString("Tamamladığın rotalar", comment: "")) {
                        showHistory = true
                    }
                    MoreRow(icon: "chart.bar.fill", iconColor: PinlyTheme.warning,
                            title: NSLocalizedString("Haftalık Rapor", comment: ""),
                            subtitle: NSLocalizedString("Bu haftanın özeti", comment: "")) {
                        showWeeklyReport = true
                    }
                    MoreRow(icon: "trophy.fill", iconColor: PinlyTheme.gold,
                            title: NSLocalizedString("Rozetler", comment: ""),
                            subtitle: {
                                let earned = badges.unlockedBadges.count
                                let total  = Badge.allCases.count
                                return earned == 0
                                    ? NSLocalizedString("Rozet kazanmaya başla", comment: "")
                                    : String(format: NSLocalizedString("%lld/%lld rozet kazanıldı", comment: ""), earned, total)
                            }()) {
                        showBadges = true
                    }
                }
                .listRowBackground(PinlyTheme.surface)

                Section {
                    let current = LanguageManager.supported.first { $0.code == languageManager.currentLanguage }
                    MoreRow(
                        icon: "globe",
                        iconColor: PinlyTheme.primary,
                        title: "Dil / Language",
                        subtitle: current.map { "\($0.flag) \($0.name)" } ?? "Türkçe"
                    ) {
                        showLanguagePicker = true
                    }

                    // Görünüm (Sistem / Açık / Koyu)
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(PinlyTheme.slate.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "circle.lefthalf.filled")
                                .foregroundColor(PinlyTheme.slate)
                                .font(.headline)
                        }
                        Text(NSLocalizedString("Görünüm", comment: ""))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Picker("", selection: $appearance) {
                            Text(NSLocalizedString("Sistem", comment: "")).tag("system")
                            Text(NSLocalizedString("Açık", comment: "")).tag("light")
                            Text(NSLocalizedString("Koyu", comment: "")).tag("dark")
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .tint(PinlyTheme.primary)
                    }
                }
                .listRowBackground(PinlyTheme.surface)

                // Hakkında / Destek / Veri
                Section {
                    HStack(spacing: 14) {
                        settingsIcon("info.circle.fill", color: PinlyTheme.primaryWarm)
                        Text(NSLocalizedString("Sürüm", comment: ""))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(appVersionText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Button {
                        openURL(URL(string: "mailto:akkopru_ferhat65@outlook.com?subject=Pinly%20Destek")!)
                    } label: {
                        HStack(spacing: 14) {
                            settingsIcon("envelope.fill", color: PinlyTheme.slate)
                            Text(NSLocalizedString("Destek", comment: ""))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    MoreRow(icon: "stethoscope", iconColor: PinlyTheme.slate,
                            title: NSLocalizedString("Tanılama Günlüğü", comment: ""),
                            subtitle: NSLocalizedString("Crash ve performans kayıtları", comment: "")) {
                        showDiagnostics = true
                    }

                    Button(role: .destructive) {
                        showDeleteAllConfirm = true
                    } label: {
                        HStack(spacing: 14) {
                            settingsIcon("trash.fill", color: PinlyTheme.danger)
                            Text(NSLocalizedString("Tüm Verilerimi Sil", comment: ""))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(PinlyTheme.danger)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(PinlyTheme.surface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 32, for: .scrollContent)
            .background(PinlyTheme.groundGradient)
            .navigationTitle(NSLocalizedString("Profil", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
        }
        .sheet(isPresented: $showStats) {
            ProfileStatsView()
                .environmentObject(placeStore)
        }
        .sheet(isPresented: $showHistory) {
            RouteHistoryView()
        }
        .sheet(isPresented: $showWeeklyReport) {
            WeeklyReportView()
                .environmentObject(placeStore)
        }
        .sheet(isPresented: $showBadges) {
            BadgesView()
                .environmentObject(placeStore)
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet()
                .environmentObject(languageManager)
        }
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticsView()
        }
        .sheet(isPresented: $showEditProfile, onDismiss: reloadProfile) {
            ProfileEditSheet(onSaved: reloadProfile)
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            NSLocalizedString("Tüm verilerin kalıcı olarak silinecek — mekanlar, rotalar, rozetler ve profil. Uygulama ilk kurulum durumuna döner. Bu işlem geri alınamaz.", comment: ""),
            isPresented: $showDeleteAllConfirm,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("Tüm Verilerimi Sil", comment: ""), role: .destructive) {
                deleteAllData()
            }
            Button(NSLocalizedString("Vazgeç", comment: ""), role: .cancel) {}
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        profileService.savePhoto(image)
                        profilePhoto = profileService.loadPhoto()
                        pickerItem = nil
                    }
                }
            }
        }
        .onAppear { reloadProfile() }
    }

    private var profileAvatar: some View {
        Group {
            if let profilePhoto {
                Image(uiImage: profilePhoto)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    PinlyTheme.heroGradient
                    Text(profile?.initials.isEmpty == false ? profile!.initials : "?")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: 104, height: 104)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(PinlyTheme.surface, lineWidth: 4))
        .overlay(
            Circle()
                .strokeBorder(PinlyTheme.primary.opacity(0.25), lineWidth: 2)
                .padding(-6)
        )
    }

    private func profileMiniStat(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func reloadProfile() {
        profile = profileService.load()
        profilePhoto = profileService.loadPhoto()
    }
}

// MARK: - MoreRow

private struct MoreRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.headline)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Language Picker Sheet

private struct LanguagePickerSheet: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(LanguageManager.supported, id: \.code) { lang in
                    Button {
                        languageManager.setLanguage(lang.code)
                        dismiss()
                    } label: {
                        HStack {
                            Text(lang.flag).font(.title2)
                            Text(lang.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if languageManager.currentLanguage == lang.code {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(PinlyTheme.primary)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Dil / Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("Kapat", comment: "")) { dismiss() }
                }
            }
        }
    }
}
