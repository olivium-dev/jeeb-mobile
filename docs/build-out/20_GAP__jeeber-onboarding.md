# 20_GAP — Domain: jeeber-onboarding (JEEBER onboarding / KYC / offering)

> Phase 1 gap analysis. Compares each blueprint screen contract
> (`jeeb-mind-map/web/blueprint.json` + `web/src/screens/_data/<id>.json`) against the
> Flutter app (`jeeb-mobile/lib/features`, router `lib/core/router/app_router.dart`) and the
> mock backend (`jeeb-mock-backend/src/services`). Authority: CTO brief `00_CTO_BRIEF.md`,
> decisions `jeeb-mind-map/docs/07_DECISIONS_LOG.md` D1–D93.
>
> Status legend: **exists** (built, matches) · **partial** (built, missing contract pieces) ·
> **divergent** (built but contradicts a decision / blueprint) · **missing** (no implementation).

---

## Domain-wide findings (read first)

The Jeeber-onboarding domain is the **least blueprint-faithful** in the app. Three
cross-cutting defects govern almost every screen below:

1. **D20 (no vehicle data) is violated in TWO places.**
   - DM-onboarding "Personal Details" step renders a **Vehicle number** field
     (`dm_onboarding_address_step.dart` `_vehicle(...)`, identifier
     `dm_onboarding_address_vehicle_number_field`; state field `vehicleNumber` in
     `dm_onboarding_state.dart`/`dm_onboarding_cubit.dart`; persisted in
     `DmOnboardingSubmission.vehicleNumber`).
   - The KYC wizard has an **entire Vehicle step** (`kyc/presentation/widgets/kyc_vehicle_step.dart`,
     `VehicleType` + `vehicleRegistration` on `KycSubmission`, `KycWizardStep.vehicle`,
     `kyc-vehicle-*` keys; `KycRejectionReason.vehicleDocumentMissing`).
   Blueprint `delivery-onboarding-personal-details` + D20 require the vehicle field **removed**;
   `kyc-identity` is **Gov-ID (front+back) + selfie only** — no vehicle capture. Both must be
   stripped. This is the single largest divergence and touches every onboarding/KYC screen.

2. **The onboarding → KYC → funding chain does not exist.**
   Blueprint sequence (per `_data` `outgoing` edges):
   `delivery-register-prompt → delivery-onboarding-image-upload → delivery-onboarding-personal-details
   → delivery-onboarding-service-area → kyc-identity → onboarding-funding → kyc-pending-status`.
   Flutter reality: `DmOnboardingScreen` (`/jeeber/onboarding`) runs **photo → address → service-area
   → submit-to-Fake-gateway → pop**, and `KycWizardScreen` (`/profile/kyc`) is a **separate,
   unchained** wizard (schema → id → selfie → vehicle → tos → submitting → status). There is **no
   `onboarding-funding` step at all**, and service-area's "Continue" does **not** flow into KYC.
   The two wizards are disjoint islands.

3. **The structured offer composer (D1/D14/D44) is not built.**
   The routed `OfferSubmissionScreen` (`lib/features/offers/...`, `/jeeber/requests/:id/offer`) is a
   bare price + ETA + note form. It is **missing**: the exact **10% platform-fee line** (D37/D44),
   the **"you earn (cash)" net-per-offer line** (D44), the **"reserved now; charged if you win;
   released if not"** copy (D1), the **ETA dropdown constrained to the tier SLA band** (D14 — current
   field is a free integer-minutes input), and there is **no insufficient-balance path** (D43)
   — neither in the UI nor in the mock.

