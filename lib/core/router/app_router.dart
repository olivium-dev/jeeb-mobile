import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../dev_seam/dev_seam.dart';
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
import '../../features/deep_link_targets/kyc_status_screen.dart';
import '../../features/deep_link_targets/rating_prompt_screen.dart';
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
import '../../features/offers/domain/offer_submission_service.dart';
import '../../features/offers/presentation/offer_submission_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/otp_handover/application/otp_handover_cubit.dart';
import '../../features/otp_handover/domain/otp_handover_repository.dart';
import '../../features/otp_handover/presentation/otp_handover_screen.dart';
import '../../features/registration/presentation/registration_screen.dart';
import '../../features/request_summary/application/request_summary_cubit.dart';
import '../../features/request_summary/domain/request_draft.dart';
import '../../features/request_summary/presentation/request_summary_screen.dart';
import '../../features/settings/presentation/screens/notification_preferences_screen.dart';
import '../../features/settings/presentation/screens/profile_edit_screen.dart';
import '../../features/settings/presentation/screens/saved_addresses_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/request_type/presentation/request_type_screen.dart';
import '../../features/shell/shell_screen.dart';
import '../../features/tier_selection/presentation/tier_selection_screen.dart';
import '../../features/transcription/domain/voice_clip.dart';
import '../../features/transcription/presentation/transcription_screen.dart';
import '../../features/voice_request/presentation/voice_request_screen.dart';
import '../di/injection_container.dart';
import '../onboarding/onboarding_cubit.dart';

/// Top-level router.
///
/// First-launch gate: while [OnboardingCubit.state] is `false`, the user is
/// kept on `/onboarding` or `/register` (the only pre-auth destinations).
/// Once the user finishes or skips onboarding the cubit flips and the
/// redirect lets `/` (the shell) render normally. `refreshListenable`
/// re-evaluates redirects whenever the cubit emits.
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
  }) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: _MergedRefreshListenable([
        _CubitRefreshListenable<bool>(onboarding),
        _CubitRefreshListenable<BiometricLockState>(biometricLock),
      ]),
      redirect: (context, state) {
        // Debug capture aid: drop straight onto the fixtures-backed chat
        // (chat selector wins over a generic route override).
        if (_devChat.isNotEmpty) {
          return state.matchedLocation == '/dev-chat' ? null : '/dev-chat';
        }
        // Debug capture aid: drop straight onto any requested route, skipping
        // onboarding + biometric gates. `/` reproduces the old JEEB_DEV_HOME.
        // Compare on the PATH only so a seam route carrying query params (e.g.
        // `/orders/d-1/feedback?name=Sami`) lands once instead of looping.
        if (_devRoute.isNotEmpty) {
          final devPath = Uri.parse(_devRoute).path;
          return state.matchedLocation == devPath ? null : _devRoute;
        }
        final completed = onboarding.state;
        final loc = state.matchedLocation;
        final atPreAuth = _preAuthRoutes.contains(loc);
        if (!completed && !atPreAuth) return '/onboarding';
        if (completed && loc == '/onboarding') return '/';
        // Biometric gate (T-mobile-005). Once onboarding has completed, hold
        // the user on `/lock` until the cubit reports unlocked/disabled. The
        // gate is a no-op before evaluation finishes (phase == unknown) so we
        // don't flash the lock screen during cold start.
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
          path: '/orders/:id/rate',
          name: 'rating-prompt',
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
          builder: (context, state) => const KycStatusScreen(),
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
          // Real callers hand the aggregated view data via `extra`; the
          // dev-seam capture path (`jeeb.route=/profile/customer`) has no
          // extra, so fall back to the deterministic debug fixture.
          builder: (context, state) {
            final extra = state.extra;
            final data = extra is CustomerProfileViewData
                ? extra
                : DevCustomerProfileFixtures.sample;
            return CustomerProfileScreen(data: data);
          },
        ),
        GoRoute(
          path: '/profile/delivery-man',
          name: 'delivery-man-profile',
          // Same pattern: typed `extra` from a real client tap, else the
          // debug fixture so a single dev APK captures screen 27.
          builder: (context, state) {
            final extra = state.extra;
            final data = extra is DeliveryManProfileViewData
                ? extra
                : DevDeliveryManProfileFixtures.sample;
            return DeliveryManProfileScreen(data: data);
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
              builder: (context, state) => const SavedAddressesScreen(),
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
          builder: (context, state) => const VoiceRequestScreen(),
        ),
        GoRoute(
          path: '/tier-selection',
          name: 'tier-selection',
          builder: (context, state) => const TierSelectionScreen(),
        ),
        // Delivery-create flow (Figma 56535:2392 → 56539:1444 → 56546:2303).
        GoRoute(
          path: '/request-type',
          name: 'request-type',
          builder: (context, state) => RequestTypeScreen(
            onChangeLocation: () => context.push('/client-location'),
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
          // The clip is handed over via `extra` from the voice_request flow.
          // If the route is hit directly (cold deep link, no extra), the
          // errorBuilder upstream owns the missing-extra case via the cast
          // failure below — there's no meaningful recovery without audio.
          builder: (context, state) => TranscriptionScreen(
            clip: state.extra as VoiceClip,
          ),
        ),
        GoRoute(
          path: '/jeeber/requests/:id/offer',
          name: 'jeeber-offer-submission',
          // Bid composition entry-point. The Jeeber lands here after tapping
          // through a feed card; the request id is the only parameter the
          // screen needs to drive the cubit. Both onConfirmed and onWithdrawn
          // pop back to the feed — host owns navigation.
          builder: (context, state) => OfferSubmissionScreen(
            requestId: state.pathParameters['id'] ?? '',
            submissionService: sl<OfferSubmissionService>(),
            onWithdrawn: () {
              if (context.canPop()) context.pop();
            },
          ),
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
              return Scaffold(
                appBar: AppBar(title: const Text('Review Request')),
                body: const Center(
                  child: Text('No request draft available.'),
                ),
              );
            }
            return BlocProvider<RequestSummaryCubit>(
              create: (_) => RequestSummaryCubit()..setDraft(extra),
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
