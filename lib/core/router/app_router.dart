import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../dev_seam/dev_seam.dart';
import '../session/account_status_gate.dart';
import '../session/session_gate.dart';
import '../session/session_state.dart';
import 'profile_unavailable_screen.dart';
import '../../features/account_status/presentation/account_status_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/recover_password_screen.dart';
import '../../features/auth/presentation/set_password_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/auth/presentation/verify_recovery_code_screen.dart';
import '../../features/biometric_auth/application/biometric_lock_cubit.dart';
import '../../features/biometric_auth/application/biometric_lock_state.dart';
import '../../features/biometric_auth/presentation/biometric_lock_screen.dart';
import '../../features/chat/presentation/dev_chat_preview_screen.dart';
import '../../features/client_offers/presentation/client_offers_screen.dart';
import '../../features/customer_profile/data/dev_customer_profile_fixtures.dart';
import '../../features/customer_profile/domain/customer_profile_view_data.dart';
import '../../features/customer_profile/presentation/customer_profile_screen.dart';
import '../../features/deep_link_targets/chat_detail_screen.dart';
import '../../features/delivery_man_profile/data/dev_delivery_man_profile_fixtures.dart';
import '../../features/delivery_man_profile/domain/delivery_man_profile_view_data.dart';
import '../../features/delivery_man_profile/presentation/delivery_man_profile_screen.dart';
import '../../features/deep_link_targets/delivery_detail_screen.dart';
import '../../features/deep_link_targets/rating_prompt_screen.dart';
import '../../features/kyc/presentation/kyc_wizard_screen.dart';
import '../../features/kyc_rejected/presentation/kyc_rejected_screen.dart';
import '../../features/jeeber_onboarding_funding/presentation/onboarding_funding_screen.dart';
import '../../features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart';
import '../../features/offer_kyc_gate/presentation/delivery_register_prompt_screen.dart';
import '../../features/offer_kyc_gate/presentation/offer_kyc_gate_screen.dart';
import '../../features/wallet/presentation/transaction_detail_screen.dart';
import '../../features/wallet/presentation/wallet_activity_list_screen.dart';
import '../../features/wallet/presentation/wallet_charge_info_screen.dart';
import '../../features/wallet/presentation/wallet_hub_screen.dart';
import '../../features/dispute_status/presentation/dispute_status_screen.dart';
import '../../features/language/presentation/screens/language_settings_screen.dart';
import '../../features/notifications/presentation/notifications_list_screen.dart';
import '../../features/password_security/presentation/password_security_screen.dart';
import '../../features/reviews/presentation/reviews_list_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/search/presentation/search_results_screen.dart';
import '../../features/support/presentation/support_ticket_screen.dart';
import '../../features/escalate/application/escalate_cubit.dart';
import '../../features/escalate/domain/escalate_repository.dart';
import '../../features/escalate/presentation/escalate_screen.dart';
import '../../features/rating/application/mutual_rating_cubit.dart';
import '../../features/rating/domain/rating_repository.dart';
import '../../features/rating/presentation/mutual_rating_screen.dart';
import '../../features/rating/presentation/rating_screen.dart';
import '../../features/jeeber_home/domain/entities/feed_request.dart';
import '../../features/jeeber_home/domain/services/request_feed_service.dart';
import '../../features/jeeber_onboarding/application/dm_onboarding_state.dart';
import '../../features/jeeber_onboarding/presentation/dm_onboarding_screen.dart';
import '../../features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import '../../features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart';
import '../../features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart';
import '../../features/live_tracking/application/live_tracking_cubit.dart';
import '../../features/live_tracking/data/demo_live_tracking_repository.dart';
import '../../features/live_tracking/domain/live_tracking_repository.dart';
import '../../features/live_tracking/presentation/live_tracking_screen.dart';
import '../../features/delivery_receipt/presentation/delivery_receipt_screen.dart';
import '../../features/goods_cost/presentation/goods_cost_screen.dart';
import '../../features/background_gps/data/geolocator_geocapture_gateway.dart';
import '../../features/location/data/location_repository.dart';
import '../../features/location/presentation/capture_location_screen.dart';
import '../../features/location/presentation/client_location_screen.dart';
import '../../features/location/presentation/screens/address_detail_form_screen.dart';
import '../../features/location/presentation/screens/location_picker_screen.dart';
import '../../features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';
import '../../features/order_summary/presentation/order_summary_screen.dart';
import '../../features/location/presentation/widgets/google_map_capture_view.dart';
import '../../features/location/presentation/widgets/map_capture_controller.dart';
import '../../features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import '../../features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';
import '../../features/offers/domain/offer_submission_repository.dart';
import '../../features/offers/domain/offer_submission_service.dart';
import '../../features/offers/presentation/offer_submission_screen.dart';
import '../../features/settlement/domain/settlement_repository.dart';
import '../../features/settlement/domain/settlement_statement.dart';
import '../../features/settlement/presentation/settlement_detail_screen.dart';
import '../../features/settlement/presentation/settlement_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/otp_handover/application/otp_handover_cubit.dart';
import '../../features/otp_handover/domain/otp_handover_repository.dart';
import '../../features/otp_handover/presentation/otp_handover_screen.dart';
import '../../features/registration/presentation/registration_screen.dart';
import '../../features/request_summary/application/request_summary_cubit.dart';
import '../../features/request_summary/domain/request_draft.dart';
import '../../features/request_summary/domain/request_submission_service.dart';
import '../../features/request_summary/presentation/request_summary_screen.dart';
import '../../features/request_summary/presentation/request_summary_unavailable_screen.dart';
import '../../features/settings/presentation/screens/notification_preferences_screen.dart';
import '../../features/settings/presentation/screens/profile_edit_screen.dart';
import '../../features/cancellation/presentation/cancellation_screen.dart';
import '../../features/location/presentation/saved_locations_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/request_type/presentation/request_type_screen.dart';
import '../../features/shell/shell_screen.dart';
import '../../features/shell/tabs/earnings_tab.dart';
import '../../features/transcription/domain/voice_clip.dart';
import '../../features/transcription/presentation/transcription_screen.dart';
import '../../features/voice_request/presentation/voice_request_screen.dart';
import '../di/injection_container.dart';
import '../onboarding/onboarding_cubit.dart';

/// Top-level router.
///
/// First-launch gate (two layers, FR-P0-1 + FR-P0-3):
///   1. While [OnboardingCubit.state] is `false`, the user is kept on
///      `/onboarding` or `/register` (the only pre-auth destinations).
///   2. Once onboarding completes, the [SessionGate] gate keeps an
///      onboarded-but-tokenless user on `/register` (the phone-OTP entry,
///      DEFECT-3) until a valid token exists, so Home is unreachable without
///      authenticating. `/register` is the reachable auth entry because the
///      LIVE gateway only implements phone-OTP (`/v1/auth/otp/request` →
///      `/v1/auth/otp/verify`); the email `/login` + `/sign-up` screens are
///      kept (a later gateway fix may add those routes) and remain reachable
///      from `/register`, but they no longer force the entry.
/// Once the user finishes onboarding AND has a valid session the redirect lets
/// `/` (the shell) render normally. `refreshListenable` re-evaluates redirects
/// whenever onboarding, the biometric lock, or the session emits.
///
/// The debug-only DevSeam route pin can still drive deterministic capture of
/// authenticated screens, but (FR-P0-1) it may only *bypass* the onboarding +
/// session gates when [DevSeamConfig.skipOnboarding] is explicitly set — a bare
/// `jeeb.route=/` / `JEEB_DEV_HOME=true` on a fresh install now lands on
/// `/onboarding`, not Home.
/// Resolves the id the live-tracking surface must read
/// (`GET /v1/delivery/<id>`).
///
/// S9 live-tracking fix: the server-created delivery id (`delivery-<offerId>`)
/// is surfaced in the accept/offer response and forwarded by CTAs as the
/// `?deliveryId=` query param. It takes precedence over the path `:id`, which
/// for many entry points carries the parent REQUEST id — a value the
/// delivery-service answers with 404 ("Delivery not found"). Falls back to the
/// path id when no query param is present (legacy callers + dev seam).
///
/// Pure + side-effect free so the precedence rule is unit-testable without
/// booting the router.
String resolveTrackingDeliveryId({
  required String? routeId,
  required String? queryDeliveryId,
}) {
  if (queryDeliveryId != null && queryDeliveryId.isNotEmpty) {
    return queryDeliveryId;
  }
  return routeId ?? '';
}

