import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev_seam/dev_seam.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/lifecycle/polling_visibility_gate.dart';
import '../../../core/lifecycle/route_visibility.dart';
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
import '../tab_visibility.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, this.repository, this.greetingNameProvider});

  final ClientHomeRepository? repository;

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
            refreshSignals: resolvePushRefreshStream(
              topics: const {RefreshTopic.order, RefreshTopic.offers},
            ),
          ),
        ),
        // real `GET /users/me` (the same getMe the Profile tab reads), so the
        BlocProvider(
          create: (_) => GreetingProfileCubit(
            repository: _resolveGreetingRepository(devSeed),
            seed: _greetingSeed(devSeed),
            refreshSignals: _profileRefreshStream(),
          )..load(),
        ),
      ],
      child: Builder(
        builder: (innerContext) => PollingVisibilityGate(
          // b02 READ ECONOMICS. `isVisible` must AND every condition that makes
          isVisible:
              (TabVisibility.maybeOf(innerContext)?.isVisible ?? true) &&
              RouteVisibilityScope.isOnTop(innerContext),
          target: innerContext.read<ClientHomeCubit>(),
          child: ClientHomeScreen(
            key: const Key('home-tab-root'),
            initialTab: devTab ?? ClientHomeTab.pendingRequests,
            onCreateRequest: () => _openRequestType(context),
            onOpenRequest: (request) => _openChat(context, request),
            onTrack: (request) => _openTracking(context, request),
          ),
        ),
      ),
    );
  }

  Stream<void>? _profileRefreshStream() {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<ProfileRefreshSignals>()) return null;
    return getIt<ProfileRefreshSignals>().stream;
  }

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

  GreetingProfileState _greetingSeed(bool devSeed) {
    if (!devSeed) return const GreetingProfileState();
    return GreetingProfileState(
      name: DevCustomerProfileFixtures.sample.name,
      avatarUrl: DevCustomerProfileFixtures.sample.avatarUrl,
    );
  }

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

  String? _resolveGreetingName() => _devSeamTab() != null ? 'Sami' : null;

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

  void _openRequestType(BuildContext context) {
    GoRouter.of(context).pushNamed('request-type');
  }

  void _openChat(BuildContext context, ClientHomeRequest request) {
    final target = request.id.isNotEmpty
        ? request.id
        : (request.conversationId ?? '');
    if (target.isEmpty) return;
    GoRouter.of(
      context,
    ).pushNamed('chat-detail', pathParameters: {'id': target});
  }

  void _openTracking(BuildContext context, ClientHomeRequest request) {
    if (request.trackingId.isEmpty) return;
    GoRouter.of(context).pushNamed(
      'live-tracking',
      pathParameters: {'id': request.trackingId},
      queryParameters: {
        if (request.deliveryId != null && request.deliveryId!.isNotEmpty)
          'deliveryId': request.deliveryId!,
      },
    );
  }
}
