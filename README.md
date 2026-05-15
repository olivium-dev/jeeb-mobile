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

| Flavor     | App ID                       | Notes            |
|-----------|------------------------------|------------------|
| dev       | app.jeeb.mobile.dev          | Local/CI builds  |
| staging   | app.jeeb.mobile.staging      | QA/UAT           |
| production| app.jeeb.mobile              | App Store/Play   |

## iOS

iOS project configuration requires Xcode. Run:

```bash
cd ios && pod install
```

Ensure the signing team and bundle ID are set in Xcode before building.

## CI

GitHub Actions workflow at `.github/workflows/flutter-ci.yml` runs:
- `flutter analyze`
- `flutter test --coverage`
- `flutter build apk --debug`

## License

Proprietary — olivium-dev.
