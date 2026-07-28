import SwiftUI

// MARK: - ReportRouteSheet
//
// UGC moderasyon şartı (specs/FAZ5_SUPABASE_MIMARI.md "App Review UGC uyum listesi"):
// 4 sebep (spam/uygunsuz/yanlış bilgi/diğer) + opsiyonel ≤280 karakter not.
// Kendi kendine yeterli: `\.social.report(routeId:reason:note:)` çağrısını kendi içinde yapar.
struct ReportRouteSheet: View {
    @Environment(\.social) private var social
    @Environment(\.dismiss) private var dismiss

    let routeId: String
    /// Bildirim başarıyla gönderilince çağrılır (ör. bir "Teşekkürler" toast'u göstermek için).
    var onSubmitted: (() -> Void)? = nil

    @State private var reason: ReportReason = .spam
    @State private var note = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let noteLimit = 280

    private var reasonLabel: (ReportReason) -> String {
        { reason in
            switch reason {
            case .spam: return NSLocalizedString("Spam", comment: "")
            case .inappropriate: return NSLocalizedString("Uygunsuz içerik", comment: "")
            case .wrongInfo: return NSLocalizedString("Yanlış bilgi", comment: "")
            case .other: return NSLocalizedString("Diğer", comment: "")
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("Bu rotayı neden bildiriyorsun?", comment: "")) {
                    Picker(NSLocalizedString("Sebep", comment: ""), selection: $reason) {
                        ForEach([ReportReason.spam, .inappropriate, .wrongInfo, .other], id: \.self) { r in
                            Text(reasonLabel(r)).tag(r)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section(NSLocalizedString("Not (opsiyonel)", comment: "")) {
                    TextField(NSLocalizedString("Detay ekle...", comment: ""), text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: note) { _, newValue in
                            if newValue.count > noteLimit {
                                note = String(newValue.prefix(noteLimit))
                            }
                        }
                    Text("\(note.count)/\(noteLimit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(PinlyTheme.danger)
                }
            }
            .navigationTitle(NSLocalizedString("Rotayı Bildir", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("İptal", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Gönder", comment: "")) { submit() }
                        .disabled(isSubmitting)
                }
            }
        }
    }

    private func submit() {
        isSubmitting = true
        errorMessage = nil
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                try await social.report(routeId: routeId, reason: reason, note: trimmedNote.isEmpty ? nil : trimmedNote)
                isSubmitting = false
                dismiss()
                onSubmitted?()
            } catch {
                isSubmitting = false
                errorMessage = NSLocalizedString("Bildirim gönderilemedi, tekrar dene.", comment: "")
            }
        }
    }
}