class AppRouter {
  AppRouter._();

  // Pre-auth destinations a logged-out user may reach WITHOUT the first-run
  // session gate bouncing them back. The W0 auth funnel (CTO-D1) adds the new
  // email-first screens alongside the legacy `/register` (kept as the reused
  // phone-OTP verify step, JM-009). `/recover/verify` is nested under `/recover`
  // and matched by prefix below (a `matchedLocation` startsWith check).
  static const Set<String> _preAuthRoutes = {
    '/onboarding',
    '/register',
    '/login',
    '/sign-up',
    '/recover',
    '/set-password',
  };
  static const String _lockRoute = '/lock';

  /// JM-066 (D5): the account-status gate target. A blocked account
  /// (`status ∈ {suspended, locked}`) is forced here and ALL tabs are blocked.
  static const String _accountStatusRoute = '/account-status';

  /// True when [loc] is one of the pre-auth funnel destinations (exact match or
  /// nested under one, e.g. `/recover/verify` under `/recover`).
  static bool _isPreAuth(String loc) {
    if (_preAuthRoutes.contains(loc)) return true;
    // Nested verify step lives at `/recover/verify`.
    return loc.startsWith('/recover/');
  }

  /// Debug-only chat-capture selector, resolved at RUNTIME from [DevSeam]
  /// (replaces the compile-time `JEEB_DEV_CHAT`). When non-empty the router
  /// lands on the full-screen [DevChatPreviewScreen] for the requested chat
  /// state — `broadcasting`, `accepted`, `dm`, `dm-order-picked`,
  /// `dm-confirm-picking`, `dm-confirm-heading-off`. Empty in release.
  static String get _devChat =>
      kDebugMode ? DevSeam.current.chatSelector : '';

  /// Debug-only route override, resolved at RUNTIME from [DevSeam] (generalises
  /// the old `JEEB_DEV_HOME=true` → `/`). When non-empty the router lands
  /// directly on this location, skipping onboarding + biometric gates, so any
  /// authenticated screen can be captured deterministically. Empty in release.
  static String get _devRoute => kDebugMode ? DevSeam.current.route : '';

  /// FR-P0-1: explicit opt-in for letting [_devRoute] bypass the first-run
  /// (onboarding + session) gate. Debug-only and `false` unless
  /// [DevSeamConfig.skipOnboarding] is set, so a bare route pin can never
  /// silently skip first-run. Always `false` in release.
  static bool get _devSkipOnboarding =>
      kDebugMode && DevSeam.current.skipOnboarding;

  /// Sentinel returned by [_devRoutePinRedirect] meaning "the pin is not
  /// forcing a redirect right now" — distinct from `null`, which go_router
  /// treats as "stay here". Using a sentinel lets the caller tell "no opinion"
  /// apart from "explicitly allow".
  static const String _noPin = '__no_pin__';

  /// The DevSeam route-pin's initial-landing-only redirect, extracted so it can
  /// be applied either before (skipOnboarding) or after (deep-capture of an
  /// already-onboarded device) the first-run gate. Returns [_noPin] when it has
  /// no opinion, a path to force a redirect, or `null` to explicitly allow the
  /// current location.
  static String? _devRoutePinRedirect(
    GoRouterState state,
    bool Function() landed,
    void Function(bool) setLanded,
  ) {
    // Compare on the PATH only so a seam route carrying query params (e.g.
    // `/orders/d-1/feedback?name=Sami`) lands once instead of looping.
    final devPath = Uri.parse(_devRoute).path;
    if (state.matchedLocation == devPath) {
      // Reached the pinned route: latch landed and let it render.
      setLanded(true);
      return null;
    }
    // Before landing, only force the redirect while still on the default root.
    // This drives the initial capture. After landing, never force again — so
    // user-pushed routes stick (screens 10 & 13, regression-tested).
    if (!landed() && state.matchedLocation == '/') {
      return _devRoute;
    }
    return _noPin;
  }

  /// First-run gate: onboarding (FR-P0-1) then session/JWT (FR-P0-3), then the
  /// account-status gate (JM-066, D5). Returns the redirect target, or `null` to
  /// allow the current location. Session-aware branches (JM-006):
  ///
  ///   * onboarding incomplete, not on a pre-auth route → `/onboarding`
  ///   * onboarding complete but on `/onboarding`        → `/`
  ///   * onboarding complete, NO valid token, not on a pre-auth route
  ///       → `/register` (the phone-OTP entry, DEFECT-3). The phone-OTP flow
  ///       (`POST /v1/auth/otp/request` → `/v1/auth/otp/verify`) is the ONLY
  ///       auth that works against the LIVE gateway, which has no
  ///       `/v1/auth/login` or `/v1/auth/signup` route (email login/signup
  ///       dead-ends there). So the tokenless first-run gate lands the user on
  ///       the reachable, working auth. The email `/login` + `/sign-up` screens
  ///       are kept (a later gateway fix may add those routes) and are still
  ///       reachable from `/register`, but they are no longer the forced entry.
  ///   * onboarding complete, token present, account `status ∈ {suspended,
  ///       locked}` → `/account-status` (D5; blocks ALL tabs, the only exits are
  ///       support + sign-out)
  ///
  /// Logged-in routing to a SPECIFIC tab (customer → Requests last-tab D75;
  /// jeeber → DELIVERY) is a `ShellScreen` + `RoleCubit` concern, not a route —
  /// the gate lands authenticated, active users at `/` and the shell selects the
  /// tab (CTO brief §4: tabs are not routes). The biometric branch (`/lock`,
  /// JM-005) is the separate gate below.
  ///
  /// The session check uses [SessionGate.isUnauthenticated] (not
  /// `!isAuthenticated`) so the cold-start `unknown` phase is a no-op and we
  /// never flash `/login` while the keystore read is in flight. Likewise the
  /// account-status gate keys on [AccountStatusGate.isBlocked] (false until the
  /// status read resolves) so it never flashes `/account-status` on launch.
  static String? _firstRunRedirect(
    GoRouterState state,
    OnboardingCubit onboarding,
    SessionGate session,
    AccountStatusGate accountStatus,
  ) {
    final completed = onboarding.state;
    final loc = state.matchedLocation;
    final atPreAuth = _isPreAuth(loc);
    if (!completed && !atPreAuth) return '/onboarding';
    if (completed && loc == '/onboarding') return '/';
    // FR-P0-3 / DEFECT-3: onboarded-but-tokenless user must authenticate before
    // reaching Home. The destination is the phone-OTP `/register` flow — the
    // only auth that works against the LIVE gateway (email `/login`/`/sign-up`
    // 401 there). The email screens stay reachable from `/register` for a later
    // gateway fix, but phone-OTP is the reachable entry.
    if (completed && session.isUnauthenticated && !atPreAuth) {
      return '/register';
    }
    // JM-066 / D5: a suspended/locked account is forced to `/account-status`
    // and cannot reach any tab. Only evaluated once a session exists (a blocked
    // account is, by definition, authenticated). The gate is a no-op
    // (`isBlocked == false`) until the real status source resolves.
    //
    // The account-status screen's two documented exits MUST remain reachable
    // (D5: "the only exits are support/signout"): `/support` (the support
    // ticket, JM-066 AC2) and the logout sheet (a sheet over `/account-status`,
    // not a route). So the gate allowlists `/support` (+ `/disputes/*`, reachable
    // from support) in addition to `/account-status` itself; everything else
    // bounces back.
    if (completed &&
        !session.isUnauthenticated &&
        accountStatus.isBlocked &&
        loc != _accountStatusRoute &&
        !loc.startsWith('/support') &&
        !loc.startsWith('/disputes')) {
      return _accountStatusRoute;
    }
    return null;
  }

