import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct AddPlaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager

    @StateObject private var viewModel = AddPlaceViewModel()

    // Haritada Pinle
    @State private var showMapPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(NSLocalizedString("Mekan Bilgileri", comment: ""))) {
                    TextField(NSLocalizedString("Mekan Adı", comment: ""), text: $viewModel.name)
                    Picker(NSLocalizedString("Kategori", comment: ""), selection: $viewModel.category) {
                        ForEach(PlaceCategory.allCases, id: \.rawValue) { cat in
                            Text(cat.rawValue).tag(cat.rawValue)
                        }
                    }
                }

                Section(header: Text(NSLocalizedString("Konum", comment: ""))) {
                    if viewModel.usedCurrentLocation {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(PinlyTheme.primary)
                            Text(NSLocalizedString("Mevcut konum kullanılıyor", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(PinlyTheme.primary)
                            Spacer()
                            Button(NSLocalizedString("Değiştir", comment: "")) {
                                viewModel.usedCurrentLocation = false
                                viewModel.currentCoord = nil
                                viewModel.address = ""
                            }
                            .font(.caption)
                            .foregroundColor(PinlyTheme.danger)
                        }
                    } else {
                        TextField(NSLocalizedString("Adres (Örn: Kadıköy, İstanbul)", comment: ""), text: $viewModel.address)
                            .onChange(of: viewModel.address) {
                                viewModel.handleAddressChanged()
                            }

                        if viewModel.pinnedCoord != nil {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(PinlyTheme.success)
                                Text(NSLocalizedString("Konum haritadan seçildi", comment: ""))
                                    .font(.subheadline)
                                    .foregroundColor(PinlyTheme.success)
                                Spacer()
                                Button(NSLocalizedString("Kaldır", comment: "")) {
                                    viewModel.pinnedCoord = nil
                                    viewModel.pinnedAddress = ""
                                    viewModel.address = ""
                                }
                                .font(.caption)
                                .foregroundColor(PinlyTheme.danger)
                            }
                        }

                        Button {
                            viewModel.fetchCurrentLocation(from: locationManager)
                        } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                Text(NSLocalizedString("Mevcut Konumumu Kullan", comment: ""))
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(PinlyTheme.primary)
                        }

                        Button {
                            showMapPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                Text(NSLocalizedString("Haritada Pinle", comment: ""))
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(PinlyTheme.primary)
                        }
                    }
                }

                Section(header: Text(NSLocalizedString("Fotoğraf", comment: ""))) {
                    PlacePhotoPickerRow(
                        image: viewModel.photoImage,
                        onPicked: { viewModel.setPhoto($0) },
                        onRemove: { viewModel.removePhoto() }
                    )
                }

                Section(header: Text(NSLocalizedString("Notlar", comment: ""))) {
                    TextEditor(text: $viewModel.notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle(NSLocalizedString("Yeni Mekan Ekle", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("İptal", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if viewModel.isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text(NSLocalizedString("Kaydet", comment: ""))
                        }
                    }
                    .disabled(viewModel.name.isEmpty || (!viewModel.usedCurrentLocation && viewModel.address.isEmpty) || viewModel.isSaving)
                }
            }
            .sheet(isPresented: $showMapPicker) {
                MapPinPickerView(initialCoordinate: viewModel.pinnedCoord) { coord, resolvedAddress in
                    viewModel.applyPinnedLocation(coord: coord, resolvedAddress: resolvedAddress)
                }
                .environmentObject(locationManager)
            }
        }
    }

    // MARK: - Kaydet

    private func save() {
        Task {
            await viewModel.save(placeStore: placeStore, context: modelContext)
            dismiss()
        }
    }
}
