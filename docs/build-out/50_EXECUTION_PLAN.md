# 50 — EXECUTION PLAN (Authoritative, consolidated)

> **Phase 2 deliverable — Tech Lead synthesis.** This is the single authoritative wave-by-wave
> execution plan for the Jeeb mobile build-out. It consolidates the three perspective drafts —
> `50_PLAN__critical_path.md` (critical path & parallelization), `50_PLAN__integration.md`
> (integrator pattern, shared-file batching, exact W0/W1 route lists), `50_PLAN__qa_gating.md`
> (RED→GREEN→SIGNED pipeline, wave EXIT checklist) — into one runnable plan, and reconciles it
> with the verified state of the foundation/mock as of 2026-06-18.
>
> **Authority (cite, never re-litigate):** `00_CTO_BRIEF.md` (mission, §6 non-negotiables,
> §7 pipeline + isolation rule, §10 DoD) · `01_CTO_DECISIONS.md` (CTO-D1 email-first auth /
> CTO-D2 wallet contract / CTO-D3 order-summary / R-A..R-F) · `30_BACKLOG.md` (58 JM, 5 waves,
> Given/When/Then ACs) · `21_NAV_PLAN.md` (routes §B / edges §C / batching §D / tab-vs-route §A) ·
> `20_GAP_MAP.md` (per-screen gap + the mock-gap register) · `42_GUARDRAILS_MOCK.md §4`
> (consolidated mock-fix register: B0..R1m) · `40/41_GUARDRAILS_*` (arch + testing recipe).
>
> **This plan does not fork the testing recipe** (`41 §3`), the id grammar (`41 §1.1`), or any
> product decision. Where a JM AC is silent, the implementing agent applies R-F.

---

## 0. Reconciliation of the three drafts (what this plan adopts and why)

The three perspectives agree on the shape; this plan adopts each in its lane and resolves the seams:

| concern | source draft adopted | adoption |
|---|---|---|
| Wave order, critical path, max concurrency, demo subset | `50_PLAN__critical_path.md` | Adopted verbatim: customer backbone `JM-001→007→009→006→025→032→033→034`; jeeber money backbone `W1m→054→053→045` gated by `036→044`; W2/W2.5 overlap W1. |
| Per-wave integrator-first phase, shared-file conflict surface (S1–S4), exact W0/W1 route batches, stub-screen contract, route-request funnel | `50_PLAN__integration.md` | Adopted verbatim as the per-wave **section (1) integrator central edits**. |
| RED→GREEN→SIGNED state machine, signoff artifact, wave EXIT checklist, regression suites | `50_PLAN__qa_gating.md` | Adopted verbatim as the per-wave **section (3) gating** and **section (4) entry/exit gate**. |
| W0 mock-fix outcome | (unavailable) | **Treated as NOT-YET-GREEN.** W0 entry gate (B0/B1 app-side + B2/B3/B4/U1 backend) is explicitly listed as the unverified blocker. See §W0 and the closing READY summary. |

**The one cross-draft seam to keep straight (X3+X4, wallet↔offer):** JM-053/054 are tagged **W2.5**
and run *alongside* W2, gating only JM-045's money lines and JM-046 — not the whole composer. The
integrator stubs the wallet repo (CTO-D2) so UI shells build before W1m lands.

---

## 1. The shared-file conflict surface (the entire reason for integrator-first)

Only **four** files are shared across a wave's parallel engineers (`50_PLAN__integration.md §1`).
Exactly **one integrator** edits them, once per wave, **before** any engineer starts:

| # | shared file | integrator owns | note |
|---|---|---|---|
| S1 | `lib/core/router/app_router.dart` | all `GoRoute` adds/replaces + redirect-gate logic (`_firstRunRedirect`, account-status gate) | flat `GoRoute` list — **no `ShellRoute`**; tabs are bodies in `/`'s `ShellScreen` by `RoleCubit` index |
| S2 | `lib/core/di/injection_container.dart` | `sl.registerX<...>()` per new repo/cubit/service; **stub repos** for not-yet-landed mock (CTO-D2) | stub marker `// INTEGRATOR-STUB(JM-###): swap when <Bn/Wnm> lands` |
| S3 | `lib/features/shell/shell_screen.dart` + `tabs/*` | tab-body swaps + persistent header **wallet chip** + **bell** | a tab-body swap is an **S3 edit, not S1** |
| S4 | `lib/l10n/app_en.arb` + `app_ar.arb` | every i18n key for the wave's screens | engineers reference keys; never inline-add |

Six disjoint namespaces, each single-owner, make engineer collisions structurally impossible:
route-name (integrator, from `21 §A`) · feature-folder (one JM, from GAP_MAP `flutter target`) ·
Semantics-prefix `<screen-id>_*` (one JM) · l10n-key (integrator) · DI-type (integrator) ·
mock-service-prefix (backenders). A mid-wave new-route need is funneled to the integrator via
`docs/build-out/50_ROUTE_REQUESTS.md` (`50_PLAN__integration.md §6`) — engineers never touch S1–S4.

