import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/layout/bottom_inset.dart';
import '../../../l10n/app_localizations.dart';
import '../../shell/tab_visibility.dart';
import '../application/client_home_cubit.dart';
import '../application/client_home_state.dart';
import '../domain/client_home_request.dart';
import 'tabs/in_progress_tab.dart';
import 'tabs/pending_requests_tab.dart';
import 'tabs/replies_tab.dart';
import 'widgets/client_home_greeting.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/client_home_screen_fixtures.dart';
import '../domain/client_home_repository.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({
    super.key,
    this.onOpenRequest,
    this.onCreateRequest,
    this.onTrack,
    this.initialTab = ClientHomeTab.pendingRequests,
  });

  final void Function(ClientHomeRequest request)? onOpenRequest;
  final VoidCallback? onCreateRequest;

  final void Function(ClientHomeRequest request)? onTrack;

  final ClientHomeTab initialTab;

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen>
    with WidgetsBindingObserver {
  late ClientHomeTab _selectedTab = widget.initialTab;

  bool _appResumed = true;

  bool _tabResolved = false;

  bool? _wasVisible;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _appResumed) return;
    _appResumed = resumed;
    if (!resumed) return;
    final cubit = _homeCubit;
    final isVisible = TabVisibility.maybeOf(context)?.isVisible ?? true;
    if (cubit == null || !isVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cubit.refresh();
    });
  }

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

  void _resolveInitialTab(ClientHomeState state) {
    if (_tabResolved) return;
    if (state.status != ClientHomeStatus.ready) return;
    _tabResolved = true;
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
      padding: EdgeInsets.only(bottom: context.scrollBodyBottomInset),
      children: [
        ClientHomeGreeting(name: null, onAddPressed: onCreateRequest),
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
      padding: EdgeInsets.only(bottom: context.scrollBodyBottomInset),
      children: [
        ClientHomeGreeting(name: name, onAddPressed: onCreateRequest),
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
        avatarSemanticsIdentifier:
            selectedTab == ClientHomeTab.pendingRequests &&
                state.pending.isEmpty
            ? '_request_empty_state_avatar'
            : null,
      ),
      const SizedBox(height: Spacing.large),
      _ClientHomeTabBar(selectedTab: selectedTab, onSelected: onTabSelected),
      const SizedBox(height: Spacing.large),
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
        return PendingRequestsTab(
          onTap: (request) => _openWaiting(context, request),
          onCreateRequest: onCreateRequest,
        );
      case ClientHomeTab.replies:
        return const RepliesTab();
    }
  }

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
  });

  final ClientHomeTab selectedTab;
  final ValueChanged<ClientHomeTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = <_TabSpec>[
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
        unselectedColor: colorScheme.surface.withValues(
          alpha: UIConstants.elevationNone,
        ),
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The phone the client home is designed against (Figma 56535:1525).
const double _clientHomeScreenPhoneWidth = 390;

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const double _clientHomeScreenCompactWidth = 320;

const Size _clientHomeScreenPhoneBox = Size(_clientHomeScreenPhoneWidth, 844);
const Size _clientHomeScreenCompactBox = Size(
  _clientHomeScreenCompactWidth,
  568,
);

/// Mounts the real screen the way its shell host does: a [ClientHomeCubit] over
/// a local fake repository, with both navigation callbacks wired.
Widget _clientHomeScreenHosted(
  ClientHomeRepository repository, {
  ClientHomeTab initialTab = ClientHomeTab.pendingRequests,
  String? name = ClientHomeScreenPreviewFixtures.greetingName,
}) {
  return BlocProvider<ClientHomeCubit>(
    create: (_) => ClientHomeScreenPreviewFixtures.cubit(repository, name: name),
    child: ClientHomeScreen(
      initialTab: initialTab,
      onCreateRequest: () {},
      onTrack: (_) {},
    ),
  );
}

/// The default landing surface: Pending Requests with three broadcast rows.
/// The reference reading, and the one the matrix is for. Everything that makes
@JeebPreview(
  group: 'home_client',
  name: 'Pending · three requests',
  size: _clientHomeScreenPhoneBox,
  matrix: true,
)
Widget clientHomeScreenPending() =>
    _clientHomeScreenHosted(ClientHomeScreenPreviewFixtures.populated());

/// The Replies sub-tab: one request with nine offers and a `+6` overflow.
/// Note the tab bar keeps its full height above a single card, and that the
@JeebPreview(
  group: 'home_client',
  name: 'Replies · nine offers',
  size: _clientHomeScreenPhoneBox,
)
Widget clientHomeScreenReplies() => _clientHomeScreenHosted(
  ClientHomeScreenPreviewFixtures.populated(),
  initialTab: ClientHomeTab.replies,
);

/// The dev-seam-only In-Progress body, pinned explicitly.
/// JEBV4-298 moved the In-Progress chip to the Delivery tab but left
@JeebPreview(
  group: 'home_client',
  name: 'In Progress (dev seam)',
  size: _clientHomeScreenPhoneBox,
)
Widget clientHomeScreenInProgress() => _clientHomeScreenHosted(
  ClientHomeScreenPreviewFixtures.populated(),
  initialTab: ClientHomeTab.inProgress,
);

/// A fresh account: the load succeeded and there is nothing to show.
/// The illustrated empty state sits BELOW the greeting and the chip row, so it
@JeebPreview(
  group: 'home_client',
  name: 'Empty · first run',
  size: _clientHomeScreenPhoneBox,
)
Widget clientHomeScreenEmpty() =>
    _clientHomeScreenHosted(ClientHomeScreenPreviewFixtures.empty());

/// The same empty state with 70 pt less width and 276 pt less height.
/// Worth its own card because the empty view's illustration is a FIXED 200 pt
@JeebPreview(
  group: 'home_client',
  name: 'Empty · 320 pt floor',
  size: _clientHomeScreenCompactBox,
)
Widget clientHomeScreenEmptyCompact() => _clientHomeScreenHosted(
  ClientHomeScreenPreviewFixtures.empty(),
  name: 'Yasmine',
);

/// Cold load failed: the whole body is replaced by an error block and a Retry.
/// Only a COLD failure reaches here — `ClientHomeCubit._fetch` keeps the
@JeebPreview(
  group: 'home_client',
  name: 'Failed · cold load',
  size: _clientHomeScreenPhoneBox,
)
Widget clientHomeScreenFailed() =>
    _clientHomeScreenHosted(ClientHomeScreenPreviewFixtures.failing());

/// The cold read is in flight: greeting, then a centred spinner.
/// The chip row is absent here too, and the spinner carries no text in either
@JeebPreview(
  group: 'home_client',
  name: 'Loading · cold',
  size: _clientHomeScreenPhoneBox,
)
Widget clientHomeScreenLoading() =>
    _clientHomeScreenHosted(ClientHomeScreenPreviewFixtures.stalled());

/// Layout ceiling: the longest content this screen can actually carry.
/// A long account name in the greeting (which greets the FIRST name only, then
@JeebPreview(
  group: 'home_client',
  name: 'Longest content',
  size: _clientHomeScreenPhoneBox,
  matrix: true,
)
Widget clientHomeScreenLongContent() => _clientHomeScreenHosted(
  ClientHomeScreenPreviewFixtures.longContent(),
  name: ClientHomeScreenPreviewFixtures.longGreetingName,
);

/// Pending empty, Replies populated — the one-shot "land where the content is"
/// affordance (`_resolveInitialTab`, JM-023 AC2 / JEBV4-298).
@JeebPreview(
  group: 'home_client',
  name: 'Auto-advanced to Replies',
  size: _clientHomeScreenPhoneBox,
)
Widget clientHomeScreenAutoAdvancedToReplies() =>
    _clientHomeScreenHosted(ClientHomeScreenPreviewFixtures.repliesOnly());
