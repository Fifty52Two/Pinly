import AuthenticationServices
import CryptoKit
import Supabase
import SwiftUI

// MARK: - AppleAuthService
//
// "Sign in with Apple" → Supabase Auth köprüsü. `SocialConfig.client` (SocialService.swift)
// ile AYNI Supabase client'ı kullanır — kullanıcı daha önce sosyal katmana hiç dokunmadıysa
// anonim oturumu YOKTUR, bu akış onu doğrudan kalıcı bir kimliğe bağlar; anonim oturumu
// VARSA (rota yayınlamış/favlamış ise) Supabase bu oturumu SESSİZCE aynı UID'ye yükseltir
// (id_token ile giriş + aktif anonim oturum kombinasyonu resmi Supabase davranışı) — kullanıcı
// veri kaybetmez.
@MainActor
final class AppleAuthService: NSObject, ObservableObject {
    static let shared = AppleAuthService()

    @Published private(set) var isSignedIn: Bool
    @Published private(set) var displayName: String?
    @Published var errorMessage: String?

    private var currentNonce: String?
    private var continuation: CheckedContinuation<Void, Error>?

    override init() {
        let user = SocialConfig.client.auth.currentUser
        // Anonim oturumlar `is_anonymous == true` döner — gerçek girişi ayırt etmek için.
        isSignedIn = user != nil && user?.isAnonymous == false
        displayName = user?.userMetadata["full_name"]?.stringValue
        super.init()
    }

    func signInWithApple() async {
        errorMessage = nil
        let nonce = Self.randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.continuation = continuation
                controller.performRequests()
            }
        } catch {
            errorMessage = NSLocalizedString("Apple ile giriş başarısız oldu, tekrar dene.", comment: "")
        }
    }

    func signOut() async {
        try? await SocialConfig.client.auth.signOut()
        isSignedIn = false
        displayName = nil
    }

    // MARK: - Nonce yardımcıları (Apple'ın önerdiği standart desen)

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(status == errSecSuccess, "Rastgele nonce üretilemedi: \(status)")
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}

extension AppleAuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                continuation?.resume(throwing: SocialServiceError.publishFailed)
                continuation = nil
                return
            }
            do {
                let session = try await SocialConfig.client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
                )
                // Apple, ad-soyadı SADECE İLK yetkilendirmede verir — bir daha asla göndermez.
                // O yüzden geldiği anda profile yazılır (aksi halde ikinci girişte kaybolur).
                if let fullName = credential.fullName, let given = fullName.givenName {
                    let full = [given, fullName.familyName].compactMap { $0 }.joined(separator: " ")
                    displayName = full
                    _ = try? await SocialConfig.client.auth.update(user: UserAttributes(data: ["full_name": .string(full)]))
                } else {
                    displayName = session.user.userMetadata["full_name"]?.stringValue
                }
                isSignedIn = true
                continuation?.resume()
            } catch {
                continuation?.resume(throwing: error)
            }
            continuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

extension AppleAuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first(where: { $0.activationState == .foregroundActive })?
                .windows.first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}
