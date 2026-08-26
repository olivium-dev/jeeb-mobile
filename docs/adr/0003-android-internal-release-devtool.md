# ADR 0003: Restricted Android internal-release QA tool

- Status: Accepted
- Date: 2026-08-26
- Owners: Jeeb Mobile

## Context

Play Internal Testing needs a small, inspectable QA surface in the store-signed
Android application. The existing full developer tool can mint or select test
identities, mutate journeys, change endpoints, and use mocks. Compiling that
graph into a release candidate would materially widen the authentication and
business-action blast radius. Jeeb also has locked cash-on-delivery, gateway-only,
no-LAN-host, no-cleartext, and Clarity-off staging policies.

## Decision

We extend `jeeb-mobile` and reuse OMDS, `AppConfig`, the existing local-auth
gateway, connectivity reachability source, secure storage, and shared preferences.
No backend, auth contract, service, or new state-management package is introduced.
Ephemeral unlock/status state stays in a local `StatefulWidget`; adding Riverpod
beside the app's BLoC graph would add lifecycle and cold-start cost without shared
state benefits.

Android gains an `internalRelease` flavor with the unchanged
`com.olivium.jeeb` store identity and the normal protected release signer. Its
dedicated `DevToolLauncher` Activity and Flutter engine exist only in the flavor
source set. The legacy full tool launcher exists only in the Android debug source
set. The production and iOS Dart entrypoints never import the restricted tool.

The internal entrypoint starts only under this truth table:

| Gate | Required value | Drift result |
|---|---|---|
| Native build | non-debug release | blocked screen |
| Native flavor/resource | `internalRelease` / `true` | blocked screen |
| Dedicated launcher | `true` for `/devtool` | blocked screen |
| Dart build/flag | release / `JEEB_INTERNAL_RELEASE=true` | blocked screen |
| Runtime | `APP_FLAVOR=staging` | blocked screen |
| HTTP origin | `https://app.jeeb.fds-1.com` | blocked screen |
| Realtime | `wss://app.jeeb.fds-1.com/socket/websocket` | blocked screen |
| Clarity | enabled/privacy false; project id empty | blocked screen |
| Route | exact `/devtool` | normal launcher opens `JeebBootstrap` |

The tool requires device biometric/credential authentication and exposes only
build/environment status, a local-only connectivity reading, and confirmed local
data clearing with a second unlock. It shows exact staging HTTP/WSS endpoints,
Clarity off, and normal SMS only. Stable `Semantics(identifier:)` values provide
black-box selectors without text, coordinates, or PII.

No live health request is shipped. The repository has no approved public-gateway
client abstraction that guarantees redacted bodies and credentials for this
surface. Catalog is also deferred because its offline/sanitized isolation is not
proven. Super Login/Plus, token minting, rosters, scenarios, KYC/admin, OTP,
location, delivery, server editing, raw logs, mocks, payments, and direct upstream
ports are excluded by source and binary contracts.

Build numbers are monotonic across both stores and have floor `26082601`. The
internal profile must re-read Play and App Store maxima, build with Clarity
false/false and exact staging defines, inspect the signed AAB, and record
`devtool=true`, `super_login=false`, `retained=true`, and `store_uploaded=false`.
The separate upload lane can target Google Play `internal` only.

## Consequences

- Defense in depth prevents a single Gradle resource, Dart define, route, or
  runtime configuration mistake from opening the tool.
- Production and iOS release inspectors reject internal entrypoints, UI markers,
  labels, and positive internal defines.
- The flavor adds one Android-only Flutter engine when the QA launcher is opened;
  the normal app cold start and production binary avoid the restricted Dart graph.
- Connectivity proves device reachability only; it does not claim gateway health.
- Local clear is destructive only to this installation and never calls a server.

Rollback is to disable or remove the `internalRelease` workflow/profile and stop
promoting its higher build code. Existing production and iOS lanes remain
unchanged and reject internal markers.

## Alternatives considered

1. Reuse the full legacy developer tool in release: rejected because its auth and
   mutation capabilities violate least privilege and expand incident blast radius.
2. Add a hidden route in `MainActivity`: rejected because launcher identity and
   engine isolation would rely on a single Dart route check.
3. Add a backend QA endpoint: rejected because no backend/auth change is
   authorized; any such defect or contract would require a separate architecture
   and Claude guardrail debate.
