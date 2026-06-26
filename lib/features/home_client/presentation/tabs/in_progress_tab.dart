import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/client_home_cubit.dart';
import '../../application/client_home_state.dart';
import '../../domain/client_home_request.dart';
import '../widgets/active_request_card.dart';

/// T-MOB-006: Isolated In Progress tab widget.
///
/// Renders the list of active deliveries. Each row uses [ActiveOrderCard]
/// with a status pill, ETA, and Track CTA wired to `/delivery/<id>/track`.
/// Pulls from the cubit's [ClientHomeState.inProgress] list; the cubit owns
/// loading and pull-to-refresh (hoisted to [ClientHomeScreen]).
///
/// Mock endpoint: GET /v1/delivery/active  (Mockoon :3055, useMockPrefixes=false)
class InProgressTab extends StatelessWidget {
  const InProgressTab({super.key, this.onTrack, this.onOpenChat});

  /// Called when the Track CTA is tapped. If null the tab navigates to the
  /// tracking route directly via GoRouter; pass a callback in tests to avoid
  /// the router dependency.
  final void Function(ClientHomeRequest request)? onTrack;

  /// iter6 close-tail: called when the "Open chat" CTA is tapped — opens the
  /// order conversation for the accepted/in-progress request so the client can
  /// re-reach the SAME chat (resolved server-side from the request id via the
  /// create-or-get). If null the tab navigates to `chat-detail` directly via
  /// GoRouter; pass a callback in tests to avoid the router dependency.
  final void Function(ClientHomeRequest request)? onOpenChat;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientHomeCubit, ClientHomeState>(
      buildWhen: _rebuildWhen,
      builder: (context, state) => _InProgressContent(
        state: state,
        onTrack: onTrack ?? (r) => _navigateToTracking(context, r),
        onOpenChat: onOpenChat ?? (r) => _navigateToChat(context, r),
      ),
    );
  }

  static bool _rebuildWhen(ClientHomeState prev, ClientHomeState next) =>
      prev.status != next.status || prev.inProgress != next.inProgress;

  static void _navigateToTracking(
    BuildContext context,
    ClientHomeRequest request,
  ) {
    // S9 live-tracking fix: open tracking with the SERVER delivery id
    // (`delivery-<offerId>`), not the request id — `GET /v1/delivery/<id>`
    // 404s on a request id. The router reads `?deliveryId=` in preference to
    // the path `:id` (app_router live-tracking route). When the gateway list
    // item carries no distinct delivery id, [ClientHomeRequest.trackingId]
    // falls back to `id` and we omit the query param.
    GoRouter.of(context).pushNamed(
      'live-tracking',
      pathParameters: {'id': request.trackingId},
      queryParameters: {
        if (request.deliveryId != null && request.deliveryId!.isNotEmpty)
          'deliveryId': request.deliveryId!,
      },
    );
  }

  static void _navigateToChat(
    BuildContext context,
    ClientHomeRequest request,
  ) {
    if (request.id.isEmpty) return;
    // `chat-detail` (/chat/:id) resolves the request id → the server-minted
    // conversation via create-or-get (#69), landing the client back in the SAME
    // accepted-order conversation.
    GoRouter.of(context).pushNamed(
      'chat-detail',
      pathParameters: {'id': request.id},
    );
  }
}

class _InProgressContent extends StatelessWidget {
  const _InProgressContent({
    required this.state,
    required this.onTrack,
    required this.onOpenChat,
  });

  final ClientHomeState state;
  final void Function(ClientHomeRequest) onTrack;
  final void Function(ClientHomeRequest) onOpenChat;

  @override
  Widget build(BuildContext context) {
    if (state.status == ClientHomeStatus.failed) {
      return _InProgressError(
        onRetry: () => context.read<ClientHomeCubit>().load(),
      );
    }
    if (state.status == ClientHomeStatus.loading) {
      return const _InProgressLoading();
    }
    if (state.inProgress.isEmpty) {
      return _InProgressEmpty(
        onCreateRequest: () => _openCreateRequest(context),
      );
    }
    return _InProgressList(
      requests: state.inProgress,
      onTrack: onTrack,
      onOpenChat: onOpenChat,
    );
  }

  static void _openCreateRequest(BuildContext context) {
    GoRouter.of(context).pushNamed('request-type');
  }
}

class _InProgressLoading extends StatelessWidget {
  const _InProgressLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('in-progress-loading'),
      child: OmdsLoadingState(),
    );
  }
}

class _InProgressError extends StatelessWidget {
  const _InProgressError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsErrorState(
      key: const Key('in-progress-error'),
      icon: Icons.cloud_off_outlined,
      title: l10n.homeLoadFailedTitle,
      message: l10n.homeErrorRetry,
      retryLabel: l10n.homeLoadFailedRetry,
      onRetry: onRetry,
    );
  }
}

class _InProgressEmpty extends StatelessWidget {
  const _InProgressEmpty({required this.onCreateRequest});

  final VoidCallback onCreateRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsEmptyState(
      key: const Key('in-progress-empty'),
      icon: Icons.local_shipping_outlined,
      title: l10n.homeEmptyTitle,
      subtitle: l10n.homeInProgressEmpty,
      buttonText: l10n.homeEmptyCta,
      onButtonTap: onCreateRequest,
    );
  }
}

class _InProgressList extends StatelessWidget {
  const _InProgressList({
    required this.requests,
    required this.onTrack,
    required this.onOpenChat,
  });

  final List<ClientHomeRequest> requests;
  final void Function(ClientHomeRequest) onTrack;
  final void Function(ClientHomeRequest) onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('in-progress-list'),
      children: [
        for (final r in requests)
          Semantics(
            label: _a11yLabel(context, r),
            child: ActiveOrderCard(
              request: r,
              onTap: () => onTrack(r),
              onOpenChat: () => onOpenChat(r),
            ),
          ),
      ],
    );
  }

  String _a11yLabel(BuildContext context, ClientHomeRequest r) {
    final l10n = AppLocalizations.of(context);
    final status = _statusLabel(context, r.status);
    final eta = r.etaMinutes != null
        ? l10n.homeRequestEtaMinutes(r.etaMinutes!)
        : l10n.homeRequestEtaUnknown;
    return l10n.inProgressTabA11yLabel(r.title, status, eta);
  }

  static String _statusLabel(BuildContext context, ClientRequestStatus s) {
    final l10n = AppLocalizations.of(context);
    switch (s) {
      case ClientRequestStatus.searching:
        return l10n.requestStatusSearching;
      case ClientRequestStatus.offersReceived:
        return l10n.homeTabReplies;
      case ClientRequestStatus.accepted:
        return l10n.homeStageOrdered;
      case ClientRequestStatus.atPickup:
        return l10n.homeStagePicked;
      case ClientRequestStatus.enRoute:
        return l10n.homeStageInTransit;
    }
  }
}
