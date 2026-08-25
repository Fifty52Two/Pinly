import SwiftUI
import RevenueCat

struct PaywallView: View {
    /// Paywall'ı açan doğrulanmış ürün yüzeyini `paywall_viewed` event'ine ekler.
    /// Bugünkü üç kaynak: `export_locked`, `first_route_completed` ve `profile`.
    var source: String = "profile"
    let onDismiss: () -> Void

    @Environment(\.entitlements) private var entitlements
    @Environment(\.analytics) private var analytics
    @Environment(\.purchases) private var purchases

    @State private var offering: Offering?
    @State private var selectedPackage: Package?
    @State private var isLoadingOfferings = true
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    // Trial yalnızca RevenueCat/App Store açıkça `.eligible` dediğinde gösterilir. Bilinmeyen
    // veya offline durumda ücretsiz deneme vaat etmek yanıltıcı olabilir.
    @State private var yearlyTrialEligible = false

    private var isSoftPaywall: Bool { source == "first_route_completed" }
    private var yearlyPackage: Package? { offering?.annual }
    private var monthlyPackage: Package? { offering?.monthly }
    private var hasFreeTrial: Bool {
        yearlyPackage?.storeProduct.introductoryDiscount?.paymentMode == .freeTrial
            && yearlyTrialEligible
    }

    /// Yıllık planın aylığa göre tasarrufu — App Store Connect'teki GERÇEK fiyatlardan
    /// hesaplanır. Daha önce "%33" olarak sabit yazılıydı; fiyat değiştiği gün rozet
    /// yalan söyleyecekti (App Store Guideline 2.3.1 — yanıltıcı metadata).
    /// Her iki paket de yoksa veya tasarruf anlamlı değilse rozet gösterilmez.
    private var yearlySavingsPercent: Int? {
        guard let yearly = yearlyPackage?.storeProduct.price as NSDecimalNumber?,
              let monthly = monthlyPackage?.storeProduct.price as NSDecimalNumber?
        else { return nil }
        let yearlyValue = yearly.doubleValue
        let monthlyTotal = monthly.doubleValue * 12
        guard monthlyTotal > 0, yearlyValue > 0, yearlyValue < monthlyTotal else { return nil }
        let percent = Int(((1 - yearlyValue / monthlyTotal) * 100).rounded())
        return percent >= 5 ? percent : nil
    }

