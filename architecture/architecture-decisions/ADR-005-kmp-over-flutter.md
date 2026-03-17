# ADR-005: Use Kotlin Multiplatform with Jetpack Compose for Mobile Applications

- **Date**: 2026-03-14
- **Status**: Accepted
- **Deciders**: RPMS Architecture Team
- **Consulted**: Mobile engineering, plantation field operations team, hardware/IoT specialists
- **Related**: ADR-002 (Spring Boot + Quarkus — Kotlin/Java backend alignment), ADR-004 (Angular — web dashboard is separate from mobile)

## Context and Problem Statement

RPMS requires mobile applications for two primary user roles — tappers and supervisors — who work in rubber plantation fields with limited connectivity, diverse Android devices, and heavy dependence on hardware peripherals. The mobile framework choice is not a typical "which cross-platform tool" decision because the application's core value depends on deep integration with physical hardware that most mobile applications never touch.

The specific hardware and environmental requirements that dominate this decision are:

**Bluetooth Low Energy (BLE) — simultaneous multi-device connections in the field.** A tapper's morning shift involves connecting to three BLE devices concurrently: a smart tapping knife (streaming cut angle, depth, and count data per tree), a digital collection scale (transmitting latex weight at collection points), and a GPS wearable band (continuous location tracking). These connections must survive walking through a plantation with trees, rain, and variable signal strength. BLE connections must reconnect automatically after signal drops without user intervention. Android's `BluetoothGatt` API provides fine-grained control over connection parameters (MTU size, connection interval, PHY selection) that is critical for reliable field operation. The tapper cannot troubleshoot Bluetooth issues — the app must handle everything silently.

**NFC — high-frequency tag scanning during tapping rounds.** Each tapper scans 300-500 tree NFC tags per shift. The scan must be instantaneous — tap the phone to the tree tag, see the tree profile, log the tapping data, move to the next tree in under 3 seconds. This requires background NFC detection (`NfcAdapter.enableReaderMode`) so the tapper doesn't need to open the app for each scan. Some plantations use NFC-F (FeliCa) or NFC-V (ISO 15693) tags alongside standard NDEF, requiring tag-type-specific handling that goes beyond simple NDEF reading. The app also writes data back to tags — updating the last scan timestamp and scan count on the tag itself.

**CameraX — photo capture with real-time AR overlay.** Supervisors photograph tapping cuts for AI quality analysis. The app must overlay guide lines on the camera preview showing the ideal cut angle and panel boundaries (AR-style), then capture the photo with metadata (GPS coordinates, tree ID, timestamp). The AI analysis pipeline requires specific image preprocessing (resolution, format, orientation correction) before upload to MinIO. Android's CameraX API provides the `ImageAnalysis` use case for frame-level processing that an AR overlay requires.

**Continuous GPS tracking — 6-hour shift recording as LineString geometry.** During a tapping shift (04:30–11:30), the app records the tapper's GPS position every 10 seconds, building a `GEOMETRY(LineString, 4326)` that matches the PostGIS column in the database. This requires a `ForegroundService` with a persistent notification on Android to prevent the OS from killing the process during a 6+ hour background operation. Battery optimization settings vary wildly across Android manufacturers (Samsung, Xiaomi, Oppo, Vivo each have proprietary battery management that aggressively kills background processes). The implementation must handle OEM-specific workarounds.

**Biometric integration — third-party SDK for attendance.** Plantation attendance uses fingerprint matching against locally-stored templates via third-party biometric hardware SDKs (Suprema, ZKTeco, Mantra). These vendors provide native Android SDKs (Java/Kotlin libraries with `.aar` files) — not Flutter plugins, not web APIs, not cross-platform abstractions. Integration requires direct Android API access.

**Geofence-based automatic attendance.** The Attendance Service (Module 6) supports GPS geofence auto-detection. When the tapper's phone enters a field's geofence polygon, the app automatically triggers an attendance check-in scan event. Android's `GeofencingClient` handles this natively with battery-efficient monitoring. The geofence polygons are PostGIS `GEOMETRY(Polygon, 4326)` synced from the backend and stored locally in SQLDelight.

