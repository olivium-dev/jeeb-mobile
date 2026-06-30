import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The session/journey state a `jeeb.seam.session` extra seeds before the
/// GoRouter first-run redirect fires (62_SEAM_HARNESS.md). Strongly typed so
/// the bootstrap switch is exhaustive and the contract is greppable; designed
/// to extend cleanly to future role/kycStatus permutations (just add a value
/// + a seed branch in [SessionSeamBootstrap]).
///
/// Each value maps to a concrete (onboarding flag, auth token, role, biometric
/// lock, account-status) tuple — see [SessionSeamBootstrap] and the contract
/// doc. [none] is the inert default (no session seeding; first launch shows the
/// walkthrough).
enum SessionSeed {
  /// No session seeding — first launch (walkthrough). The inert default.
  none,

  /// Onboarding done + valid token + role customer → Requests shell.
  customerLoggedIn('customer_logged_in'),

  /// Onboarding done + valid token + role jeeber → Delivery tab.
  jeeberLoggedIn('jeeber_logged_in'),

  /// Onboarding done + NO token → `/login`.
  loggedOutReturning('logged_out_returning'),

  /// Onboarding done + valid token + biometric enrolled & LOCKED → `/lock`.
  biometricEnrolled('biometric_enrolled'),

  /// Onboarding done + biometric enrolled but NO token (shows the biometric
  /// affordance on `/login`).
  biometricEnrolledLoggedOut('biometric_enrolled_logged_out'),

  /// Onboarding done + valid token + account-status blocked → `/account-status`.
  suspended('suspended'),

  /// Onboarding done + REAL gateway JWT (from intent extra
  /// `jeeb.seam.super_login_token`) written into [AuthTokenStore] → live
  /// gateway session for QA against /v1/* without OTP.
  ///
  /// GUARD: this case is only reachable in debug builds (the switch is inside
  /// a `kDebugMode`-gated path). The token is never baked into the binary; it
  /// is supplied at launch time via `adb am start -e` and is ephemerally stored
  /// in the Keystore-backed [AuthTokenStore] for the duration of the QA session.
  superLoginPlus('super_login_plus');

  const SessionSeed([this.wireValue = '']);

  /// The string a Maestro flow passes via `jeeb.seam.session`.
  final String wireValue;

  /// Parses the wire value into a [SessionSeed]; unknown/empty → [none] so a
  /// typo never crashes startup (it simply seeds nothing → walkthrough).
  static SessionSeed fromWire(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return SessionSeed.none;
    for (final seed in SessionSeed.values) {
      if (seed.wireValue == v) return seed;
    }
    return SessionSeed.none;
  }
}

/// The mid-journey state a `jeeb.seam.journey` extra seeds on top of a
/// `jeeb.seam.session` base seed (63_W1_TEST_PLAN §4). Each value (a) makes the
/// mock hold deterministic request/offer/delivery/conversation rows for
/// `user-client-001` (or `user-jeeber-002`) under the stable ids in 63 §4.3
/// — via `POST /__mock/seed/journey` — and (b) pins the deep route the router
/// should land on so the flow starts on the right screen.
///
/// Layered on the session seed, so a flow always passes BOTH
/// `jeeb.seam.session=customer_logged_in` (or `jeeber_logged_in`) AND
/// `jeeb.seam.journey=<value>`. [none] is the inert default (no journey
/// seeding). Designed to extend cleanly — add a value + a mock seed branch
/// (`journey-seed.ts`) + a route mapping below.
enum JourneySeed {
  /// No journey seeding — the session seed alone decides the landing.
  none('', ''),

  /// 1 pending request (notified_count>0) for user-client-001. Backs the
  /// home pending row (JM-023) + the waiting screen (JM-026). Pins
  /// `/requests/req-client-001-pending/waiting` so JM-026 starts on waiting.
  pendingRequest('pending_request', '/requests/req-client-001-pending/waiting'),

  /// 1 pending request with 0 nearby jeebers (no-coverage variant, JM-026 AC1b).
  pendingRequestNoCoverage(
    'pending_request_no_coverage',
    '/requests/req-client-001-pending/waiting',
  ),

  /// 1 offers-received request with >=2 offers (JM-026 AC2, JM-027, JM-028,
  /// JM-029). No route pin — the flows navigate from the Requests/Replies tab,
  /// so the app lands on the shell home.
  offersReceived('offers_received', ''),

  /// 1 accepted request + winning offer + 1:1 conversation + delivery
  /// (JM-025, JM-029, JM-031). Pins the order chat so the pinned summary shows.
  orderAccepted('order_accepted', '/chat/conv-journey-accepted'),