**Routing facts.** Only two routes serve this whole domain: `/jeeber/onboarding`
(`DmOnboardingScreen`) and `/profile/kyc` (`KycWizardScreen`), plus `/jeeber/requests/:id/offer`
(`OfferSubmissionScreen`) and `/jeeber/requests/:id` (`JeeberRequestDetailScreen`). There are **no
distinct routes/screens** for `delivery-register-prompt`, `onboarding-funding`, `offer-kyc-gate`,
`offer-insufficient-balance`, or `wallet-charge-info`. The "not registered" state is an **inline
view** (`jeeber_home/presentation/widgets/jeeber_unregistered_view.dart`) toggled **only by a
debug dev-seam flag** (`dashboard_tab.dart` `_devSeamUnregistered()`), **not by real KYC status** —
so in release the gate never engages off the live `user.kycStatus`.

**Mock facts.**
- `offer-service` (`POST /offer-service/v1/offers`) has **no wallet balance / reserve check** — it
  only 409s on duplicate request+jeeber. No 402 / insufficient-balance contract exists.
- `wallet-service` exposes **earnings only** (`GET /v1/jeeb/earnings`); there is **no balance,
  reserved-amount, or reserve-on-offer endpoint** anywhere. D1's per-offer reserve is unbacked.
- KYC: the Flutter `DioKycGateway` calls `/v1/kyc/jeeb/form-schema`, `/v1/kyc/submit`, `/v1/kyc/status`,
  etc. The **mock has none of those** — KYC lives at `form-builder-service` `GET/POST
  /v1/templates/:templateId` (`jeeb_jeeber_v1`), `contract-signing-service` `/v1/templates/:id`
  (`jeeb_tos_v1`), and status at `user-management` `GET /user-management/users/:userId/kyc`. This is a
  contract mismatch the KYC screens inherit.

---

## Per-screen analysis

### 1. `delivery-register-prompt` — Jeeber Gate (not registered / KYC pending) · **divergent**
- **flutter_target:** Extend inline `lib/features/jeeber_home/presentation/widgets/jeeber_unregistered_view.dart`
  (rendered by `DashboardTab`/`JeeberHomeScreen` State 1). Promote it to a real gate keyed off
  `user.kycStatus`, OR add a dedicated `delivery-register-prompt` route.
- **gap:** The unregistered hero + "Register now" CTA exists and routes to `jeeber-onboarding`. BUT
  the registered/unregistered switch is driven by a **debug dev-seam flag** (`_devSeamUnregistered()`),
  not by real KYC/role status (D38). Blueprint also defines this as the **KYC-pending / not-approved**
  gate that the DELIVERY tab lands on when not approved — that branch is absent. Bottom-nav + header
  wallet-chip/bell not present on this state.
- **nav_edges_missing:** `delivery-requests -> delivery-register-prompt` (KYC-not-approved gate on
  DELIVERY tab); the `Requests`/`Profile`/`DELIVERY` bottom-nav edges are shell-level (present). The
  `delivery-register-prompt -> delivery-onboarding-image-upload` edge IS wired (`onRegister →
  pushNamed('jeeber-onboarding')`).
- **mock:** `GET /user-management/users/:userId/kyc` (drive gate from real status);
  `GET /user-management/users/:userId` (availableRoles / activeRole).
- **decisions:** D38 (KYC gates Jeeber role only), D67 (term "Jeeber").
- **complexity:** M · **priority:** P0 (gate blocks the entire Jeeber journey from being real).

### 2. `delivery-onboarding-image-upload` — Photo Upload · **partial**
- **flutter_target:** `DmOnboardingScreen` step `DmOnboardingStep.photo`
  (`jeeber_onboarding/presentation/widgets/dm_onboarding_photo_step.dart`), route `/jeeber/onboarding`.
- **gap:** Photo upload + progress header + gated Continue exist and match well. Two issues:
  (a) the **back chevron on step 1** calls `Navigator.maybePop()` but the blueprint back target is
  `delivery-register-prompt`; (b) Continue advances to the **address** step but does NOT preserve the
  blueprint's alternate edge `→ kyc-identity` (the flow never reaches KYC from here — see screen 5).
- **nav_edges_missing:** `delivery-onboarding-image-upload -> kyc-identity` (the re-chain edge — flow
  must eventually reach KYC; today it dead-ends at a Fake gateway). `-> delivery-register-prompt` (back).
