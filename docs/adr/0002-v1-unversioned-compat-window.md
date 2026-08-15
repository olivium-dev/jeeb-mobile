# ADR 0002 — The `/v1` unversioned compat window, and the auth flag-day precondition

- Status: Accepted
- Date: 2026-08-16
- Deciders: Jeeb mobile engineering
- Supersedes: nothing. Related: gwdbx W6-02 (gateway route de-versioning).

## Context

The gateway programme (gwdbx) is dropping the `/v1` prefix from its route
literals. `jeeb-mobile` serves no HTTP routes of its own, so it cannot "add an
alias"; it is purely a **caller**, and it holds roughly **310 `/v1/...` string
literals** spread across feature repositories, services and screens.

`UnversionedPathFallbackInterceptor` (PR #257) is the compat window for that:
a Dio error interceptor that, on a `404`/`405` from a `/v1/...` path, replays
the same call **once** against the unversioned twin. `404`/`405` is the whole
safety argument — both statuses mean no handler ran, so replaying a `POST` or
`PATCH` cannot duplicate a side effect that already happened.

### The hole this ADR exists to close

`TokenRefreshInterceptor` does not use the app's main `Dio`. It refreshes over a
**dedicated `Dio` that carries no interceptors** (`dio_client.dart`), on purpose:
a refresh performed through the main client would re-enter the refresh logic on
its own `401` and loop. That deliberate isolation also excluded it from the
compat window — so on the day `/v1/auth/refresh` stops existing, the refresh
call would `404`, `TokenRefreshInterceptor` would treat that as a dead session
and call `_logout()`.

That failure mode is not a bad screen. Refresh runs when an access token
expires, which happens to **every installed app, unprompted, within hours** —
so removing the route force-logs-out the entire installed base at once, and the
only recovery is a fresh OTP sign-in. It is the highest-blast-radius item in the
de-versioning programme and it is invisible until it fires.

### What the gateway actually serves today (verified on `jeeb-gateway@main`)

| Mobile path | Unversioned twin today | Served by |
|---|---|---|
| `/v1/auth/otp/request`, `/v1/auth/otp/verify` | yes | `AuthOtpController` — **dual-routed** `[Route("v1/auth/otp")]` + `[Route("auth/otp")]` |
| `/v1/auth/login`, `/signup`, `/set-password`, `/recovery*`, `/social` | yes | `AuthEmailFacadeController` — **dual-routed** `[Route("v1/auth")]` + `[Route("auth")]` |
| `/v1/auth/refresh`, `/v1/auth/logout` | yes, but a **different class** | `[Route("v1/auth")]` on `AuthRefreshV1Controller`; the unversioned pair is served by the `[Obsolete] AuthController` at `[Route("auth")]` |

The refresh twin is a *different controller* but **not a different behaviour**:
`AuthController.Refresh` delegates to the same `ITokenService.RefreshAsync`
(same rotate-on-use, same reuse detection), and its `TokenPairResponse` is a
camelCase **superset** of `RefreshPairResponse` — `accessToken` /
`refreshToken` deserialize identically, and the extra `tokenType` /
`accessTokenExpires*` fields are ignored by the client. So the twin is a real,
compatible target, unlike `/deliveries` and `/requests*`, which the interceptor
blocks precisely because their unversioned forms are genuinely different
actions.

## Decision

**1. The refresh client gets a scoped copy of the fallback.**
`UnversionedPathFallbackInterceptor` takes an optional `scopedToSubtrees`, and
`DioClient.createDio` attaches an instance scoped to `['/v1/auth']` to the
refresh `Dio`. It stays recursion-free by construction: that client still has
no `BearerAuthInterceptor` and no `TokenRefreshInterceptor`, so a replay cannot
start a second refresh, and the interceptor's own `retriedFlag` caps it at one
replay.

It is **inert today**. It fires only on `404`/`405`, and the live gateway
answers `POST /v1/auth/refresh` with `200`, `400` or `401`. On `401` — the only
failure the app sees in practice — nothing is replayed and the existing logout
path runs unchanged. If both paths are missing, the original versioned error is
surfaced and behaviour is byte-identical to before this change.

**2. Removing `/v1/auth/*` is a FLAG-DAY PRECONDITION, not a cleanup.**

- **P1 — Do not delete `[Obsolete] AuthController`** (`POST /auth/refresh`,
  `POST /auth/logout`) while any shipped build still calls `/v1/auth/refresh`.
  It is the *only* thing the refresh fallback can fall back to. It is marked
  `[Obsolete]` and listed for removal in the gateway's remediation plan — that
  removal is now coupled to mobile's release train.
- **P2 — Do not delete `AuthRefreshV1Controller`** (`POST /v1/auth/refresh`)
  until a mobile build whose auth paths are already unversioned has **shipped**
  and the tail of un-upgraded installs has drained. There is no in-app recovery:
  every user still on an older build is logged out and must re-OTP.
- **P3 — Order is ship-then-remove, never remove-then-ship.** Mobile release
  first, install tail second, server route removal last.
- **P4 — The interceptor is a safety net, not the migration.** The ~310 `/v1`
  literals in `lib/` still have to be migrated. Every replay costs a wasted
  round trip and writes a `404` into the gateway logs, so a fleet running on the
  fallback looks healthy while doubling its auth-path request count.

## Consequences

- (+) A gateway-side removal of `/v1/auth/refresh` alone no longer logs out the
  installed base; the refresh silently lands on the legacy twin.
- (+) The fallback's blast radius on the auth path is bounded to `/v1/auth` by
  an explicit scope, so widening the shared interceptor's general rules later
  cannot silently widen what the refresh client will replay.
- (−) A *simultaneous* removal of both `/v1/auth/refresh` and the legacy
  `/auth/refresh` still logs everyone out. Only P1–P3 prevent that; no client
  change can.
- (−) One extra request on the refresh path in the window between the two
  removals. Bounded at one, on the same rate-limit policy.
- (−) The interceptor makes an incomplete migration survivable, which reduces
  the pressure to finish it. P4 is the counterweight.
