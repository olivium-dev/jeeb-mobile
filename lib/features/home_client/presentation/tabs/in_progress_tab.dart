import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/client_home_cubit.dart';
import '../../application/client_home_state.dart';
import '../../domain/client_home_request.dart';
import '../widgets/active_request_card.dart';

class InProgressTab extends StatelessWidget {
  const InProgressTab({super.key, this.onTrack, this.onOpenChat});

  final void Function(ClientHomeRequest request)? onTrack;

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
        return l10n.deliveryStageCancelled;
    }
  }
}
