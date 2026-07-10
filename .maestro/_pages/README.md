# `.maestro/_pages/` — page-object library (shared helper flows)

Canonical page-object skeleton for the Jeeb mobile Maestro suite. Ref:
Sprint-009 testing-acceleration Area-2 §3.1 and Area-5 (a); skills
`maestro-page-object-via-runflow`, `maestro-flow-yaml-patterns`.

## Why

Each file here encapsulates the interactions with **one** funnel/screen and is
composed into top-level scenarios via `runFlow:`. Selectors for any shared
screen live **only** here — scenarios under `flows/` do assertions + composition
only. This retires per-flow login duplication and the 115-id selector drift.

## Conventions

- **`_` prefix** keeps these out of top-level `maestro test .maestro/` discovery
  (they are fixtures, not runnable scenarios).
- **Params documented first** in every file's header block (name → meaning).
- **Stable ids only** (`Semantics(identifier:)`), no visible text / no
  coordinates on any surface that exports ids. The one justified exception is
  documented inline (`login_super.yaml` submit CTA has no id in cycle-5).
- **Deterministic waits**: `extendedWaitUntil: visible: id:<root>` with tiered
  timeouts (`NAV_TIMEOUT` / `NET_TIMEOUT` / `LAUNCH_TIMEOUT` from `config.yaml`).
  No `sleep`, no `waitForAnimationToEnd` chains as waits (Area-2 §3.3).
- **No secrets baked**: phones, OTP codes, tokens, passcodes are injected at run
  time via `runFlow env:` / CLI `--env`. Maestro does not log `inputText` values.

## The helpers

| File | Tier | Purpose | Key params |
|---|---|---|---|
| `bootstrap.yaml` | any | normalize first-run funnel (dismiss notif prompt + skip walkthrough/onboarding) + assert landing root; caller owns `launchApp` | `SUCCESS_ID` |
| `login_real_otp.yaml` | **authoritative + emulator** | honest real-OTP login vs live `:10090` (no seam/seed) | `LOCAL_PHONE`, `OTP_CODE`, `SUCCESS_ID` |
| `login_super.yaml` | **emulator pre-gate ONLY** ⛔ | debug passcode super-login (fast real JWT); FORBIDDEN on S22/S24 | `SUPER_USER_ID`, `SUPER_PASSCODE`, `SUCCESS_ID` |
| `nav.yaml` | any (logged-in) | `jeeb://` deep-link jump to a screen, assert its root | `DEEPLINK`, `SUCCESS_ID` |

### Real landing roots (cycle-5 lib — NOT the drifted `shell_tab_*`)

- customer → `client_home_root`
- jeeber → `jeeber_home_root`

## Composition example

```yaml
# flows/live/e2e-customer-create.yaml
appId: ${APP_ID}
env:
  SUCCESS_ID: "client_home_root"
---
- launchApp:
    clearState: true          # caller owns launch (clearState is a typed bool)
- runFlow:
    file: ../../_pages/bootstrap.yaml
    env: { SUCCESS_ID: "login_root" }
- runFlow:
    file: ../../_pages/login_real_otp.yaml
    env: { LOCAL_PHONE: "3000001", OTP_CODE: "${OTP_CODE}", SUCCESS_ID: "client_home_root" }
- runFlow:
    file: ../../_pages/nav.yaml
    env: { DEEPLINK: "jeeb://requests", SUCCESS_ID: "_request_empty_state_root" }
# ...scenario-specific assertions continue here...
```

## Pre-device gates (run before any device time — Area-2 §3.4)

1. **Syntax**: `mcp__maestro__check_flow_syntax` (or `maestro test`'s parse) on
   every changed flow. All files here pass syntax as of authoring.
2. **ID-lint**: diff `identifier:` ids in `lib/**.dart` against `id:` refs here;
   fail on unknown ids (allowlist dynamic `${idPrefix}_*`).
