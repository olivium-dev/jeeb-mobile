import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dev_seam/dev_seam.dart';
import '../session/account_status_gate.dart';
import '../session/session_gate.dart';
import '../session/session_state.dart';
import 'profile_unavailable_screen.dart';
import 'root_aware_back_scope.dart';
import '../../features/account_status/presentation/account_status_screen.dart';
import '../../features/auth/presentation/set_password_screen.dart';
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
import '../../features/jeeber_request_detail/presentation/jeeber_request_detail_loader.dart';
import '../../features/jeeber_request_feed/data/request_feed_repository.dart';
import '../../features/live_tracking/application/live_tracking_cubit.dart';
import '../../features/live_tracking/data/demo_live_tracking_repository.dart';
import '../../features/live_tracking/domain/live_tracking_repository.dart';
import '../../features/live_tracking/presentation/live_tracking_screen.dart';
import '../../features/delivery_receipt/presentation/delivery_receipt_screen.dart';
import '../../features/location/presentation/capture_location_screen.dart';
import '../../features/location/presentation/client_location_screen.dart';
import '../../features/location/presentation/screens/address_detail_form_screen.dart';
import '../../features/location/presentation/screens/location_picker_screen.dart';
import '../../features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';
import '../../features/order_summary/presentation/order_summary_screen.dart';
import '../../features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import '../../features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../../features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';
import '../../features/photo_attachment/domain/photo_picker_service.dart';
import '../../features/offers/domain/offer_submission_repository.dart';
import '../../features/offers/domain/offer_submission_service.dart';
import '../../features/offers/presentation/offer_submission_screen.dart';
import '../../features/settlement/domain/settlement_repository.dart';
import '../../features/settlement/domain/settlement_statement.dart';
import '../../features/settlement/presentation/settlement_detail_screen.dart';
import '../../features/settlement/presentation/settlement_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/otp_handover/application/otp_handover_cubit.dart';
import '../../features/otp_handover/domain/handover_code_store.dart';
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
import '../../features/settings/presentation/screens/live_settings_screen.dart';
import '../../features/request_type/presentation/request_type_screen.dart';
import '../../features/shell/shell_screen.dart';
import '../../features/shell/tabs/earnings_tab.dart';
import '../../features/transcription/domain/voice_clip.dart';
import '../../features/transcription/presentation/transcription_screen.dart';
import '../../features/voice_request/presentation/voice_request_screen.dart';
import '../di/injection_container.dart';
import '../diagnostics/diagnostics.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../onboarding/onboarding_cubit.dart';

/// `/capture-location` route host (B-35).
///
/// JEBV4-176: this placeholder route has NO live draggable map injected yet
/// (B-23, Maps SDK key owner-gated), so there is NO real user-picked coordinate
/// to return. It therefore refuses to fabricate one. Previously it seeded a
/// `MapCaptureController` with a hardcoded Beirut-downtown centre
/// (`33.8938, 35.5018`) and popped THAT back on "Pin Location", so — because
/// the neutral [CaptureMapViewport] placeholder never pans — every confirmed
/// pin silently collapsed to downtown Beirut and could create a Beirut-pinned
/// request. That silent fabrication is exactly what JEBV4-176 removes.
///
/// Now "Pin Location" pops with NO coordinate. client-location's `markPinned`
/// then records the pinned CHOICE but no point, and [LocationSelectState]
/// keeps that choice un-confirmable (Confirm stays disabled) — the same honest
/// gating the GPS-recovery path uses, so no fabricated coordinate can reach a
/// created request. Once B-23 injects a live `GoogleMap` `mapBuilder` here,
/// wire a `MapCaptureController` whose camera-idle writes the REAL point and
/// pop that instead.
@visibleForTesting
class CaptureLocationRoute extends StatelessWidget {
  const CaptureLocationRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return CaptureLocationScreen(
      // JEBV4-176: no live map → no real picked point → pop WITHOUT a
      // coordinate rather than fabricate the old Beirut default. Once a live
      // map is injected, pass its `mapBuilder` and pop the real camera centre.
      onPinned: () {
        if (context.canPop()) context.pop();
      },
    );
  }
}