- **mock:** none for the photo itself (local capture); submission lands later via KYC/onboarding BFF.
- **decisions:** D67.
- **complexity:** S · **priority:** P1.

### 3. `delivery-onboarding-personal-details` — Personal Details · **divergent**
- **flutter_target:** `DmOnboardingScreen` step `DmOnboardingStep.address`
  (`dm_onboarding_address_step.dart`).
- **gap:** **D20 VIOLATION** — renders a **Vehicle number** field
  (`dm_onboarding_address_vehicle_number_field`; cubit `setVehicleNumber`; state `vehicleNumber`;
  `DmOnboardingSubmission.vehicleNumber`). Must be removed across widget + cubit + state + submission
  DTO. Name/State/Country/Street/Address fields are otherwise consistent (blueprint: Name + State /
  Country / Street / Address). Note blueprint per-screen `interactiveElements` still *lists* the
  vehicle field, but it is a stale `screenshot` artifact superseded by D20 (the inventory and
  `delivery-onboarding-personal-details` lofiOutline explicitly say "NO vehicle-number field (removed,
  D20)").
- **nav_edges_missing:** none new (back → image-upload, Continue → service-area both wired via cubit
  step transitions).
- **mock:** submission via jeeb-gateway BFF (form-builder-service `POST /v1/templates/jeeb_jeeber_v1/submit`)
  — currently a `FakeDmOnboardingGateway` no-op.
- **decisions:** D20 (remove vehicle), D67.
- **complexity:** S · **priority:** P0 (decision violation; cheap to fix).

### 4. `delivery-onboarding-service-area` — Service Area · **divergent**
- **flutter_target:** `DmOnboardingScreen` step `DmOnboardingStep.serviceArea`
  (`dm_onboarding_service_area_step.dart` + `dm_onboarding_distance_slider.dart`).
- **gap:** **D51 VIOLATION** — the step renders a **distance-preference slider**
  (`DmOnboardingDistanceSlider`, `distanceKm` 1–150) plus a location selector. D51 **removes the static
  service-area radius slider**; the screen must be reworked to a **home-base map pin only** (matching uses
  live/last-known location × tier-scaled radius; home base is fallback). Blueprint also wires
  `Select location row -> location-map-pin` and `Continue -> kyc-identity`; the Flutter step has a
  location *selector* but does not push the dedicated map-pin screen, and Continue submits to the Fake
  gateway rather than continuing to KYC.
- **nav_edges_missing:** `delivery-onboarding-service-area -> location-map-pin` (pick home base on map);
  `delivery-onboarding-service-area -> kyc-identity` (Continue chains into KYC — absent today).
- **mock:** `geolocation-service` for home-base persistence (no current screen-facing endpoint; flag for
  backenders). `POST /matching/v1/matching/find-jeebers` is the live-location consumer (D51).
- **decisions:** D51 (drop radius slider; home-base/fallback), D67.
- **complexity:** M · **priority:** P0 (decision violation + breaks the chain into KYC).

### 5. `kyc-identity` — Verify Identity · **divergent**
- **flutter_target:** `KycWizardScreen` (`/profile/kyc`), steps `KycWizardStep.id` +
  `KycWizardStep.selfie` (`kyc_id_step.dart`, `kyc_selfie_step.dart`).
- **gap:** Gov-ID front/back + selfie capture exist and match `kyc-identity`. BUT the wizard also has a
  **Vehicle step** (`KycWizardStep.vehicle`, `kyc_vehicle_step.dart`) and a **ToS step**
  (`KycWizardStep.tos`) baked into the **same** flow — the vehicle step is a **D20 violation** and must
  be removed. Bigger structural gap: this wizard is **NOT chained from onboarding** (service-area never
  routes here) and on submit it goes to its own status view rather than the blueprint's
  `onboarding-funding`. Blueprint back target is `delivery-onboarding-service-area`; Flutter back is
  intra-wizard. KYC gateway also targets non-existent mock paths (`/v1/kyc/*`).