---

## 2. The per-item pipeline (every JM item, every wave)

The data-mediated loop (CTO brief §7), expanded into a checkable state machine
(`50_PLAN__qa_gating.md §1`). **Strict left→right; the artifact at each gate is the proof.**

```
 S0 AC-READY → S1 RED → S2 IMPLEMENTED → S3 REVIEWED → S4 GREEN → S5 SIGNED
   PO(Opus)    QA(Sonnet)   ENG(Opus)      REVR(Opus)   QA(Sonnet)  PO(Opus)
   AC in 30    red flow     screen+nav+    diff vs 41§7  flow GREEN  DoD →
   /BACKLOG,   keyed on     mock; every    + 40 Clean-   + prior-    signoffs/
   ids named   AC ids       id in          Arch/nav      wave suite  JM-###.md
                            hierarchy§1.4                 still green = DONE
```

- **Model policy (R-E):** QA flow authoring (S1) + QA execution (S4) = **Sonnet**. PO, Designer,
  Engineer, Reviewer, Integrator = **Opus**.
- **Test-first is absolute:** the engineer (S2) may not start until the RED flow exists (S1), which
  may not start until the AC's ids are confirmed against a real route/tab (S0).
- **Signoff artifact:** one `signoffs/JM-###.md` per item, stubbed at S1, completed at S5, in the
  fixed format of `50_PLAN__qa_gating.md §2` (AC→evidence table, DoD checklist, hierarchy proof,
  regression, review, trail). **The `signoffs/` dir does not exist yet — the W0 integrator creates it.**
- **The two standing gates** (CTO brief §8, run at S2 + S4 + every wave EXIT):
  ```bash
  cd /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile
  /Users/oudaykhaled/flutter/bin/flutter analyze   # CLEAN (zero errors/warnings)
  /Users/oudaykhaled/flutter/bin/flutter test      # GREEN (all unit/widget)
  ```
- **The Maestro run recipe is `41 §3` verbatim** (dev flavor `app.jeeb.mobile.dev`, mock `:4010`
  via `10.0.2.2`, `JAVA_HOME=$(/usr/libexec/java_home)`, `--format JUNIT`). Before any Android run:
  `rm -f android/build.gradle.kts android/settings.gradle.kts android/app/build.gradle.kts`.

---

## 3. The mock-fix register, sequenced ahead of the JM items it gates

From `42_GUARDRAILS_MOCK.md §4`. **B0/B1 are app-side (Foundation); all others are backenders.**
Each lands on the **backender/foundation track** (separate owner, CTO-D2) *before* the dependent
item's data-bound ACs reach S4. UI shells build in parallel against the integrator's stub repo.

| ref | gate wave | unblocks | owner |
|---|---|---|---|
| **B0** base URL → `:4010` when prefixes on | W0 (pre-everything) | ALL mock-backed JM | Foundation (app) |
| **B1** `/v1/auth/*` rewrite keys | W0 | JM-007/008/009/018 | Foundation (app) |
| **B2** `POST /auth/social` (+ reconcile `/api/auth/social`) | W0 | JM-018/019 | backenders |
| **B3** app-client login / email-signup / recovery-code / set-password routes | W0 | JM-007/008/020/021/022 | backenders |
| **B4** 6-digit OTP (mock emits 4-digit `'1234'`) | W0 | JM-009 | backenders |
| **U1** getMe surfaces `status` + role `kycStatus` | W0 (status) / W2 (kyc) | JM-066, JM-036/044 | backenders |
| **T1** 5-tier catalog (seed has 3) | W1 | JM-024 (+JM-045 ETA-by-tier) | backenders |
| **D1m** proof-photo upload sink | W1 / W2 | JM-033, JM-051 | backenders |
| **K1** KYC gateway path reconcile (`/v1/kyc/*` ↔ form-builder/user-mgmt) | W2 | JM-040 | backenders/app |
| **O1** offer 402 `{needed,available}` + reserve/capture/release ledger rows | W2 (money) | JM-046 | backenders |
| **W1m** wallet balance/affordability/reserved-now/gift | W2.5 | JM-053, JM-046 | backenders |
| **W2m** wallet ledger (paginated typed rows) | W3 | JM-055 | backenders |
| **W3m** wallet txn-by-id | W3 | JM-056 | backenders |
| **S1** support-ticket service | W4 | JM-063 | backenders |
| **R1m** reviews-list source (per-jeeber, paginated) | W4 | JM-068 | backenders |

> Mock-ready already (no fix; confirm only): disputes `POST/GET /v1/disputes` (JM-060/065),
> ratings `POST /v1/ratings/jeeb/submit` (JM-034), notifications prefs+list+read (JM-057/058).

---

# WAVE-BY-WAVE PLAN