  /// 1 in-transit delivery (JM-025, JM-032). Pins the tracking screen.
  activeDelivery('active_delivery', '/orders/del-client-001-active/tracking'),

  /// 1 AtDoor delivery with a proof photo (JM-032 AC2, JM-033, JM-034). Pins
  /// the delivered-receipt-confirm screen so it shows on first frame.
  deliveryMarkedDone(
    'delivery_marked_done',
    '/orders/del-client-001-delivered/receipt',
  ),

  /// 1 delivered delivery for user-jeeber-002 awaiting the jeeber rating
  /// (JM-034 AC3). Pins the jeeber-mode mutual-rate screen.
  jeeberRatingPending(
    'jeeber_rating_pending',
    '/orders/del-jeeber-002-delivered/mutual-rate?mode=jeeber',
  ),

  /// >=1 saved address with a default for user-client-001 (JM-049). No route
  /// pin — the flow navigates from the profile/location-select.
  hasSavedAddresses('has_saved_addresses', ''),

  // ── Wave 2 jeeber journeys (65_W2_TEST_PLAN §3.3) ─────────────────────────
  // Layered on `jeeb.seam.session=jeeber_logged_in`. Each seeds mock-side rows
  // for user-jeeber-002 via `POST /__mock/seed/journey` (backend `seedJourney`)
  // and, for the deep-landing journeys, pins the route the flow starts on.

  /// KYC just submitted (status=pending), no delivery/request row; enables the
  /// onboarding-funding screen as a valid landing (JM-041). Pins
  /// `/jeeber/onboarding/funding` so the funding explainer shows on first frame.
  jeeberKycSubmitted('jeeber_kyc_submitted', '/jeeber/onboarding/funding'),

  /// 1 open request visible to user-jeeber-002 in the delivery feed (JM-044,
  /// JM-045, JM-046, JM-048). Stable id: req-feed-001. No route pin — the flow
  /// lands on the jeeber shell (`shell_tab_dashboard`) and navigates to the feed
  /// (`jeeber_feed_root`), then taps `feed_make_offer_cta`.
  jeeberFeedWithRequest('jeeber_feed_with_request', ''),

  /// 1 offer submitted by user-jeeber-002 awaiting the customer decision
  /// (status=submitted) (JM-047, JM-048 AC3). Stable id: pending-offer-jeeber-001.
  /// No route pin — the flow lands on the shell and navigates via the pending
  /// sub-tab (`jeeber_feed_pending_tab` → `pending_offer_0`).
  jeeberPendingOffers('jeeber_pending_offers', ''),

  /// 1 in-transit delivery for user-jeeber-002 with a 1:1 chat (JM-051). Stable
  /// id: del-jeeber-002-active. Pins
  /// `/jeeber/deliveries/del-jeeber-002-active/active` so the mark-delivered
  /// screen (`mark_delivered_root`) shows on first frame.
  jeeberActiveDelivery(
    'jeeber_active_delivery',
    '/jeeber/deliveries/del-jeeber-002-active/active',
  ),

  // ── Wave 4 shared journeys (30_BACKLOG W4 items + 21_NAV_PLAN §B W4) ───────
  // Layered on a `jeeb.seam.session` base seed. Each makes the mock hold the
  // deterministic rows the W4 shared screens fetch (notifications inbox /
  // dispute / jeeber reviews) via `POST /__mock/seed/journey` (backend
  // `seedJourney`), and pins the deep route the flow starts on. The seam OWNS
  // the value→route contract; the backend OWNS the mock rows; the W4 integrator
  // OWNS the route registration — exactly the W1/W2 split.

  /// A populated notifications inbox for user-client-001: >=1 typed row per
  /// dispatch class (offer / accepted / status / low-balance / fee /
  /// refund-penalty / topup / kyc) so `/notifications` (`notifications_root`)
  /// renders typed `notif_row_<id>` rows on first frame (JM-057). Pins
  /// `/notifications` so the inbox shows immediately. Pair with
  /// `jeeb.seam.session=customer_logged_in` (or `jeeber_logged_in`).
  hasNotifications('has_notifications', '/notifications'),

  /// 1 OPEN dispute for user-client-001 on the accepted order so the
  /// dispute-status screen (`dispute_status_state`) shows an Open status +
  /// outcome/evidence summary on first frame (JM-065). Stable id
  /// `dispute-client-001-open`. Pins `/disputes/dispute-client-001-open`. The
  /// backend seeds the dispute row (+ the chat snapshot it summarises) on the
  /// accepted-order conversation.
  disputeOpen('dispute_open', '/disputes/dispute-client-001-open'),

