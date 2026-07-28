import SwiftUI

// MARK: - Zoom Geçişleri (Wow #2 — specs/FAZ6_UI_YON.md)
//
// `matchedGeometryEffect` fullScreenCover/sheet SINIRINDAN GEÇMEZ (bilinen SwiftUI
// kısıtı) — kart→detay geçişlerinde KULLANILMAZ. Bunun yerine iOS 18+'ta gerçek
// `NavigationStack` push'larında `navigationTransition(.zoom(sourceID:in:))` kullanılır;
// iOS 17'de sessizce varsayılan push'a düşer. Merkezi kapı: aşağıdaki iki modifier —
// dağınık `if #available` tekrarına boğulmamak için tüm kullanım noktaları bunlardan geçer.

extension View {
    /// Zoom geçişinin KAYNAĞI (kart/satır) — NavigationLink etiketine uygulanır.
    /// iOS 18 altında no-op (varsayılan push davranışı korunur).
    @ViewBuilder
    func pinlyZoomSource<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Zoom geçişinin HEDEFİ (detay ekranı) — `navigationDestination`/`NavigationLink`
    /// hedef view'ına uygulanır. iOS 18 altında no-op.
    @ViewBuilder
    func pinlyZoomDestination<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
