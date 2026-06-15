import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dev_seam/dev_seam.dart';
import '../session/session_gate.dart';
import '../session/session_state.dart';
import 'profile_unavailable_screen.dart';
import '../../features/biometric_auth/application/biometric_lock_cubit.dart';
import '../../features/biometric_auth/application/biometric_lock_state.dart';
import '../../features/biometric_auth/presentation/biometric_lock_screen.dart';
import '../../features/chat/presentation/dev_chat_preview_screen.dart';
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
import '../../features/location/presentation/capture_location_screen.dart';
import '../../features/location/presentation/client_location_screen.dart';
import '../../features/location/presentation/screens/location_picker_screen.dart';
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
class AppRouter {
  AppRouter._();

  static const Set<String> _preAuthRoutes = {'/onboarding', '/register'};
  static const String _lockRoute = '/lock';

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

  /// First-run gate: onboarding (FR-P0-1) then session/JWT (FR-P0-3). Returns
  /// the redirect target, or `null` to allow the current location.
  ///
  ///   * onboarding incomplete, not on a pre-auth route → `/onboarding`
  ///   * onboarding complete but on `/onboarding`        → `/`
  ///   * onboarding complete, NO valid token, not on a pre-auth route
  ///       → `/register` (the login destination)
  ///
  /// The session check uses [SessionGate.isUnauthenticated] (not
  /// `!isAuthenticated`) so the cold-start `unknown` phase is a no-op and we
  /// never flash `/register` while the keystore read is in flight.
  static String? _firstRunRedirect(
    GoRouterState state,
    OnboardingCubit onboarding,
    SessionGate session,
  ) {
    final completed = onboarding.state;
    final loc = state.matchedLocation;
    final atPreAuth = _preAuthRoutes.contains(loc);
    if (!completed && !atPreAuth) return '/onboarding';
    if (completed && loc == '/onboarding') return '/';
    // FR-P0-3: onboarded-but-tokenless user must log in before reaching Home.
    if (completed && session.isUnauthenticated && !atPreAuth) {
      return '/register';
    }
    return null;
  }

  /// Order-tracking (screen 16) needs a reachable gateway to render its ready
  /// state. When the dev seam is driving a `/orders/.../tracking` capture, swap
  /// in the deterministic demo repository so the screen renders offline; every
  /// other run uses the real DI-registered repository.
  static LiveTrackingRepository _trackingRepository() {
    if (kDebugMode && _devRoute.contains('/tracking')) {
      return const DemoLiveTrackingRepository();
    }
    return sl<LiveTrackingRepository>();
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
    return GoRouter(
      initialLocation: '/',
      refreshListenable: _MergedRefreshListenable([
        _CubitRefreshListenable<bool>(onboarding),
        _CubitRefreshListenable<BiometricLockState>(biometricLock),
        if (sessionCubit != null)
          _CubitRefreshListenable<SessionState>(sessionCubit),
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
        final firstRun = _firstRunRedirect(state, onboarding, session);
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
        final completed = onboarding.state;
        final loc = state.matchedLocation;
        final lockPhase = biometricLock.state.phase;
        if (completed && lockPhase == BiometricLockPhase.locked && loc != _lockRoute) {
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
          builder: (context, state) => const BiometricLockScreen(),
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
          builder: (context, state) => CaptureLocationScreen(
            onPinned: () {
              if (context.canPop()) context.pop();
            },
          ),
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
            final deliveryId = state.pathParameters['id'] ?? '';
            return BlocProvider<LiveTrackingCubit>(
              create: (_) => LiveTrackingCubit(
                repository: _trackingRepository(),
                deliveryId: deliveryId,
              ),
              child: LiveTrackingScreen(deliveryId: deliveryId),
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

        // T-MOB-024 AC3: Wallet deep-link destination.
        // Shown after cancellation when a fee was charged and the user taps
        // "View Wallet". A full wallet feature (balance + top-up) is tracked
        // under T-MOB-035; this route provides a non-crashing landing page
        // until that feature ships.
        GoRoute(
          path: '/wallet',
          name: 'wallet',
          builder: (context, state) => const Scaffold(
            body: Center(
              child: Text('Wallet — coming soon'),
            ),
          ),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(child: Text('Route not found: ${state.uri}')),
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
