import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/layout/bottom_inset.dart';
import '../../../core/widgets/jeeb/jeeb_select_chip.dart';
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

/// Client home screen — redesign-2026-08 screen 04 (`04-client-home.html`).
///
/// Layout top-to-bottom:
/// 1. Profile header: Ø46 avatar, time-of-day eyebrow, "Hello, {name}"
/// 2. The navy mic hero — the single create surface (`ClientHomeRequestHero`)
/// 3. Counted filter pills: Pending Requests | Replies (`JeebSelectChip`)
/// 4. Outlined request cards or the application-illustration empty state.
///
/// The debug-only In Progress surface still renders its order cards
/// (`ActiveOrderCard`) with avatar, name + tier badge,
///    destination, progress bar (Ordered → Picked → In Transit), and an
///    `OmdsPrimaryButton` "Track my order" CTA when actionable.
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

class _LoadingLayout extends StatelessWidget {
  const _LoadingLayout({required this.onCreateRequest});

  final VoidCallback? onCreateRequest;

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.xLarge,
          ),
          child: ClientHomeRequestHero(onCreateRequest: onCreateRequest),
        ),
        const SizedBox(height: Spacing.large),
        const Center(child: OmdsLoadingState()),
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
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.xLarge,
          ),
          child: ClientHomeRequestHero(onCreateRequest: onCreateRequest),
        ),
        const SizedBox(height: Spacing.xLarge),
        OmdsErrorState(
          icon: Icons.cloud_off_outlined,
          title: l10n.homeLoadFailedTitle,
          message: l10n.homeLoadFailedBody,
          retryLabel: l10n.homeLoadFailedRetry,
          onRetry: () => context.read<ClientHomeCubit>().load(),
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

  List<Widget> _scrollChildren() {
    return <Widget>[
      ClientHomeGreeting(
        name: state.greetingName,
        avatarSemanticsIdentifier:
            selectedTab == ClientHomeTab.pendingRequests &&
                state.pending.isEmpty
            ? '_request_empty_state_avatar'
            : null,
      ),
      const SizedBox(height: Spacing.medium),
      Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.xLarge,
        ),
        child: ClientHomeRequestHero(onCreateRequest: onCreateRequest),
      ),
      const SizedBox(height: Spacing.large),
      _ClientHomeTabBar(
        selectedTab: selectedTab,
        onSelected: onTabSelected,
        pendingCount: state.pending.length,
        repliesCount: state.replies.length,
      ),
      const SizedBox(height: Spacing.medium),
      _ReadyContent(
        selectedTab: selectedTab,
        onCreateRequest: onCreateRequest,
        onTrack: onTrack,
      ),
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

class _ClientHomeTabBar extends StatelessWidget {
  const _ClientHomeTabBar({
    required this.selectedTab,
    required this.onSelected,
    required this.pendingCount,
    required this.repliesCount,
  });

  final ClientHomeTab selectedTab;
  final ValueChanged<ClientHomeTab> onSelected;

  /// Rendered on the chip as the board's `Pending 1` / `Replies 3` count. Read
  /// straight off the already-loaded lists — no cubit change, no extra read.
  final int pendingCount;
  final int repliesCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // JEBV4-298 (E24/Q-086): the Requests tab is the ON-HOLD surface only —
    // Pending Requests + Replies. The accepted-onward In-Progress live-tracking
    // chip was relocated to the Delivery tab (its Active order detail exposes
    // the map/ETA/Track surface via `/orders/:id/tracking`), so it is
    // intentionally NOT listed here.
    final tabs = <_TabSpec>[
      _TabSpec(
        ClientHomeTab.pendingRequests,
        l10n.homeTabPendingRequests,
        pendingCount,
      ),
      _TabSpec(ClientHomeTab.replies, l10n.homeTabReplies, repliesCount),
    ];
    // `.scrollable`, not the fixed row: with the count badges the two labels
    // exceed a 390pt gutter-to-gutter line in EN, and more so under AR or a
    // raised text scale. The kit's scrollable form is a NON-lazy `Row`, so both
    // chips stay resolvable by `find.bySemanticsIdentifier` even off-screen —
    // the `orders_filter_*` / `orders_home_replies_tab` contracts are intact.
    return JeebChipRow.scrollable(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xLarge,
      ),
      spacing: Spacing.xSmall,
      children: [
        for (final tab in tabs)
          _ClientHomeTabChip(
            label: tab.label,
            isSelected: tab.tab == selectedTab,
            onTap: () => onSelected(tab.tab),
            keySuffix: tab.tab.name,
            // A zero count is not drawn: the board only ever shows a populated
            // one, and "Replies 0" next to an empty list is noise.
            count: tab.count > 0 ? tab.count : null,
            // JM-023 / JM-027: the Replies sub-tab carries the coined
            // `orders_home_replies_tab` identifier so QA can target it from
            // the Requests home as the tap target onto the Replies surface.
            extraIdentifier: tab.tab == ClientHomeTab.replies
                ? 'orders_home_replies_tab'
                : null,
          ),
      ],
    );
  }
}

class _TabSpec {
  const _TabSpec(this.tab, this.label, this.count);

  final ClientHomeTab tab;
  final String label;
  final int count;
}

class _ClientHomeTabChip extends StatelessWidget {
  const _ClientHomeTabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.keySuffix,
    this.count,
    this.extraIdentifier,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String keySuffix;

  /// Board count badge. Selected chips render it inline in the label's ink;
  /// unselected ones get the Ø18 orange badge. Kit-owned either way — and a
  /// separate `Text` in both, so `find.text('Replies')` still resolves.
  final int? count;

  /// An additional QA identifier wrapped around the chip (e.g. the coined
  /// `orders_home_replies_tab`). Kept distinct from the existing
  /// `orders_filter_<tab>` id so both id contracts stay targetable.
  final String? extraIdentifier;

  @override
  Widget build(BuildContext context) {
    Widget chip = Semantics(
      identifier: 'orders_filter_$keySuffix',
      button: true,
      selected: isSelected,
      label: label,
      child: JeebSelectChip(
        key: Key('client-home-tab-$keySuffix'),
        role: JeebChipRole.filter,
        label: label,
        selected: isSelected,
        onTap: onTap,
        count: count,
      ),
    );
    final extraId = extraIdentifier;
    if (extraId != null) {
      chip = Semantics(
        identifier: extraId,
        container: true,
        explicitChildNodes: true,
        child: chip,
      );
    }
    return chip;
  }
}
