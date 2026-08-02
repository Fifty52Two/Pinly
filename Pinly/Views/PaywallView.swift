import SwiftUI
import RevenueCat

struct PaywallView: View {
    /// Hangi gate'in açtığını taşır (`paywall_shown` analytics param'ı + soft/hard metin
    /// seçimi). Varsayılan "limit_reached" — mevcut 10 hard-gate çağrı sitesi hiç
    /// değişmeden bu default'u kullanır (bkz. specs/FAZ1_REVENUECAT_KARAR.md).
    var source: String = "limit_reached"
    let onDismiss: () -> Void

    @Environment(\.entitlements) private var entitlements
    @Environment(\.analytics) private var analytics
    @Environment(\.purchases) private var purchases

    @State private var offering: Offering?
    @State private var selectedPackage: Package?
    @State private var isLoadingOfferings = true
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    // Optimistic varsayılan: RC'nin App Store hesabı bazlı gerçek cevabı gelene kadar (veya
    // hiç gelmezse — offline/ilk kontrol) trial rozetini gizlemeyiz; yalnızca SDK açıkça
    // ".ineligible" derse (kullanıcı bu ürünün denemesini daha önce kullanmış) gizleriz.
    @State private var yearlyTrialEligible = true

    private var isSoftPaywall: Bool { source == "first_route_completed" }
    private var yearlyPackage: Package? { offering?.annual }
    private var monthlyPackage: Package? { offering?.monthly }
    private var hasFreeTrial: Bool {
        yearlyPackage?.storeProduct.introductoryDiscount?.paymentMode == .freeTrial
            && yearlyTrialEligible
    }