Each wave below gives, in order: **(0) entry gate** · **(1) integrator central edits (FIRST)** ·
**(5) backend mock-fixes that must land** · **(2) parallel engineer batches with max concurrency** ·
**(3) QA / review / PO gating** · **(4) EXIT checklist**.
Notation: **[INT]** = the single per-wave integrator step (lands first). **maxN** = peak concurrent
engineers in that batch (items in one batch have no intra-batch dependency).

---

## WAVE -1 — Foundation harness (the floor; gates literally everything)

*Owner: Foundation (app-side) + backenders. No JM screens. This is the Phase-2 floor
(`00_CTO_BRIEF §9`, `42 §4`). **Do NOT overlap W-1 with anything.***

**(0) Entry gate:** none — this is the start.

**(1)/(5) Work (app-side F-A serial-ish, backend F-B parallel):**

| batch | items | maxN | gate-out (must be true to proceed) |
|---|---|---|---|
| **F-A** (app, Foundation) | **B0** base URL→`:4010` + `JEEB_MOCK_BASE_URL` dart-define ∥ build-harness: confirm **F2** semantics boot + **F3** gradle `.kts` removal | 2 | app reaches `:4010`; `maestro hierarchy` non-empty; Android build green |
| **F-A** (app, Foundation) | **B1** add `/v1/auth/*` rewrite keys above legacy `/auth/*` | (in F-A) | app auth POSTs reach `:4010` |
| **F-B** (backend, parallel) | **B2** social · **B3** email/recovery/set-pw routes · **B4** 6-digit OTP · **U1** getMe `status`+`kycStatus` | 4 | auth + status/KYC contracts live on `:4010` |
| **F-C** (verify, QA Sonnet) | smoke Maestro flow on `jeeb_test` (boot→splash, e.g. existing `.maestro/smoke.yaml` / `01-splash.yaml`) GREEN | 1 | **green-gate proven** → W0 may start |

**Verified state (2026-06-18):** F2 semantics boot **DONE** (`main.dart:18
SemanticsBinding.instance.ensureSemantics()`). F3 gradle `.kts` **DONE** (no stray files present).
**B0 NOT done** (`mock_gateway_client.dart` `mockBaseUrl` defaults `:3055` with `useMockPrefixes=true`).
**B1 NOT done** (map keys are `/auth/otp|social|refresh` only, no `/v1/auth/*`). **B2/B3/B4/U1
status UNKNOWN** (W0 mock-fix outcome unavailable).

**(4) EXIT:** F-A green (B0+B1 landed, app talks to `:4010`) · F-B green (B2/B3/B4/U1 on `:4010`) ·
F-C smoke Maestro GREEN. **All four are the W0 entry gate.**

---

## WAVE 0 — Auth funnel + session/status gates (JM-001, 005–010, 018–022)

*Decision: **CTO-D1** (email-first, reuse phone-OTP) already resolves AUTH-OD-1. JM-001 is a
recorded ruling, day-0, no build. JM-066's **redirect gate logic** lands here; the full screen body
in W4.*

**(0) Entry gate (hard):** W-1 EXITED — **B0+B1 (Foundation)** and **B2/B3/B4/U1 (backenders)**
green on `:4010`, semantics+gradle+smoke-Maestro green. **CTO-D1 unblocks JM-007/008/010.**

**(1) Integrator central edits — W0-INT [INT], lands FIRST** (`50_PLAN__integration.md §8`):

- **S1 routes (`21 §B` W0 batch):**

  | action | path | name | screen (stub→engineer) | JM | decision |
  |---|---|---|---|---|---|
  | ADD | `/login` | `login` | `LoginScreen` (`lib/features/auth/presentation/`) | JM-007 | email+pwd; reuse `auth/social/`; D23 biometric affordance |
  | ADD | `/sign-up` | `sign-up` | `SignUpScreen` (`lib/features/auth/presentation/`) | JM-008 | **CTO-D1 email-first**; keep `/register` OTP as verify step |
  | ADD | `/recover` | `recover-password` | `RecoverPasswordScreen` | JM-020 | email field → verify |
  | ADD (nested) | `/recover/verify` | `recover-verify` | `VerifyRecoveryCodeScreen` | JM-021 | reuse `OmdsOtpInput`; NOT phone-anchored |
  | ADD | `/set-password` | `set-password` | `SetPasswordScreen` | JM-022 | `?mode=recovery\|in-app-social` (D90) |
  | REPLACE builder | `/lock` | `biometric-lock` | real `BiometricLockScreen` (cubit real) | JM-005 | D23 skip-OTP |
  | EDIT redirect | — `_firstRunRedirect` | — | router redirect | JM-006 | session-aware branches (D75/D23/D5) |
  | ADD (stub root only) | `/account-status` | `account-status` | `AccountStatusScreen` stub | JM-066 | **redirect-gate predicate now**, body in W4 |

- **S2 DI:** register real `BiometricLockCubit`; auth login/recover/set-password repos
  (`// INTEGRATOR-STUB(JM-007/020/022): swap when B3 lands` until B3 is verified).
