import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/dev_seam/dev_seam.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/lifecycle/app_resume_signals.dart';
import '../../../core/lifecycle/polling_visibility_gate.dart';
import '../../../core/lifecycle/route_visibility.dart';
import '../../../core/power/battery_optimization.dart';
import '../../../core/session/greeting_profile_cubit.dart';
import '../../../core/session/jeeber_kyc_status_gate.dart';
import '../../../core/session/profile_refresh_signals.dart';
import '../../../l10n/app_localizations.dart';
import '../../customer_profile/data/dio_customer_profile_repository.dart';
import '../../customer_profile/domain/customer_profile_repository.dart';
import '../../jeeber_home/application/availability_cubit.dart';
import '../../jeeber_home/application/availability_state.dart';
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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../../customer_profile/domain/customer_profile_view_data.dart';

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
          create: (_) => AvailabilityCubit(
            gateway: sl<AvailabilityGateway>(),
            resumeSignals: AppResumeSignals.instance.stream,
          ),
        ),
        BlocProvider<RequestFeedCubit>(
          create: (_) => RequestFeedCubit(
            repository: sl<RequestFeedRepository>(),
            repositoryOwnership: RequestFeedRepositoryOwnership.borrowed,
            refreshSignals: resolvePushRefreshStream(
              topics: const {RefreshTopic.feed, RefreshTopic.offers},
            ),
          )..start(),
        ),
        BlocProvider<ActiveDeliveriesCubit>(
          create: (_) => ActiveDeliveriesCubit(
            repository: _resolveActiveDeliveriesRepository(),
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
        builder: (context) => _BatteryOptimizationPrompt(
          enabled: !_unregistered,
          child: _MaybeResumeRefetch(
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
      ),
    );
  }
}

/// Samsung app-sleep withholds FCM from a battery-restricted app, so a jeeber
/// who just went ONLINE gets no new-request push. Asked once per install.
class _BatteryOptimizationPrompt extends StatefulWidget {
  const _BatteryOptimizationPrompt({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_BatteryOptimizationPrompt> createState() =>
      _BatteryOptimizationPromptState();
}

class _BatteryOptimizationPromptState
    extends State<_BatteryOptimizationPrompt> {
  static const BatteryOptimization _power = BatteryOptimization();

  bool _wasOnline = false;
  bool _inFlight = false;

  @override
  void initState() {
    super.initState();
    _wasOnline = context.read<AvailabilityCubit>().state.status.isOnline;
    if (widget.enabled && _wasOnline) unawaited(_maybePrompt());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AvailabilityCubit, AvailabilityViewState>(
      listenWhen: (previous, current) =>
          previous.status.isOnline != current.status.isOnline,
      listener: (context, state) {
        final wentOnline = !_wasOnline && state.status.isOnline;
        _wasOnline = state.status.isOnline;
        if (!widget.enabled || !wentOnline) return;
        unawaited(_maybePrompt());
      },
      child: widget.child,
    );
  }

  Future<void> _maybePrompt() async {
    if (_inFlight || !sl.isRegistered<SharedPreferences>()) return;
    _inFlight = true;
    try {
      final prefs = sl<SharedPreferences>();
      if (!await _power.shouldPrompt(prefs)) return;
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      await _power.markPrompted(prefs);
      if (!mounted) return;
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.batteryOptimizationTitle),
          content: Text(l10n.batteryOptimizationBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.batteryOptimizationDismiss),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.batteryOptimizationAction),
            ),
          ],
        ),
      );
      if (open ?? false) await _power.openSettings();
    } finally {
      _inFlight = false;
    }
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The box the DELIVERY tab actually gets on the device this team tests on: a
/// Galaxy S22 is 360×780 logical and the shell's bottom nav takes ~80 of it.
const Size _dashboardTabBody = Size(360, 700);

/// A gate with a canned status and no [Listenable] surface — the shape of the
/// const seam gate and of every DI fake. [JeeberKycGateBuilder] builds these
/// exactly once, which is also the debug/Maestro behaviour.
class _DashboardTabFixedKycGate implements JeeberKycStatusGate {
  const _DashboardTabFixedKycGate(this.status);

  @override
  final JeeberKycStatus status;

  @override
  bool get isApproved => status == JeeberKycStatus.approved;
}

/// Answers `GET /users/me` with one canned name and no avatar.
/// The avatar is deliberately absent: [JeeberHomeGreeting] renders a supplied
/// URL through `CachedNetworkImage`, so any URL here would be a fetch the canvas
class _DashboardTabCannedProfileRepository
    implements CustomerProfileRepository {
  const _DashboardTabCannedProfileRepository(this.name);

  final String name;

  @override
  Future<CustomerProfileViewData> fetchProfile() async =>
      CustomerProfileViewData(name: name);
}

/// Answers `GET /v1/deliveries?role=jeeber` with a canned list.
class _DashboardTabCannedActiveDeliveriesRepository
    implements ActiveDeliveriesRepository {
  const _DashboardTabCannedActiveDeliveriesRepository(this.deliveries);

  final List<ActiveDeliverySummary> deliveries;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async => deliveries;
}

/// One won order in the shape the gateway returns it, taken verbatim from the
/// live envelope pinned in `test/jeeber_active_deliveries_test.dart` so the
const ActiveDeliverySummary _dashboardTabWonDelivery = ActiveDeliverySummary(
  id: 'req-1',
  status: JeeberDeliveryStatus.inTransit,
  conversationId: 'conv-9',
  title: 'Flash delivery request',
  pickupAddress: 'Hamra',
  dropoffAddress: 'Achrafieh',
);

