import SwiftUI
import SwiftData
import CoreLocation

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var placeStore: PlaceStore

    @StateObject private var viewModel = QuickAddViewModel()
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("Konum", comment: "")) {
                    if viewModel.isLocating {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(NSLocalizedString("Konum alınıyor...", comment: ""))
                                .foregroundStyle(.secondary)
                        }
                    } else if locationManager.userLocation != nil {
                        Label(
                            viewModel.address.isEmpty
                                ? NSLocalizedString("Konum hazır", comment: "")
                                : viewModel.address,
                            systemImage: "location.fill"
                        )
                        .foregroundStyle(.green)
                    } else {
                        Label(NSLocalizedString("Konum alınamadı", comment: ""), systemImage: "location.slash")
                            .foregroundStyle(.red)
                    }
                }

                Section(NSLocalizedString("Mekan Bilgisi", comment: "")) {
                    TextField(NSLocalizedString("Mekan adı", comment: ""), text: $viewModel.name)
                    Picker(NSLocalizedString("Kategori", comment: ""), selection: $viewModel.category) {
                        ForEach(PlaceCategory.allCases, id: \.self) { cat in
                            Label(cat.localizedName, systemImage: cat.icon).tag(cat)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Hızlı Mekan Ekle", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: toolbarContent)
        }
        .onAppear { viewModel.observeLocation(locationManager) }
        .sheet(isPresented: $showPaywall) { PaywallView(onDismiss: { showPaywall = false }) }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(NSLocalizedString("İptal", comment: "")) { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(NSLocalizedString("Ekle", comment: "")) { save() }
                .disabled(viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLocating)
        }
    }

    // MARK: - Kaydet

    private func save() {
        let success = viewModel.save(placeStore: placeStore, userLocation: locationManager.userLocation, context: modelContext)
        if success {
            dismiss()
        } else {
            showPaywall = true
        }
    }
}
