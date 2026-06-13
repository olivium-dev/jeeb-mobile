import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/client_home_cubit.dart';
import '../../application/client_home_state.dart';
import '../../domain/client_home_request.dart';
import '../widgets/replies_card.dart';

/// T-MOB-008: Isolated Replies tab widget.
///
/// Renders requests where ≥1 Jeeber has replied with an offer. Each row
/// shows the stacked offerer avatars (max 3 + overflow count), an offer
/// badge, and a "Check Offers" CTA wired to `/chat/<conversationId>`.
/// Avatar images are rendered by [OmdsProfileAvatar] with network URLs to
/// benefit from the OS image cache (AC6 of T-MOB-008 — cached_network_image).
///
/// WS push integration: real-time offer increments are handled by the
/// cubit (future work T-BE-016/T-BE-017); this tab rebuilds when the cubit
/// emits a new replies list.
///
/// Mock endpoint: GET /v1/requests?status=offers-received  (Mockoon :3055)
class RepliesTab extends StatelessWidget {
  const RepliesTab({super.key, this.onCheckOffers});

  /// Called when "Check Offers" is tapped. If null the tab navigates to the
  /// chat route directly via GoRouter; pass a callback in tests.
  final void Function(ClientHomeRequest request)? onCheckOffers;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientHomeCubit, ClientHomeState>(
      buildWhen: _rebuildWhen,
      builder: (context, state) => _RepliesContent(
        state: state,
        onCheckOffers: onCheckOffers ??
            (r) => _navigateToChat(context, r),
      ),
    );
  }

  static bool _rebuildWhen(ClientHomeState prev, ClientHomeState next) =>
      prev.status != next.status || prev.replies != next.replies;

  static void _navigateToChat(
    BuildContext context,
    ClientHomeRequest request,
  ) {
    final target = request.conversationId ?? request.id;
    if (target.isEmpty) return;
    GoRouter.of(context).pushNamed(
      'chat-detail',
      pathParameters: {'id': target},
    );
  }
}

class _RepliesContent extends StatelessWidget {
  const _RepliesContent({required this.state, required this.onCheckOffers});

  final ClientHomeState state;
  final void Function(ClientHomeRequest) onCheckOffers;

  @override
  Widget build(BuildContext context) {
    if (state.status == ClientHomeStatus.failed) {
      return _RepliesError(
        onRetry: () => context.read<ClientHomeCubit>().load(),
      );
    }
    if (state.status == ClientHomeStatus.loading) {
      return const _RepliesLoading();
    }
    if (state.replies.isEmpty) {
      return const _RepliesEmpty();
    }
    return _RepliesList(requests: state.replies, onCheckOffers: onCheckOffers);
  }
}

class _RepliesLoading extends StatelessWidget {
  const _RepliesLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('replies-loading'),
      child: OmdsLoadingState(),
    );
  }
}

class _RepliesError extends StatelessWidget {
  const _RepliesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsErrorState(
      key: const Key('replies-error'),
      icon: Icons.cloud_off_outlined,
      title: l10n.homeLoadFailedTitle,
      message: l10n.homeErrorRetry,
      retryLabel: l10n.homeLoadFailedRetry,
      onRetry: onRetry,
    );
  }
}

class _RepliesEmpty extends StatelessWidget {
  const _RepliesEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsEmptyState(
      key: const Key('replies-empty'),
      icon: Icons.mark_chat_unread_outlined,
      title: l10n.homeEmptyTitle,
      subtitle: l10n.homeRepliesEmpty,
    );
  }
}

class _RepliesList extends StatelessWidget {
  const _RepliesList({required this.requests, required this.onCheckOffers});

  final List<ClientHomeRequest> requests;
  final void Function(ClientHomeRequest) onCheckOffers;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('replies-tab-list'),
      children: [
        for (final r in requests)
          Semantics(
            label: _a11yLabel(context, r),
            child: RepliesCard(
              request: r,
              onCheckOffers: () => onCheckOffers(r),
            ),
          ),
      ],
    );
  }

  String _a11yLabel(BuildContext context, ClientHomeRequest r) {
    final l10n = AppLocalizations.of(context);
    return l10n.repliesTabA11yLabel(r.offerCount);
  }
}
