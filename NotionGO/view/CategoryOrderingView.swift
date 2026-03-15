import SwiftUI

struct CategoryOrderingView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @Environment(\.dismissRouteFlow) var dismissRouteFlow

    @State private var goToPicker = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Sırayı belirle")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Hangi sırayla gitmek istiyorsun?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 8)

            Text("Sürükleyerek sırala")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)

            List {
                ForEach(Array(routeManager.selectedCategories.enumerated()), id: \.element) { index, category in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 28, height: 28)
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }

                        Image(systemName: icon(for: category))
                            .foregroundColor(color(for: category))
                            .font(.title3)
                            .frame(width: 30)

                        Text(category)
                            .font(.body)
                            .fontWeight(.medium)

                        Spacer()

                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                .onMove { from, to in
                    routeManager.selectedCategories.move(fromOffsets: from, toOffset: to)
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))

            Button {
                goToPicker = true
            } label: {
                HStack {
                    Text("Mekan Seçimine Geç")
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
        }
        .navigationTitle("Sıralama")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    routeManager.reset()
                    dismissRouteFlow()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
        }
        .navigationDestination(isPresented: $goToPicker) {
            PlacePickerStepView(stepIndex: 0)
                .environmentObject(placeStore)
                .environmentObject(locationManager)
                .environmentObject(routeManager)
        }
    }

    func icon(for category: String) -> String { PlaceStyle.icon(for: category) }
    func color(for category: String) -> Color { PlaceStyle.color(for: category) }
}
