# SPRINT-001 — Real cross-device login against the MSI backend

Backend (real): `http://192.168.2.39:10090` (native JeebGateway). Origin-only — every
request adds its own single `/v1`. Confirmed reachable from this LAN; `/health` → 200.

## Why the app currently fakes its own login / never hits a real backend

1. `AppConfig.gatewayBaseUrl` default is `https://api.jeeb.app`
   (`lib/core/config/app_config.dart:31`) — that host fails DNS on the devices.
   It is **contract-pinned** (`test/core/config/base_url_convention_test.dart:39,64`)
   to prevent the S16 `/v1/v1` doubling regression, so we override it with
   `--dart-define=GATEWAY_BASE_URL`, never by editing the default.
2. The "hardcoded JWT" is the **debug-only** session seam
   (`lib/core/dev_seam/session_seam_bootstrap.dart`): when launched with the intent
   extra `jeeb.seam.session=customer_logged_in` it writes a synthetic
   `mock-jwt-access-user-client-001` token into secure storage. It is `kDebugMode`
   gated and **opt-in** — if QA simply does NOT pass that extra, the app performs a
   real OTP login. (A synthetic token sent to `:10090` is rejected with 401, so it
   can never produce a false PASS against the real backend.)

## Real login — verified working on :10090

Login is phone + OTP. In the MSI/dev environment the OTP service runs in mock mode and
accepts the fixed code **`1234`** for any `+961…` phone (real SMS not required).

```
POST /v1/auth/otp/request   {"phone":"+961XXXXXXX"}            -> 200 {"ttlSeconds":300}
POST /v1/auth/otp/verify    {"phone":"+961XXXXXXX","code":"1234"} -> 200 {accessToken, refreshToken, user}
```

Role landing is then driven by `GET /v1/users/me` (`lib/core/role/role_sync.dart`).

### Planned device → user assignment

| Device | Role intent | Phone | Real userId | `/v1/users/me` today |
|---|---|---|---|---|
| iOS Simulator | CLIENT | `+9613000077` | `b4c26077-0985-40a1-b799-ec001bc9ad10` | `activeRole=client, availableRoles=[client]` ✅ |
| Android `R5CT71TVVAJ` | DUAL JEEBER | `+9613000002` (Kamal seed) | `c23efd76-6fa4-40cf-814c-116f67ea5e95` | `activeRole=client, availableRoles=[client]` ⚠️ see blocker |

## Run commands

```bash
# iOS Simulator — real CLIENT
GATEWAY=http://192.168.2.39:10090 tool/run_realbackend_msi.sh ios
# then in-app: enter +9613000077, OTP 1234

# Android physical — real (intended) JEEBER
tool/run_realbackend_msi.sh android
# then in-app: enter +9613000002, OTP 1234
```

Do **not** pass `--ez`/intent extras for `jeeb.seam.session`; that engages the fake
session. Real login only.

## BLOCKER — dual-role not emitted by the live gateway

`+9613000002` (Kamal) is `ActiveRole=driver, AvailableRoles={customer,driver}` in the
identity DB (`192.168.2.20 / jeeb-user-management`) and its KYC state is `Verified`,
yet `:10090` returns `activeRole=client, availableRoles=[client]` — the
`driver→jeeber` role is dropped in the gateway's role projection (`/v1/auth/otp/verify`
and `/v1/users/me`). No active-role-switch route exists (all candidates 404). Until the
gateway emits `available_roles` containing `jeeber`, the dual-role landing fix cannot be
exercised on a device. This is a **server-side** fix (gateway `JeebRoleTranslator` /
the role-projection read path), not a mobile change.
