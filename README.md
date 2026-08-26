# Jeeb Mobile

Flutter mobile app for the Jeeb product line (olivium-dev).

## Architecture

- **State Management:** flutter_bloc
- **Routing:** GoRouter
- **DI:** GetIt
- **Networking:** Dio
- **Design System:** OMDS tokens (to be integrated via `omds_flutter`)
- **Pattern:** Clean Architecture (data / domain / presentation per feature)

## Getting Started

```bash
fvm flutter pub get
fvm flutter run --flavor dev
```

The repository toolchain source of truth is `.fvmrc` (`3.44.2`). CI reads the
same file; workflow files must not carry independent Flutter version literals.

## Project Structure

```
lib/
├── app/              # App widget, top-level configuration
├── core/
│   ├── di/           # Dependency injection (GetIt)
│   ├── network/      # Dio client, interceptors
│   ├── router/       # GoRouter configuration
│   └── theme/        # OMDS-aligned theme tokens
├── features/         # Feature modules (clean arch layers per feature)
│   └── <feature>/
│       ├── data/         # Data sources, models, repository impls
│       ├── domain/       # Entities, repository contracts, use cases
│       └── presentation/ # BLoC, pages, widgets
└── main.dart
```

## Flavors

Android application IDs:

| Flavor | Application ID | Notes |
|---|---|---|
| dev | `app.jeeb.mobile.dev` | Local/CI builds |
| staging runtime | `com.olivium.jeeb` | Play Internal candidate, built with `APP_FLAVOR=staging` |
| production | `com.olivium.jeeb` | Play Store |

iOS bundle IDs:

| Flavor | Bundle ID | Notes |
|---|---|---|
| dev | `app.jeeb.jeebMobile.dev` | Local development |
| staging runtime | `com.olivium.jeeb` | TestFlight candidate, built with `APP_FLAVOR=staging` |
| production | `com.olivium.jeeb` | App Store |

## iOS

iOS project configuration requires Xcode. Run:

```bash
cd ios && pod install
```

Ensure the signing team and bundle ID are set in Xcode before building.

Store candidates keep the permanent native identity and receive staging only as
build-time runtime configuration:

```bash
flutter build appbundle --flavor production --release \
  --dart-define=APP_FLAVOR=staging \
  --dart-define=GATEWAY_BASE_URL=https://app.jeeb.fds-1.com

flutter build ipa --release \
  --dart-define=APP_FLAVOR=staging \
  --dart-define=GATEWAY_BASE_URL=https://app.jeeb.fds-1.com
```

Run the normal iOS dev app against the LAN gateway with:

```bash
flutter run -d "iPhone 15" --debug --flavor dev \
  --dart-define=JEEB_MOCK_BASE_URL=http://192.168.2.39:10090 \
  --dart-define=JEEB_USE_MOCK_PREFIXES=false \
  --dart-define=JEEB_DEVTOOL_ENABLED=true \
  --dart-define=JEEB_REALTIME_TRACKING=true
```

Launch directly into the Jeeber Dev Tool with the checked helper:

```bash
tool/run_ios_devtool.sh "iPhone 15"
```

Set `JEEB_IOS_BASE_URL` to change the gateway, or `JEEB_IOS_DEVICE` to change
the default simulator. The Dev Tool is available only in debug builds.

## Backend route compatibility (`/v1` de-versioning)

The gateway is dropping the `/v1` prefix. `UnversionedPathFallbackInterceptor`
replays a `404`/`405` on `/v1/...` once against the unversioned twin, so the app
keeps working mid-migration — including on the token-refresh client, which is
otherwise interceptor-free.

**Read `docs/adr/0002-v1-unversioned-compat-window.md` before removing any
`/v1/auth/*` route, or before deleting the gateway's `[Obsolete] AuthController`.**
Refresh runs on token expiry, so getting the order wrong force-logs-out every
installed app at once with no in-app recovery. The safe order is: ship a mobile
build with unversioned auth paths, wait out the install tail, remove the server
routes last. The ~310 `/v1` literals in `lib/` still need migrating — the
interceptor is a safety net, not the migration.

## CI

Three GitHub Actions workflows gate `main`: `ci.yml` (analyze → test → build APK),
`flutter-ci.yml` (the same plus coverage) and `mobile-ci.yml` (the l10n parity gate).

**CI is expected green. There is no standing waiver** — a red run is a real
failure, not inherited noise. If a check cannot pass, fix it or skip the single
expectation with a written reason; do not merge on red.

- **Flutter is pinned to 3.44.2 in `.fvmrc`**, the version the Mac Studio builds
  the phone APKs with. CI used to sit on 3.38.9, two minor versions behind every
  dev machine, which is what made `main` permanently red: ~21 tests asserted
  behaviour only the newer framework produces.
- **Coverage is a release gate.** `flutter-ci.yml` requires at least 79% line
  coverage through the commit-pinned `very_good_coverage` action. Tests and the
  threshold are both blocking.
- **Generated sources are reproducible.** Every ordinary CI lane runs the
  cached `build_runner build --delete-conflicting-outputs` composite action
  after dependency resolution.
- **`--exclude-tags capture`**: `test/tools/catalog_capture_test.dart` and
  `m6_jeeber_orange_budget_capture_test.dart` are golden-PNG *review* harnesses,
  not gates. Their goldens are host-rendered and cannot match a Linux runner.
  Run them locally: `flutter test --tags capture`.