- **S3 shell/tabs:** none in W0 (tab swaps start W1).
- **S4 l10n:** all 6 auth-screen keys into both ARBs (`loginEmailField`, `signupNameField`,
  `recoverSubmitCta`, `setpwNewField`, …).
- **Re-parent (no new route):** `phone-otp-verification` (JM-009) stays inside `/register` (name
  `phone-otp`) as the verify step. `walkthrough` (JM-010) flips destination `/register`→`/sign-up`
  (call-site edge). `social-login` (JM-018) + `social-collision-prompt` (JM-019) are native sheet/dialog.
- **Integrator also creates `docs/build-out/signoffs/`.**
- **Phase-A exit gate:** analyze clean · test green · `jeeb_test` boots · every new route reaches its
  stub root. Only then engineers unlock.

**(5) Backend mock-fixes that must land before W0 screens:** B0, B1 (Foundation), **B2, B3, B4, U1**
(backenders) — see §3. These are the W0 entry gate; auth cannot reach `:4010` without them.

**(2) Parallel engineer batches (after W0-INT merges):**

| batch | items (JM) | maxN | deps / notes |
|---|---|---|---|
| **W0-A** auth core (critical path) | JM-007 login · JM-009 phone-OTP · JM-005 biometric-unlock | **3** | all reach `:4010` via B1; JM-005 makes cubit real |
| **W0-B** funnel breadth (off critical path) | JM-008 sign-up · JM-018 social · JM-019 collision sheet · JM-020 recover · JM-021 verify-code · JM-022 set-password · JM-010 walkthrough dest | **6** | JM-008→JM-009; JM-018→JM-009/019; JM-021→JM-022 |
| **W0-C** session integrator + gate | JM-006 splash routing (consumes JM-007/005/066 branches) · JM-066 account-status **gate logic only** | **2** | JM-006 is the wave's convergence; account-status body in W4 |

**Wave-0 critical path:** W0-INT → (JM-007 ∥ JM-009 ∥ JM-005) → JM-006. **Peak concurrency: 6** (W0-B).

**(3) Gating (per item, §2 pipeline):** QA authors RED flow keyed on AC ids (Sonnet) → Engineer to
hierarchy-green (Opus) → Reviewer `41 §7` + `40` (Opus) → QA runs `jm-NNN` GREEN on `jeeb_test`
(Sonnet) → PO signs `signoffs/JM-###.md` (Opus). Tag every flow `[jm-NNN, w0, auth]`.

**(4) EXIT checklist (entry gate to W1):** every W0 JM `signoffs/*.md` = SIGNED · each `jm-NNN`
GREEN · `--include-tags w0` suite GREEN · analyze clean + test green on the wave branch · every
`21 §B` W0 route registered+reachable · no leading-underscore ids · id-only assertions, no fixed
sleeps · B0/B1/B2/B3/B4/U1 closed (or dependent ACs PARTIAL-parked) · dev-seam = intent-extras only.

---

## WAVE 1 — Core customer journey (JM-023–035, 049/050)

*The demo's customer spine. Runs **in parallel with W2/W2.5** (different feature dirs). Journey
backbone is P0; saved-addresses (JM-049/050, P2) may defer to a trailing batch.*

**(0) Entry gate:** W0 EXITED — shell + session landed (JM-006 splash gate, JM-005 lock).

**(1) Integrator central edits — W1-INT [INT]** (`50_PLAN__integration.md §9`):

- **S1 routes (`21 §B` W1 batch):** ADD `/requests/:id/offers` (`offer-review`, wire orphan
  `ClientOffersScreen`, JM-028) · ADD `/requests/:id/waiting` (`waiting-no-coverage`, rewrite orphan
  `no_offer_timeout_screen.dart`, JM-026) · ADD `/orders/:id/receipt` (`delivered-receipt`, rewrite
  orphan `delivery_receipt_screen.dart`, JM-033) · ADD optional `/orders/:id/summary`
  (`order-summary`, JM-031 — **CTO-D3: pinned widget is primary; this route is the deep-link target**
  for JM-056) · ADD optional/P2 `/settings/addresses/edit` (`address-detail`, JM-050).
  **Sheets/widgets (no S1 edit):** JM-029 accept-confirm, JM-030 cancel-confirm,
  JM-031 pinned header widget.
- **S3 shell/tabs (the key W1 job):** swap **Profile tab body** from dev `shell/tabs/profile_tab.dart`
  to real `CustomerProfileScreen` (JM-035, `shell_tab_profile`); add persistent **header wallet chip**
  (`orders_home_wallet_chip`/`customer_profile_wallet_chip` → `goNamed('wallet')`) + **bell**
  (`orders_home_bell` → `goNamed('notifications')`) on Requests + Profile headers. **Cross-wave
  targets** (`wallet` W2.5/W3, `notifications` W4) are guarded "coming soon" until those routes land
  ("rows light up as targets land," `30_BACKLOG`).
