import SwiftUI

// MARK: - Daha Fazla Sekmesi

struct MoreTab: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.badges) private var badges

    @State private var showHistory = false
    @State private var showWeeklyReport = false
    @State private var showBadges = false
    @State private var showLanguagePicker = false
    @State private var showStats = false
    @AppStorage("pinly.appearance") private var appearance = "system"
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            List {
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
            .background(PinlyTheme.groundGradient)
            .navigationTitle(NSLocalizedString("Daha Fazla", comment: ""))
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
