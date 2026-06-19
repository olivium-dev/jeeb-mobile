# 50 — QA Gating & Definition of Done (the per-item pipeline + the wave gates)

> **Phase 2 deliverable — Lead Principal 3 (QA Gating & DoD).** This is the **process contract**
> that turns each `JM-###` backlog item into a signed-off, regression-protected change. It binds
> together the four already-fixed standards into one runnable pipeline:
>
> - **What to build** — `30_BACKLOG.md` (58 JM items, Given/When/Then ACs naming every `Semantics`
>   id) + `21_NAV_PLAN.md` (routes/edges) + `20_GAP_MAP.md` (per-screen gap).
> - **How to make it testable + the run recipe** — `41_GUARDRAILS_TESTING.md` (the authoritative
>   *how*: id grammar §1.1, test-first pipeline §2, the copy-pasteable run recipe §3, id-not-text §4,
>   accumulating suites §5, the template flow §6, the reviewer checklist §7). **This doc does not
>   restate that recipe — it references §3 verbatim and never forks it.**
> - **Architecture/DoD invariants** — `40_GUARDRAILS_ARCH.md` (Clean Arch + nav honesty + DoD line).
> - **Product law** — `01_CTO_DECISIONS.md` (`CTO-D1..D3`, `R-A..R-F`) + `07_DECISIONS_LOG.md`
>   (`D#`/`G#`/`Q#`). **No product decision is made here.** Where a JM AC is silent, the implementing
>   agent applies **CTO-D R-F** (most blueprint-consistent option, record inline) — QA never invents
>   an acceptance criterion the PO did not write.
>
> **Model policy (CTO brief §8 / CTO-D R-E), enforced per role below:**
> **QA flow authoring (step 2) and QA execution (step 4) run on Sonnet. Every other role —
> PO, Designer, Engineer, Reviewer, Integrator — runs on Opus.**

---

## 0. TL;DR — the one rule per role

1. **PO** writes the AC (already in `30_BACKLOG.md`) and **signs off last** into `signoffs/JM-###.md`. *(Opus)*
2. **QA authors the RED flow FIRST** — `.maestro/flows/jm-NNN-slug.yaml`, keyed on the AC's
   `Semantics(identifier:)`, before any screen code exists. The flow **is** the executable AC. *(Sonnet)*
3. **Engineer** implements screen + nav + mock until every id in the flow appears in
   `maestro hierarchy` (`41 §1.4`). *(Opus)*
4. **Reviewer** reviews the diff against `41 §7` + `40` Clean-Arch/nav-honesty. *(Opus)*
5. **QA runs the flow on `jeeb_test` against mock** until **GREEN**, plus the prior-wave suite as a
   regression gate. *(Sonnet)*
6. **PO signs off** — DoD met (CTO brief §10) → `signoffs/JM-###.md` → **DONE**.

A flow that ever went green is **append-only**: never deleted, only migrated when its screen is
re-worked under a new JM (`41 §5`).

---

## 1. The per-item pipeline (RED → GREEN → SIGNED)

This is the data-mediated loop from CTO brief §7 / `41 §2`, expanded into a checkable state machine.
**Each item moves strictly left→right; it cannot skip a state. The artifact named at each gate is
the proof the state was reached** (agents communicate through files in `docs/build-out/`, never by
guessing — CTO brief §7).

```
 S0 AC-READY      S1 RED            S2 IMPLEMENTED     S3 REVIEWED      S4 GREEN          S5 SIGNED
┌───────────┐   ┌────────────┐   ┌───────────────┐  ┌────────────┐  ┌──────────────┐  ┌──────────────┐
│ PO   Opus │──▶│ QA  Sonnet │──▶│ ENG     Opus  │─▶│ REVR  Opus │─▶│ QA   Sonnet  │─▶│ PO    Opus   │
│ AC in     │   │ flow keyed │   │ screen+nav+   │  │ diff vs    │  │ flow GREEN + │  │ DoD checked  │
│ 30_BACKLOG│   │ on AC ids, │   │ mock; every   │  │ 41 §7 +    │  │ prior-wave   │  │ → signoffs/  │
│ G/W/T,    │   │ RED (no    │   │ id appears in │  │ 40 Clean-  │  │ suite still  │  │ JM-###.md    │
│ ids named │   │ screen yet)│   │ hierarchy §1.4│  │ Arch/nav   │  │ green (regr.)│  │ = DONE       │
└───────────┘   └────────────┘   └───────────────┘  └────────────┘  └──────────────┘  └──────────────┘
   proof:           proof:            proof:             proof:           proof:            proof:
 AC text +       jm-NNN flow      hierarchy dump     review note in   JUNIT xml in      signoffs/
 id list         committed RED    shows all ids      signoff stub     evidence/maestro  JM-###.md
```

