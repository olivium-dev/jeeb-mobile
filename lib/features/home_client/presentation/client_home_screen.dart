import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/layout/bottom_inset.dart';
import '../../../l10n/app_localizations.dart';
import '../application/client_home_cubit.dart';
import '../application/client_home_state.dart';
import '../domain/client_home_request.dart';
import 'tabs/in_progress_tab.dart';
import 'tabs/pending_requests_tab.dart';
import 'tabs/replies_tab.dart';
import 'widgets/client_home_empty_view.dart';
import 'widgets/client_home_greeting.dart';
import 'widgets/client_home_voice_cta.dart';

/// Client home screen matching the Figma design (node 56535:1525).
///
/// Layout top-to-bottom:
/// 1. Greeting header with avatar, "Hello, {name}", "Everything, One Place", and "+" button
/// 2. Pill-shaped search bar (`OmdsSearchBar`)
/// 3. Tab chips row: In Progress | Pending Requests | Replies (`OmdsChip`)
/// 4. Order cards (`ActiveOrderCard`) with avatar, name + tier badge,
///    destination, progress bar (Ordered → Picked → In Transit), and an
///    `OmdsPrimaryButton` "Track my order" CTA when actionable.
class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({
    super.key,
    this.onOpenRequest,
    this.onCreateRequest,
    this.onRecordVoice,
    this.onTrack,
    this.initialTab = ClientHomeTab.inProgress,
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

  /// Opens the voice-request recorder (`/voice-request`). Supplied by the
  /// HomeTab shell; when null the voice CTA is not rendered.
  final VoidCallback? onRecordVoice;

  /// Which filter chip is selected on first render. Defaults to In Progress;
  /// the dev seam drives this so a single APK can land on Pending / Replies
  /// for capture without a rebuild.
  final ClientHomeTab initialTab;

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  late ClientHomeTab _selectedTab = widget.initialTab;

  /// True once a sub-tab has been chosen — either by the user tapping a chip or
  /// by the one-shot "land on the first populated tab" affordance below. Guards
  /// the affordance so it never fights a manual selection on later rebuilds.
  bool _tabResolved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<ClientHomeCubit>();
      if (cubit.state.status == ClientHomeStatus.initial) {
        cubit.load();
      }
    });
  }

  /// JM-023 AC2: when data first lands, surface the requests that actually
  /// exist. If the caller left the default In Progress chip selected (i.e. the
  /// dev seam / a deep-link did NOT pin a specific tab) and In Progress is
  /// empty while another tab has content, advance to the first populated tab —
  /// Pending Requests first (the seeded pending journey), then Replies. This is
  /// a one-shot "land where the content is" affordance; once the user taps a
  /// chip [_tabResolved] is set and the selection is never overridden again.
  void _resolveInitialTab(ClientHomeState state) {
    if (_tabResolved) return;
    if (state.status != ClientHomeStatus.ready) return;
    _tabResolved = true;
    // Respect an explicit (non-default) starting tab — capture flows pin one.
    if (widget.initialTab != ClientHomeTab.inProgress) return;
    if (state.inProgress.isNotEmpty) return;
    final ClientHomeTab? populated = state.pending.isNotEmpty
        ? ClientHomeTab.pendingRequests
        : (state.replies.isNotEmpty ? ClientHomeTab.replies : null);
    if (populated == null || populated == _selectedTab) return;
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
        // JM-023: the New Order FAB (`orders_home_new_order_fab`) is the
        // signature create-flow entry on the Requests tab and must be present
        // regardless of load phase / list contents, so it is overlaid on the
        // scrollable body via a Stack rather than rendered inside the list.
        // (The tab is a body inside the shell's IndexedStack — there is no
        // Scaffold here to host a `floatingActionButton`.)
        return Stack(
          children: [
            Positioned.fill(
              child: OmdsPullToRefresh(
                onRefresh: () => context.read<ClientHomeCubit>().refresh(),
                child: _ClientHomeBody(
                  state: state,
                  selectedTab: _selectedTab,
                  onTabSelected: (tab) => setState(() {
                    _tabResolved = true;
                    _selectedTab = tab;
                  }),
                  onCreateRequest: widget.onCreateRequest,
                  onRecordVoice: widget.onRecordVoice,
                  onTrack: widget.onTrack,
                ),
              ),
            ),
            _ClientHomeNewOrderFab(onCreateRequest: widget.onCreateRequest),
          ],
        );
      },
    );
  }
}

/// JM-023 AC3: the "New Order" FAB on the Requests tab. Carries the
/// signature `orders_home_new_order_fab` identifier and routes to
/// `request-type-selection` (the existing `request-type` route) via the
/// shell-supplied [onCreateRequest]. Falls back to a direct GoRouter push when
/// no callback is wired (release always supplies one through HomeTab).
class _ClientHomeNewOrderFab extends StatelessWidget {
  const _ClientHomeNewOrderFab({required this.onCreateRequest});

