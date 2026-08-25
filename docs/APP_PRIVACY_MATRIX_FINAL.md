# Pinly V1 — App Privacy Matrix Final

Durum: **repo/code final inventory; App Store Connect + provider dashboard + Xcode Organizer Privacy Report teyidi bekliyor**. Bu yüzden submission gate PASS değildir.

Apple açısından “collected”, verinin cihaz dışına aktarılıp isteği gerçek zamanda karşılamak için gerekenden uzun süre geliştirici veya üçüncü tarafça erişilebilir tutulmasıdır. Yalnız cihazda kalan SwiftData/UserDefaults/Documents/HealthKit içeriği bu tanımda developer collection sayılmaz; üçüncü taraf SDK davranışı yine beyan edilmelidir.

| Data Type | Collected? | Linked? | Tracking? | Purpose | SDK / Code Source | Stored Where | Retention | App Store Connect Answer | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| Name, birth year, optional profile | No in V1 | No | No | Local profile/personalization | `ProfileService`, `UserProfile` | UserDefaults + local photo file | User deletes/uninstalls | Not collected | V1 NoOp social composition; no profile upload |
| Places, addresses, private notes, ratings, saved routes | No automatic collection | No | No | App functionality | SwiftData models, import/export services | Device app container | User deletes/uninstalls | Other User Content: not collected | Social hard-off; sharing only explicit user action |
| Place/profile/memory photos | No automatic collection | No | No | App functionality | PhotosPicker/camera, `PlacePhotoService`, route memory | Device Documents | Record deletion/uninstall | Photos/Videos: not collected | Downscaled local files; share sheet is intentional user transfer |
| Precise location and route position | No by Pinly backend | No | No | Route planning/navigation/Nearby | CoreLocation, MapKit, RouteManager | Live memory + local route state/history | Local record deletion/uninstall | Precise Location: not collected by developer | No location analytics parameter; Apple service behavior is governed by Apple |
| Health steps and walking/running distance | No | No | No | Completed-route stats | `HealthKitService` | HealthKit + local aggregate in route history | Local record deletion/uninstall | Health & Fitness: not collected | Read-only types; no update usage description; no analytics parameter |
| Product interaction | Yes | Conservatively yes | No | Analytics and ad measurement | Firebase Analytics, Google Mobile Ads | Provider systems | Provider/dashboard policy | Product Interaction: collected; linked; Analytics + Third-Party Advertising | Runtime event set contains no coordinates/notes/private route names |
| Device ID | Yes | Yes | Yes when ATT-authorized ad path uses IDFA | Analytics, ads, fraud/measurement | Firebase installation IDs, Crashlytics, AdMob IDFV/IDFA | Provider systems | Provider/dashboard policy | Device ID: collected, linked, tracking; Analytics + Third-Party Advertising | ATT + AdMob widest production behavior; `NSPrivacyTracking=true` |
| Coarse location | Yes, may be inferred | Yes conservatively | No | Regional consent, ads, analytics | AdMob/UMP via IP or SDK signals | Google systems | Google policy/settings | Coarse Location: collected, linked; Analytics + Third-Party Advertising | GPS coordinate is not added to ad request by Pinly |
| Advertising data | Yes | Yes conservatively | No in SDK manifest row | Ad delivery/measurement | Google Mobile Ads | Google systems | Google policy/settings | Advertising Data: collected, linked; Third-Party Advertising + Analytics | AdMob bundled manifest + request flow |
| Purchase history / entitlement | Yes | No under current anonymous SDK configuration | No | Purchase/restore/App functionality | StoreKit + RevenueCat | Apple/RevenueCat systems; local entitlement mirror | Provider/account policy | Purchase History: collected, not linked, App Functionality | No custom user ID is configured in production code |
| Crash data | Yes | No conservatively | No | Reliability | Firebase Crashlytics | Firebase systems | Firebase dashboard policy | Crash Data: collected, not linked, App Functionality + Analytics | Firebase config enabled only when client config exists |
| Performance data | Yes | No conservatively | No | Reliability/ad performance | Firebase/Google SDKs; local MetricKit diagnostics | Provider systems; local MetricKit summary | Provider policy; local max 50 lines | Performance Data: collected, not linked, Analytics + Third-Party Advertising | `DiagnosticsService` local summary + SDK manifests |
| Other diagnostic data | Yes | No conservatively | No | Reliability/ad diagnostics | Crashlytics/Google Mobile Ads | Provider systems | Provider policy | Other Diagnostic Data: collected, not linked, App Functionality + Analytics + Third-Party Advertising | Privacy manifest widest purposes |
| UMP consent and ATT status | Yes/provider managed | Device/app linked may apply | ATT controls tracking eligibility | Consent/compliance | Google UMP, AppTrackingTransparency | OS/Google SDK state | Provider/OS policy | Covered under identifiers/advertising interaction; verify Organizer report | Ads do not start before `canRequestAds` |
| Support email/message | User-initiated only | Yes if email identifies user | No | Customer support | Future mail/support channel | Mail/support provider | Support/legal policy | Review optional-disclosure conditions; disclose Contact Info if routinely retained | Production support address not yet supplied |
| Supabase profile/community content | No in V1 | No | No | Disabled | Real services remain in source; composition root resolves NoOp | No V1 runtime storage | N/A | Not collected | `SocialFeaturePolicy`, NoOp tests, ignored sharedroute path |

## Required-reason APIs

- Direct app use: UserDefaults for app-container preferences.
- Declared reason: `CA92.1`.
- File timestamp, disk space, system boot time and active keyboard APIs were not found in app source during audit.
- Third-party SDK manifests merge at archive time; Organizer report remains authoritative evidence.

## Analytics privacy contract

Allowed funnel events:

`onboarding_complete`, `first_place_added`, `route_created`, `route_started`, `route_completed`, `route_shared`, `paywall_viewed`, `purchase_started`, `purchase_completed`, `restore_completed`, `export_gpx`, `export_pdf`.

Allowed parameters are controlled enum/source/product identifiers. Never add precise coordinates, HealthKit values, private notes, user-created route/place names, photo metadata, email, name or birth year.

## Blocking verification

1. Archive exact RC build; export Organizer Privacy Report.
2. Compare every merged SDK row with this matrix and `Pinly/PrivacyInfo.xcprivacy`.
3. Verify Firebase Analytics/Crashlytics data and retention settings.
4. Verify AdMob/UMP regional, child/under-age, IDFA and data settings.
5. Verify RevenueCat project has no custom user identity mapping that changes “linked” status.
6. Enter App Store Connect answers manually; second-person review.
7. Do not change `NSPrivacyTracking` merely to silence a discrepancy—resolve actual SDK/request behavior.

## Primary references

- [Apple App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple required-reason API guidance](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Firebase privacy and security](https://firebase.google.com/support/privacy)
- [Google Mobile Ads iOS targeting](https://developers.google.com/admob/ios/targeting)
- [Google advertising technologies](https://policies.google.com/technologies/ads)
- [RevenueCat privacy policy](https://www.revenuecat.com/privacy-policy)