/// Top-level router.
///
/// First-launch gate (two layers, FR-P0-1 + FR-P0-3):
///   1. While [OnboardingCubit.state] is `false`, the user is kept on
///      `/onboarding` or `/register` (the only pre-auth destinations).
///   2. Once onboarding completes, the [SessionGate] gate keeps an
///      onboarded-but-tokenless user on `/register` until a valid token exists,
///      so Home is unreachable without logging in.
/// Once the user finishes onboarding AND has a valid session the redirect lets
/// `/` (the shell) render normally. `refreshListenable` re-evaluates redirects
/// whenever onboarding, the biometric lock, or the session emits.
///
/// The debug-only DevSeam route pin can still drive deterministic capture of
/// authenticated screens, but (FR-P0-1) it may only *bypass* the onboarding +
/// session gates when [DevSeamConfig.skipOnboarding] is explicitly set — a bare
/// `jeeb.route=/` / `JEEB_DEV_HOME=true` on a fresh install now lands on
/// `/onboarding`, not Home.

/// S007-P1B: normalizes an inbound custom-scheme chat deep link into the
/// canonical `/chat/:id` route.
///
/// A `VIEW` intent like `jeeb://chat/<conversationId>` parses to
/// `scheme=jeeb, host=chat, path=/<conversationId>`, so go_router would
/// otherwise try to match `/<conversationId>` and miss `chat-detail`. We detect
/// the `host == 'chat'` shape and rewrite it to `/chat/<id>`. Returns `null`
/// for everything else — in-app navigation (`host == ''`) and HTTPS App Links
/// (`https://<domain>/chat/<id>`, already path-shaped) are untouched.
@visibleForTesting
String? normalizeChatDeepLink(Uri uri) {
  if (uri.host != 'chat') return null;
  final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
  return id.isEmpty ? null : '/chat/$id';
}

/// Resolves the id the live-tracking surface should load (S9 P0, restored
/// after an integration merge dropped it while keeping its test + the CTAs
/// that thread the query param). The delivery's REAL server-created id
/// (`delivery-<offerId>`) is surfaced in the accept/offer response and
/// forwarded by CTAs as the `?deliveryId=` query param. It takes precedence
/// over the path `:id`, which for many entry points carries the parent REQUEST
/// id — a value the delivery-service answers with 404 ("Delivery not found").
/// Falls back to the path id when no query param is present (legacy callers +
/// dev seam).
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

/// Folds a generic `jeeb://<host>/<path...>` custom-scheme VIEW intent into the
/// canonical in-app route by treating the URI host as the FIRST path segment.
///
/// A `VIEW` intent like `jeeb://jeeber/requests/<id>/offer` parses to
/// `scheme=jeeb, host=jeeber, path=/requests/<id>/offer`. go_router matches on
/// `state.uri.path`, which is only `/requests/<id>/offer` — the `jeeber` host is
/// dropped, so the route never resolves. Worse, a naive `'/' + host + '/' +
/// path` produced a double slash (`/jeeber//requests/...`). We rebuild the path
/// as `/<host><path>` (path already carries its own leading slash), preserving
/// any query string.
///
/// Returns `null` for non-`jeeb` schemes (HTTPS App Links are left to go_router
/// native matching) and for host-less `jeeb:/…` URIs (nothing to fold in).
/// [normalizeChatDeepLink] is applied first, so `jeeb://chat/<id>` keeps its
/// dedicated handling; this is the general fallback for every other host.
@visibleForTesting
String? normalizeJeebSchemeDeepLink(Uri uri) {
  if (uri.scheme != 'jeeb' || uri.host.isEmpty) return null;
  final path = '/${uri.host}${uri.path}';
  return uri.hasQuery ? '$path?${uri.query}' : path;
}

class AppRouter {
  AppRouter._();

