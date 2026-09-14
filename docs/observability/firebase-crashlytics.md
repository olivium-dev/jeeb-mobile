# Firebase Crashlytics runtime contract

Crashlytics uses the native Firebase app selected by the protected configuration
wrappers. Development/MSI is `jeeb-development-msi`; staging is `jeeb-5a293`.
The exact app IDs and native package identifiers are pinned in
`contracts/jeeb-mobile-firebase-apps-v1.json`. Production is outside this
runtime-policy rollout and keeps its native/default collection behavior.

`CrashlyticsCollectionPolicy` prefers `APP_FLAVOR`, falls back to Flutter's
native `--flavor` value, applies these non-production rules after
`Firebase.initializeApp()`, and verifies that the SDK accepted the value:

| Flavor | Debug | Profile/release |
| --- | --- | --- |
| `dev` | off unless `CRASHLYTICS_DEBUG_CAPTURE=true` | on |
| `staging` | off unless `CRASHLYTICS_DEBUG_CAPTURE=true` | on |
| any other value | no runtime override | no runtime override |

Uncaught Flutter-framework and platform-dispatcher errors are both recorded as
fatal. Caught errors may still use `CrashReporter.recordError(..., fatal: false)`.

## One-shot development verification

Use only a protected development/MSI Firebase configuration and a non-production
device. Build the ordinary Dev Tool target with both gates:

```text
--dart-define=APP_FLAVOR=dev
--dart-define=CRASHLYTICS_DEBUG_CAPTURE=true
--dart-define=CRASHLYTICS_TEST_PROBE=true
```

Keep all existing protected Firebase, Maps, push, and Dev Tool build flags. Open
**Dev Tool → Actions**, tap **Send test exception** exactly once, and record the
device, app version/build, and local timestamp. The control reports the fixed
marker `Jeeb non-production Crashlytics test probe` through the global fatal
handler. It is absent from ordinary builds and from any flavor outside `dev` or
`staging`.

Read back the marker under the development Android app in the
`jeeb-development-msi` Crashlytics dashboard. Do not close, delete, or mutate
existing issues while verifying ingestion. Firebase can take several minutes
to display a first report.

Firebase references:

- https://firebase.google.com/docs/crashlytics/flutter/get-started
- https://firebase.google.com/docs/crashlytics/flutter/test-implementation
- https://firebase.google.com/docs/crashlytics/flutter/customize-crash-reports
