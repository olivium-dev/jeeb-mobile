import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev_seam/dev_seam.dart';
import '../../../core/session/greeting_profile_cubit.dart';
import '../../customer_profile/data/dev_customer_profile_fixtures.dart';
import '../../customer_profile/data/dio_customer_profile_repository.dart';
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
    this.greetingRepository,
  });

  /// Injection hook so tests + the future DI wiring can swap in a Dio-
  /// backed repository without modifying the tab.
  final ClientHomeRepository? repository;

  /// Returns the first name to greet the user with, or `null` if unknown.
  /// Wired to the profile cubit once that ships.
  final String? Function()? greetingNameProvider;

  /// Test/preview seam: overrides the source [GreetingProfileCubit] resolves
  /// (see [_resolveGreetingRepository]). Additive — when null the tab keeps
  /// its existing dev-seam / GetIt resolution untouched (DT-04 catalog hook,
  /// so a bare Dev Tool preview never fires the live getMe request).
  final CustomerProfileRepository? greetingRepository;

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
          )..load(),
        ),
      ],
      child: ClientHomeScreen(
        key: const Key('home-tab-root'),
        initialTab: devTab ?? ClientHomeTab.inProgress,
        onCreateRequest: () => _openRequestType(context),
        onOpenRequest: (request) => _openChat(context, request),
        onTrack: (request) => _openTracking(context, request),
        onRecordVoice: () => _openVoiceRequest(context),
      ),
    );
  }

  /// The live profile source for the greeting. In the dev-seam capture path we
  /// skip the network (the seed already carries the Figma name/avatar); in
  /// release we self-provide the Dio-backed getMe repo off GetIt — no DI edit,
  /// mirroring how [CustomerProfileScreen] resolves its repo. A bare test (no
  /// Dio registered) gets `null` → the greeting stays on its seed.
  CustomerProfileRepository? _resolveGreetingRepository(bool devSeed) {
    if (greetingRepository != null) return greetingRepository;
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

  /// Routes a card tap to `/chat/:id`. Replies-tab cards carry a
  /// [ClientHomeRequest.conversationId]; in-progress cards fall back to the
  /// delivery id (the mock backend mirrors both onto the conversation map).
  void _openChat(BuildContext context, ClientHomeRequest request) {
    final target = request.conversationId ?? request.id;
    if (target.isEmpty) return;
    GoRouter.of(context).pushNamed('chat-detail', pathParameters: {'id': target});
  }

  /// Routes an in-progress card's "Track my order" CTA to the live-tracking
  /// screen (`/orders/:id/tracking`, route `live-tracking`). Distinct from
  /// [_openChat]: in-progress cards track the delivery, replies/pending cards
  /// open the conversation. The tracking screen defends its own empty/invalid
  /// state, so an empty id is a no-op here.
  void _openTracking(BuildContext context, ClientHomeRequest request) {
    if (request.id.isEmpty) return;
    GoRouter.of(context)
        .pushNamed('live-tracking', pathParameters: {'id': request.id});
  }

  /// Opens the voice-request capture flow (`/voice-request`, route
  /// `voice-request`) from the home voice CTA.
  void _openVoiceRequest(BuildContext context) {
    GoRouter.of(context).pushNamed('voice-request');
  }
}