### S0 — AC-READY (PO, Opus)
- **Done already** for all 58 items: each `JM-###` in `30_BACKLOG.md` has a Given/When/Then AC that
  **names every `Semantics(identifier:)`** QA will assert (e.g. `JM-007` names `login_email_field`,
  `login_password_field`, `login_password_visibility_toggle`, `login_continue_cta`,
  `login_forgot_password_link`, `login_signup_link`, `login_social_<provider>`,
  `login_biometric_affordance`). The id convention is `30_BACKLOG.md §"Identifier convention"`;
  the full grammar is `41 §1.1`.
- **PO obligation at S0:** confirm the AC's ids follow the grammar and that every nav target the AC
  asserts is a real route/tab in `21_NAV_PLAN.md §A/§B` (nav honesty, CTO brief §6.7). If a target is
  itself unbuilt (cross-wave), the AC must say so (e.g. `JM-035` "rows light up as targets land") so
  QA writes a *tap-accepted + root-survives* assertion, not a fabricated destination (`41 §2`, AP-9).
- **Gate to S1:** AC text + the explicit id list exist. No screen code may begin before S1.

### S1 — RED (QA, **Sonnet**)
- QA authors **one flow per item**, `/.maestro/flows/jm-NNN-slug.yaml`, from the template `41 §6`.
  `NNN` = zero-padded JM number; `slug` = blueprint screen id (`jm-007-login.yaml`,
  `jm-053-wallet-hub.yaml`, `jm-029-offer-accept-confirm.yaml`).
- The flow keys **only** on ids the AC named (`41 §2`). It asserts by **id, never visible text /
  label / coordinate** (`41 §4`, CTO-D R-B, AP-5/AP-1). Timed waits use `extendedWaitUntil`;
  settles use `waitForAnimationToEnd`; **no fixed `sleep`** (AP-1/AP-7). It carries `tags: [jm-NNN,
  wN, <area>]` (`41 §5.1`).
- It is expected to be **RED** now (screen unbuilt or ids absent). RED-for-the-right-reason is the
  signal, not a failure: it must red on *missing id / missing screen*, not on a flow syntax error.
  QA proves this by running it once (it errors on the absent root id) and committing it red.
- **Sheets** use `<screenId>_sheet_<element>` (`41 §1.1`, worked example `41 §6.1` —
  `jm-029-offer-accept-confirm.yaml`). **Tab bodies are reached via `shell_tab_<id>`, never a path**
  (`41 §1.1`, `21_NAV_PLAN §A "Tab disambiguation"`): the six tab-body items
  (`JM-023` requests, `JM-035` profile, `JM-036`/`JM-048` delivery/dashboard, `JM-052` earnings,
  `JM-027` replies sub-tab) tap `shell_tab_requests` / `shell_tab_delivery` / `shell_tab_profile` /
  `shell_tab_dashboard` / `shell_tab_earnings` (and sub-tab chips by id) to arrive.
- **Dev-seam entry** (not clearState) when a screen sits deep in a flow that can't yet be reached
  end-to-end: pass the route/state as Android **intent extras** via `launchApp.arguments`
  (`jeeb.route`, `jeeb.home_tab`, `jeeb.feed`, `jeeb.state`, `jeeb.locale`, `jeeb.hold_splash` —
  the knobs in flows `01`/`13`), **never** `--dart-define` for seam knobs (`41 §3.4`). Example:
  `jm-029` launches `jeeb.route: "/requests/req-1/offers"` to raise the sheet directly.
- **Gate to S2:** the `jm-NNN` flow is committed and demonstrably RED on the missing root/id (the
  S1 proof). **Engineer may not start before this flow exists** (test-first, CTO brief §7 / `41 §2`).

### S2 — IMPLEMENTED (Engineer, Opus)
- Engineer builds the screen (Clean Arch `data/domain/presentation`, bloc/GoRouter/GetIt/Dio per
  `40`), wires the nav (route added centrally in the wave's `app_router.dart` batch first —
  `21_NAV_PLAN §D` — then the call-site edge), and wires the mock (`:4010`, `useMockPrefixes=true`).
