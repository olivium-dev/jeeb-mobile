# 42 — Guardrails: Mock & Networking

> **Phase 2 deliverable (Senior Principal Engineer — Mock & Networking guardrail).** The standing
> reference for how the Flutter app reaches the mock backend, how to keep app DTOs and mock
> responses in lockstep, and the single consolidated mock-fix worklist for backenders. Companion
> to `40_GUARDRAILS.md` (semantics/maestro/gradle), `20_GAP_MAP.md` (per-screen gaps + mock-gap
> table), `30_BACKLOG.md` (JM items), `21_NAV_PLAN.md` (routes), `12_MOCK_INVENTORY.md`.
>
> Source of truth verified 2026-06-18 by reading: `lib/core/network/mock_gateway_client.dart`,
> `lib/core/network/dio_client.dart`, `lib/core/network/auth_token_store.dart`,
> `jeeb-mock-backend/src/server.ts`, `config.ts`, and the auth / wallet / offer / delivery /
> user-management / notification / compliment / score-taking services.
>
> **Decision authority:** CTO-D1, CTO-D2, CTO-D3 (`01_CTO_DECISIONS.md`); product decisions
> D1–D93 (`jeeb-mind-map/docs/07_DECISIONS_LOG.md`). Cite by id; never re-litigate.

---

## 1. How the app reaches the mock

### 1.1 The two-mock reality (READ THIS FIRST — there is a port/flag coupling)

The app has **one networking seam**, `MockGatewayClient` (`lib/core/network/mock_gateway_client.dart`),
that can target **either of two different mocks**. The choice is hard-coded by two `const`s that
**must be set as a pair**:

| `useMockPrefixes` | `mockBaseUrl` default | Target | Contract spoken | Path handling |
|---|---|---|---|---|
| `true` (current) | `http://10.0.2.2:3055` | **the Express mock** (`jeeb-mock-backend`, default port **4010**) | service-prefixed (`/auth-service/...`, `/offer-service/v1/...`) | `rewritePath()` rewrites gateway paths → service prefixes |
| `false` | `http://10.0.2.2:3055` | Mockoon gateway-shaped mock | raw gateway contract (`/v1/auth/otp/request`) | pass-through, no rewrite |

**⚠️ Misconfiguration B0 (new — flag this):** the file ships with `useMockPrefixes = true` (line 30),
which means "target the service-prefixed Express mock", **but `mockBaseUrl` still defaults to
`http://10.0.2.2:3055`** (lines 22–25) — the Mockoon port. The Express mock (`server.ts` +
`config.ts`) listens on **`4010`**. So in the current configuration the app rewrites paths to the
`:4010` service-prefix shape and then sends them to `:3055`, which speaks a different contract. The
two `const`s are internally inconsistent. **Foundation must reconcile this:** when
`useMockPrefixes = true`, the default `mockBaseUrl` must be `http://10.0.2.2:4010` (Android) — or the
run must always pass `--dart-define=JEEB_MOCK_BASE_URL=http://10.0.2.2:4010`. This is a foundation
fix that gates *all* mock-backed work, not just auth. **Owner: Foundation (Phase 2).**

> The rest of this doc assumes the intended target is the **Express mock at `:4010`** with
> `useMockPrefixes = true` (the CTO brief §4 baseline), and that B0 above is fixed so the base URL
> points at `:4010`.

### 1.2 Service-prefixed routes + the rewrite map

The app speaks the **gateway/BFF contract** (`/v1/chat/jeeb/...`, `/v1/offers`, `/auth/otp/...`).
The Express mock mounts **22 service routers under per-service prefixes** in `server.ts`
(`/auth-service`, `/user-management`, `/wallet-service`, `/chat-service`, `/delivery-service`,
`/offer-service`, `/matching`, `/geolocation-service`, `/notification-service`,
`/score-taking-service`, `/compliment-service`, `/form-builder-service`,
`/voice-transcription-service`, `/push-notification`, `/unified-payment-gateway`,
`/realtime-comunication-service`, `/feedback-service`, `/ban-service`,
`/contract-signing-service`, `/gateway`, `/cms-admin`). The bridge between the two shapes is
`MockGatewayClient.rewritePath()` driven by `_pathToServicePrefix` (lines 32–62).

**How the rewrite works (`rewritePath`, lines 64–73):** first-match-wins prefix replacement —
it iterates the map in declaration order and, for the first key the path `startsWith`, replaces
that prefix. It is wired in as `_PathRewriteInterceptor` (Dio `onRequest`, lines 116–122), added
only when `useMockPrefixes == true`. The full map today:

```
/auth/otp              → /auth-service/auth/otp
/auth/social           → /auth-service/auth/social
/auth/refresh          → /auth-service/auth/refresh
/users                 → /user-management/users
/v1/chat/jeeb          → /chat-service/v1/chat/jeeb
/v1/offers             → /offer-service/v1/offers
/v1/delivery           → /delivery-service/v1/delivery
/v1/tiers              → /delivery-service/v1/tiers
/v1/requests           → /delivery-service/v1/requests
/api/requests          → /delivery-service/api/requests
/v1/matching           → /matching/v1/matching
/v1/availability       → /geolocation-service/v1/availability
/v1/notifications/send → /notification-service/v1/notifications/send
/v1/notifications      → /notification-service/v1/notifications
/v1/ratings/jeeb       → /score-taking-service/v1/ratings/jeeb
/v1/feedback/jeeb      → /feedback-service/v1/feedback/jeeb
/v1/templates          → /form-builder-service/v1/templates
/v1/contracts          → /contract-signing-service/v1/templates
/v1/moderation/jeeb    → /ban-service/v1/moderation/jeeb
/v1/disputes           → /compliment-service/v1/disputes
/v1/payments/cod_jeeb  → /unified-payment-gateway/v1/payments/cod_jeeb
/v1/jeeb/earnings      → /wallet-service/v1/jeeb/earnings
/api/deliveries        → /delivery-service/api/deliveries
/v1/deliveries         → /delivery-service/v1/deliveries
/v1/transcribe         → /voice-transcription-service/v1/transcribe
/v1/devices            → /push-notification/v1/devices
/channels/jeeb-chat    → /realtime-comunication-service/channels/jeeb-chat
```

**Ordering hazard to know:** because it is `startsWith` first-match, **the more specific key must
precede the more general one**. `/v1/notifications/send` is correctly listed *before*
`/v1/notifications` (lines 47–48) so the send path is not swallowed. Any new entry that is a prefix
of an existing key must be inserted **above** it. This is a standing rule for editing the map.

### 1.3 The B1 auth-rewrite gap (owned by Foundation)

**Confirmed by reading both sides:**
- App side — `lib/features/registration/data/dio_otp_service.dart` posts to **`/v1/auth/otp/request`**
  and **`/v1/auth/otp/verify`** (lines 24, 43).
- Map side — the only auth keys are **`/auth/otp`**, **`/auth/social`**, **`/auth/refresh`** —
  **none has the `/v1` prefix.**

`rewritePath('/v1/auth/otp/request')` therefore matches **no** key (`/v1/offers`, `/v1/delivery`,
etc. are siblings, not prefixes of `/v1/auth/...`), falls through unchanged, and is sent verbatim to
the base URL. The Express mock has no `/v1/auth/otp/*` route (its auth router is mounted at
`/auth-service/auth/otp/*`), so the request 404s. **Net effect: app auth never reaches `:4010`.**

This is labelled **B1** in `20_GAP_MAP.md` and **owned by Foundation** (not backenders — it is an
*app-side rewrite map* edit, Phase 2). The fix is to add `/v1`-prefixed auth keys to the map, e.g.:

```
'/v1/auth/otp':     '/auth-service/auth/otp',
'/v1/auth/social':  '/auth-service/auth/social',
'/v1/auth/refresh': '/auth-service/auth/refresh',
'/v1/auth/login':   '/auth-service/auth/login',
'/v1/auth/logout':  '/auth-service/auth/logout',
```
(keep the legacy `/auth/...` keys too for backward compat; place these `/v1/auth/*` keys **above**
any broader `/v1` key — none today is broader, but the ordering rule stands). **Related but distinct:
B2** — social auth posts `/api/auth/social` (`social_auth_service.dart:142`), which has **no map key
at all** and **no `:4010` handler**; it is a separate fix (define the route + reconcile the app path),
owned by backenders. See the register in §4.

### 1.4 Auth token plumbing

`_AuthInterceptor` (lines 124–137) injects `Authorization: Bearer <token>` when a token is set and
the header is absent. Tokens are persisted by `AuthTokenStore` (`auth_token_store.dart`) in the
platform keychain (`flutter_secure_storage`). The mock issues opaque
`mock-jwt-access-<userId>` / `mock-jwt-refresh-<userId>` strings (auth-service.ts:55–60); the mock's
`authStub` middleware decodes the userId from the bearer token to resolve `req.userId` (this is what
`GET /users/me` reads — see U1 in §4). There is **no** cookie path on mobile: the mock also sets an
HttpOnly `jeeb_rt` refresh cookie (auth-service.ts:49–53, 108–112) for the CMS shell, but the Flutter
client uses the **body** refresh path (`{ refreshToken }`), which the mock still honors
(auth-service.ts:130–131). No change needed mobile-side.

---

## 2. Emulator host mapping to the host mock

The mock runs on the **developer's host machine** (`npm run dev` → `localhost:4010`). Emulators and
sims do not share the host's `localhost`; the single source of truth for the base URL is
`MockGatewayClient.mockBaseUrl` (overridable via `--dart-define=JEEB_MOCK_BASE_URL=...`).