- **nav_edges_missing:** `kyc-identity -> onboarding-funding` (submit → funding step — entirely absent);
  `delivery-onboarding-service-area -> kyc-identity` (entry — absent, see screen 4);
  `kyc-identity -> delivery-onboarding-service-area` (back).
- **mock:** `GET /form-builder-service/v1/templates/jeeb_jeeber_v1` (schema),
  `POST /form-builder-service/v1/templates/jeeb_jeeber_v1/submit` (submit),
  `POST /user-management/users/:userId/kyc-link` (attach submission). NOTE app currently calls
  `/v1/kyc/*` which the mock does not serve — contract reconciliation required.
- **decisions:** D20 (no vehicle), D52 (single review), D67.
- **complexity:** L · **priority:** P0 (chain break + D20 + mock contract mismatch).

### 6. `onboarding-funding` — Add Funds to Get Started · **missing**
- **flutter_target:** NEW route/screen (e.g. `/jeeber/onboarding/funding` or a final wizard step). No
  implementation anywhere.
- **gap:** Entire screen absent. Must explain the **fixed non-refundable starter credit usable only
  after KYC approval** (D42), the **"reserve 10% per offer"** rationale (D1), a **"Top up now" CTA →
  `wallet-charge-info`** (D92/D93 — no in-app payment), and **Continue → `kyc-pending-status`**
  (top-up allowed pre-approval, D38/D39). Note `wallet-charge-info` is itself missing (cross-domain,
  wallet domain) — this screen's CTA depends on it.
- **nav_edges_missing:** `onboarding-funding -> wallet-charge-info`; `onboarding-funding -> kyc-pending-status`;
  `kyc-identity -> onboarding-funding` (inbound).
- **mock:** `GET /wallet-service/v1/jeeb/earnings` is unrelated; **no balance/starter-credit endpoint
  exists** — flag for backenders (starter-credit grant + balance read). `wallet-charge-info` is static (no call).
- **decisions:** D28 (first-run funding step), D42 (starter credit), D1 (per-offer reserve), D38/D39
  (top-up pre-approval), D92/D93 (no in-app top-up; charge at store).
- **complexity:** M · **priority:** P0 (blueprint step in the core Jeeber onboarding journey).

### 7. `kyc-pending-status` — Pending / Result Status · **partial**
- **flutter_target:** `KycStatusView` (`kyc/presentation/kyc_status_view.dart`), reached as
  `KycWizardStep.status` inside `KycWizardScreen`.
