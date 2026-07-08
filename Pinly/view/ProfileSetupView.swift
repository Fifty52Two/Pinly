import SwiftUI

struct ProfileSetupView: View {
    let onComplete: () -> Void

    @State private var firstName = ""
    @State private var lastName  = ""
    @State private var birthYearText = ""
    @State private var showError = false
    @State private var errorMessage = ""

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
                // Hero illüstrasyon
                ZStack {
                    Image("illus_trip_cuate")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .clipped()
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 28) {
                    // Başlık
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Pinly'ye Hoş Geldin", comment: ""))
                            .font(.largeTitle.bold())
                        Text(NSLocalizedString("Sana özel bir deneyim için kendini tanıt.", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
                            Text(NSLocalizedString("Geçerli bir doğum yılı girin (1900–\(currentYear - 5))", comment: ""))
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
                        profile.save()
                        onComplete()
                    } label: {
                        Text(NSLocalizedString("Başla", comment: ""))
                    }
                    .buttonStyle(PinlyPrimaryButtonStyle())
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.5)
                }
                .padding(24)
            }
        }
        .background(PinlyTheme.groundGradient.ignoresSafeArea())
        .scrollBounceBehavior(.basedOnSize)
    }
}