/// Registers one complete set of inert fakes into `sl` and builds the real
/// [DashboardTab] over them.
/// See the section doc above for why the registration lives in `initState`.
class _DashboardTabSeeded extends StatefulWidget {
  const _DashboardTabSeeded({
    required this.kycStatus,
    required this.profileName,
    required this.availabilityFails,
    required this.feed,
    required this.activeDeliveries,
  });

  final JeeberKycStatus kycStatus;

  /// Name the seeded getMe answers with, or `null` to leave the profile
  /// repository unregistered — then the greeting falls back to whatever the tab
  final String? profileName;

  /// When true the availability gateway throws, which is the ONLY read whose
  /// failure replaces the whole tab body (with `_LoadErrorView`).
  final bool availabilityFails;

  final List<DeliveryRequest> feed;
  final List<ActiveDeliverySummary> activeDeliveries;

  @override
  State<_DashboardTabSeeded> createState() => _DashboardTabSeededState();
}

class _DashboardTabSeededState extends State<_DashboardTabSeeded> {
  @override
  void initState() {
    super.initState();
    _put<JeeberKycStatusGate>(_DashboardTabFixedKycGate(widget.kycStatus));
    _put<AvailabilityGateway>(
      InMemoryAvailabilityGateway(
        initial: AvailabilityStatus.initial.copyWith(
          state: AvailabilityState.online,
        ),
        respondWithError: widget.availabilityFails,
      ),
    );
    _put<RequestFeedRepository>(SeededRequestFeedRepository(widget.feed));
    _put<ActiveDeliveriesRepository>(
      _DashboardTabCannedActiveDeliveriesRepository(widget.activeDeliveries),
    );
    final String? name = widget.profileName;
    if (name == null) {
      if (sl.isRegistered<CustomerProfileRepository>()) {
        sl.unregister<CustomerProfileRepository>();
      }
    } else {
      _put<CustomerProfileRepository>(
        _DashboardTabCannedProfileRepository(name),
      );
    }
  }

  /// Idempotent re-registration. `registerSingleton` throws on a duplicate, and
  /// the canvas mounts these previews repeatedly, so the previous instance is
  void _put<T extends Object>(T instance) {
    if (sl.isRegistered<T>()) sl.unregister<T>();
    sl.registerSingleton<T>(instance);
  }

  @override
  Widget build(BuildContext context) => const DashboardTab();
}

/// One state of the tab.
/// Every state below seeds the jeeber ONLINE. Offline is not a DashboardTab
Widget _dashboardTabHosted({
  required JeeberKycStatus kycStatus,
  String? profileName,
  bool availabilityFails = false,
  List<DeliveryRequest> feed = const <DeliveryRequest>[],
  List<ActiveDeliverySummary> activeDeliveries =
      const <ActiveDeliverySummary>[],
}) {
  return _DashboardTabSeeded(
    kycStatus: kycStatus,
    profileName: profileName,
    availabilityFails: availabilityFails,
    feed: feed,
    activeDeliveries: activeDeliveries,
  );
}

/// `none` — never onboarded. The only status that should ever reach the
/// register prompt (`delivery_register_prompt`), whose CTA chains into the
@JeebPreview(
  group: 'shell',
  name: 'KYC none · register prompt',
  size: _dashboardTabBody,
)
Widget dashboardTabRegisterPrompt() =>
    _dashboardTabHosted(kycStatus: JeeberKycStatus.none);

/// The W2-closer regression, at the level where it actually happened.
/// A registered jeeber whose KYC is still `pending` BROWSES the feed; only
@JeebPreview(
  group: 'shell',
  name: 'KYC pending · feed reachable',
  size: _dashboardTabBody,
)
Widget dashboardTabPendingKycFeed() => _dashboardTabHosted(
      kycStatus: JeeberKycStatus.pending,
      profileName: 'Layla',
      feed: DevJeeberFeedFixtures.incoming(),
    );

/// Approved and online, but nothing in range — the state a jeeber spends most
/// of a shift in, and the one that is easiest to mistake for a broken feed.
@JeebPreview(
  group: 'shell',
  name: 'KYC approved · quiet feed',
  size: _dashboardTabBody,
)
Widget dashboardTabApprovedQuietFeed() => _dashboardTabHosted(
      kycStatus: JeeberKycStatus.approved,
      profileName: 'Nadia',
    );

/// A won order, riding above a feed that is still non-empty (PUSH-UI-REACTION).
/// This is the regression the 2026-07-05 fix landed for: right after the jeeber
@JeebPreview(
  group: 'shell',
  name: 'Won delivery · banner over feed',
  size: _dashboardTabBody,
)
Widget dashboardTabWonDeliveryBanner() => _dashboardTabHosted(
      kycStatus: JeeberKycStatus.approved,
      profileName: 'Zeina',
      feed: DevJeeberFeedFixtures.incoming(),
      activeDeliveries: const <ActiveDeliverySummary>[
        _dashboardTabWonDelivery,
      ],
    );

/// The one read whose failure replaces the ENTIRE tab: availability.
/// `GET /v1/availability` throwing takes the body down to an icon, one line and
@JeebPreview(
  group: 'shell',
  name: 'Availability load failed',
  size: _dashboardTabBody,
)
Widget dashboardTabAvailabilityLoadError() => _dashboardTabHosted(
      kycStatus: JeeberKycStatus.approved,
      profileName: 'Karim',
      availabilityFails: true,
      feed: DevJeeberFeedFixtures.incoming(),
    );

/// `rejected` (D52/D87) — the frame before the redirect, made permanent.
/// In the app this destination is a post-frame `goNamed('kyc-rejected')`, and
@JeebPreview(
  group: 'shell',
  name: 'KYC rejected · pre-redirect frame',
  size: _dashboardTabBody,
)
Widget dashboardTabRejectedFrame() => _dashboardTabHosted(
      kycStatus: JeeberKycStatus.rejected,
      profileName: 'Nour',
    );
