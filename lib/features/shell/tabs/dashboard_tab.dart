import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev_seam/dev_seam.dart';
import '../../../core/di/injection_container.dart';
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

/// Selector for the deliveryman feed variant the dev seam should render
/// (Figma screens 23-26). Debug capture aid only — never reached in release.
enum _DevFeedView { empty, requests, pending, replies }

/// Jeeber-side "Home" tab in the role-aware bottom-nav shell. Delegates to
/// [JeeberHomeScreen] so the availability toggle is the first thing the
/// Jeeber sees on cold-start.
///
/// Wires the feed card → request-detail route (T-mobile-033) so tapping a
/// candidate from the feed opens the detail screen where the Jeeber can
/// review the request and, if needed, file a prohibited-item report. The
/// "Register now" upsell CTA → the delivery-man onboarding wizard
/// (screen 19 → 20).
///
/// In the dev-seam capture path (`jeeb.feed=<view>`), the tab instead renders
/// a self-contained, seeded feed surface so a single APK captures screens
/// 23-26 without a rebuild.
///
/// W2-INT (JM-036): the DELIVERY-tab body gates on REAL jeeber KYC status via
/// [JeeberKycStatusGate] (`sl<JeeberKycStatusGate>()`) instead of the old
/// dev-seam `jeeb.home_tab=unregistered` flag. Reconciled with D38 (KYC gates
/// OFFERING, not feed-browsing) per the
/// [JeeberDeliveryTabDestination.forStatus] mapping:
///   * `none`     → `delivery_register_prompt` (`JeeberHomeScreen(isRegistered:
///     false)`), whose "Register now" CTA → the onboarding wizard (JM-039).
///   * `pending`  → the jeeber request feed (`jeeber_feed_root`): a registered
///     jeeber BROWSES the feed; tapping `feed_make_offer_cta` routes through
///     `offer_kyc_gate` (JM-044/048) until approval — that is the only gated
///     action. This is the W2-closer fix: the old `!isApproved` collapse routed
///     `pending` jeebers to the register prompt, making the offer-KYC gate
///     unreachable.
///   * `approved` → the feed (`jeeber_feed_root`); offering allowed.
///   * `rejected` → redirect to the `kyc-rejected` screen (D52/D87); the tab
///     body renders the register prompt only for the frame before the redirect.
/// The gate's debug default reads `jeeb.seam.kyc_status` so a Maestro flow drives
/// the branch deterministically (65_W2_TEST_PLAN §3.1); release reports
/// approved until the JM-036 engineer swaps in the real getMe/kyc-backed gate.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final devView = _devSeamView();
    if (devView != null) return _DevFeedScaffold(view: devView);
    // JM-036 gate (D38-reconciled): resolve the DELIVERY-tab destination from
    // the gate. Resolve the gate from DI, falling back to the seam-backed
    // default when DI isn't wired (regression harnesses that mount DashboardTab
    // without configuring the gate) so the tab never throws a GetIt "not
    // registered" on entry.
    final gate = sl.isRegistered<JeeberKycStatusGate>()
        ? sl<JeeberKycStatusGate>()
        : const SeamJeeberKycStatusGate();
    // JEBV4-267: resolve the destination REACTIVELY. The release
    // LiveJeeberKycStatusGate reports a conservative non-approved status until
    // its live KYC fetch resolves, then notifies — JeeberKycGateBuilder rebuilds
    // so an approved/pending jeeber reaches the feed without a re-login. For the
    // const seam gate / test fakes (not Listenable) this builds exactly once, so
    // debug + Maestro behaviour is unchanged.
    return JeeberKycGateBuilder(
      gate: gate,
      builder: (context, gate) => _JeeberHomeHost(
        destination: JeeberDeliveryTabDestination.forStatus(gate.status),
      ),
    );
  }

  /// The deliveryman feed variant requested via the dev seam, or `null` when
  /// the seam isn't driving the dashboard. Debug-only — always `null` in
  /// release builds.
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

