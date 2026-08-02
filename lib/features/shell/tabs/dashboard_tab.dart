import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev_seam/dev_seam.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/lifecycle/app_resume_signals.dart';
import '../../../core/lifecycle/polling_visibility_gate.dart';
import '../../../core/lifecycle/route_visibility.dart';
import '../../../core/session/greeting_profile_cubit.dart';
import '../../../core/session/jeeber_kyc_status_gate.dart';
import '../../../core/session/profile_refresh_signals.dart';
import '../../customer_profile/data/dio_customer_profile_repository.dart';
import '../../customer_profile/domain/customer_profile_repository.dart';
import '../../jeeber_home/application/availability_cubit.dart';
import '../../jeeber_home/domain/entities/availability_status.dart';
import '../../jeeber_home/domain/entities/feed_request.dart';
import '../../jeeber_home/domain/services/availability_gateway.dart';
import '../../jeeber_home/presentation/jeeber_home_screen.dart';
import '../../jeeber_home/presentation/widgets/jeeber_feed_empty_view.dart';
import '../../jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart';
import '../../jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../../jeeber_request_feed/data/dev_jeeber_feed_fixtures.dart';
import '../../jeeber_request_feed/data/request_feed_models.dart';
import '../../jeeber_request_feed/data/request_feed_repository.dart';
import '../../jeeber_request_feed/presentation/feed_resume_refetcher.dart';
import '../../jeeber_active_deliveries/application/active_deliveries_cubit.dart';
import '../../jeeber_active_deliveries/data/dio_active_deliveries_repository.dart';
import '../../jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import '../../jeeber_active_deliveries/domain/active_delivery_summary.dart';
import '../../jeeber_active_deliveries/presentation/active_deliveries_banner.dart';
import '../tab_visibility.dart';

enum _DevFeedView { empty, requests, pending, replies }

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final devView = _devSeamView();
    if (devView != null) return _DevFeedScaffold(view: devView);
    final gate = sl.isRegistered<JeeberKycStatusGate>()
        ? sl<JeeberKycStatusGate>()
        : const SeamJeeberKycStatusGate();
    return JeeberKycGateBuilder(
      gate: gate,
      builder: (context, gate) => _JeeberHomeHost(
        destination: JeeberDeliveryTabDestination.forStatus(gate.status),
      ),
    );
  }

  _DevFeedView? _devSeamView() {
    if (!kDebugMode) return null;
    return switch (DevSeam.current.feed) {
      'empty' => _DevFeedView.empty,
      'requests' => _DevFeedView.requests,
      'pending' => _DevFeedView.pending,
      'replies' => _DevFeedView.replies,
      _ => null,
    };
  }
}

class _JeeberHomeHost extends StatelessWidget {
  const _JeeberHomeHost({required this.destination});

  final JeeberDeliveryTabDestination destination;

  bool get _unregistered => destination != JeeberDeliveryTabDestination.feed;

  ActiveDeliveriesRepository _resolveActiveDeliveriesRepository() {
    if (sl.isRegistered<ActiveDeliveriesRepository>()) {
      return sl<ActiveDeliveriesRepository>();
    }
    if (sl.isRegistered<Dio>()) {
      return DioActiveDeliveriesRepository(sl<Dio>());
    }
    return const _EmptyActiveDeliveriesRepository();
  }

  CustomerProfileRepository? _resolveGreetingRepository() {
    if (sl.isRegistered<CustomerProfileRepository>()) {
      return sl<CustomerProfileRepository>();
    }
    if (sl.isRegistered<Dio>()) {
      return DioCustomerProfileRepository(sl<Dio>());
    }
    return null;
  }

