import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev_seam/dev_seam.dart';
import '../../../core/session/greeting_profile_cubit.dart';
import '../../../core/session/profile_refresh_signals.dart';
import '../../customer_profile/data/dev_customer_profile_fixtures.dart';
import '../../customer_profile/data/dio_customer_profile_repository.dart';
import '../../../core/notifications/application/push_refresh_signals.dart';
import '../../customer_profile/domain/customer_profile_repository.dart';
import '../../home_client/application/client_home_cubit.dart';
import '../../home_client/application/client_home_state.dart';
import '../../home_client/data/dev_client_home_fixtures.dart';
import '../../home_client/data/in_memory_client_home_repository.dart';
import '../../home_client/domain/client_home_repository.dart';
import '../../home_client/domain/client_home_request.dart';
import '../../home_client/presentation/client_home_screen.dart';

/// Client-role home tab. Hosts the [ClientHomeCubit] scoped to this tab —
/// rebuilt on role switches (the shell tears down + reinflates), which is
/// the right lifetime for a per-tab view-model.
///
/// The repository defaults to the in-memory fake until the jeeb-gateway
/// `/api/clients/me/home-summary` endpoint exists. Callers can inject a
/// real repository through the constructor (used by widget tests).
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    this.repository,
    this.greetingNameProvider,
  });

  /// Injection hook so tests + the future DI wiring can swap in a Dio-
  /// backed repository without modifying the tab.
  final ClientHomeRepository? repository;

  /// Returns the first name to greet the user with, or `null` if unknown.
  /// Wired to the profile cubit once that ships.
  final String? Function()? greetingNameProvider;

  @override
  Widget build(BuildContext context) {
    final devTab = _devSeamTab();
    final devSeed = devTab != null;
    return MultiBlocProvider(
      key: const Key('home-tab-cubit'),
      providers: [
        BlocProvider(
          create: (_) => ClientHomeCubit(
            repository: repository ?? _resolveRepository(devSeed),
            greetingNameProvider: greetingNameProvider ?? _resolveGreetingName,
            // Push-triggered refetch (sprint-009): re-pull on a status-change
            // push. Absent under bare tests / dev seams where DI isn't set up.
            refreshSignals: GetIt.instance.isRegistered<PushRefreshSignals>()
                ? GetIt.instance<PushRefreshSignals>().stream
                : null,
          ),
        ),
        // P0-X06: the personalized greeting (name + avatar) is sourced from the
        // real `GET /users/me` (the same getMe the Profile tab reads), so the
        // header shows "Hello, {name}" + the real avatar instead of the generic
        // "Welcome back" + "?" placeholder. Under the dev seam it is seeded with
        // the deterministic capture fixture; in release it refreshes from the
        // live profile (or stays generic when getMe is unreachable / nameless).
        BlocProvider(
          create: (_) => GreetingProfileCubit(
            repository: _resolveGreetingRepository(devSeed),
            seed: _greetingSeed(devSeed),
            // Profile-name lane: re-pull getMe when a display-name save
            // broadcasts a profile change (the IndexedStack keeps this tab
            // alive, so without the signal the greeting would stay stale).
            refreshSignals: _profileRefreshStream(),
          )..load(),
        ),
      ],
      child: ClientHomeScreen(
        key: const Key('home-tab-root'),
        // JEBV4-298 (E24/Q-086): the Requests tab is on-hold only, so it
        // opens on Pending Requests. The In-Progress live-tracking surface now
        // lives on the Delivery tab. The dev seam may still pin any tab
        // (including In-Progress) for a debug-only capture of that surface.
        initialTab: devTab ?? ClientHomeTab.pendingRequests,
        onCreateRequest: () => _openRequestType(context),
        onOpenRequest: (request) => _openChat(context, request),
        onTrack: (request) => _openTracking(context, request),
        onRecordVoice: () => _openVoiceRequest(context),
      ),
    );
  }

  /// Profile-changed broadcast (display-name saves) off GetIt when registered;
  /// `null` under bare tests / fixture hosts so the cubit simply never
  /// re-pulls. Mirrors the [PushRefreshSignals] wiring above.
  Stream<void>? _profileRefreshStream() {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<ProfileRefreshSignals>()) return null;
    return getIt<ProfileRefreshSignals>().stream;
  }

  /// The live profile source for the greeting. In the dev-seam capture path we
  /// skip the network (the seed already carries the Figma name/avatar); in
  /// release we self-provide the Dio-backed getMe repo off GetIt — no DI edit,
  /// mirroring how [CustomerProfileScreen] resolves its repo. A bare test (no
  /// Dio registered) gets `null` → the greeting stays on its seed.
  CustomerProfileRepository? _resolveGreetingRepository(bool devSeed) {
    if (devSeed) return null;
    final getIt = GetIt.instance;
    if (getIt.isRegistered<CustomerProfileRepository>()) {
      return getIt<CustomerProfileRepository>();
    }
    if (getIt.isRegistered<Dio>()) {
      return DioCustomerProfileRepository(getIt<Dio>());
    }
    return null;
  }

  /// Seeds the greeting with the deterministic Figma profile under the dev seam
  /// so a single capture APK renders "Hello, Sami" + the avatar without a live
  /// fetch; empty otherwise (the live getMe populates it in release).
  GreetingProfileState _greetingSeed(bool devSeed) {
    if (!devSeed) return const GreetingProfileState();
    return GreetingProfileState(
      name: DevCustomerProfileFixtures.sample.name,
      avatarUrl: DevCustomerProfileFixtures.sample.avatarUrl,
    );
  }

  /// Pulls the [DioClientHomeRepository] off GetIt when available so the
  /// home tab talks to the mock backend; in the dev-seam capture path it uses
  /// the deterministic fixtures so all three filter tabs render populated.
  ClientHomeRepository _resolveRepository(bool devSeed) {
    if (devSeed) {
      return InMemoryClientHomeRepository.fromSnapshot(
        DevClientHomeFixtures.snapshot(),
      );
    }
    final getIt = GetIt.instance;
    if (getIt.isRegistered<ClientHomeRepository>()) {
      return getIt<ClientHomeRepository>();
    }
    return InMemoryClientHomeRepository();
  }

  /// Greets "Sami" (the Figma mock name) under the dev seam so captures match
  /// the design; `null` otherwise until the profile cubit is wired.
  String? _resolveGreetingName() => _devSeamTab() != null ? 'Sami' : null;

  /// The filter tab requested via the dev seam, or `null` when the seam isn't
  /// driving the home tab. Debug-only — always `null` in release builds.
  ClientHomeTab? _devSeamTab() {
    if (!kDebugMode) return null;
    final raw = DevSeam.current.homeTab;
    switch (raw) {
      case 'in_progress':
        return ClientHomeTab.inProgress;
      case 'pending':
        return ClientHomeTab.pendingRequests;
      case 'replies':
        return ClientHomeTab.replies;
      default:
        return null;
    }
  }

  /// Opens the delivery-create flow from the home "+" FAB. Wiring this non-null
  /// callback is what makes the `IconButton.filled` render ENABLED (navy
  /// `colorScheme.primary` fill) instead of the disabled-gray state a null
  /// `onPressed` produces — see `client_home_greeting.dart` `_AddRequestButton`.
  /// Routes to the `request-type` screen (Figma 56535:2392), matching the
  /// production create-request intent. Identical in debug + release; the seam
  /// flows (13/14/15) only assert this button's visibility, never tap it.
  void _openRequestType(BuildContext context) {
    GoRouter.of(context).pushNamed('request-type');
  }

  /// Routes a card tap to `/chat/:id` (BUG-18 client side). Prefer the request
  /// id (== correlationKey) over [ClientHomeRequest.conversationId]: chat-detail
  /// resolves correlationKey-first, so a conversationId param guarantees one
  /// wasted 404 probe. Fall back to the conversationId only when no request id
  /// is available.
  void _openChat(BuildContext context, ClientHomeRequest request) {
    final target =
        request.id.isNotEmpty ? request.id : (request.conversationId ?? '');
    if (target.isEmpty) return;
    GoRouter.of(context).pushNamed('chat-detail', pathParameters: {'id': target});
  }

  /// Routes an in-progress card's "Track my order" CTA to the live-tracking
  /// screen (`/orders/:id/tracking`, route `live-tracking`). Distinct from
  /// [_openChat]: in-progress cards track the delivery, replies/pending cards
  /// open the conversation. The tracking screen defends its own empty/invalid
  /// state, so an empty id is a no-op here.
  void _openTracking(BuildContext context, ClientHomeRequest request) {
    if (request.trackingId.isEmpty) return;
    // S9 live-tracking fix: navigate with the SERVER delivery id
    // (`delivery-<offerId>`) so `GET /v1/delivery/<id>` resolves instead of
    // 404'ing on a request id. The router prefers `?deliveryId=` over `:id`;
    // we still set the path id (delivery id when known, else request id as a
    // best-effort fallback via [ClientHomeRequest.trackingId]).
    GoRouter.of(context).pushNamed(
      'live-tracking',
      pathParameters: {'id': request.trackingId},
      queryParameters: {
        if (request.deliveryId != null && request.deliveryId!.isNotEmpty)
          'deliveryId': request.deliveryId!,
      },
    );
  }

  /// Opens the voice-request capture flow (`/voice-request`, route
  /// `voice-request`) from the home voice CTA.
  void _openVoiceRequest(BuildContext context) {
    GoRouter.of(context).pushNamed('voice-request');
  }
}
