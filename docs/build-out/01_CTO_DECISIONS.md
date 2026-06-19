# 01 — CTO Decisions (resolving Phase 1 blockers)

> The owner is unreachable for this engagement ("I will not be on my laptop … you can never
> ask me for access"). The standing rule is therefore: **the team must not stall on a product
> question — the CTO rules, biased toward (a) blueprint fidelity, (b) least rework of shipped
> code, (c) keeping the mock authoritative-able by backenders.** Each ruling below is reversible
> and documented so the owner can override later. Cite these as `CTO-D#`.

---

## CTO-D1 — Auth funnel: **follow the blueprint (email-first), reuse the phone-OTP machinery**
*(resolves AUTH-OD-1; unblocks JM-007/008/009/010/018/019/020/021/022)*

- The blueprint is the authoritative design and the owner said to rely on it. The canonical
  funnel is **email-first**: `sign-up` collects **Name / Email / Password**, then **phone-OTP**
  verification (G8) before the account is active.
- `login` = **email + password**, with a **biometric affordance** for returning enrolled users
  (D23) and a "forgot password" → recovery path.
- **Reuse, don't rebuild:** the existing phone-first `/register` already implements the phone +
  OTP step — it becomes the **phone-OTP verification step (JM-009)** behind sign-up/social, not a
  separate funnel. Net rework is the *entry ordering* + two new screens (`/login`, `/sign-up`),
  not the session/refresh/biometric stack (kept as-is).
- Routes: add `/login` and `/sign-up`; keep `/register`'s OTP logic reachable as the verify step.
- **Rationale:** honors blueprint + D8/D21/D22/D23/G8; contains rework to the funnel head.

## CTO-D2 — Wallet data contract: **backenders own it; UI shells start in parallel**
*(resolves the W1m/W2m/W3m/O1 "blocker" — reclassified as backend work, not a stall)*

- This is precisely the backenders' mandate ("update and change the mock"). The mock
  `wallet-service` is extended to expose, sourced from `jeeb-mind-map/docs/05_WALLET_SCREENS.md`
  + `08_PARAMETERS.md` + decisions D1/D37/D41/D43/D92/D93:
  - **W1m** `GET /wallet-service/v1/jeeb/wallet` → `{ availableBalance, affordabilityState:
    'enough'|'low'|'empty'|'all_reserved', reservedNow, giftCredit }` (D1/D43/D42).
  - **W2m** `GET /wallet-service/v1/jeeb/wallet/ledger` → typed rows
    `{ id, type: reserve|fee_won|released|refund|penalty|topup|gift, amount, sign, ref, ts }`.
  - **W3m** `GET /wallet-service/v1/jeeb/wallet/ledger/:id` → per-row detail.
  - **O1** `POST /offer-service/v1/offers` returns **402** w/ `{needed, available}` on insufficient
    balance, and emits reserve/capture/release ledger rows on submit/win/lose.
- Wallet UI (JM-053/054/055/056) builds its widget tree + states immediately; **data-bound ACs
  are validated once W1m–W3m land** (sequence wallet backend ahead of W2.5 in the exec plan).
- **Rationale:** no stall; the wire format is owned by backenders so app + mock stay in lockstep.

## CTO-D3 — `order-summary-pinned`: **pinned header widget + optional deep-link route** (accept default)
*(resolves the JM-031 route question)*

- Build it as a **reusable pinned-price header widget** injected into `order-chat` + `order-tracking`,
  AND register an optional `/orders/:id/summary` route so the `transaction-detail →
  order-summary-pinned` deep-link (JM-056) has a navigable target.
- **Rationale:** matches how it actually functions (a strip) while keeping every blueprint edge honest.

---

## Standing operating rulings (apply throughout)

- **R-A (testing surface):** primary = **Android emulator `jeeb_test`** + dev flavor
  (`app.jeeb.mobile.dev`); iOS sim is an acceptable fallback. Mock only (`:4010`).
- **R-B (Maestro):** every run exports `JAVA_HOME=$(/usr/libexec/java_home)`; flows assert on
  `Semantics(identifier:)`, never visible text. Semantics export is enabled at boot (Phase 2).
- **R-C (5-tier catalog, T1):** blueprint fixes **5 tiers** (Flash/Express/Standard/On-the-Way/Eco)
  — backenders make `GET /delivery-service/v1/tiers` return 5; not a product question.
- **R-D (missing OMDS components):** build local widgets (`OmdsAmount`, bottom-nav) per
  `22_DESIGN_NOTES.md` conventions; do not block on the design system library.
- **R-E (model policy):** QA test authoring/execution = Sonnet; all other roles = Opus.
- **R-F (no human gate):** where the spec is silent and no CTO-D covers it, the implementing agent
  picks the **most blueprint-consistent, least-surprising** option, records the assumption inline,
  and proceeds. Never wait on the owner.