  // Pre-auth destinations a logged-out user may reach WITHOUT the first-run
  // session gate bouncing them back. The hidden email/password funnel
  // (`/login`, `/sign-up`, `/recover`, `/recover/verify`) was removed in
  // JEBV4-199 (Q-044); `/register` is now the sole phone-OTP auth entry, with
  // Apple/Google social offered on it. `/set-password` survives for the
  // authenticated password-security settings path (JM-061) and is retained here
  // only for defensive routing (the gate lets it through when authenticated).
  static const Set<String> _preAuthRoutes = {
    '/onboarding',
    '/register',
    '/set-password',
  };
  static const String _lockRoute = '/lock';

  /// JM-066 (D5): the account-status gate target. A blocked account
  /// (`status ∈ {suspended, locked}`) is forced here and ALL tabs are blocked.
  static const String _accountStatusRoute = '/account-status';

  /// True when [loc] is one of the pre-auth destinations.
  static bool _isPreAuth(String loc) => _preAuthRoutes.contains(loc);

  /// Debug-only chat-capture selector, resolved at RUNTIME from [DevSeam]
  /// (replaces the compile-time `JEEB_DEV_CHAT`). When non-empty the router
  /// lands on the full-screen [DevChatPreviewScreen] for the requested chat
  /// state — `broadcasting`, `accepted`, `dm`, `dm-order-picked`,
  /// `dm-confirm-picking`, `dm-confirm-heading-off`. Empty in release.
  static String get _devChat => kDebugMode ? DevSeam.current.chatSelector : '';

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
  static const String _noPin = ' __no_pin__';

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
  ///       → `/register` (the phone-OTP auth entry, with Apple/Google social;
  ///       the hidden email/password `/login` funnel was removed, JEBV4-199)
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
  /// never flash `/register` while the keystore read is in flight. Likewise the
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
    // FR-P0-3: onboarded-but-tokenless user must authenticate before reaching
    // Home. Lands on the phone-OTP entry (`/register`, with Apple/Google social)
    // — the hidden email/password `/login` funnel was removed (JEBV4-199).
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