| Target | Host alias for the dev machine | Base URL to use (Express mock) |
|---|---|---|
| **Android emulator** (primary, AVD `jeeb_test`, R-A) | `10.0.2.2` (the emulator's NAT alias to the host loopback) | `http://10.0.2.2:4010` |
| **iOS simulator** | the sim shares the host network → `localhost`/`127.0.0.1` works, or the host LAN IP | `http://localhost:4010` (or `--dart-define` LAN IP) |
| **Physical device** | the host's **LAN IP** (`192.168.x.x`) — `10.0.2.2`/`localhost` do NOT resolve | `--dart-define=JEEB_MOCK_BASE_URL=http://<host-lan-ip>:4010` |

The code comment (lines 18–21) already documents `10.0.2.2` for Android and the LAN-IP override for
iOS/physical. **The only correction needed is the port** (`:4010`, not the `:3055` default — see B0,
§1.1) and the matching `useMockPrefixes` pairing. The WebSocket shim (`webSocketUrl`, lines 109–113)
derives host from `mockBaseUrl` but hard-codes port **`3056`** for the Phoenix/SSE realtime channel;
keep that in mind when overriding the base URL — only the host is reused, the WS port is fixed.

**Standing run guidance (Android, primary surface R-A):**
```
emulator -avd jeeb_test
flutter run --flavor dev \
  --dart-define=JEEB_MOCK_BASE_URL=http://10.0.2.2:4010
# (with useMockPrefixes = true → Express mock at :4010)
```

---

## 3. Adding a new mock endpoint and keeping app DTO ↔ mock response in lockstep

When a JM item needs a contract the mock does not serve (every B/U/T/W-m/O/S/R1m item in §4), the
**backender and the app engineer touch the contract in lockstep** through the artifact files. The
canonical procedure:

1. **Fix the wire shape from the spec, not from code.** The response shape is dictated by the
   blueprint per-screen contract (`jeeb-mind-map/web/src/screens/_data/<id>.json`) and the governing
   decision(s). E.g. W1m's `affordabilityState` enum is fixed by CTO-D2 + D43, not invented. If the
   spec is silent and no CTO-D covers it, apply **R-F** (most blueprint-consistent, least-surprising;
   record the assumption inline) — do **not** guess divergently from the app.

2. **Backender: add the route under the correct service prefix.** Add the handler to the matching
   `src/services/<service>.ts` router (it is already mounted in `server.ts`). Follow the in-repo
   conventions: validate inputs and throw `ProblemError(status, code, detail, …)` (RFC-7807 via
   `middleware/problem.ts`); use `idempotency` middleware for POSTs that mutate; seed any fixture
   rows in `src/fixtures/seed.ts`. **Additive only** — do not modify existing routes (every W7a/W1
   admin block in the services follows this "additive, no existing route modified" rule; keep it).

3. **App engineer: add the rewrite-map key.** The app calls the **gateway path** (e.g.
   `GET /v1/jeeb/wallet`); add the prefix mapping to `_pathToServicePrefix` so it rewrites to the
   service route (`/wallet-service/v1/jeeb/wallet`). Respect the **specific-before-general ordering
   rule** (§1.2). This is a shared-file edit — batch it centrally per wave (CTO brief §7), exactly
   like `app_router.dart` route ADDs.

4. **Lockstep the DTO.** The app's `data/` layer model (`fromJson`/`toJson`) and the mock's response
   object must agree field-for-field. The contract is **defined once** in this doc / the JM item's
   AC, then both sides implement it. If they ever diverge, the **blueprint `_data/<id>.json` +
   decision id is the tiebreaker**, not whichever side shipped first. Tests assert the shape:
   the mock has `smoke.test.ts` / per-service `*.test.ts` (e.g. `auth-cookie.test.ts`); add a case
   there for the new route, and the app's repo test mocks the same JSON.

5. **Verify end-to-end before "done."** Per DoD (CTO brief §10) the screen must be wired to `:4010`
   and its Maestro flow must pass on the emulator. A contract is only "in lockstep" once a real
   request from the running app returns the agreed shape and the screen renders it (not a unit mock).

> **Anti-pattern to avoid:** building a wallet/ledger screen against an invented wire format because
> the mock has no endpoint yet. CTO-D2 explicitly allows the **UI shell** to start, but data-bound
> ACs cannot pass until W1m–W3m land. Build the widget tree + states; gate the data-bound AC on the
> mock fix. Same applies to S1 (support), R1m (reviews), O1 (insufficient-balance 402).

---

## 4. THE CONSOLIDATED MOCK-FIX REGISTER (single backender worklist)

Every mock/contract gap flagged across `20_GAP_MAP.md` (the "Mock contract gaps that gate work"
table + per-domain notes) and `30_BACKLOG.md` (wave gates + per-JM Mock lines), de-duplicated into
one table. Each row is verified against the actual service source. **B0/B1 are app-side (Foundation);
all others are backender (`jeeb-mock-backend`) work.** "Verified" = what the source actually does
today.

| id | what to add/fix | service file (`src/...`) | verified today | unblocks JM | wave (gate) | owner |
|---|---|---|---|---|---|---|
| **B0** | Reconcile `useMockPrefixes`/`mockBaseUrl` pairing — base URL must point to `:4010` when prefixes on (port mismatch: code defaults `:3055`, Express mock is `:4010`) | app `core/network/mock_gateway_client.dart` (l.22–30) | `useMockPrefixes=true` but `mockBaseUrl` default `:3055`; Express `config.port=4010` | **ALL mock-backed JM** | W0 (pre-everything) | Foundation |
| **B1** | Add `/v1/auth/*` keys to rewrite map (`/v1/auth/otp`, `/v1/auth/social`, `/v1/auth/refresh`, `/v1/auth/login`, `/v1/auth/logout`) | app `core/network/mock_gateway_client.dart` `_pathToServicePrefix` | map keys only `/auth/otp`,`/auth/social`,`/auth/refresh` (no `/v1`); app posts `/v1/auth/otp/*` | JM-007, 008, 009, 018 | W0 (gate) | **Foundation** |
| **B2** | Define `POST /auth/social`; reconcile app's `/api/auth/social` (add map key `/api/auth/social` or repoint app) | `services/auth-service.ts` (+ app `social_auth_service.dart:142`) | no `/auth/social` handler; map has `/auth/social` key but no route; app uses `/api/auth/social` (unmapped) | JM-018, JM-019 | W0 (gate) | backenders |
| **B3** | App-client auth routes: email/password **signup-by-email** (find-or-create), **recovery-code request**, **recovery-code verify**, **set-password**. (`/auth/login` exists but is **admin-only**, hard-coded `admin@jeeb.local`.) | `services/auth-service.ts` | only `/auth/login` (admin cred map), `/auth/otp/*`, `/auth/refresh`, `/auth/logout` exist | JM-007, 008, 020, 021, 022 | W0 (gate) | backenders |
| **B4** | OTP length contract: mock issues 4-digit `'1234'`; app UI is 6-digit. Make mock emit/accept a 6-digit code (or agree the length and align both) | `services/auth-service.ts` (l.70 `const code = '1234'`) | hard-coded `'1234'` (4 digits) | JM-009 | W0 (gate) | backenders |
| **U1** | `GET /users/me` must surface **account `status`** (suspended/locked) **and role-level `kycStatus`**. Today suspension is encoded as `activeRole='suspended'` (admin PATCH) and there is **no** `kycStatus` on the user; KYC lives only in a separate `kycSubmissions` map keyed by userId | `services/user-management.ts` (`/users/me` l.9–17; status via `/admin/users/:id/status`) + `fixtures/seed.ts` (users carry no `status`/`kycStatus`) | `/users/me` returns raw user (no `status`, no role `kycStatus`) | JM-066 (status gate), JM-036/044 (KYC gate) | W0 status branch / W2 KYC | backenders |
| **K1** | Reconcile KYC gateway paths: app KYC wizard calls `/v1/kyc/*`; mock serves KYC via `form-builder-service` (`/v1/templates/jeeb_jeeber_v1`) + `user-management` (`/users/:id/kyc`, `/users/:id/kyc-link`). Add map keys and/or align app paths | app KYC data layer + map; `services/form-builder-service.ts`, `services/user-management.ts` | `/users/:id/kyc` (GET), `/users/:id/kyc-link` (POST) exist; no `/v1/kyc/*` | JM-040 | W2 | backenders / reconcile in app |
| **T1** ✅ **DONE (W1)** | Tier catalog must return **5 tiers** (Flash/Express/Standard/On-the-Way/Eco, R-C). Seed serves only **3** | `fixtures/seed.ts` (`store.deliveries.set('__tiers', […])` l.95) served by `services/delivery-service.ts` `GET /v1/tiers` (l.18) | **LANDED** — `seed.ts` `TIER_CATALOG` now exports all 5 (`flash`/`express`/`standard`/`on-the-way`/`eco`); `GET /v1/tiers` returns them in that order; `smoke.test.ts` updated 3→5 + `w1-journey-seam.test.ts` asserts ids/names | JM-024 (also JM-045 ETA-by-tier) | W1 | backenders |
| **W1m** | `GET /v1/jeeb/wallet` → `{ availableBalance, affordabilityState: 'enough'\|'low'\|'empty'\|'all_reserved', reservedNow, giftCredit }` (CTO-D2, D1/D43/D42). Add map key `/v1/jeeb/wallet` → `/wallet-service/v1/jeeb/wallet` **above** existing `/v1/jeeb/earnings`? No — siblings; order is fine but verify no `/v1/jeeb` general key | `services/wallet-service.ts` (currently earnings-only) | only `/v1/jeeb/earnings*`; no balance/affordability/reserved-now | JM-053, JM-046 | W2.5 (gate) | backenders |
| **W2m** | `GET /v1/jeeb/wallet/ledger` → typed paginated rows `{ id, type: reserve\|fee_won\|released\|refund\|penalty\|topup\|gift, amount, sign, ref, ts }` (CTO-D2) | `services/wallet-service.ts` | no ledger endpoint | JM-055 | W3 (gate) | backenders |
| **W3m** | `GET /v1/jeeb/wallet/ledger/:id` → per-row detail (per-type copy fields; fee_won carries exact-10% + pinned price, D37; refund/penalty carries dispute ref, D2) | `services/wallet-service.ts` | no transaction-by-id endpoint | JM-056 | W3 (gate) | backenders |
| **O1** | `POST /v1/offers` must return **402** `{ needed, available }` on insufficient balance, and emit reserve/capture/release **ledger rows** on submit/win/lose (CTO-D2, D1). Today only 409 (duplicate request+jeeber) | `services/offer-service.ts` (l.10–37 submitOffer; only 409 path) | submit returns 201; duplicate → 409; **no 402, no balance check, no ledger emission** | JM-046 | W2 (money line, gates on W2.5) | backenders |
| **D1m** ✅ **DONE (W1)** | Proof-of-delivery **photo upload sink** (D3) for receipt-confirm + mark-delivered (accept the `evidenceUrl` already supported by transition, but provide an upload/store endpoint that returns a URL) | `services/delivery-service.ts` (transition accepts `evidenceUrl` l.42; no upload sink) / new | **LANDED** — `POST /delivery-service/v1/delivery/proof-photo` returns `{ url, evidenceUrl, deliveryId }` and opportunistically stamps `proofPhotoUrl`/`evidenceUrl` on an existing delivery; reachable via the existing `/v1/delivery` rewrite key (no map edit). Covered by `w1-journey-seam.test.ts` | JM-033, JM-051 | W1 / W2 | backenders |
| **S1** | **Support-ticket service** (create + list tickets, category/body/attach/order-link). Closest today is `compliment-service` (disputes only) | new `services/support-service.ts` (mount in `server.ts`) or extend compliment-service | no support-ticket routes; `compliment-service` is disputes-only | JM-063 | W4 (gate) | backenders |
| **R1m** | **Reviews-list source** — paginated reviews for a jeeber (reviewer first-name D58, cold-start <5 hide D59, report D27). `score-taking-service` only reveals **per-delivery** state on `:deliveryId/status` | `services/score-taking-service.ts` (extend) or new reviews route | only `/v1/ratings/jeeb/:deliveryId/status` (per-delivery reveal); no per-jeeber list | JM-068 | W4 (gate) | backenders |

**Notes on adjacent contracts the register depends on (already present — no fix, just confirm):**
- `POST /v1/disputes` exists (`compliment-service.ts:10`) + `GET /v1/disputes?status=&userId=` +
  `GET/PATCH /:disputeId` — JM-060/065 dispute flows are mock-ready (snapshot auto-attach is app-side).
- `POST /v1/ratings/jeeb/submit` + `GET /:deliveryId/status` exist (`score-taking-service.ts`) —
  JM-034 rating is mock-ready (R1m is the *list*, a separate gap).
- `GET/PUT /v1/notifications/preferences` + `GET /v1/notifications?userId=` + `PATCH /:id/read`
  exist (`notification-service.ts`) — JM-057/058 are mock-ready.
- `POST /v1/delivery/status/transition` enforces the SM-1 table (`delivery-service.ts:9–15`); a
  bad transition is **422 `transition_not_allowed`** — handle that error in the app (see §5).

**Wave roll-up for backenders (sequence):**
- **W0 gate:** B0 (Foundation), B1 (Foundation), B2, B3, B4, U1 (status branch) — auth cannot start until these land.
- **W1:** T1, D1m (receipt proof).
- **W2:** U1 (KYC `kycStatus`), K1, O1 (402 path), D1m (mark-delivered proof).
- **W2.5:** W1m (balance/affordability/reserved-now) — front-loaded, gates JM-053 + the JM-045/046 money lines.
- **W3:** W2m (ledger), W3m (txn-by-id).
- **W4:** S1 (support), R1m (reviews list).

---

## 5. Error / empty / loading contract (D30) + offline guards on money actions (D35)

### 5.1 The D30 state contract (every data-backed screen)

Every screen that reads from the mock must render **four explicit states** keyed by
`Semantics(identifier:)` so QA can assert each (CTO brief §6.6). The mock makes all four reachable:

| state | trigger (mock) | UI contract (D30) | Maestro identifier convention |
|---|---|---|---|
| **loading** | request in flight | skeletons / shimmer (D73 for lists: wallet-activity, reviews) — **never** a bare spinner on lists | `<screen>_loading` |
| **empty** | mock returns `{ items: [] }` (e.g. `GET /v1/notifications` for a user with none; `GET /v1/offers?requestId=` before offers) | explicit empty-state illustration + copy + primary CTA, not a blank list | `<screen>_empty` |
| **error** | mock returns RFC-7807 `ProblemError` (4xx/5xx) — e.g. 404 `not_found`, 422 `transition_not_allowed`, 409 conflict, 401 `invalid_*` | inline error card with **Retry**; map the `code` to a localized message; never raw JSON | `<screen>_error`, `<screen>_retry_cta` |
| **content** | 2xx with data | the real screen | (screen-specific element ids) |

**Mock-specific error codes the app must handle gracefully (from the services read):**
- `401 invalid_otp` / `invalid_credentials` / `invalid_token` (auth-service) → re-prompt, do not crash.
- `409 conflict` / `already_accepted` (offer-service submit/accept) → "another offer won" / "already
  submitted" copy, refresh the list. **`already_accepted` carries `winner_user_id`/`winner_offer_id`** —
  use it to update the offer-review UI.
- `422 transition_not_allowed` (delivery-service) → the SM-1 state machine rejected the transition;
  show a soft error and re-fetch current status (do not optimistically advance the stepper).
- `422 edit_limit_reached` / `410 gone` (offer-service edit/withdraw) → disable the control + explain.
- **`402` (W1m/O1 once added)** → this is **not** a generic error; it is the **insufficient-balance**
  signal that routes to `offer-insufficient-balance` (JM-046) carrying `{ needed, available }`.
  Route, do not error-toast.
- `304 Not Modified` (wallet earnings ETag, wallet-service:27) → keep cached body, no UI change.

> **i18n:** error copy is localized; Maestro asserts on the **identifier** (`<screen>_error`), never
> the visible text (R-B), so error strings can change without breaking flows.

### 5.2 Offline / money-action guards (D35)

**Invariant (D35): money-moving and money-reserving actions are blocked while offline.** The mock
cannot simulate connectivity, so this is an **app-side guard** enforced *before* the request leaves
Dio — but it must be wired consistently and is a standing guardrail for every money surface:

| action | screen / JM | guard behavior (D35) |
|---|---|---|
| **Submit offer** (reserves 10%, D1) | offer-composer JM-045; `POST /v1/offers` | if offline, block `offer_composer_send_cta`, show offline banner; do **not** fire the reserve. Draft preserved. |
| **Accept offer** (captures fee, D11/D71) | offer-accept-confirm JM-029; `POST /v1/offers/:id/accept` | block `offer_accept_confirm_cta` offline; the accept is irreversible (closes losers) so it must not be attempted without connectivity. |
| **Top-up entry** | wallet-hub JM-053, wallet-charge-info JM-054 | charge-info is static (no network) so it is reachable offline; but the **wallet-hub money actions** (and the affordability/reserved-now reads) show the offline state, not a stale "enough to bid" green (this is the S-10 false-green risk D43 calls out). |
| **Record COD / confirm receipt** | delivered-receipt JM-033; `POST /v1/payments/cod_jeeb/record` + transition | block confirm offline; the cash hand-off + transition must be online so the ledger/earnings stay consistent. |

**How to wire it:** a connectivity check feeds a disabled/blocked state on the money CTA + an
`<screen>_offline_banner` Semantics node (so Maestro can assert the guard). The guard is **fail-safe**:
when connectivity is unknown, treat as offline for money actions (never optimistically reserve/capture).
Read-only screens degrade to cached/empty state per §5.1; only **money actions** are hard-blocked by D35.

> **Wallet affordability is a state, not a number (D43):** the wallet-hub renders
> `wallet_affordability_card` with copy ("enough to bid" / "top up to bid"), **not** a computed
> capacity count. Offline, it must not render a green "enough" it cannot verify — show the offline
> state. This is the concrete intersection of D35 (offline guard) and D43 (affordability-as-state),
> and the reason W1m's `affordabilityState` is an **enum**, not a derived client-side calculation.

---

## W-1 FLOOR CLOSED — verified auth contract

> **Owner: W-1 Foundation Closeout Engineer. Verified 2026-06-18** by an end-to-end curl
> round-trip against the running Express mock on **:4010** (and a fresh seeded instance on :4090),
> hitting the **exact rewritten paths** the app produces. **B0/B1/B2/B3/B4/U1 are CLOSED.** This is
> the contract Wave-0 auth engineers (JM-006/007/008/009/018/019/020/021/022/066) code to.
>
> **Status: GREEN — app auth reaches `:4010`.** Mock `npm run build` clean; `npm test` 256/256 pass.
> App `flutter analyze` clean on `mock_gateway_client.dart` + its test; `flutter test
> test/core/mock_gateway_client_test.dart` 18/18 pass.

### What changed to close the floor

- **B0 (app, `mock_gateway_client.dart`):** default `mockBaseUrl` now `http://10.0.2.2:4010`
  (was `:3055`), so it is coherent with `useMockPrefixes = true`. The run/build still always passes
  `--dart-define=JEEB_MOCK_BASE_URL=http://10.0.2.2:4010` (Android) / `http://localhost:4010` (iOS).
- **B1 (app, rewrite map):** added `/v1/auth/*` keys — `otp`, `login`, `signup`, `social`,
  `recovery`, `set-password`, `refresh`, `logout` — all → `/auth-service/auth/*`, placed **above**
  the broader `/v1/*` siblings. Legacy non-`/v1` `/auth/*` keys kept for back-compat.
- **B2 (app + mock):** app's legacy `/api/auth/social` now has a rewrite key → `/auth-service/auth/social`;
  mock gained a `POST /auth/social` find-or-create handler returning the **social-shaped** body
  (`{ userId, authToken, refreshToken, expiresIn, recentlyCreated }`) the app's `social_auth_service.dart`
  parses (NOT the OTP `tokenBundle`).
- **B3 (mock, already present + confirmed):** `signup` (find-or-create by email, 201 / 409
  `email_collision`), `login` (email/password, resolves app-client creds + the W7a admin map),
  `recovery/request`, `recovery/verify` (mints `resetToken`), `set-password`.
- **B4 (mock):** OTP code is the 6-digit `123456` (app input is 6 cells). **Side-effect fixed:** the
  prior `1234→123456` change had broken 7 OTP-verify assertions in `smoke.test.ts`,
  `auth-cookie.test.ts`, `w7a-cms.test.ts` — those test bodies were updated to `123456`. Suite green.
- **U1 (mock, `user-management.ts`, already present + confirmed):** `GET /users/me` and
  `GET /users/:id` surface account `status` (D5: active|pending|suspended|locked|deleted; derived,
  honoring the legacy `activeRole==='suspended'` encoding) and role-level `kycStatus`
  (D38/D52: none|pending|approved|rejected; jeeber-only, sourced from `kycSubmissions`).

### Verified endpoint table

All paths verified by curl on :4010/:4090. "App `/v1` path" = what the app posts; "Final mock path"
= after `rewritePath()`. The mock auth router is mounted at `/auth-service` (`server.ts:46`),
user-management at `/user-management` (`server.ts:47`).

| op | method | App `/v1/...` path (pre-rewrite) | Final mock path (post-rewrite) | request body | response (2xx) | status codes |
|---|---|---|---|---|---|---|
| **OTP request** | POST | `/v1/auth/otp/request` | `/auth-service/auth/otp/request` | `{ phone }` | `{ requestId, expiresInSeconds: 300 }` | 200 ok · 400 `bad_request` |
| **OTP verify** | POST | `/v1/auth/otp/verify` | `/auth-service/auth/otp/verify` | `{ phone, code }` (code = **6-digit `123456`**) | `{ accessToken, refreshToken, expiresIn:3600, user{ id, userId, phone, name, availableRoles, activeRole, … } }` + `Set-Cookie: jeeb_rt` | 200 ok · 401 `invalid_otp` (wrong/expired) · 400 |
| **Signup (email-first)** | POST | `/v1/auth/signup` | `/auth-service/auth/signup` | `{ email, password, name?, phone? }` | **201** `{ accessToken, refreshToken, expiresIn, user{ …, email, status:"active" } }` | **201** created · **409 `email_collision`** (D22; carries `{ email }`) · 400 |
| **Login (email/pw)** | POST | `/v1/auth/login` | `/auth-service/auth/login` | `{ email, password }` | `{ accessToken, refreshToken, expiresIn, user }` + `Set-Cookie: jeeb_rt` | 200 ok · **401 `invalid_credentials`** · 400 |
| **Recovery request** | POST | `/v1/auth/recovery/request` | `/auth-service/auth/recovery/request` | `{ email }` | `{ requestId, expiresInSeconds: 600 }` (no account enumeration) | 200 always · 400 |
| **Recovery verify** | POST | `/v1/auth/recovery/verify` | `/auth-service/auth/recovery/verify` | `{ email, code }` (code = **6-digit `654321`**) | `{ resetToken, expiresInSeconds: 600 }` | 200 ok · **401 `invalid_recovery_code`** · 400 |
| **Set password** | POST | `/v1/auth/set-password` | `/auth-service/auth/set-password` | `{ email, password, resetToken? }` (resetToken required for recovery mode; optional for in-app social) | `{ accessToken, refreshToken, expiresIn, user }` | 200 ok · 401 `invalid_token` (reset token mismatch) · 400 |
| **Social login** | POST | `/v1/auth/social` **and** `/api/auth/social` | `/auth-service/auth/social` | `{ provider: "google"\|"apple", idToken }` | `{ userId, authToken, refreshToken, expiresIn, recentlyCreated }` *(social shape — note `authToken`, not `accessToken`)* | 200 ok · **401 `invalid_token`** (bad/unsupported provider) · 400 |
| **Refresh** | POST | `/v1/auth/refresh` | `/auth-service/auth/refresh` | `{ refreshToken }` (body path — mobile) **or** `jeeb_rt` cookie | `{ accessToken, refreshToken (rotated), expiresIn:3600 }` | 200 ok · 401 `invalid_token` |
| **Logout** | POST | `/v1/auth/logout` | `/auth-service/auth/logout` | `{ refreshToken }` or cookie | (no body) clears `jeeb_rt` | **204** · 400 |
| **getMe** | GET | `/users/me` | `/user-management/users/me` | — (Bearer header) | `{ id, name, phone, availableRoles, activeRole, language, **status**, **kycStatus**, … }` | 200 ok · 401 (unknown userId) |
| **getUser** | GET | `/users/:id` | `/user-management/users/:id` | — | same shape as getMe incl. `status` + `kycStatus` | 200 ok · 404 `not_found` |

**Field notes for app DTOs (lockstep):**
- Token persistence reads `user.userId` (`dio_otp_service.dart:65`); the mock aliases `userId` next
  to `id` on every OTP/signup/login/set-password bundle. Social returns top-level `userId`.
- `status` enum: `active | pending | suspended | locked | deleted` (D5). `kycStatus` enum:
  `none | pending | approved | rejected` (D38/D52). Customers / non-jeebers → `kycStatus: "none"`.
- Verified seed examples: `user-client-001` → `status:active, kycStatus:none`; `user-jeeber-002`
  → `kycStatus:approved`; `user-jeeber-003` → `kycStatus:pending`.
- **Social uses `authToken`, the other flows use `accessToken`** — the app already maps these
  distinctly (`social_auth_token.dart` vs `auth_token_store`). Do not unify them.
- The `authStub` middleware resolves **any** bearer token to `user-client-001` for `req.userId`
  (`middleware/auth-stub.ts:8`). So in the mock, `GET /users/me` returns `user-client-001`
  regardless of which token is sent. Splash session-routing logic (JM-006) that needs a *different*
  identity must `GET /users/:id` by the `userId` it persisted at login, not rely on `users/me`.

### Round-trip evidence (curl on the live mock)

```
POST /auth-service/auth/otp/request   {phone}                  → 200 {requestId, expiresInSeconds:300}
POST /auth-service/auth/otp/verify    {phone, code:"123456"}   → 200 {accessToken, refreshToken, user{userId,…}}
POST  …/otp/verify  {code:"000000"}                            → 401 invalid_otp
POST /auth-service/auth/signup        {email,password,name}    → 201 {accessToken, …, user{status:"active"}}
POST  …/signup  (same email)                                   → 409 email_collision {email}
POST /auth-service/auth/login         {email,password}         → 200 {accessToken, …}
POST  …/login   (wrong password)                               → 401 invalid_credentials
POST /auth-service/auth/recovery/request {email}               → 200 {requestId, expiresInSeconds:600}
POST /auth-service/auth/recovery/verify  {email,code:"654321"} → 200 {resetToken}
POST  …/recovery/verify {code:"111111"}                        → 401 invalid_recovery_code
POST /auth-service/auth/set-password  {email,password,resetToken} → 200 {accessToken, …}
POST  …/login   (NEW password)                                 → 200   (set-password took effect)
POST /auth-service/auth/social        {provider:"google",idToken} → 200 {userId, authToken, recentlyCreated:true}
POST  …/social  (same idToken again)                           → 200 recentlyCreated:false
POST  …/social  {provider:"facebook"}                          → 401 invalid_token
POST /auth-service/auth/refresh       {refreshToken}           → 200 {accessToken, refreshToken(rotated)}
GET  /user-management/users/me                                 → 200 {status:"active", kycStatus:"none"}
GET  /user-management/users/user-jeeber-002                    → 200 {status:"active", kycStatus:"approved"}
GET  /user-management/users/user-jeeber-003                    → 200 {status:"active", kycStatus:"pending"}
```

### Remaining gaps / notes for W0 engineers (none block the seam)

- **App auth datasources for login/signup/recovery/set-password do not exist yet** — per CTO-D1
  these are new W0 screens (`/login`, `/sign-up`, recovery flow). Only `dio_otp_service.dart`
  (OTP) and `social_auth_service.dart` (social) exist today. When W0 builds the new datasources,
  they MUST post the **`/v1/auth/...` gateway paths in this table** (not the bare `/auth/...`), so
  the B1 rewrite carries them to `:4010`. The seam is proven; the callers are W0's to write.
- **Social `signOut` is native-only** (no mock call) — unchanged, correct.
- **Recovery code is non-enumerating**: an unknown email still returns 200 on `recovery/request`;
  the code simply never verifies. App UX should not reveal whether the email exists.
- The fixed dev codes (`OTP=123456`, `RECOVERY=654321`) and find-or-create identity model are
  mock-only conveniences; the wire **shapes + status codes** above are the real contract.

---

## W0 round-2 mock fixes — seeded login credential (RC-4) + `__mock/reset` auth state (RC-5)

> **Author:** Principal Backender (Opus — W0 MOCK FIXES). **Date:** 2026-06-18.
> Closes RC-4 (jm-007 login, demo-critical) and the mock half of RC-5 (jm-008/009 signup
> persistence) from `61_W0_QA_RESULTS.md`. Owner: `jeeb-mock-backend` only.

### RC-4 — pre-seeded email/password login credential

`appCredentials` (in `src/services/auth-service.ts`) was only populated at runtime by
`POST /auth/signup` + `POST /auth/set-password`, so a fresh process had **no** email/password
account and the demo-critical login flow 401'd. A fixed credential is now seeded at module load
(and re-seeded on reset), mapping onto the existing seeded `user-client-001` (Nadia Client):

| Field | Value |
|---|---|
| email | `test@jeeb.app` |
| password | `Password123!` |
| resolves to userId | `user-client-001` (seeded in `fixtures/seed.ts`; `GET /users/me` + `GET /users/:id` resolve it) |

Exported from `auth-service.ts` as `SEED_APP_EMAIL` / `SEED_APP_PASSWORD` / `SEED_APP_USER_ID`.

```text
POST /auth-service/auth/login  {"email":"test@jeeb.app","password":"Password123!"}
  → 200 {accessToken:"mock-jwt-access-user-client-001", refreshToken, expiresIn:3600,
         user:{id:"user-client-001", userId:"user-client-001", ...}}
POST /auth-service/auth/login  {"email":"test@jeeb.app","password":"<wrong>"}  → 401 invalid_credentials
```

### RC-5 — `POST /__mock/reset` now resets auth-service in-memory state

The `POST /__mock/reset` endpoint already existed (resets `store`); it now **also** resets the
auth-service's module-level maps that live outside `store` and otherwise leak across Maestro runs.
A new exported `resetAuthState()` in `auth-service.ts` clears `appCredentials`, `emailToUserId`,
`recoveryStore`, `resetTokens`, `otpStore`, `socialIdentityToUserId`, then **re-seeds the RC-4 test
credential** so it remains present after every reset. `server.ts` calls `resetAuthState()` inside
the `/__mock/reset` handler (alongside `store.clear()` + `seed()`).

**How to call reset (before each signup scenario, to avoid 409 collisions on fixed emails):**

```bash
# from the host
curl -s -X POST http://localhost:4010/__mock/reset            # → {"reset":true}
# from the Android emulator (host alias)
curl -s -X POST http://10.0.2.2:4010/__mock/reset
```

After reset: `store.users` is back to the initial seed, all runtime-registered signup emails are
cleared (so a fixed email like `newuser@jeeb.app` no longer 409-collides), and `test@jeeb.app` /
`Password123!` login still returns 200. The endpoint is dev-only by virtue of the `/__mock/*`
admin namespace.

### Verification

`npm run build` (tsc) clean; `npm test` (vitest) **260/260 pass** — including 4 new smoke tests in
`smoke.test.ts` covering: seeded login → 200, wrong password → 401, login survives `__mock/reset`,
and a signup-collision (409) cleared by `__mock/reset`. Confirmed live on `:4010`: login 200
pre/post reset, wrong password 401, `GET /user-management/users/me` → `user-client-001`.

---

## W1 mock closeout — T1, D1m, and the journey seam

> **Author:** W1 Test-Harness + Backend (Opus). **Date:** 2026-06-18. Closes **T1** + **D1m** in
> the register above and lands the mock half of the `jeeb.seam.journey` seam. Owner:
> `jeeb-mock-backend` (additive; no existing route modified). The seam contract (value → seeded
> state → stable ids → route pin) is in `62_SEAM_HARNESS §"W1 journey seam"`.

### T1 — 5-tier catalog (DONE)

`fixtures/seed.ts` now exports `TIER_CATALOG` with all 5 tiers and `seedTiers()` serves them, so
`GET /delivery-service/v1/tiers` returns, in canonical order:

```
flash (Flash) · express (Express) · standard (Standard) · on-the-way (On-the-Way) · eco (Eco)
```

The tier ids are the lower/snake forms the app’s `request_type_<tier>_radio` ids derive from
(`on-the-way` → `request_type_on_the_way_radio`). The pre-existing `smoke.test.ts` tier test was
updated from `length === 3` to assert the full 5-id/5-name catalog.

### D1m — proof-photo upload sink (DONE)

`services/delivery-service.ts` gained `POST /v1/delivery/proof-photo` (registered **before**
`/v1/delivery/:deliveryId` so "proof-photo" is never matched as an id). Body
`{ deliveryId?, filename?, … }` → `201 { url, evidenceUrl, deliveryId }` with a deterministic
CDN-shaped URL; if the `deliveryId` exists it also stamps `proofPhotoUrl`/`evidenceUrl` on the row
so a follow-up GET reflects the upload. App reaches it via the existing `/v1/delivery` rewrite key
(no map edit). The receipt-confirm (JM-033) + mark-delivered (JM-051) screens POST here, then pass
the returned URL as `evidenceUrl` on the `AtDoor → Done` transition.

### Journey seam — `POST /__mock/seed/journey` (DONE)

`src/fixtures/journey-seed.ts` (`seedJourney()`) + the `POST /__mock/seed/journey` route in
`src/server.ts` make the mock hold deterministic mid-journey rows for `user-client-001` (or
`user-jeeber-002` for the jeeber rating) under the stable ids in `63 §4.3`. Idempotent (overwrites
by stable id), layered on the base fixture, dev-only (`/__mock/*`). The full value → seeded-state →
ids → route-pin table is in `62_SEAM_HARNESS §W1-0`. The app’s `SessionSeamBootstrap` POSTs
`{ journey }` here during cold-start (awaited, before the first frame) so the W1 customer-journey
flows start deep.

### Verification

`npm run build` (tsc) clean; `npm test` (vitest) **274/274** — the prior 260 plus 14 in
`src/w1-journey-seam.test.ts` (T1 catalog, D1m sink incl. stamp-on-existing + missing-id tolerance,
every journey value’s seeded rows/stable ids, and idempotency). The full mock surface stays green.

---

## W2 mock closeout — W1m, O1, K1, the wallet/kyc seam seeds + jeeber journeys

> **Author:** W2 Backender (Opus). **Date:** 2026-06-19. Closes **W1m**, **O1**, **K1** in the
> register above (D1m / U1 already landed in W0/W1 — re-confirmed), and lands the mock half of the
> two new W2 seam keys (`jeeb.seam.kyc_status`, `jeeb.seam.wallet_state`) + the four new
> `jeeb.seam.journey` jeeber-side values. Owner: `jeeb-mock-backend` only; **additive — no existing
> route modified** (the offer-service reserve logic extends the existing submit/accept/withdraw
> handlers without changing their success/error contracts). Authority: CTO-D2, D1/D37/D42/D43, D20.

### Files changed / created

| File | Change |
|---|---|
| `src/fixtures/wallet-model.ts` (NEW) | Single source of truth for the jeeber wallet: `WalletState`, the `RESERVE_RATE` (10%), `affordabilityState()` (enum derivation), reserve helpers, the `WALLET_PRESETS` (`sufficient`/`insufficient`/`empty`), and the typed ledger row + `appendLedger()`. W1m, O1, and the wallet seam all read/write this so the shape never drifts. |
| `src/store.ts` | Added `wallets` (userId → `WalletState`) and `ledger` (userId → `LedgerRow[]`) maps + their `clear()`/`dump()` entries. |
| `src/services/wallet-service.ts` | **W1m** `GET /v1/jeeb/wallet`; **W2m** `GET /v1/jeeb/wallet/ledger` (paginated, newest-first). Both additive; the earnings routes are untouched. |
| `src/services/offer-service.ts` | **O1** — `POST /v1/offers` reserves exact 10% + emits a `reserve` ledger row, returns **402 `{ needed, available, currency }`** when the wallet can't cover; accept **captures** the winner fee (`fee_won`) + **releases** each loser (`released`); withdraw **releases** (`released`). |
| `src/services/user-management.ts` | **K1** — the app KYC gateway contract `/v1/kyc/*` (form-schema · contract-template · sign · submit · status). `resolveKycUserId()` decodes the userId from the `mock-jwt-access-<userId>` bearer so a jeeber's KYC keys to the jeeber (the global authStub otherwise pins everything to `user-client-001`). |
| `src/fixtures/journey-seed.ts` | `seedKycStatus()` + `seedWalletState()` (seam helpers); 4 new journey values + builders + stable ids (`req-feed-001`, `pending-offer-jeeber-001`, `del-jeeber-002-active`). |
| `src/server.ts` | Mounted `POST /__mock/seed/kyc` + `POST /__mock/seed/wallet`; extended the journey-value set. |
| `src/w2-jeeber-seam.test.ts` (NEW) | 28 tests covering W1m / O1 (reserve/402/capture/release) / W2m / K1 / the seam seeds / the 4 journeys / the D1m proof→Done chain. |

### W1m — `GET /wallet-service/v1/jeeb/wallet` (the affordability snapshot)

| op | method | App `/v1/...` path (pre-rewrite) | Final mock path | request | response (200) |
|---|---|---|---|---|---|
| **wallet snapshot** | GET | `/v1/jeeb/wallet?jeeberId=` | `/wallet-service/v1/jeeb/wallet` | `?jeeberId=` (optional; else bearer/`user-jeeber-002`) | `{ jeeberId, availableBalance, affordabilityState, reservedNow, giftCredit, currency }` |
| **wallet ledger (W2m)** | GET | `/v1/jeeb/wallet/ledger?jeeberId=&page=&pageSize=` | `/wallet-service/v1/jeeb/wallet/ledger` | `?jeeberId=&page=&pageSize=` | `{ items:[{ id, type, amount, sign, ref, ts }], page, pageSize, totalCount, totalPages, cursor:null }` |

- `affordabilityState` is the **D43 state enum** (`enough` \| `low` \| `empty` \| `all_reserved`),
  derived against the reference reserve a fresh offer would hold (10% of the default offer price,
  `0.8`). It is **not** a capacity number — the app renders copy off the enum. Rule: `availableBalance <= 0`
  → `all_reserved` if reserves are held else `empty`; `availableBalance < reserveNeeded` → `low`; else `enough`.
- `availableBalance` / `reservedNow` / `giftCredit` are plain USD numbers (no `minorUnits`),
  matching `05_WALLET_SCREENS`. The **app rewrite-map key** to add (app-side, batched):
  `'/v1/jeeb/wallet' → '/wallet-service/v1/jeeb/wallet'` (sibling of the existing
  `/v1/jeeb/earnings` key — no ordering hazard; both are under `/v1/jeeb` but neither is a prefix
  of the other once `/wallet` vs `/earnings` diverge — place the **more specific `/v1/jeeb/wallet/ledger`
  is served by the same prefix**, so one key covers both).
- Verified live (port 4032): default → `availableBalance:40, affordabilityState:"enough", reservedNow:4, giftCredit:5`;
  after `seed/wallet insufficient` → `availableBalance:0.5, affordabilityState:"low"`.

### O1 — `POST /offer-service/v1/offers` (reserve · 402 · capture · release)

The submit handler now holds **exactly 10%** of the offer price (`reserveFor(price)`, D1/D37). The
402 is **not** a generic error — the app routes it to the insufficient-balance sheet (JM-046, §5.1).

| outcome | status | body |
|---|---|---|
| **reserved (success)** | 201 | `{ id, requestId, jeeberId, amount, price:{value,currency}, reserve:{value,currency}, status:"submitted", editCount, createdAt, updatedAt }` + a `reserve` ledger row (sign `-1`) + `availableBalance -= reserve`, `reservedNow += reserve` |
| **insufficient balance** | **402** | `{ type:"urn:jeeb:error:insufficient_balance", title, status:402, detail, needed, available, currency }` (no wallet mutation, no offer row) |
| **duplicate request+jeeber** | 409 | `conflict` (unchanged) |

Lifecycle ledger emission (CTO-D2 "reserve/capture/release on submit/win/lose"):
- **submit** → `reserve` (−). **win (accept)** → `fee_won` (−, reserve consumed, drops out of `reservedNow`).
  **lose (superseded on accept)** → `released` (+, reserve returned to `availableBalance`).
  **withdraw** → `released` (+). Each row carries `ref = offerId`.
- Verified live (port 4032): insufficient wallet → `402 { needed:1, available:0.5, currency:"USD" }`;
  sufficient → `201` with `reserve:{value:1,...}` and a matching `reserve` ledger row.

### K1 — the app KYC gateway `/v1/kyc/*` (reconciled)

The app's `dio_kyc_gateway.dart` speaks a `/v1/kyc/*` contract the mock did **not** serve (the mock
only had the form-builder `jeeb_jeeber_v1` template + `/users/:id/kyc-link`). K1 adds the five routes
on **user-management** (KYC is user-domain); the **app rewrite-map key** to add is
`'/v1/kyc' → '/user-management/v1/kyc'`. Field names match the app DTOs field-for-field.