  Stream<void>? _profileRefreshStream() {
    if (!sl.isRegistered<ProfileRefreshSignals>()) return null;
    return sl<ProfileRefreshSignals>().stream;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AvailabilityCubit>(
          create: (_) => AvailabilityCubit(gateway: sl<AvailabilityGateway>()),
        ),
        BlocProvider<RequestFeedCubit>(
          create: (_) => RequestFeedCubit(
            repository: sl<RequestFeedRepository>(),
            repositoryOwnership: RequestFeedRepositoryOwnership.borrowed,
            //
            refreshSignals: resolvePushRefreshStream(
              topics: const {RefreshTopic.feed, RefreshTopic.offers},
            ),
          )..start(),
        ),
        BlocProvider<ActiveDeliveriesCubit>(
          create: (_) => ActiveDeliveriesCubit(
            repository: _resolveActiveDeliveriesRepository(),
            //
            refreshSignals: resolvePushRefreshStream(
              topics: const {RefreshTopic.order},
            ),
          )..start(),
        ),
        BlocProvider<GreetingProfileCubit>(
          create: (_) => GreetingProfileCubit(
            repository: _resolveGreetingRepository(),
            refreshSignals: _profileRefreshStream(),
          )..load(),
        ),
      ],
      child: Builder(
        builder: (context) => _MaybeResumeRefetch(
          enabled: !_unregistered,
          child: _GateScoped(
            destination: destination,
            child: JeeberHomeScreen(
              key: const Key('dashboard-tab-root'),
              isRegistered: !_unregistered,
              profileName: _unregistered ? 'Kamal' : null,
              registerCtaIdentifier: 'delivery_register_now_cta',
              requestFeedCubit: context.read<RequestFeedCubit>(),
              activeDeliveriesBanner: _unregistered
                  ? null
                  : ActiveDeliveriesBanner(
                      onOpenChat: (d) => context.push('/chat/${d.chatRouteId}'),
                      onManageDelivery: (d) =>
                          context.push('/jeeber/deliveries/${d.id}/active'),
                    ),
              onRegister: () => context.pushNamed('jeeber-onboarding'),
              onOpenFeedRequest: (FeedRequest request) {
                context.pushNamed(
                  'jeeber-request-detail',
                  pathParameters: {'id': request.id},
                  extra: request,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MaybeResumeRefetch extends StatelessWidget {
  const _MaybeResumeRefetch({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shellVisible =
        (TabVisibility.maybeOf(context)?.isVisible ?? true) &&
        RouteVisibilityScope.isOnTop(context);
    final activeDeliveriesGate = PollingVisibilityGate(
      target: context.read<ActiveDeliveriesCubit>(),
      isVisible: shellVisible,
      child: _ActiveDeliveriesResumeRefetch(child: child),
    );
    if (!enabled) return activeDeliveriesGate;
    return PollingVisibilityGate(
      target: context.read<RequestFeedCubit>(),
      isVisible: shellVisible,
      child: FeedResumeRefetcher(child: activeDeliveriesGate),
    );
  }
}

class _ActiveDeliveriesResumeRefetch extends StatefulWidget {
  const _ActiveDeliveriesResumeRefetch({required this.child});

  final Widget child;

  @override
  State<_ActiveDeliveriesResumeRefetch> createState() =>
      _ActiveDeliveriesResumeRefetchState();
}

class _ActiveDeliveriesResumeRefetchState
    extends State<_ActiveDeliveriesResumeRefetch> with ResumeRefetchMixin {
  @override
  void onAppResumed() => context.read<ActiveDeliveriesCubit>().refreshOnResume();

  @override
  Widget build(BuildContext context) => widget.child;
}

class _GateScoped extends StatefulWidget {
  const _GateScoped({required this.destination, required this.child});

  final JeeberDeliveryTabDestination destination;
  final Widget child;

  @override
  State<_GateScoped> createState() => _GateScopedState();
}

class _GateScopedState extends State<_GateScoped> {
  @override
  void initState() {
    super.initState();
    _scheduleRejectedRedirect();
  }

  @override
  void didUpdateWidget(_GateScoped oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.destination != oldWidget.destination) {
      _scheduleRejectedRedirect();
    }
  }

  void _scheduleRejectedRedirect() {
    if (widget.destination != JeeberDeliveryTabDestination.kycRejected) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (GoRouter.maybeOf(context) == null) return;
      context.goNamed('kyc-rejected');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFeed = widget.destination == JeeberDeliveryTabDestination.feed;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      identifier: isFeed ? 'jeeber_feed_root' : 'delivery_register_prompt',
      child: widget.child,
    );
  }
}

class _DevFeedScaffold extends StatelessWidget {
  const _DevFeedScaffold({required this.view});

  static const _name = 'Kamal';
  static const _avatarUrl = 'https://i.pravatar.cc/150?img=12';

  final _DevFeedView view;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('dashboard-tab-dev-feed'),
      body: _DevFeedBody(view: view, name: _name, avatarUrl: _avatarUrl),
    );
  }
}

class _DevFeedBody extends StatelessWidget {
  const _DevFeedBody({
    required this.view,
    required this.name,
    required this.avatarUrl,
  });

  final _DevFeedView view;
  final String name;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (view == _DevFeedView.empty) {
      return JeeberFeedEmptyView(
        profileName: name,
        profileAvatarUrl: avatarUrl,
      );
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider<AvailabilityCubit>(
          create: (_) => AvailabilityCubit(
            gateway: InMemoryAvailabilityGateway(
              initial: AvailabilityStatus.initial.copyWith(
                state: AvailabilityState.online,
              ),
            ),
          ),
        ),
        BlocProvider<RequestFeedCubit>(
          create: (_) => RequestFeedCubit(
            repository: SeededRequestFeedRepository(_snapshotFor(view)),
            refreshSignals: resolvePushRefreshStream(
              topics: const {RefreshTopic.feed, RefreshTopic.offers},
            ),
          )..start(),
        ),
      ],
      child: JeeberFeedTabView(
        profileName: name,
        profileAvatarUrl: avatarUrl,
        initialTab: _tabFor(view),
      ),
    );
  }

  List<DeliveryRequest> _snapshotFor(_DevFeedView v) => switch (v) {
    _DevFeedView.requests => DevJeeberFeedFixtures.incoming(),
    _DevFeedView.pending => DevJeeberFeedFixtures.pending(),
    _DevFeedView.replies => DevJeeberFeedFixtures.replies(),
    _DevFeedView.empty => const [],
  };

  JeeberFeedTab _tabFor(_DevFeedView v) => switch (v) {
    _DevFeedView.pending => JeeberFeedTab.pendingResponse,
    _DevFeedView.replies => JeeberFeedTab.replies,
    _DevFeedView.requests || _DevFeedView.empty => JeeberFeedTab.requests,
  };
}

class _EmptyActiveDeliveriesRepository implements ActiveDeliveriesRepository {
  const _EmptyActiveDeliveriesRepository();

  @override
  Future<List<ActiveDeliverySummary>> listActive() async =>
      const <ActiveDeliverySummary>[];
}