    /// Abonelik süresi + yenileme fiyatı + trial bitişinde ne olacağı aynı ekranda
    /// açıkça yazılmalı (App Store Guideline 3.1.2). Fiyat mağazadan gelir, hardcode edilmez.
    private var renewalDisclosure: String? {
        guard let package = selectedPackage else { return nil }
        let price = package.storeProduct.localizedPriceString
        let isYearly = package.identifier == yearlyPackage?.identifier
        let period = isYearly
            ? NSLocalizedString("yıl", comment: "")
            : NSLocalizedString("ay", comment: "")

        if isYearly, hasFreeTrial {
            return String(
                format: NSLocalizedString(
                    "7 gün ücretsiz, ardından %@ / %@. İptal edilmediği sürece otomatik yenilenir. Dilediğin zaman App Store ayarlarından iptal edebilirsin.",
                    comment: ""
                ), price, period
            )
        }
        return String(
            format: NSLocalizedString(
                "%@ / %@. İptal edilmediği sürece otomatik yenilenir. Dilediğin zaman App Store ayarlarından iptal edebilirsin.",
                comment: ""
            ), price, period
        )
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
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 64, height: 64)
                Image(systemName: "crown.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }

            Text(NSLocalizedString(isSoftPaywall ? "Harika bir rota tamamladın!" : "Pinly Pro'yu Keşfet", comment: ""))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(NSLocalizedString("Reklamsız keşfet, rotalarını GPX ve PDF olarak dışa aktar.", comment: ""))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 36)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity)
        .background(
            // Claude Design "Pinly Seigaiha Uygulama" mockup'ındaki Paywall header'ı — sıcak
            // hero gradyanı (Ana sekme kartıyla aynı, mod bağımsız) + gerçek seigaiha PNG dokusu.
            ZStack {
                PinlyTheme.heroWarmGradient
                GeometryReader { geo in
                    Image("SeigaihaLinesPale")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipShape(Rectangle())
                }
                .opacity(0.55)
                .allowsHitTesting(false)
            }
            .clipped()
            .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Fayda listesi

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Buradaki HER madde bugün ÇALIŞAN bir özellik olmalı. Önceden 3 maddenin
            // 2'si "Yakında" rozetliydi (Çevrimdışı Harita, Topluluk Rotaları) — ücretli
            // bir ürünün fayda listesini var olmayan özelliklerle doldurmak hem App Store
            // review riski (Guideline 2.3.1 / 3.1.2) hem de zayıf bir değer önerisi.
            ProFeatureRow(icon: "nosign", color: PinlyTheme.accent,
                          title: NSLocalizedString("Reklamsız Kullanım", comment: ""),
                          subtitle: NSLocalizedString("Kesintisiz, reklam olmadan keşfet", comment: ""),
                          badge: nil)
            ProFeatureRow(icon: "square.and.arrow.down", color: PinlyTheme.slate,
                          title: NSLocalizedString("GPX Dışa Aktarma", comment: ""),
                          subtitle: NSLocalizedString("Rotanı saat ve harita uygulamalarında kullan", comment: ""),
                          badge: nil)
            ProFeatureRow(icon: "doc.richtext", color: PinlyTheme.primary,
                          title: NSLocalizedString("PDF Gezi Planı", comment: ""),
                          subtitle: NSLocalizedString("Rotanı yazdırılabilir plan olarak indir", comment: ""),
                          badge: nil)
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
                        : yearlySavingsPercent.map {
                            String(format: NSLocalizedString("%%%lld Tasarruf", comment: ""), $0)
                        },
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

            // Otomatik yenileme açıklaması — App Store Guideline 3.1.2 gereği abonelik
            // süresi, yenileme fiyatı ve trial bitişinde ne olacağı satın alma butonuyla
            // AYNI ekranda görünmek zorunda.
            if let renewalDisclosure {
                Text(renewalDisclosure)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            Button {
                Task { await restore() }
            } label: {
                Text(NSLocalizedString("Satın Alımları Geri Yükle", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .disabled(isPurchasing)

            legalFooter

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

    /// Gizlilik Politikası + Kullanım Koşulları — abonelik satan ekranda zorunlu
    /// (App Store Guideline 3.1.2). Adresler `PinlyLegal`'da tek yerde tutulur.
    private var legalFooter: some View {
        HStack(spacing: 6) {
            if let privacy = PinlyLegal.privacyPolicyURL {
                Link(NSLocalizedString("Gizlilik Politikası", comment: ""), destination: privacy)
            }
            if PinlyLegal.privacyPolicyURL != nil, PinlyLegal.termsOfUseURL != nil {
                Text("·")
            }
            if let terms = PinlyLegal.termsOfUseURL {
                Link(NSLocalizedString("Kullanım Koşulları", comment: ""), destination: terms)
            }
        }
        .font(.caption2)
        .foregroundColor(.secondary)
        .padding(.top, 2)
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
            yearlyTrialEligible = status == .eligible
        }
    }

    private func purchaseSelected() async {
        guard let package = selectedPackage else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            analytics.track(.purchaseStarted(product: package.storeProduct.productIdentifier))
            let result = try await purchases.purchase(package: package)
            guard !result.userCancelled else { return }
            let active = EntitlementMapper.isPro(customerInfo: result.customerInfo)
            guard active else {
                errorMessage = NSLocalizedString(
                    "Satın alma tamamlandı ancak Pro erişimi henüz doğrulanamadı. Lütfen Satın Alımları Geri Yükle'yi dene.",
                    comment: ""
                )
                return
            }
            if package.identifier == yearlyPackage?.identifier, hasFreeTrial {
                analytics.track(.trialStarted(product: package.storeProduct.productIdentifier))
            }
            analytics.track(.purchaseCompleted(product: package.storeProduct.productIdentifier))
            // Doğrulanmış CustomerInfo sonucu aynaya hemen yazılır; export gate'i paywall
            // kapanır kapanmaz ikinci bir bekleme/paywall olmadan açılır.
            entitlements.isPro = true
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
