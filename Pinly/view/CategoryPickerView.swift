import SwiftUI

struct CategoryPickerView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @Environment(\.dismiss) var dismiss

    @State private var goToOrdering = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("Ne yapmak istiyorsun?")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Rotana eklemek istediğin kategorileri seç")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 24)
                .padding(.bottom, 20)

                if placeStore.places.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Mekanlar yükleniyor...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(placeStore.allCategories, id: \.self) { category in
                                CategoryCard(
                                    category: category,
                                    isSelected: routeManager.selectedCategories.contains(category)
                                ) {
                                    toggleCategory(category)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 120)
                    }
                }
            }
            .navigationTitle("Rota Oluştur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") {
                        routeManager.reset()
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !routeManager.selectedCategories.isEmpty {
                    Button {
                        goToOrdering = true
                    } label: {
                        HStack {
                            Text("Devam Et")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .background(.regularMaterial)
                }
            }
            .navigationDestination(isPresented: $goToOrdering) {
                CategoryOrderingView()
                    .environmentObject(placeStore)
                    .environmentObject(locationManager)
                    .environmentObject(routeManager)
            }
        }
    }

    private func toggleCategory(_ category: String) {
        withAnimation(.spring(response: 0.3)) {
            if let idx = routeManager.selectedCategories.firstIndex(of: category) {
                routeManager.selectedCategories.remove(at: idx)
            } else {
                routeManager.selectedCategories.append(category)
            }
        }
    }
}

// MARK: - Kategori Kartı

struct CategoryCard: View {
    let category: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? categoryColor : categoryColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(isSelected ? .white : categoryColor)
                }
                Text(category)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? categoryColor : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? categoryColor.opacity(0.12) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? categoryColor : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    var categoryColor: Color { PlaceCategory.from(category).color }
    var icon: String { PlaceCategory.from(category).icon }
}
