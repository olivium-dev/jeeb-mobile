# 50 — Execution Plan: Critical Path & Parallelization

> **Phase 2 deliverable (Lead Principal 1 — Critical Path & Parallelization).** Turns the 58 JM
> items (`30_BACKLOG.md`) and 5 waves into a concrete execution schedule: the **critical path**
> (the P0 chain that gates the demo), the **parallel batches** inside each wave (by JM id, with
> max concurrency), and the **cross-wave unblock points**. Companion plans: `51_PLAN__*`
> (other Lead Principals). Source of truth honored: `30_BACKLOG.md`, `21_NAV_PLAN.md`,
> `20_GAP_MAP.md`, `01_CTO_DECISIONS.md`, guardrails `40/41/42`.
>
> **Scheduling rules this plan obeys (do not relitigate):**
> - **Integrator-first per wave** (CTO brief §7; `40_GUARDRAILS_ARCH.md §10.7`, `21_NAV_PLAN.md §D`):
>   exactly ONE agent edits the shared files (`app_router.dart`, `injection_container.dart`, l10n
>   ARB, `shell_screen.dart`/`tabs/*`) and lands that wave's **route + DI + ARB + tab-swap batch
>   FIRST**. Per-screen engineers then build in parallel and wire only their own call-site edges.
> - **Foundation gate is real** (`42_GUARDRAILS_MOCK.md §4`, "W0 gate"): B0/B1 (app-side, Foundation),
>   B2/B3/B4/U1 (backenders) land before any auth screen starts. Plus the two **standing
>   guardrails** from `00_CTO_BRIEF.md §5`: semantics-tree export at boot + the `.kts` gradle dup
>   removal — both are part of W-1 and gate every Maestro run.
> - **Mock fixes are scheduled ahead of the JM items they gate** (W1m before JM-053; O1+W1m before
>   JM-046; etc.) — the per-wave "backend lead-in" lands the mock contract before the UI's
>   data-bound ACs are verified. UI shells may build against the contract spec in parallel (CTO-D2).
> - **A wave does not "complete" until its critical-path items are signed off**; non-critical P1/P2
>   items in the same wave may trail into the next wave's calendar without blocking the demo.

---

## 0. The one-line answer

**Critical path (the demo spine, end to end):**

```
[W-1 foundation] B0/B1 + semantics + gradle + AVD/Maestro harness green
   └─► [W0] JM-001 (auth decision) ─► JM-007 login ─► JM-009 phone-OTP ─► JM-006 splash routing
          └─► [W1] JM-035 profile tab ║ JM-023 requests home
                 └─► JM-025 order-chat(broadcast) ─► JM-032 order-tracking
                        └─► JM-033 delivered-receipt ─► JM-034 rating  ══► DEMO CAN RUN
   (parallel jeeber spine, joins at offer): [W2.5] JM-054→JM-053 wallet ─► [W2] JM-045 offer-composer
          gated by [W2] JM-036 KYC gate + JM-044 offer-gate; fed by JM-051 mark-delivered)
```

Everything else hangs off this spine as parallelizable leaves. The **longest dependency chain**
(the thing that sets the calendar) is the **customer journey backbone**:
`JM-001 → JM-007 → JM-009 → JM-006 → JM-025 → JM-032 → JM-033 → JM-034`. The **jeeber money
backbone** (`W1m → JM-054 → JM-053 → JM-045`, gated by `JM-036 → JM-044`) runs alongside it and
**joins the demo at the offer step** — it is the second-longest chain and the reason W2/W2.5 must
start in parallel with W1, not after it.

---

## 1. Critical path (the P0 chain that gates the demo)

The demo is the full marketplace loop: **a customer signs in, posts a request, a Jeeber (already
KYC-approved, wallet-funded) makes an offer, customer accepts, tracks, confirms receipt, both
rate.** The P0 chain that gates that loop, in strict dependency order:

