import Foundation

/// V1'in sosyal katman için tek açma/kapama noktası.
///
/// Canlı Supabase implementasyonları V1.1 geliştirmesi için kaynakta kalabilir; V1 uygulama
/// ağacında ve ViewModel varsayılanlarında yalnızca bu resolver kullanılmalıdır. Böylece UI'da
/// unutulmuş bir çağrı olsa bile hesap, feed veya yazma isteği oluşmaz.
enum SocialFeaturePolicy {
    static let isEnabledInV1 = false

    static var socialService: SocialServicing {
        NoOpSocialService.shared
    }

    static var sharedRouteService: SharedRouteServicing {
        NoOpSharedRouteService.shared
    }
}