  final VoidCallback? onCreateRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PositionedDirectional(
      end: Spacing.medium,
      bottom: Spacing.medium + context.scrollBodyBottomInset,
      child: Semantics(
        identifier: 'orders_home_new_order_fab',
        button: true,
        // Tooltip-only label (not a visible Text child) so the FAB carries the
        // create-flow affordance without colliding with the empty-state hero's
        // visible "New Order" CTA text.
        label: l10n.homeNewOrderCta,
        child: FloatingActionButton(
          heroTag: 'orders-home-new-order-fab',
          tooltip: l10n.homeNewOrderCta,
          onPressed: () => _onPressed(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _onPressed(BuildContext context) {
    final onCreate = onCreateRequest;
    if (onCreate != null) {
      onCreate();
      return;
    }
    // Honest fallback target: the create-flow tier-selection step
    // (request-type-selection → existing `request-type` route).
    GoRouter.of(context).pushNamed('request-type');
  }
}

class _ClientHomeBody extends StatelessWidget {
  const _ClientHomeBody({
    required this.state,
    required this.selectedTab,
    required this.onTabSelected,
    required this.onCreateRequest,
    required this.onRecordVoice,
    required this.onTrack,
  });

  final ClientHomeState state;
  final ClientHomeTab selectedTab;
  final ValueChanged<ClientHomeTab> onTabSelected;
  final VoidCallback? onCreateRequest;
  final VoidCallback? onRecordVoice;
  final void Function(ClientHomeRequest)? onTrack;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case ClientHomeStatus.initial:
      case ClientHomeStatus.loading:
        return _LoadingLayout(
          onCreateRequest: onCreateRequest,
          onRecordVoice: onRecordVoice,
        );
      case ClientHomeStatus.failed:
        return _FailedLayout(
          name: state.greetingName,
          onCreateRequest: onCreateRequest,
          onRecordVoice: onRecordVoice,
        );
      case ClientHomeStatus.ready:
        if (_hasNoRequests(state)) {
          return ClientHomeEmptyView(
            name: state.greetingName,
            onNewOrder: onCreateRequest,
          );
        }
        return _ReadyLayout(
          state: state,
          selectedTab: selectedTab,
          onTabSelected: onTabSelected,
          onCreateRequest: onCreateRequest,
          onRecordVoice: onRecordVoice,
          onTrack: onTrack,
        );
    }
  }

  /// True when the client has zero requests across every tab — the
  /// "No orders yet" hero empty state (Figma 56535:1514) applies.
  bool _hasNoRequests(ClientHomeState state) =>
      state.inProgress.isEmpty &&
      state.pending.isEmpty &&
      state.replies.isEmpty;
}

class _LoadingLayout extends StatelessWidget {
  const _LoadingLayout({
    required this.onCreateRequest,
    required this.onRecordVoice,
  });

  final VoidCallback? onCreateRequest;
  final VoidCallback? onRecordVoice;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Reserve the system nav-bar inset so the last item clears the soft
      // buttons / bottom nav bar in edge-to-edge mode. See [BottomInsetX].
      padding: EdgeInsets.only(bottom: context.scrollBodyBottomInset),
      children: [
        ClientHomeGreeting(name: null, onAddPressed: onCreateRequest),
        _ClientHomeVoiceRequestCta(onRecordVoice: onRecordVoice),
        const _ClientHomeSearchBar(),
        const SizedBox(height: Spacing.large),
        const Center(child: OmdsLoadingState()),
      ],
    );
  }
}

/// Renders the voice-request CTA below the greeting on every home layout,
/// gated on a non-null [onRecordVoice] (the HomeTab shell supplies it). Wraps
/// the OMDS button in a QA-targetable Semantics node. Routes to
/// `/voice-request`.
class _ClientHomeVoiceRequestCta extends StatelessWidget {
  const _ClientHomeVoiceRequestCta({required this.onRecordVoice});

  final VoidCallback? onRecordVoice;

  @override
  Widget build(BuildContext context) {
    final onRecord = onRecordVoice;
    if (onRecord == null) return const SizedBox.shrink();
    return Semantics(
      identifier: 'client_home_voice_request',
      button: true,
      child: ClientHomeVoiceCta(onPressed: onRecord),
    );
  }
}

class _FailedLayout extends StatelessWidget {
  const _FailedLayout({
    required this.name,
    required this.onCreateRequest,
    required this.onRecordVoice,
  });

