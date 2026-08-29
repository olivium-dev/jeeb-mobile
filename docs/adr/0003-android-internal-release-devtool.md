# ADR 0003: Full Android staging Dev Tool on Play Internal Testing

- Status: Accepted (supersedes the restricted-surface decision)
- Date: 2026-08-29
- Owners: Jeeb Mobile

## Context

The Android Internal Testing launcher was originally replaced with a small
status-and-connectivity page. That was not the requested staging behavior: QA
needs the existing full Jeeber Dev Tool menu, including Super Login, Screen
Catalog, Actions, Location Simulator, Server URL, Clear Local Data, and Scenario
Users. The status-only page also made a successfully distributed build appear
to be the wrong application.

## Decision

The `internalRelease` flavor keeps the unchanged `com.olivium.jeeb` store
identity, protected release signer, separate `DevToolLauncher` activity, exact
`/devtool` route, and native/Dart fail-closed policy checks. Once those checks
pass, `lib/main_android_internal.dart` routes through the existing product root
with the Dev Tool initially open. This reuses the original `DevToolShakeHost`
and `DevToolShell`, including the `Apply & Restart` and close controls, instead
of maintaining a second QA page.

The staging build must explicitly set all of these Dart gates:

| Gate | Required value |
|---|---|
| `APP_FLAVOR` | `staging` |
| `JEEB_INTERNAL_RELEASE` | `true` |
| `JEEB_DEVTOOL_ENABLED` | `true` |
| `JEEB_STAGING_DEVTOOL` | `true` |
| `JEEB_DEVTOOL_SHAKE` | `false` on Android |
| Gateway | `https://app.jeeb.fds-1.com` |
| Realtime | `wss://app.jeeb.fds-1.com/socket/websocket` |
| Clarity enabled/privacy | `false` / `false` |

The artifact inspector requires the complete menu and launcher-control markers,
plus both Super Login endpoints. Provenance and distribution receipts bind
`devtool=true`, `super_login=true`, and `shake_to_open=false`. Candidate
encryption, exact-SHA custody,
release signing, dual-store build-number monotonicity, and Play Internal-only
upload remain unchanged.

Production containment is unchanged: the ordinary Android and iOS release
inspectors continue rejecting the internal entrypoint, full Dev Tool graph,
Super Login material, launcher label, and positive internal defines. The
production build does not receive the two Dart enablement defines or the native
internal flavor/resource/launcher combination.

The `.50` host, production API host, direct upstream ports, UPG/payment routes,
and Clarity remain forbidden in the internal artifact. No backend or production
authentication behavior changes in this decision.

## Consequences

- Opening **Jeeber Dev Tool** from Play Internal Testing displays the original
  full tool, not a status page.
- No biometric or device-credential gate is introduced by this launcher.
- The Server URL override is enabled only when development affordances are
  compiled in, so it works for the internal Dev Tool while remaining inert in
  production.
- The normal launcher in the same internal package still opens the Jeeb product
  app.
- Rollback is to stop distributing the internal candidate; it must not be
  replaced with another reduced tool under the same launcher contract.
