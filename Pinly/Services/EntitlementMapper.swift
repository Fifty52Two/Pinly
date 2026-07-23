import RevenueCat

// MARK: - EntitlementMapper

/// RevenueCat `CustomerInfo` → `isPro` kararının saf çekirdeği (SDK'dan ayrı test edilebilir).
enum EntitlementMapper {
    static let entitlementID = "pro"

    static func isPro(customerInfo: CustomerInfo) -> Bool {
        customerInfo.entitlements.all[entitlementID]?.isActive == true
    }
}