    var body: some View {
        ZStack {
            // Paywall daha önce hiç temalanmamıştı (sistem varsayılan sheet zemini) —
            // uygulamanın geri kalanıyla aynı krem zemin + seigaiha dokusu, en kritik
            // gelir ekranının "dandik" görünmemesi için (bkz. OnboardingView aynı desen).
            PinlyTheme.groundGradient
                .ignoresSafeArea()
            WavePattern(waveLength: 90, amplitude: 12, rowSpacing: 22)
                .stroke(PinlyTheme.slate.opacity(0.08), lineWidth: 1)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                featureList
                Spacer()
                content
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { analytics.track(.paywallShown(source: source)) }
        .task { await loadOfferings() }
        .alert(NSLocalizedString("Satın alma başarısız oldu", comment: ""), isPresented: errorAlertBinding) {
            Button(NSLocalizedString("Tamam", comment: ""), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // MARK: - Başlık

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PinlyTheme.primary.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 32))
                    .foregroundColor(PinlyTheme.primary)
            }
            .padding(.top, 32)

            Text(NSLocalizedString(isSoftPaywall ? "Sınırsız keşif" : "Mekan Limitine Ulaştın", comment: ""))
                .font(.title2)
                .fontWeight(.bold)

            if isSoftPaywall {
                Text(NSLocalizedString("Rotanı tamamladın! Sınırsız mekan, dışa aktarma ve reklamsız deneyim için Pro'ya geç.", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } else {
                Text(String(format: NSLocalizedString("Ücretsiz planda en fazla %lld mekan kaydedebilirsin.\nSınırsız mekan için Pro'ya geç.", comment: ""), entitlements.freeLimit))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Fayda listesi

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ProFeatureRow(icon: "mappin.and.ellipse", color: PinlyTheme.primary,
                          title: NSLocalizedString("Sınırsız Mekan", comment: ""),
                          subtitle: NSLocalizedString("İstediğin kadar mekan kaydet", comment: ""),
                          badge: nil)
            ProFeatureRow(icon: "square.and.arrow.down.on.square", color: PinlyTheme.primaryWarm,
                          title: NSLocalizedString("GPX & PDF Dışa Aktar", comment: ""),
                          subtitle: NSLocalizedString("Rotalarını dışa aktar ve arşivle", comment: ""),
                          badge: nil)
            ProFeatureRow(icon: "nosign", color: PinlyTheme.accent,
                          title: NSLocalizedString("Reklamsız Kullanım", comment: ""),
                          subtitle: NSLocalizedString("Kesintisiz keşfet", comment: ""),
                          badge: nil)
            ProFeatureRow(icon: "wifi.slash", color: PinlyTheme.slate,
                          title: NSLocalizedString("Çevrimdışı Harita", comment: ""),
                          subtitle: NSLocalizedString("İnternetsiz de çalışır", comment: ""),
                          badge: NSLocalizedString("Yakında", comment: ""))
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 8)
    }

    // MARK: - İçerik (yükleniyor / hata / plan seçici)

    @ViewBuilder
    private var content: some View {
        if isLoadingOfferings {
            ProgressView()
                .padding(.bottom, 40)
        } else if offering == nil || (yearlyPackage == nil && monthlyPackage == nil) {
            offeringsUnavailableView
        } else {
            planPicker
            actionButtons
        }
    }

    private var offeringsUnavailableView: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("Şu an mağazaya ulaşılamıyor", comment: ""))
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(NSLocalizedString("Lütfen internet bağlantını kontrol edip tekrar dene.", comment: ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await loadOfferings() }
            } label: {
                Text(NSLocalizedString("Tekrar Dene", comment: ""))
            }
            .buttonStyle(PinlySecondaryButtonStyle())
            .padding(.top, 4)

            Button { onDismiss() } label: {
                Text(NSLocalizedString("Şimdi Değil", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }

    private var planPicker: some View {
        VStack(spacing: 10) {
            if let yearly = yearlyPackage {
                PlanOptionButton(
                    label: NSLocalizedString("Yıllık", comment: ""),
                    price: "\(yearly.storeProduct.localizedPriceString) \(NSLocalizedString("/ yıl", comment: ""))",
                    badge: hasFreeTrial
                        ? NSLocalizedString("7 Gün Ücretsiz", comment: "")
                        : NSLocalizedString("%33 Tasarruf", comment: ""),
                    isSelected: selectedPackage?.identifier == yearly.identifier
                ) { selectedPackage = yearly }
            }

            if let monthly = monthlyPackage {
                PlanOptionButton(
                    label: NSLocalizedString("Aylık", comment: ""),
                    price: "\(monthly.storeProduct.localizedPriceString) \(NSLocalizedString("/ ay", comment: ""))",
                    badge: nil,
                    isSelected: selectedPackage?.identifier == monthly.identifier
                ) { selectedPackage = monthly }
            }
        }
        .padding(.horizontal, 24)
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button {
                Task { await purchaseSelected() }
            } label: {
                if isPurchasing {
                    ProgressView()
                        .tint(PinlyTheme.onAccent)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(ctaTitle)
                }
            }
            .buttonStyle(PinlyPrimaryButtonStyle())
            .disabled(isPurchasing || selectedPackage == nil)

            Button {
                Task { await restore() }
            } label: {
                Text(NSLocalizedString("Satın Alımları Geri Yükle", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .disabled(isPurchasing)

            Button { onDismiss() } label: {
                Text(NSLocalizedString("Şimdi Değil", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 32)
    }

    private var ctaTitle: String {
        if selectedPackage?.identifier == yearlyPackage?.identifier, hasFreeTrial {
            return NSLocalizedString("7 Gün Ücretsiz Dene", comment: "")
        }
        return NSLocalizedString("Pro'ya Geç", comment: "")
    }

    // MARK: - Mağaza çağrıları

    private func loadOfferings() async {
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }
        do {
            let offerings = try await purchases.offerings()
            offering = offerings.current
            selectedPackage = offerings.current?.annual
                ?? offerings.current?.monthly
                ?? offerings.current?.availablePackages.first
        } catch {
            offering = nil
        }

        if let yearly = yearlyPackage,
           yearly.storeProduct.introductoryDiscount?.paymentMode == .freeTrial {
            let status = await purchases.checkTrialEligibility(product: yearly.storeProduct)
            yearlyTrialEligible = status != .ineligible
        }
    }

    private func purchaseSelected() async {
        guard let package = selectedPackage else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await purchases.purchase(package: package)
            guard !result.userCancelled else { return }
            // Ödeme GERÇEKLEŞTİ: event ve kapanış entitlement eşleşmesine bağlanmaz —
            // eşleşme gelmese bile (RC konfigürasyon aksaklığı) kullanıcı parası alınmışken
            // paywall'da kilitli bırakılmaz; Release'te customerInfoStream gecikmeli de olsa
            // mirror'ı düzeltir.
            if package.identifier == yearlyPackage?.identifier, hasFreeTrial {
                analytics.track(.trialStarted(product: package.storeProduct.productIdentifier))
            }
            analytics.track(.purchaseCompleted(product: package.storeProduct.productIdentifier))
            // DEBUG'da entitlements=Local → gerçekten set eder; Release'te entitlements=RevenueCat
            // → setter no-op (gerçek kaynak zaten customerInfoStream ile aynı anda güncellenir).
            entitlements.isPro = EntitlementMapper.isPro(customerInfo: result.customerInfo)
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let customerInfo = try await purchases.restorePurchases()
            let active = EntitlementMapper.isPro(customerInfo: customerInfo)
            entitlements.isPro = active
            analytics.track(.restoreCompleted)
            if active { onDismiss() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Plan Seçeneği

private struct PlanOptionButton: View {
    let label: String
    let price: String
    let badge: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(label)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        if let badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(PinlyTheme.gold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(PinlyTheme.gold.opacity(0.12))
                                .cornerRadius(6)
                        }
                    }
                    Text(price)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? PinlyTheme.primary : .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? PinlyTheme.primary.opacity(0.06) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? PinlyTheme.primary : PinlyTheme.fillMuted, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Fayda Satırı

private struct ProFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let badge: String?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if let badge {
                        Text(badge)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(PinlyTheme.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(PinlyTheme.warning.opacity(0.12))
                            .cornerRadius(6)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
