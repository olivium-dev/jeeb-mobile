# `dev` flavor Firebase config

`google-services.json` in this directory is a **committed-safe placeholder** (no
real credentials). It exists so the `dev` product flavor compiles.

## Why this file is needed

The `dev` flavor sets `applicationIdSuffix ".dev"`, so its applicationId is
`app.jeeb.mobile.dev`. The `com.google.gms.google-services` Gradle plugin
requires a `client` entry whose `package_name` exactly matches the variant
applicationId. The real, gitignored `android/app/google-services.json` only
carries the production package `app.jeeb.mobile`, so a `dev` build with no
matching client fails at the `process<Variant>GoogleServices` task with
`No matching client found for package name 'app.jeeb.mobile.dev'`.

The google-services plugin resolves config per source set, preferring
`src/<flavor>/google-services.json` over `app/google-services.json`. So:

| Flavor       | applicationId            | google-services.json used                         |
|--------------|--------------------------|---------------------------------------------------|
| `dev`        | `app.jeeb.mobile.dev`    | `android/app/src/dev/google-services.json` (this) |
| `production` | `app.jeeb.mobile`        | `android/app/google-services.json` (real, ignored)|
| `staging`    | `app.jeeb.mobile.staging`| needs its own real/placeholder client             |

## Runtime behaviour

`Firebase.initializeApp()` parses these placeholder values and the app boots
fine. Because the `api_key` is fake, **FCM token retrieval and Crashlytics
upload log a benign `invalid API key` warning** — expected for the placeholder.

## Getting real FCM / Crashlytics on `dev`

Generate a real config (it stays gitignored — never commit real keys):

```bash
# Register an Android app with package app.jeeb.mobile.dev in the Firebase
# console (or via flutterfire), download its google-services.json, then drop it
# here (overrides this placeholder) or at android/app/google-services.json:
flutterfire configure --project <jeeb-firebase-project> \
  --android-package-name app.jeeb.mobile.dev \
  --out lib/core/firebase/firebase_options.g.dart
```

## Build / run the dev flavor

```bash
flutter pub get
# Debug APK:
flutter build apk --debug --flavor dev
# Run on a device/emulator:
flutter run --flavor dev
```

> NEVER replace the placeholder values in this committed file with a real key.
