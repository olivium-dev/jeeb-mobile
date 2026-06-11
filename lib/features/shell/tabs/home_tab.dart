import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev_seam/dev_seam.dart';
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
    return BlocProvider(
      key: const Key('home-tab-cubit'),
      create: (_) => ClientHomeCubit(
        repository: repository ?? _resolveRepository(devTab != null),
        greetingNameProvider: greetingNameProvider ?? _resolveGreetingName,
      ),
      child: ClientHomeScreen(
        key: const Key('home-tab-root'),
        initialTab: devTab ?? ClientHomeTab.inProgress,
        onOpenRequest: (request) => _openChat(context, request),
      ),
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

  /// Routes a card tap to `/chat/:id`. Replies-tab cards carry a
  /// [ClientHomeRequest.conversationId]; in-progress cards fall back to the
  /// delivery id (the mock backend mirrors both onto the conversation map).
  void _openChat(BuildContext context, ClientHomeRequest request) {
    final target = request.conversationId ?? request.id;
    if (target.isEmpty) return;
    GoRouter.of(context).pushNamed('chat-detail', pathParameters: {'id': target});
  }
}
