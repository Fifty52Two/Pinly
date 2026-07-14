import SwiftUI

// MARK: - Rota Import View

struct RouteImportView: View {
    let routeImport: RouteImport
    let onConfirm: () -> Void
    let onCancel: () -> Void
    var onSaveToSavedRoutes: (() -> Void)? = nil

    private var places: [PlaceImportData] { routeImport.places }

    var body: some View {
        VStack(spacing: 0) {
            // Başlık
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(PinlyTheme.success.opacity(0.12))
                        .frame(width: 60, height: 60)
                    Image(systemName: routeImport.category.map { $0.icon } ?? "map.fill")
                        .font(.title2)
                        .foregroundColor(PinlyTheme.success)
                }
                .padding(.top, 24)

                if let name = routeImport.name, !name.isEmpty {
                    Text(name)
                        .font(.title3)
                        .fontWeight(.bold)
                    if let cat = routeImport.category {
                        Text(cat.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(PinlyTheme.fillMuted)
                            .cornerRadius(8)
                    }
                } else {
                    Text(String(format: NSLocalizedString("%lld Duraklı Rota Paylaşıldı", comment: ""), places.count))
                        .font(.title3)
                        .fontWeight(.bold)
                    if let cat = routeImport.category {
                        Text(cat.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(PinlyTheme.fillMuted)
                            .cornerRadius(8)
                    }
                }

                Text(NSLocalizedString("Tüm mekanları listenize eklemek ister misiniz?", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Mekan listesi
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(places.enumerated()), id: \.offset) { index, place in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(PlaceCategory.from(place.category).color.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: PlaceCategory.from(place.category).icon)
                                    .font(.body)
                                    .foregroundColor(PlaceCategory.from(place.category).color)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(PlaceCategory.from(place.category).localizedName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(index + 1)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        if index < places.count - 1 {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
            }
            .frame(maxHeight: 260)

            Spacer()

            // Butonlar
            VStack(spacing: 12) {
                Button(action: onConfirm) {
                    Text(NSLocalizedString("Tümünü Ekle", comment: ""))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PinlyTheme.success)
                        .cornerRadius(14)
                }
                if let saveAction = onSaveToSavedRoutes {
                    Button(action: saveAction) {
                        HStack {
                            Image(systemName: "bookmark.fill")
                            Text(NSLocalizedString("Kayıtlı Rotalarıma Ekle", comment: ""))
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.indigo)
                        .cornerRadius(14)
                    }
                }
                Button(action: onCancel) {
                    Text(NSLocalizedString("İptal", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }
}

// MARK: - Swarm Import View

struct SwarmImportView: View {
    let places: [PlaceImportData]
    let currentCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.entitlements) private var entitlements

    private var canAddAll: Bool {
        entitlements.canAddPlace(currentCount: currentCount + places.count - 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(PinlyTheme.warning.opacity(0.12))
                        .frame(width: 60, height: 60)
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                        .foregroundColor(PinlyTheme.warning)
                }
                .padding(.top, 24)

                Text(NSLocalizedString("Swarm Geçmişin Bulundu", comment: ""))
                    .font(.title3)
                    .fontWeight(.bold)

                Text(String(format: NSLocalizedString("%lld benzersiz mekan import edilmeye hazır", comment: ""), places.count))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(places.prefix(50).enumerated()), id: \.offset) { index, place in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(PlaceCategory.from(place.category).color.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: PlaceCategory.from(place.category).icon)
                                    .font(.body)
                                    .foregroundColor(PlaceCategory.from(place.category).color)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                if !place.address.isEmpty {
                                    Text(place.address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        if index < min(places.count, 50) - 1 {
                            Divider().padding(.leading, 68)
                        }
                    }
                    if places.count > 50 {
                        Text(String(format: NSLocalizedString("+ %lld mekan daha", comment: ""), places.count - 50))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 12)
                    }
                }
            }
            .frame(maxHeight: 280)

            Spacer()

            VStack(spacing: 12) {
                if !canAddAll {
                    Text(NSLocalizedString("Ücretsiz limitini aşıyor. Pro'ya geçerek tümünü ekle.", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                Button(action: onConfirm) {
                    Text(canAddAll
                         ? String(format: NSLocalizedString("Tümünü Ekle (%lld)", comment: ""), places.count)
                         : NSLocalizedString("Pro'ya Geç", comment: ""))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PinlyTheme.warning)
                        .cornerRadius(14)
                }
                Button(action: onCancel) {
                    Text(NSLocalizedString("İptal", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }
}