/// Hosts the production [JeeberHomeScreen] under a [MultiBlocProvider] that
/// supplies the two cubits the registered home reads: an [AvailabilityCubit]
/// (`didChangeDependencies` + `_RegisteredBody`'s `BlocConsumer`) and a
/// [RequestFeedCubit] (the active-delivery / request feed surface).
///
/// Before the availability provider existed, the role-switch into the Jeeber
/// surface mounted `JeeberHomeScreen(isRegistered: true)` with no
/// `AvailabilityCubit` ancestor — only the dev-seam feed path provided one — so
/// the registered screen threw `ProviderNotFound<AvailabilityCubit>` on entry
/// (E2E "Switch to Jeeber" crash).
///
/// JEEBER-LOOP F3: the host also did not pass a `requestFeedCubit`, so
/// [JeeberHomeScreen] stayed in State 2 (availability toggle only, no feed) —
/// the Jeeber had no in-app entry to an active delivery and could only reach
/// one via a deep link. Wiring a DI-backed [RequestFeedCubit] lights up State 3
/// (the live request / active-delivery feed) so tapping a card reaches the
/// chat → "Start delivery" → active-delivery → OTP entry chain that closes the
/// two-party loop. Both cubits are built from DI-registered gateways
/// (`sl<...>()`), matching how sibling route builders construct their
/// screen-scoped cubits.
///
/// Both providers wrap even the `unregistered` (screen-19) path: the
/// availability auto-offline ticker is owned by its cubit and the upsell view
/// simply never reads either cubit, so a single create-site avoids a second
/// provider tree. `BlocProvider.create` owns the cubit lifecycle (it is closed
/// on dispose), so we hand the created [RequestFeedCubit] to
/// [JeeberHomeScreen] — which re-exposes it via `BlocProvider.value` (a
/// non-owning view) — instead of constructing a second, leaked instance.
class _JeeberHomeHost extends StatelessWidget {
  const _JeeberHomeHost({required this.destination});

  final JeeberDeliveryTabDestination destination;

  /// The DELIVERY-tab body renders the register prompt (State 1) for both the
  /// `none` (not-onboarded) destination AND the `rejected` destination — the
  /// latter only for the single frame before [_GateScoped] redirects to the
  /// `kyc-rejected` screen (so a registered-but-rejected jeeber never sees the
  /// feed). The feed (State 2/3) renders only for `pending`/`approved`.
  bool get _unregistered => destination != JeeberDeliveryTabDestination.feed;

  /// The live profile source for the greeting. Self-provided off GetIt (no DI
  /// edit), mirroring how [CustomerProfileScreen] resolves its repo; `null` in
  /// a bare regression harness (no Dio registered) → the greeting stays generic.
  /// Resolve the active-deliveries repo from DI, mirroring the sibling repos.
  /// Falls back to a bare Dio-backed instance when only Dio is registered, and
  /// (in a bare harness with no Dio) to an empty repo so the banner self-hides
  /// rather than throwing a GetIt "not registered" on entry.
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