  /// >=5 reviews for the jeeber `user-jeeber-002` so the public jeeber profile
  /// (`delivery_man_profile_screen_root`) shows its score (>=5 clears the
  /// cold-start hide, D59) + a populated reviews section, and `reviews-list`
  /// (JM-068) has rows (JM-067/068). No route pin — the W4 jeeber-profile route
  /// takes its identity via `extra` from the offer card today, so the flow
  /// lands on the shell and navigates to the profile via the offer-review card
  /// (pair with `jeeb.seam.journey` is single-valued, so this journey ALSO
  /// seeds the offers_received-style entry rows in the backend branch). The
  /// mock holds the reviews for `user-jeeber-002` keyed by the stable id below.
  jeeberHasReviews('jeeber_has_reviews', ''),

  // ── Wave 3 wallet ledger journey (30_BACKLOG W3 items + 21_NAV_PLAN §B W3) ──

  /// A populated wallet ledger for the jeeber `user-jeeber-002`: >=1 typed row
  /// per ledger type (reserve / fee_won / released / refund / penalty / topup /
  /// gift) so the wallet activity list (`wallet_activity_row_<id>`, JM-055), a
  /// transaction detail (`txn_detail`, JM-056) and the earnings dashboard
  /// (`earnings_total_cash`, JM-052) have data. No route pin — the flow lands
  /// on the jeeber shell (`shell_tab_dashboard`/`shell_tab_earnings`) and
  /// navigates via the wallet hub (`wallet_see_all_activity` / `wallet_earnings_row`).
  /// Pair with `jeeb.seam.session=jeeber_logged_in` (+ `jeeb.seam.wallet_state`
  /// for the hub balance). Pass an explicit `jeeb.route=/wallet/activity` (or
  /// `/wallet/transactions/<id>`) to deep-land a ledger flow.
  walletWithLedger('wallet_with_ledger', ''),

  // ── W3/W4 flow-contract journey values (67_W34_TEST_PLAN) ─────────────────
  // The shipped Maestro flows pass these exact wire names. The backend
  // `seedJourney` (journey-seed.ts) holds the rows under the stable ids each
  // flow asserts; `SessionSeamBootstrap` must recognise the value so it POSTs
  // `{ journey }` to the mock during cold-start. None pin a route — every flow
  // passes an explicit `jeeb.route` (e.g. `/wallet/transactions/txn-fee-001`,
  // `/disputes/dispute-client-001`, `/profile/delivery-man/<id>/reviews`), which
  // the existing `_devRoute` pin lands.

  /// 1 Fee-won transaction `txn-fee-001` for `user-jeeber-002` so the
  /// transaction-detail flow (JM-056 AC1/2/4) pinned at
  /// `/wallet/transactions/txn-fee-001` shows the fee_won detail (D37).
  jeeberWalletFeeTxn('jeeber_wallet_fee_txn', ''),

  /// 1 Refund transaction `txn-refund-001` for `user-jeeber-002` so the
  /// transaction-detail flow (JM-056 AC3/5) shows the refund detail + dispute
  /// link (D2).
  jeeberWalletRefundTxn('jeeber_wallet_refund_txn', ''),

  /// 1 OPEN dispute `dispute-client-001` for `user-client-001` (JM-065). The
  /// flow passes `jeeb.route=/disputes/dispute-client-001`.
  hasOpenDispute('has_open_dispute', ''),

  /// A populated wallet ledger for `user-jeeber-002` with the flow's stable row
  /// ids (`ledger-row-reserve-001` / `-fee-001` / `-released-001`) so the
  /// wallet-activity flow (JM-055) shows typed rows. The flow passes an explicit
  /// `jeeb.route=/wallet/activity`. (Distinct wire name from `wallet_with_ledger`
  /// above — this is the JM-055 flow's exact value.)
  jeeberWalletLedger('jeeber_wallet_ledger', ''),

  /// <5 reviews cold-start posture for `user-jeeber-002` (JM-068 AC2b). The
  /// flow passes `jeeb.route=/profile/delivery-man/user-jeeber-002/reviews`.
  /// (`has_notifications` and `jeeber_has_reviews` already exist above.)
  jeeberColdStartProfile('jeeber_cold_start_profile', '');

  const JourneySeed(this.wireValue, this.routePin);

  /// The string a Maestro flow passes via `jeeb.seam.journey`.
  final String wireValue;

  /// The deep route the router should land on for this journey, or empty when
  /// the flow navigates there from the shell (so the app lands on `/`).
  final String routePin;

  /// Parses the wire value into a [JourneySeed]; unknown/empty → [none] so a
  /// typo never crashes startup (it simply seeds nothing).
  static JourneySeed fromWire(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return JourneySeed.none;
    for (final seed in JourneySeed.values) {
      if (seed.wireValue == v) return seed;
    }
    return JourneySeed.none;
  }
}