### 1a. Foundation spine (W-1 — gates literally everything)
| step | item | why it's on the path | owner |
|---|---|---|---|
| F1 | **B0/B1** mock-gateway rewrite (`/v1/auth/*` keys) + `JEEB_MOCK_BASE_URL` dart-define | without it auth never reaches `:4010` — nothing logs in | Foundation |
| F2 | **Semantics export at boot** (`SemanticsBinding.instance.ensureSemantics()` in `main.dart`) + standing `Semantics(identifier:)` rule | without it `maestro hierarchy` is empty → **zero items can be signed off** (DoD §10) | Foundation |
| F3 | **Gradle `.kts` dup removal** + AVD `jeeb_test` boots + `maestro test` green on a smoke flow | without it Android build/test harness is red → no green-gate | Foundation |
| F4 | **B2/B3/B4** (auth social/email-signup/recovery/set-pw routes + 6-digit OTP), **U1** (getMe surfaces `status`+`kycStatus`) | the auth + status/KYC gates downstream read these | backenders |

> F1–F3 are the hard blocker. F4 (B2/B3/B4/U1) gates the *auth screens* specifically and must be
> green before W0 screen work starts (`42 §4` "W0 gate").

### 1b. Auth backbone (W0)
| step | item | gates | deps |
|---|---|---|---|
| A1 | **JM-001** Auth funnel decision spike | resolved by **CTO-D1** (email-first, reuse phone-OTP). This is a *recorded ruling*, not a build — it unblocks A2–A4 on day 0 | — |
| A2 | **JM-007** Login (email/password) | the only way into the shell for the demo customer | JM-001, B1, B3 |
| A3 | **JM-009** Phone-OTP verification (re-parent behind sign-up/social, D23 bypass) | sign-up/social completion → active account | B1, B4 |
| A4 | **JM-006** Session-aware splash routing | routes logged-in user to the right tab / lock / account-status on cold start — the demo's entry point | JM-007, JM-005, JM-066(status branch) |

> **On the path but not blocking the *first* demo run:** JM-005 biometric-unlock (P0) is a deferred
> dependency of JM-006 — JM-006 ships its non-biometric branches first; the `/lock` branch lands
> when JM-005 does (same wave). JM-008 sign-up is P0 but the demo customer is pre-seeded, so it
> rides the wave without gating the spine.

### 1c. Customer journey backbone (W1)
| step | item | why on path | deps |
|---|---|---|---|
| C1 | **JM-035** Customer Profile tab (real screen) | the role-switch + wallet/bell entry surface; also the Profile tab the demo lands on | JM-006 |
| C2 | **JM-023** Requests tab (home) | the customer's home; New-Order FAB starts the loop | JM-026, JM-053, JM-057 (entry targets) |
| C3 | **JM-025** Order Chat (compose = broadcast, pinned summary, dispute link) | the request **is** the first chat message → broadcast. Core of the product model | JM-026, JM-031 |
| C4 | **JM-032** Order Tracking (4-step stepper + auto-advance) | the post-accept tracking surface; auto-advances to receipt | JM-031, JM-033 |
| C5 | **JM-033** Confirm Receipt (proof photo, cash-on-delivery copy) | the delivery-complete gate | JM-034 |
| C6 | **JM-034** Rating (mutual, no-skip) | the terminal; both roles rate | — |

### 1d. Jeeber + money backbone (W2 / W2.5 — runs in parallel, joins at the offer)
| step | item | why on path | deps |
|---|---|---|---|
| J1 | **W1m** wallet balance/affordability/reserved-now (mock) | the offer reserve & affordability gate read it | backenders |
| J2 | **JM-054** Wallet Charge Info (static) | every "+Top up" CTA target; no data dep → front-load | — |
| J3 | **JM-053** Wallet Hub | the funded-wallet surface the Jeeber needs before offering | JM-054, W1m |
| J4 | **JM-036** DELIVERY-tab KYC gate | branches register-prompt vs feed off real `kycStatus` | JM-039, U1 |
| J5 | **JM-044** Offer-KYC gate | enforces D38 (KYC gates offering) before the composer | JM-048 |
| J6 | **JM-045** Offer Composer (10% reserve, net line, ETA-by-tier) | the Jeeber's offer — **joins the customer spine at JM-028/029 accept** | JM-044, JM-046, JM-053 |
| J7 | **JM-051** Mark Delivered (proof photo → rating chain) | the Jeeber side of C4→C5; feeds JM-034 | JM-034, D1m |

