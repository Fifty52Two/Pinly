import SwiftUI
import PhotosUI

// MARK: - Profil Sekmesi

struct MoreTab: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.badges) private var badges

    @State private var showHistory = false
    @State private var showWeeklyReport = false
    @State private var showBadges = false
    @State private var showLanguagePicker = false
    @State private var showStats = false
    @State private var showEditProfile = false
    @State private var profile: UserProfile? = UserProfile.load()
    @State private var profilePhoto: UIImage? = UserProfile.loadPhoto()
    @State private var pickerItem: PhotosPickerItem? = nil

    private var visitedCount: Int { placeStore.places.filter { $0.isVisited }.count }
    @AppStorage("pinly.appearance") private var appearance = "system"
    @EnvironmentObject private var themeManager: ThemeManager

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
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                }
                                .overlay(Circle().strokeBorder(PinlyTheme.surface, lineWidth: 3))
                            }
                        }
                        .buttonStyle(.plain)

                        VStack(spacing: 3) {
                            Text(profile?.fullName ?? NSLocalizedString("Profil", comment: ""))
                                .font(.title3.bold())
                            if let profile {
                                Text(String(format: NSLocalizedString("%lld yaşında", comment: ""), profile.age))
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
                    MoreRow(icon: "clock.arrow.circlepath", iconColor: .teal,
                            title: NSLocalizedString("Rota Geçmişi", comment: ""),
                            subtitle: NSLocalizedString("Tamamladığın rotalar", comment: "")) {
                        showHistory = true
                    }
                    MoreRow(icon: "chart.bar.fill", iconColor: .orange,
                            title: NSLocalizedString("Haftalık Rapor", comment: ""),
                            subtitle: NSLocalizedString("Bu haftanın özeti", comment: "")) {
                        showWeeklyReport = true
                    }
                    MoreRow(icon: "trophy.fill", iconColor: .yellow,
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
                        iconColor: .indigo,
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
                                .font(.system(size: 18))
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

                    // Tema (Slate / Farad)
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(PinlyTheme.primary.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "paintpalette.fill")
                                .foregroundColor(PinlyTheme.primary)
                                .font(.system(size: 18))
                        }
                        Text(NSLocalizedString("Tema", comment: ""))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { themeManager.themeKey },
                            set: { themeManager.themeKey = $0 }
                        )) {
                            Text("Slate").tag("slate")
                            Text("Farad").tag("farad")
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .tint(PinlyTheme.primary)
                    }
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
        .sheet(isPresented: $showEditProfile, onDismiss: reloadProfile) {
            ProfileEditSheet(onSaved: reloadProfile)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        UserProfile.savePhoto(image)
                        profilePhoto = UserProfile.loadPhoto()
                        pickerItem = nil
                    }
                }
            }
        }
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
        .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
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
        profile = UserProfile.load()
        profilePhoto = UserProfile.loadPhoto()
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
                        .font(.system(size: 18))
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