| op | method | App path | Final mock path | request | response |
|---|---|---|---|---|---|
| **form-schema** | GET | `/v1/kyc/jeeb/form-schema?variant=` | `/user-management/v1/kyc/jeeb/form-schema` | `?variant=` | `{ template_version, template_name:"jeeb_jeeber_v1", variant, schema:{ fields:[{ key, type, i18n_label_key, … }] } }` — **NO vehicle field (D20)**: `full_name, national_id, dob, id_front, id_back, selfie` |
| **contract-template** | GET | `/v1/kyc/contract-template?type=tos` | `/user-management/v1/kyc/contract-template` | `?type=tos` | `{ template_id:"tos_jeeber_v1", tos_version:"1.0", document_url, locale, name }` |
| **sign** | POST | `/v1/kyc/contract-template/sign` | `/user-management/v1/kyc/contract-template/sign` | `{ template_id, tos_version, signature_blob }` | **201** `{ tos_signed_at, tos_accepted_version }` |
| **submit** | POST | `/v1/kyc/submit` | `/user-management/v1/kyc/submit` | `{ … }` (free-form; app sends vehicle fields blank) | **201** first / **200** replay `{ state:"Submitted", submitted_at, submissionId }` — flips the caller's `kycStatus → pending` |
| **status** | GET | `/v1/kyc/status` | `/user-management/v1/kyc/status` | — (bearer) | `{ state, rejection_reason?, submitted_at }` · **404 `not_found`** when no submission (app → `notSubmitted`) |