- Adds `Semantics(identifier:)` per `41 §1.2` (Rule A `container: true`; never via `Container`/
  `Padding`/`MergeSemantics`) to **every id the QA flow references**, until:
  ```bash
  export JAVA_HOME="$(/usr/libexec/java_home)"
  ~/.maestro/bin/maestro hierarchy | grep -iE 'resource-id|identifier'
  ```
  shows **every** AC id as a real Android `resource-id` (`41 §1.4`). An id set-but-merged is a defect
  the engineer fixes (add `container: true` / scroll into view / build the right state).
- Where a downstream backend leg is unwired on dev (e.g. a mock gap from `20_GAP_MAP §"Mock contract
  gaps"` — `B1`/`W1m`/`O1`/`S1`/`R1m`/`U1`/`T1`/`K1`/`D1m`), the engineer records it inline (CTO-D
  R-F) so QA's GREEN at S4 asserts *tap-accepted + screen survives* rather than a destination the
  mock can't produce (AP-9). The mock owner closes the gap on the backender track (`42_GUARDRAILS_
  MOCK.md`); the item is **not** signed off on the data-bound AC until the gap lands (CTO-D2's rule
  for wallet — UI shell builds now, data-bound ACs validate once `W1m–W3m` land).
- **Gate to S3:** every AC id present in `maestro hierarchy` (dump attached to the signoff stub);
  `flutter analyze` clean + `flutter test` green locally (the analyze/test gate, §3 below).

### S3 — REVIEWED (Reviewer, Opus)
- Reviewer runs the **`41 §7` checklist** against the diff (it is the authoritative reviewer gate;
  not re-printed here) **plus** the `40` architecture invariants:
  - every interactive/asserted widget has a grammar-valid `Semantics(identifier:)`; **no new
    leading-underscore ids** (`41 §1.1` legacy clause);
  - the flow asserts on **ids only** (no text/label/coordinate; no fixed `sleep`);
  - **nav honesty:** every `goNamed/push` target is a registered route in `21_NAV_PLAN §B`, added in
    the wave's central router batch (`§D`), not ad-hoc;
  - Clean-Arch layering + OMDS-only styling (`40`); mock wired to `:4010` not a real backend;
  - the flow is named `jm-NNN-slug.yaml` and carries its `jm-NNN`/`wN` tags.
- A failing checklist item is a **block, not a comment**: the reviewer returns the item to S2 with
  the specific `41 §7` / `40` line cited. Reviewer records the verdict in the signoff stub's
  **Review** section (see §2).
- **Gate to S4:** reviewer "approved" recorded; analyze/test still green.

### S4 — GREEN (QA, **Sonnet**)
- QA runs the item flow with the **exact recipe from `41 §3` (do not fork it)** on `jeeb_test` (dev
  flavor `app.jeeb.mobile.dev`, mock on host `:4010` via `10.0.2.2`), capturing JUNIT evidence:
  ```bash
  JAVA_HOME=$(/usr/libexec/java_home) maestro --device emulator-5554 test \
    -e APP_ID=app.jeeb.mobile.dev \
    --format JUNIT --output evidence/maestro/jm-NNN-junit.xml \
    .maestro/flows/jm-NNN-slug.yaml
  ```
- The item flow must be **GREEN**. Then QA runs the **prior-wave regression suite** (`--include-tags
  wN` of every wave already signed off, §4 below) — it must **stay GREEN**. A new screen that reds an
  earlier flow is a regression: **return to S2, fix, do not retag/skip** (`41 §5.2`).
- Evidence pack for the signoff: the item JUNIT xml + the `takeScreenshot` frames (settled, after
  `waitForAnimationToEnd`) under `evidence/maestro/`.
- **Gate to S5:** item flow GREEN + prior-wave suite GREEN, JUNIT attached.

### S5 — SIGNED (PO, Opus)
- PO verifies the **Definition of Done** (CTO brief §10 / `40`): screen matches blueprint+decisions ·
  OMDS components · nav wired both directions · wired to mock · `Semantics(identifier:)` present ·
  Maestro flow green · `flutter analyze` clean + `flutter test` green · reviewer approved · ACs met.
- PO writes **`signoffs/JM-###.md`** (format §2). The item is **DONE** only when this file exists and
  every DoD checkbox is ticked with a pointer to its evidence. **No human/owner gate** — the PO agent
  signs per the AC and CTO-D rulings; it never waits on the owner (CTO-D R-F).