**Offline-first operation with background sync.** Plantation connectivity is unreliable — cellular coverage is patchy in rural estates, and Wi-Fi is only available at office buildings. The app must function fully offline: scan NFC tags, record tapping data, capture photos, log attendance, track GPS — all stored locally in SQLDelight. When connectivity returns, Android's `WorkManager` schedules background sync with exponential backoff and network-type constraints (sync only on Wi-Fi for photo uploads, sync on any connection for critical data). The sync engine must handle conflict resolution (server timestamp authority with last-write-wins and conflict logging).

**Android-only for now, iOS as a future possibility.** The plantation workforce uses Android phones — typically mid-range Samsung, Xiaomi, or Oppo devices running Android 10-14. There is no current iOS requirement. However, if RPMS expands to serve plantation management companies whose executives use iPhones, an iOS app may be needed in 1-2 years for the supervisor and manager roles (not for tappers, who will remain on Android).

## Decision Drivers

1. **Native BLE reliability** — Simultaneous multi-device BLE connections with fine-grained connection parameter control
2. **NFC depth** — Background detection, multi-tag-type support (NDEF, NFC-F, NFC-V), read and write operations
3. **Camera with frame-level processing** — CameraX `ImageAnalysis` for AR overlay and preprocessing
4. **Background GPS with ForegroundService** — 6-hour continuous tracking surviving OEM battery optimization
5. **Third-party native SDK integration** — Biometric vendor `.aar` libraries with no cross-platform wrapper
6. **Offline-first with native sync** — SQLDelight local database, WorkManager background sync, conflict resolution
7. **Backend team alignment** — Kotlin/Java shared knowledge with the Spring Boot + Quarkus backend
8. **iOS future path** — Ability to share 60-70% of business logic when iOS is needed without full rewrite
9. **Performance on mid-range devices** — Smooth UI on Samsung A-series and Xiaomi Redmi-class hardware
10. **Developer productivity** — Hot reload, modern UI toolkit, type-safe API client

## Considered Options

1. **Kotlin Multiplatform (KMP) + Jetpack Compose** — Shared business logic in Kotlin, native Android UI with Compose, future iOS via SwiftUI
2. **Flutter (Dart)** — Cross-platform UI framework with plugin-based native access
3. **React Native** — JavaScript-based cross-platform with native bridge
4. **Native Android (Kotlin) only** — No cross-platform, no shared code, no iOS path

## Decision Outcome

**Chosen option: Kotlin Multiplatform with Jetpack Compose**, because it provides direct, unmediated access to every Android API that RPMS's field hardware requires (BLE, NFC, CameraX, ForegroundService, biometric SDKs) — without the plugin abstraction layer that causes reliability problems in cross-platform frameworks — while sharing 60-70% of business logic (domain models, API client, offline database, sync engine, validation) for a future iOS app via the same Kotlin codebase.

The decisive factor is that RPMS is not a typical mobile application where UI rendering is the main concern. It is a **hardware-integrated field operations tool** where the critical path runs through BLE radios, NFC controllers, camera sensors, and GPS chipsets. In this context, any abstraction layer between the application code and the hardware API is a reliability risk, not a productivity gain.

### Confirmation

This decision will be confirmed successful if:
- The tapper app maintains simultaneous BLE connections to a smart knife, digital scale, and GPS band for a full 6-hour shift without user-visible disconnections
- NFC tree tag scanning averages under 500ms from tap to tree profile display, including local SQLDelight lookup
- GPS route recording runs for 6+ hours via ForegroundService without being killed by battery optimization on Samsung and Xiaomi test devices
- The KMP shared module (domain models, Ktor API client, SQLDelight schemas, sync engine) compiles as both an Android library (AAR) and a JVM library (for unit testing on desktop)
- Offline operation covers the full tapper workflow: NFC scan → tapping data entry → photo capture → attendance check-in → GPS tracking — all without connectivity
- When iOS development begins, the shared module requires zero modification — only the SwiftUI presentation layer is written new

## Pros and Cons of the Options

### Kotlin Multiplatform + Jetpack Compose (Selected)

Kotlin Multiplatform (KMP) is JetBrains' technology for sharing Kotlin code across platforms (Android, iOS, JVM, JS, Native). The shared code compiles to each platform's native format — Android JAR/AAR, iOS Framework, JVM bytecode. Jetpack Compose is Google's modern declarative UI toolkit for Android, the official recommended approach for new Android development.

**Pros:**

