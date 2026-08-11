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
flutter pub get
flutter run --flavor dev
```

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
| staging | `app.jeeb.mobile.staging` | QA/UAT |
| production | `app.jeeb.mobile` | Play Store |

iOS bundle IDs:

| Flavor | Bundle ID | Notes |
|---|---|---|
| dev | `app.jeeb.jeebMobile.dev` | Local development |
| staging | Not configured | No iOS staging scheme yet |
| production | `app.jeeb.jeebMobile` | App Store |

## iOS

iOS project configuration requires Xcode. Run:

```bash
cd ios && pod install
```

Ensure the signing team and bundle ID are set in Xcode before building.

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

## CI

Three GitHub Actions workflows gate `main`: `ci.yml` (analyze → test → build APK),
`flutter-ci.yml` (the same plus coverage) and `mobile-ci.yml` (the l10n parity gate).

**CI is expected green. There is no standing waiver** — a red run is a real
failure, not inherited noise. If a check cannot pass, fix it or skip the single
expectation with a written reason; do not merge on red.

- **Flutter is pinned to 3.44.2**, the version the Mac Studio builds the phone
  APKs with. CI used to sit on 3.38.9, two minor versions behind every dev
  machine, which is what made `main` permanently red: ~21 tests asserted
  behaviour only the newer framework produces.
- **`--exclude-tags capture`**: `test/tools/catalog_capture_test.dart` and
  `m6_jeeber_orange_budget_capture_test.dart` are golden-PNG *review* harnesses,
  not gates. Their goldens are host-rendered and cannot match a Linux runner.
  Run them locally: `flutter test --tags capture`.
- **`tool/check_firebase_core_pin.sh`** runs after every `flutter pub get` and
  fails if the resolved `firebase_core` leaves `>=3.13.1 <3.15.0`. `pubspec.lock`
  is gitignored, so without this gate each machine silently resolves its own —
  and 3.15.0 kills push registration and Firestore chat on Android with no error.

## License

Proprietary — olivium-dev.
