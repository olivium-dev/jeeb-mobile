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

  /// Called when the "Open chat" CTA is tapped. If null the tab navigates to
  /// the order-chat route directly via GoRouter; pass a callback in tests to
  /// avoid the router dependency.
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

  /// S9 P0 (restored on feat/request-scenarios — the cycle-1 merge dropped the
  /// query-param threading while keeping its test): tracking must poll by the
  /// SERVER delivery id. The card's row id may be the REQUEST id, which 404s
  /// on `GET /v1/deliveries/<id>`; when the row carries a delivery id it rides
  /// along as `?deliveryId=` and the route resolver prefers it (mirrors
  /// [_navigateToChat]).
  static void _navigateToTracking(
    BuildContext context,
    ClientHomeRequest request,
  ) {
    // S9 live-tracking fix (mirrors home_tab.dart): navigate with the SERVER
    // delivery id (`delivery-<offerId>`) so `GET /v1/delivery/<id>` resolves
    // instead of 404'ing on a request id. The router prefers `?deliveryId=`
    // over `:id` (resolveTrackingDeliveryId); we still set the path id
    // (delivery id when known, else request id as a best-effort fallback via
    // [ClientHomeRequest.trackingId]).
    GoRouter.of(context).pushNamed(
      'live-tracking',
      pathParameters: {'id': request.trackingId},
      queryParameters: {
        if (request.deliveryId != null && request.deliveryId!.isNotEmpty)
          'deliveryId': request.deliveryId!,
      },
    );
  }

  /// Opens the accepted order's EXISTING conversation. Routes by the parent
  /// REQUEST/correlation id ([ClientHomeRequest.chatThreadId]) — NEVER a
  /// (possibly phantom) conversationId or a delivery row id — mirroring the
  /// accept-sheet CHAT-CONTRACT: `ChatDetailScreen` resolves the thread via
  /// `GET /v1/conversations?correlationKey={requestId}`, so passing a
  /// conversationId guarantees a 404 on that first lookup (BUG-17 chat-load
  /// 404 storm). The delivery id rides along as `?deliveryId=` so the in-chat
  /// "Track order" CTA still resolves.
  static void _navigateToChat(
    BuildContext context,
    ClientHomeRequest request,
  ) {
    final deliveryId = request.trackingId;
    GoRouter.of(context).pushNamed(
      'chat-detail',
      pathParameters: {'id': request.chatThreadId},
      queryParameters: {
        if (deliveryId.isNotEmpty) 'deliveryId': deliveryId,
      },
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
              // Post-accept conversation re-entry (JM-025). Routes by the
              // parent request/correlation id (chatThreadId), NEVER the
              // conversationId — see [InProgressTab._navigateToChat] (BUG-17).
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
      case ClientRequestStatus.delivered:
        return l10n.deliveryStageDelivered;
      case ClientRequestStatus.cancelled:
        // Terminal; filtered out of In Progress upstream, so this is a
        // defensive label only (keeps the switch exhaustive).
        return l10n.deliveryStageCancelled;
    }
  }
}