- `state` wire enum (app `_parseStatus`): `Draft`/`Submitted` → pending, `Approved` → approved,
  `Rejected` → rejected. After `submit`, `GET /users/:id`.kycStatus reads `pending` (the U1 derivation),
  so the DELIVERY-tab gate (JM-036/044) + status views (JM-042/043) light up.
- **Identity caveat:** the global `authStub` pins `req.userId` to `user-client-001` for any bearer.
  The KYC routes instead decode the userId from the `mock-jwt-access-<userId>` token (`resolveKycUserId`),
  so a jeeber's KYC keys to the jeeber. An explicit `?userId=` always wins. Verified live (port 4033):
  submit → 201 `Submitted`; status → `Submitted`; `getUser` → `kycStatus:"pending"`.

### D1m / U1 — re-confirmed (no new work)

- **D1m** proof-photo sink `POST /delivery-service/v1/delivery/proof-photo` (landed W1) is the
  JM-051 mark-delivered upload; the W2 test drives the full `jeeber_active_delivery → AtDoor →
  proof-photo → Done(evidenceUrl)` chain and it passes.
- **U1** `GET /users/:id` already surfaces derived `status` + role-level `kycStatus`; the kyc seam
  override + `/v1/kyc/submit` both feed the same `kycSubmissions` map U1 reads.

