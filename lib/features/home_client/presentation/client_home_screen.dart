import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/layout/bottom_inset.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_segmented_toggle.dart';
import '../../../l10n/app_localizations.dart';
import '../../shell/tab_visibility.dart';
import '../application/client_home_cubit.dart';
import '../application/client_home_state.dart';
import '../domain/client_home_request.dart';
import 'tabs/in_progress_tab.dart';
import 'tabs/pending_requests_tab.dart';
import 'tabs/replies_tab.dart';
import 'widgets/client_home_greeting.dart';
import 'widgets/client_home_request_hero.dart';

/// Client home screen — MIDNIGHT R1 (`01-r1-client-home.png`) and its E1 empty
/// (`27-e1-empty-no-requests.png`), on the hero `JeebMidnightField`.
///
/// R1 top-to-bottom: profile header · white prompt + orange Arabic tagline ·
/// frosted voice capsule · Pending/Replies segmented toggle · glass cards.
/// E1 is the board's OTHER composition of the same parts: header · toggle ·
/// the composed empty illustration · the capsule beneath it. Which one renders
/// is decided by [_ReadyLayout] from the selected tab's emptiness, so the
/// prompt is never printed twice on one screen.
///
/// The field's decor is drawn but NOT animated (`03-MOTION-NOTES` §R1: zero
/// animated elements, including the broadcast dot and the orbit rings).
class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({
    super.key,
    this.onOpenRequest,
    this.onCreateRequest,
    this.onTrack,
    this.initialTab = ClientHomeTab.pendingRequests,
  });

  /// Legacy "open the conversation for a request" hook. Retained for API
  /// compatibility with the shell host (`shell/tabs/home_tab.dart`) and the
  /// widget tests that still pass it. As of JM-027/JM-023 it no longer drives
  /// the Pending and Replies sub-tabs: Pending rows route to
  /// `waiting-no-coverage` (JM-026) and Replies CTAs route to `offer-review`
  /// (JM-028) / `offer-accept-confirm` (JM-029) from inside their own tabs, so
  /// `my-orders` no longer opens `/chat/:id` (the divergence 20_GAP_MAP flagged).
  final void Function(ClientHomeRequest request)? onOpenRequest;
  final VoidCallback? onCreateRequest;

  /// Opens the live-tracking screen (`/orders/:id/tracking`) for an in-progress
  /// delivery's "Track my order" CTA. Distinct from [onOpenRequest]. When null
  /// the [InProgressTab] falls back to GoRouter navigation directly.
  final void Function(ClientHomeRequest request)? onTrack;

  /// Which filter chip is selected on first render. Defaults to Pending
  /// Requests — JEBV4-298 (E24/Q-086): the Requests bottom-nav tab is the
  /// ON-HOLD surface only (Pending + Replies). The accepted-onward
  /// In-Progress live-tracking surface was relocated to the Delivery tab
  /// (`/orders/:id` → Track → `/orders/:id/tracking`), so the In-Progress
  /// chip is no longer part of this tab bar. The dev seam may still pin an
  /// explicit tab (including [ClientHomeTab.inProgress] for a debug-only
  /// capture of the isolated surface) so a single APK can land on any list
  /// without a rebuild.
  final ClientHomeTab initialTab;

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen>
    with WidgetsBindingObserver {
  late ClientHomeTab _selectedTab = widget.initialTab;

  /// Whether the app is in the foreground. The 10s home poll must NOT keep
  /// firing while the app is backgrounded (F3 — offers polling storm): a hidden
  /// app hammering `/requests` + `/deliveries` + `/v1/offers` is pure waste and
  /// a fast path to a 429. Starts true (a freshly-built screen is foreground).
  bool _appResumed = true;

  /// True once a sub-tab has been chosen — either by the user tapping a chip or
  /// by the one-shot "land on the first populated tab" affordance below. Guards
  /// the affordance so it never fights a manual selection on later rebuilds.
  bool _tabResolved = false;

  /// Last-observed shell-tab visibility, used to detect the off-screen →
  /// on-screen transition. `null` until the first [didChangeDependencies] so we
  /// never auto-refresh on the very first frame ([initState] owns that load).
  bool? _wasVisible;

  /// Captured in [didChangeDependencies] so the resume refetch can reach the
  /// cubit without an unsafe `context.read` from a lifecycle callback.
  ClientHomeCubit? _homeCubit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<ClientHomeCubit>();
      if (cubit.state.status == ClientHomeStatus.initial) {
        cubit.load();
      }
    });
  }

  /// N3's RESUME one-shot — the backstop that makes a DROPPED push cost
  /// freshness until the user next looks, instead of a permanently wrong
  /// screen. One silent [ClientHomeCubit.refresh] when the app comes back to
  /// the foreground, iff this tab is on screen.
  ///
  /// b02 P0 — deliberately NOT moved to [AppResumeSignals], unlike the other
  /// seven resume-refetch surfaces, and the reason SURVIVES the poll deletion:
  /// the `if (resumed == _appResumed) return;` line below makes this an EDGE
  /// trigger, and that is why this screen contributed ZERO reads to the
  /// measured 60-read storm while the three level-triggered observers
  /// contributed twenty each. It is also the control that proves the platform
  /// re-delivered `resumed` with no intervening background state — had there
  /// been one, this guard would have re-armed and `/requests` + `/deliveries`
  /// would appear in the capture. They do not. Swapping a working edge trigger
  /// for the shared bus would buy nothing and retire that control.
  ///
  /// (The second reason recorded here — "`_appResumed` gates the 10 s poll,
  /// which must stop on the RAW `paused` notification" — is now moot: there is
  /// no poll to gate.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _appResumed) return;
    _appResumed = resumed;
    if (!resumed) return;
    // Back-to-foreground: one immediate refresh iff this tab is on-screen.
    final cubit = _homeCubit;
    final isVisible = TabVisibility.maybeOf(context)?.isVisible ?? true;
    if (cubit == null || !isVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cubit.refresh();
    });
  }

  /// S13 auto-refresh: the Requests tab is an [IndexedStack] child, so
  /// re-entering it from the bottom nav (or returning from a create/accept
  /// flow that left the shell mounted) does NOT re-run [initState]. Watch the
  /// shell-provided [TabVisibility] and, whenever this tab goes off-screen →
  /// on-screen, silently re-pull so a freshly created/accepted order surfaces
  /// without a manual pull-to-refresh. [ClientHomeCubit.refresh] keeps the
  /// current data painted (no loading flash) and drops re-entrant calls.
  /// Outside the shell (bare tests / deep links) [TabVisibility.maybeOf] is
  /// null → treated as always-visible → this affordance is inert.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _homeCubit = context.read<ClientHomeCubit>();
    final isVisible = TabVisibility.maybeOf(context)?.isVisible ?? true;
    final becameVisible = _wasVisible == false && isVisible;
    _wasVisible = isVisible;
    if (!becameVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ClientHomeCubit>().refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// JM-023 AC2 (updated for JEBV4-298): when data first lands, surface the
  /// requests that actually exist. The Requests tab is now on-hold only, so the
  /// default landing chip is Pending Requests. If the caller left that default
  /// selected (i.e. the dev seam / a deep-link did NOT pin a specific tab) and
  /// Pending is empty while Replies has content, advance to Replies. This is a
  /// one-shot "land where the content is" affordance; once the user taps a chip
  /// [_tabResolved] is set and the selection is never overridden again.
  void _resolveInitialTab(ClientHomeState state) {
    if (_tabResolved) return;
    if (state.status != ClientHomeStatus.ready) return;
    _tabResolved = true;
    // Respect an explicit (non-default) starting tab — capture flows pin one.
    if (widget.initialTab != ClientHomeTab.pendingRequests) return;
    if (state.pending.isNotEmpty) return;
    if (state.replies.isEmpty) return;
    const populated = ClientHomeTab.replies;
    if (populated == _selectedTab) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedTab = populated);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientHomeCubit, ClientHomeState>(
      builder: (context, state) {
        _resolveInitialTab(state);
        return Semantics(
          identifier: 'client_home_root',
          container: true,
          explicitChildNodes: true,
          child: JeebMidnightField(
            variant: JeebFieldVariant.hero,
            animateDecor: false,
            child: OmdsPullToRefresh(
              onRefresh: () => context.read<ClientHomeCubit>().refresh(),
              child: _ClientHomeBody(
                state: state,
                selectedTab: _selectedTab,
                onTabSelected: (tab) {
                  setState(() {
                    _tabResolved = true;
                    _selectedTab = tab;
                  });
                },
                onCreateRequest: widget.onCreateRequest,
                onTrack: widget.onTrack,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ClientHomeBody extends StatelessWidget {
  const _ClientHomeBody({
    required this.state,
    required this.selectedTab,
    required this.onTabSelected,
    required this.onCreateRequest,
    required this.onTrack,
  });

  final ClientHomeState state;
  final ClientHomeTab selectedTab;
  final ValueChanged<ClientHomeTab> onTabSelected;
  final VoidCallback? onCreateRequest;
  final void Function(ClientHomeRequest)? onTrack;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case ClientHomeStatus.initial:
      case ClientHomeStatus.loading:
        return _LoadingLayout(onCreateRequest: onCreateRequest);
      case ClientHomeStatus.failed:
        return _FailedLayout(
          name: state.greetingName,
          onCreateRequest: onCreateRequest,
        );
      case ClientHomeStatus.ready:
        return _ReadyLayout(
          state: state,
          selectedTab: selectedTab,
          onTabSelected: onTabSelected,
          onCreateRequest: onCreateRequest,
          onTrack: onTrack,
        );
    }
  }
}

/// Screen gutter (token sheet §5) for every block this screen stacks.
const EdgeInsetsGeometry _kGutter = EdgeInsetsDirectional.symmetric(
  horizontal: Spacing.xLarge,
);

class _LoadingLayout extends StatelessWidget {
  const _LoadingLayout({required this.onCreateRequest});

  final VoidCallback? onCreateRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Reserve the system nav-bar inset so the last item clears the soft
      // buttons / bottom nav bar in edge-to-edge mode. See [BottomInsetX].
      padding: EdgeInsets.only(bottom: context.scrollBodyBottomInset),
      children: [
        const ClientHomeGreeting(name: null),
        const SizedBox(height: Spacing.medium),
        // The create surface must survive a degraded load — a spinner with no
        // way to start a request is the defect this mirrors on all three
        // layouts (client_home_429_tolerant_test.dart:196).
        Padding(
          padding: _kGutter,
          child: ClientHomeRequestHero(
            onCreateRequest: onCreateRequest,
            showPrompt: false,
          ),
        ),
        const SizedBox(height: Spacing.large),
        JeebEmptyState(
          status: JeebEmptyStateStatus.loading,
          headline: l10n.homeEmptyTitle,
        ),
      ],
    );
  }
}

class _FailedLayout extends StatelessWidget {
  const _FailedLayout({required this.name, required this.onCreateRequest});

  final String? name;
  final VoidCallback? onCreateRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Reserve the system nav-bar inset so the retry CTA clears the soft
      // buttons / bottom nav bar in edge-to-edge mode. See [BottomInsetX].
      padding: EdgeInsets.only(bottom: context.scrollBodyBottomInset),
      children: [
        ClientHomeGreeting(name: name),
        const SizedBox(height: Spacing.medium),
        Padding(
          padding: _kGutter,
          child: ClientHomeRequestHero(
            onCreateRequest: onCreateRequest,
            showPrompt: false,
          ),
        ),
        const SizedBox(height: Spacing.large),
        JeebEmptyState(
          status: JeebEmptyStateStatus.error,
          headline: l10n.homeLoadFailedTitle,
          body: l10n.homeLoadFailedBody,
          action: IntrinsicWidth(
            child: JeebCtaButton.primary(
              label: l10n.homeLoadFailedRetry,
              identifier: 'client_home_retry_cta',
              expand: false,
              onTap: () => context.read<ClientHomeCubit>().load(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadyLayout extends StatelessWidget {
  const _ReadyLayout({
    required this.state,
    required this.selectedTab,
    required this.onTabSelected,
    required this.onCreateRequest,
    required this.onTrack,
  });

  final ClientHomeState state;
  final ClientHomeTab selectedTab;
  final ValueChanged<ClientHomeTab> onTabSelected;
  final VoidCallback? onCreateRequest;
  final void Function(ClientHomeRequest)? onTrack;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Keep the design's twoXLarge breathing room AND reserve the system
      // nav-bar inset so the last order card clears the soft buttons / bottom
      // nav bar in edge-to-edge mode. See [BottomInsetX.scrollBodyBottomInset].
      padding: EdgeInsets.only(
        bottom: Spacing.twoXLarge + context.scrollBodyBottomInset,
      ),
      children: _scrollChildren(),
    );
  }

  /// True on the pending tab with nothing pending — E1's own composition, and
  /// the only state that re-homes the empty CTA identifier.
  bool get _pendingEmpty =>
      selectedTab == ClientHomeTab.pendingRequests && state.pending.isEmpty;

  /// Either tab showing its empty block: the prompt moves into that block, so
  /// the capsule follows it to the bottom the way the E1 tile draws.
  bool get _emptyComposition =>
      _pendingEmpty ||
      (selectedTab == ClientHomeTab.replies && state.replies.isEmpty);

  List<Widget> _scrollChildren() {
    final bool empty = _emptyComposition;
    final Widget capsule = Padding(
      padding: _kGutter,
      child: ClientHomeRequestHero(
        onCreateRequest: onCreateRequest,
        showPrompt: !empty,
        firstRequest: _pendingEmpty,
      ),
    );
    return <Widget>[
      ClientHomeGreeting(
        name: state.greetingName,
        avatarSemanticsIdentifier: _pendingEmpty
            ? '_request_empty_state_avatar'
            : null,
      ),
      const SizedBox(height: Spacing.medium),
      if (!empty) ...<Widget>[capsule, const SizedBox(height: Spacing.large)],
      _ClientHomeTabBar(selectedTab: selectedTab, onSelected: onTabSelected),
      const SizedBox(height: Spacing.medium),
      _ReadyContent(
        selectedTab: selectedTab,
        onCreateRequest: onCreateRequest,
        onTrack: onTrack,
      ),
      if (empty) ...<Widget>[const SizedBox(height: Spacing.large), capsule],
    ];
  }
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    required this.selectedTab,
    required this.onCreateRequest,
    required this.onTrack,
  });

  final ClientHomeTab selectedTab;
  final VoidCallback? onCreateRequest;
  final void Function(ClientHomeRequest)? onTrack;

  @override
  Widget build(BuildContext context) {
    switch (selectedTab) {
      case ClientHomeTab.inProgress:
        return InProgressTab(onTrack: onTrack);
      case ClientHomeTab.pendingRequests:
        // JM-023 AC2: a pending request row routes to `waiting-no-coverage`
        // (the live broadcast/wait state, JM-026) — NOT the chat thread. We
        // pass an explicit waiting handler so the pending tap target diverges
        // from the Replies/In-Progress chat/track callbacks; the rows carry
        // the indexed `orders_home_request_row_<n>` identifier inside the tab.
        return PendingRequestsTab(
          onTap: (request) => _openWaiting(context, request),
          onCreateRequest: onCreateRequest,
        );
      case ClientHomeTab.replies:
        // JM-027: the Replies sub-tab owns its own navigation — Check Offers →
        // offer-review-list (JM-028) and Accept → offer-accept-confirm sheet
        // (JM-029). It MUST NOT reuse `onOpenRequest` (which routes to
        // `/chat/:id`, the divergent edge 20_GAP_MAP flagged for `my-orders`),
        // so no callbacks are injected here — RepliesTab's defaults apply.
        return const RepliesTab();
    }
  }

  /// JM-023 AC2: route a pending request row to its waiting / no-coverage
  /// state (`waiting-no-coverage` → `/requests/:id/waiting`, JM-026), keyed by
  /// the request id. Defends an empty id (the route requires the path param).
  void _openWaiting(BuildContext context, ClientHomeRequest request) {
    if (request.id.isEmpty) return;
    GoRouter.of(
      context,
    ).pushNamed('waiting-no-coverage', pathParameters: {'id': request.id});
  }
}

/// E1's segmented Pending/Replies control (study-notes ruling 3): the active
/// segment is a WHITE fill with navy ink, the other stays glass. The board
/// draws no count badge on either, so none is rendered.
class _ClientHomeTabBar extends StatelessWidget {
  const _ClientHomeTabBar({required this.selectedTab, required this.onSelected});

  /// JEBV4-298 (E24/Q-086): the Requests tab is the ON-HOLD surface only. The
  /// accepted-onward In-Progress surface lives on the Delivery tab.
  static const List<ClientHomeTab> _tabs = <ClientHomeTab>[
    ClientHomeTab.pendingRequests,
    ClientHomeTab.replies,
  ];

  final ClientHomeTab selectedTab;
  final ValueChanged<ClientHomeTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // TODO(midnight): l10n-queued homeTabPending — the tile's segment reads
    // "Pending", which is also what keeps the control at the drawn width.
    final labels = <String>[l10n.homeTabPendingRequests, l10n.homeTabReplies];
    return Padding(
      padding: _kGutter,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Stack(
          children: <Widget>[
            // E1 draws no enclosing track: two free pills that hug their
            // labels at the start edge (wave-A trackless placement).
            JeebSegmentedToggle(
              placement: JeebSegmentedPlacement.trackless,
              segments: <JeebSegment>[
                for (var i = 0; i < _tabs.length; i++)
                  JeebSegment(
                    label: labels[i],
                    key: Key('client-home-tab-${_tabs[i].name}'),
                    identifier: 'orders_filter_${_tabs[i].name}',
                  ),
              ],
              selectedIndex: _tabs.indexOf(selectedTab),
              onChanged: (index) => onSelected(_tabs[index]),
            ),
            // JM-023 / JM-027's coined `orders_home_replies_tab`: a second id
            // for the same target, laid over the Replies half so QA still taps
            // real bounds (the kit segment carries only one identifier).
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 1,
                    child: Semantics(
                      identifier: 'orders_home_replies_tab',
                      button: true,
                      label: l10n.homeTabReplies,
                      onTap: () => onSelected(ClientHomeTab.replies),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