- **Zero abstraction over Android hardware APIs.** The Android app calls `BluetoothGatt`, `NfcAdapter`, `CameraX`, `FusedLocationProviderClient`, and `WorkManager` directly — the same APIs that Google's own apps use. There is no plugin bridge, no method channel, no platform channel, no serialization overhead between Dart/JS and Kotlin. When the BLE connection to the smart knife drops in the middle of a tree row, the app handles it with Android's native `onConnectionStateChange` callback immediately — not through a plugin that may or may not forward the event correctly. For a field tool where hardware reliability is the entire value proposition, this is non-negotiable.

- **BLE multi-device with connection parameter control.** Android's `BluetoothGatt` API exposes `requestMtu()`, `requestConnectionPriority()`, `setPreferredPhy()`, and connection state callbacks per device. When a tapper walks between tree rows and the smart knife signal weakens, the app can switch to `CONNECTION_PRIORITY_HIGH` for faster reconnection, then back to `CONNECTION_PRIORITY_BALANCED` to save battery. Flutter's `flutter_blue_plus` and `flutter_reactive_ble` plugins do not expose all of these parameters, and their event delivery for connection state changes is less reliable under rapid connect/disconnect cycles in the field.

- **NFC beyond NDEF.** Android's `NfcAdapter.enableReaderMode` supports NFC-A, NFC-B, NFC-F (FeliCa), and NFC-V (ISO 15693) in addition to NDEF. The app can read raw byte blocks from custom tag formats, write data back to tags (scan count, last scan timestamp), and handle tag presence detection for reliable read confirmation. Flutter's NFC plugins (`nfc_manager`, `flutter_nfc_kit`) support NDEF well but have incomplete or inconsistent support for non-NDEF tag types and write operations — exactly the features RPMS needs for its existing NFC tag infrastructure.

- **CameraX with ImageAnalysis.** The supervisor's photo capture screen overlays AR guide lines (ideal cut angle, panel boundary markers) on the live camera preview. This requires processing each camera frame in real-time via CameraX's `ImageAnalysis` use case — detecting the tapping cut in the frame and positioning the overlay relative to it. Flutter's camera plugin does not expose frame-level processing; you would need a platform channel to pass image buffers between Dart and Kotlin on every frame — introducing latency and complexity that defeats the purpose.

