import SwiftUI

struct ProfileSetupView: View {
    let onComplete: () -> Void

    @Environment(\.profile) private var profileService
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var appleAuth = AppleAuthService.shared
    @State private var firstName = ""
    @State private var lastName  = ""
    @State private var birthYearText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSigningInWithApple = false

    private let currentYear = Calendar.current.component(.year, from: Date())

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        validBirthYear != nil
    }

    private var validBirthYear: Int? {
        guard let year = Int(birthYearText),
              year >= 1900,
              year <= currentYear - 5 else { return nil }
        return year
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero — Claude Design "Pinly Seigaiha Uygulama" mockup'ındaki gerçek
                // seigaiha dokulu daire + küçük primary rozet (birebir; önceki heroGradient
                // dairenin yerine).
                ZStack {
                    Circle()
                        .fill(PinlyTheme.ground)
                        .frame(width: 132, height: 132)
                    Image(PinlyTheme.seigaihaLinesOnPaper(colorScheme))
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(width: 132, height: 132)
                        .clipShape(Circle())
                    Circle()
                        .fill(PinlyTheme.primary)
                        .frame(width: 48, height: 48)
                        .shadow(color: PinlyTheme.primary.opacity(0.3), radius: 10, y: 4)
                    Image(systemName: "person.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(PinlyTheme.onAccent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 44)

                VStack(alignment: .leading, spacing: 28) {
                    // Başlık
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Pinly'ye Hoş Geldin", comment: ""))
                            .font(.largeTitle.bold())
                        Text(NSLocalizedString("Sana özel bir deneyim için kendini tanıt.", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Apple ile Giriş — cihazlar arası aynı hesap/veri için en hızlı yol.
                    // Başarılı olursa Apple'ın verdiği ad-soyadı (varsa) forma otomatik doldurur,
                    // kullanıcı yine de gözden geçirip "Başla"ya kendisi basar (zorla atlamaz).
                    VStack(spacing: 10) {
                        if appleAuth.isSignedIn {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(PinlyTheme.success)
                                Text(NSLocalizedString("Apple ile giriş yapıldı", comment: ""))
                                    .font(.subheadline.weight(.medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(PinlyTheme.success.opacity(0.1)))
                        } else {
                            Button {
                                Task {
                                    isSigningInWithApple = true
                                    await appleAuth.signInWithApple()
                                    isSigningInWithApple = false
                                    if let name = appleAuth.displayName {
                                        let parts = name.split(separator: " ", maxSplits: 1)
                                        if firstName.isEmpty { firstName = parts.first.map(String.init) ?? "" }
                                        if lastName.isEmpty, parts.count > 1 { lastName = String(parts[1]) }
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if isSigningInWithApple {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "apple.logo")
                                    }
                                    Text(NSLocalizedString("Apple ile Giriş Yap", comment: ""))
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black))
                            }
                            .disabled(isSigningInWithApple)
                            if let error = appleAuth.errorMessage {
                                Text(error).font(.caption).foregroundColor(PinlyTheme.danger)
                            }
                        }

                        HStack {
                            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
                            Text(NSLocalizedString("veya elle doldur", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
                        }
                    }

                    // Ad
                    VStack(alignment: .leading, spacing: 10) {
                        PinlyFormLabel(NSLocalizedString("AD", comment: ""))
                        PinlyField(
                            icon: "person",
                            placeholder: NSLocalizedString("Adın", comment: ""),
                            text: $firstName
                        )
                    }

                    // Soyad
                    VStack(alignment: .leading, spacing: 10) {
                        PinlyFormLabel(NSLocalizedString("SOYAD", comment: ""))
                        PinlyField(
                            icon: "person.fill",
                            placeholder: NSLocalizedString("Soyadın", comment: ""),
                            text: $lastName
                        )
                    }

                    // Doğum Yılı
                    VStack(alignment: .leading, spacing: 10) {
                        PinlyFormLabel(NSLocalizedString("DOĞUM YILI", comment: ""))
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .foregroundColor(PinlyTheme.primary)
                                .frame(width: 20)
                            TextField(NSLocalizedString("Örn: 1995", comment: ""), text: $birthYearText)
                                .keyboardType(.numberPad)
                                .onChange(of: birthYearText) { _, v in
                                    if v.count > 4 { birthYearText = String(v.prefix(4)) }
                                }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(PinlyTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(
                                            validBirthYear != nil
                                                ? PinlyTheme.primary.opacity(0.4)
                                                : Color.primary.opacity(0.08),
                                            lineWidth: 1
                                        )
                                )
                        )
                        if !birthYearText.isEmpty && validBirthYear == nil {
                            Text(String(format: NSLocalizedString("Geçerli bir doğum yılı girin (1900–%d)", comment: ""), currentYear - 5))
                                .font(.caption)
                                .foregroundColor(PinlyTheme.accent)
                        }
                    }

                    if showError {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(PinlyTheme.accent)
                            .padding(.top, -10)
                    }

                    // Başla butonu
                    Button {
                        guard isValid, let year = validBirthYear else {
                            errorMessage = NSLocalizedString("Lütfen tüm alanları doldurun.", comment: "")
                            showError = true
                            return
                        }
                        let profile = UserProfile(
                            firstName: firstName.trimmingCharacters(in: .whitespaces),
                            lastName:  lastName.trimmingCharacters(in: .whitespaces),
                            birthYear: year
                        )
                        profileService.save(profile)
                        onComplete()
                    } label: {
                        Text(NSLocalizedString("Başla", comment: ""))
                    }
                    .buttonStyle(PinlyPrimaryButtonStyle())
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.5)

                    // Kişisel bilgi zorunlu değil — kullanıcı değeri görmeden
                    // PII istemek sürtünme yaratır; profil sonradan Profil
                    // sekmesinden tamamlanabilir.
                    Button {
                        onComplete()
                    } label: {
                        Text(NSLocalizedString("Şimdilik Atla", comment: ""))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, -12)
                }
                .padding(24)
            }
        }
        .background(PinlyTheme.groundGradient.ignoresSafeArea())
        .scrollBounceBehavior(.basedOnSize)
    }
}