- **`tool/check_firebase_core_pin.sh`** runs after every `flutter pub get` and
  fails if the resolved `firebase_core` leaves `>=3.13.1 <3.15.0`. `pubspec.lock`
  is gitignored, so without this gate each machine silently resolves its own —
  and 3.15.0 kills push registration and Firestore chat on Android with no error.

## Internal release cadence

`trusted-mobile-rc.yml` builds reviewed `main` with an explicit semantic build
name containing exactly three numeric components and a monotonically
increasing numeric build number. It retains the exact signed AAB and IPA,
SHA-256 provenance, the Android R8 mapping, and iOS dSYMs
for seven days. This workflow does not contact either store. Android and iOS
use the same OMDS commit from `.omds-revision`; that revision is recorded in
both provenance manifests. The iOS contract and candidate jobs run on
`macos-26`, select `/Applications/Xcode_26.6.app`, and require Xcode 26.6 with
an `iphoneos26.*` SDK.

Before signing, the RC policy gate verifies that the requested commit is the
exact protected `main` head and that every named release check succeeded for
that commit. The contexts include Flutter test/analysis, the blocking 79%
coverage floor, native release contracts, localization parity, and
`release-security.yml`. The latter scans
the complete commit range introduced by each pull request or `main` push with
checksum-pinned Gitleaks 8.30.1 and blocks known Ruby release-tooling
advisories with `bundler-audit` 0.9.3. The Gradle
8.14.4 wrapper JAR and distribution are separately checksum-gated.

After the retained RC succeeds, an authorized operator may dispatch
`distribute-mobile-internal.yml` with the source RC run ID, reviewed commit,
version, and build number. The workflow REST-downloads both exact retained artifacts,
verifies their GitHub ZIP digests, rejects unsafe entries, and independently
rehashes the IPA, dSYMs, and provenance before the upload lane can run. It also
verifies exact workflow paths, head SHA, run attempts, and same-byte hashes; it
does not rebuild either candidate. A single non-mutating preflight reads every
Google Play track and pages every Jeeb iOS prerelease version and build in App
Store Connect. It rejects a build number that is not newer than the global
maximum before either upload job can start. Fastlane may upload only to Google
Play Internal Testing and internal TestFlight. There is deliberately no
production track, external
TestFlight distribution, App Review submission, or automatic promotion lane.

Distribution receipts deliberately record
`physical_device_verification: pending` and `final_release_go: false`; they do
not claim pre-distribution E2E evidence. After upload, the Android happy paths
`JMS-JHP-001`, `JMS-JHP-002`, and `JMS-JHP-003` must run without mocks on the
Google Play-delivered Internal Testing build on real S24 and A33 devices. The
TestFlight-delivered build must likewise be exercised on a physical iOS device.
Only real, sanitized post-store results can clear the pending state and support
a later release decision. Sideloaded, simulator, handwritten, or fabricated
evidence does not satisfy this gate.

The workflows use protected-branch-only GitHub environments for credential
scoping; they do not depend on repository-ruleset or reviewer metadata APIs.
Store binaries are uploaded only by `distribute-mobile-internal.yml`; manual
store upload is unsupported. `OMDS_FLUTTER_PAT` is the repository-level,
read-only credential used to fetch the exact `.omds-revision`:

- `mobile-rc`: `ANDROID_UPLOAD_KEYSTORE_B64`,
  `ANDROID_UPLOAD_KEY_ALIAS`, `ANDROID_UPLOAD_KEY_PASSWORD`,
  `ANDROID_UPLOAD_STORE_PASSWORD`, `ANDROID_UPLOAD_CERT_SHA1`,
  `ANDROID_UPLOAD_CERT_SHA256`, `ANDROID_GOOGLE_SERVICES_JSON_B64`,
  `ANDROID_FIREBASE_EXPECTED_APP_ID`,
  `ANDROID_FIREBASE_UPLOAD_OAUTH_CLIENT_ID`,
  `ANDROID_FIREBASE_PLAY_OAUTH_CLIENT_ID`, `ANDROID_MAPS_API_KEY`,
- `mobile-internal-distribution`: `GOOGLE_PLAY_JSON_KEY`,
  `APP_STORE_KEY_ID`, `APP_STORE_ISSUER_ID`, and
  `APP_STORE_KEY_CONTENT_B64`, plus `IOS_GOOGLE_SERVICE_INFO_PLIST_B64`,
  `IOS_FIREBASE_EXPECTED_APP_ID`, `IOS_FIREBASE_EXPECTED_CLIENT_ID`,
  `IOS_FIREBASE_EXPECTED_REVERSED_CLIENT_ID`, and `IOS_GOOGLE_MAPS_API_KEY`.

The iOS RC decodes the App Store Connect private key only into a mode-`0600`
temporary file, validates it without printing it, and removes it on every exit.
Xcode automatic signing uses that key to create or update Apple provisioning
assets when necessary; the RC export remains local, preserves the requested
version/build, sets `testFlightInternalTestingOnly`, and never uploads to App
Store Connect. Release runs fail closed when protected-branch policy, retained
provenance, successful check contexts, monotonic store build numbers, or any
named credential is absent. Credentials must never be committed.

## License

Proprietary — olivium-dev.
