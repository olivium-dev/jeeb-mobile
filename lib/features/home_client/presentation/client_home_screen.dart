import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

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

  final void Function(ClientHomeRequest request)? onOpenRequest;
  final VoidCallback? onCreateRequest;

  /// Opens the live-tracking screen (`/orders/:id/tracking`) for an in-progress
  /// delivery's "Track my order" CTA. Distinct from [onOpenRequest], which
  /// opens the conversation for pending/replies cards. When null the
  /// [InProgressTab] falls back to GoRouter navigation directly.
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
            onRecordVoice: widget.onRecordVoice,
            onTrack: widget.onTrack,
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
    required this.onRecordVoice,
    required this.onTrack,
  });

  final ClientHomeState state;
  final ClientHomeTab selectedTab;
  final ValueChanged<ClientHomeTab> onTabSelected;
  final VoidCallback? onCreateRequest;
  final void Function(ClientHomeRequest)? onOpenRequest;
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
          onOpenRequest: onOpenRequest,
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
    required this.onOpenRequest,
    required this.onRecordVoice,
    required this.onTrack,
  });

  final ClientHomeState state;
  final ClientHomeTab selectedTab;
  final ValueChanged<ClientHomeTab> onTabSelected;
  final VoidCallback? onCreateRequest;
  final void Function(ClientHomeRequest)? onOpenRequest;
  final VoidCallback? onRecordVoice;
  final void Function(ClientHomeRequest)? onTrack;

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
      _ClientHomeVoiceRequestCta(onRecordVoice: onRecordVoice),
      const _ClientHomeSearchBar(),
      const SizedBox(height: Spacing.large),
      _ClientHomeTabBar(selectedTab: selectedTab, onSelected: onTabSelected),
      const SizedBox(height: Spacing.large),
      _ReadyContent(
        selectedTab: selectedTab,
        onOpenRequest: onOpenRequest,
        onTrack: onTrack,
      ),
    ];
  }
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    required this.selectedTab,
    required this.onOpenRequest,
    required this.onTrack,
  });

  final ClientHomeTab selectedTab;
  final void Function(ClientHomeRequest)? onOpenRequest;
  final void Function(ClientHomeRequest)? onTrack;

  @override
  Widget build(BuildContext context) {
    switch (selectedTab) {
      case ClientHomeTab.inProgress:
        return InProgressTab(
          onTrack: onTrack,
        );
      case ClientHomeTab.pendingRequests:
        return PendingRequestsTab(
          onTap: onOpenRequest,
        );
      case ClientHomeTab.replies:
        return RepliesTab(
          onCheckOffers: onOpenRequest,
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
    return Semantics(
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
  }
}