**Convergence point:** the customer accept (JM-028 → JM-029) consumes a *real* offer produced by
JM-045. For the demo to show a live offer (not a seeded stub), J6 must be done before the W1
accept step is exercised end-to-end. Hence W2/W2.5 **start with W1**, not after.

---

## 2. Cross-wave unblock points (the dependency seams)

These are the edges that cross wave boundaries — get them wrong and a wave stalls.

| # | unblock point | predecessor (must land first) | dependent (unblocked) | source |
|---|---|---|---|---|
| X1 | **Foundation → all auth** | F1–F4 (B0/B1/B2/B3/B4/U1, semantics, gradle/Maestro) | every W0 screen | `42 §4` W0 gate |
| X2 | **Shell + session → all tabbed work** | JM-006 splash routing + JM-035 profile-tab swap | W1/W2 tab bodies (JM-023, JM-036, JM-048, JM-052) | `30 §W1/W2` |
| X3 | **Wallet precedes offer money lines** | **JM-053 + JM-054 (W2.5)** | **JM-045 money lines + JM-046 insufficient-balance (W2)** | `30 §"W2↔W3 ordering"`, CTO-D2 |
| X4 | **W1m mock precedes wallet data ACs** | W1m (balance/affordability/reserved-now) | JM-053 data-bound ACs, JM-046 402 path | `42 §4`, CTO-D2 |
| X5 | **KYC gate precedes offering** | JM-036 (tab gate) + JM-044 (offer gate) | JM-045/JM-048 make-offer path (D38 invariant) | `20_GAP_MAP` jeeber-onboarding |
| X6 | **Ledger mock precedes activity/txn** | W2m (ledger) + W3m (txn-by-id) | JM-055 activity-list, JM-056 transaction-detail | `42 §4` W3 |
| X7 | **U1 precedes status + KYC gates** | U1 (getMe surfaces `status`+`kycStatus`) | JM-066 account-status gate, JM-036/044 KYC gates | `42 §4` |
| X8 | **Notifications need their deep-link targets** | JM-053(wallet), JM-033(receipt), JM-026(waiting), JM-043(kyc-rejected), JM-057's D84 map | **JM-057 notifications-list** (each row's tap target must be a real route) | `30 §JM-057`, `21 §C` |
| X9 | **Dispute targets** | JM-025 chat snapshot + JM-063 support-ticket + JM-065 dispute-status | JM-060 dispute-open-evidence | `30 §JM-060` |
| X10 | **Reviews chain** | R1m (reviews source) + JM-067 jeeber-profile | JM-068 reviews-list | `42 §4` W4 |
| X11 | **Set-password reachable from security** | JM-022 set-password | JM-061 password-security (social-only entry) | `21 §C` |
| X12 | **Account-status entry** | JM-066 account-status + JM-062 logout/delete | JM-062 entry edge; splash status branch (JM-006) | `30 §JM-066` |

> **The single hardest seam is X3+X4 (wallet ↔ offer).** It is the reason **JM-053/054 are tagged
> W2.5 and run *alongside* W2**, gating only JM-045's money lines and JM-046 — not the whole offer
> composer. JM-045's *structure* (ETA dropdown, order-ref header, send→feed) builds in W2; its
> *money lines* (fee/net/reserve) verify only once JM-053 + W1m land. Sequence: **W1m → JM-054 →
> JM-053 → (JM-045 money lines + JM-046)**.

---

## 3. Wave-by-wave ordered batch list (with max concurrency)

