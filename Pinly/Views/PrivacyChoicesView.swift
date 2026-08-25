import SwiftUI

struct PrivacyChoicesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if ConsentManager.shared.isPrivacyOptionsRequired {
                        Button {
                            ConsentManager.shared.presentPrivacyOptions { error in
                                if let error { errorMessage = error.localizedDescription }
                            }
                        } label: {
                            Label(NSLocalizedString("Reklam Gizlilik Seçenekleri", comment: ""), systemImage: "rectangle.badge.checkmark")
                        }
                    }

                    Button {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    } label: {
                        Label(NSLocalizedString("iOS İzin Ayarlarını Aç", comment: ""), systemImage: "gearshape.fill")
                    }
                } header: {
                    Text(NSLocalizedString("İzinler ve Reklam", comment: ""))
                } footer: {
                    Text(NSLocalizedString("Takip iznini reddetmek temel özellikleri kapatmaz. Gerekli bölgelerde reklam gizlilik seçenekleri burada görünür. Pro kullanıcıya reklam gösterilmez.", comment: ""))
                }

                Section {
                    if let url = PinlyLegal.privacyPolicyURL {
                        Link(destination: url) {
                            Label(NSLocalizedString("Gizlilik Politikası", comment: ""), systemImage: "lock.shield")
                        }
                    }
                    if let url = PinlyLegal.privacyChoicesURL {
                        Link(destination: url) {
                            Label(NSLocalizedString("Gizlilik Tercihleri Yardımı", comment: ""), systemImage: "safari")
                        }
                    }
                    if let url = PinlyLegal.termsOfUseURL {
                        Link(destination: url) {
                            Label(NSLocalizedString("Kullanım Koşulları", comment: ""), systemImage: "doc.text")
                        }
                    }
                    if let url = PinlyLegal.supportURL {
                        Link(destination: url) {
                            Label(NSLocalizedString("Destek", comment: ""), systemImage: "questionmark.circle")
                        }
                    }
                } header: {
                    Text(NSLocalizedString("Belgeler", comment: ""))
                } footer: {
                    if PinlyLegal.privacyPolicyURL == nil {
                        Text(NSLocalizedString("Website bağlantıları bu build için henüz yapılandırılmadı.", comment: ""))
                    }
                }

                Section {
                    Text(NSLocalizedString("V1'de Pinly sunucu hesabı oluşturulmaz. Mekan ve rota verileri cihazda tutulur; uygulamayı silmek yerel uygulama alanını kaldırır. App Store aboneliği ayrıca Apple ayarlarından yönetilir.", comment: ""))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(NSLocalizedString("Veri Silme", comment: ""))
                }
            }
            .navigationTitle(NSLocalizedString("Gizlilik Tercihleri", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("Kapat", comment: "")) { dismiss() }
                }
            }
            .alert(NSLocalizedString("Gizlilik Seçenekleri", comment: ""), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(NSLocalizedString("Tamam", comment: ""), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}
