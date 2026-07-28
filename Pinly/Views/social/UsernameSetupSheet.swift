import SwiftUI

// MARK: - UsernameSetupSheet
//
// İlk sosyal aksiyondan (yayınlama/favlama) HEMEN ÖNCE gösterilen tek seferlik sheet:
// kullanıcı adı + "Topluluk Kuralları" onay kutusu. Ayrı bir ekran/akış DEĞİL — App Review
// UGC şartının "yayınlama anında tek onay" maddesini karşılar (specs/FAZ5_SUPABASE_MIMARI.md).
//
// Tamamen kendi kendine yeterli: `\.social.setUsername(_:)` çağrısını kendi içinde yapar,
// başarılı olursa `onSuccess` ile çağırana haber verir. Böylece hem SavedRoutesViewModel
// (yayınlama) hem CommunityFeedViewModel (favlama) aynı sheet'i, kendi "bekleyen aksiyon"
// mantıklarıyla paylaşabilir.
struct UsernameSetupSheet: View {
    @Environment(\.social) private var social
    @Environment(\.dismiss) private var dismiss

    /// Kullanıcı adı başarıyla kaydedilince çağrılır — çağıran taraf bekleyen aksiyonu
    /// (publish/favorite) burada devam ettirir.
    let onSuccess: () -> Void

    @State private var username = ""
    @State private var agreedToGuidelines = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private static let usernamePattern = "^[a-z0-9_]{3,20}$"

    private var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private var isValidUsername: Bool {
        trimmedUsername.range(of: Self.usernamePattern, options: .regularExpression) != nil
    }

    private var canSubmit: Bool {
        isValidUsername && agreedToGuidelines && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Topluluğa Katıl", comment: ""))
                            .font(.title2.bold())
                        Text(NSLocalizedString("Rotalarını paylaşmak ve favorilemek için bir kullanıcı adı seç. Gerçek adın gösterilmez.", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("Kullanıcı Adı", comment: ""))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        TextField(NSLocalizedString("orn_gezgin34", comment: ""), text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(PinlyTheme.fillMuted))
                        Text(NSLocalizedString("3-20 karakter, sadece küçük harf/rakam/alt çizgi (_).", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Button {
                        agreedToGuidelines.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: agreedToGuidelines ? "checkmark.square.fill" : "square")
                                .foregroundColor(agreedToGuidelines ? PinlyTheme.primary : .secondary)
                                .font(.title3)
                            Text(NSLocalizedString("Topluluk kurallarını okudum ve kabul ediyorum: spam, taciz veya yanıltıcı içerik paylaşmayacağım. Kural dışı içerikler bildirilebilir ve 24 saat içinde incelenir.", comment: ""))
                                .font(.caption)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(PinlyTheme.danger)
                    }

                    Button {
                        submit()
                    } label: {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text(NSLocalizedString("Devam Et", comment: ""))
                        }
                    }
                    .buttonStyle(PinlyPrimaryButtonStyle())
                    .disabled(!canSubmit)
                }
                .padding(20)
            }
            .background(PinlyTheme.groundGradient)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("İptal", comment: "")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func submit() {
        guard canSubmit else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await social.setUsername(trimmedUsername)
                isSaving = false
                dismiss()
                onSuccess()
            } catch {
                isSaving = false
                errorMessage = NSLocalizedString("Bu kullanıcı adı alınamadı. Başka bir tane dene.", comment: "")
            }
        }
    }
}