  /// Order-tracking (screen 16) needs a reachable gateway to render its ready
  /// state. When the dev seam is driving a `/orders/.../tracking` capture
  /// WITHOUT a journey seed — so a flow that navigates to tracking from a
  /// pinned chat/summary renders the stepper offline — swap in the deterministic
  /// demo repository. When a journey seed IS present the mock is already seeded
  /// with the correct delivery state (e.g. `delivery_marked_done` → AtDoor) so
  /// the REAL repository is used to fetch that live status from the mock; using
  /// the demo repo here would hard-code InTransit and block journey-specific
  /// states such as the SC-041 OTP-at-door card. Every other run (no seam /
  /// release) uses the real DI-registered repository. Debug-only: in release
  /// `_devRoute` is empty and `DevSeam.current` is inert, so the real repo is
  /// always used.
  static LiveTrackingRepository _trackingRepository() {
    if (kDebugMode &&
        _devRoute.contains('/tracking') &&
        !DevSeam.current.hasJourneySeed) {
      return const DemoLiveTrackingRepository();
    }
    return sl<LiveTrackingRepository>();
  }

  /// T-MOB-012: builds the live `GoogleMap` viewport injected into
  /// [CaptureLocationScreen] at the `/capture-location` route. A fresh
  /// [MapCaptureController] is created per build (one per screen entry) seeded
  /// at Beirut downtown — the same canonical default the in-memory location
  /// repo centres on. The screen's centre pin overlays this; the controller
  /// tracks the parked coordinate for the "Pin Location" CTA.
  static MapCaptureController _newCaptureController() =>
      MapCaptureController(
        initial: const LocationPoint(latitude: 33.8938, longitude: 35.5018),
      );

