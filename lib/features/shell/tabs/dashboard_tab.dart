import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/dev_seam/dev_seam.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/session/jeeber_kyc_status_gate.dart';
import '../../../l10n/app_localizations.dart';
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
    return _JeeberHomeHost(
      destination: JeeberDeliveryTabDestination.forStatus(gate.status),
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
  bool get _unregistered =>
      destination != JeeberDeliveryTabDestination.feed;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AvailabilityCubit>(
          create: (_) => AvailabilityCubit(gateway: sl<AvailabilityGateway>()),
        ),
        BlocProvider<RequestFeedCubit>(
          create: (_) =>
              RequestFeedCubit(repository: sl<RequestFeedRepository>())
                ..start(),
        ),
      ],
      child: Builder(
        builder: (context) => _GateScoped(
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: const Key('dashboard-tab-dev-feed'),
      appBar: OMDSAppBar(title: l10n.availabilityHomeTitle, centerTitle: false),
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