/// The jeeber KYC verification status a `jeeb.seam.kyc_status` extra seeds
/// (65_W2_TEST_PLAN §3.1). Layered on `jeeb.seam.session=jeeber_logged_in`, it
/// drives WHAT the jeeber screens render — NOT where the router lands:
///   * `none`     → the DELIVERY tab shows `delivery_register_prompt` (JM-036),
///                  the offer flow shows `offer_kyc_gate` (JM-044).
///   * `approved` → the DELIVERY tab shows `jeeber_feed_root` (JM-036), the
///                  offer flow opens `offer_composer_root` directly (JM-044).
///   * `pending`  → funding/pending-status context (JM-041/042).
///   * `rejected` → the rejected screen (JM-043).
///
/// [SessionSeamBootstrap] (a) writes a client-side kyc-status value the
/// DELIVERY-tab/offer gates read on first frame and (b) `POST`s the mock kyc
/// seed endpoint so `GET /user-management/users/:userId/kyc` (and getMe) reflect
/// it for the live app path. [none] is the inert default — but note that, for a
/// `jeeber_logged_in` session, an *absent* kyc_status is itself the "not
/// approved" state, so the gate behaves like `none` whether or not the seam is
/// set. The four explicit values exist so a flow can pick a specific status.
enum KycStatusSeed {
  /// No kyc_status seeding (absent). For a jeeber session this is read as "not
  /// approved" by the gates — same effective gate as [statusNone].
  none(''),

  /// KYC not started — register prompt / offer gate (JM-036/044/048).
  statusNone('none'),

  /// KYC submitted, under review — funding/pending context (JM-041/042).
  pending('pending'),

  /// KYC approved — feed/composer unlocked (JM-036/042/044/045/047/051/053).
  approved('approved'),

  /// KYC rejected — the rejected screen (JM-042/043).
  rejected('rejected');

  const KycStatusSeed(this.wireValue);

  /// The string a Maestro flow passes via `jeeb.seam.kyc_status` AND the exact
  /// status string the mock seed endpoint stores (so `none`/`pending`/
  /// `approved`/`rejected` round-trip to `GET …/kyc`). [none] (absent) has no
  /// wire value.
  final String wireValue;

  /// Parses the wire value into a [KycStatusSeed]; unknown/empty → [none] so a
  /// typo never crashes startup (it simply seeds nothing → "not approved").
  static KycStatusSeed fromWire(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return KycStatusSeed.none;
    for (final seed in KycStatusSeed.values) {
      if (seed != KycStatusSeed.none && seed.wireValue == v) return seed;
    }
    return KycStatusSeed.none;
  }
}

/// The wallet affordability state a `jeeb.seam.wallet_state` extra seeds
/// (65_W2_TEST_PLAN §3.2). MOCK-side only: it makes `GET /wallet-service/v1/jeeb/
/// wallet` return a balance/affordability/reserved-now tuple the wallet hub
/// (JM-053) and the offer composer (JM-045/046) read. The app seeds nothing
/// locally for it — there is no client-side wallet store the seam owns; the
/// screens fetch the seeded balance from the mock.
///
///   * `sufficient`   → availableBalance > reserve needed; composer send → feed.
///   * `insufficient` → availableBalance < reserve needed; composer send raises
///                      `insufficient_balance_sheet` (with the mock O1 402 path).
///   * `empty`        → availableBalance = 0 (all-reserved/empty affordability).
///
/// [none] is the inert default (no wallet seeding — the mock keeps its base
/// fixture balance).
enum WalletStateSeed {
  /// No wallet seeding (absent) — the mock keeps its base fixture balance.
  none(''),

  /// availableBalance > reserve needed (affordability "enough").
  sufficient('sufficient'),

  /// availableBalance < reserve needed (affordability "low"/"empty"); the offer
  /// 402 path is reachable.
  insufficient('insufficient'),

  /// availableBalance = 0 (affordability "all_reserved"/"empty").
  empty('empty');

  const WalletStateSeed(this.wireValue);

  /// The string a Maestro flow passes via `jeeb.seam.wallet_state` AND the exact
  /// state the mock wallet seed endpoint stores. [none] (absent) has no wire
  /// value.
  final String wireValue;

  /// Parses the wire value into a [WalletStateSeed]; unknown/empty → [none] so a
  /// typo never crashes startup (it simply seeds nothing).
  static WalletStateSeed fromWire(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return WalletStateSeed.none;
    for (final seed in WalletStateSeed.values) {
      if (seed != WalletStateSeed.none && seed.wireValue == v) return seed;
    }
    return WalletStateSeed.none;
  }
}