Notation: **[INT]** = the single per-wave integrator step (shared-file batch, lands FIRST).
**maxN** = max engineers running concurrently in that batch. Items in the same batch have no
intra-batch dependency. A batch starts only when the prior batch (and its cross-wave preds) is done.

---

### WAVE -1 — Foundation harness (gates everything; no JM screens)
*Owner: Foundation + backenders. This is the Phase-2 floor (`00_CTO_BRIEF §9`, `42 §4`).*

| batch | items | maxN | gate-out |
|---|---|---|---|
| **F-A** (app-side, serial-ish) | **B0/B1** rewrite map + `JEEB_MOCK_BASE_URL`; **semantics** boot + identifier rule; **gradle `.kts`** removal | 2 (rewrite ∥ build-harness) | app reaches `:4010`; `maestro hierarchy` non-empty; Android build green |
| **F-B** (backend, parallel to F-A) | **B2** social, **B3** email/recovery/set-pw routes, **B4** 6-digit OTP, **U1** getMe `status`+`kycStatus` | 4 | auth + status/KYC contracts live on `:4010` |
| **F-C** (verify) | smoke Maestro flow on `jeeb_test` AVD (boot → splash) green | 1 | **green-gate proven** → W0 may start |

**Critical-path contribution:** F-A + F-C are the demo-blocking floor. **maxN across wave = ~7**
(2 app + 4 backend + 1 QA), but F-C serializes after F-A/F-B.

---

### WAVE 0 — Auth funnel + gates (JM-001, 005–010, 018–022)
*Gate in: X1 (foundation green). Decision: CTO-D1 (email-first, reuse phone-OTP) — JM-001 is a
recorded ruling, day-0, no build.*

| batch | items (JM) | maxN | notes / deps |
|---|---|---|---|
| **W0-INT** [INT] | route batch §B-W0: add `/login`, `/recover`, `/recover/verify`, `/set-password`, `/sign-up`(per CTO-D1), replace `/lock` builder; DI + ARB stubs | 1 | lands FIRST (`21 §D`). JM-001 ruling already recorded |
| **W0-A** (auth core — critical path) | **JM-007** login · **JM-009** phone-OTP · **JM-005** biometric-unlock | **3** | JM-005 makes `BiometricLockCubit` real; all reach `:4010` via B1 |
| **W0-B** (auth funnel breadth — parallel, off critical path) | **JM-008** sign-up · **JM-018** social · **JM-020** recover · **JM-021** verify-code · **JM-022** set-password · **JM-010** walkthrough dest | **6** | JM-008 deps JM-009; JM-018 deps JM-009/019; JM-019 (collision sheet) folds in with JM-018; JM-021→JM-022 chain |
| **W0-C** (session integrator + gate) | **JM-006** splash routing (consumes JM-007/005/066 branches) · **JM-066** account-status **gate logic only** (full screen in W4) | **2** | JM-006 is the wave's convergence; account-status *redirect gate* lands here per `30 §JM-066` note, screen body in W4 |

