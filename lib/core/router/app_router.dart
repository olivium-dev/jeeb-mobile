import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/biometric_auth/application/biometric_lock_cubit.dart';
import '../../features/biometric_auth/application/biometric_lock_state.dart';
import '../../features/biometric_auth/presentation/biometric_lock_screen.dart';
import '../../features/deep_link_targets/chat_detail_screen.dart';
import '../../features/deep_link_targets/delivery_detail_screen.dart';
import '../../features/deep_link_targets/kyc_status_screen.dart';
import '../../features/deep_link_targets/rating_prompt_screen.dart';
import '../../features/jeeber_home/domain/entities/feed_request.dart';
import '../../features/jeeber_home/domain/services/request_feed_service.dart';
import '../../features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import '../../features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart';
import '../../features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart';
import '../../features/location/presentation/screens/location_picker_screen.dart';
import '../../features/offers/domain/offer_submission_service.dart';
import '../../features/offers/presentation/offer_submission_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/registration/presentation/registration_screen.dart';
import '../../features/request_summary/application/request_summary_cubit.dart';
import '../../features/request_summary/domain/request_draft.dart';
import '../../features/request_summary/presentation/request_summary_screen.dart';
import '../../features/settings/presentation/screens/notification_preferences_screen.dart';
import '../../features/settings/presentation/screens/profile_edit_screen.dart';
import '../../features/settings/presentation/screens/saved_addresses_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
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
        GoRoute(
          path: '/profile/kyc',
          name: 'kyc-status',
          builder: (context, state) => const KycStatusScreen(),
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