/// Immutable, debug-only configuration that lets a SINGLE dev APK render any
/// screen / state / locale at runtime — no per-state rebuild.
///
/// It generalises the four compile-time `JEEB_DEV_*` dart-defines (which were
/// `const String.fromEnvironment`, so frozen at build time → one value per
/// APK) into a value object resolved at startup from a runtime source (Android
/// intent extras or a pushed device file). The dart-defines remain the lowest
/// fallback so in-flight `--dart-define` flows keep working unchanged.
///
/// Release builds never construct a non-empty instance: every read site is
/// `kDebugMode`-gated and [DevSeam.resolve] short-circuits to [empty] in
/// release. The class is therefore inert (and tree-shakeable) in production.
@immutable
class DevSeamConfig {
  const DevSeamConfig({
    this.route = '',
    this.chatSelector = '',
    this.forcedLocale = '',
    this.homeTab = '',
    this.feed = '',
    this.holdSplash = false,
    this.skipOnboarding = false,
    this.sessionSeed = SessionSeed.none,
    this.journeySeed = JourneySeed.none,
    this.kycStatusSeed = KycStatusSeed.none,
    this.walletStateSeed = WalletStateSeed.none,
    this.otpCode = '',
    this.otpCountdownExpired = false,
    this.signupCollision = false,
    this.socialLogin = '',
    this.recoveryCode = '',
    this.recoveryCountdownExpired = false,
    this.setPasswordMode = '',
    // super-login+ seam fields (QA-only; debug-gated end-to-end).
    this.superLoginToken = '',
    this.superLoginRefreshToken = '',
    this.superLoginUserId = '',
    this.superLoginRole = '',
  });

  /// Builds a config from a flat string map (intent extras or decoded JSON).
  /// Keys mirror the dart-define names without the `JEEB_` prefix, lower-cased
  /// and dotted: `jeeb.route`, `jeeb.state`, `jeeb.locale`, `jeeb.hold_splash`.
  factory DevSeamConfig.fromMap(Map<String, String> map) {
    return DevSeamConfig(
      route: map['jeeb.route']?.trim() ?? '',
      chatSelector: map['jeeb.state']?.trim() ?? '',
      forcedLocale: map['jeeb.locale']?.trim() ?? '',
      homeTab: map['jeeb.home_tab']?.trim() ?? '',
      feed: map['jeeb.feed']?.trim() ?? '',
      holdSplash: _asBool(map['jeeb.hold_splash']),
      skipOnboarding: _asBool(map['jeeb.skip_onboarding']),
      // Wave 0 dev-seam session/journey harness (62_SEAM_HARNESS.md).
      sessionSeed: SessionSeed.fromWire(map['jeeb.seam.session']),
      // Wave 1 journey seam (63_W1_TEST_PLAN §4).
      journeySeed: JourneySeed.fromWire(map['jeeb.seam.journey']),
      // Wave 2 jeeber seam (65_W2_TEST_PLAN §3.1/§3.2).
      kycStatusSeed: KycStatusSeed.fromWire(map['jeeb.seam.kyc_status']),
      walletStateSeed: WalletStateSeed.fromWire(map['jeeb.seam.wallet_state']),
      otpCode: map['jeeb.seam.otp_code']?.trim() ?? '',
      otpCountdownExpired: _asBool(map['jeeb.seam.otp_countdown_expired']),
      signupCollision: _asBool(map['jeeb.seam.signup_collision']),
      socialLogin: map['jeeb.seam.social_login']?.trim() ?? '',
      recoveryCode: map['jeeb.seam.recovery_code']?.trim() ?? '',
      recoveryCountdownExpired: _asBool(
        map['jeeb.seam.recovery_countdown_expired'],
      ),
      setPasswordMode: map['jeeb.seam.set_password_mode']?.trim() ?? '',
      // super-login+ seam: real gateway JWT injected via intent extras.
      superLoginToken: map['jeeb.seam.super_login_token']?.trim() ?? '',
      superLoginRefreshToken:
          map['jeeb.seam.super_login_refresh']?.trim() ?? '',
      superLoginUserId: map['jeeb.seam.super_login_user_id']?.trim() ?? '',
      superLoginRole: map['jeeb.seam.super_login_role']?.trim() ?? '',
    );
  }