  /// Profile-changed broadcast (display-name saves) off GetIt when registered;
  /// `null` under bare tests so the greeting simply never re-pulls.
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
            // JEBV4-342 (b02): this is THE live jeeber feed cubit — the one
            // JeeberFeedTabView renders. The gateway's new-request fan-out
            // already reaches this device; before this wire it drove nothing,
            // so a fresh auction appeared only on the next poll tick. Same
            // resolver the active-deliveries card above uses: one bus, one
            // lookup. Null under a bare harness keeps the poll as sole input.
            //
            // b02 wave D — `{feed, offers}`. `new_request` opens an auction
            // (feed); `offer_accepted` / `offer_lost` / `request_expired`
            // remove a row from it (offers). A `chat` message and a plain
            // `delivery` status change cannot alter this snapshot, yet used to
            // re-pull the whole `GET /v1/requests` list.
            refreshSignals: resolvePushRefreshStream(
              topics: const {RefreshTopic.feed, RefreshTopic.offers},
            ),
          )..start(),
        ),
        // iter6 real-flow blocker fix: poll the jeeber's ACCEPTED/active
        // deliveries (`GET /v1/deliveries?role=jeeber`) so a freshly-accepted
        // offer surfaces a real-UI entry to its chat + delivery without leaving
        // the dashboard. Self-hides when the jeeber has none.
        BlocProvider<ActiveDeliveriesCubit>(
          create: (_) => ActiveDeliveriesCubit(
            repository: _resolveActiveDeliveriesRepository(),
            // Re-pull when a reachable `offer_accepted` notification lands —
            // and, since wave C proved the delivery-status transport live, on
            // every `type=delivery` transition too.
            //
            // b02 wave D — `{order}`. This card paints `GET /v1/deliveries?
            // role=jeeber`: whether this jeeber OWNS an active delivery and
            // what state it is in. `offer_accepted` publishes `{order, offers}`
            // so it still lands. `chat` and `new_request` no longer do — they
            // cannot add, remove or advance a row here, and this was the
            // 60s-poll surface a busy conversation would have out-paced.
            refreshSignals: resolvePushRefreshStream(
              topics: const {RefreshTopic.order},
            ),
          )..start(),
        ),
        // P0-X06: source the jeeber-home greeting (name + avatar) from the live
        // `GET /users/me` (role-agnostic getMe) so the header shows the real
        // name + avatar instead of "Welcome back" + "?". Falls back to the
        // generic greeting when getMe is unreachable / the account is nameless.
        BlocProvider<GreetingProfileCubit>(
          create: (_) => GreetingProfileCubit(
            repository: _resolveGreetingRepository(),
            // Profile-name lane: re-pull getMe on a display-name save so the
            // jeeber greeting picks the new name up while the tab stays alive
            // in the shell's IndexedStack.
            refreshSignals: _profileRefreshStream(),
          )..load(),
        ),
      ],
      child: Builder(
        // G3: refetch the feed on app resume + Dashboard-tab refocus
        // (mirrors the customer home's TabVisibility re-pull) so a request
        // whose push was dismissed is still findable when the jeeber looks.
        // Only the feed path mounts the refetcher — the register prompt has
        // no feed to refresh.
        builder: (context) => _MaybeResumeRefetch(
          enabled: !_unregistered,
          child: _GateScoped(
            destination: destination,
            child: JeeberHomeScreen(
              key: const Key('dashboard-tab-root'),
              isRegistered: !_unregistered,
              profileName: _unregistered ? 'Kamal' : null,
              // JM-036: when the gate renders the register prompt (State 1), the
              // home screen wraps its "Register now" CTA in an additional
              // `delivery_register_now_cta` Semantics so the JM-036 flow can tap
              // it by the coined id (the W0 `jeeber_unregistered_register_button`
              // id is preserved underneath for the screen-19 flow).
              registerCtaIdentifier: 'delivery_register_now_cta',
              requestFeedCubit: context.read<RequestFeedCubit>(),
              // iter6 real-flow blocker fix: the accepted/active-deliveries banner
              // is built HERE (the host owns navigation) and rendered at the top
              // of the registered jeeber home. Tapping a row opens the order chat
              // (`/chat/:id`, conversation already exists) — which is role-aware
              // for a jeeber and exposes Start delivery → `/jeeber/deliveries/:id/
              // active`. "Manage delivery" opens that active-delivery screen
              // directly.
              activeDeliveriesBanner: _unregistered
                  ? null
                  : ActiveDeliveriesBanner(
                      onOpenChat: (d) => context.push('/chat/${d.chatRouteId}'),
                      onManageDelivery: (d) =>
                          context.push('/jeeber/deliveries/${d.id}/active'),
                    ),
              // JM-036 AC1b / JM-039: the register-prompt CTA chains into the
              // delivery-man onboarding wizard (photo step). The wizard's own
              // `dm_onboarding_continue` / `dm_onboarding_back` ids are JM-039's.
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

/// Mounts [FeedResumeRefetcher] around the feed-destination body only; the
/// register-prompt destinations render [child] bare (no feed to refresh).
/// Kept as a widget (not an inline ternary) so the wrapped/unwrapped branches
/// share one build site and the tree diff stays minimal on gate flips.
class _MaybeResumeRefetch extends StatelessWidget {
  const _MaybeResumeRefetch({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // b02 READ ECONOMICS: "visible" is tab-selected AND nothing pushed on top of
    // the shell. Without the route half, the feed and the active-deliveries card
    // kept polling and kept answering the push bus while the jeeber was on the
    // request-detail or active-delivery route above them.
    final shellVisible =
        (TabVisibility.maybeOf(context)?.isVisible ?? true) &&
        RouteVisibilityScope.isOnTop(context);
    final activeDeliveriesGate = PollingVisibilityGate(
      target: context.read<ActiveDeliveriesCubit>(),
      isVisible: shellVisible,
      child: child,
    );
    if (!enabled) return activeDeliveriesGate;
    return PollingVisibilityGate(
      target: context.read<RequestFeedCubit>(),
      isVisible: shellVisible,
      child: FeedResumeRefetcher(child: activeDeliveriesGate),
    );
  }
}

/// Places the JM-036 coined screen-level *root* Semantics id on the DELIVERY-tab
/// body so the QA flow (`jm-036-delivery-tab-kyc-gate.yaml`) can assert the
/// gate branch by identifier (65_W2_TEST_PLAN §2 JM-036), without disturbing the
/// W0-asserted widget ids inside [JeeberUnregisteredView] (`jeeber_unregistered_*`)
/// or [JeeberFeedTabView] (`jeeber_feed_search_field`):
///
///   * [JeeberDeliveryTabDestination.registerPrompt] (`none`) →
///     `delivery_register_prompt` (root) wraps the register prompt.
///     `explicitChildNodes` keeps the nested W0 `jeeber_unregistered_*` and the
///     `delivery_register_now_cta` nodes individually queryable (same CAP-3
///     boundary pattern as `JeeberUnregisteredView`'s own root), so the existing
///     screen-19 flow still passes.
///   * [JeeberDeliveryTabDestination.feed] (`pending`/`approved`) →
///     `jeeber_feed_root` (root) wraps the feed surface; the flow asserts it is
///     shown and `delivery_register_prompt` is NOT. A `pending` jeeber browses
///     this feed and reaches the offer-KYC gate via `feed_make_offer_cta`
///     (JM-044/048, D38).
///   * [JeeberDeliveryTabDestination.kycRejected] (`rejected`) → a post-frame
///     redirect to the `kyc-rejected` screen (D52/D87). The body carries the
///     `delivery_register_prompt` root for the single frame before the redirect
///     fires, so a rejected jeeber never lands on the feed.
///
/// The root id sits on the gate host (this file, the JM-036 target per
/// 20_GAP_MAP.md row JM-036) rather than inside the shared home widgets, so the
/// gate's branches each expose exactly one screen-level root id regardless of
/// which inner State (1/2/3) [JeeberHomeScreen] renders.
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

  /// `rejected` is terminal (D52/D87): the DELIVERY tab must not host the feed
  /// or the register prompt for a rejected jeeber — it redirects to the
  /// dedicated `kyc-rejected` screen. Done after the first frame (the tab is
  /// built inside the shell's IndexedStack) and guarded by `GoRouter.maybeOf`
  /// so it is a no-op in a router-less widget test.
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

/// Self-contained scaffold for the dev-seam feed capture path. Owns its own
/// seeded [RequestFeedCubit] so it needs no shell-provided availability cubit.
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

/// Body of the dev-seam feed scaffold: an empty view or a seeded feed tab view
/// for the selected [view].
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
    // Provide a dev-only availability cubit (always-online) so
    // JeeberFeedTabView can read it for the offline-banner check.
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
            // JEBV4-342 (b02): wired for parity with the live host so the
            // dev-seam feed exercises the same code path. The seeded repository
            // replays a fixture snapshot, so a push here re-pulls the fixture —
            // harmless, and it keeps the two constructions from diverging.
            // Same topics as the live host, for the same reason.
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

/// Inert [ActiveDeliveriesRepository] for the no-DI (bare widget test) path —
/// reports no active deliveries so the banner self-hides without a network
/// call. Production always resolves the Dio-backed repo.
class _EmptyActiveDeliveriesRepository implements ActiveDeliveriesRepository {
  const _EmptyActiveDeliveriesRepository();

  @override
  Future<List<ActiveDeliverySummary>> listActive() async =>
      const <ActiveDeliverySummary>[];
}
