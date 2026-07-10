# RC4 Maestro Mock Smoke Preparation

Scope: `.maestro/**` only, Android dev app `app.jeeb.mobile.dev`, branch
`feat/rc4-maestro`. Source checkpoints:

- `008-maestro-strategy.md`: layout, tags, app IDs, selector contract.
- `011-mock-gateway-mobile-smoke.md`: mock ports, OTP code, known mock gaps.

## What Was Added

- `.maestro/env/android-mock.env` and `.maestro/env/android-dev.env` for shell
  sourcing. Maestro 2.0.5 has `-e/--env` in help, not `--env-file`.
- `.maestro/_pages/*.yaml` reusable subflows for launch, onboarding,
  registration, OTP, invalid-code assertion, and shell landing. Maestro 2.0.5
  requires these included files to carry a config section, so each has
  `appId: ${APP_ID}`. Smoke flows reference them with `../../_pages/...`
  because Maestro resolves `runFlow` paths relative to the parent flow file.
- `.maestro/flows/smoke/*.yaml` tagged runnable smoke scenarios:
  - `00-cold-launch.yaml` (`android`, `smoke`, `mock`, `cold-launch`,
    `critical`, `blocked`)
  - `01-mock-otp-happy.yaml` (`android`, `smoke`, `mock`, `auth`, `critical`,
    `happy-path`, `blocked`)
  - `02-mock-otp-invalid-code.yaml` (`android`, `smoke`, `mock`, `auth`,
    `negative`, `blocked`)
  - `03-dev-seam-shell-smoke.yaml` (`android`, `smoke`, `mock`, `dev-seam`,
    `critical`, `blocked`)
- `.maestro/smoke.yaml` kept as a compatibility cold-launch alias and tagged.

## Run Contract

Build the Android dev APK with the mock URL baked in:

```bash
flutter build apk --flavor dev --debug \
  --dart-define=JEEB_MOCK_BASE_URL=http://10.0.2.2:3055
```

Check the host-side mock health before Maestro:

```bash
curl -fsS http://127.0.0.1:3055/health/aggregate
```

Run the structured smoke suite with debug output under the orchestrator path:

```bash
DEBUG_ROOT="/Volumes/Extreme Pro/claude-jeeb/jeeb-mobile-orchestrator/maestro-debug"

maestro --device emulator-5554 test \
  -e APP_ID=app.jeeb.mobile.dev \
  -e LOCALE=en \
  -e PHONE_NATIONAL=71123456 \
  -e OTP_VALID=123456 \
  -e OTP_INVALID=000000 \
  --include-tags smoke,mock \
  --format JUNIT \
  --output "$DEBUG_ROOT/junit/android-mock-smoke.xml" \
  --debug-output "$DEBUG_ROOT" \
  --screenshot-on-failure \
  .maestro/flows/smoke/
```

The current files are tagged `blocked` because they assert the shared semantic
contract instead of falling back to text/coordinates. Do not wire this command
as a required CI gate until the blockers below are resolved and the `blocked`
tags are removed.

Expected runtime after blockers are resolved: `00` and `03` stay under 20s;
`01` and `02` target 35-55s. Anything above 60s should be split or moved out
of PR smoke.

## Current Blockers

These are app semantic-contract blockers, not Maestro authoring gaps:

- `onboarding_skip_button`, `onboarding_next_button`,
  `onboarding_get_started_button` are expected, but onboarding currently exposes
  Flutter `Key(...)` only for controls.
- `registration_phone_field`, `registration_send_code_button`,
  `registration_otp_field`, `registration_verify_button` are expected, but the
  registration/OTP screens currently expose `Key(...)` only.
- `registration_otp_error` is expected for invalid-code recovery; the inline
  OTP error text currently has no `Semantics(identifier: ...)`.
- `home_shell` is expected as the post-login landing ID; `ShellScreen` does not
  yet wrap the shell root with that identifier.
- `jeeb.skip_onboarding` is parsed in Dart but missing from Android
  `MainActivity.kt` `seamKeys`, so `launchApp.arguments` cannot make a fresh
  install bypass onboarding for the dev-seam shell smoke.

The flows are tagged `blocked` until those shared-lane IDs/intent extras land.
Do not replace them with text selectors, coordinates, or `index:` fallbacks.
