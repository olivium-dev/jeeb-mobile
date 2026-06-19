# Blueprint Inventory — 62 Screens (Phase 1)

> Source of truth: `jeeb-mind-map/web/blueprint.json` (62 screens, 188 outgoing edges
> stored on screens / 182 in the de-duplicated `edges` array per `coverage.edgeCount`).
> Per-screen contracts: `jeeb-mind-map/web/src/screens/_data/<id>.json` (identical
> `lofiOutline`/`doc`/`outgoing` to the blueprint screen entries — no extra detail).
> Authored Phase 1 (CTO brief §9). Do not invent product decisions — cite by `Dnn`.

## How to read this
- **id** = canonical screen id used by `app_router.dart` route names and Maestro identifiers.
- **role** = `customer` | `auth` | `jeeber` | `shared` (the blueprint's `role` field).
- **outgoing** = every edge `to` (target id) + `trigger` (verbatim trigger label).
- **key elements** = 2–5 representative UI elements from the screen `lofiOutline`.
- `doc.decisions` cited where the blueprint attaches them (`Dnn`).

## Counts (verified)
- Total: **62** screens · **188** outgoing edges (on screens).
- By role: **jeeber 22 · shared 17 · customer 15 · auth 8** (matches CTO brief §4).
- `source` per `_index.json`: 23 `screenshot` (have Figma PNGs), 39 `lofi` (low-fi outline only).
- Note: `_index.json` also lists `topup-amount / topup-payment-method / topup-processing /
  topup-success / topup-failed` — these are **NOT** part of the canonical 62. Top-up was
  replaced by `wallet-charge-info` (no in-app payment, **D41/D92/D93**). Excluded here.

---

## CUSTOMER (15)

### customer-orders-home — Requests Tab (home)
- Key: persistent header (wallet chip → wallet-hub, bell → notifications-list); sub-tabs In Progress / Pending Requests / Replies; order rows (e.g. ORD-234700); New Order FAB (+); bottom nav Requests/DELIVERY/Profile.
- Outgoing: request-type-selection (tap New Order) · customer-orders-home (open Pending sub-tab) · my-orders (open Replies sub-tab) · waiting-no-coverage (open a pending request thread) · wallet-hub (header wallet chip) · notifications-list (header bell) · delivery-requests (DELIVERY tab) · customer-profile (Profile tab) · order-chat (open order thread) · order-tracking (Track my order).

### request-type-selection — New Order — Tier Choice
- Key: tier radios Flash / Express / Standard / On-the-Way / Eco (forced explicit choice); "Change Location >" row; Start order / Continue.
- Outgoing: location-select (select a tier) · customer-orders-home (back) · order-chat (Start order after selecting a tier).

### order-chat — 1:1 Chat (pinned price) / Compose Request
- Key: pinned order-summary strip (ref, accepted price locked, ETA, tier); chat thread + system rows; state variants compose/offers/approved/milestone; composer (text + attach + mic + send); View tracking / View summary links.
- Outgoing: waiting-no-coverage (send request — broadcast) · order-tracking (view tracking) · dispute-open-evidence (open dispute) · jeeber-mark-delivered (advance milestones) · my-orders (back to orders) · order-summary-pinned (view summary) · customer-orders-home (back to home).

### waiting-no-coverage — Waiting State / No Coverage
- Key: "Waiting for offers / N notified + countdown" state; widen/change-tier reuse; cancel (free pre-accept); offers-arrived path.
- Outgoing: my-orders (offers arrive live) · order-chat (widen/change tier — no_coverage) · request-type-selection (re-target change tier, D48) · offer-review-list (offers arrived → review) · cancel-request-confirm (cancel pre-accept, free).

### my-orders — Replies (offer cards)
- Key: search bar; sub-tabs (Replies selected); offer cards (ORD ref, tier, offers badge); "Check Offers" per card; bottom nav.
- Outgoing: offer-accept-confirm (tap Accept on offer card) · customer-orders-home (Requests tab) · delivery-requests (DELIVERY tab) · customer-profile (Profile tab) · order-chat (order row → chat).

### offer-review-list — Offer Review (Customer)
- Key: "Offers for ORD-… (N)" header; one card per Jeeber (blind to competitors); name/rating/price/ETA/note; sort by price/ETA/rating; per-card Accept; "accept only one" helper.
- Outgoing: offer-accept-confirm (Accept offer button) · jeeber-profile-reviews (tap Jeeber name/avatar) · my-orders (back/close) · cancel-request-confirm (cancel request pre-accept, free).

### offer-accept-confirm — Accept Offer Confirmation
- Key: "Accept X's offer?" sheet; "Pay $N cash on delivery" line; "Other offers will close" warning; Cancel; Confirm (capture + close losers).
- Outgoing: order-chat (confirm acceptance — fee captured, losers released) · offer-review-list (cancel acceptance / dismiss).

### cancel-request-confirm — Cancel Request?
- Key: "Cancel this request?" sheet; consequence copy (free before accept, nothing charged, D69); Keep request; Cancel request (confirm).
- Outgoing: customer-orders-home (confirm cancellation — request removed). · Decisions: D69.

### order-summary-pinned — Order Summary + Pinned Price
- Key: pinned authoritative accepted price; Jeeber name + rating; ETA; tier + item summary; "Pay cash on delivery" reminder.
- Outgoing: order-chat (Open chat with Jeeber) · order-tracking (Track delivery).

### order-tracking — Track / Order Status Stepper
- Key: pinned order-summary header (price/Jeeber/locked ETA); stepper Ordered → Picked → In Transit → Delivered (D70); dispute link; no-show action sheet (reassign / re-broadcast, D88); auto-advance on delivered.
- Outgoing: delivered-receipt-confirm (Jeeber marked delivered) · dispute-open-evidence (open dispute) · my-orders (back/details) · offer-review-list (no-show reassign) · waiting-no-coverage (no-show re-broadcast, same order id) · order-chat (open thread/back to chat). · Decisions: D70, D11, D18, D71, D88.

### delivered-receipt-confirm — Confirm Receipt (Customer)
- Key: push prompt "Did you receive your order?"; "Pay $N cash to <Jeeber>"; proof-of-delivery photo (D3); Not yet; Confirm ✓; auto-complete on timeout.
- Outgoing: rate-jeeber (confirm receipt / auto-complete — completed) · dispute-open-evidence (Not yet). · Decisions: D3, D11.

### rate-jeeber — Rate Jeeber (Mandatory)
- Key: star selector (mandatory); optional immutable review (first-name shown, hidden until 5); order context; Submit (completion-gated, no dismiss).
- Outgoing: customer-orders-home (submit mandatory rating — order closed).

### customer-profile — Profile Tab
- Key: header avatar + name + per-role rating + wallet chip + bell; rows Register as delivery / Saved addresses / Password & security / Notification prefs / Language / Contact us / Rate app / Logout-Delete; bottom nav.
- Outgoing: delivery-onboarding-image-upload (Register as delivery) · password-security · notification-prefs · language-settings · support-ticket (Contact us) · rate-the-app · logout-delete-account · wallet-hub (Wallet row) · wallet-hub (header chip) · notifications-list (header bell) · customer-orders-home (back/Requests tab) · delivery-requests (DELIVERY tab) · saved-addresses (Saved addresses).

### saved-addresses — Saved Addresses Manager
- Key: "Addresses" title; list with labels; per-entry edit/delete; "+ Add new address"; default indicator.
- Outgoing: address-detail-form (edit / + add new address) · customer-profile (back).

### address-detail-form — Address Detail Form
- Key: map pin/preview; label, building, floor/apt fields; delivery notes; phone (COD coordination); Save address.
- Outgoing: saved-addresses (Save address button).

---

## AUTH (8)

### login — Login
- Key: brand mark; Email + Password (masked) + eye toggle; Continue → home; Forgot password?; social buttons FB/Google/Apple; Sign up link.
- Outgoing: recover-password (forgot password) · sign-up (Sign up link) · social-login (Login with FB/Google/Apple) · customer-orders-home (submit credentials — returning user). · Decisions: D22, D23, D65.

### sign-up — Sign Up
- Key: "Create account"; Name / Email / Password (masked) + eye toggle; strength hint; Sign up → phone OTP (phone required, G8); social buttons; "Already have an account? Login"; email not verified (D21).
- Outgoing: phone-otp-verification (submit Name/Email/Password — phone required) · social-collision-prompt (email/social collision) · login (Login link). · Decisions: D8, D21, D22, D65.

### phone-otp-verification — Phone OTP Verification
- Key: phone entry/confirm; multi-digit OTP input; Resend + countdown; Verify; wrong/expired error; phone is account anchor.
- Outgoing: customer-orders-home (OTP verified — account active) · login (back).
- (Role in blueprint: `shared`.)

### social-login — Social Login (FB/Google/Apple)
- Key: native OAuth provider flow (no in-app screen body in outline).
- Outgoing: phone-otp-verification (authenticate via social — phone still required) · social-collision-prompt (2nd method on registered email) · login (back).

### social-collision-prompt — Email/Social Collision Prompt
- Key: collision warning (inline error on sign-up / link-accounts prompt; empty outline).
- Outgoing: login (link accounts / continue) · sign-up (use a different email).

### recover-password — Password Recovery (Request Code)
- Key: "Recover Password"; Email field; Recover → verify-code (code emailed); Sign up link; Back to sign in.
- Outgoing: verify-code (submit email — code emailed) · sign-up (Sign up link) · login (back to sign in).

### verify-code — Verify Recovery Code
- Key: "Verify Code"; multi-digit code input; wrong/expired error; Resend link; Verify → set password.
- Outgoing: auth-set-password (code verified) · recover-password (back).

### auth-set-password — Set Password
- Key: "Set Password"; new password field + eye toggle; re-type field + eye toggle; mismatch/strength validation; Set password → Login (recovery) or Profile (in-app social, D90).
- Outgoing: login (new password set) · customer-profile (password set in-app social user → Profile). · Decisions: D90.

---

## JEEBER (22)

### delivery-requests — DELIVERY Tab
- Key: "DELIVERY" title + wallet chip + bell; "Accept orders" availability toggle; sub-tabs Requests / Pending Response / Replies; per-row Ignore | Offer; empty-state variant; bottom nav.
- Outgoing: delivery-register-prompt (open DELIVERY while not registered / KYC not approved) · jeeber-requests-home (open DELIVERY when KYC-approved) · earnings-fees-dashboard (open dashboard) · wallet-hub (header chip) · notifications-list (header bell) · customer-profile (Profile tab) · offer-composer (make-offer) · delivery-order-chat (open accepted reply / active delivery) · jeeber-pending-offers (open Pending Response tab).

### delivery-register-prompt — Jeeber Gate (not registered / KYC pending)
- Key: "DELIVERY" title; illustration; "You are not registered as a delivery person"; benefits copy; Register now; bottom nav.
- Outgoing: delivery-onboarding-image-upload (Register as delivery) · customer-orders-home (Requests tab) · customer-profile (Profile tab) · delivery-requests (DELIVERY tab).

### delivery-onboarding-image-upload — Register as Delivery — Photo Upload
- Key: back chevron; step indicator; profile photo upload (+/camera); "Upload a clear photo"; Continue (gated on photo).
- Outgoing: delivery-register-prompt (back chevron) · delivery-onboarding-personal-details (Continue — re-chain) · kyc-identity (continue to identity verification).

### delivery-onboarding-personal-details — Register as Delivery — Personal Details
- Key: "Register as Jeeber" (D67); name fields; address State/Country/Street/Address; NO vehicle-number field (removed, D20); Back / Continue.
- Outgoing: delivery-onboarding-image-upload (back) · delivery-onboarding-service-area (Continue). · Decisions: D67, D20.

### delivery-onboarding-service-area — Register as Delivery — Service Area
- Key: "Set your home base" (required); map / home-base pin; note matching uses live location, home base is fallback (D51); Continue (gated on pin).
- Outgoing: delivery-onboarding-personal-details (back) · location-map-pin (Select location row) · kyc-identity (Continue). · Decisions: D51.

### kyc-identity — KYC — Verify Identity
- Key: "Verify identity" step; Gov ID front + back upload; selfie capture; Submit for review; note single final manual review, cannot offer until approved.
- Outgoing: delivery-onboarding-service-area (back) · onboarding-funding (submit Gov ID + selfie → funding step).

### onboarding-funding — Add Funds to Get Started
- Key: starter-credit explainer (fixed promo credit, non-refundable, usable after KYC, D42); "you reserve 10% per offer" (D1); Top up now CTA; Continue → KYC pending; top-up allowed pre-approval (D38/D39).
- Outgoing: wallet-charge-info (how to add funds — charge at a store) · kyc-pending-status (continue to pending). · Decisions: D28, D42, D38, D39, D1.

### kyc-pending-status — KYC — Pending / Result Status
- Key: status Pending / Approved / Rejected; per-state copy; rejected → reason + resubmit; top-up allowed while pending; link to wallet/feed once approved.
- Outgoing: jeeber-requests-home (manual review approved — may offer) · kyc-identity (resubmit KYC docs) · wallet-hub (link to wallet once approved) · kyc-rejected (review rejected) · wallet-charge-info (how to add funds).

### kyc-rejected — KYC — Verification Failed
- Key: "Verification failed" + back; error icon; "We couldn't verify your identity"; reason line; review final, appeal only via support (D52); Appeal via support; Back to Profile.
- Outgoing: support-ticket (appeal via support) · customer-profile (back to Profile). · Decisions: D7, D52, D87.

### offer-kyc-gate — Offering Gated — KYC Not Approved
- Key: "Get approved to start sending offers"; current KYC status; start/continue KYC CTA; top-up still allowed pre-approval; register-as-delivery link.
- Outgoing: kyc-identity (CTA start/continue KYC) · delivery-register-prompt (register as delivery link) · jeeber-requests-home (back).

### jeeber-requests-home — Delivery Feed
- Key: search; tabs Requests / Pending Response / Replies; request rows (e.g. Sami Fawaz); status chips (Order picked / Heading to drop off); bottom nav.
- Outgoing: customer-profile (Profile tab) · customer-orders-home (Requests tab) · delivery-order-chat (open delivery chat) · delivery-requests (DELIVERY tab) · offer-composer (make an offer) · order-chat (open accepted order chat).

### offer-composer — Structured Offer Composer
- Key: "Your offer · ORD-…" header; Price input ($); ETA dropdown (within tier SLA band, D14); optional Note; Platform fee (exact 10%, no rounding); "You earn (cash)" net line; "reserved now / charged if win / released if not"; Send offer; no in-place edit (withdraw+re-offer, D15).
- Outgoing: jeeber-requests-home (send one offer — 10% reserved) · offer-insufficient-balance (send with insufficient balance). · Decisions: D1, D15, D44, D37, D43, D18, D54, D45.

### offer-insufficient-balance — Insufficient Balance to Offer
- Key: inline "Not enough — top up to bid"; shortfall sheet; amount needed vs available; Top up CTA; draft preserved + auto-sent after top-up; Cancel / keep editing.
- Outgoing: wallet-charge-info (how to add funds — charge at a store) · offer-composer (Cancel / keep editing).

### jeeber-pending-offers — Pending Response
- Key: list of submitted offers awaiting customer; per-row price + ETA + "Awaiting customer decision"; per-row Withdraw (D15); back.
- Outgoing: delivery-requests (back). · Decisions: D15, D50.

### delivery-order-chat — Delivery Chat with Customer
- Key: back arrow + customer name/avatar; chat thread; pinned order-context strip; milestone action button (heading off / picked / drop off → jeeber-mark-delivered); composer (text/PRICE\TIME + attach + mic + send).
- Outgoing: delivery-requests (header back arrow) · jeeber-mark-delivered (advance order / send milestone action).

### jeeber-mark-delivered — Fulfilment Milestones / Mark Delivered
- Key: imperative milestones (D70): Confirm heading off → Mark picked up → Heading to drop off → Mark delivered + proof photo (D3); on completion → rate customer; back/cancel → delivery chat.
- Outgoing: feedback-rate-delivery (marked delivered then completion reached) · delivery-order-chat (back / cancel to delivery chat). · Decisions: D70, D3.

### feedback-rate-delivery — Rate Customer
- Key: Jeeber rates customer (per-role rating, D6); star rating (mandatory, D56); optional written feedback; unrated auto-close after N days; Submit → delivery requests; NO skip.
- Outgoing: delivery-requests (submit mandatory rating). · Decisions: D6, D56.

### earnings-fees-dashboard — Earnings & Fees Dashboard
- Key: "Earnings & fees" title; total cash earned (net, off-wallet COD); total platform fees paid (captured 10%); net-per-offer running totals; delivery stats (count/rating/member-since); period breakdown.
- Outgoing: wallet-hub (back to wallet) · wallet-activity-list (view full activity).

### wallet-hub — Wallet Hub
- Key: available balance; gift-credit badge (usable after KYC); affordability state card (not a capacity number, D43); reserved-now line (sum of live reserves); "+ Top up"; Earnings & fees row; "How fees work" explainer; activity list (typed rows); See all activity; state variants healthy/low/empty/all-reserved; KYC-pending banner.
- Outgoing: wallet-charge-info (how to add funds) · offer-kyc-gate (KYC status / approval) · earnings-fees-dashboard (Earnings & fees) · wallet-activity-list (See all activity). · Decisions: D1, D41, D37, D43, D44, D33.

### wallet-charge-info — How to Add Funds
- Key: no in-app payment — charge wallet at authorized store; steps (visit store, give phone/ID, pay cash → store credits); auto balance update; 10% fees deducted from pre-charged balance (D1/D41); back to wallet.
- Outgoing: wallet-hub (back to wallet). · Decisions: D41, D1. (Replaces in-app top-up — Q18/Q19.)

### wallet-activity-list — All Wallet Activity
- Key: "Activity" title; full ledger (infinite scroll + skeletons); typed rows Reserve / Fee(won) / Released / Refund / Penalty / Top up / Gift; per-row amount/sign/icon/order ref; tap row → transaction detail.
- Outgoing: transaction-detail (open transaction detail) · wallet-hub (back to Wallet hub).

### transaction-detail — Transaction Detail
- Key: type title; per-type explainer; variants Reserve / Fee(won, exact 10% + pinned price) / Released(+reason) / Refund-Penalty(+dispute link) / Top up / Gift; amount/date/status; link to related order.
- Outgoing: dispute-open-evidence (link to related dispute) · wallet-activity-list (back) · order-summary-pinned (related order summary).

---

## SHARED (17)

### splash — Splash
- Key: full-screen brand logo; loading indicator; auto-routes after session check (first launch → walkthrough; logged-out → login; biometric → biometric-unlock; customer → home; jeeber → delivery; suspended → account-status); no interactive elements.
- Outgoing: walkthrough (first launch, not logged in) · customer-orders-home (logged-in customer → Requests) · delivery-requests (logged-in jeeber → DELIVERY) · login (logged-out returning user) · biometric-unlock (returning logged-in + biometric enabled) · account-status (suspended/locked user). · Decisions: D79, D75, D23, D85.

### walkthrough — Walkthrough
- Key: 3 swipeable onboarding slides (placeholder art, G14); page-indicator dots; Next arrow; Skip (first-launch only) → sign-up; last slide Get started → sign-up.
- Outgoing: sign-up (finish or Skip walkthrough). · Decisions: D79.

### biometric-unlock — Biometric Unlock
- Key: Face/Touch ID prompt; Unlock; "Use password instead" link; returning users skip OTP (D23).
- Outgoing: customer-orders-home (unlock success) · login (use password instead / unlock failed). · Decisions: D23, D8, D79.
- (Role in blueprint: `auth`.)

### account-status — Account Status (Suspended/Locked)
- Key: suspended/locked banner (D5); reason copy; Contact support (D76); Sign out; no tab access while suspended.
- Outgoing: support-ticket (contact support) · logout-delete-account (sign out). · Decisions: D5, D76.

### notifications-list — Notifications
- Key: "Notifications" title; rows (new offer, offer accepted, status changes, low balance, fee charged/released, refund/penalty, top-up result); per-item icon/text/timestamp/deep-link; tier-modulated urgency; empty state; inline confirm-receipt action.
- Outgoing: delivered-receipt-confirm (inline confirm-receipt) · wallet-hub (wallet rows deep-link) · my-orders (offers push → Replies) · order-chat (dispute / offer-accepted push → thread) · customer-orders-home (marketing push → home) · jeeber-requests-home (KYC approved push → feed) · kyc-rejected (KYC rejected push) · waiting-no-coverage (request expired push → re-target). · Decisions: D84 (deep-link targets).

### notification-prefs — Notification Preferences
- Key: "Notifications" title; per-category toggles (offers/status/wallet); transactional category locked (cannot turn off); wallet category toggle (D64); push-only note (no email/SMS, R2).
- Outgoing: customer-profile (back nav). · Decisions: D64.

### language-settings — Language Settings (EN/AR)
- Key: "Language" title; English option; العربية / Arabic option (triggers RTL mirror); current-selection indicator; Apply/confirm.
- Outgoing: customer-profile (Apply / back). · (RTL per D10/D66, cross-cutting.)

### password-security — Password & Security
- Key: "Password & security" title; change/set password fields (current/new/confirm); set-password entry for social-only accounts; Save; validation.
- Outgoing: auth-set-password (Set a password — social-only account) · customer-profile (back nav / save confirm).

### logout-delete-account — Logout / Delete Account Confirm
- Key: Logout with confirm; Delete account; delete confirmation dialog (status→deleted); irreversibility / role-suspension warning copy.
- Outgoing: splash (confirm logout / account deletion).

### support-ticket — Contact Us / Support Ticket
- Key: "Contact us" title; subject/category selector; message body; attach evidence/screenshot; link to related order/dispute; Submit; list of existing tickets/statuses.
- Outgoing: dispute-open-evidence (ticket tied to a dispute) · customer-profile (submit ticket confirmation). · Decisions: D76.

### dispute-open-evidence — Dispute (open + evidence)
- Key: free photo/voice evidence; auto-attached chat + GPS/status timeline (D53); ledger fee_refund/penalty on resolution; linked to Contact-us ticket; all disputes manual in v1 (empty visual outline).
- Outgoing: support-ticket (Link to Contact-us ticket) · order-chat (back to order) · dispute-status (submit evidence → track dispute status). · Decisions: D19, D53, D2, D54, D76.

### dispute-status — Dispute Status
- Key: status Open / Resolved; outcome note (refund or penalty, D2); auto-attached evidence summary (chat, GPS/timeline, D53); link to support ticket (D76); back to order thread.
- Outgoing: support-ticket (escalate / contact support) · order-chat (back to order). · Decisions: D2, D19, D53, D76.

### jeeber-profile-reviews — Jeeber Profile with Reviews
- Key: sheet header name + avatar + per-role star rating; Close (X) → offer-review-list; summary stats (deliveries/avg rating/member since); recent reviews (first name, stars, snippet) with Helpful/Reply; View all → reviews-list.
- Outgoing: offer-review-list (Close X) · reviews-list (tap View all).

### reviews-list — All Reviews
- Key: full reviews list (infinite scroll + skeletons, D73); reviewer first name/initial (D58); cold-start hide score until N≥5 + New badge (D59); report a review (D27); back to profile.
- Outgoing: jeeber-profile-reviews (back to profile). · Decisions: D27, D57, D58, D59, D73.

### location-select — Set Location
- Key: "Set delivery location" + back; Current Location (radio); Saved addresses entry; New Location (+) → pin map; Confirm → order flow.
- Outgoing: order-chat (confirm delivery location — pin/current/saved) · request-type-selection (back) · location-map-pin (new location pin-on-map) · saved-addresses (pick a saved address / manage).

### location-map-pin — Pin Location on Map
- Key: back arrow; full-screen map with draggable/tappable centre pin; current-location detection / address preview; "Pin Location" confirm button.
- Outgoing: location-select (back / Pin Location confirm).

### rate-the-app — Rate the App
- Key: app-store rating prompt (likely native OS sheet; empty in-app outline).
- Outgoing: customer-profile (submit / dismiss).

---

## Cross-cutting blueprint metadata (for nav planning)
- **mergeDecisions:** keep `my-orders` ≠ `customer-orders-home` (D82); keep `order-chat` ≠ `delivery-order-chat` (D83).
- **notificationDeepLinks (D84):** offers→my-orders · order_status→order-tracking · wallet→wallet-hub · dispute→order-chat · offer_accepted→order-chat · marketing→customer-orders-home · kyc_approved→jeeber-requests-home · kyc_rejected→kyc-rejected · request_expired→waiting-no-coverage.
- **Open questions (blueprint):** several screens flagged as native flows (social-login, social-collision-prompt, rate-the-app), inline sub-flows, or empty low-fi (waiting-no-coverage, dispute-open-evidence) — confirm during nav/backlog, do not invent.
