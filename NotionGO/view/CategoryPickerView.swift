import SwiftUI

struct CategoryPickerView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @Environment(\.dismiss) var dismiss

    @AppStorage("appTheme") private var storedTheme = "light"
    @State private var goToOrdering = false

    private var t: ThemeColors { ThemeColors.make(storedTheme) }

    var body: some View {
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button {
                            routeManager.reset()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(t.subtitle)
                                .padding(10)
                                .background(Circle().fill(t.card))
                                .overlay(Circle().stroke(t.cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text("ROTA OLUŞTUR")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(2)
                            .foregroundColor(t.title)

                        Spacer()

                        // Balance the X button
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 36, height: 36)
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    VStack(spacing: 6) {
                        Text("Ne yapmak istiyorsun?")
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundColor(t.title)
                            .tracking(-0.3)
                        Text("Rotana eklenecek kategorileri seç")
                            .font(.system(size: 13))
                            .foregroundColor(t.subtitle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                    if placeStore.places.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView().tint(t.primary)
                            Text("Mekanlar yükleniyor...")
                                .font(.system(size: 13))
                                .foregroundColor(t.subtitle)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())],
                                spacing: 12
                            ) {
                                ForEach(placeStore.allCategories, id: \.self) { category in
                                    CategoryCard(
                                        category: category,
                                        isSelected: routeManager.selectedCategories.contains(category),
                                        t: t
                                    ) { toggleCategory(category) }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 120)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                if !routeManager.selectedCategories.isEmpty {
                    Button { goToOrdering = true } label: {
                        HStack(spacing: 8) {
                            Text("Devam Et")
                                .font(.system(size: 16, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(t.buttonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(t.accent)
                        .clipShape(Capsule())
                        .shadow(color: t.accent.opacity(0.25), radius: 12, y: 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                    .padding(.top, 10)
                    .background(t.bg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationDestination(isPresented: $goToOrdering) {
                CategoryOrderingView()
                    .environmentObject(placeStore)
                    .environmentObject(locationManager)
                    .environmentObject(routeManager)
            }
        }
        .animation(.spring(response: 0.3), value: routeManager.selectedCategories.count)
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

// MARK: - Category Card

struct CategoryCard: View {
    let category: String
    let isSelected: Bool
    let t: ThemeColors
    let onTap: () -> Void

    var categoryColor: Color { PlaceStyle.color(for: category) }
    var icon: String { PlaceStyle.icon(for: category) }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? t.accent : categoryColor.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? t.buttonText : categoryColor)
                }
                Text(category)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? t.primary : t.subtitle)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? t.accent.opacity(0.1) : t.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? t.accent.opacity(0.5) : t.cardBorder, lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
