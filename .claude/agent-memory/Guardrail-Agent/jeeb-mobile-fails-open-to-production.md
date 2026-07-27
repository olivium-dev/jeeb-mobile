---
name: jeeb-mobile-fails-open-to-production
description: AppConfig.gatewayBaseUrl defaults to https://api.jeeb.app — a Flutter build without --dart-define GATEWAY_BASE_URL silently talks to production, and the Dev Tool ships a one-tap prod preset
metadata:
  type: project
---

`jeeb-mobile/lib/core/config/app_config.dart:25-28`:

```dart
static const String gatewayBaseUrl = String.fromEnvironment(
  'GATEWAY_BASE_URL',
  defaultValue: 'https://api.jeeb.app',
);
```

An APK built **without** `--dart-define=GATEWAY_BASE_URL=…` does not fail, does not
warn, and does not fall back to a dev host — it silently talks to **production**.
The failure mode is a forgotten flag, and the symptom is "the app works fine", so
nothing signals that the wrong environment was hit.

Second path to the same place: `lib/devtool/dev_settings_page.dart:79-86` ships a
tappable `ActionChip` preset for `https://api.jeeb.app/v1` and hints
`https://staging.jeeb.app/v1` at `:71`. One tap moves a device onto a non-dev
environment, and the override persists into later runs.

**Why:** found during the b02-20260726 MSI-only sweep, under the owner ruling that
MSI (192.168.2.39) is the only backend anything may touch (see
[[owner-ruling-msi-only-no-staging]]). Under that ruling this default is the
highest-consequence trap in the mobile tree: evidence captured against a
prod-pointed build is a false PASS in the strongest sense.

**How to apply:** every dev/test build carries
`--dart-define=GATEWAY_BASE_URL=http://192.168.2.39:10090` (origin-only, no `/v1` —
the ARCH-01 convention frozen by `test/core/config/base_url_convention_test.dart`)
**and** `--dart-define=JEEB_DEVTOOL_ENABLED=true`. Paste the build command into the
run record before installing; a build whose command was not recorded cannot be
trusted as evidence. If a device session touches Dev Settings, capture the effective
base URL the page renders (`SelectableText(_effective)`, `:62-63`) so the
environment is proven rather than assumed. Changing the default itself is a product
change — raise it, don't slip it into an unrelated batch.