  /// Logical BACK parent for every route that can become the stack ROOT — i.e.
  /// be reached via a stack-REPLACING `context.go(...)`/`goNamed(...)`, an
  /// inbound platform deep link, or a push-notification tap (`GoRouter.go`).
  /// Keyed by route NAME (unique and stable; nested route `path`s are relative,
  /// so name is the correct key). [_wrapRootAware] wraps each named route's
  /// builder in a [RootAwareBackScope] with this fallback, so the system BACK
  /// gesture ALWAYS resolves to a parent instead of exiting the app to the
  /// launcher.
  ///
  /// `context.canPop()` is evaluated first inside the scope, so a normally
  /// PUSHED screen still pops to its real parent; the fallback is only consumed
  /// at the true stack root. `/` is safe as a universal fallback because the
  /// first-run redirect re-routes it to the correct destination for the user's
  /// auth state (Home when authenticated, `/onboarding` or `/register`
  /// otherwise), so a wrapped screen can never strand a logged-out user on Home.
  ///
  /// EXCLUSIONS — routes deliberately ABSENT here (never wrapped), and why:
  ///   * tab/home + first-run roots (`shell`, `onboarding`, `register`):
  ///     BACK there legitimately exits the app; wrapping would trap the user
  ///     (BACK could never leave).
  ///   * gate screens (`biometric-lock`, `account-status`): BACK must not
  ///     bypass the lock / blocked-account gate.
  ///   * mandatory blind-rating screens (`feedback`, `mutual-rating`): they
  ///     suppress BACK with `PopScope(canPop: false)`; a `BackButtonListener`
  ///     fires BEFORE `Navigator.maybePop`/`PopScope` and would preempt that
  ///     guard, so they must NOT be wrapped.
  ///   * screens that ALREADY self-wrap in [RootAwareBackScope]
  ///     (`delivery-detail`, `settings-addresses`, `jeeber-offer-submission`):
  ///     wrapping again is redundant and would shadow their tuned fallbacks.
  ///   * `rating-prompt` (a redirect-only Type-A placeholder) and `dev-chat`
  ///     (debug-only) — never a real user destination.
  @visibleForTesting
  static const Map<String, String> backFallbacks = {
    // ── set-password (JM-061 password-security; the email/password sign-in
    //    funnel that used to sit alongside it was removed in JEBV4-199).
    'set-password': '/',
    // ── W1 core customer journey.
    'offer-review': '/',
    'waiting-no-coverage': '/',
    'delivered-receipt': '/',
    'order-summary': '/',
    'delivery-cancel': '/',
    'chat-detail': '/',
    'kyc-status': '/',
    'jeeber-onboarding': '/',
    'customer-profile': '/',
    'delivery-man-profile': '/',
    'location-picker': '/',
    'settings': '/',
    'settings-profile': '/settings',
    'address-detail': '/settings/addresses',
    'settings-notifications': '/settings',
    'voice-request': '/',
    'request-type': '/',
    'client-location': '/',
    'capture-location': '/',
    'transcription': '/',
    // G1 compose-dictation pair: pushed from the compose description field;
    // as a cold stack root BACK falls back to the shell like its voice-flow
    // siblings above.
    'compose-dictation': '/',
    'compose-dictation-review': '/',
    'jeeber-request-detail': '/',
    'request-summary': '/',
    'live-tracking': '/',
    'otp-handover': '/',
    'escalate': '/',
    // ── W2 / W2.5 jeeber + wallet.
    'jeeber-active-delivery': '/',
    'jeeber-settlement': '/',
    'jeeber-settlement-detail': '/jeeber/settlement',
    'onboarding-funding': '/',
    'offer-kyc-gate': '/',
    'delivery-register-prompt': '/',
    'kyc-rejected': '/',
    'jeeber-pending-offers': '/',
    'wallet': '/',
    'wallet-charge-info': '/wallet',
    'earnings': '/',
    // ── W3 wallet ledger.
    'wallet-activity': '/wallet',
    'transaction-detail': '/wallet/activity',
    // ── W4 shared.
    'notifications': '/',
    'support-ticket': '/',
    'dispute-status': '/',
    'reviews-list': '/',
    'reviews-list-by-id': '/',
    'language-settings': '/settings',
    'password-security': '/settings',
  };

  /// Recursively wraps every route named in [backFallbacks] in a
  /// [RootAwareBackScope], preserving the route tree otherwise verbatim (path,
  /// name, redirect, and nested child routes are carried through untouched).
  /// A route absent from the map keeps its exact builder, so shell / gate /
  /// mandatory-rating / self-wrapping screens are structurally unchanged.
  static List<RouteBase> _wrapRootAware(List<RouteBase> routes) {
    return <RouteBase>[
      for (final route in routes)
        if (route is GoRoute) _wrapGoRoute(route) else route,
    ];
  }

