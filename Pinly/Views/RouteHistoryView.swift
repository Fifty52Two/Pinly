import SwiftUI
import SwiftData

// MARK: - Rota Geçmişi

struct RouteHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.routeMemories) private var routeMemories
    @Query(sort: \RouteHistory.date, order: .reverse) private var histories: [RouteHistory]

    // Wow #2: kart → MemoryDetailView zoom geçişi (iOS 18+, specs/FAZ6_UI_YON.md).
    // Eskiden .sheet(item:) idi — .zoom yalnızca gerçek NavigationStack push'larında
    // çalıştığı için akış push'a çevrildi (iOS 17'de fallback = varsayılan push).
    @Namespace private var zoomNamespace

    var body: some View {
        NavigationStack {
            Group {
                if histories.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(histories) { history in
                            NavigationLink(value: history) {
                                if history.memoryPhotos.isEmpty {
                                    RouteHistoryRow(history: history)
                                } else {
                                    MemoryHistoryCard(history: history, routeMemories: routeMemories)
                                }
                            }
                            .pinlyZoomSource(id: history.id, in: zoomNamespace)
                            .listRowBackground(PinlyTheme.surface)
                        }
                        .onDelete(perform: deleteHistories)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PinlyTheme.groundGradient)
            .navigationTitle(NSLocalizedString("Rota Geçmişi", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationDestination(for: RouteHistory.self) { history in
                MemoryDetailView(history: history, routeMemories: routeMemories)
                    .pinlyZoomDestination(id: history.id, in: zoomNamespace)
            }
        }
    }

    /// Anı fotoğraf klasörünü de siler — `RouteHistory` kaydı silinince
    /// `RouteMemories/<historyID>/` yetim kalmamalı.
    private func deleteHistories(at offsets: IndexSet) {
        for index in offsets {
            let history = histories[index]
            routeMemories.deleteAll(historyID: history.id)
            modelContext.delete(history)
        }
        try? modelContext.save()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text(NSLocalizedString("Henüz rota tamamlanmadı", comment: ""))
                .font(.title3)
                .fontWeight(.semibold)
            Text(NSLocalizedString("Bir rota tamamladığında burada görünecek.", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Foto'lu Kayıt Kartı (Anı Günlüğü)

private struct MemoryHistoryCard: View {
    let history: RouteHistory
    let routeMemories: RouteMemoryStoring

    private var memoryPhotos: [RouteMemoryPhoto] { history.memoryPhotos }

    private var coverImage: UIImage? {
        guard let first = memoryPhotos.first else { return nil }
        return routeMemories.load(fileName: first.fileName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .bottomLeading) {
                        if memoryPhotos.count > 1 {
                            Text("+\(memoryPhotos.count - 1)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.5), in: Capsule())
                                .padding(8)
                        }
                    }
                    .clipped()
            }

            HStack {
                Text(history.routeName)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(history.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 0) {
                HistoryStatPill(icon: "figure.walk", value: history.formattedDistance, color: PinlyTheme.primary)
                HistoryStatPill(icon: "clock", value: history.formattedDuration, color: PinlyTheme.success)
                if history.stepCount > 0 {
                    HistoryStatPill(icon: "shoeprints.fill", value: "\(history.stepCount) adım", color: PinlyTheme.warning)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Fotosuz Eski Kayıt Satırı

private struct RouteHistoryRow: View {
    let history: RouteHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(history.routeName)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(history.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Mekan listesi
            if !history.placeNames.isEmpty {
                Text(history.placeNames.joined(separator: " → "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // İstatistikler
            HStack(spacing: 0) {
                HistoryStatPill(icon: "figure.walk", value: history.formattedDistance, color: PinlyTheme.primary)
                HistoryStatPill(icon: "clock", value: history.formattedDuration, color: PinlyTheme.success)
                if history.stepCount > 0 {
                    HistoryStatPill(icon: "shoeprints.fill", value: "\(history.stepCount) adım", color: PinlyTheme.warning)
                }
                if history.averageSpeedKmh > 0 {
                    HistoryStatPill(icon: "speedometer", value: String(format: "%.1f km/s", history.averageSpeedKmh), color: PinlyTheme.primaryWarm)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct HistoryStatPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(value)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .padding(.trailing, 6)
    }
}