- If a data-bound AC is parked on a mock gap (CTO-D2 wallet pattern), the signoff records it as
  **PARTIAL — UI-signed, data-bound AC pending `<ref>`** and lists the blocking mock ref; the item
  re-enters S4 for the data-bound assertions when the gap lands. It is **not** counted DONE until then.

---

## 2. The signoff artifact (`signoffs/JM-###.md`)

One file per item, created as a **stub at S1** (so the chain is auditable from the first RED) and
**completed at S5**. Path: `/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile/docs/build-out/signoffs/JM-###.md`
(the `signoffs/` dir does not yet exist — the W0 integrator creates it). The format is fixed so the
orchestrator can parse status and the next wave's entry gate can verify all prior items are `SIGNED`.

```markdown
# JM-007 — Login (email/password) — SIGNOFF

- **Blueprint screen:** `login`            **Wave:** W0      **Area:** auth
- **Route(s):** `/login` (name `login`)    **Tab body:** no
- **Status:** SIGNED            <!-- one of: RED | IMPLEMENTED | REVIEWED | GREEN | SIGNED | PARTIAL -->
- **Flow:** `.maestro/flows/jm-007-login.yaml`   **Tags:** jm-007, w0, auth
- **Decisions honored:** D22, D23, D65, D85, CTO-D1
- **Mock refs:** B1 (auth /v1 rewrite), B3 (app-client login route)   <!-- gaps gating data-bound ACs -->

## Acceptance criteria → evidence  (each AC line from 30_BACKLOG.md JM-007)
| # | AC (Given/When/Then, abbrev) | id(s) asserted | flow step | result |
|---|---|---|---|---|
| 1 | valid creds → Requests tab | login_email_field, login_password_field, login_continue_cta, shell_tab_requests | tapOn login_continue_cta → assert shell host | PASS |
| 2 | visibility toggle flips masking | login_password_visibility_toggle | tapOn → re-assert field | PASS |
| 3 | forgot → /recover | login_forgot_password_link | tapOn → recover_password_root | PASS |
| 4 | signup link → sign-up | login_signup_link | tapOn → sign_up_root | PASS |
| 5 | biometric affordance shown (enrolled) | login_biometric_affordance | assertVisible | PASS |

## Definition of Done (CTO brief §10)  — tick with evidence pointer
- [x] Screen matches blueprint + decisions (20_GAP_MAP / 30_BACKLOG)        → review note below
- [x] OMDS components only (40_GUARDRAILS_ARCH)                              → reviewer ✓
- [x] Nav wired both directions (21_NAV_PLAN §B/§C)                          → routes added in W0 router batch
- [x] Wired to mock :4010 (useMockPrefixes=true)                            → B1/B3 landed; auth reaches :4010
- [x] Semantics(identifier:) present, verified in `maestro hierarchy`        → evidence/hierarchy/jm-007.txt
- [x] Maestro flow GREEN on jeeb_test against mock                           → evidence/maestro/jm-007-junit.xml
- [x] flutter analyze clean + flutter test green                            → §3 gate run <hash>
- [x] Reviewer approved                                                      → Review section
- [x] PO criteria met (all AC rows PASS)                                     → table above

## Hierarchy proof (S2)
`maestro hierarchy` confirmed ids before GREEN: login_email_field, login_password_field,
login_password_visibility_toggle, login_continue_cta, login_forgot_password_link, login_signup_link,
login_biometric_affordance, login_root.   → evidence/hierarchy/jm-007.txt

## Regression (S4)
- Item flow: GREEN — evidence/maestro/jm-007-junit.xml
- Prior-wave suites still green: (W0 is the first wave — n/a; later items list w0..w{N-1} JUNIT)

## Review (S3 — Reviewer, Opus)
41 §7 checklist: all pass. 40 Clean-Arch: data/domain/presentation present; bloc+GoRouter+GetIt+Dio.
Nav honesty: /login, /recover targets registered in W0 batch. No text/coordinate assertions. Approved.

## Trail (who/when/model)
- S0 AC-READY  — PO    (Opus)   — 30_BACKLOG.md JM-007
- S1 RED       — QA    (Sonnet) — flow committed red on missing login_root
- S2 IMPLEMENTED — ENG (Opus)   — branch <ref>; hierarchy ✓
- S3 REVIEWED  — REVR  (Opus)   — approved
- S4 GREEN     — QA    (Sonnet) — jm-007-junit.xml PASS; prior-wave suites green
- S5 SIGNED    — PO    (Opus)   — DoD complete
```