### Seam seed endpoints (what the app's `SessionSeamBootstrap` POSTs)

All `/__mock/*` admin paths → **no rewrite-map key** (pass through unchanged to `:4010`).

| endpoint | body | response (200) | unknown value |
|---|---|---|---|
| `POST /__mock/seed/kyc` | `{ kycStatus: "none"\|"pending"\|"approved"\|"rejected", userId? }` (default `user-jeeber-002`) | `{ seeded:true, userId, kycStatus }` — writes/clears the `kycSubmissions` row U1 reads | **400** |
| `POST /__mock/seed/wallet` | `{ state: "sufficient"\|"insufficient"\|"empty", userId? }` (default `user-jeeber-002`) | `{ seeded:true, userId, state }` — overwrites the W1m wallet preset | **400** |
| `POST /__mock/seed/journey` | `{ journey: <value> }` | `{ seeded:true, journey, ids:{…} }` — now also accepts the 4 jeeber values below | **400** |

**`jeeb.seam.wallet_state` → W1m preset (65 §3.2):** `sufficient` → `{available:40, reserved:4, gift:5}`
(`enough`); `insufficient` → `{available:0.5, reserved:2, gift:0}` (`low`, can't cover a 10% reserve → O1 402);
`empty` → `{available:0, reserved:6, gift:0}` (`all_reserved`).

**New `jeeb.seam.journey` jeeber-side values (65 §3.3) — all seed for `user-jeeber-002`:**

| value | seeds | stable id(s) | route pin (app-side) |
|---|---|---|---|
| `jeeber_kyc_submitted` | kycStatus=pending (KYC just submitted) | (no row) | `/jeeber/onboarding/funding` |
| `jeeber_feed_with_request` | 1 open `pending` request in the feed | `req-feed-001` | none (navigates to feed tab) |
| `jeeber_pending_offers` | the feed request + 1 `submitted` offer by the jeeber | `pending-offer-jeeber-001` (on `req-feed-001`) | none (navigates via pending tab) |
| `jeeber_active_delivery` | 1 `InTransit` delivery (jeeberId=user-jeeber-002) + 1:1 accepted conversation `conv-jeeber-active` | `del-jeeber-002-active` | `/jeeber/deliveries/del-jeeber-002-active/active` |

> KYC/wallet posture is set by the **dedicated** `/__mock/seed/kyc` + `/__mock/seed/wallet` seeds
> (a flow passes the journey **and** the kyc_status/wallet_state keys); the journey seeds own only
> the request/offer/delivery/conversation rows. All seeds are idempotent (overwrite by stable id),
> layered on the base fixture, dev-only.

### Verification

`npm run build` (tsc) clean; `npm test` (vitest) **302/302** — the prior 274 plus 28 in
`src/w2-jeeber-seam.test.ts`. Confirmed live on `:4010`-shaped instances (ports 4032/4033) by curl:
W1m snapshot (default + insufficient), O1 (402 `{needed,available}` + 201 reserve + ledger row),
W2m ledger, K1 (form-schema without vehicle, contract, sign, submit → `kycStatus:pending`, status),
and all four jeeber journey seeds. The full W0/W1 mock surface stays green (no existing route modified).

---

## W2 RESIDUALS — bearer-identity fix for the jeeber wallet + composer O1 (close W2)

> **Author:** Principal Backender (Opus — W2 RESIDUALS). **Date:** 2026-06-19. Closes the
> money-path mock gaps the W2 closer (`66_W2_QA_RESULTS`) left open: jm-045 (offer send), jm-046
> (insufficient-balance sheet), jm-047 (withdraw empties the pending list). Owner:
> `jeeb-mock-backend` only; **additive — no existing route added/removed**, the change is to how the
> existing W1m/W2m/O1 handlers RESOLVE the jeeber and read the offer price. Authority: CTO-D2,
> D1/D37/D43; R-F where the spec is silent (recorded inline). `npm run build` clean; `npm test`
> **312/312** (the prior 302 + 10 new in `src/w2-jeeber-seam.test.ts`, now 38).

### Root cause (one systemic bug, two symptoms)

The W2 closer flagged "`GET /wallet` returns `enough`/40 for `user-jeeber-002` even after
`POST /__mock/seed/wallet {insufficient}` — the GET resolves to `user-client-001`." Confirmed by
curl: the global **`authStub` pins `req.userId = 'user-client-001'` for ANY bearer**
(`middleware/auth-stub.ts:8`). The W1m/W2m routes resolved `jeeberId = req.userId` when no
`?jeeberId=` was passed, and **the app's `DioWalletRepository` sends only the bearer (no
`?jeeberId=`)** — so the jeeber's wallet read `user-client-001`, which `getWallet()` lazily
materialised to the **default `sufficient` preset** (`enough`/40). The seeded `user-jeeber-002`
state was never read. Same class of bug hid in O1: the composer
(`DioOfferSubmissionRepository`) posts `{ requestId, priceUsd, etaMinutes, note }` — **no
`jeeberId`, no `amount`** — but `submitOffer` *required* `body.jeeberId` (→ 400) and read price from
`body.amount` (→ fell back to the 8.0 default, so the reserve was wrong). Net: the composer's send
never reached the 402/201 path; jm-045/046 could not pass.

