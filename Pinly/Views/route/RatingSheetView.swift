import SwiftUI
import SwiftData
// MARK: - Rating Sheet

struct RatingSheetView: View {
    let place: Place
    let placeStore: PlaceRepository
    let modelContext: ModelContext
    let onDismiss: () -> Void

    @State private var selectedRating: Int = 0

    var body: some View {
        VStack(spacing: 24) {
            Text(NSLocalizedString("Nasıldı?", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(place.name)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            selectedRating = star
                        }
                    } label: {
                        Image(systemName: star <= selectedRating ? "star.fill" : "star")
                            .font(.system(size: 36))
                            .foregroundColor(star <= selectedRating ? PinlyTheme.ratingStar : .secondary)
                            .scaleEffect(star <= selectedRating ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedRating)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 16) {
                Button(NSLocalizedString("Atla", comment: "")) {
                    onDismiss()
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PinlyTheme.fillMuted)
                .cornerRadius(12)

                Button(NSLocalizedString("Kaydet", comment: "")) {
                    if selectedRating > 0 {
                        place.userRating = selectedRating
                        placeStore.save(context: modelContext)
                    }
                    onDismiss()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selectedRating > 0 ? PinlyTheme.primary : Color.gray)
                .cornerRadius(12)
                .disabled(selectedRating == 0)
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .presentationDetents([.height(300)])
    }
}