  static GoRouter create({
    required OnboardingCubit onboarding,
    required BiometricLockCubit biometricLock,
    // FR-P0-3: the JWT/session gate. Defaults to an inert, always-authenticated
    // gate so callers (and tests) that don't wire a real session keep the
    // pre-gate routing behaviour. Production passes a `SessionCubit`, which is
    // also a `Cubit` and is therefore added to `refreshListenable` below so a
    // login/logout re-runs the redirect.
    SessionGate session = const AlwaysAuthenticatedSessionGate(),
    // JM-066 (D5): the account-status gate. Defaults to an inert, always-active
    // gate so the account-status redirect is a NO-OP for every call site that
    // doesn't (yet) wire a real status source — preserving prior behaviour. The
    // JM-006/JM-066 engineer wires the real status cubit (GET /users/:id by the
    // persisted userId, NOT /users/me); when it is a `Cubit` it is added to
    // `refreshListenable` below so a status change re-runs the redirect.
    AccountStatusGate accountStatus = const AlwaysActiveAccountStatusGate(),
  }) {
    // One-shot latch (per router instance) for the dev-seam route pin. The seam
    // must drive the INITIAL landing onto the pinned dev route, but must NOT
    // keep bouncing every later user-initiated push back to it — otherwise
    // screen 10's "New Location" → `/capture-location` and screen 13's pending
    // item → `/chat/:id` get redirected away the instant they're pushed and the
    // target never mounts. Once the seam has landed on its dev route (or the
    // app has otherwise moved off the default root), we stop forcing and let
    // any pushed location pass. Instance-scoped (not static) so parallel tests
    // and hot restarts each get a fresh latch.
    var devSeamLanded = false;
    // FR-P0-3: re-run redirects when the session changes (login/logout). Only
    // the real `SessionCubit` is a `Cubit`; the inert default gate has no stream
    // so it contributes nothing. `session` is captured by the `redirect` closure
    // below, which blocks flow promotion, so we narrow via an explicit cast.
    final Cubit<SessionState>? sessionCubit =
        session is Cubit<SessionState> ? session as Cubit<SessionState> : null;
    // JM-066: re-run redirects when the account status resolves/changes. The
    // inert default gate is not a `Cubit` and contributes nothing; the real
    // status cubit (JM-006/066) is a `BlocBase` and is bridged here.
    final BlocBase<Object?>? accountStatusBloc =
        accountStatus is BlocBase<Object?>
            ? accountStatus as BlocBase<Object?>
            : null;
    return GoRouter(
      initialLocation: '/',
      refreshListenable: _MergedRefreshListenable([
        _CubitRefreshListenable<bool>(onboarding),
        _CubitRefreshListenable<BiometricLockState>(biometricLock),
        if (sessionCubit != null)
          _CubitRefreshListenable<SessionState>(sessionCubit),
        if (accountStatusBloc != null)
          _BlocRefreshListenable(accountStatusBloc),
      ]),
      redirect: (context, state) {
        // Debug capture aid: drop straight onto the fixtures-backed chat
        // (chat selector wins over a generic route override).
        if (_devChat.isNotEmpty) {
          return state.matchedLocation == '/dev-chat' ? null : '/dev-chat';
        }

        // FR-P0-1: The DevSeam route pin may only BYPASS the first-run
        // (onboarding + session) gate when `DevSeamConfig.skipOnboarding` is
        // explicitly set. A bare `jeeb.route=/` / device-file / `JEEB_DEV_HOME`
        // no longer silently skips first-run: on a fresh install (onboarding
        // incomplete or no token) the first-run gate below wins and lands the
        // user on `/onboarding` (or `/register`), exactly like a real device.
        //
        // When skipOnboarding IS set, the pin keeps its original FULL bypass
        // (onboarding + session + biometric) + initial-landing-only latch so
        // authenticated screens (10/13/16/…) can be captured deterministically
        // from a single APK without seeding prefs or a token. This branch
        // returns early in every sub-case, exactly like the pre-FR-P0-1 code.
        if (_devRoute.isNotEmpty && _devSkipOnboarding) {
          final pinRedirect = _devRoutePinRedirect(state, () => devSeamLanded,
              (v) => devSeamLanded = v);
          // _noPin → not forcing → allow (null). Otherwise force the pin path.
          return pinRedirect == _noPin ? null : pinRedirect;
        }

        // First-run gate (FR-P0-1 onboarding + FR-P0-3 session). Runs for every
        // non-skip launch — including when a route is pinned WITHOUT
        // skipOnboarding, which is precisely how the silent bypass is closed.
        final firstRun =
            _firstRunRedirect(state, onboarding, session, accountStatus);
        if (firstRun != null) return firstRun;

        // Onboarded + authenticated. If a route is pinned (without skip) and the
        // first-run gate allowed us through, honour the pin's initial landing so
        // deep-capture of authenticated screens still works on a device whose
        // onboarding is already complete.
        if (_devRoute.isNotEmpty && !_devSkipOnboarding) {
          final pinRedirect = _devRoutePinRedirect(state, () => devSeamLanded,
              (v) => devSeamLanded = v);
          if (pinRedirect != _noPin) return pinRedirect;
        }

        // Biometric gate (T-mobile-005). Once onboarding has completed, hold
        // the user on `/lock` until the cubit reports unlocked/disabled. The
        // gate is a no-op before evaluation finishes (phase == unknown) so we
        // don't flash the lock screen during cold start.
        //
        // RC-9 (W0 jm-007 AC6, 61_W0_QA_RESULTS): the lock gate must NOT
        // capture a LOGGED-OUT user. A biometric-enrolled but token-less
        // returning user (`biometric_enrolled_logged_out`, 62_SEAM_HARNESS §3)
        // must land on `/login` — the first-run session gate above already
        // returned `/login` for that user, but the biometric preference can
        // still read `locked` from a prior session, so without this guard the
        // lock gate would re-capture them onto `/lock` (a dead end: there is no
        // session to unlock into). Guarding with `!session.isUnauthenticated`
        // means a present session is required before `/lock` can hold; a
        // logged-out user is left on `/login`. The `unknown` cold-start phase
        // keeps `isUnauthenticated == false`, so an enrolled+logged-in user
        // still locks normally (no regression to JM-005).
        final completed = onboarding.state;
        final loc = state.matchedLocation;
        final lockPhase = biometricLock.state.phase;
        if (completed &&
            !session.isUnauthenticated &&
            lockPhase == BiometricLockPhase.locked &&
            loc != _lockRoute) {
          return _lockRoute;
        }
        if (lockPhase != BiometricLockPhase.locked && loc == _lockRoute) {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          name: 'shell',
          builder: (context, state) => const ShellScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/register',
          name: 'register',
          builder: (context, state) => const RegistrationScreen(),
        ),
        GoRoute(
          path: _lockRoute,
          name: 'biometric-lock',
          // W0-INT (JM-005): real BiometricLockScreen (no longer the placeholder
          // empty-state). The W0-A engineer fills in the cubit-driven body.
          builder: (context, state) => const BiometricLockScreen(),
        ),
        // ── WAVE 0 auth funnel (CTO-D1 email-first; 21_NAV_PLAN §B batch W0,
        //    50_EXECUTION_PLAN §"Exact W0 integrator route additions"). These
        //    register the routes + reach their stub roots; the W0 engineers
        //    (JM-007/008/020/021/022) replace each screen body. `/register`
        //    above is kept as the reused phone-OTP verify step (JM-009).
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/sign-up',
          name: 'sign-up',
          builder: (context, state) => const SignUpScreen(),
        ),
        GoRoute(
          path: '/recover',
          name: 'recover-password',
          builder: (context, state) => const RecoverPasswordScreen(),
          routes: [
            // Nested verify-code step (JM-021). Email-based recovery, NOT
            // phone-anchored.
            GoRoute(
              path: 'verify',
              name: 'recover-verify',
              builder: (context, state) => const VerifyRecoveryCodeScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/set-password',
          name: 'set-password',
          // JM-022 / D90 dual exit: `?mode=recovery|in-app-social`. Defaults to
          // recovery (the most common entry) when absent/unrecognised (R-F).
          //
          // Recovery identity forwarding (50_ROUTE_REQUESTS JM-022): the
          // verify-code step (JM-021) hands `email` + `resetToken` to this route
          // via BOTH the query string AND `extra` (a `Map<String, String>`). The
          // recovery-mode submit needs `resetToken` to reach
          // `POST /v1/auth/set-password` (401 `invalid_token` otherwise,
          // 42_GUARDRAILS_MOCK W-1 FLOOR). We read the query params first (they
          // survive a cold reload of the URL), then fall back to the typed
          // `extra` Map; in-app-social mode supplies neither and renders fine.
          builder: (context, state) {
            final query = state.uri.queryParameters;
            final extra = state.extra;
            final extraMap =
                extra is Map<String, String> ? extra : const <String, String>{};
            final email = query['email'] ?? extraMap['email'] ?? '';
            final resetToken = query['resetToken'] ?? extraMap['resetToken'];
            return SetPasswordScreen(
              mode: SetPasswordMode.fromQuery(query['mode']),
              email: email,
              resetToken: resetToken,
            );
          },
        ),
        // JM-066 (D5): account-status stub root. The redirect-gate PREDICATE
        // lands in W0 (above, via [AccountStatusGate]); the full screen body is
        // W4.
        GoRoute(
          path: _accountStatusRoute,
          name: 'account-status',
          builder: (context, state) => const AccountStatusScreen(),
        ),
        // ── WAVE 1 core-customer-journey routes (W1-INT batch;
        //    21_NAV_PLAN §B batch W1; 50_EXECUTION_PLAN §"WAVE 1 (1)").
        //    Registered centrally BEFORE the per-screen engineers wire their
        //    call sites (CTO brief §6.7 navigation honesty + §7 isolation).
        //    Sheets (JM-029 accept-confirm, JM-030 cancel-confirm) and the
        //    JM-031 pinned header WIDGET are NOT routes.
        //
        // JM-028 offer-review-list: wire the orphaned ClientOffersScreen (it
        // self-provides ClientOffersCubit over sl<OffersRepository>(), with a
        // constructor test seam). `offerId` accept/cancel edges are the JM-028
        // engineer's call-site work (→ JM-029/JM-030 sheets).
        GoRoute(
          path: '/requests/:id/offers',
          name: 'offer-review',
          builder: (context, state) => ClientOffersScreen(
            requestId: state.pathParameters['id'] ?? '',
          ),
        ),
        // JM-026 waiting-no-coverage: targets the orphaned
        // no_offer_timeout_screen.dart for in-place REWRITE by the JM-026
        // engineer (count+countdown, no-coverage variant, review-offers /
        // retarget / cancel edges, signature id `waiting_no_coverage_root`).
        // The route points at the existing widget now so the path resolves and
        // the app compiles; the rewrite swaps the body without touching this
        // registration.
        GoRoute(
          path: '/requests/:id/waiting',
          name: 'waiting-no-coverage',
          builder: (context, state) => NoOfferTimeoutScreen(
            requestId: state.pathParameters['id'] ?? '',
          ),
        ),
        // JM-033 delivered-receipt: targets the orphaned
        // delivery_receipt_screen.dart for in-place REWRITE by the JM-033
        // engineer (D3 proof photo + "Pay $N cash to <Jeeber>" + NO commission
        // line; confirm → rate-jeeber, not-yet → dispute). Wrong contract today
        // (it renders a commission/finance receipt); the route resolves now and
        // the rewrite swaps the body.
        GoRoute(
          path: '/orders/:id/receipt',
          name: 'delivered-receipt',
          builder: (context, state) => DeliveryReceiptScreen(
            deliveryId: state.pathParameters['id'] ?? '',
          ),
        ),
        // JM-031 order-summary (CTO-D3): the pinned summary is PRIMARILY a
        // header widget in chat+tracking; THIS optional route is only the
        // navigable deep-link target for `transaction-detail →
        // order-summary-pinned` (JM-056, W3). Stub root now; JM-031 fills the
        // `extra`-driven body.
        GoRoute(
          path: '/orders/:id/summary',
          name: 'order-summary',
          builder: (context, state) => OrderSummaryScreen(
            deliveryId: state.pathParameters['id'] ?? '',
          ),
        ),
        GoRoute(
          path: '/orders/:id',
          name: 'delivery-detail',
          builder: (context, state) => DeliveryDetailScreen(
            deliveryId: state.pathParameters['id'] ?? '',
          ),
        ),
        GoRoute(
          path: '/orders/:id/cancel',
          name: 'delivery-cancel',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final isJeeber =
                state.uri.queryParameters['role'] == 'jeeber';
            return CancellationScreen(
              deliveryId: id,
              isJeeber: isJeeber,
            );
          },
        ),
        GoRoute(
          path: '/orders/:id/rate',
          name: 'rating-prompt',
          // B-3: the `rating-prompt` placeholder is superseded by the real
          // blind mutual-rating screen (T-MOB-020). Redirect this route — hit
          // from the post-delivery "rate" notification deep link
          // (notification_deep_link.dart) — to `/orders/:id/mutual-rate`,
          // carrying the delivery id (and any `mode` query param) through. The
          // [RatingPromptScreen] builder below is retained only as an
          // unreachable fallback so the placeholder file stays under the
          // Type-A discipline gate until T-MOB-RATING-001 formally lifts it.
          redirect: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            if (id.isEmpty) return null;
            final query = state.uri.query;
            final suffix = query.isEmpty ? '' : '?$query';
            return '/orders/$id/mutual-rate$suffix';
          },
          builder: (context, state) => RatingPromptScreen(
            deliveryId: state.pathParameters['id'] ?? '',
          ),
        ),
        GoRoute(
          path: '/chat/:id',
          name: 'chat-detail',
          builder: (context, state) => ChatDetailScreen(
            chatId: state.pathParameters['id'] ?? '',
            // Forwarded by the offer-accept-confirm sheet so the client's
            // "Track order" CTA is reachable on an order accepted from the
            // review list (the accept response's server-created deliveryId).
            initialDeliveryId: state.uri.queryParameters['deliveryId'],
          ),
        ),
        // Debug-only chat-capture seam; gated by [_devChat] in the redirect
        // above so it is unreachable in release builds.
        GoRoute(
          path: '/dev-chat',
          name: 'dev-chat',
          builder: (context, state) =>
              DevChatPreviewScreen(selector: _devChat),
        ),
        GoRoute(
          path: '/profile/kyc',
          name: 'kyc-status',
          // E-P0 fix: the old `KycStatusScreen` was a read-only status stub
          // with no way to actually start KYC, dead-ending profile_tab's
          // goNamed('kyc-status'). Surface the real wizard instead.
          // KycWizardScreen self-provides KycWizardCubit via DI when no cubit
          // is passed.
          builder: (context, state) => const KycWizardScreen(),
        ),
        // Delivery-man onboarding wizard (Figma 56591:5323 → 56591:4109 →
        // 56591:5337). Entered from the Delivery-tab upsell (screen 19). A
        // `step` query param (address|service-area) lets the dev seam / a deep
        // link land directly on a later step for deterministic capture.
        GoRoute(
          path: '/jeeber/onboarding',
          name: 'jeeber-onboarding',
          builder: (context, state) => DmOnboardingScreen(
            initialStep: DmOnboardingStep.fromSlug(
              state.uri.queryParameters['step'],
            ),
            onCompleted: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
        ),
        GoRoute(
          path: '/profile/customer',
          name: 'customer-profile',
          // Real callers hand the aggregated view data via `extra`. When it is
          // absent the debug-only fixture drives the dev-seam capture path
          // (`jeeb.route=/profile/customer`); in release we never render the
          // fixture (it carries PII) and instead show an unavailable state.
          builder: (context, state) {
            final extra = state.extra;
            if (extra is CustomerProfileViewData) {
              return CustomerProfileScreen(data: extra);
            }
            if (kDebugMode) {
              return const CustomerProfileScreen(
                data: DevCustomerProfileFixtures.sample,
              );
            }
            return const ProfileUnavailableScreen();
          },
        ),
        GoRoute(
          path: '/profile/delivery-man',
          name: 'delivery-man-profile',
          // Same pattern: typed `extra` from a real client tap drives the real
          // screen; the debug fixture only powers screen-27 capture; release
          // falls back to the unavailable state instead of fixture PII.
          builder: (context, state) {
            final extra = state.extra;
            if (extra is DeliveryManProfileViewData) {
              return DeliveryManProfileScreen(data: extra);
            }
            if (kDebugMode) {
              return const DeliveryManProfileScreen(
                data: DevDeliveryManProfileFixtures.sample,
              );
            }
            return const ProfileUnavailableScreen();
          },
        ),
        GoRoute(
          path: '/location',
          name: 'location-picker',
          builder: (context, state) => const LocationPickerScreen(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'profile',
              name: 'settings-profile',
              builder: (context, state) => const ProfileEditScreen(),
            ),
            GoRoute(
              path: 'addresses',
              name: 'settings-addresses',
              // T-MOB-025: replace placeholder with the real CRUD screen.
              builder: (context, state) => const SavedLocationsScreen(),
              routes: [
                // JM-050 address-detail-form (21_NAV_PLAN §B batch W1, P2).
                // Promotes add_edit_location_sheet.dart to a full screen. Stub
                // root now (`address_detail_form_root` + `address_form_save_cta`
                // signature ids); the JM-050 engineer fills the form + save.
                // `?id=` selects the edit path; absent = add.
                GoRoute(
                  path: 'edit',
                  name: 'address-detail',
                  builder: (context, state) => AddressDetailFormScreen(
                    addressId: state.uri.queryParameters['id'],
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'notifications',
              name: 'settings-notifications',
              builder: (context, state) =>
                  const NotificationPreferencesScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/voice-request',
          name: 'voice-request',
          // A-P1: wire the recording → transcription chain. The screen's
          // `onSent` now surfaces BOTH the transcription result id and the
          // optional machine transcript; the transcription route requires a
          // [VoiceClip] via `extra`. We bridge by wrapping both into a
          // VoiceClip here so the downstream screen reads `clip.transcript`
          // and lands on its happy path when the gateway returned the
          // transcript synchronously (null → the screen's queued/manual-entry
          // state). (The full clip surface is owned by the voice_request
          // feature; the router does the minimal-coupling bridge.)
          builder: (context, state) => VoiceRequestScreen(
            onSent: (clipId, transcript) => context.push(
              '/voice-request/transcription',
              extra: VoiceClip(
                audioPath: clipId,
                durationMs: 0,
                transcript: transcript,
              ),
            ),
          ),
        ),
        // The legacy `/tier-selection` route (TierSelectionScreen) was removed
        // here per the in-code CTO note: it was a dead duplicate of
        // `/request-type` with an unwired onConfirmed. The create flow now
        // standardizes on `/request-type`. TierSelectionScreen itself is kept
        // for its widget tests.
        // Delivery-create flow (Figma 56535:2392 → 56539:1444 → 56546:2303).
        GoRoute(
          path: '/request-type',
          name: 'request-type',
          builder: (context, state) => RequestTypeScreen(
            onChangeLocation: () => context.push('/client-location'),
            // A-P0: Continue producer. The screen owns the Continue CTA + tier
            // selection; the router supplies the navigation closure that
            // assembles a RequestDraft from the chosen [Tier] and pushes the
            // summary step. The Tier carries no free-text description, so the
            // draft description starts empty (the user fills it on the summary
            // screen); the tier id/name seed the quote.
            onTierSelected: (tier) => context.push(
              '/request-summary',
              extra: RequestDraft(
                description: '',
                tierId: tier.id.name,
                tierName: tier.id.name,
              ),
            ),
            // FIX-B: the sticky Continue CTA was a dead end — only the tier
            // card tap navigated. The screen already assembles a complete
            // [RequestDraft] (localized tier name + pickup) from the current
            // selection and hands it here; forward it to the SAME destination
            // the tier-card tap uses (`/request-summary`). No double-navigate:
            // tapping a card and pressing Continue are distinct user actions.
            onContinue: (draft) => context.push(
              '/request-summary',
              extra: draft,
            ),
          ),
        ),
        GoRoute(
          path: '/client-location',
          name: 'client-location',
          builder: (context, state) => ClientLocationScreen(
            onAddLocation: () => context.push('/capture-location'),
          ),
        ),
        GoRoute(
          path: '/capture-location',
          name: 'capture-location',
          // T-MOB-012: inject the live GoogleMap viewport. The controller is
          // created per build and tracks the centre under the fixed pin; the
          // "Pin Location" CTA returns that coordinate via `extra` on pop so
          // the upstream draft flow can read it. The screen's centre pin +
          // CTA chrome are owned by CaptureLocationScreen.
          builder: (context, state) {
            final controller = _newCaptureController();
            // The "centre on me" GPS button is only wired when DI is up
            // (production / integration). Router-only tests build the router
            // without configureDependencies(), so resolve the gateway
            // defensively — the map still renders, just without the GPS FAB.
            final gateway = sl.isRegistered<GeolocatorGeocaptureGateway>()
                ? sl<GeolocatorGeocaptureGateway>()
                : null;
            return CaptureLocationScreen(
              mapBuilder: (mapContext) => GoogleMapCaptureView(
                controller: controller,
                gateway: gateway,
              ),
              onPinned: () {
                if (context.canPop()) context.pop(controller.center);
              },
            );
          },
        ),
        GoRoute(
          path: '/voice-request/transcription',
          name: 'transcription',
          // T-MOB-TRANSCRIPT: the voice TRANSCRIPTION-RESULT step. The clip is
          // handed over via `extra` from the voice composer (audioId + optional
          // machine transcript). On confirm we assemble a [RequestDraft] from
          // the reviewed text and forward to the next create-request step
          // (`/request-summary`, the same target the `/request-type` path uses).
          // Re-record pops back to the composer.
          //
          // A cold deep-link can land here without a clip; rather than crash on
          // the cast we fall back to an empty clip so the screen renders its
          // queued/manual-entry state.
          builder: (context, state) {
            final extra = state.extra;
            final clip = extra is VoiceClip
                ? extra
                : const VoiceClip(audioPath: '', durationMs: 0);
            return TranscriptionScreen(
              clip: clip,
              onConfirm: (text, audioPath) => context.push(
                '/request-summary',
                extra: RequestDraft(
                  description: text,
                  transcription: text,
                  audioUrl: audioPath.isEmpty ? null : audioPath,
                ),
              ),
              onReRecord: () {
                if (context.canPop()) context.pop();
              },
            );
          },
        ),
        GoRoute(
          path: '/jeeber/requests/:id/offer',
          name: 'jeeber-offer-submission',
          // T-MOB-030: Bid composition entry-point with full form wired to
          // POST /v1/offers. Navigates to chat on success; pops to feed on 409.
          builder: (context, state) {
            final requestId = state.pathParameters['id'] ?? '';
            return OfferSubmissionScreen(
              requestId: requestId,
              submissionService: sl<OfferSubmissionService>(),
              repository: sl<OfferSubmissionRepository>(),
              onWithdrawn: () {
                if (context.canPop()) context.pop();
              },
              onSubmitted: (conversationId) {
                context.go('/chat/$conversationId');
              },
              onRequestGone: () {
                if (context.canPop()) context.pop();
              },
            );
          },
        ),
        GoRoute(
          path: '/jeeber/requests/:id',
          name: 'jeeber-request-detail',
          // Two entry-points share this route (T-mobile-013):
          //   1. In-app feed tap — the dashboard hands over the
          //      [FeedRequest] payload via `extra` so the detail screen
          //      renders without a round-trip.
          //   2. Push notification tap — no `extra`, just the id in the
          //      path. We recover the payload from the
          //      [RequestFeedService] cache the dashboard subscription
          //      keeps warm. The request may already have been closed
          //      (matched / cancelled / expired) between the push
          //      enqueue and the user's tap, in which case we surface
          //      the "no longer available" screen instead of crashing.
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final extra = state.extra;
            final fromExtra = extra is FeedRequest ? extra : null;
            final resolved = fromExtra ??
                (sl.isRegistered<RequestFeedService>()
                    ? sl<RequestFeedService>().findById(id)
                    : null);
            if (resolved == null) {
              return JeeberRequestUnavailableScreen(
                requestId: id,
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              );
            }
            return JeeberRequestDetailScreen(
              request: resolved,
              reportService: sl<ProhibitedItemReportService>(),
              onDeclined: (_) {
                if (context.canPop()) context.pop();
              },
            );
          },
        ),
        GoRoute(
          path: '/request-summary',
          name: 'request-summary',
          // The aggregated draft is handed over via `extra` from the upstream
          // step that owns the full request-creation flow (T-mobile-012).
          // A cold deep-link can land here without a draft (or with a
          // wrong-typed payload) — defensively type-check and fall back to a
          // graceful empty-state scaffold instead of crashing on the cast.
          builder: (context, state) {
            final extra = state.extra;
            if (extra is! RequestDraft) {
              return const RequestSummaryUnavailableScreen();
            }
            return BlocProvider<RequestSummaryCubit>(
              create: (_) =>
                  RequestSummaryCubit(sl<RequestSubmissionService>())
                    ..setDraft(extra),
              child: const RequestSummaryScreen(),
            );
          },
        ),
        GoRoute(
          path: '/orders/:id/tracking',
          name: 'live-tracking',
          builder: (context, state) {
            // S9 live-tracking fix: the delivery's REAL server-created id
            // (`delivery-<offerId>`) is returned in the accept/offer response
            // and is NOT derivable from the request id the path `:id` often
            // carries. `GET /v1/delivery/<requestId>` 404s. Callers that hold
            // the server id pass it as `?deliveryId=`; it takes precedence over
            // `:id` so the delivery-service lookup resolves. Falls back to the
            // path `:id` for legacy callers + the dev seam. Mirrors the
            // `chat-detail` route's `deliveryId` query-param plumbing.
            final deliveryId = resolveTrackingDeliveryId(
              routeId: state.pathParameters['id'],
              queryDeliveryId: state.uri.queryParameters['deliveryId'],
            );
            // T-MOB-017: render the deterministic placeholder (not a live
            // GoogleMap) when the dev seam is driving a `/tracking` capture —
            // no Maps key / unstable emulator on that path. Every other run
            // renders the live polyline + marker map.
            final useLiveMap =
                !(kDebugMode && _devRoute.contains('/tracking'));
            return BlocProvider<LiveTrackingCubit>(
              create: (_) => LiveTrackingCubit(
                repository: _trackingRepository(),
                deliveryId: deliveryId,
              ),
              child: LiveTrackingScreen(
                deliveryId: deliveryId,
                useLiveMap: useLiveMap,
              ),
            );
          },
        ),
        GoRoute(
          path: '/orders/:id/otp',
          name: 'otp-handover',
          builder: (context, state) {
            final deliveryId = state.pathParameters['id'] ?? '';
            final isClient = state.uri.queryParameters['mode'] != 'jeeber';
            return BlocProvider<OtpHandoverCubit>(
              create: (_) => OtpHandoverCubit(
                repository: sl<OtpHandoverRepository>(),
                deliveryId: deliveryId,
                isClient: isClient,
              ),
              child: OtpHandoverScreen(
                deliveryId: deliveryId,
                isClient: isClient,
              ),
            );
          },
        ),
        // Feedback / rating screen (Figma 56614:20132). `mode=jeeber` flips the
        // audience so the delivery man rates the client; `name` seeds the
        // ratee for capture. Distinct from the frozen `/orders/:id/rate`
        // placeholder (RatingPromptScreen, Type-A CI gate).
        GoRoute(
          path: '/orders/:id/feedback',
          name: 'feedback',
          builder: (context, state) {
            final deliveryId = state.pathParameters['id'] ?? '';
            final isClient = state.uri.queryParameters['mode'] != 'jeeber';
            return RatingScreen(
              deliveryId: deliveryId,
              isClient: isClient,
              rateeName: state.uri.queryParameters['name'] ?? '',
            );
          },
        ),
        // T-MOB-020: Mutual blind rating screen. `mode=jeeber` flips to
        // delivery-man rating the client. Both see stars + comment until
        // counterpart also rates (or 7-day auto-reveal).
        GoRoute(
          path: '/orders/:id/mutual-rate',
          name: 'mutual-rating',
          builder: (context, state) {
            final deliveryId = state.pathParameters['id'] ?? '';
            final isClient = state.uri.queryParameters['mode'] != 'jeeber';
            return BlocProvider<MutualRatingCubit>(
              create: (_) => MutualRatingCubit(
                repository: sl<RatingRepository>(),
                deliveryId: deliveryId,
                isClient: isClient,
              ),
              child: const MutualRatingScreen(),
            );
          },
        ),
        // T-MOB-022: Escalate/dispute screen. Accessible from delivery detail
        // and OTP-failed flow. Multipart POST to /v1/deliveries/{id}/escalate.
        GoRoute(
          path: '/orders/:id/escalate',
          name: 'escalate',
          builder: (context, state) {
            final deliveryId = state.pathParameters['id'] ?? '';
            return BlocProvider<EscalateCubit>(
              create: (_) => EscalateCubit(
                repository: sl<EscalateRepository>(),
                deliveryId: deliveryId,
              ),
              child: const EscalateScreen(),
            );
          },
        ),
        // T-MOB-031: Jeeber active-delivery screen.
        // Path: /jeeber/deliveries/:id/active
        GoRoute(
          path: '/jeeber/deliveries/:id/active',
          name: 'jeeber-active-delivery',
          builder: (context, state) {
            final deliveryId = state.pathParameters['id'] ?? '';
            return ActiveDeliveryJeeberScreen(
              deliveryId: deliveryId,
              repository: sl<ActiveDeliveryRepository>(),
              onOpenChat: () {
                if (context.canPop()) context.pop();
              },
              onOpenOtp: () {
                context.go('/orders/$deliveryId/otp?mode=jeeber');
              },
              // Sprint 2 Stream G: the Jeeber declares the goods cost for this
              // delivery (the amount the Client reimburses on receipt, D11).
              // Pushes the goods-cost screen, which pops with the
              // gateway-confirmed [GoodsCost]; we don't need the result here
              // beyond confirming entry, so the future is fire-and-forget.
              onEnterGoodsCost: () {
                context.push('/orders/$deliveryId/goods-cost');
              },
              // JM-051 AC2 (C7 wiring gap, 66_W2_QA_RESULTS): once the delivery
              // reaches `Done` the jeeber goes to the MANDATORY mutual rating
              // (NOT OTP), in jeeber mode — matching the W1 journey contract
              // (62 §W1-0 `/orders/:id/mutual-rate?mode=jeeber`). This was the
              // missing leg: the screen fired `onMarkedDelivered` but the route
              // passed no callback, so mark-delivered completed (stepper filled)
              // yet never opened the rating screen (`rating_submit_cta`).
              onMarkedDelivered: () {
                context.go('/orders/$deliveryId/mutual-rate?mode=jeeber');
              },
              // T-MOB-031 AC4: open destination in Google Maps via url_launcher.
              mapsUrlBuilder: (url) => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
            );
          },
        ),

        // Sprint 2 Stream G (goods-cost): the Jeeber declares how much the
        // purchased goods cost for a delivery (the amount the Client reimburses
        // on receipt — D11). Delivery-scoped, so it sits with the other
        // `/orders/:id/...` jeeber-action routes. The screen self-provides
        // GoodsCostCubit and self-resolves GoodsCostRepository from DI (now
        // registered in injection_container.dart) — falling back to the Dio
        // impl over sl<Dio>() when the explicit binding is absent. It pops with
        // the gateway-confirmed [GoodsCost] (amount + currency verbatim), which
        // the caller (active-delivery action) reads off the push() future.
        GoRoute(
          path: '/orders/:id/goods-cost',
          name: 'goods-cost',
          builder: (context, state) => GoodsCostScreen(
            deliveryId: state.pathParameters['id'] ?? '',
          ),
        ),

        // T-MOB-032: Settlement statement list.
        GoRoute(
          path: '/jeeber/settlement',
          name: 'jeeber-settlement',
          builder: (context, state) => SettlementScreen(
            repository: sl<SettlementRepository>(),
            onTapStatement: (statement) {
              context.push(
                '/jeeber/settlement/${statement.id}',
                extra: statement,
              );
            },
            // T-MOB-032 AC3: open downloaded PDF using open_file package.
            onOpenPdf: (path) => OpenFile.open(path),
          ),
        ),

        // T-MOB-032: Settlement statement detail (per-delivery breakdown).
        GoRoute(
          path: '/jeeber/settlement/:id',
          name: 'jeeber-settlement-detail',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is SettlementStatement) {
              return SettlementDetailScreen(statement: extra);
            }
            return Scaffold(
              body: Center(
                child: Text(AppLocalizations.of(context).statementNotFound),
              ),
            );
          },
        ),

        // ── WAVE 2 / 2.5 jeeber onboarding/offering + wallet routes (W2-INT
        //    batch; 21_NAV_PLAN §B batch W2 + the W3 wallet routes front-loaded
        //    so W2.5 runs inside W2; 50_EXECUTION_PLAN §WAVE 2 (1)). Registered
        //    centrally BEFORE the per-screen engineers wire their call sites
        //    (CTO brief §6.7 navigation honesty + §7 isolation). The bodies are
        //    compiling integrator STUBS; the JM-041/043/044/047/053/054 engineers
        //    fill them. Sheets (JM-046 insufficient-balance) and the JM-037/038/
        //    039/040 D20/D51 wizard fixes are NOT routes (widget/cubit edits
        //    inside the existing /jeeber/onboarding + /profile/kyc routes).

        // JM-041 onboarding-funding — starter-credit explainer after KYC submit
        // (D42/D1; Top up → wallet-charge-info; Continue → kyc-pending-status).
        GoRoute(
          path: '/jeeber/onboarding/funding',
          name: 'onboarding-funding',
          builder: (context, state) => const OnboardingFundingScreen(),
        ),
        // JM-044 offer-kyc-gate — the D38 interstitial routed through when an
        // UNAPPROVED jeeber taps make-offer (approved skips it → composer).
        GoRoute(
          path: '/jeeber/offer-gate',
          name: 'offer-kyc-gate',
          builder: (context, state) => const OfferKycGateScreen(),
        ),
        // JM-044 delivery-register-prompt — the standalone register prompt the
        // offer-KYC gate's `gate_register_link` navigates to (RD-1 fix). Renders
        // `delivery_register_prompt` unconditionally (the DELIVERY tab body's
        // prompt is gate-state-dependent, so a pop-back was wrong — 66 RD-1).
        GoRoute(
          path: '/jeeber/register-prompt',
          name: 'delivery-register-prompt',
          builder: (context, state) => const DeliveryRegisterPromptScreen(),
        ),
        // JM-043 kyc-rejected — appeal-via-support only, NO resubmit (D52/D87).
        GoRoute(
          path: '/kyc/rejected',
          name: 'kyc-rejected',
          builder: (context, state) => const KycRejectedScreen(),
        ),
        // JM-047 jeeber-pending-offers — submitted offers awaiting decision +
        // withdraw (D15). The blueprint allows this as a feed sub-tab too
        // (21_NAV_PLAN §A); the route is registered (per the work order) so the
        // screen is reachable both ways.
        GoRoute(
          path: '/jeeber/pending-offers',
          name: 'jeeber-pending-offers',
          builder: (context, state) => const JeeberPendingOffersScreen(),
        ),
        // JM-053 wallet-hub — REPLACES the T-MOB-024 "Wallet — coming soon" stub
        // (21_NAV_PLAN §A: exists-stub → REPLACE). Balance/affordability/
        // reserved-now/gift (D1/D42/D43). Self-provides WalletHubCubit over
        // sl<WalletRepository>() — the INTEGRATOR-STUB wallet repo until W1m
        // lands (CTO-D2). The header wallet chip (`*_wallet_chip`) targets this
        // route by name (`goNamed('wallet')`).
        GoRoute(
          path: '/wallet',
          name: 'wallet',
          builder: (context, state) => const WalletHubScreen(),
        ),
        // JM-054 wallet-charge-info — static, no-payment instructional screen
        // (D92/D93). Every "+ Top up" CTA across the app targets this route.
        GoRoute(
          path: '/wallet/charge-info',
          name: 'wallet-charge-info',
          builder: (context, state) => const WalletChargeInfoScreen(),
        ),
        // JM-052 earnings — the earnings-fees dashboard as a standalone route
        // (R-4, jm-053). The dashboard otherwise lives only as the jeeber
        // Earnings shell tab; the wallet hub's `wallet_earnings_row` needs a
        // named target (`goNamed('earnings')`), so the same [EarningsTab]
        // (which wires EarningsCubit over sl<EarningsRepository>() with the
        // session jeeber id) is mounted here. Single source of truth — no
        // duplicated provider wiring, so the route can never drift from the tab.
        GoRoute(
          path: '/earnings',
          name: 'earnings',
          builder: (context, state) => const EarningsTab(),
        ),

        // ── WAVE 3 wallet ledger routes (W3-INT batch; 21_NAV_PLAN §B batch
        //    W3; 50_EXECUTION_PLAN §"WAVE 3 (1)"). Registered centrally BEFORE
        //    the per-screen engineers wire their call sites (CTO brief §6.7
        //    navigation honesty + §7 isolation). The bodies are compiling
        //    integrator STUBS; the JM-055/056 engineers fill them.

        // JM-055 wallet-activity-list — the typed ledger (W2m LIVE on :4010 →
        // real Dio in DI). Inbound: wallet-hub `wallet_see_all_activity`,
        // earnings `earnings_activity_link`. Tap a row → transaction-detail.
        GoRoute(
          path: '/wallet/activity',
          name: 'wallet-activity',
          builder: (context, state) => const WalletActivityListScreen(),
        ),
        // JM-056 transaction-detail — per-type ledger row detail (W3m NOT live
        // → INTEGRATOR-STUB repo, CTO-D2). `transaction-detail →
        // order-summary-pinned` deep-link (JM-056) targets the optional
        // `/orders/:id/summary` route added in W1 (CTO-D3).
        GoRoute(
          path: '/wallet/transactions/:id',
          name: 'transaction-detail',
          builder: (context, state) => TransactionDetailScreen(
            transactionId: state.pathParameters['id'] ?? '',
          ),
        ),

        // ── WAVE 4 shared routes (W4-INT batch; 21_NAV_PLAN §B batch W4;
        //    50_EXECUTION_PLAN §"WAVE 4 (1)"). Registered centrally BEFORE the
        //    per-screen engineers wire their call sites. The bodies are
        //    compiling integrator STUBS (JM-057/063/065/068) + the registered
        //    existing language screen (JM-059) + the password stub (JM-061);
        //    `/account-status` body (JM-066) was fleshed in
        //    account_status_screen.dart (gate seeded in W0). Sheets/dialogs
        //    (JM-062 logout-delete confirm) + native (JM-064 rate-the-app) are
        //    NOT routes.

        // JM-057 notifications-list — the shared inbox the header bell now
        // routes to (the shell `*_bell` guard is removed; goNamed('notifications')
        // is honest). Notification-service list+read LIVE → real Dio in DI.
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          builder: (context, state) => const NotificationsListScreen(),
        ),
        // JM-063 support-ticket — contact-us / ticket (S1 NOT live →
        // INTEGRATOR-STUB repo). Inbound: account-status, dispute-status,
        // kyc-rejected, customer-profile contact row (D76).
        GoRoute(
          path: '/support',
          name: 'support-ticket',
          builder: (context, state) => const SupportTicketScreen(),
        ),
        // JM-065 dispute-status — Open/Resolved + outcome (D2). Disputes
        // GET-by-id LIVE on :4010 → real Dio in DI.
        GoRoute(
          path: '/disputes/:id',
          name: 'dispute-status',
          builder: (context, state) => DisputeStatusScreen(
            disputeId: state.pathParameters['id'] ?? '',
          ),
        ),
        // JM-068 reviews-list — the All-reviews list (R1m NOT live →
        // INTEGRATOR-STUB repo). Inbound: jeeber-profile-reviews
        // `profile_view_all_reviews` (JM-067). `?jeeberId=` selects the jeeber.
        GoRoute(
          path: '/profile/delivery-man/reviews',
          name: 'reviews-list',
          builder: (context, state) => ReviewsListScreen(
            jeeberId: state.uri.queryParameters['jeeberId'],
          ),
        ),
        // JM-068 path-param form — the flow pins
        // `/profile/delivery-man/<jeeberId>/reviews`. Same screen; the jeeber
        // id comes from the path segment (or `?jeeberId=` if also present).
        GoRoute(
          path: '/profile/delivery-man/:jeeberId/reviews',
          name: 'reviews-list-by-id',
          builder: (context, state) => ReviewsListScreen(
            jeeberId: state.pathParameters['jeeberId'] ??
                state.uri.queryParameters['jeeberId'],
          ),
        ),
        // JM-059 language-settings — register the EXISTING screen at its
        // blueprint path. LocaleCubit is provided globally above the router
        // (app.dart), so the screen resolves it from context. Note: distinct
        // from the legacy `/settings/notifications` etc. nested under `/settings`
        // — the blueprint models language as its own screen from customer-profile.
        GoRoute(
          path: '/settings/language',
          name: 'language-settings',
          builder: (context, state) => const LanguageSettingsScreen(),
        ),
        // JM-061 password-security — current/new/confirm + social-only "set
        // password" entry → auth-set-password (D90). No mock dependency.
        GoRoute(
          path: '/settings/password',
          name: 'password-security',
          builder: (context, state) => const PasswordSecurityScreen(),
        ),
        // Sprint-5 Stream C: free-text search. `/search` is the compose
        // surface (search bar + prompt) reached from the shell header search
        // affordance (`*_search` → `goNamed('search')`); submitting forwards
        // to `/search-results?q=` which runs the query against the gateway
        // search BFF (DioSearchRepository over sl<SearchRepository>()) and
        // renders the 4-state machine. When `/v1/search` is absent the repo
        // surfaces an honest "search isn't available yet" empty state — no
        // dead-end. The `q` query param makes a results link shareable +
        // process-death-safe.
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/search-results',
          name: 'search-results',
          builder: (context, state) => SearchResultsScreen(
            query: state.uri.queryParameters['q'] ?? '',
          ),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text(
            AppLocalizations.of(context).routeNotFound('${state.uri}'),
          ),
        ),
      ),
    );
  }
}

/// Bridges a [Cubit] to go_router's [Listenable] contract so route redirects
/// re-evaluate whenever the cubit emits a new state.
class _CubitRefreshListenable<T> extends ChangeNotifier {
  _CubitRefreshListenable(Cubit<T> cubit) {
    _subscription = cubit.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<T> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Bridges any [BlocBase] (Cubit/Bloc of an unconstrained state type) to
/// go_router's [Listenable]. Used for the account-status gate (JM-066), whose
/// concrete cubit's state type is owned by the JM-006/066 engineer and is not
/// known at the router layer.
class _BlocRefreshListenable extends ChangeNotifier {
  _BlocRefreshListenable(BlocBase<Object?> bloc) {
    _subscription = bloc.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Fans changes from multiple listenables into a single [Listenable] so
/// `GoRouter.refreshListenable` only has to subscribe once.
class _MergedRefreshListenable extends ChangeNotifier {
  _MergedRefreshListenable(this._children) {
    for (final child in _children) {
      child.addListener(notifyListeners);
    }
  }

  final List<Listenable> _children;

  @override
  void dispose() {
    for (final child in _children) {
      child.removeListener(notifyListeners);
      if (child is ChangeNotifier) child.dispose();
    }
    super.dispose();
  }
}