- **gap:** Pending / Approved / Rejected bodies exist with correct copy and a resubmit CTA on rejected.
  Missing the blueprint's **outgoing links**: `→ jeeber-requests-home` on approval ("may offer"),
  `→ wallet-hub` once approved, `→ wallet-charge-info` ("how to add funds"), and the **"top-up allowed
  while pending"** note. Today approved/pending both just pop to Profile. Also it is not reached from
  `onboarding-funding` (which doesn't exist) — it is only the terminal of the standalone KYC wizard.
- **nav_edges_missing:** `kyc-pending-status -> jeeber-requests-home` (approved → feed);
  `kyc-pending-status -> wallet-hub`; `kyc-pending-status -> wallet-charge-info`;
  `kyc-pending-status -> kyc-rejected` (route rejected to the dedicated screen — see 8);
  `onboarding-funding -> kyc-pending-status` (inbound).
- **mock:** `GET /user-management/users/:userId/kyc` (poll status). App currently uses `/v1/kyc/status`.
- **decisions:** D38/D39 (top-up pre-approval note), D52, D67.
- **complexity:** M · **priority:** P1.

### 8. `kyc-rejected` — Verification Failed · **divergent**
- **flutter_target:** Currently folded into `KycStatusView` rejected branch. Blueprint wants a
  **dedicated `kyc-rejected` screen** (D87) with distinct nav. Either extract a new route or make the
  rejected status view honor the dedicated edges.
- **gap:** The rejected state renders headline + reason + a **"resubmit"** CTA. Blueprint/D52/D87 say
  **rejection is FINAL — appeal only via support**; the primary CTA must be **"Appeal via support" →
  `support-ticket`**, plus **"Back to Profile" → `customer-profile`**. The current **resubmit** CTA
  (`KycWizardCubit.resubmit`) **contradicts D52**. (Note: blueprint `kyc-pending-status` does list a
  `resubmit` edge for the pending/rejected-within-pending generic status, but the dedicated
  `kyc-rejected` screen per D52/D87 is final — reconcile: the *final* rejection screen has no resubmit.)
- **nav_edges_missing:** `kyc-rejected -> support-ticket` (appeal); `kyc-rejected -> customer-profile`
  (back). Both absent; current CTA wrongly resubmits.
- **mock:** none beyond status read; `compliment-service`/`support-ticket` is cross-domain.
- **decisions:** D52 (rejection final, manual appeal), D87 (dedicated rejection screen), D7.
- **complexity:** S · **priority:** P1.

### 9. `offer-kyc-gate` — Offering Gated, KYC Not Approved · **missing**
- **flutter_target:** NEW. No screen, and **offering is not gated by KYC at all** today — the feed
  card / request-detail "Offer" CTA pushes `jeeber-offer-submission` unconditionally.
- **gap:** Entire gate absent. When a not-yet-approved Jeeber taps "make offer", they must hit a gate:
  **"Get approved to start sending offers"**, current KYC status (pending / not started / rejected),
  **CTA → `kyc-identity`** (start/continue KYC), **"top-up still allowed"** note, and a
  **register-as-delivery link → `delivery-register-prompt`**. Back → `jeeber-requests-home`. The brief
  enumerates this screen's edges (start/continue KYC, register link, back) — none exist.
- **nav_edges_missing:** `offer-kyc-gate -> kyc-identity`; `offer-kyc-gate -> delivery-register-prompt`;
  `offer-kyc-gate -> jeeber-requests-home`; and the **inbound gate** must intercept
  `jeeber-requests-home -> offer-composer` / `delivery-requests -> offer-composer` when not approved.
- **mock:** `GET /user-management/users/:userId/kyc` (status drives the gate).
- **decisions:** D38 (KYC gates offering), D67.
- **complexity:** M · **priority:** P0 (without it, an unapproved Jeeber can submit offers — breaks the
  core gating invariant).

### 10. `offer-composer` — Structured Offer Composer · **divergent**
- **flutter_target:** `OfferSubmissionScreen` (`lib/features/offers/presentation/offer_submission_screen.dart`),
  route `/jeeber/requests/:id/offer`, driven by `OfferFormCubit`.
- **gap:** Form has price + ETA(min) + note + submit (wired to `POST /offer-service/v1/offers`, handles
  409). **Missing the entire structured-economics layer (G3):** exact **10% platform-fee line**
  (D37/D44), **"you earn (cash)" net-per-offer line** (D44), **"reserved now; charged if you win;
  released if not"** copy (D1), **ETA as a dropdown bounded by the tier SLA band** (D14 — current is a
  free integer field with `eta > 0` validation only), and the `'Your offer · ORD-…'` header. Also no
  **insufficient-balance branch** (must route to screen 11). No withdraw+re-offer affordance framing
  (D15) though the route's `onWithdrawn` (close) exists.
- **nav_edges_missing:** `offer-composer -> offer-insufficient-balance` (on shortfall — absent);
  `offer-composer -> jeeber-requests-home` (send → 10% reserved → back to feed; today it goes to
  `/chat/:conversationId` instead).
- **mock:** `POST /offer-service/v1/offers` (exists, but **add a wallet balance/reserve check** so it
  can 402 on shortfall and reserve 10% on success — currently none). Needs a
  **`wallet-service` balance + reserve** endpoint (does not exist). `GET /delivery-service/v1/tiers`
  to source the SLA band for the ETA dropdown.
