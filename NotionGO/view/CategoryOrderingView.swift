import SwiftUI

struct CategoryOrderingView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @Environment(\.dismissRouteFlow) var dismissRouteFlow

    @AppStorage("appTheme") private var storedTheme = "light"
    @State private var goToPicker = false

    private var t: ThemeColors { ThemeColors.make(storedTheme) }

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    // Back handled by NavigationStack
                    Spacer()
                    Text("SIRALAMA")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(t.title)
                    Spacer()
                    Button {
                        routeManager.reset()
                        dismissRouteFlow()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(t.subtitle)
                            .padding(10)
                            .background(Circle().fill(t.card))
                            .overlay(Circle().stroke(t.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Sırayı belirle")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(t.title)
                        .tracking(-0.3)
                    Text("Hangi sırayla gitmek istiyorsun?")
                        .font(.system(size: 13))
                        .foregroundColor(t.subtitle)
                    Text("SÜRÜKLEYEREK SIRALA")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(2)
                        .foregroundColor(t.subtitle.opacity(0.45))
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                List {
                    ForEach(Array(routeManager.selectedCategories.enumerated()), id: \.element) { index, category in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(t.accent)
                                    .frame(width: 28, height: 28)
                                Text("\(index + 1)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(t.buttonText)
                            }

                            ZStack {
                                Circle()
                                    .fill(PlaceStyle.color(for: category).opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: PlaceStyle.icon(for: category))
                                    .font(.system(size: 14))
                                    .foregroundColor(PlaceStyle.color(for: category))
                            }

                            Text(category)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(t.title)

                            Spacer()

                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 14))
                                .foregroundColor(t.subtitle.opacity(0.4))
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(t.card)
                        .listRowSeparatorTint(t.separator)
                    }
                    .onMove { from, to in
                        routeManager.selectedCategories.move(fromOffsets: from, toOffset: to)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))

                Button { goToPicker = true } label: {
                    HStack(spacing: 8) {
                        Text("Mekan Seçimine Geç")
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
                .padding(.bottom, 40)
                .padding(.top, 10)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $goToPicker) {
            PlacePickerStepView(stepIndex: 0)
                .environmentObject(placeStore)
                .environmentObject(locationManager)
                .environmentObject(routeManager)
        }
    }
}