**Wave-0 critical path:** W0-INT → (JM-007 ∥ JM-009 ∥ JM-005) → JM-006. **Peak concurrency: 6**
(W0-B). Sign-off order: JM-007, JM-009, JM-005, then JM-006 (needs the others' branches).

---

### WAVE 1 — Core customer journey (JM-023–035, 049/050)
*Gate in: X2 (shell+session from JM-006/JM-035). Backend lead-in: **T1** (5 tiers), **D1m** (proof
sink). The journey backbone is P0; saved-addresses (JM-049/050, P2) may defer.*

| batch | items (JM) | maxN | notes / deps |
|---|---|---|---|
| **W1-LEADIN** (backend, parallel w/ W1-INT) | **T1** 5-tier catalog · **D1m** proof-photo sink | 2 | gates JM-024 tier list + JM-033 proof |
| **W1-INT** [INT] | route batch §B-W1: `/requests/:id/offers`, `/requests/:id/waiting`, `/orders/:id/receipt`, optional `/orders/:id/summary`; **tab-swap**: real `CustomerProfileScreen` into Profile tab; DI (chat/offer repos) + ARB | 1 | lands FIRST. The tab-swap is JM-035's shell edit, batched here |
| **W1-A** (journey spine — critical path, dependency-ordered) | **JM-035** profile tab → **JM-023** requests home → **JM-025** order-chat → **JM-032** tracking → **JM-033** receipt → **JM-034** rating | **3** (see below) | These have a chain (JM-025→032→033→034) but **fan out**: JM-035, JM-034, JM-030, JM-031 have no upstream and start immediately |
| **W1-B** (offer-leg leaves — parallel) | **JM-026** waiting · **JM-027** replies sub-tab · **JM-028** offer-review · **JM-029** accept-confirm sheet · **JM-030** cancel-confirm sheet · **JM-031** order-summary widget | **6** | JM-028/029 are the accept gate that consumes a real JM-045 offer (cross-wave join). JM-031 widget feeds JM-025/032 |
| **W1-C** (create-flow leg — parallel) | **JM-024** tier→location→map-pin→chat (deps T1) | **1** (3 files, one owner — coupled per GAP note #4) | feeds JM-025 |
| **W1-D** (P2 — defer-able) | **JM-049** saved-addresses → **JM-050** address-detail-form | **1** | JM-050 deps JM-049; both P2, slot late or push to a trailing batch |

**Wave-1 critical path:** W1-INT → JM-035 → JM-023 → JM-025 → JM-032 → JM-033 → JM-034. Because
JM-031 (summary widget) feeds JM-025+JM-032 and JM-033 feeds JM-032's auto-advance, the real build
order inside W1-A/B is: **(JM-035, JM-031, JM-034, JM-030 start together)** → JM-024+JM-026 →
JM-025 → JM-028/029 → JM-032 → JM-033. **Peak concurrency: 6** (W1-B), realistically **8–10**
engineers across W1-A+W1-B+W1-C if staffed (they touch different feature dirs).

---

### WAVE 2 — Jeeber onboarding + offering (JM-036–048) + WAVE 2.5 wallet front-load
*Gate in: X2 (shell), X5 (KYC gate), X7 (U1). Runs **in parallel with W1** (separate feature dirs;
the offer joins W1 at accept). Backend lead-in: **U1** (kycStatus), **K1**, **O1** (402), **D1m**,
**W1m** (W2.5).*

| batch | items (JM) | maxN | notes / deps |
|---|---|---|---|
| **W2.5-LEADIN** (backend, EARLIEST — gates X3) | **W1m** wallet balance/affordability/reserved-now | 1 | front-loaded; gates JM-053 + JM-045/046 money lines |
| **W2-LEADIN** (backend, parallel) | **K1** KYC path reconcile · **O1** offer 402 + ledger rows · **D1m** proof sink (shared w/ W1) | 3 | K1→JM-040; O1→JM-046 |
| **W2-INT** [INT] | route batch §B-W2 + §B-W3(wallet): `/jeeber/onboarding/funding`, `/jeeber/offer-gate`, `/kyc/rejected`, optional `/jeeber/pending-offers`; **REPLACE `/wallet`**, `/wallet/charge-info`; **tab-swap**: KYC-gate into DELIVERY tab; DI (wallet repo) + ARB | 1 | lands FIRST. Wallet routes batched here so W2.5 can run inside W2 |
| **W2.5-A** (wallet front-load — critical for X3) | **JM-054** charge-info (no data dep — first) → **JM-053** wallet-hub (deps JM-054, W1m) | **2** | unblocks every "+Top up" CTA + the offer money lines |
| **W2-A** (onboarding chain — critical for offering) | **JM-037** remove-vehicle (D20) ∥ **JM-039** photo-step nav → **JM-038** service-area (D51) → **JM-040** KYC-identity (deps K1) → **JM-041** funding (deps JM-054) → **JM-042** kyc-pending | **3** | JM-037/039 have no upstream (start now); the chain 038→040→041→042 serializes; JM-036 tab-gate (deps JM-039, U1) gates the DELIVERY tab |
| **W2-B** (gate + composer — critical path join) | **JM-036** DELIVERY-tab KYC gate → **JM-044** offer-KYC gate → **JM-045** offer-composer → **JM-046** insufficient-balance sheet (deps O1, W1m, JM-054) | **2** (036/044 then 045/046) | **JM-045 is the convergence with W1's accept.** Money lines gate on W2.5-A + W1m |
| **W2-C** (jeeber feed leaves — parallel) | **JM-043** kyc-rejected · **JM-047** pending-offers · **JM-048** delivery-feed (routes make-offer through gate) · **JM-051** mark-delivered (deps JM-034, D1m) | **4** | JM-048 deps JM-044/045/047; JM-043 deps JM-063(W4) for appeal target — wire as it lands |

**Wave-2 critical path:** W2-INT → (W2.5-A: JM-054→JM-053) ∥ (W2-A onboarding chain) → JM-036 →
JM-044 → JM-045. **Peak concurrency: ~9** (W2-A 3 + W2.5-A 2 + W2-C 4), plus backend lead-in 4.
**JM-045 is the latest-finishing critical item of the jeeber spine** — schedule it to complete just
before W1's accept-path end-to-end verification.

---

### WAVE 3 — Wallet ledger + earnings (JM-052, 055, 056)
*Gate in: X6 (W2m/W3m mock ledger). Follows W2.5 once the ledger exists. Mostly P1 — does not gate
the first demo run, enriches the wallet surface.*

| batch | items (JM) | maxN | notes / deps |
|---|---|---|---|
| **W3-LEADIN** (backend) | **W2m** ledger (paginated typed rows) · **W3m** txn-by-id | 2 | gate JM-055 / JM-056 |
| **W3-INT** [INT] | route batch §B-W3 remainder: `/wallet/activity`, `/wallet/transactions/:id`; DI + ARB | 1 | lands FIRST |
| **W3-A** (parallel) | **JM-052** earnings dashboard (fee-only reframe; deps JM-053) · **JM-055** activity-list (deps W2m) → **JM-056** transaction-detail (deps JM-055, W3m) | **2** | JM-052 independent of the ledger pair; JM-055→056 chain |

**Peak concurrency: 2** (+2 backend lead-in). Short wave.

---

### WAVE 4 — Shared: notifications, support, dispute, account, reviews, settings (JM-057–068)
*Gate in: X8 (notif deep-link targets), X9 (dispute targets), X10 (reviews), X11 (set-pw), X12
(account-status). Backend lead-in: **S1** (support), **R1m** (reviews). This wave is mostly
re-pointing into already-built targets — runs last because its deep-links need W1/W2/W3 to exist.*

| batch | items (JM) | maxN | notes / deps |
|---|---|---|---|
| **W4-LEADIN** (backend) | **S1** support-ticket service · **R1m** reviews-list source | 2 | gate JM-063 / JM-068 |
| **W4-INT** [INT] | route batch §B-W4: `/notifications`, `/support`, `/disputes/:id`, `/account-status`(+redirect gate already seeded W0), `/profile/delivery-man/reviews`, `/settings/language`, `/settings/password`, `/settings/addresses/edit`; DI (notif/support/dispute repos) + ARB | 1 | lands FIRST; biggest route batch |
| **W4-A** (P0 shared — critical-ish) | **JM-057** notifications-list (deps X8 targets) · **JM-060** dispute-open-evidence (deps JM-065, JM-063) | **2** | both P0; JM-057's per-row deep-links must hit real routes (X8) |
| **W4-B** (dispute + support + account — parallel) | **JM-063** support-ticket (deps S1) · **JM-065** dispute-status · **JM-066** account-status screen body · **JM-062** logout/delete | **4** | JM-065→JM-060 feeds back; JM-066 gate logic already in W0, body here |
| **W4-C** (settings + reviews + misc — parallel) | **JM-058** notif-prefs · **JM-059** language · **JM-061** password-security (deps JM-022) · **JM-064** rate-the-app · **JM-067** jeeber-profile-reviews → **JM-068** reviews-list (deps R1m) | **5** | JM-067→JM-068 chain; rest independent leaves off JM-035 |

**Peak concurrency: ~7** (W4-B 4 + a few W4-C), +2 backend lead-in.

---

## 4. Max-concurrency summary (staffing envelope per wave)

| wave | integrator | engineers (peak parallel) | backend lead-in | QA (Sonnet) | longest internal chain |
|---|---|---|---|---|---|
| **W-1** | — | 2 (app) | 4 | 1 | F-A → F-C |
| **W0** | 1 | **6** (W0-B) | (done in W-1) | ≤3 | INT → {007/009/005} → 006 |
| **W1** | 1 | **6** (W1-B); ~8–10 across A+B+C | 2 (T1, D1m) | ≤4 | INT → 035 → 023 → 025 → 032 → 033 → 034 |
| **W2 (+2.5)** | 1 | **~9** (A+2.5A+C) | 4 (W1m,K1,O1,D1m) | ≤4 | INT → {054→053 ∥ 037/039→038→040→041→042} → 036 → 044 → 045 |
| **W3** | 1 | **2** | 2 (W2m,W3m) | ≤2 | INT → 055 → 056 |
| **W4** | 1 | **~7** (B+C) | 2 (S1,R1m) | ≤4 | INT → 067 → 068 / 065 → 060 |

> **Practical org read:** the project parallelizes to roughly **8–12 concurrent engineers at peak**
> (when W1 and W2/W2.5 overlap), each owning one screen/feature dir, behind **one integrator per
> wave** and **one QA author per item** (Sonnet, R-E). The pacing constraints are the two backbones
> (customer journey 6-deep, jeeber money 5-deep) and the X3 wallet↔offer seam.

---

## 5. Recommended calendar overlap (which waves run together)

Waves are dependency-ordered but **not strictly serial** — three overlaps are safe and shorten the
schedule:

1. **W2/W2.5 overlaps W1.** Different feature dirs (jeeber vs customer); the only join is JM-045's
   offer feeding JM-028/029 accept. Start W2-INT + W2.5-A the moment W0's shell (JM-006/JM-035) is
   green. The W2 onboarding chain and W2.5 wallet have *no* dependency on the W1 customer screens.
2. **W3 tails W2.5.** Once W2m/W3m mock ledger lands, JM-055/056 can start while W2-B/C finish.
3. **W4 starts when its targets exist**, not when W1–W3 are "done": JM-058/059/061/064 (settings
   leaves off JM-035) can begin as soon as W1's profile tab is green; only JM-057 (deep-links) and
   JM-060 (dispute) truly wait on W1/W2/W3 targets (X8/X9).

**Do NOT overlap:** W-1 foundation with anything (it is the floor), and W0-INT with W0 screen work
(integrator-first is absolute per `21 §D`).

---

## 6. Demo-readiness checkpoint

The demo can run end-to-end the moment this minimal set is signed off (a strict subset of the full
backlog — everything else is enrichment):

**W-1:** F1–F4 · **W0:** JM-007, JM-009, JM-006 (+JM-005 for the lock branch) · **W1:** JM-035,
JM-023, JM-024, JM-025, JM-026, JM-028, JM-029, JM-031, JM-032, JM-033, JM-034 · **W2/2.5:** W1m,
JM-054, JM-053, JM-036, JM-044, JM-045, JM-051 · **plus** JM-057 (W4) if the demo shows a
notification-driven entry.

That is **~24 JM items + 5 foundation/mock fixes** on the critical demo path; the remaining ~34 JM
items are parallelizable enrichment that can land after the first green demo.