- **decisions:** D1 (per-offer reserve), D14 (ETA within tier SLA band), D15 (no edit; withdraw+re-offer),
  D37 (exact 10% no rounding), D43 (affordability), D44 (net-per-offer + dashboard), D45 (fee framing),
  D18 (ETA absolute deadline), D54 (order-value cap validation).
- **complexity:** L · **priority:** P0 (the economic heart of the Jeeber side; G3).

### 11. `offer-insufficient-balance` — Insufficient Balance to Offer · **missing**
- **flutter_target:** NEW — a sheet/inline block on top of `OfferSubmissionScreen`. No implementation;
  the cubit has no shortfall path.
- **gap:** Entire flow absent. Needs inline **"Not enough — top up to bid"** + shortfall sheet
  (amount needed vs available), **"Top up" CTA → `wallet-charge-info`** (D92/D93, NOT an in-app top-up
  screen), **draft preserved + auto-sent after the store charge lands**, and **Cancel / keep editing →
  back to composer**. Depends on the offer-service returning a 402-style insufficient-balance problem
  and a wallet balance source — both missing in the mock.
- **nav_edges_missing:** `offer-insufficient-balance -> wallet-charge-info`;
  `offer-insufficient-balance -> offer-composer` (cancel/keep editing);
  `offer-composer -> offer-insufficient-balance` (inbound).
- **mock:** `offer-service` must return insufficient-balance (e.g. 402 problem+json) when balance <
  10% of price; `wallet-service` balance read. Both to be added (flag for backenders).
- **decisions:** D43 (affordability state), D92/D93 (charge at store, no in-app top-up), D1.
- **complexity:** M · **priority:** P1.

### 12. `jeeber-pending-offers` — Pending Response · **missing**
- **flutter_target:** NEW screen, OR the **"Pending Response" sub-tab** of the Jeeber feed
  (`jeeber_home`/`jeeber_request_feed`). The feed has tab *labels* Requests / Pending Response / Replies
  (`OmdsFilterChips` in `jeeber_feed_tab_view.dart`) but **no submitted-offers list** behind Pending
  Response, and no per-row withdraw.
- **gap:** No list of the Jeeber's submitted offers awaiting customer decision; no per-row price + ETA +
  "Awaiting customer decision"; no per-row **Withdraw** (D15). Back → `delivery-requests`.
- **nav_edges_missing:** `delivery-requests -> jeeber-pending-offers` (open Pending Response tab);
  `jeeber-pending-offers -> delivery-requests` (back).
- **mock:** `GET /offer-service/v1/offers?jeeberId=` (list my offers);
  `DELETE /offer-service/v1/offers/:offerId` (withdraw, 204; 410 if finalized) — both exist.
- **decisions:** D15 (withdraw, no edit), D67.
- **complexity:** M · **priority:** P1.

### 13. `jeeber-requests-home` — Delivery Feed · **partial**
- **flutter_target:** `JeeberHomeScreen` State 3 + `JeeberFeedTabView`
  (`jeeber_home/presentation/...`), surfaced by `DashboardTab` (the jeeber Dashboard tab). Note the
  blueprint's "Requests" bottom-nav label maps to the **client** Requests home; the Jeeber feed is the
  Dashboard tab.
- **gap:** Search bar + Requests/Pending Response/Replies tab strip + incoming request rows + open-chat
  exist. Gaps: (a) the **"make an offer" edge goes through `jeeber-request-detail` then
  `jeeber-offer-submission`**, which is fine, but the blueprint also wires a direct
  `jeeber-requests-home -> offer-composer` — and that path is **not KYC-gated** (see screen 9);
  (b) **Pending Response / Replies tabs have no real backing data** (see screen 12);
  (c) status chips (Order picked / Heading to drop off) and `→ order-chat`/`delivery-order-chat`
  open edges are cross-domain (delivery/chat) and only partially wired.
- **nav_edges_missing:** `jeeber-requests-home -> offer-composer` should pass through `offer-kyc-gate`
  when unapproved; `jeeber-requests-home` Pending Response/Replies data wiring (screen 12).