- **ForegroundService for GPS tracking.** Android requires a `ForegroundService` with a persistent notification for long-running background work. The RPMS GPS tracker runs for 6+ hours, recording positions every 10 seconds. This requires handling Doze mode exemptions, OEM battery optimization workarounds (Samsung's "sleeping apps," Xiaomi's "battery saver," Oppo's "auto-launch manager"), and graceful degradation if the user force-stops the service. In Kotlin, these are standard Android patterns with extensive documentation. In Flutter, background execution relies on plugins like `flutter_background_service` or `workmanager` — which are community-maintained wrappers around the same Android APIs, adding a failure point without adding value.

- **Third-party biometric SDKs integrate directly.** Suprema, ZKTeco, and Mantra provide native Android SDKs as `.aar` files with Java/Kotlin APIs. In a KMP Android app, these are added as Gradle dependencies and called directly. In Flutter, each SDK would require a custom platform channel wrapper — a significant development effort per vendor with ongoing maintenance as SDK versions update. Since biometric vendor SDKs are updated infrequently and often lack documentation, debugging a Flutter wrapper around an already-opaque SDK compounds the difficulty.

- **Shared KMP module for iOS reuse.** The `shared/` module contains domain models (60+ entities as Kotlin data classes), the Ktor HTTP client (API services for all 6 modules), SQLDelight schemas (offline database with compile-time SQL verification), the sync engine (offline queue, conflict resolution), and validation rules. This module compiles to an Android library today and can target an iOS Framework in the future. When iOS development begins, the developer writes only the SwiftUI presentation layer and platform-specific hardware integrations (CoreBluetooth, CoreNFC, AVFoundation) — the business logic, API client, and offline database are already done.

- **Kotlin ↔ Java interoperability with the backend.** The backend team writes Java 21 with Spring Boot and Quarkus. Kotlin is fully interoperable with Java — the shared KMP module's domain models and DTOs can mirror the backend's Java records. A backend developer can review and contribute to the mobile shared module without learning a new language (Dart, JavaScript, Swift). Serialization formats (kotlinx.serialization with JSON) align with the backend's Jackson JSON serialization, ensuring DTO compatibility.

- **Jetpack Compose is the official Android UI future.** Google has declared Compose as the recommended approach for new Android UI development. Material 3 components, adaptive layouts, and new Android features are Compose-first. Building RPMS's Android UI in Compose ensures long-term compatibility with Android platform evolution. The UI is declarative, composable, and state-driven — similar in philosophy to Angular's component model and React's hooks, providing conceptual alignment across the frontend stack.

- **SQLDelight compile-time SQL verification.** Unlike Room (Android-only) or Hive (Flutter's local DB), SQLDelight verifies SQL queries against the schema at compile time. If a column name changes in the schema, the build fails — not the runtime. For RPMS's 60+ entity offline database, compile-time verification catches schema drift errors that would otherwise surface as field crashes.

**Cons:**

- **UI code is not shared with iOS.** When iOS is needed, the SwiftUI presentation layer must be written from scratch. Estimated 30-35% of the total iOS codebase is platform-specific UI. This is more work than Flutter's single-codebase approach, where the same widget tree renders on both platforms. Mitigated by the fact that iOS is a future, uncertain requirement — investing in a shared UI today for a platform that may never be needed is premature optimization.

- **Compose Multiplatform for iOS is immature.** JetBrains offers Compose Multiplatform, which extends Jetpack Compose to iOS/Desktop. As of 2026, it works for simple UIs but lacks the maturity of Flutter for cross-platform rendering. RPMS could adopt Compose Multiplatform for iOS in the future if it matures, but the architecture doesn't depend on it.

- **Smaller cross-platform community than Flutter.** KMP's community is growing rapidly but is smaller than Flutter's for cross-platform patterns. Fewer tutorials for "KMP + BLE" or "KMP + offline sync" compared to Flutter equivalents. Mitigated by the fact that RPMS's hardware integrations are written in native Android (Kotlin), not in KMP's cross-platform layer — so Android-native tutorials apply directly.

- **Two build systems for the mobile repo.** The KMP shared module uses Gradle with the Kotlin Multiplatform plugin. The Angular web dashboard uses npm. These coexist in the same repository but have separate build pipelines and dependency management. This is manageable but adds CI configuration complexity.

- **Jetpack Compose maturity on older devices.** Some plantation workers use older Android 10 devices where Compose performance on low-RAM (2-3GB) hardware can be sluggish with complex layouts. Mitigated by keeping screens simple (field data display, not animation-heavy dashboards) and testing on target hardware class (Samsung A-series, Xiaomi Redmi).

### Flutter (Dart)

Flutter is Google's UI toolkit for building natively compiled applications for mobile, web, and desktop from a single Dart codebase. It renders its own UI via the Skia/Impeller engine, bypassing native platform UI components.

**Pros:**

- **Single codebase for Android and iOS.** The same Dart code renders on both platforms. If RPMS needed iOS from day one with identical UI, Flutter would deliver it with less total code than KMP (which requires separate Android and iOS UI layers).
- **Hot reload.** Dart's JIT compilation enables instant UI changes during development. This is faster than Compose's preview and rebuild cycle for pure UI iteration.
- **Large cross-platform community.** More Stack Overflow answers, more tutorials, more plugins for common patterns than KMP.
- **Attractive UI out of the box.** Flutter's widget library produces polished, consistent UI across platforms with Material and Cupertino design systems.

**Cons:**

- **Plugin bridge for every hardware API.** Flutter accesses native platform APIs through "method channels" — a serialization layer between Dart and Kotlin/Swift. For RPMS's BLE, NFC, Camera, GPS, and biometric requirements, every hardware interaction crosses this bridge. The reliability, performance, and completeness of each plugin depends on its community maintainer, not on Google. This is the fundamental issue for RPMS.

- **BLE plugins are insufficient for field conditions.** `flutter_blue_plus` and `flutter_reactive_ble` are the best BLE plugins for Flutter. They support basic scanning, connection, and characteristic read/write. However, they do not fully expose connection parameter tuning (`requestMtu`, `requestConnectionPriority`, `setPreferredPhy`), and their event delivery for connection state changes under rapid reconnection scenarios (tapper walking between tree rows) is documented as unreliable by multiple developers in production BLE applications. For RPMS's simultaneous 3-device BLE requirement in variable signal conditions, this is a critical gap.

- **NFC write operations and non-NDEF tags.** Flutter's `nfc_manager` plugin supports NDEF reading well. NFC-F, NFC-V, and raw byte block operations are partially supported with platform-specific workarounds. Tag write operations (updating scan count on the tree tag) work but are less reliable than Android's native `NfcAdapter` API. Since RPMS uses tag writing as part of the core tapping workflow, plugin-level NFC would require extensive testing and potential platform channel fallback code — at which point the "cross-platform" advantage is lost.

- **Background execution is fragile.** Flutter's background execution model relies on community plugins (`flutter_background_service`, `workmanager`) that wrap Android's `ForegroundService` and `WorkManager`. These plugins have known issues with OEM battery optimization (Samsung, Xiaomi, Oppo), process lifecycle management, and Dart isolate communication. For a 6-hour GPS tracking shift, a Flutter background service crash is a data loss event — the tapper's route is gone. In native Kotlin, the `ForegroundService` is a first-class Android component with predictable lifecycle behavior.

- **No direct biometric SDK integration.** Biometric vendor SDKs (Suprema, ZKTeco) provide `.aar` files for Android. In Flutter, using these requires writing a custom platform channel for each SDK, marshaling data between Dart and Kotlin, and maintaining this bridge as SDK versions change. This is custom glue code that adds development effort and maintenance burden without contributing to the application's actual functionality.

- **Dart language creates a team silo.** The backend team uses Java/Kotlin. The web dashboard uses TypeScript/Angular. A Flutter mobile app introduces Dart — a third language that no other part of the system uses. This means the mobile developer(s) cannot easily contribute to backend services, and backend developers cannot review or help with mobile code. KMP eliminates this silo by using Kotlin across mobile and backend.

- **Performance on low-RAM devices.** Flutter's Skia/Impeller rendering engine consumes more memory than native Android UI. On 2-3GB RAM devices (common in plantation worker budgets), Flutter's baseline memory consumption plus Dart VM overhead leaves less room for the application's actual data (offline database, BLE buffers, photo cache). Jetpack Compose renders via Android's native rendering pipeline with lower overhead.

### React Native

React Native is Meta's JavaScript-based framework for building mobile applications using React components that map to native platform views.

**Pros:**

- Large developer community and extensive npm package ecosystem.
- JavaScript/TypeScript aligns with the Angular web dashboard team's language.
- Hot reload for fast UI iteration.

**Cons:**

- **JavaScript bridge creates performance bottleneck for hardware operations.** Every BLE event, NFC scan, GPS update, and camera frame crosses a JavaScript bridge with serialization overhead. For RPMS's high-frequency operations (NFC scans every 3 seconds, BLE data streaming, GPS every 10 seconds), the bridge introduces latency and GC pauses that native code avoids entirely.
- **BLE and NFC libraries are less mature than Flutter's.** React Native's BLE libraries (`react-native-ble-plx`, `react-native-ble-manager`) and NFC libraries are maintained by smaller communities with less frequent updates than Flutter's equivalents.
- **Background execution is the weakest of all options.** React Native's background task support (Headless JS) is limited to short-running tasks. A 6-hour GPS tracking service is not feasible without a native module — at which point the developer is writing Kotlin anyway.
- **No shared logic path to iOS.** React Native's "shared code" is JavaScript UI code. The business logic (API client, offline database, sync engine) would need to be reimplemented in a native module or maintained as JavaScript — neither of which aligns with RPMS's Kotlin backend stack.
- **Hermes engine memory overhead.** React Native's Hermes JavaScript engine, while improved, adds 15-30MB baseline memory on top of the application's native footprint. On 2-3GB RAM devices, this margin matters.

### Native Android (Kotlin) Only — No Cross-Platform

Build a pure Kotlin + Jetpack Compose Android application with no shared code and no iOS path.

**Pros:**

- Simplest architecture — no KMP configuration, no multiplatform Gradle plugins, no shared module abstraction.
- Maximum Android API access (identical to KMP on Android).
- Fastest development for Android-only delivery.

**Cons:**

- **No iOS code sharing path.** If iOS is needed in 1-2 years, the entire application must be rebuilt in Swift/SwiftUI from scratch — including the API client, offline database, sync engine, and domain models. With KMP, 60-70% of this work is already done.
- **Domain model duplication.** Without the shared module, the Android app defines its own domain models and API client independently from any future iOS app — leading to divergence and inconsistency if both platforms exist.
- **Lost opportunity for JVM testing.** The KMP shared module can be tested on the JVM (fast, no emulator required). A pure Android module requires Android instrumented tests (slow, emulator-dependent) for anything that touches the local database or API client.

## Decision Matrix

| Criterion (Weight) | KMP + Compose | Flutter | React Native | Native Only |
|---|---|---|---|---|
| BLE multi-device reliability (Critical) | ★★★★★ | ★★★☆☆ | ★★☆☆☆ | ★★★★★ |
| NFC depth — write + non-NDEF (Critical) | ★★★★★ | ★★★☆☆ | ★★☆☆☆ | ★★★★★ |
| CameraX frame processing (High) | ★★★★★ | ★★☆☆☆ | ★★☆☆☆ | ★★★★★ |
| 6-hour ForegroundService GPS (Critical) | ★★★★★ | ★★★☆☆ | ★★☆☆☆ | ★★★★★ |
| Biometric SDK integration (High) | ★★★★★ | ★★☆☆☆ | ★★☆☆☆ | ★★★★★ |
| Offline-first with compile-time SQL (High) | ★★★★★ | ★★★★☆ | ★★★☆☆ | ★★★★☆ |
| iOS future code sharing (Medium) | ★★★★☆ | ★★★★★ | ★★★☆☆ | ★☆☆☆☆ |
| Backend team alignment (Medium) | ★★★★★ | ★★☆☆☆ | ★★★☆☆ | ★★★★★ |
| Performance on mid-range devices (High) | ★★★★★ | ★★★☆☆ | ★★★☆☆ | ★★★★★ |
| Cross-platform community (Low) | ★★★☆☆ | ★★★★★ | ★★★★★ | ★☆☆☆☆ |
| **Weighted Score** | **Highest** | **Mid** | **Low** | **High** |

KMP + Compose scores identically to Native Only on all hardware criteria (because KMP's Android layer *is* native Android) while adding the iOS code-sharing path that Native Only lacks. This makes it strictly superior to Native Only for RPMS's requirements.

## Shared Module Architecture

The KMP shared module is the foundation for cross-platform code reuse:

| Layer | Location | Contents | Shared % |
|---|---|---|---|
| Domain Models | `commonMain` | 60+ Kotlin data classes matching DDL entities | 100% |
| API Client | `commonMain` | Ktor 3.x HTTP client, per-module API services, auth token management | 100% |
| Offline Database | `commonMain` (schemas) + platform-specific drivers | SQLDelight `.sq` files, DAOs, migration scripts | 90% (driver is platform-specific) |
| Sync Engine | `commonMain` | SyncQueue, ConflictResolver, SyncManager with coroutines | 100% |
| Validation | `commonMain` | Business rule validators matching backend service logic | 100% |
| UI | `androidMain` / `iosMain` (future) | Jetpack Compose / SwiftUI | 0% (platform-specific) |
| Hardware | `androidMain` / `iosMain` (future) | BLE, NFC, CameraX, GPS / CoreBluetooth, CoreNFC, etc. | 0% (platform-specific) |
| **Overall** | | | **~65% shared** |

### Key Technology Choices Within KMP

| Concern | Choice | Rationale |
|---|---|---|
| HTTP Client | Ktor 3.x + kotlinx.serialization | KMP-native, same API on Android and iOS, JSON serialization without reflection |
| Offline Database | SQLDelight 2.x | Compile-time SQL verification, KMP-native, generates type-safe Kotlin APIs from SQL |
| Dependency Injection | Koin | Lightweight, KMP-compatible DI (Hilt is Android-only) |
| Async | Kotlin Coroutines + Flow | KMP-native concurrency, StateFlow for UI state, SharedFlow for events |
| Image Loading | Coil 3.x | Compose-native, Kotlin-first, lighter than Glide |
| UI Toolkit | Jetpack Compose + Material 3 | Official Android UI, dynamic color, adaptive layouts |
| Navigation | Compose Navigation | Type-safe routes, deep linking support |
| Background Work | WorkManager (Android) | Constraint-based scheduling (network, battery, charging) |
| GPS Tracking | ForegroundService + FusedLocationProvider | Persistent service with notification for 6-hour shifts |

## Consequences

### Positive

- Every hardware integration (BLE, NFC, CameraX, GPS, biometric) calls Android APIs directly with zero abstraction overhead. Field reliability depends on Android's proven hardware stack, not on community-maintained plugin bridges.
- The KMP shared module (domain models, API client, offline DB, sync engine, validation) is written once in Kotlin and shared across platforms. When iOS development begins, an estimated 60-70% of the codebase is already functional — only the SwiftUI presentation layer and CoreBluetooth/CoreNFC integrations need to be written.
- Backend developers (Java 21 / Spring Boot / Quarkus) can review, contribute to, and maintain the mobile shared module without learning a new language. Kotlin's Java interoperability means backend DTOs and mobile domain models stay aligned naturally.
- SQLDelight's compile-time SQL verification catches schema drift between the mobile offline database and the backend PostgreSQL schema at build time — not at runtime in the field where debugging is impossible.
- Jetpack Compose renders through Android's native rendering pipeline, consuming less memory than Flutter's Skia/Impeller engine on the 2-3GB RAM devices common in plantation worker budgets.

### Negative

- iOS UI must be written separately in SwiftUI when the time comes. For a single-developer team, this means iOS delivery takes additional time compared to Flutter's single codebase. Mitigated by the fact that iOS is not a current requirement and may never be needed for the tapper role.
- KMP's cross-platform ecosystem is smaller than Flutter's. Fewer pre-built KMP libraries for common patterns, fewer community tutorials, and fewer Stack Overflow answers for KMP-specific issues. Mitigated by the fact that hardware integrations are native Android (extensive documentation) and the shared module uses well-documented libraries (Ktor, SQLDelight, Coroutines).
- The KMP Gradle plugin configuration can be complex — managing source sets (`commonMain`, `androidMain`, `iosMain`), expect/actual declarations, and platform-specific dependencies requires understanding KMP's build model. Mitigated by established KMP project templates and JetBrains' improving tooling.
- Two testing environments: shared module tests run on JVM (fast, no emulator), but hardware integration tests require an Android device or emulator. The Compose UI layer can be tested with Compose Testing APIs but not on JVM.

### Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| KMP shared module adds build complexity | Medium | Low | Use the official KMP project wizard template. Gradle configuration is one-time setup. JetBrains actively improves KMP tooling with each Kotlin release. |
| iOS requirement arrives sooner than expected | Low | Medium | The KMP shared module is iOS-ready from day one (commonMain compiles to iOS Framework). Only SwiftUI UI and CoreBluetooth/CoreNFC need writing. Estimated 4-6 weeks for a basic iOS supervisor app leveraging the shared module. |
| Jetpack Compose performance on low-end devices | Medium | Medium | Keep screens simple — data display, not animation-heavy. Use `LazyColumn` for lists. Profile on target hardware (Samsung A14, Xiaomi Redmi 12). Compose performance improves with each release. |
| Third-party biometric SDK compatibility | Low | Medium | Test each vendor SDK (.aar) integration in isolation before building the full attendance flow. Maintain a hardware compatibility matrix. Fall back to standard Android BiometricPrompt if vendor SDK fails. |
| Flutter becomes clearly superior for cross-platform | Very Low | Low | KMP's Android layer is identical to pure native — there is no migration cost if Flutter later offers equivalent hardware access (unlikely for BLE/NFC depth). The worst case is that RPMS remains a high-quality native Android app. |

## Links

- **Related ADRs**: ADR-002 (Spring Boot + Quarkus — Kotlin/Java backend alignment), ADR-004 (Angular — web dashboard separate from mobile, no shared rendering framework needed)
- **Design artifacts**: [`rpms-design/architecture/rpms_high_level_architecture.html`](../rpms_high_level_architecture.html) — Layer 3 (Mobile & Client Applications)
- **Kotlin Multiplatform documentation**: https://kotlinlang.org/docs/multiplatform.html
- **Jetpack Compose documentation**: https://developer.android.com/develop/ui/compose
- **SQLDelight documentation**: https://cashapp.github.io/sqldelight/
- **Ktor documentation**: https://ktor.io/docs/welcome.html
- **Repository structure**: [`rpms-mobile/`](https://github.com/rpms-plantation/rpms-mobile) — shared/, android-app/, web-dashboard/
