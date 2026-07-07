# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Native iOS app — no CLI build or test commands. Everything goes through Xcode:
- Open `NotionGO.xcodeproj` in Xcode. Build: `Cmd+B`, run on simulator: `Cmd+R`.
- No test target exists.
- **Temporary override on `ContentView.swift`** resets `hasSeenOnboarding = false` on every launch for testing. Remove before shipping.

## App Entry Flow

1. `ThemeSelectionView` — first-launch screen where user picks **Ivory & Gilded** (light) or **Obsidian & Muted Gilt** (dark). Saves choice to `@AppStorage("appTheme")`. Shown until `@AppStorage("hasSeenOnboarding")` is set.
2. `PermissionView` / `LocationDeniedView` — shown based on `locationManager.authorizationStatus`.
3. `HomeView` — two cards leading to `PlacesListView` and `MapView`.

## Three Global Managers

Instantiated in `ContentView`, injected as `@EnvironmentObject` everywhere:

- **`PlaceStore`** (`manager/PlaceStore.swift`) — owns `@Published var places: [Place]`. All SwiftData reads/writes go through it. Every mutation must be followed by `placeStore.load(context:)` to re-sync the published array.
- **`LocationManager`** (`manager/locationManager.swift`) — wraps `CLLocationManager`. Two modes: idle (`kCLLocationAccuracyHundredMeters`, stops after one fix) and navigation (`kCLLocationAccuracyBest`, `distanceFilter = 5m`, continuous). Call `startNavigationTracking()` / `stopNavigationTracking()` explicitly.
- **`RouteManager`** (`manager/RouteManager.swift`) — all route state: selected categories/places, `MKPolyline` segments, turn-by-turn steps, navigation progress, arrival events. Call `reset()` when starting a new route flow.

## Route Planning Flow

Presented via `fullScreenCover` from `MapView`:
```
CategoryPickerView → CategoryOrderingView → PlacePickerStepView → RouteSummaryView
```
- `RouteManager.selectedCategories: [String]` (ordered) drives the flow. Category strings are dictionary keys in `selectedPlaces: [String: Place]`.
- `routePlaces` computed property on `RouteManager` returns places in category order.
- `RouteSummaryView` calls `calculateRoutes(from:completion:)` which fires parallel `MKDirections` requests (one per consecutive waypoint pair) and assembles results in order via `DispatchGroup`.
- Navigation thresholds: waypoint arrival at **30 m**, step advance at **20 m**, route deviation recalculation at **75 m** (10-second cooldown).
- To dismiss the entire route flow from deep in the navigation stack, use the custom environment key `\.dismissRouteFlow` (defined in `MapView.swift`).

## Category System

Categories are plain `String` values on `Place`. The canonical string → color/icon mapping exists in **two places that must stay in sync**:
- `model/PlaceStyle.swift` — `PlaceStyle.color(for:)` and `PlaceStyle.icon(for:)`
- `model/Place.swift` — `@Transient var categoryColor` and `@Transient var categoryIcon`

The hardcoded list of selectable categories also lives in `AddPlaceView.categories`. When adding a new category, update all three.

## Theme System

`AppTheme` enum (`view/ThemeSelectionView.swift`) has `.light` ("Ivory & Gilded") and `.dark` ("Obsidian & Muted Gilt"). The user's choice is stored in `@AppStorage("appTheme")`. The rest of the app still uses the original green palette — `appTheme` is available for future full-app theming.

**Ivory & Gilded palette:** primary `#735a36`, accent/CTA `#C8A97E`, background `#FBF9F6`
**Obsidian & Muted Gilt palette:** primary `#C5C9A4`, accent/CTA `#DFE39C`, background `#1A1C19`

## Utility: `Color(hex:)`

`Color(hex: Int, opacity: Double = 1.0)` extension is defined in `Extensions.swift` (module root). Uses `Int` so integer literals resolve without explicit casting.

The original app palette (HomeView, PlacesListView, etc.):
- Dark green (primary/CTA): `0x1a3c1a`
- Medium green (secondary): `0x3a6b3a`
- Background: `0xe9f2e4`

## Data Persistence Pattern

`PlaceStore` loads from SwiftData via `FetchDescriptor<Place>()`. Direct mutations to a `Place` object (e.g. toggling `isVisited`) are saved with `try? modelContext.save()` at the call site, then `placeStore.load()` is called to sync the published array.

## Navigation Tracking

`LocationManager` has two modes:
- **Idle:** `kCLLocationAccuracyHundredMeters`, stops updating after each fix.
- **Navigation:** `kCLLocationAccuracyBest`, `distanceFilter = 5m`, continuous updates.

`RouteSummaryView` calls start/stop automatically. `MapView` calls stop when the route flow is dismissed.
