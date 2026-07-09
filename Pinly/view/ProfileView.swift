import SwiftUI

// MARK: - Profil Düzenleme

struct ProfileEditSheet: View {
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName  = ""
    @State private var birthYearText = ""

    private let currentYear = Calendar.current.component(.year, from: Date())

    private var validBirthYear: Int? {
        guard let year = Int(birthYearText),
              year >= 1900,
              year <= currentYear - 5 else { return nil }
        return year
    }

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        validBirthYear != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        PinlyFormLabel(NSLocalizedString("AD", comment: ""))
                        PinlyField(
                            icon: "person",
                            placeholder: NSLocalizedString("Adın", comment: ""),
                            text: $firstName
                        )
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        PinlyFormLabel(NSLocalizedString("SOYAD", comment: ""))
                        PinlyField(
                            icon: "person.fill",
                            placeholder: NSLocalizedString("Soyadın", comment: ""),
                            text: $lastName
                        )
                    }
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

                    Button {
                        guard let year = validBirthYear else { return }
                        UserProfile(
                            firstName: firstName.trimmingCharacters(in: .whitespaces),
                            lastName:  lastName.trimmingCharacters(in: .whitespaces),
                            birthYear: year
                        ).save()
                        onSaved()
                        dismiss()
                    } label: {
                        Text(NSLocalizedString("Kaydet", comment: ""))
                    }
                    .buttonStyle(PinlyPrimaryButtonStyle())
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.5)
                }
                .padding(24)
            }
            .background(PinlyTheme.groundGradient.ignoresSafeArea())
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle(NSLocalizedString("Profili Düzenle", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("Kapat", comment: "")) { dismiss() }
                }
            }
        }
        .onAppear {
            guard let profile = UserProfile.load() else { return }
            firstName = profile.firstName
            lastName = profile.lastName
            birthYearText = String(profile.birthYear)
        }
    }
}
