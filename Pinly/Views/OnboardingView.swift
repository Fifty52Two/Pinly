import SwiftUI

// MARK: - Onboarding (ilk açılış tanıtım akışı)

struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.swarmImporting) private var swarmImporting
    @Environment(\.entitlements) private var entitlements
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var placeStore: PlaceStore

    @State private var page = 0
    @State private var showSwarmPicker = false
    @State private var isImportingSwarm = false
    @State private var swarmImportedCount: Int? = nil
    @State private var swarmTruncated = false
    @State private var swarmError = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "mappin.and.ellipse",
            accent: PinlyTheme.primary,
            title: NSLocalizedString("Mekanlarını Kaydet", comment: ""),
            subtitle: NSLocalizedString("Gittiğin ya da gitmek istediğin her yeri kategorilerle sakla. Swarm geçmişini tek dokunuşla içeri aktar.", comment: "")
        ),
        OnboardingPage(
            icon: "figure.walk.motion",
            accent: PinlyTheme.slate,
            title: NSLocalizedString("Rotanı Planla, Yürü", comment: ""),
            subtitle: NSLocalizedString("Mekanlarından yürüyüş rotası oluştur. Adım adım navigasyon kilit ekranında seni takip eder.", comment: "")
        ),
        OnboardingPage(
            icon: "trophy.fill",
            accent: PinlyTheme.accent,
            title: NSLocalizedString("Rozet Kazan, Paylaş", comment: ""),
            subtitle: NSLocalizedString("22 rozet, haftalık raporlar ve arkadaşlarınla QR kod ile rota paylaşımı seni bekliyor.", comment: "")
        ),
    ]

    var body: some View {
        ZStack {
            PinlyTheme.groundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < pages.count {
                        Button(NSLocalizedString("Atla", comment: "")) {
                            onFinish()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 24)
                        .padding(.top, 16)
                    }
                }
                .frame(height: 44)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, p in
                        OnboardingPageView(page: p)
                            .tag(index)
                    }
                    SwarmOnboardingPageView(
                        isImporting: isImportingSwarm,
                        importedCount: swarmImportedCount,
                        truncated: swarmTruncated,
                        onPickFile: { showSwarmPicker = true }
                    )
                    .tag(pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Sayfa göstergesi
                HStack(spacing: 8) {
                    ForEach(0..<(pages.count + 1), id: \.self) { i in
                        Capsule()
                            .fill(i == page ? PinlyTheme.primary : Color.primary.opacity(0.15))
                            .frame(width: i == page ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
                    }
                }
                .padding(.bottom, 28)

                Button {
                    if page < pages.count {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            page += 1
                        }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(page < pages.count
                         ? NSLocalizedString("Devam Et", comment: "")
                         : NSLocalizedString("Başla", comment: ""))
                }
                .buttonStyle(PinlyPrimaryButtonStyle())
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
        }
        .fileImporter(
            isPresented: $showSwarmPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleSwarmFile(result)
        }
        .alert(NSLocalizedString("Dosya Okunamadı", comment: ""), isPresented: $swarmError) {
            Button(NSLocalizedString("Tamam", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("Geçerli bir Swarm checkins.json dosyası seçin.", comment: ""))
        }
    }

    private func handleSwarmFile(_ result: Result<[URL], Error>) {
        guard let url = try? result.get().first,
              url.startAccessingSecurityScopedResource()
        else { swarmError = true; return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url),
              let parsed = swarmImporting.parseSwarm(data: data),
              !parsed.isEmpty
        else { swarmError = true; return }

        // Onboarding'de paywall gösterilmez — ücretsiz limit kadar aktarılır
        let capacity = entitlements.isPro
            ? parsed.count
            : max(0, entitlements.freeLimit - placeStore.places.count)
        let toImport = Array(parsed.prefix(capacity))
        swarmTruncated = parsed.count > toImport.count
        isImportingSwarm = true
        Task {
            for item in toImport {
                await placeStore.importPlace(item, context: modelContext)
            }
            swarmImportedCount = toImport.count
            isImportingSwarm = false
        }
    }
}

// MARK: - Sayfa Modeli

private struct OnboardingPage {
    let icon: String
    let accent: Color
    let title: String
    let subtitle: String
}

// MARK: - Tek Sayfa

private struct OnboardingPageView: View {
    let page: OnboardingPage

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                // Arka halkalar — kâğıt üzerinde yumuşak, düşük kontrast
                Circle()
                    .stroke(page.accent.opacity(0.10), lineWidth: 1.5)
                    .frame(width: 220, height: 220)
                Circle()
                    .stroke(page.accent.opacity(0.18), lineWidth: 1.5)
                    .frame(width: 164, height: 164)
                Circle()
                    .fill(page.accent.opacity(0.12))
                    .frame(width: 128, height: 128)
                Image(systemName: page.icon)
                    .font(.system(size: 54, weight: .medium))
                    .foregroundStyle(page.accent)
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.title.bold())
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                Text(page.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)
            }
            .offset(y: appeared ? 0 : 16)
            .opacity(appeared ? 1 : 0)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - Swarm İçe Aktarma Sayfası

private struct SwarmOnboardingPageView: View {
    let isImporting: Bool
    let importedCount: Int?
    let truncated: Bool
    let onPickFile: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(PinlyTheme.gold.opacity(0.10), lineWidth: 1.5)
                    .frame(width: 220, height: 220)
                Circle()
                    .stroke(PinlyTheme.gold.opacity(0.18), lineWidth: 1.5)
                    .frame(width: 164, height: 164)
                Circle()
                    .fill(PinlyTheme.gold.opacity(0.12))
                    .frame(width: 128, height: 128)
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 54, weight: .medium))
                    .foregroundStyle(PinlyTheme.gold)
            }

            VStack(spacing: 14) {
                Text(NSLocalizedString("Swarm'dan Taşın", comment: ""))
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(NSLocalizedString("Foursquare/Swarm geçmişin mi var? checkins.json dosyanı seç, mekanların saniyeler içinde Pinly'de olsun.", comment: ""))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)
            }

            if let count = importedCount {
                VStack(spacing: 6) {
                    Label(
                        String(format: NSLocalizedString("%lld mekan içe aktarıldı", comment: ""), count),
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(PinlyTheme.success)
                    if truncated {
                        Text(NSLocalizedString("Ücretsiz sürüm 20 mekanla sınırlı — kalanını Pro ile ekleyebilirsin.", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                    }
                }
            } else if isImporting {
                ProgressView()
            } else {
                VStack(spacing: 10) {
                    Button(action: onPickFile) {
                        Label(NSLocalizedString("Swarm Dosyası Seç", comment: ""), systemImage: "doc.badge.arrow.up")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(PinlyTheme.gold.opacity(0.12))
                            .foregroundColor(PinlyTheme.gold)
                            .cornerRadius(14)
                    }
                    Text(NSLocalizedString("İpucu: Swarm → Profil → Ayarlar → Verilerimi İndir", comment: ""))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
            Spacer()
        }
    }
}