  final String? name;
  final VoidCallback? onCreateRequest;
  final VoidCallback? onRecordVoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Reserve the system nav-bar inset so the retry CTA clears the soft
      // buttons / bottom nav bar in edge-to-edge mode. See [BottomInsetX].
      padding: EdgeInsets.only(bottom: context.scrollBodyBottomInset),
      children: [
        ClientHomeGreeting(name: name, onAddPressed: onCreateRequest),
        _ClientHomeVoiceRequestCta(onRecordVoice: onRecordVoice),
        const _ClientHomeSearchBar(),
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
    required this.onRecordVoice,
    required this.onTrack,
  });

  final ClientHomeState state;
  final ClientHomeTab selectedTab;
  final ValueChanged<ClientHomeTab> onTabSelected;
  final VoidCallback? onCreateRequest;
  final VoidCallback? onRecordVoice;
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
        onAddPressed: onCreateRequest,
      ),
      _ClientHomeVoiceRequestCta(onRecordVoice: onRecordVoice),
      const _ClientHomeSearchBar(),
      const SizedBox(height: Spacing.large),
      _ClientHomeTabBar(selectedTab: selectedTab, onSelected: onTabSelected),
      const SizedBox(height: Spacing.large),
      _ReadyContent(
        selectedTab: selectedTab,
        onTrack: onTrack,
      ),
    ];
  }
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    required this.selectedTab,
    required this.onTrack,
  });

  final ClientHomeTab selectedTab;
  final void Function(ClientHomeRequest)? onTrack;

  @override
  Widget build(BuildContext context) {
    switch (selectedTab) {
      case ClientHomeTab.inProgress:
        return InProgressTab(
          onTrack: onTrack,
        );
      case ClientHomeTab.pendingRequests:
        // JM-023 AC2: a pending request row routes to `waiting-no-coverage`
        // (the live broadcast/wait state, JM-026) — NOT the chat thread. We
        // pass an explicit waiting handler so the pending tap target diverges
        // from the Replies/In-Progress chat/track callbacks; the rows carry
        // the indexed `orders_home_request_row_<n>` identifier inside the tab.
        return PendingRequestsTab(
          onTap: (request) => _openWaiting(context, request),
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
    GoRouter.of(context).pushNamed(
      'waiting-no-coverage',
      pathParameters: {'id': request.id},
    );
  }
}

/// Pill-shaped read-only search placeholder backed by [OmdsSearchBar].
///
/// The home tab uses the search bar as a navigation affordance, not as a
/// live filter — tapping is suppressed by [IgnorePointer] until the search
/// destination ships in a future wave.
class _ClientHomeSearchBar extends StatelessWidget {
  const _ClientHomeSearchBar();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
      child: Semantics(
        identifier: 'orders_search_bar',
        textField: true,
        label: l10n.homeSearchHint,
        child: IgnorePointer(
          child: OmdsSearchBar(
            key: const Key('client-home-search-bar'),
            hintText: l10n.homeSearchHint,
            fillColor: colorScheme.surfaceContainerHigh,
            borderRadius: UIConstants.borderRadiusPill,
            height: Sizes.fiveXLarge,
          ),
        ),
      ),
    );
  }
}

class _ClientHomeTabBar extends StatelessWidget {
  const _ClientHomeTabBar({
    required this.selectedTab,
    required this.onSelected,
  });

  final ClientHomeTab selectedTab;
  final ValueChanged<ClientHomeTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = <_TabSpec>[
      _TabSpec(ClientHomeTab.inProgress, l10n.homeTabInProgress),
      _TabSpec(ClientHomeTab.pendingRequests, l10n.homeTabPendingRequests),
      _TabSpec(ClientHomeTab.replies, l10n.homeTabReplies),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: Spacing.xSmall),
            _ClientHomeTabChip(
              label: tabs[i].label,
              isSelected: tabs[i].tab == selectedTab,
              onTap: () => onSelected(tabs[i].tab),
              keySuffix: tabs[i].tab.name,
              // JM-023 / JM-027: the Replies sub-tab carries the coined
              // `orders_home_replies_tab` identifier so QA can target it from
              // the Requests home as the tap target onto the Replies surface.
              extraIdentifier: tabs[i].tab == ClientHomeTab.replies
                  ? 'orders_home_replies_tab'
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.tab, this.label);

  final ClientHomeTab tab;
  final String label;
}

class _ClientHomeTabChip extends StatelessWidget {
  const _ClientHomeTabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.keySuffix,
    this.extraIdentifier,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String keySuffix;

  /// An additional QA identifier wrapped around the chip (e.g. the coined
  /// `orders_home_replies_tab`). Kept distinct from the existing
  /// `orders_filter_<tab>` id so both id contracts stay targetable.
  final String? extraIdentifier;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget chip = Semantics(
      identifier: 'orders_filter_$keySuffix',
      button: true,
      selected: isSelected,
      label: label,
      child: OmdsChip(
        key: Key('client-home-tab-$keySuffix'),
        label: label,
        isSelected: isSelected,
        onTap: onTap,
        selectedColor: colorScheme.primary,
        unselectedColor: Colors.transparent,
        selectedTextColor: colorScheme.onPrimary,
        unselectedTextColor: colorScheme.onSurfaceVariant,
        borderColor: isSelected ? colorScheme.primary : colorScheme.outline,
        borderRadius: OmdsBorderRadius.xSmall,
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

