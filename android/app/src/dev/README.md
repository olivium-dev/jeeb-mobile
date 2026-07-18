# `dev` flavor Firebase config

`google-services.json.template` is the committed-safe placeholder. The real-path
`google-services.json` is ignored and must be injected locally or by CI before a
dev build that requires FCM.

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
| `dev`        | `app.jeeb.mobile.dev`    | ignored `android/app/src/dev/google-services.json` |
| `production` | `app.jeeb.mobile`        | `android/app/google-services.json` (real, ignored)|
| `staging`    | `app.jeeb.mobile.staging`| needs its own real/placeholder client             |

## Runtime behaviour

The template is intentionally rejected by `tool/validate_dev_google_services.sh`.
The validator checks JSON structure, the dev package, and exact project-number,
project-id, and mobile-app-id values supplied separately through protected
inputs. It does **not** contact Firebase or prove that the key is enabled,
unrevoked, correctly restricted, or capable of minting a live FCM token.

Strict acceptance has two runtime readiness stages:

1. Before installing the real transport, `REQUIRE_REAL_PUSH=true` waits for a
   nonempty FCM token. Invalid, revoked, or incompatible configuration fails the
   acceptance boot instead of falling back to `FakePushTransport`.
2. After authentication, `DeviceTokenRegistrar.notifyLogin()` must receive 2xx
   from `PUT /api/PushNotification/register`. Token readiness alone is not
   gateway registration readiness, and neither alone proves end-to-end delivery.

## Getting real FCM / Crashlytics on `dev`

Generate a real config (it stays gitignored — never commit its values):

```bash
# Register an Android app with package app.jeeb.mobile.dev in the Firebase
# console (or via flutterfire), download its google-services.json, then drop it
# here (overrides this placeholder) or at android/app/google-services.json:
flutterfire configure --project <jeeb-firebase-project> \
  --android-package-name app.jeeb.mobile.dev \
  --out lib/core/firebase/firebase_options.g.dart

export DEV_FIREBASE_EXPECTED_PROJECT_NUMBER='<approved sender/project number>'
export DEV_FIREBASE_EXPECTED_PROJECT_ID='<approved Firebase project id>'
export DEV_FIREBASE_EXPECTED_APP_ID='<approved Firebase Android app id>'
bash tool/validate_dev_google_services.sh
```

## Build / run the dev flavor

```bash
flutter pub get
# Debug APK:
flutter build apk --debug --flavor dev \
  --dart-define=REQUIRE_REAL_PUSH=true
# Run on a device/emulator:
flutter run --flavor dev
```

> NEVER replace the placeholder values in this committed file with a real key.
> Never claim the MSI push run ready until token acquisition and the authenticated
> registration request both pass; final E2E proof still requires an observed push.