**Rules for the artifact:**
- The **AC→evidence table** has exactly one row per Given/When/Then line in that item's
  `30_BACKLOG.md` AC. Every row names the id(s) asserted and the flow step — this is what makes the
  flow *the executable AC*. A `PARTIAL` row (data-bound, blocked on a mock ref) is allowed only with
  the ref in **Mock refs** and a re-test plan in **Regression**.
- **Status** values map 1:1 to the pipeline states (§1). The orchestrator treats only `SIGNED` (and,
  for a parked data-bound leg, `PARTIAL`) as "moves the wave forward".
- Evidence is **referenced, never inlined**: `evidence/maestro/jm-NNN-junit.xml`,
  `evidence/hierarchy/jm-NNN.txt`, screenshots under `evidence/maestro/`. (Matches the `--format
  JUNIT --output` pattern flows `01`/`13` already emit, `41 §3.5`/§5.2.)

---

## 3. The analyze + test gates (every handoff, every wave)

Two standing gates from CTO brief §8 / `40` ("Don't break green"). They run at **S2 (engineer
pre-handoff)**, **S4 (QA, before declaring GREEN)**, and **at every wave EXIT (§5)**.

```bash
cd /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile
/Users/oudaykhaled/flutter/bin/flutter analyze        # must be CLEAN (zero errors/warnings)
/Users/oudaykhaled/flutter/bin/flutter test           # must be GREEN (all unit/widget tests pass)
```

- **analyze gate:** zero issues. A lint/analyzer error blocks the handoff at S2 and blocks the wave
  EXIT — it is never "warned and merged".
- **test gate:** the full `flutter test` suite green. New screens add their own widget/bloc tests
  (Clean-Arch testability, `40`); these accumulate exactly like Maestro flows.
- These are **distinct from the Maestro gate**: analyze/test is static + unit/widget (host machine,
  no emulator); Maestro is on-device behavior (`jeeb_test` + mock). DoD requires **both** green.
- Before any Android Maestro run, the engineer removes the stray Kotlin-DSL gradle files that break
  the Android build (`rm -f android/build.gradle.kts android/settings.gradle.kts
  android/app/build.gradle.kts`, CTO brief §5 / `41 §3.4`).

---

## 4. The per-wave regression suite (accumulating flows)

Flows are **append-only** (`41 §5`). Each item's `jm-NNN` flow joins its wave's tag-suite and stays a
permanent gate. Wave tags mirror `30_BACKLOG.md §"Wave summary"` and `41 §5.1`:

| tag | wave | items (JM) | suite grows to include |
|---|---|---|---|
| `w0` | Foundation: auth + biometric + session/status gates | 001,005,006,007,008,009,010,018,019,020,021,022 | all w0 flows |
| `w1` | Core customer journey (request→offer→track→receipt→rate) + profile | 023,024,025,026,027,028,029,030,031,032,033,034,035,049,050 | w0 + w1 |
| `w2` | Jeeber onboarding + KYC-gates-offering + composer | 036,037,038,039,040,041,042,043,044,045,046,047,048,051 | w0 + w1 + w2 |
| `w2_5` | Wallet hub + charge-info (unblock W2 money CTAs) | 053,054 | runs alongside w2 |
| `w3` | Wallet ledger/txn + earnings | 052,055,056 | w0..w2_5 + w3 |
| `w4` | Shared: notifications/support/dispute/account/reviews/settings | 057,058,059,060,061,062,063,064,065,066,067,068 | w0..w3 + w4 |

**Run a wave's full suite** (the exact `--include-tags` invocation from `41 §5.1`, not forked):

```bash
export JAVA_HOME="$(/usr/libexec/java_home)"
maestro --device emulator-5554 test \
  -e APP_ID=app.jeeb.mobile.dev \
  --include-tags w0 \
  --format JUNIT --output evidence/maestro/w0-suite-junit.xml \
  .maestro/flows/
```

The three accumulating gates (`41 §5.2`), restated as **who runs them when**:
- **Per item (S4):** `jm-NNN` flow GREEN → required for that item's signoff.
- **Per wave (entry gate to the next wave):** the **entire prior-wave suite** (`--include-tags wN`)
  GREEN before the next wave's parallel build starts (this is the EXIT checklist, §5). QA runs it; a
  red is a regression → fix in the owning item before the next wave begins.