### The fix (mirror K1's `resolveKycUserId` bearer-decode)

The mock issues `mock-jwt-access-<userId>` tokens, so the real identity is recoverable from the
bearer (the same trick K1's KYC routes already use). A bearer-decode resolver was added to the two
money services so the seeded jeeber wallet **actually drives** the response:

| service | resolver | precedence |
|---|---|---|
| `wallet-service.ts` `resolveJeeberId(req)` (W1m `GET /v1/jeeb/wallet` + W2m `…/ledger`) | `?jeeberId=` → bearer-decoded `<userId>` → `req.userId` → `user-jeeber-002` | explicit query wins |
| `offer-service.ts` `resolveOfferJeeberId(req)` (O1 `POST /v1/offers`) | `body.jeeberId` → bearer-decoded `<userId>` → `req.userId` → `user-jeeber-002` | explicit body wins |

`submitOffer` now also reads the price from **`priceUsd`** (the composer's field) as well as
`amount` (number or `{value}`), and **`jeeberId` is no longer required in the body** (only
`requestId` is). The 201 response now **aliases `offerId` next to the canonical `id` and adds
`conversationId`** — the exact fields the composer's `_parseResult` reads to navigate back to the
feed on success (jm-045 AC4). Existing journey/test callers that DO send `body.jeeberId` /
`body.amount` are unchanged (explicit always wins).

### How the wallet seed now drives affordability (the W1m contract, unchanged shape)

`GET /wallet-service/v1/jeeb/wallet` (bearer = jeeber, **no `?jeeberId=`**) — verified live on `:4055`:

| after seam seed | `availableBalance` | `affordabilityState` | app affordability copy |
|---|---|---|---|
| (default / `sufficient`) | `40` | `enough` | "enough to bid" |
| `POST /__mock/seed/wallet {insufficient}` | `0.5` | `low` | "top up to bid" |
| `POST /__mock/seed/wallet {empty}` | `0` | `all_reserved` | "top up to bid" |

`jeeberId` in the body now always reads back `user-jeeber-002` (was `user-client-001`). The W2m
ledger GET resolves the same way. An explicit `?jeeberId=user-jeeber-003` still overrides.

### The 402 contract (O1, with the composer's real body shape)

`POST /offer-service/v1/offers` body `{ requestId, priceUsd, etaMinutes, note? }` + jeeber bearer
(no `jeeberId`) — reserve = exact 10% of `priceUsd` (D1/D37):

| outcome | status | body |
|---|---|---|
| **insufficient** (seeded `insufficient`/`empty`, reserve > available) | **402** | `{ type:"urn:jeeb:error:insufficient_balance", title, status:402, detail, needed, available, currency }` — e.g. `priceUsd:9` → `{ needed:0.9, available:0.5, currency:"USD" }`. **No** wallet mutation, **no** offer row. The app routes this to the JM-046 sheet (§5.1), not an error toast. |
| **reserved (success)** | **201** | `{ id, offerId:(==id), conversationId, requestId, jeeberId:"user-jeeber-002", price:{value,currency}, reserve:{value:0.9,currency}, status:"submitted", … }` + `availableBalance -= reserve` (40 → 39.1), `reservedNow += reserve`, and a `reserve` ledger row (sign −1, `ref=offerId`). |
| **duplicate request+jeeber** | 409 `conflict` | unchanged |

Lifecycle ledger emission (accept → `fee_won` winner / `released` losers; withdraw → `released`)
is unchanged from the W2 closeout above.

### jm-047 withdraw — the pending list now empties

The base fixture seeds OTHER `submitted` offers for `user-jeeber-002` (`offer-replies-001`,
`offer-pending-001-a`), so the pending-offers tab showed 3 rows and `pending_offer_0` resolved to a
stale base offer — withdrawing the journey offer left the list non-empty ("row still visible").
`seedJeeberPendingOffers()` now **deletes the jeeber's other `submitted` offers** before seeding
`pending-offer-jeeber-001`, so it is the ONLY submitted row. The app withdraws via
`DELETE /offer-service/v1/offers/pending-offer-jeeber-001` (the existing route, unchanged) → **204**,
the reserve is `released`, and the app's `status==submitted` filter empties the list — the row
disappears. (accepted/other-jeeber offers are untouched; idempotent.)

### Files changed

| File | Change |
|---|---|
| `src/services/wallet-service.ts` | NEW `resolveJeeberId(req)` (bearer-decode); W1m + W2m GETs use it instead of `req.userId`. |
| `src/services/offer-service.ts` | NEW `resolveOfferJeeberId(req)` (bearer-decode); `offerPrice()` reads `priceUsd`; `jeeberId` no longer required in the body; 201 response aliases `offerId` + adds `conversationId`. |
| `src/fixtures/journey-seed.ts` | `seedJeeberPendingOffers()` clears the jeeber's stale base-fixture `submitted` offers so the pending list is clean (jm-047). |
| `src/w2-jeeber-seam.test.ts` | +10 tests (28 → 38): bearer-only wallet/ledger honors the seed; O1 with the composer body (402 + 201/offerId/conversationId/correct reserve); explicit jeeberId precedence; jm-047 single-submitted-offer + withdraw-empties-list + released row. |

### Verification

`npm run build` (tsc) clean; `npm test` (vitest) **312/312**. Confirmed live on `:4055` by curl:
W1m bearer-only GET honors `sufficient`/`insufficient`/`empty` seeds (`enough`/40 → `low`/0.5 →
`all_reserved`/0); O1 with `{requestId, priceUsd:9}` + jeeber bearer → **402 `{needed:0.9,
available:0.5}`** when insufficient, **201 `{offerId, conversationId, reserve:0.9}`** + wallet 40→39.1
+ reserve ledger row when sufficient; jm-047 journey seeds one submitted offer, DELETE → 204 → list
empties + `released` ledger row. No existing route added/removed; the W0/W1/W2 surface stays green.

---

## FINAL WAVE (W3+W4) mock closeout — W3m, S1, R1m, JM-057 inbox + W2-residual RE-VERIFY

> **Author:** Final-Wave Backender (Opus). **Date:** 2026-06-19. Lands the W3/W4 backend gaps:
> **W3m** (wallet txn-by-id → JM-056), **S1** (support-ticket service → JM-063), **R1m** (per-jeeber
> reviews list → JM-068), and a **JM-057 notifications-inbox seam** (the existing send-path wrote the
> wrong shape for the app's list parser). Also **re-verified the W2 residual money path is CLOSED**
> (the `66_W2_QA_RESULTS` RD-4 MOCK_GAP was a STALE-BUILD false negative — see below). Owner:
> `jeeb-mock-backend` only; **additive — no existing route modified**. Authority: CTO-D2,
> D37/D1/D2/D41 (wallet), D76 (support), D27/D57/D58/D59/D73 (reviews), D84 (notifications).
> `npm run build` (tsc) clean; `npm test` (vitest) **336/336** (the prior 312 + **24 new** in
> `src/w3w4-shared-seam.test.ts`; the smoke health assertion bumped 19→20 for the new service).

### W2-RESIDUAL RE-VERIFY — RD-4 was a stale build, the fix is already LIVE

The `66_W2_QA_RESULTS` "W2 RESIDUAL VERIFY" flagged **RD-4 (MOCK)**: `POST /__mock/seed/wallet
{insufficient, user-jeeber-002}` did not make `POST /offer-service/v1/offers` return 402. **Re-run
on the current `:4010` source: it DOES.** The bearer-decode fix (`resolveJeeberId` /
`resolveOfferJeeberId`, documented in the "W2 RESIDUALS" section above) is present and correct in the
source; the QA's APK was built before that fix landed. Verified live by curl (port 4099, current
HEAD), seeding `user-jeeber-002` wallet = `insufficient`, then POST offer with the **composer body**
(`{requestId:"req-feed-001", priceUsd:9, etaMinutes:25}`, **NO `jeeberId`**, jeeber bearer):

```
POST /__mock/seed/wallet {state:"insufficient", userId:"user-jeeber-002"}      → {seeded:true}
GET  /wallet-service/v1/jeeb/wallet            (jeeber bearer, no ?jeeberId=)  → {availableBalance:0.5, affordabilityState:"low", reservedNow:2, giftCredit:0}
POST /offer-service/v1/offers  {requestId:"req-feed-001", priceUsd:9}          → 402 {type:"…insufficient_balance", needed:0.9, available:0.5, currency:"USD"}
# sufficient (default) wallet, same body:
POST /offer-service/v1/offers  {requestId:"req-feed-001", priceUsd:9}          → 201 {id, offerId(==id), conversationId, reserve:{value:0.9}}  + wallet 40→39.1 + a `reserve` ledger row
```

The GET wallet **honors the `user-jeeber-002` insufficient/empty seed** (no longer falls back to
`user-client-001`/`enough`/40), and the offer POST returns the JM-046 402 contract. RD-4 is CLOSED;
re-run the jm-045 AC5 / jm-046 flows against a **freshly built APK** (the fix needs a rebuild). Covered
by `w3w4-shared-seam.test.ts` ("W2 residual" describe) as a permanent regression net.

### W3m — `GET /wallet-service/v1/jeeb/wallet/ledger/:id` (transaction-by-id detail, JM-056)

The wallet-activity row (W2m, JM-055) deep-links into the transaction-detail screen (JM-056), which
renders **per-type copy**. The detail is a **superset** of the W2m row (same `{id,type,amount,sign,
ref,ts}` + the per-type link fields) so the list and detail never drift (`wallet-model.ledgerDetail`).

| op | method | App `/v1/...` path (pre-rewrite) | Final mock path | response (200) |
|---|---|---|---|---|
| **txn detail** | GET | `/v1/jeeb/wallet/ledger/:id?jeeberId=` | `/wallet-service/v1/jeeb/wallet/ledger/:id` | `{ id, type, category, title, amount, sign, ref, ts, currency, feeRate?, pinnedPrice?, offerId?, orderId?, disputeId? }` · **404 `not_found`** for an unknown id |

- **fee_won** → `feeRate:0.1` + `pinnedPrice` (= `amount/0.1`, the exact-10% pinned price, **D37**) +
  `offerId` + `orderId` (for `txn_detail_order_link` → order-summary-pinned).
- **reserve / released** → `offerId` + `orderId` (the offer/request the reserve is held/returned on, D1).
- **refund / penalty** → `disputeId` (for `txn_detail_dispute_link` → dispute-open-evidence, **D2**).
- **topup / gift** → `title` only (store charge / starter credit, D92/D93/D42).
- Resolved jeeber follows the same precedence as W1m/W2m (`?jeeberId=` → bearer-decode → default).
- Reachable via the **existing `/v1/jeeb/wallet` rewrite key** the W2.5 hand-off adds — **no new map key**
  (the `:id` is a deeper segment of the same prefix). Registered as a distinct path depth from the
  `/ledger` list, so **no route shadowing**.

### S1 — support-ticket service (`/support-service`, JM-063)

A **new** service router (`src/services/support-service.ts`, mounted in `server.ts` as the 20th
service). The closest existing surface was `compliment-service` (disputes only), so support gets its
own service. **App rewrite-map key to add (app-side, batched):** `'/v1/support' →
'/support-service/v1/support'`.

| op | method | App `/v1/...` path | Final mock path | request / response |
|---|---|---|---|---|
| **create** | POST | `/v1/support/tickets` | `/support-service/v1/support/tickets` | `{ category, body, attachments?, orderId?, subject?, userId? }` → **201** `{ id, ticketNumber, userId, category, subject, body, attachments, orderId, status:"open", createdAt, updatedAt }` · **400** unknown/missing category · **400** empty body |
| **list** | GET | `/v1/support/tickets?userId=&status=&page=&pageSize=` | `…/support/tickets` | → `{ items, page, pageSize, totalCount, totalPages, cursor:null }` (the caller's own tickets, **newest-first**, scoped per user) |
| **detail** | GET | `/v1/support/tickets/:id` | `…/support/tickets/:id` | → the ticket · **404** unknown |
| **categories** | GET | `/v1/support/categories` | `…/support/categories` | → `{ items:["order","payment","account","kyc","dispute","other"] }` |

- Identity = bearer-decode (same as wallet/kyc), so a ticket keys to the real caller; `?userId=` /
  `body.userId` wins. Newest-first uses an internal monotonic `_seq` tiebreaker (stripped on the wire)
  so same-ms creates order deterministically. `dispute`/`account`/`kyc` categories cover the
  account-status / dispute-status / kyc-rejected appeal entries (D76).

### R1m — per-jeeber reviews list (`/v1/ratings/jeeb/reviews`, JM-068)

Sourced from `score-taking-service.ts` (the rating domain) as a **distinct read** from the
per-delivery mutual-rate reveal (`/:deliveryId/status`). Reachable via the **existing
`/v1/ratings/jeeb` rewrite key** — **no map edit**. Declared **before** `/:deliveryId/status` and at a
different path depth, so `reviews` is never matched as a `:deliveryId` (regression-guarded).

| op | method | App `/v1/...` path | Final mock path | response (200) |
|---|---|---|---|---|
| **reviews list** | GET | `/v1/ratings/jeeb/reviews?jeeberId=&page=&pageSize=` | `/score-taking-service/v1/ratings/jeeb/reviews` | `{ jeeberId, items:[{ id, reviewerFirstName, score, body, tags, reportable, createdAt }], page, pageSize, totalCount, totalPages, cursor, coldStart, reviewCount, averageScore }` · **400** missing jeeberId |
| **report a review** | POST | `/v1/ratings/jeeb/reviews/:reviewId/report` | `…/reviews/:reviewId/report` | `{ reason?, note? }` → **202** `{ reviewId, reported:true, reason, reportedAt }` (D27) |

- Reviewer attribution is **first name only** (`reviewerFirstName`, **D58**). Every row is
  `reportable:true` (**D27**, `review_<id>_report_cta`). **D59 cold-start:** `coldStart:true` when
  `reviewCount < 5` → `averageScore:null` (the app hides the aggregate + shows the "New" badge); a
  jeeber with ≥5 reviews returns the rounded `averageScore`. Default lazily materialises 7 reviews so
  a profile has content out of the box; the seam overrides the count.

### Seam seeds added (`/__mock/seed/journey` — no rewrite key, pass-through)

| journey value | seeds | stable ids / notes |
|---|---|---|
| `jeeber_wallet_ledger` | one ledger row of **every** type for `user-jeeber-002` + the 3 backing offers the offer-tied rows ref | rows `led-seed-<type>` (`led-seed-fee_won`, `led-seed-refund`, …); fee_won/reserve/released `orderId` resolves to `req-ledger-<n>` |
| `jeeber_reviews` | 7 reviews for `user-jeeber-002` (non-cold-start, aggregate shown) | rows `review-user-jeeber-002-<n>` |
| `jeeber_reviews_cold_start` | 3 reviews for `user-jeeber-002` (**D59** cold-start, score hidden) | rows `review-user-jeeber-002-<n>` |
| `notifications_inbox` | a typed inbox (12 rows, one per **D84** dispatch class) for **both** `user-client-001` and `user-jeeber-002`, in the app's **flat** DTO shape | rows `notif-001`..`notif-012` |

> **JM-057 shape note (important):** the existing `POST /v1/notifications/send` writes
> `{ id, topic, body:{…object}, createdAt, read }`, but the app's `DioNotificationsRepository._item`
> reads **`type`** (not `topic`) and **`title`/`body` as STRINGS** (not an object). The
> `notifications_inbox` seam writes the **flat shape** (`{ id, type, title, body:string, ts, createdAt,
> read, ref }`) so the JM-057 list renders. The send-path was **left untouched** (other tests depend
> on it); the seam is the JM-057 data source. The mark-read PATCH + per-`userId` list are unchanged.

### Disputes + notifications — RE-CONFIRMED mock-ready (no work needed)

The W4 dispute (JM-060/065) and notification-prefs (JM-058) screens use already-present routes,
re-confirmed live: `POST/GET/GET-by-id/PATCH /compliment-service/v1/disputes` (201/200) and
`GET/PUT /notification-service/v1/notifications/preferences` (200) + `PATCH …/:id/read` (204).

### Files changed / created (this wave)

| File | Change |
|---|---|
| `src/fixtures/wallet-model.ts` | NEW `LedgerDetail` + `ledgerDetail()` (per-type W3m detail) + `findLedgerRow()` + `seedLedgerRows()` (one row of every type under stable ids). Additive; the row shape + reserve/affordability logic are unchanged. |
| `src/services/wallet-service.ts` | NEW `GET /v1/jeeb/wallet/ledger/:id` (W3m). Uses the existing `resolveJeeberId`. |
| `src/services/support-service.ts` | NEW service (S1) — create/list/get/categories tickets. |
| `src/fixtures/reviews.ts` | NEW reviews source (R1m) — `seedReviewsFor`, `getReviewsFor`, `COLD_START_THRESHOLD`. |
| `src/services/score-taking-service.ts` | NEW `GET /v1/ratings/jeeb/reviews` (R1m, declared before `/:deliveryId/status`) + `POST /reviews/:id/report` (D27). |
| `src/store.ts` | NEW `supportTickets` + `reviews` maps (+ `clear()`/`dump()` entries). |
| `src/fixtures/journey-seed.ts` | NEW journey values `jeeber_wallet_ledger`, `jeeber_reviews`, `jeeber_reviews_cold_start`, `notifications_inbox` + builders + stable ids. |
| `src/server.ts` | Mount `supportServiceRouter` (20th service); health/log `services: 20`. |
| `src/smoke.test.ts` | Health assertion `19 → 20` (the only existing test touched — honest service count). |
| `src/w3w4-shared-seam.test.ts` | NEW — 24 tests: W3m (per-type detail/404/explicit-jeeber), S1 (create/list/get/400/categories/per-user scope), R1m (full/paginate/cold-start/400/report/no-shadow), JM-057 inbox (flat shape/mark-read/both users), W2-residual re-verify (402 + 201/ledger). |

### Verification

`npm run build` (tsc) clean; `npm test` (vitest) **336/336**. Confirmed live by curl on a fresh
`:4099` instance: W3m fee_won detail `{feeRate:0.1, pinnedPrice:12, orderId:"req-ledger-feewon"}` +
unknown→404; S1 create→201/list→1/400s/categories; R1m full (`coldStart:false, averageScore:4.4`) +
cold-start (`coldStart:true, averageScore:null`) + report→202 + per-delivery status NOT shadowed; the
`notifications_inbox` seam returns 12 typed flat rows; **the W2 residual money path returns 402 on the
seeded-insufficient jeeber wallet**. No existing route added/removed; the W0/W1/W2/W3/W4 surface stays
green.