- **mock:** `GET /delivery-service/v1/requests?status=...` (feed), `GET /offer-service/v1/offers?jeeberId=`
  (replies/pending), `POST /geolocation-service/v1/availability` (online toggle) — all exist.
- **decisions:** D38 (gate offering), D67.
- **complexity:** M · **priority:** P1.

### 14. `delivery-requests` — DELIVERY Tab · **partial**
- **flutter_target:** `DashboardTab` → `JeeberHomeScreen` (the jeeber-side landing). The DELIVERY tab is
  a **shell tab**, not a route; it currently always mounts the registered feed (or the dev-seam
  unregistered view).
- **gap:** The blueprint's defining behavior — **branch on KYC status**: open
  `delivery-register-prompt` when **not registered or KYC not approved**, else `jeeber-requests-home`
  — is **not implemented off real status** (only the debug dev-seam flag flips it, screen 1). Also the
  blueprint header **wallet chip + notification bell** (→ `wallet-hub` / `notifications-list`) are
  absent on this tab (cross-domain: wallet is a stub `/wallet`; notifications-list has no route).
  "Accept orders" availability toggle exists (`AvailabilityToggle`).
- **nav_edges_missing:** `delivery-requests -> delivery-register-prompt` (KYC-not-approved branch);
  `delivery-requests -> earnings-fees-dashboard` (present via Earnings tab); `delivery-requests ->
  wallet-hub` (header chip); `delivery-requests -> notifications-list` (header bell).
- **mock:** `GET /user-management/users/:userId/kyc` (branch), `GET /delivery-service/v1/requests`
  (feed when approved).
- **decisions:** D38 (gate), D67.
- **complexity:** M · **priority:** P0 (the real KYC branch is the spine of the Jeeber entry).

---

## Summary table

| # | blueprint_id | status | priority | complexity | crux |
|---|--------------|--------|----------|-----------|------|
| 1 | delivery-register-prompt | divergent | P0 | M | gate driven by debug flag, not real KYC |
| 2 | delivery-onboarding-image-upload | partial | P1 | S | back target + KYC re-chain edge |
| 3 | delivery-onboarding-personal-details | divergent | P0 | S | D20 vehicle field present |
| 4 | delivery-onboarding-service-area | divergent | P0 | M | D51 radius slider present; no map-pin / KYC chain |
| 5 | kyc-identity | divergent | P0 | L | D20 vehicle step; unchained; mock path mismatch |
| 6 | onboarding-funding | missing | P0 | M | whole funding step absent |
| 7 | kyc-pending-status | partial | P1 | M | missing approved→feed / wallet edges |
| 8 | kyc-rejected | divergent | P1 | S | resubmit CTA violates D52 (should be appeal) |
| 9 | offer-kyc-gate | missing | P0 | M | offering not KYC-gated |
| 10 | offer-composer | divergent | P0 | L | no 10% fee / net / reserve / SLA-band ETA (G3) |
| 11 | offer-insufficient-balance | missing | P1 | M | no shortfall path (UI + mock) |
| 12 | jeeber-pending-offers | missing | P1 | M | no submitted-offers list / withdraw |
| 13 | jeeber-requests-home | partial | P1 | M | tabs unbacked; offer path ungated |
| 14 | delivery-requests | partial | P0 | M | KYC branch not real |

## Cross-domain dependencies to flag
- **wallet-charge-info** (wallet domain) is the CTA target for `onboarding-funding` and
  `offer-insufficient-balance` — both blocked until it exists.
- **wallet balance + per-offer reserve** (mock) backs `offer-composer`, `offer-insufficient-balance`,
  `onboarding-funding` — entirely absent in `wallet-service`.
- **notifications-list** + **wallet-hub** header chips on `delivery-requests` are cross-domain stubs.
- **support-ticket** is the appeal target for `kyc-rejected`.
- KYC mock contract (`/v1/kyc/*` app paths vs `form-builder-service`/`user-management` mock routes)
  needs reconciliation by foundation/backenders.
