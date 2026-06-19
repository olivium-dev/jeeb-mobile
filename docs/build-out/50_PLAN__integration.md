# 50 — Integration & Merge Strategy Plan (Lead Principal 2)

> **Phase 2 deliverable (Lead Principal 2 — Integration & Merge Strategy).** How to run many
> parallel engineers per wave without clobbering shared files. Defines the per-wave **INTEGRATOR**
> pattern, the stable id namespace so engineers never collide, the execution order
> (integrator → engineers → reviewer → QA → PO signoff), how a screen requests a NEW route
> mid-wave, and the **exact route list** the W0 and W1 integrators must add.
>
> Authority chain: CTO brief §7 (isolation rule — only ONE agent edits a shared file per wave;
> shared-file edits batched centrally first) · CTO brief §6.7 (navigation honesty — add the route
> centrally first, then wire the call site) · `21_NAV_PLAN.md §B/§D` (routes-to-add batched by
> wave + the batching rule) · `30_BACKLOG.md` (58 JM items, 5 waves) · `01_CTO_DECISIONS.md`
> (CTO-D1/D2/D3, R-A..R-F).
>
> Ground truth verified 2026-06-18: `lib/core/router/app_router.dart` (40 `GoRoute`s, 34 paths /
> 35 names, flat list — **no `ShellRoute`/`StatefulShellRoute`**; tabs are bodies inside the `/`
> route's `ShellScreen`, switched by `RoleCubit`/index, per CTO brief §4), redirect via
> `_firstRunRedirect(state, onboarding, session)`; `lib/core/di/injection_container.dart` (255 ln);
> `lib/features/shell/shell_screen.dart` (238 ln); `lib/l10n/app_en.arb` + `app_ar.arb`.

---

## 0. TL;DR (the one rule)

Every wave runs in two strict phases:

```
PHASE A — INTEGRATOR (exactly ONE agent, serial, lands first):
   batches ALL shared-file edges for the wave in a single PR:
     1. app_router.dart   — add the wave's GoRoutes (§B of 21_NAV_PLAN) + redirect-gate logic
     2. injection_container.dart — register the wave's repos/cubits/services (GetIt)
     3. shell_screen.dart / tabs/* — tab-body swaps + header chip/bell wiring for the wave
     4. l10n (app_en.arb + app_ar.arb) — ALL i18n keys for the wave's screens
   Each new route points at a NAMED stub screen (compiles, renders a Semantics scaffold).
   Gate: `flutter analyze` clean + `flutter test` green + app boots. Merge to the wave branch.

PHASE B — ENGINEERS (N agents, parallel, after Phase A merges):
   each owns ONE JM item = ONE feature folder. Touches ONLY:
     lib/features/<their-feature>/**  + .maestro/flows/<their-jm>.yaml
   They flesh out the stub the integrator registered, and wire their OWN call-site edges
   (goNamed/push to routes the integrator ALREADY created). They NEVER touch the 4 shared files.

THEN per item: Reviewer → QA (Maestro on emulator vs mock) → PO signoff → DONE.
```

The shared files (`app_router.dart`, `injection_container.dart`, `shell_screen.dart`+`tabs/*`,
the two `.arb` files) are the **only merge-conflict surface**. By collapsing all four into one
serial integrator PR per wave, the N parallel engineer PRs after it touch **disjoint file sets**
and cannot conflict with each other. This is the same discipline the prototype used for
`blueprint.json` (CTO brief §7).

---

## 1. The four shared files (the entire conflict surface)

| # | shared file | what the integrator owns in it | why it conflicts if engineers touch it |
|---|---|---|---|
| S1 | `lib/core/router/app_router.dart` | all `GoRoute` adds/replaces + redirect-gate logic (`_firstRunRedirect`, account-status gate) | every screen adds a route → N agents editing the same `routes:[...]` list = guaranteed clash |
| S2 | `lib/core/di/injection_container.dart` | `sl.registerX<...>()` for each new repo/cubit/service | new features register DI here; one flat `init()` body → clash |
| S3 | `lib/features/shell/shell_screen.dart` + `lib/features/shell/tabs/*` | tab-body swaps (real `CustomerProfileScreen` into Profile tab; KYC gate into DELIVERY tab); persistent header **wallet chip** + **bell** | the shell hosts ALL tabs; two agents swapping different tab bodies in the same `build` = clash |
| S4 | `lib/l10n/app_en.arb` + `lib/l10n/app_ar.arb` | every i18n key for the wave's screens (`@@` metadata + key/value) | JSON object; N agents appending keys = clash + codegen churn |

**No other file is shared.** Each `lib/features/<feature>/{data,domain,presentation}/**` folder is
owned by exactly one JM item (the GAP_MAP `flutter target` column assigns it). The mock backend
(`jeeb-mock-backend`) is owned by the **backender track** (CTO-D2), not the integrator — see §9.

> **Important nuance on S1 (router) — there is no `ShellRoute`.** Verified: `app_router.dart` is a
> flat `GoRoute` list and the tabbed home is a single `/` route whose `builder` returns
> `ShellScreen`, which renders the active tab body by `RoleCubit` index (CTO brief §4 — "tabs are
> not routes"). So a tab-body swap is an **S3 (shell) edit, NOT an S1 (router) edit**. The
> integrator must treat S1 and S3 as separate concerns even though both are "shared".

---

## 2. The INTEGRATOR pattern (per wave)

### 2.1 Who / when
- **Exactly one** integrator agent per wave (Opus, per R-E). Runs **before** any engineer in that
  wave. Serial. No parallelism inside Phase A.
- The integrator does **not** build screens. It builds the **central edges**: routes, DI slots,
  tab wiring, and l10n keys — the scaffolding every engineer in the wave will plug into.

### 2.2 The four edits (in this order, one PR)

1. **Routes (S1).** Add every `GoRoute` from `21_NAV_PLAN §B` batch for the wave, plus any
   redirect-gate logic. Each route's `builder`/`pageBuilder` returns a **named stub screen** the
   engineer will replace — see §2.3. Replaces (`/wallet`, `/lock`) swap the stub builder in place.
2. **DI (S2).** Register every repo/cubit/service the wave's screens need in `injection_container.dart`.
   For data not yet available (CTO-D2 wallet W1m–W3m, S1/R1m), register a **deterministic stub repo**
   (returns fixture data) so engineers and QA aren't blocked; the backender track swaps it for the
   real Dio-backed repo when the mock lands. Record each stub with `// INTEGRATOR-STUB(JM-###): swap when <Bn/Wnm> lands`.
3. **Shell / tabs (S3).** Wire tab-body swaps and the persistent header **wallet chip** + **bell**
   for the wave (W1 lights up the customer Profile/Requests headers; W2 the DELIVERY tab gate).
   Use a stub body where the real screen isn't built yet.
4. **l10n (S4).** Add **all** ARB keys for every screen in the wave to **both** `app_en.arb` and
   `app_ar.arb` (AR may be a TODO-marked English placeholder; R3 covers RTL). Engineers reference
   keys, never add them. This removes the single biggest churn source.

### 2.3 Stub screen contract (so Phase A compiles AND is Maestro-visible)

Each route the integrator registers points at a stub that:
- is a real named widget at the engineer's eventual path
  (e.g. `lib/features/wallet/presentation/wallet_hub_screen.dart` → `WalletHubScreen`),
- renders a `Scaffold` carrying the screen's **root `Semantics(identifier: '<screen-id>_root')`**
  (so QA's red Maestro flow can already assert the screen is reachable),
- contains a `// INTEGRATOR-STUB(JM-###)` marker line the owning engineer deletes.

This makes Phase A a green, bootable, navigable skeleton of the whole wave. Engineers then
**flesh out the stub** (same file) and add the rest of the `Semantics(identifier:)` per
`30_BACKLOG`'s `<screen-id>_<element>` convention (CTO brief §6.6).

### 2.4 Phase A exit gate (hard)
`flutter analyze` clean · `flutter test` green · `emulator jeeb_test` boots the app · every new
route is reachable to its stub (smoke nav). Only then does Phase A merge and Phase B unlocks.
This honors CTO brief §6.8 ("don't break green") and §6.7 (route exists before any call site).

---

## 3. Engineer pattern (Phase B — parallel)

- **One JM item = one engineer = one feature folder.** The engineer touches only
  `lib/features/<feature>/**` (the GAP_MAP `flutter target`) and `.maestro/flows/<jm>.yaml`.
- They **flesh out** the integrator's stub screen and wire their **own outgoing edges** (§C of
  `21_NAV_PLAN`) by `context.goNamed('<name>')` / `pushNamed` to routes the integrator already
  registered. Because the target route already exists, navigation honesty (§6.7) holds with zero
  cross-engineer coordination.
- They **must not** edit S1–S4. If they need something there that the integrator didn't provide,
  they file a route/DI/key request (§6) — they do **not** edit the shared file themselves.
- DoD per item is CTO brief §10 (blueprint+decisions, OMDS, nav both ways, mock-wired,
  `Semantics(identifier:)`, Maestro passes, analyze clean, reviewer+PO signed).

**Parallelism is bounded only by feature-folder disjointness.** Two JM items that share a target
file are **serialized within Phase B** (or merged into one item) — see §5 collision rules. The
GAP_MAP reconciliation notes already merged the obvious ones (JM-034 = rate-jeeber+feedback;
JM-036 = delivery-requests+register-prompt; JM-051 = mark-delivered+delivery-order-chat;
JM-024 = request-type+location-select+map-pin).

---

## 4. Stable id namespace (engineers never collide)

Collisions happen on **names**, not just files. Lock these namespaces:

### 4.1 GoRoute `name:` — globally unique, from `21_NAV_PLAN §A`
The route **name** (not path) is the stable handle engineers `goNamed` against. `21_NAV_PLAN §A`
already assigns a unique name to all 62 screens. Integrator uses those names verbatim. Engineers
**only** reference existing names; requesting a new name goes through §6. No engineer invents a name.

### 4.2 Semantics identifiers — `<screen-id>_<element>` (CTO brief §6.6, `30_BACKLOG` §"Identifier convention")
- `<screen-id>` = the **blueprint id** (e.g. `wallet-hub` → prefix `wallet_`, `offer-composer` →
  `offer_composer_`). The `30_BACKLOG` ACs already spell the exact element ids
  (`login_email_field`, `offer_composer_send_cta`, `wallet_hub_topup_cta`, …).
- Tab targets: `shell_tab_<id>` (`requests`/`delivery`/`profile`/`dashboard`/`earnings`).
- Bottom sheets: `<screen-id>_sheet_<element>`.
- **Rule:** an engineer may ONLY mint identifiers under **their own screen's prefix**. The prefix
  is owned by the JM item. No two JM items share a `<screen-id>` prefix (the GAP_MAP maps each
  blueprint id to exactly one JM), so identifier collisions are structurally impossible.

### 4.3 l10n keys — `<screenCamel>_<element>` owned by the integrator
ARB keys are minted by the **integrator** (S4), namespaced by screen
(e.g. `walletHubBalanceLabel`, `offerComposerFeeLine`). Engineers reference `S.of(context).<key>`.
A missing key is a §6 request, never an inline ARB edit.

### 4.4 DI registration tokens — typed, no string keys
GetIt registrations are by **type** (`sl<WalletRepository>()`), registered once by the integrator.
No `instanceName` strings unless a wave genuinely needs two impls (then the integrator names them
`'<feature>_<variant>'`). Engineers `sl<...>()` by type; they never `registerX`.

### 4.5 Mock endpoint paths — owned by backenders, service-prefixed
Already namespaced by service prefix (`/wallet-service/...`, `/offer-service/...`). App-side
rewrite map keys (`mock_gateway_client.dart`) are a **backender/foundation** edit (B1), not an
engineer or integrator edit.

> **Net effect:** routes (by name), screens (by feature folder), identifiers (by screen prefix),
> l10n (by integrator), DI (by type), mock (by service prefix) are six disjoint namespaces, each
> with exactly one owner. An engineer working inside their lane cannot name-clash another engineer.

---

## 5. Collision rules (when two items want the same thing)

| collision | rule |
|---|---|
| Two JM items target the **same feature file** | Serialize them in Phase B (engineer B starts after A merges), OR merge into one JM (GAP_MAP already did this for JM-024/034/036/051). The wave's task list marks the dependency. |
| Item needs a route the integrator didn't add | §6 route-request → integrator adds it in a **mid-wave router patch** (still the only agent touching S1). |
| Item needs DI the integrator didn't register | §6 DI-request → integrator patches S2. |
| Item needs an l10n key | §6 key-request → integrator patches S4. Never inline. |
| A **widget shared across screens** (e.g. `order-summary-pinned` pinned header JM-031, `OmdsAmount`, bottom-nav R-D) | Owned by **one** JM item that builds it as a reusable widget under its feature (or `lib/core/widgets/`); consumers depend on it. JM-031's widget is built first (W1), injected by JM-025 (chat) + JM-032 (tracking). Treat the shared widget's file as that item's exclusive lane. |
| Cross-wave target (e.g. W1 `customer-profile` row → `wallet-hub`, a W2.5 screen) | The integrator stubs/guards the edge: the call site `goNamed('wallet')` is wired now (route exists as stub from W3 integrator if W3 ran, else a "coming soon" guard). `30_BACKLOG` already notes "rows light up as targets land." |

---

## 6. How a screen requests a NEW route mid-wave

The blueprint/NAV_PLAN should have pre-listed every route, so this is the exception path. When an
engineer discovers a needed route/DI-slot/l10n-key that the integrator's batch missed:

1. Engineer does **NOT** edit S1–S4. Instead appends a row to
   `docs/build-out/50_ROUTE_REQUESTS.md` (create on first use) with:
   `JM-### · requested name · path · screen widget · reason · governing decision/blueprint edge`.
2. The **same wave integrator** (still the only S1/S2/S4 editor) picks it up, validates it against
   `21_NAV_PLAN §A` (does a name already cover this? is it really new?), and either:
   - adds the route in a **mid-wave router patch PR** (serial, re-runs the Phase A exit gate), or
   - rejects it pointing the engineer at the existing name to reuse, or
   - if it implies a **product decision** not covered by CTO-D1/D2/D3 or D1–D93, escalates per
     **R-F** (implementing agent picks most blueprint-consistent option, records assumption) — never
     stalls on the owner (CTO-D preamble).
3. The integrator updates `21_NAV_PLAN §A/§B` so the route table stays the source of truth.

**The genuinely-blocked route decision** is `/sign-up` (AUTH-OD-1). **CTO-D1 already resolves it**:
email-first, add `/login` + `/sign-up`, keep `/register`'s OTP as the verify step. So the W0
integrator adds `/sign-up` (see §8). No live escalation needed.

---

## 7. Execution order (per wave) — the pipeline

```
   ┌─ PO writes/confirms ACs in 30_BACKLOG (already done for W0/W1)
   │
   ▼
[1] INTEGRATOR (serial)   ─ adds wave routes + DI + shell/tabs + l10n keys; stubs compile; green gate
   │                        merges → wave branch
   ▼
[2] QA (Sonnet, per R-E)  ─ authors RED Maestro flows keyed to Semantics identifiers (can start
   │                        against the integrator's stub roots — flows assert reachability first)
   │   ── parallel with ──
[2] ENGINEERS (Opus, N parallel) ─ flesh out each stub screen + wire own edges + mock-bind
   │                        each on its own item branch off the wave branch; touches only its feature folder
   ▼
[3] REVIEWER (Opus)       ─ reviews each engineer diff: blueprint fidelity, OMDS, decisions,
   │                        Semantics present, no S1–S4 edits, analyze clean
   ▼
[4] QA (Sonnet)           ─ runs the now-GREEN Maestro flow on emulator jeeb_test vs mock :4010
   │                        (JAVA_HOME=$(/usr/libexec/java_home), assert on identifiers, R-B)
   ▼
[5] PO SIGNOFF            ─ verifies AC met → writes signoffs/<JM-###>.md → DONE
```

Ordering invariants:
- **Integrator routes BEFORE engineers screens** (CTO brief §6.7 navigation honesty + §7 batching).
- **QA writes the red flow FIRST** (CTO brief §7 pipeline) — it can be authored against the
  integrator's stub roots in parallel with engineers, and goes green when the engineer lands.
- **Reviewer before QA-run**: don't burn an emulator run on a diff that fails review.
- **PO last**: signoff is the DONE gate (CTO brief §10).
- **Waves are serial; items within a wave's Phase B are parallel.** W1 cannot start its integrator
  until W0's shell+session merged (`30_BACKLOG` wave gates). W2/W2.5/W3 ordering: run JM-053/054
  (W2.5 wallet) alongside W2, gating only JM-045/046 money lines on them (`30_BACKLOG` note).

Branch model: one long-lived branch per wave off `integration/first-run-rc5-mac-book`
(`wave/w0`, `wave/w1`, …). Integrator PR merges first. Each engineer item branches off the wave
branch (`jm/JM-007-login`), PRs back into it. Wave branch merges up only when all its items are
PO-signed and the wave's full Maestro suite is green.

---

## 8. EXACT routes the **W0 integrator** must add (from `21_NAV_PLAN §B` batch W0)

W0 = Foundation (auth funnel, biometric gate, session+status routing). Gate: mock B1/B3/B4/U1 +
CTO-D1 (resolves AUTH-OD-1 → email-first; add `/login` + `/sign-up`).

| # | action | path | name | screen (stub→engineer) | JM | notes / decision |
|---|---|---|---|---|---|---|
| 1 | **ADD** | `/login` | `login` | `LoginScreen` (`lib/features/auth/presentation/`) | JM-007 | email+password; reuse `auth/social/`; D23 biometric affordance |
| 2 | **ADD** | `/sign-up` | `sign-up` | `SignUpScreen` (`lib/features/auth/presentation/`) | JM-008 | **CTO-D1: email-first** — add `/sign-up`; keep `/register` OTP as verify step |
| 3 | **ADD** | `/recover` | `recover-password` | `RecoverPasswordScreen` | JM-020 | email field → `/recover/verify` |
| 4 | **ADD** (nested) | `/recover/verify` | `recover-verify` | `VerifyRecoveryCodeScreen` | JM-021 | reuse `OmdsOtpInput`; distinct from phone-OTP (must NOT anchor phone) |
| 5 | **ADD** | `/set-password` | `set-password` | `SetPasswordScreen` | JM-022 | `?mode=recovery\|in-app-social` (D90 dual exit) |
| 6 | **REPLACE** stub builder | `/lock` | `biometric-lock` | real `BiometricLockScreen` (replace placeholder; `BiometricLockCubit` real) | JM-005 | D23 skip-OTP path |
| 7 | **EDIT redirect** | — (`_firstRunRedirect`) | — | `app_router.dart` redirect | JM-006 | session-aware: first-run→`/onboarding`; logged-in customer→`/` last tab (D75); jeeber→DELIVERY; biometric→`/lock`; logged-out→`/login`; `status==suspended`→`/account-status` (D5 — see W4 gate note) |

**Re-parent (no new route):** `phone-otp-verification` (JM-009) stays inside the `/register` flow
(name `phone-otp` reachable as the verify step behind sign-up/social) — CTO-D1. `walkthrough`
(JM-010) destination flips `/register` → `/sign-up` (call-site edge in onboarding feature, not a
router add). `social-login` (JM-018) + `social-collision-prompt` (JM-019) are **native sheet /
dialog**, no route.

**W0 DI (S2):** register `BiometricLockCubit` (real), auth login/recover/set-password repos
(point at B3 mock routes once they land; stub repo until then with
`// INTEGRATOR-STUB(JM-007/020/022): swap when B3 lands`).

**W0 shell/l10n:** no tab-body swaps in W0 (those start W1). l10n keys for all 6 auth screens
(`loginEmailField`, `signupNameField`, `recoverSubmitCta`, `setpwNewField`, …) into both ARBs.

**W0 account-status gate note:** `30_BACKLOG` JM-066 says the **suspended-status branch** in the
splash redirect may be needed in W0 even though the `/account-status` *screen* lands in W4. The W0
integrator wires the **redirect predicate** (`status==suspended → /account-status`) pointing at a
W0 stub `AccountStatusScreen` (root Semantics only); W4's integrator/engineer fleshes it out. This
keeps session integrity (D5) enforced from W0 without building the full screen early.

---

## 9. EXACT routes the **W1 integrator** must add (from `21_NAV_PLAN §B` batch W1)

W1 = Core customer journey. Gate: W0 shell+session merged.

| # | action | path | name | screen (stub→engineer) | JM | notes |
|---|---|---|---|---|---|---|
| 1 | **ADD** | `/requests/:id/offers` | `offer-review` | `ClientOffersScreen` (wire orphan → route) | JM-028 | offer-review-list; screen exists, needs route+caller |
| 2 | **ADD** | `/requests/:id/waiting` | `waiting-no-coverage` | `WaitingNoCoverageScreen` (rewrite orphan `no_offer_timeout_screen.dart`) | JM-026 | N-notified + countdown + no-coverage variant |
| 3 | **ADD** | `/orders/:id/receipt` | `delivered-receipt` | `DeliveredReceiptScreen` (rewrite orphan `delivery_receipt_screen.dart`) | JM-033 | proof photo (D3); NO commission line (customer-facing) |
| 4 | **ADD (optional)** | `/orders/:id/summary` | `order-summary` | `OrderSummaryScreen` | JM-031 | **CTO-D3: pinned header WIDGET is primary**; add this route too as the deep-link target for `transaction-detail → order-summary-pinned` (JM-056) |
| 5 | **ADD (optional, P2)** | `/settings/addresses/edit` | `address-detail` | `AddressDetailFormScreen` (promote `add_edit_location_sheet.dart`) | JM-050 | nested under existing `/settings/addresses`; may defer with JM-049/050 |

**NOT routes in W1 (sheets/widgets — no S1 edit):**
- `offer-accept-confirm` (JM-029) — OMDS confirm **sheet**.
- `cancel-request-confirm` (JM-030) — OMDS confirm **sheet** (do NOT reuse `cancellation_screen.dart`).
- `order-summary-pinned` (JM-031) — primary form is a **reusable pinned-price header widget**
  (CTO-D3) built by JM-031 and injected into `order-chat` (JM-025) + `order-tracking` (JM-032);
  the `/orders/:id/summary` route above is the *optional* deep-link target.

**W1 shell/tabs (S3) — the integrator's key W1 job:**
- Swap the **Profile tab body** from the dev surface `shell/tabs/profile_tab.dart` to the real
  `CustomerProfileScreen` (JM-035). Tab id `shell_tab_profile`.
- Add the persistent **header wallet chip** (`orders_home_wallet_chip` / `customer_profile_wallet_chip`)
  → `goNamed('wallet')` and **bell** (`orders_home_bell`) → `goNamed('notifications')` on the
  Requests + Profile headers (JM-023/035). Targets (`wallet`, `notifications`) are **cross-wave**:
  guard with a "coming soon" until W3/W4 routes land, per `30_BACKLOG` "rows light up as targets land."

**W1 DI (S2):** register repos/cubits for offer-review, waiting/matching, delivered-receipt,
order-summary, customer-profile. Where the mock path is fine (delivery-service, offer-service,
chat-service all rewrite OK per CTO brief §4), bind real Dio repos. Tier catalog returns 3 not 5
(T1) — register against the endpoint; the **backender** fixes the data (R-C: 5 tiers is not a
product question).

**W1 l10n:** keys for all W1 customer screens into both ARBs.

**W1 call-site edges (engineers, §C of NAV_PLAN — NOT integrator):** `request-type → location-select
→ order-chat`; `order-chat → waiting` (send=broadcast); `waiting → offer-review/my-orders`;
`offer-review → offer-accept-confirm(sheet)/jeeber-profile-reviews`; `order-tracking → delivered-receipt`;
`delivered-receipt → rate-jeeber`; all `customer-profile` rows. Each is wired by the owning JM
engineer to a route the W1 (or prior-wave) integrator already created.

---

## 10. Backender track (parallel, separate owner — CTO-D2)

The integrator does **not** edit `jeeb-mock-backend`. A separate **backender** owns it and runs
ahead of / alongside each wave to close the mock gaps that gate data-bound ACs (`20_GAP_MAP`
table + `30_BACKLOG` gates):

- **W0 gate:** B1 (`/v1/auth/...` rewrite), B2 (`/auth/social`), B3 (login/signup/recover/set-pw
  app routes), B4 (OTP length), U1 (getMe surfaces `status`+`kycStatus`).
- **W2.5/W3 gate (CTO-D2):** W1m (balance/affordability/reserved-now), W2m (ledger), W3m (txn-by-id),
  O1 (offer 402). Wallet UI shells build immediately against the integrator's **stub repo**; ACs
  validate when W1m–W3m land.
- **W2 gate:** K1 (KYC gateway paths), T1 (5 tiers), D1m (proof-photo sink).
- **W4 gate:** S1 (support service), R1m (reviews source), D1m.

Integrator stub repos (§2.2 step 2) are the seam: registered by type in S2, swapped Dio-real by
the backender track when the endpoint lands — a one-line `injection_container.dart` change the
**integrator** (not the engineer) makes, so S2's single-owner rule holds.

---

## 11. Conflict-avoidance summary (the guarantees)

1. **Only the integrator touches S1–S4**, once per wave (+ mid-wave patches via §6). → engineer
   PRs never conflict on shared files.
2. **Each JM item owns one feature folder** (GAP_MAP `flutter target`). → engineer PRs touch
   disjoint files.
3. **Six disjoint namespaces** (route-name / feature-folder / Semantics-prefix / l10n-key / DI-type
   / mock-service-prefix), each single-owner. → no name clashes.
4. **Route-before-call-site** (integrator first, §6.7). → no dangling `goNamed`.
5. **Green gate after Phase A and per item** (§6.8). → no broken-base parallelism.
6. **New-route requests are funneled** (§6) back to the integrator. → S1 never has two editors.
7. **Backend is a separate track** (CTO-D2). → mock churn never blocks UI shells; stub repos bridge.

**Files this plan touches that future waves extend here:** `docs/build-out/50_ROUTE_REQUESTS.md`
(created on first mid-wave route request, §6); per-item `docs/build-out/signoffs/<JM-###>.md`.
W2/W2.5/W3/W4 integrator route batches are already enumerated in `21_NAV_PLAN §B` (batches W2/W3/W4)
and follow the identical pattern defined here.
