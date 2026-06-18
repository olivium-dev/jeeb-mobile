# RC4 Maestro Mock Smoke Preparation

Scope: `.maestro/**` only, Android dev app `app.jeeb.mobile.dev`, branch
`integration/rc4-mock-backed`. Source checkpoints:

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
    `critical`)
  - `01-mock-otp-happy.yaml` (`android`, `smoke`, `mock`, `auth`, `critical`,
    `happy-path`)
  - `02-mock-otp-invalid-code.yaml` (`android`, `smoke`, `mock`, `auth`,
    `negative`)
  - `03-dev-seam-shell-smoke.yaml` (`android`, `smoke`, `mock`, `dev-seam`,
    `critical`)
- `.maestro/smoke.yaml` kept as a compatibility cold-launch alias and tagged.

## Run Contract

Build the Android dev APK with the mock URL fallback baked in. The Maestro
launch flows also pass the same URL at runtime via `jeeb.mock_base_url` so one
already-built debug APK can be reused with a different mock host.

```bash
flutter build apk --flavor dev --debug \
  --dart-define=JEEB_MOCK_BASE_URL=http://10.0.2.2:3055
```

Check the host-side mock health before Maestro:

```bash
curl -fsS http://127.0.0.1:3055/health/aggregate
curl -fsS http://127.0.0.1:3056/health
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
  -e JEEB_MOCK_BASE_URL=http://10.0.2.2:3055 \
  -e JEEB_REALTIME_URL=ws://10.0.2.2:3056/socket/websocket \
  --include-tags smoke,mock \
  --format JUNIT \
  --output "$DEBUG_ROOT/junit/android-mock-smoke.xml" \
  --debug-output "$DEBUG_ROOT" \
  --test-output-dir "$DEBUG_ROOT/test-output" \
  --screenshot-on-failure \
  .maestro/flows/smoke/
```

The flows assert the shared semantic contract by stable IDs only. Do not add
text selectors, coordinates, or `index:` fallbacks for these app interactions.

Expected runtime: `00` and `03` stay under 20s; `01` and `02` target 35-55s.
Anything above 60s should be split or moved out of PR smoke.

## Static Contract

The integrated app source now satisfies the smoke suite's static contract:

- Android `MainActivity.kt` accepts `jeeb.skip_onboarding` and
  `jeeb.mock_base_url` intent extras.
- Dart parses and merges `jeeb.mock_base_url`, and `MockGatewayClient` prefers
  that runtime value over the dart-define/default.
- Onboarding, registration, OTP, and shell screens export the IDs used by the
  smoke flows, including `home_shell`.

This document is preparation only. Runtime proof still requires building and
installing the combined Android dev APK, running the Maestro command above
against healthy `:3055` and `:3056` mocks, and attaching JUnit XML, screenshots,
debug output, and a terminal transcript under the orchestrator artifact path.