- **S2 DI:** offer-review, waiting/matching, delivered-receipt, order-summary, customer-profile repos.
  delivery-service/offer-service/chat-service rewrite OK → bind real Dio. Tier endpoint bound; T1
  data fix is backender.
- **S4 l10n:** all W1 customer-screen keys into both ARBs.

**(5) Backend mock-fixes that must land:** **T1** (5-tier catalog — gates JM-024 tier list +
JM-045 ETA-by-tier) · **D1m** (proof-photo sink — gates JM-033 receipt proof, shared with W2).

**(2) Parallel engineer batches:**

| batch | items (JM) | maxN | notes / deps |
|---|---|---|---|
| **W1-LEADIN** (backend, ∥ INT) | T1 5-tier · D1m proof sink | 2 | gate JM-024 / JM-033 |
| **W1-A** journey spine (chain) | JM-035 → JM-023 → JM-025 → JM-032 → JM-033 → JM-034 | **3** | chain 025→032→033→034; but 035/034/031/030 have no upstream — start now |
| **W1-B** offer-leg leaves (∥) | JM-026 waiting · JM-027 replies sub-tab · JM-028 offer-review · JM-029 accept sheet · JM-030 cancel sheet · JM-031 summary widget | **6** | JM-028/029 = accept gate that consumes a real JM-045 offer (cross-wave join); JM-031 widget feeds 025+032 |
| **W1-C** create-flow leg (∥, one owner) | JM-024 tier→location→map-pin→chat (3 coupled files, GAP note #4) | **1** | deps T1; feeds JM-025 |
| **W1-D** P2 defer-able | JM-049 saved-addresses → JM-050 address-detail-form | **1** | both P2; slot late or trail |

**Real build order inside A/B:** (JM-035, JM-031, JM-034, JM-030 start together) → JM-024+JM-026 →
JM-025 → JM-028/029 → JM-032 → JM-033. **Critical path:** INT → 035 → 023 → 025 → 032 → 033 → 034.
**Peak: 6** (W1-B); ~8–10 across A+B+C if staffed.

**(3) Gating:** per-item §2 pipeline. Flows tagged `[jm-NNN, w1, customer]`. Tab-body items
(JM-023/035, JM-027 sub-tab) reach the screen via `shell_tab_requests`/`shell_tab_profile` + sub-tab
chip id, never a path. Cross-wave-target rows (wallet/bell, JM-035/023) assert *tap-accepted +
root-survives* (AP-9) until the target lands.

**(4) EXIT:** all W1 JM SIGNED (49/050 may PARTIAL-defer) · `--include-tags w1` GREEN · `w0` still
GREEN (regression) · analyze/test green · routes/edges nav-honest · T1+D1m closed or data-bound ACs
PARTIAL-parked.

---

## WAVE 2 — Jeeber onboarding + offering (JM-036–048) + WAVE 2.5 wallet front-load (JM-053/054)

*KYC gates offering (D38). **Runs in parallel with W1**; the offer joins W1 at the accept step
(JM-028/029 consumes a real JM-045 offer). Start W2-INT + W2.5-A the moment W0's shell is green.*

**(0) Entry gate:** W0 EXITED (shell/session) + **U1** (role `kycStatus`). JM-045 money lines +
JM-046 gate on **W2.5** (JM-053/054) being GREEN first.

**(1) Integrator central edits — W2-INT [INT]** (batches `21 §B` W2 **and** the wallet W3 routes so
W2.5 can run inside W2):

- **S1 routes:** ADD `/jeeber/onboarding/funding` (`onboarding-funding`, JM-041) · ADD
  `/jeeber/offer-gate` (`offer-kyc-gate`, JM-044) · ADD `/kyc/rejected` (`kyc-rejected`, extract from
  status view, JM-043) · ADD optional `/jeeber/pending-offers` (JM-047, prefer feed sub-tab) ·
  **REPLACE `/wallet`** stub → `WalletHubScreen` (JM-053) · ADD `/wallet/charge-info`
  (`wallet-charge-info`, JM-054). **Sheet (no S1):** JM-046 insufficient-balance.
  Wizard steps (JM-037/038/039/040 D20/D51 fixes) are widget/cubit edits inside existing
  `/jeeber/onboarding` + `/profile/kyc` — **not new routes**.
- **S3 shell/tabs:** swap **KYC-gate into the DELIVERY tab** (JM-036 — `delivery_register_prompt` vs
  feed off real `user.kycStatus`, remove the dev-seam flag); DELIVERY-tab header chip+bell.
- **S2 DI:** wallet repo — register **stub repo** (CTO-D2: `// INTEGRATOR-STUB(JM-053/046): swap
  when W1m lands`) so wallet UI builds before W1m; KYC/offer/funding repos.
- **S4 l10n:** all W2 + wallet (053/054) keys.

**(5) Backend mock-fixes that must land:** **W1m** (balance/affordability/reserved-now/gift —
**EARLIEST**, gates JM-053 + JM-045/046 money lines) · **K1** (KYC paths → JM-040) · **O1** (offer
402 + ledger rows → JM-046) · **D1m** (mark-delivered proof → JM-051) · **U1** (role `kycStatus` →
JM-036/044, from W0).

**(2) Parallel engineer batches:**

| batch | items (JM) | maxN | notes / deps |
|---|---|---|---|
| **W2.5-LEADIN** (backend, EARLIEST) | W1m wallet balance/affordability/reserved-now | 1 | gates X3 (wallet↔offer) |
| **W2-LEADIN** (backend, ∥) | K1 · O1 (402+ledger) · D1m | 3 | K1→040; O1→046 |
| **W2.5-A** wallet front-load (critical for X3) | JM-054 charge-info (no data dep — first) → JM-053 wallet-hub (deps JM-054, W1m) | **2** | unblocks every "+Top up" CTA + offer money lines |
| **W2-A** onboarding chain | JM-037 remove-vehicle (D20) ∥ JM-039 photo-step nav → JM-038 service-area (D51) → JM-040 KYC-identity (deps K1) → JM-041 funding (deps JM-054) → JM-042 kyc-pending | **3** | 037/039 no upstream (start now); 038→040→041→042 serializes |
| **W2-B** gate + composer (critical join) | JM-036 DELIVERY-tab KYC gate → JM-044 offer-KYC gate → JM-045 offer-composer → JM-046 insufficient-balance sheet | **2** | **JM-045 is the convergence with W1's accept.** Money lines gate on W2.5-A + W1m; JM-046 deps O1+W1m |
| **W2-C** jeeber feed leaves (∥) | JM-043 kyc-rejected · JM-047 pending-offers · JM-048 delivery-feed (routes make-offer through gate) · JM-051 mark-delivered (deps JM-034, D1m) | **4** | JM-048 deps 044/045/047; JM-043 appeal target → JM-063 (W4), wire as it lands |

**Critical path:** W2-INT → (JM-054→JM-053 ∥ 037/039→038→040→041→042) → JM-036 → JM-044 → JM-045.
JM-045 is the **latest-finishing critical item of the jeeber spine** — schedule it to complete just
before W1's accept-path end-to-end verification. **Peak: ~9** (A 3 + 2.5-A 2 + C 4) + 4 backend.

**(3) Gating:** §2 pipeline. JM-045 money lines + JM-046 cannot reach S4 until `jm-053`/`jm-054`
(tag `w2_5`) are GREEN (CTO-D2). DELIVERY tab reached via `shell_tab_delivery`/`shell_tab_dashboard`.
Items whose data-bound legs await W1m/O1 are PARTIAL-parked until those land.

**(4) EXIT:** all W2 JM SIGNED (or PARTIAL on W1m/O1) · `--include-tags w2` **and** `w2_5` GREEN
together · `w0`+`w1` still GREEN · analyze/test green · W1m+K1+O1+D1m+U1 closed or ACs PARTIAL-parked.

---

## WAVE 3 — Wallet ledger + earnings (JM-052, 055, 056)

*Follows W2.5 once the ledger exists. Mostly P1 — enriches the wallet surface, does not gate the
first demo run.*

**(0) Entry gate:** W0 EXITED + mock **W2m** (ledger) + **W3m** (txn-by-id) defined (CTO-D2). Until
then JM-055/056 build the UI shell but their data-bound ACs are PARTIAL-parked.

**(1) Integrator central edits — W3-INT [INT]:** ADD `/wallet/activity` (`wallet-activity`, JM-055) ·
ADD `/wallet/transactions/:id` (`transaction-detail`, JM-056). S2 DI: ledger/txn repos (swap from
W2.5 stub when W2m/W3m land). S4 l10n keys.

**(5) Backend mock-fixes that must land:** **W2m** (ledger, paginated typed rows) · **W3m** (txn-by-id).

**(2) Parallel engineer batches:**

| batch | items (JM) | maxN | notes / deps |
|---|---|---|---|
| **W3-LEADIN** (backend) | W2m ledger · W3m txn-by-id | 2 | gate 055 / 056 |
| **W3-A** (∥) | JM-052 earnings dashboard (fee-only reframe; deps JM-053) · JM-055 activity-list (deps W2m) → JM-056 transaction-detail (deps JM-055, W3m) | **2** | JM-052 independent of ledger pair; 055→056 chain |

**Peak: 2** (+2 backend). Short wave.

**(3) Gating:** §2 pipeline; flows `[jm-NNN, w3, jeeber]`. `transaction-detail → order-summary-pinned`
deep-link (JM-056) targets the optional `/orders/:id/summary` route added in W1 (CTO-D3).

**(4) EXIT:** JM-052/055/056 SIGNED (or PARTIAL on W2m/W3m) · `--include-tags w3` GREEN ·
`w0..w2_5` still GREEN · analyze/test green.

---

## WAVE 4 — Shared: notifications, support, dispute, account, reviews, settings (JM-057–068)

*Runs last because its deep-links need W1/W2/W3 targets to exist. Mostly re-pointing into already-built
targets. Note: JM-058/059/061/064 (settings leaves off JM-035) can begin as soon as W1's profile tab
is green — only JM-057 (deep-links) and JM-060 (dispute) truly wait on W1/W2/W3 targets.*

**(0) Entry gate:** the deep-link targets these screens point to (W1/W2/W3) exist; mock **S1**
(support), **R1m** (reviews), **D1m** (proof) tracked. **JM-066 account-status redirect gate already
landed in W0**; its screen body lands here.

**(1) Integrator central edits — W4-INT [INT]** (biggest route batch): ADD `/notifications`
(`notifications`, JM-057) · `/support` (`support-ticket`, JM-063) · `/disputes/:id` (`dispute-status`,
JM-065) · flesh out `/account-status` body (gate seeded W0, JM-066) · `/profile/delivery-man/reviews`
(`reviews-list`, JM-068) · `/settings/language` (`language-settings`, register existing, JM-059) ·
`/settings/password` (`password-security`, JM-061) · `/settings/addresses/edit` if not done in W1
(JM-050). S2 DI: notif/support/dispute repos (support→S1 stub until landed). S4 l10n keys.

**(5) Backend mock-fixes that must land:** **S1** (support service → JM-063) · **R1m** (reviews
source → JM-068). (Disputes + notifications prefs/list are already mock-ready — confirm only.)

**(2) Parallel engineer batches:**

| batch | items (JM) | maxN | notes / deps |
|---|---|---|---|
| **W4-LEADIN** (backend) | S1 support · R1m reviews | 2 | gate 063 / 068 |
| **W4-A** P0 shared (critical-ish) | JM-057 notifications-list (deps X8 targets) · JM-060 dispute-open-evidence (deps JM-065, JM-063) | **2** | JM-057 per-row deep-links must hit real routes |
| **W4-B** dispute+support+account (∥) | JM-063 support-ticket (deps S1) · JM-065 dispute-status · JM-066 account-status body · JM-062 logout/delete | **4** | JM-065→060 feeds back; JM-066 gate already in W0 |
| **W4-C** settings+reviews+misc (∥) | JM-058 notif-prefs · JM-059 language · JM-061 password-security (deps JM-022) · JM-064 rate-the-app · JM-067 jeeber-profile-reviews → JM-068 reviews-list (deps R1m) | **5** | 067→068 chain; rest independent leaves off JM-035 |

**Peak: ~7** (B 4 + part of C) + 2 backend.

**(3) Gating:** §2 pipeline; flows `[jm-NNN, w4, shared]`. JM-057's per-row deep-link assertions
must each land on a real route (X8) — assert *tap → target root visible*.

**(4) EXIT (also the release gate):** all W4 JM SIGNED · `--include-tags w4` GREEN · **all prior
suites `w0..w3` still GREEN** · **full regression** `maestro test .maestro/flows/` (every `jm-*` +
the legacy parity flows `01..30`, never deleted) GREEN · analyze/test green · S1+R1m closed.

---

## 5. Max-concurrency / staffing envelope

| wave | integrator | engineers (peak ∥) | backend lead-in | QA (Sonnet) | longest internal chain |
|---|---|---|---|---|---|
| W-1 | — | 2 (app) | 4 | 1 | F-A → F-C |
| W0 | 1 | **6** (W0-B) | (in W-1) | ≤3 | INT → {007/009/005} → 006 |
| W1 | 1 | **6** (W1-B); ~8–10 across A+B+C | 2 (T1, D1m) | ≤4 | INT → 035 → 023 → 025 → 032 → 033 → 034 |
| W2 (+2.5) | 1 | **~9** (A+2.5A+C) | 4 (W1m,K1,O1,D1m) | ≤4 | INT → {054→053 ∥ 037/039→038→040→041→042} → 036 → 044 → 045 |
| W3 | 1 | **2** | 2 (W2m,W3m) | ≤2 | INT → 055 → 056 |
| W4 | 1 | **~7** (B+C) | 2 (S1,R1m) | ≤4 | INT → 067 → 068 / 065 → 060 |

**Calendar overlap (safe):** W2/W2.5 overlaps W1 (separate dirs; join only at JM-045→028/029 accept).
W3 tails W2.5. W4 settings-leaves can start when W1 profile tab is green. **Do NOT overlap** W-1 with
anything, nor W0-INT with W0 screen work (integrator-first is absolute, `21 §D`).

**Branch model:** one branch per wave off `integration/first-run-rc5-mac-book` (`wave/w0`, …);
integrator PR merges first; each item branches off the wave branch (`jm/JM-007-login`); wave merges
up only when all items PO-signed and the wave's full Maestro suite is green.

---

## 6. Demo-readiness checkpoint (the minimal signed-off subset)

The full marketplace loop runs end-to-end the moment this subset is SIGNED (everything else is
enrichment): **W-1:** F1–F4 (B0/B1/B2/B3/B4/U1 + semantics/gradle/Maestro) · **W0:** JM-007, JM-009,
JM-006 (+JM-005 lock branch) · **W1:** JM-023, JM-024, JM-025, JM-026, JM-028, JM-029, JM-031,
JM-032, JM-033, JM-034, JM-035 · **W2/2.5:** W1m, JM-054, JM-053, JM-036, JM-044, JM-045, JM-051 ·
**plus** JM-057 (W4) if the demo shows a notification-driven entry. ≈ **24 JM items + 5
foundation/mock fixes** on the critical demo path; the remaining ~34 items are parallelizable
enrichment after the first green demo.

---

## READY TO EXECUTE W0

**W0 is the first buildable wave. It becomes immediately executable the moment the W-1 floor is
green** (Foundation B0+B1 + backender B2/B3/B4/U1 + semantics/gradle/smoke-Maestro). CTO-D1 has
already resolved the only blocking product question (AUTH-OD-1 → email-first; add `/login` + `/sign-up`,
reuse `/register`'s OTP as the verify step), so there is **no product gate left** for W0.

### Step order (strict)

**Step 0 — W-1 floor (must be green first):**
- **Foundation (app):** **B0** — set `mockBaseUrl` to `http://10.0.2.2:4010` (currently `:3055`) when
  `useMockPrefixes=true` in `lib/core/network/mock_gateway_client.dart`. **B1** — add `/v1/auth/otp`,
  `/v1/auth/social`, `/v1/auth/refresh`, `/v1/auth/login`, `/v1/auth/logout` keys to `_pathToServicePrefix`
  above the legacy `/auth/*` keys. (F2 semantics + F3 gradle `.kts` removal are already DONE — verified.)
- **Backenders:** **B2** (`POST /auth/social`), **B3** (app-client email/pwd login + email-signup +
  recovery-code request/verify + set-password), **B4** (6-digit OTP), **U1** (getMe surfaces `status`
  + role `kycStatus`).
- **QA:** smoke Maestro (`.maestro/smoke.yaml` / `01-splash.yaml`) GREEN on `jeeb_test`.

**Step 1 — W0-INT integrator (one agent, serial, lands FIRST):** add the 6 W0 routes + account-status
stub gate, register DI (real `BiometricLockCubit` + auth repos with B3-stub), add all auth l10n keys,
create `docs/build-out/signoffs/`, flip `walkthrough → /sign-up` call-site is left to JM-010. Phase-A
gate: analyze clean · test green · `jeeb_test` boots · all 6 routes reach their stub root.

**Step 2 — Parallel engineer batches (after INT merges), with per-item QA-RED-first / Reviewer / PO:**
1. **W0-A (maxN 3, critical path):** JM-007 login · JM-009 phone-OTP · JM-005 biometric-unlock.
2. **W0-B (maxN 6, breadth):** JM-008 sign-up · JM-018 social · JM-019 collision sheet · JM-020 recover ·
   JM-021 verify-code · JM-022 set-password · JM-010 walkthrough destination.
3. **W0-C (maxN 2, convergence — last):** JM-006 splash routing (consumes JM-007/005/066 branches) ·
   JM-066 account-status **gate logic only** (full screen W4).

### Exact W0 integrator route additions

| # | action | path | name | screen | JM |
|---|---|---|---|---|---|
| 1 | ADD | `/login` | `login` | `LoginScreen` | JM-007 |
| 2 | ADD | `/sign-up` | `sign-up` | `SignUpScreen` | JM-008 |
| 3 | ADD | `/recover` | `recover-password` | `RecoverPasswordScreen` | JM-020 |
| 4 | ADD (nested) | `/recover/verify` | `recover-verify` | `VerifyRecoveryCodeScreen` | JM-021 |
| 5 | ADD | `/set-password` | `set-password` | `SetPasswordScreen` (`?mode=recovery\|in-app-social`) | JM-022 |
| 6 | REPLACE builder | `/lock` | `biometric-lock` | real `BiometricLockScreen` | JM-005 |
| 7 | EDIT redirect | `_firstRunRedirect` | — | session-aware branches (first-run→`/onboarding`; logged-in customer→`/` last tab D75; jeeber→DELIVERY; biometric→`/lock`; logged-out→`/login`; `status==suspended`→`/account-status` D5) | JM-006 |
| 8 | ADD (stub root) | `/account-status` | `account-status` | `AccountStatusScreen` stub (+ redirect predicate) | JM-066 |

Re-parent (no new route): `phone-otp-verification` stays inside `/register` (JM-009). Native
sheet/dialog (no route): `social-login` (JM-018), `social-collision-prompt` (JM-019).

### Sign-off order within W0
JM-007 → JM-009 → JM-005 → (then) JM-006 → JM-066 gate. JM-008/018/019/020/021/022/010 sign off in
parallel as each goes GREEN. W0 EXITS when all are SIGNED, `--include-tags w0` is GREEN, and analyze/test
are clean on `wave/w0`.