- **Full regression (release gate):** `maestro test .maestro/flows/` (no tag filter) runs every
  `jm-*` flow **plus the legacy parity flows `01`..`30`** (kept, never deleted — `41 §2`/§5.2). Run
  at the end of W4 (and before any external handoff).

**W2.5 sequencing note (CTO-D2 / `30_BACKLOG.md §"Wave summary"`):** `jm-053`/`jm-054` (wallet hub +
charge-info) run **alongside W2** because every "+ Top up" CTA routes to `wallet-charge-info`; their
flows are tagged `w2_5` and must be GREEN before `jm-045`/`jm-046` (composer money lines +
insufficient-balance) can reach S4. The W2 EXIT checklist therefore requires the `w2` **and** `w2_5`
suites green together.

---

## 5. Wave EXIT checklist (entry gate to the next wave)

A wave is **EXITED** (and the next wave's parallel build may start) only when **every line** below is
true. The integrator + PO co-own this; QA produces the suite evidence. This is the hard gate that
keeps "don't break green" true across the whole build-out.

```
WAVE W_ EXIT CHECKLIST                                                      owner   evidence
─────────────────────────────────────────────────────────────────────────────────────────
[ ] Every JM item in the wave has signoffs/JM-###.md with Status: SIGNED   PO      signoffs/*.md
    (or PARTIAL with a tracked mock ref + re-test plan — CTO-D2).
[ ] Every item's jm-NNN flow is GREEN individually (S4).                    QA      evidence/maestro/jm-*-junit.xml
[ ] The wave's full tag-suite (--include-tags wN) is GREEN.                 QA      evidence/maestro/wN-suite-junit.xml
[ ] ALL prior-wave suites (w0..w{N-1}) still GREEN (no regression).         QA      evidence/maestro/w*-suite-junit.xml
[ ] flutter analyze CLEAN on the integrated branch.                        ENG     §3 run log
[ ] flutter test GREEN on the integrated branch.                           ENG     §3 run log
[ ] Every new route in the wave's 21_NAV_PLAN §B batch is registered and    REVR    diff vs 21_NAV_PLAN §B
    reachable; every wired edge (§C) hits a real target (nav honesty).
[ ] No new leading-underscore Semantics ids introduced (41 §1.1).           REVR    41 §7 checklist
[ ] Every flow asserts by id only — zero text/label/coordinate assertions,  REVR    41 §7 / §4
    zero fixed sleeps (41 §4, AP-1/AP-5/AP-7).
[ ] Mock gaps that gated this wave (20_GAP_MAP) are either CLOSED on the    PO+BE   42_GUARDRAILS_MOCK
    backender track, or the dependent ACs are explicitly PARTIAL-parked.
[ ] Dev-seam knobs used by this wave's flows are intent-extras only         REVR    flow review
    (jeeb.route/home_tab/feed/state/locale), never dart-defines (41 §3.4).
```

**Per-wave entry preconditions** (from `30_BACKLOG.md` wave gates — the wave cannot even reach S1
until these hold; restated so the EXIT of one wave feeds the entry of the next):
- **W0 entry:** mock blockers `B1` (`/v1/auth/...` rewrite), `B3` (app-client login/signup/recover/
  set-password), `B4` (OTP length), `U1` (getMe surfaces `status`+role `kycStatus`) fixed by
  foundation/backenders; **CTO-D1 already resolves AUTH-OD-1** (email-first; add `/login`+`/sign-up`,
  reuse `/register` OTP) so `JM-007/008/010` are unblocked.
- **W1 entry:** W0 EXITED (shell + session routing landed: `JM-006` splash gate, `JM-005` lock).
- **W2 entry:** W0 EXITED + `U1` (role `kycStatus`); offer-composer money lines (`JM-045`) +
  insufficient-balance (`JM-046`) gate on **W2.5** wallet (`JM-053/054`) — those two are tagged
  `w2_5` and must be GREEN first.
- **W3 entry:** W0 EXITED + mock `W1m`/`W2m`/`W3m` (balance/ledger/txn) + `O1` (offer 402) defined by
  backenders (CTO-D2) — until then `JM-055/056` build the UI shell but their data-bound ACs are
  PARTIAL-parked, validated when the ledger lands.
- **W4 entry:** the deep-link targets these screens point to (W1/W2/W3) exist; mock `S1`
  (support), `R1m` (reviews), `D1m` (proof sink) tracked for backenders. **`JM-066` account-status
  router gate may need to land in W0** if the splash status branch (`JM-006`) requires it — build the
  gate logic in W0, the full screen in W4 (`30_BACKLOG.md` JM-066 note).

---

## 6. End-to-end worked example — `JM-029` (Accept Offer Confirmation sheet)

Ties §1–§5 together on a real item (the sheet form, `41 §6.1`):

1. **S0 (PO, Opus):** AC in `30_BACKLOG.md` JM-029 names `offer_accept_sheet`,
   `offer_accept_sheet_confirm_cta` (the AC's `offer_accept_confirm_cta`), `offer_accept_sheet_cancel_cta`,
   destination `order-chat`. Decisions D11/D71/D69. PO confirms `/requests/:id/offers` (W1 §B) +
   `/chat/:id` are real routes.
2. **S1 (QA, Sonnet):** authors `.maestro/flows/jm-029-offer-accept-confirm.yaml` (verbatim the
   `41 §6.1` example), `tags: [jm-029, w1, customer]`, dev-seam `launchApp.arguments.jeeb.route:
   "/requests/req-1/offers"`, opens the sheet from seeded `offer_card_off-1_accept_cta`, asserts the
   sheet, cancel→list, re-open→confirm→`order_chat_root`. Runs it: RED (sheet not built). Commits red.
   Creates `signoffs/JM-029.md` stub, Status: RED.
3. **S2 (ENG, Opus):** builds the OMDS confirm bottom sheet, captures fee + closes losers on confirm,
   routes to order-chat; adds `Semantics(identifier:)` (`container: true`) to the three sheet ids;
   `maestro hierarchy` shows all three + `offer_accept_sheet`; `flutter analyze`/`test` green. Updates
   stub → IMPLEMENTED, attaches hierarchy dump.
4. **S3 (REVR, Opus):** `41 §7` checklist + `40`: sheet uses OMDS, ids grammar-valid, no text/coord
   assertions in the flow, nav target real. Approved → stub REVIEWED.
5. **S4 (QA, Sonnet):** runs jm-029 with `41 §3.5` recipe → GREEN (junit attached); runs `--include-tags
   w0` (prior wave) → still GREEN. Stub → GREEN.
6. **S5 (PO, Opus):** DoD all ticked; fills AC→evidence table (4 rows, all PASS); Status: SIGNED.
   JM-029 counts toward the **W1 EXIT** checklist (§5).

---

## 7. Cross-references (do not duplicate — this doc orchestrates these)

- **Run recipe / id grammar / template / reviewer checklist / accumulating suites:**
  `41_GUARDRAILS_TESTING.md` (§1.1 grammar, §1.4 hierarchy verify, §2 pipeline, §3 recipe, §4
  id-not-text, §5 suites, §6 template + §6.1 worked sheet, §7 reviewer gate). **Authoritative; this
  doc references it and never forks the recipe.**
- **Architecture/DoD invariants + analyze/test "don't break green":** `40_GUARDRAILS_ARCH.md`.
- **Mock gaps that gate waves + the backender track:** `20_GAP_MAP.md §"Mock contract gaps"`,
  `42_GUARDRAILS_MOCK.md`.
- **What/where to build + ACs (the id source of truth):** `30_BACKLOG.md` (58 JM, 5 waves) +
  `21_NAV_PLAN.md` (routes §B / edges §C / shared-file batching §D / tab-vs-route §A).
- **Product law (cite, never re-litigate):** `01_CTO_DECISIONS.md` (CTO-D1 auth, CTO-D2 wallet
  contract, CTO-D3 order-summary, R-A surface, R-B id-not-text, R-E model policy, R-F no human gate);
  `jeeb-mind-map/docs/07_DECISIONS_LOG.md` (`D#`/`G#`/`Q#`).
- **Mission + pipeline + DoD §10 + env/MAESTRO BLOCKER:** `00_CTO_BRIEF.md` (§5/§6.6/§7/§8/§10).
- **Reference flows for the patterns:** `.maestro/flows/01-splash.yaml` (id-only + locale=ar + seam),
  `13-request-pending-requests.yaml` (dev-seam route + dynamic row id + tap-accepted honesty),
  `30-walkthrough-login-home.yaml` (node-merge lesson → `container: true`), `.maestro/smoke.yaml`
  (the original empty-semantics blocker).
