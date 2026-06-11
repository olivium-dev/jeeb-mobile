import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/client_home_cubit.dart';
import '../application/client_home_state.dart';
import '../domain/client_home_request.dart';
import 'widgets/active_request_card.dart';
import 'widgets/client_home_empty_view.dart';
import 'widgets/client_home_greeting.dart';
import 'widgets/replies_card.dart';

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
  const ClientHomeScreen({super.key, this.onOpenRequest, this.onCreateRequest});

  final void Function(ClientHomeRequest request)? onOpenRequest;
  final VoidCallback? onCreateRequest;

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  ClientHomeTab _selectedTab = ClientHomeTab.inProgress;

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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientHomeCubit, ClientHomeState>(
      builder: (context, state) {
        return OmdsPullToRefresh(
          onRefresh: () => context.read<ClientHomeCubit>().refresh(),
          child: _ClientHomeBody(
            state: state,
            selectedTab: _selectedTab,
            onTabSelected: (tab) => setState(() => _selectedTab = tab),
            onCreateRequest: widget.onCreateRequest,
            onOpenRequest: widget.onOpenRequest,
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
    required this.onOpenRequest,
  });

  final ClientHomeState state;
  final ClientHomeTab selectedTab;
  final ValueChanged<ClientHomeTab> onTabSelected;
  final VoidCallback? onCreateRequest;
  final void Function(ClientHomeRequest)? onOpenRequest;

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
          onOpenRequest: onOpenRequest,
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
  const _LoadingLayout({required this.onCreateRequest});

  final VoidCallback? onCreateRequest;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ClientHomeGreeting(name: null, onAddPressed: onCreateRequest),
        const _ClientHomeSearchBar(),
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
      children: [
        ClientHomeGreeting(name: name, onAddPressed: onCreateRequest),
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
    required this.onOpenRequest,
  });

  final ClientHomeState state;
  final ClientHomeTab selectedTab;
  final ValueChanged<ClientHomeTab> onTabSelected;
  final VoidCallback? onCreateRequest;
  final void Function(ClientHomeRequest)? onOpenRequest;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: Spacing.twoXLarge),
      children: _scrollChildren(),
    );
  }

  List<Widget> _scrollChildren() {
    return <Widget>[
      ClientHomeGreeting(
        name: state.greetingName,
        onAddPressed: onCreateRequest,
      ),
      const _ClientHomeSearchBar(),
      const SizedBox(height: Spacing.large),
      _ClientHomeTabBar(selectedTab: selectedTab, onSelected: onTabSelected),
      const SizedBox(height: Spacing.large),
      _ReadyContent(
        state: state,
        selectedTab: selectedTab,
        onCreateRequest: onCreateRequest,
        onOpenRequest: onOpenRequest,
      ),
    ];
  }
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    required this.state,
    required this.selectedTab,
    required this.onCreateRequest,
    required this.onOpenRequest,
  });

  final ClientHomeState state;
  final ClientHomeTab selectedTab;
  final VoidCallback? onCreateRequest;
  final void Function(ClientHomeRequest)? onOpenRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = state.listFor(selectedTab);
    if (items.isEmpty) {
      return _TabEmptyState(
        selectedTab: selectedTab,
        l10n: l10n,
        onCreateRequest: onCreateRequest,
      );
    }
    switch (selectedTab) {
      case ClientHomeTab.inProgress:
      case ClientHomeTab.pendingRequests:
        return _ActiveRequestList(
          requests: items,
          onOpenRequest: onOpenRequest,
        );
      case ClientHomeTab.replies:
        return _RepliesList(
          requests: items,
          onOpenRequest: onOpenRequest,
        );
    }
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
      child: IgnorePointer(
        child: OmdsSearchBar(
          key: const Key('client-home-search-bar'),
          hintText: 'Search...',
          fillColor: colorScheme.surfaceContainerHigh,
          borderRadius: UIConstants.borderRadiusPill,
          height: Sizes.fiveXLarge,
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
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String keySuffix;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OmdsChip(
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
    );
  }
}

class _ActiveRequestList extends StatelessWidget {
  const _ActiveRequestList({
    required this.requests,
    required this.onOpenRequest,
  });

  final List<ClientHomeRequest> requests;
  final void Function(ClientHomeRequest)? onOpenRequest;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final r in requests)
          ActiveOrderCard(request: r, onTap: () => onOpenRequest?.call(r)),
      ],
    );
  }
}

class _RepliesList extends StatelessWidget {
  const _RepliesList({
    required this.requests,
    required this.onOpenRequest,
  });

  final List<ClientHomeRequest> requests;
  final void Function(ClientHomeRequest)? onOpenRequest;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final r in requests)
          RepliesCard(request: r, onCheckOffers: () => onOpenRequest?.call(r)),
      ],
    );
  }
}

class _TabEmptyState extends StatelessWidget {
  const _TabEmptyState({
    required this.selectedTab,
    required this.l10n,
    required this.onCreateRequest,
  });

  final ClientHomeTab selectedTab;
  final AppLocalizations l10n;
  final VoidCallback? onCreateRequest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.large),
      child: OmdsEmptyState(
        icon: _iconFor(selectedTab),
        title: l10n.homeEmptyTitle,
        subtitle: _subtitleFor(selectedTab),
        buttonText: l10n.homeEmptyCta,
        onButtonTap: onCreateRequest,
      ),
    );
  }

  IconData _iconFor(ClientHomeTab tab) {
    switch (tab) {
      case ClientHomeTab.inProgress:
        return Icons.local_shipping_outlined;
      case ClientHomeTab.pendingRequests:
        return Icons.hourglass_empty_rounded;
      case ClientHomeTab.replies:
        return Icons.mark_chat_unread_outlined;
    }
  }

  String _subtitleFor(ClientHomeTab tab) {
    switch (tab) {
      case ClientHomeTab.inProgress:
        return l10n.homeInProgressEmpty;
      case ClientHomeTab.pendingRequests:
        return l10n.homePendingEmpty;
      case ClientHomeTab.replies:
        return l10n.homeRepliesEmpty;
    }
  }
}