  static GoRoute _wrapGoRoute(GoRoute route) {
    final fallback = backFallbacks[route.name];
    final builder = route.builder;
    final GoRouterWidgetBuilder? wrapped = (fallback != null && builder != null)
        ? (context, state) => RootAwareBackScope(
              fallbackLocation: fallback,
              child: builder(context, state),
            )
        : builder;
    return GoRoute(
      path: route.path,
      name: route.name,
      builder: wrapped,
      redirect: route.redirect,
      routes: _wrapRootAware(route.routes),
    );
  }

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
    final Cubit<SessionState>? sessionCubit = session is Cubit<SessionState>
        ? session as Cubit<SessionState>
        : null;
    // JM-066: re-run redirects when the account status resolves/changes. The
    // inert default gate is not a `Cubit` and contributes nothing; the real
    // status cubit (JM-006/066) is a `BlocBase` and is bridged here.
    final BlocBase<Object?>? accountStatusBloc =
        accountStatus is BlocBase<Object?>
        ? accountStatus as BlocBase<Object?>
        : null;
    return GoRouter(
      initialLocation: '/',
      // Diagnostic event stream (debug/dev-only): emits one `[jeeb-diag]`
      // `{"t":"nav",...}` line per push/pop/replace so a device run can be
      // grepped for exactly which screens opened. Inert in release (every
      // `Diag.*` call early-returns when `Diag.enabled` is false).
      observers: [DiagNavObserver()],
      refreshListenable: _MergedRefreshListenable([
        _CubitRefreshListenable<bool>(onboarding),
        _CubitRefreshListenable<BiometricLockState>(biometricLock),
        if (sessionCubit != null)
          _CubitRefreshListenable<SessionState>(sessionCubit),
        if (accountStatusBloc != null)
          _BlocRefreshListenable(accountStatusBloc),
      ]),
      redirect: (context, state) {
        // S007-P1B: a custom-scheme VIEW intent `jeeb://chat/<id>` arrives with
        // the chat id as the URI host+segment; normalize it to `/chat/:id` so
        // `chat-detail` resolves the accepted conversation in-app. Inert for
        // in-app navigation and https App Links (already `/chat/<id>`).
        final chatDeepLink = normalizeChatDeepLink(state.uri) ??
            normalizeJeebSchemeDeepLink(state.uri);
        if (chatDeepLink != null && state.matchedLocation != chatDeepLink) {
          return chatDeepLink;
        }

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
          final pinRedirect = _devRoutePinRedirect(
            state,
            () => devSeamLanded,
            (v) => devSeamLanded = v,
          );
          // _noPin → not forcing → allow (null). Otherwise force the pin path.
          return pinRedirect == _noPin ? null : pinRedirect;
        }

        // First-run gate (FR-P0-1 onboarding + FR-P0-3 session). Runs for every
        // non-skip launch — including when a route is pinned WITHOUT
        // skipOnboarding, which is precisely how the silent bypass is closed.
        final firstRun = _firstRunRedirect(
          state,
          onboarding,
          session,
          accountStatus,
        );
        if (firstRun != null) return firstRun;

        // Onboarded + authenticated. If a route is pinned (without skip) and the
        // first-run gate allowed us through, honour the pin's initial landing so
        // deep-capture of authenticated screens still works on a device whose
        // onboarding is already complete.
        if (_devRoute.isNotEmpty && !_devSkipOnboarding) {
          final pinRedirect = _devRoutePinRedirect(
            state,
            () => devSeamLanded,
            (v) => devSeamLanded = v,
          );
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
      // Every root-capable route is wrapped in a [RootAwareBackScope] via
      // [_wrapRootAware] (keyed by [backFallbacks]) so the system BACK gesture
      // resolves to a parent instead of exiting the app when the screen is the
      // stack ROOT (deep-link / push / `go`). Shell, first-run, gate, and
      // mandatory-rating routes are excluded (see [backFallbacks]).
      routes: _wrapRootAware([
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
        // ── The hidden email/password auth funnel (`/login`, `/sign-up`,
        //    `/recover`, `/recover/verify`) was REMOVED in JEBV4-199 (Q-044
        //    RATIFIED): the only end-user auth surfaces are phone-OTP
        //    (`/register`, above) + Apple/Google social (offered on it). The
        //    app-side super-login dev/test path is unaffected (registration).
        //    `/set-password` survives for the authenticated password-security
        //    settings flow (JM-061) — a social-only account adding a password.
        GoRoute(
          path: '/set-password',
          name: 'set-password',
          // JM-061 in-app-social only. The recovery mode + its email/password
          // recovery funnel were removed in JEBV4-199, so this route now serves
          // solely the authenticated "social-only account adds a password"
          // settings path. `email`/`resetToken` remain optional inputs an
          // authenticated caller may forward (read from the query first — they
          // survive a cold URL reload — then the typed `extra` Map); neither is
          // required in-app-social.
          builder: (context, state) {
            final query = state.uri.queryParameters;
            final extra = state.extra;
            final extraMap = extra is Map<String, String>
                ? extra
                : const <String, String>{};
            final email = query['email'] ?? extraMap['email'] ?? '';
            final resetToken = query['resetToken'] ?? extraMap['resetToken'];
            return SetPasswordScreen(
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
          builder: (context, state) =>
              ClientOffersScreen(requestId: state.pathParameters['id'] ?? ''),
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
          builder: (context, state) =>
              NoOfferTimeoutScreen(requestId: state.pathParameters['id'] ?? ''),
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
          builder: (context, state) =>
              OrderSummaryScreen(deliveryId: state.pathParameters['id'] ?? ''),
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
            final isJeeber = state.uri.queryParameters['role'] == 'jeeber';
            return CancellationScreen(deliveryId: id, isJeeber: isJeeber);
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
          builder: (context, state) =>
              RatingPromptScreen(deliveryId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: '/chat/:id',
          name: 'chat-detail',
          builder: (context, state) =>
              ChatDetailScreen(chatId: state.pathParameters['id'] ?? ''),
        ),
        // Debug-only chat-capture seam; gated by [_devChat] in the redirect
        // above so it is unreachable in release builds.
        GoRoute(
          path: '/dev-chat',
          name: 'dev-chat',
          builder: (context, state) => DevChatPreviewScreen(selector: _devChat),
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
          builder: (context, state) => const LiveSettingsScreen(),
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
            // Dev-only diagnostics export (diag-persistence lane): lists the
            // persisted `[jeeb-diag]` JSONL session files with share / copy-
            // path export. The Settings row that leads here is gated on
            // `Diag.enabled`; the screen itself renders a "dev builds only"
            // notice if reached in a build where the stream is off.
            GoRoute(
              path: 'diagnostics',
              name: 'settings-diagnostics',
              builder: (context, state) => const DiagnosticsScreen(),
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
            // JEBV4-13: forward the recorder's local file path + duration so
            // the transcription review's replay control plays the real clip
            // (the upload id in `audioPath` is a gateway audioId, not a path).
            onSent: (clipId, transcript,
                    {String? localAudioPath,
                    Duration duration = Duration.zero}) =>
                context.push(
              '/voice-request/transcription',
              extra: VoiceClip(
                audioPath: clipId,
                durationMs: duration.inMilliseconds,
                transcript: transcript,
                localAudioPath: localAudioPath,
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
            onContinue: (draft) =>
                context.push('/request-summary', extra: draft),
          ),
        ),
        GoRoute(
          path: '/client-location',
          name: 'client-location',
          // B-35: do NOT override `onAddLocation` — the screen's own handler
          // awaits `pushNamed('capture-location')` and threads the returned
          // `LocationPoint` into `markPinned` (so the create payload carries the
          // real pin). The old `context.push(...)` override was fire-and-forget:
          // it discarded the popped coordinate, collapsing every pinned pickup to
          // the Beirut fallback.
          builder: (context, state) => const ClientLocationScreen(),
        ),
        GoRoute(
          path: '/capture-location',
          name: 'capture-location',
          builder: (context, state) => const CaptureLocationRoute(),
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
        // G1 (sprint-009 P0) — compose-dictation: the mic affordance on the
        // "What do you need?" compose field. REUSES the existing voice
        // recording + transcription-review screens verbatim; only the
        // navigation closures differ — instead of forwarding a RequestDraft to
        // `/request-summary`, the confirmed transcript POPS back to the
        // compose step as a [VoiceClip] result, which the description field
        // inserts and the compose controller attaches as
        // `transcription`/`audioUrl` on the POST body.
        GoRoute(
          path: '/compose-dictation',
          name: 'compose-dictation',
          builder: (context, state) => VoiceRequestScreen(
            onSent: (clipId, transcript,
                {String? localAudioPath,
                Duration duration = Duration.zero}) async {
              // Review step: same TranscriptionScreen, dictation-result wiring.
              // JEBV4-13: local path + duration make the replay control real.
              final clip = await context.push<VoiceClip>(
                '/compose-dictation/review',
                extra: VoiceClip(
                  audioPath: clipId,
                  durationMs: duration.inMilliseconds,
                  transcript: transcript,
                  localAudioPath: localAudioPath,
                ),
              );
              // Confirmed → cascade the result back to the compose field.
              // Cancelled/re-recorded → stay on the recorder.
              if (clip != null && context.mounted && context.canPop()) {
                context.pop(clip);
              }
            },
          ),
        ),
        GoRoute(
          path: '/compose-dictation/review',
          name: 'compose-dictation-review',
          builder: (context, state) {
            final extra = state.extra;
            final clip = extra is VoiceClip
                ? extra
                : const VoiceClip(audioPath: '', durationMs: 0);
            return TranscriptionScreen(
              clip: clip,
              onConfirm: (text, audioPath) => context.pop(
                VoiceClip(
                  audioPath: audioPath,
                  durationMs: clip.durationMs,
                  transcript: text,
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
            // The composer is reachable as a stack ROOT (a push-notification /
            // deep-link `go('/jeeber/requests/:id/offer')`), so the system BACK
            // gesture would otherwise exit the app. Wrap it so BACK — and the
            // withdraw / request-gone callbacks — resolve to the shell instead.
            return RootAwareBackScope(
              fallbackLocation: '/',
              child: OfferSubmissionScreen(
                requestId: requestId,
                submissionService: sl<OfferSubmissionService>(),
                repository: sl<OfferSubmissionRepository>(),
                onWithdrawn: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                onSubmitted: (conversationId) {
                  context.go('/chat/$conversationId');
                },
                onRequestGone: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
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
          //      path. We first try the warm [RequestFeedService] cache the
          //      dashboard subscription keeps hot; on a miss (run-20 pushD:
          //      the request was created seconds before the tap, AFTER the
          //      cache was last populated) we FETCH it by id from the jeeber
          //      discovery feed via [_recoverFeedRequestById]. A genuinely
          //      missing/expired request (fetch returns null or throws) still
          //      surfaces the graceful "no longer available" screen.
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final extra = state.extra;
            final cached = extra is FeedRequest
                ? extra
                : (sl.isRegistered<RequestFeedService>()
                    ? sl<RequestFeedService>().findById(id)
                    : null);
            void back() {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            }

            return JeeberRequestDetailLoader(
              requestId: id,
              initial: cached,
              fetch: () => _recoverFeedRequestById(id),
              // Run-22 replacement P1: the discovery feed is pending-scoped,
              // so an ACCEPTED request rightly misses it. Probe the delivery
              // by id (deliveryId == requestId) and swap to the active-
              // delivery screen instead of the "Request unavailable" dead end.
              fetchAcceptedDeliveryId: () => _probeAcceptedDeliveryId(id),
              onAcceptedRedirect: (deliveryId) => context.pushReplacementNamed(
                'jeeber-active-delivery',
                pathParameters: {'id': deliveryId},
              ),
              reportService: sl<ProhibitedItemReportService>(),
              onDeclined: (_) => back(),
              onBack: back,
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
            return BlocProvider<LiveTrackingCubit>(
              create: (_) => LiveTrackingCubit(
                repository: _trackingRepository(),
                deliveryId: deliveryId,
                // G4: re-hydrate the accept-time handover code from local
                // persistence so the customer tracking surface can render it
                // (compact row pre-at-door, prominent at-door card).
                handoverCodeStore: sl.isRegistered<HandoverCodeStore>()
                    ? sl<HandoverCodeStore>()
                    : null,
              ),
              // Maps-ON: render the LIVE GoogleMap. The sprint-009 stop-the-bleed
              // placeholder is retired now that the manifest wires
              // `com.google.android.geo.API_KEY` (from `android/local.properties`
              // `${MAPS_API_KEY}`) and Google-Cloud billing is enabled on
              // `jeeb-5a293`, so the native Maps SDK serves instead of throwing
              // the keyless-map IllegalStateException → SIGKILL it used to.
              // Explicit here (matching the widget default) so this pin stays
              // visible at the former crash site for all three inbound tracking
              // CTAs (home "Track my order", delivery-detail "Live tracking",
              // chat offer-accepted banner).
              child: LiveTrackingScreen(
                deliveryId: deliveryId,
                useLiveMap: true,
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
                // G4: local-first code sourcing — the accept-time persisted
                // code renders instantly (and restart-safe) without hitting
                // the SMS-trigger endpoint.
                codeStore: sl.isRegistered<HandoverCodeStore>()
                    ? sl<HandoverCodeStore>()
                    : null,
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
              // JEBV4-200: real camera picker so the proof photo captures REAL
              // image bytes (streamed to the CDN broker), not a filename stub.
              photoPicker: sl<PhotoPickerService>(),
              // Post-accept entry point from the ACTIVE delivery surface: open
              // the order conversation. chat-detail resolves the conversation
              // against the live gateway from this delivery id (== request id
              // == correlationKey). Previously this only popped, assuming the
              // jeeber always arrived from chat — leaving the button a dead end
              // when reached from the feed.
              onOpenChat: () => context.pushNamed(
                'chat-detail',
                pathParameters: {'id': deliveryId},
              ),
              onOpenOtp: () {
                context.go('/orders/$deliveryId/otp?mode=jeeber');
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
            return const Scaffold(
              body: Center(child: Text('Statement not found')),
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
          builder: (context, state) =>
              DisputeStatusScreen(disputeId: state.pathParameters['id'] ?? ''),
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
            jeeberId:
                state.pathParameters['jeeberId'] ??
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
      ]),
      errorBuilder: (context, state) =>
          Scaffold(body: Center(child: Text('Route not found: ${state.uri}'))),
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

/// Recovers the [FeedRequest] for [id] from the jeeber discovery feed
/// (`GET /v1/jeebers/me/feed?status=pending`, reused verbatim via
/// [RequestFeedRepository.refresh]) so a PUSH tap — which carries only the id
/// and lands after the warm feed cache was last populated — still resolves to
/// the request detail (run-20 pushD gap).
///
/// This is the SAME jeeber-scoped, authz-safe feed the dashboard reads (the
/// server-side visibility predicate already gates it to `online + pending +
/// clientId != jeeberId`), and the id→[FeedRequest] mapping is identical to the
/// dashboard's feed-row tap. Returns null when the id is not among the jeeber's
/// visible pending requests (matched / expired / offline) so the caller keeps
/// the graceful unavailable fallback.
Future<FeedRequest?> _recoverFeedRequestById(String id) async {
  if (id.isEmpty || !sl.isRegistered<RequestFeedRepository>()) return null;
  final requests = await sl<RequestFeedRepository>().refresh();
  for (final request in requests) {
    if (request.id == id) {
      return FeedRequest(
        id: request.id,
        shortLabel: request.pickup.label,
        // G1: the customer's request content (gateway feed `description`,
        // parsed into itemsSummary) — the detail renders it prominently.
        description: request.itemsSummary,
      );
    }
  }
  return null;
}

/// Run-22 replacement P1 (jeeber "Request unavailable" on an accepted
/// request): the discovery feed above is `status=pending`-scoped, so a request
/// that was ACCEPTED (assigned to this jeeber) legitimately vanishes from it —
/// yet an active delivery for it exists and is the screen the jeeber actually
/// needs. Probe `GET /v1/deliveries/{id}` (deliveryId == requestId convention,
/// reused via [ActiveDeliveryRepository.fetchDelivery]) and return the id when
/// the delivery exists and is still in flight. Terminal (`Done`) deliveries
/// return null — the graceful unavailable fallback is the right surface for a
/// finished order. Server-side authz on the by-id read remains the boundary
/// for deliveries that belong to another jeeber (the mock/dev gateway returns
/// them; the loader still only redirects on non-terminal states).
Future<String?> _probeAcceptedDeliveryId(String id) async {
  if (id.isEmpty || !sl.isRegistered<ActiveDeliveryRepository>()) return null;
  try {
    final delivery = await sl<ActiveDeliveryRepository>().fetchDelivery(id);
    if (delivery.status == JeeberDeliveryStatus.done) return null;
    return delivery.id.isNotEmpty ? delivery.id : id;
  } catch (_) {
    return null;
  }
}
