import SwiftUI

struct DiagnosticsView: View {
    @State private var log: [String] = DiagnosticsCollector.shared.log
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if log.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 48))
                            .foregroundColor(PinlyTheme.success)
                        Text(NSLocalizedString("Tanılama günlüğü boş", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("Crash veya takılma tespit edilmedi.", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PinlyTheme.groundGradient)
                } else {
                    List {
                        ForEach(Array(log.enumerated()), id: \.offset) { _, entry in
                            Text(entry)
                                .font(.caption.monospaced())
                                .foregroundColor(.primary)
                                .listRowBackground(PinlyTheme.surface)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(PinlyTheme.groundGradient)
                }
            }
            .navigationTitle(NSLocalizedString("Tanılama Günlüğü", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !log.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(NSLocalizedString("Temizle", comment: "")) {
                            showClearConfirm = true
                        }
                        .foregroundColor(PinlyTheme.danger)
                    }
                }
            }
            .alert(NSLocalizedString("Günlüğü Temizle", comment: ""), isPresented: $showClearConfirm) {
                Button(NSLocalizedString("Temizle", comment: ""), role: .destructive) {
                    DiagnosticsCollector.shared.clearLog()
                    log = []
                }
                Button(NSLocalizedString("İptal", comment: ""), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("Tüm tanılama kayıtları silinecek.", comment: ""))
            }
        }
    }
}