  /// Parses a `jeeb-dev-seam.json` device-file payload. Returns [empty] on any
  /// malformed input — a broken dev file must never crash app startup.
  factory DevSeamConfig.fromJsonString(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return empty;
      final flat = decoded.map((k, v) => MapEntry('$k', '${v ?? ''}'));
      return DevSeamConfig.fromMap(flat);
    } catch (_) {
      return empty;
    }
  }

  /// Direct route override (generalises `JEEB_DEV_HOME`). When non-empty the
  /// router lands straight on this location, bypassing onboarding + biometric
  /// gates. `/` reproduces the old `JEEB_DEV_HOME=true` behaviour.
  final String route;

  /// Chat fixture selector (replaces `JEEB_DEV_CHAT`, e.g. `broadcasting`,
  /// `accepted`, `dm`, `dm-order-picked`, …). When non-empty the router lands
  /// on the fixtures-backed chat preview for that state.
  final String chatSelector;

  /// Forced locale language code (replaces `JEEB_FORCE_LOCALE`, e.g. `ar`).
  final String forcedLocale;

  /// Client "My Orders" filter tab to land on when [route] resolves to the
  /// shell home (`in_progress`, `pending`, `replies`), or `unregistered` to
  /// force the jeeber Delivery-tab upsell view. Debug capture aid only: the
  /// home tab seeds deterministic fixtures and selects this filter so a single
  /// APK renders screens 13/14/15 (and the jeeber-unregistered upsell) without
  /// a rebuild. Keyed `jeeb.home_tab`. Empty in release.
  final String homeTab;

  /// Deliveryman (jeeber) feed selector for the Delivery tab. Debug capture
  /// aid only: the dashboard tab seeds deterministic fixtures and selects this
  /// view so a single APK renders screens 23-26 without a rebuild. Empty in
  /// release. Values: `empty` (23), `requests` (24), `pending` (25),
  /// `replies` (26).
  final String feed;

  /// Holds the branded splash on screen after bootstrap (replaces
  /// `JEEB_HOLD_SPLASH`).
  final bool holdSplash;

  /// Explicit opt-in that lets [route] bypass the first-run onboarding (and
  /// session/JWT) gate. SECURITY-CRITICAL DEFAULT: `false`.
  ///
  /// Why this exists (FR-P0-1): a bare route pin (`jeeb.route=/`, the device
  /// file, or `--dart-define=JEEB_DEV_HOME=true`) used to *silently* skip
  /// onboarding + login, so anyone who ran the dev APK out of habit booted
  /// straight to Home and never saw splash → walkthrough → login. The router
  /// now only allows the pin to skip first-run when THIS flag is also set, so a
  /// fresh install with empty prefs deterministically lands on `/onboarding`
  /// even when a route is pinned. Deep-capture of *already-onboarded* states
  /// (the original capture use case) is unaffected — that path never needed to
  /// skip onboarding because onboarding was already complete.
  ///
  /// Keyed `jeeb.skip_onboarding` (intent extra / device file) or
  /// `--dart-define=JEEB_DEV_SKIP_ONBOARDING=true`. Empty/false in release.
  final bool skipOnboarding;

  // ── Wave 0 dev-seam session/journey harness (62_SEAM_HARNESS.md) ──────────
  // These let a Maestro flow deterministically start mid-journey. Consumed by
  // [SessionSeamBootstrap] (session/biometric/role/account-status state, seeded
  // before the router redirect fires) and by the per-flow screens (OTP/recovery
  // countdown overrides). All are kDebugMode-gated end to end.

  /// Pre-seeds session/journey state so the router lands the flow at the right
  /// start destination. Keyed `jeeb.seam.session`. [SessionSeed.none] in
  /// release / when absent. See [SessionSeed] for the value→destination map.
  final SessionSeed sessionSeed;

  /// Pre-seeds mid-journey request/offer/delivery/conversation state (in the
  /// mock + a deep route pin) so a W1 customer-journey flow starts deep
  /// (63_W1_TEST_PLAN §4). Layered on [sessionSeed]. Keyed `jeeb.seam.journey`.
  /// [JourneySeed.none] in release / when absent. See [JourneySeed] for the
  /// value→seed→route map; consumed by [SessionSeamBootstrap].
  final JourneySeed journeySeed;

  /// Pre-seeds the jeeber KYC verification status (65_W2_TEST_PLAN §3.1) so the
  /// DELIVERY-tab gate (JM-036), the offer gate (JM-044), the funding/pending
  /// screens (JM-041/042) and the rejected screen (JM-043) render the right
  /// state on first frame. Consumed by [SessionSeamBootstrap], which writes a
  /// client-side kyc-status value the gates read AND `POST`s the mock kyc seed
  /// endpoint. Keyed `jeeb.seam.kyc_status`. [KycStatusSeed.none] in release /
  /// when absent. Does NOT itself pin a route — the route-pinned KYC flows pass
  /// an explicit `jeeb.route` (JM-042/043) or land on the jeeber shell (JM-036).
  final KycStatusSeed kycStatusSeed;

  /// Pre-seeds the wallet affordability state (65_W2_TEST_PLAN §3.2) so the
  /// wallet hub (JM-053) and the offer composer (JM-045/046) read the right
  /// balance/affordability. MOCK-side only — consumed by [SessionSeamBootstrap]
  /// which `POST`s the mock wallet seed endpoint; seeds NO client-side store.
  /// Keyed `jeeb.seam.wallet_state`. [WalletStateSeed.none] in release / when
  /// absent.
  final WalletStateSeed walletStateSeed;

  /// Fixed OTP the phone-OTP flow should type (JM-009). The mock already
  /// accepts the dev code `123456`, so this is the value a flow enters — no app
  /// seeding is needed for it to verify. Keyed `jeeb.seam.otp_code`. Empty in
  /// release.
  final String otpCode;

  /// Forces the phone-OTP resend countdown to zero so `phone_otp_resend_cta` is
  /// immediately tappable (JM-009). App-driven countdown override — the
  /// registration screen injects a zero-cooldown policy when this is set. Keyed
  /// `jeeb.seam.otp_countdown_expired`. False in release.
  final bool otpCountdownExpired;

  /// Documents that the flow intends to trigger a signup 409 (JM-008/019). The
  /// collision is MOCK-driven: the mock 409s `email_collision` on a duplicate
  /// email, so a flow types an already-registered email (e.g. seeded
  /// `nadia@example.com` after a prior signup) rather than seeding app state.
  /// Kept as a typed flag for parity + future use. Keyed
  /// `jeeb.seam.signup_collision`. False in release.
  final bool signupCollision;

  /// Social-login variant the flow exercises (JM-018/019). MOCK-driven: the
  /// mock derives a stable pseudo-identity from `provider + idToken`. Values:
  /// `facebook_no_phone` (new identity → phone-OTP), `collision_409` (the flow
  /// drives the email/password collision path that raises the JM-019 sheet).
  /// Keyed `jeeb.seam.social_login`. Empty in release.
  final String socialLogin;

  /// Fixed recovery code the verify-recovery-code flow should type (JM-021).
  /// MOCK-driven dev code `654321` — the value a flow enters; no app seeding is
  /// needed. Keyed `jeeb.seam.recovery_code`. Empty in release.
  final String recoveryCode;

  /// Forces the recovery resend countdown to zero (JM-021). NOTE: the
  /// verify-recovery-code screen has NO app-driven countdown today
  /// (`verify_code_resend_cta` is always tappable), so this is currently a
  /// no-op flag retained for contract parity / future use. Keyed
  /// `jeeb.seam.recovery_countdown_expired`. False in release.
  final bool recoveryCountdownExpired;

  /// Launches `/set-password` directly in a specific mode (JM-022). Values:
  /// `in-app-social` (social account setting its first password → profile),
  /// `recovery` (the default; recovery reset → login). Consumed when the flow
  /// deep-links to set-password via `jeeb.route=/set-password`. Keyed
  /// `jeeb.seam.set_password_mode`. Empty in release.
  final String setPasswordMode;

  // ── super-login+ seam (QA-only; debug-gated end-to-end) ─────────────────
  // Passed via intent extras at launch time — never baked into the binary.
  // Consumed by [SessionSeamBootstrap] when sessionSeed == superLoginPlus.

  /// Real gateway access JWT to write into [AuthTokenStore] so the app
  /// authenticates against the live /v1/* API as the seeded user without OTP.
  /// Keyed `jeeb.seam.super_login_token`. Empty in release.
  final String superLoginToken;

  /// Optional refresh token paired with [superLoginToken]. Falls back to
  /// [superLoginToken] when absent (gateway refresh endpoint may accept the
  /// access token as a refresh in dev). Keyed `jeeb.seam.super_login_refresh`.
  /// Empty in release.
  final String superLoginRefreshToken;

  /// UUID of the user the minted token belongs to (e.g.
  /// `c23efd76-6fa4-40cf-814c-116f67ea5e95`). Written to [AuthTokenStore] as
  /// `auth.userId` so account-status / profile lookups use the correct id.
  /// Keyed `jeeb.seam.super_login_user_id`. Empty in release.
  final String superLoginUserId;

  /// Optional local role to seed with [SessionSeed.superLoginPlus]. Values:
  /// `client`/`customer` or `jeeber`/`driver`. Keyed
  /// `jeeb.seam.super_login_role`. Empty defaults to client for backward
  /// compatibility with PR #56.
  final String superLoginRole;

  /// The inert default. The only instance a release build ever sees.
  static const DevSeamConfig empty = DevSeamConfig();

  bool get hasRoute => route.isNotEmpty;
  bool get hasChatSelector => chatSelector.isNotEmpty;
  bool get hasForcedLocale => forcedLocale.isNotEmpty;
  bool get hasHomeTab => homeTab.isNotEmpty;
  bool get hasFeed => feed.isNotEmpty;

  /// True when a `jeeb.seam.session` extra requested a non-inert session seed.
  bool get hasSessionSeed => sessionSeed != SessionSeed.none;

  /// True when a `jeeb.seam.journey` extra requested a non-inert journey seed.
  bool get hasJourneySeed => journeySeed != JourneySeed.none;

  /// True when a `jeeb.seam.kyc_status` extra requested a non-inert KYC seed.
  bool get hasKycStatusSeed => kycStatusSeed != KycStatusSeed.none;

  /// True when a `jeeb.seam.wallet_state` extra requested a non-inert wallet seed.
  bool get hasWalletStateSeed => walletStateSeed != WalletStateSeed.none;
  bool get hasSetPasswordMode => setPasswordMode.isNotEmpty;
  bool get hasSocialLogin => socialLogin.isNotEmpty;

  /// True when every field is at its inert default (nothing to apply).
  bool get isEmpty =>
      route.isEmpty &&
      chatSelector.isEmpty &&
      forcedLocale.isEmpty &&
      homeTab.isEmpty &&
      feed.isEmpty &&
      !holdSplash &&
      !skipOnboarding &&
      sessionSeed == SessionSeed.none &&
      journeySeed == JourneySeed.none &&
      kycStatusSeed == KycStatusSeed.none &&
      walletStateSeed == WalletStateSeed.none &&
      otpCode.isEmpty &&
      !otpCountdownExpired &&
      !signupCollision &&
      socialLogin.isEmpty &&
      recoveryCode.isEmpty &&
      !recoveryCountdownExpired &&
      setPasswordMode.isEmpty &&
      superLoginToken.isEmpty &&
      superLoginRefreshToken.isEmpty &&
      superLoginUserId.isEmpty &&
      superLoginRole.isEmpty;

  static bool _asBool(String? value) {
    final v = value?.trim().toLowerCase();
    return v == 'true' || v == '1' || v == 'yes';
  }

  @override
  bool operator ==(Object other) =>
      other is DevSeamConfig &&
      other.route == route &&
      other.chatSelector == chatSelector &&
      other.forcedLocale == forcedLocale &&
      other.homeTab == homeTab &&
      other.feed == feed &&
      other.holdSplash == holdSplash &&
      other.skipOnboarding == skipOnboarding &&
      other.sessionSeed == sessionSeed &&
      other.journeySeed == journeySeed &&
      other.kycStatusSeed == kycStatusSeed &&
      other.walletStateSeed == walletStateSeed &&
      other.otpCode == otpCode &&
      other.otpCountdownExpired == otpCountdownExpired &&
      other.signupCollision == signupCollision &&
      other.socialLogin == socialLogin &&
      other.recoveryCode == recoveryCode &&
      other.recoveryCountdownExpired == recoveryCountdownExpired &&
      other.setPasswordMode == setPasswordMode &&
      other.superLoginToken == superLoginToken &&
      other.superLoginRefreshToken == superLoginRefreshToken &&
      other.superLoginUserId == superLoginUserId &&
      other.superLoginRole == superLoginRole;

  @override
  int get hashCode => Object.hashAll([
    route,
    chatSelector,
    forcedLocale,
    homeTab,
    feed,
    holdSplash,
    skipOnboarding,
    sessionSeed,
    journeySeed,
    kycStatusSeed,
    walletStateSeed,
    otpCode,
    otpCountdownExpired,
    signupCollision,
    socialLogin,
    recoveryCode,
    recoveryCountdownExpired,
    setPasswordMode,
    superLoginToken,
    superLoginRefreshToken,
    superLoginUserId,
    superLoginRole,
  ]);

  @override
  String toString() =>
      'DevSeamConfig(route: $route, chat: $chatSelector, '
      'locale: $forcedLocale, homeTab: $homeTab, feed: $feed, '
      'holdSplash: $holdSplash, skipOnboarding: $skipOnboarding, '
      'sessionSeed: ${sessionSeed.name}, journeySeed: ${journeySeed.name}, '
      'kycStatusSeed: ${kycStatusSeed.name}, '
      'walletStateSeed: ${walletStateSeed.name}, '
      'otpCode: $otpCode, '
      'otpCountdownExpired: $otpCountdownExpired, '
      'signupCollision: $signupCollision, socialLogin: $socialLogin, '
      'recoveryCode: $recoveryCode, '
      'recoveryCountdownExpired: $recoveryCountdownExpired, '
      'setPasswordMode: $setPasswordMode, '
      'superLoginToken: ${superLoginToken.isNotEmpty ? '[present]' : '[absent]'}, '
      'superLoginUserId: $superLoginUserId, '
      'superLoginRole: $superLoginRole)';
}
