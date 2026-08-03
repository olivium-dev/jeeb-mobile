import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/client_home_cubit.dart';
import '../../application/client_home_state.dart';
import '../../domain/client_home_request.dart';
import '../widgets/active_request_card.dart';
import '../widgets/client_home_motion.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';
import '../../../../core/previews/jeeb_preview.dart';
import '../../domain/client_home_repository.dart';

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
      child: Padding(
        padding: EdgeInsets.all(Spacing.large),
        child: ClientHomeLoadingDots(),
      ),
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width, matching the `ListView` the tab is a child of in production.
const double _inProgressTabPhoneWidth = 390;

/// One order card is ~150 pt tall; these boxes leave room for the EN 200%-text
/// rendering of the matrix to grow into before the scroll view takes over.
const Size _inProgressTabOneCardBox = Size(_inProgressTabPhoneWidth, 340);
const Size _inProgressTabTwoCardBox = Size(_inProgressTabPhoneWidth, 620);
const Size _inProgressTabPlaceholderBox = Size(_inProgressTabPhoneWidth, 360);

/// Canned snapshot, resolved on the next microtask like a real (fast) load.
class _InProgressTabSeededHomeRepository implements ClientHomeRepository {
  const _InProgressTabSeededHomeRepository(this.inProgress);

  final List<ClientHomeRequest> inProgress;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      ClientHomeSnapshot(inProgress: inProgress);
}

/// A cold load that never returns — the cubit stays in
/// [ClientHomeStatus.loading] forever, which is the only way to hold the
/// loading sub-state still long enough to look at it.
class _InProgressTabNeverResolvingHomeRepository
    implements ClientHomeRepository {
  const _InProgressTabNeverResolvingHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() =>
      Completer<ClientHomeSnapshot>().future;
}

/// A cold load that throws. The cubit only emits [ClientHomeStatus.failed] when
/// nothing is cached yet, so this fake must fail on the FIRST call — a fake that
/// succeeded once and then threw would render the list, not the error.
class _InProgressTabFailingHomeRepository implements ClientHomeRepository {
  const _InProgressTabFailingHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      throw StateError('preview fixture: cold home load failed');
}

/// The tab as `client_home_screen.dart` mounts it: an ambient [ClientHomeCubit]
/// above it and unbounded height below it (the canvas box supplies the width —
Widget _inProgressTabHosted(ClientHomeRepository repository) =>
    BlocProvider<ClientHomeCubit>(
      create: (_) => ClientHomeCubit(
        repository: repository,
        greetingNameProvider: () => null,
      )..load(),
      child: SingleChildScrollView(
        child: InProgressTab(
          onTrack: (ClientHomeRequest _) {},
          onOpenChat: (ClientHomeRequest _) {},
        ),
      ),
    );

/// One in-progress row, shaped like `_activeRequest` in
/// `test/features/home_client/in_progress_tab_test.dart`.
ClientHomeRequest _inProgressTabRow({
  required String id,
  required String title,
  ClientRequestStatus status = ClientRequestStatus.enRoute,
  int progressStep = 2,
  ClientRequestTier tier = ClientRequestTier.flash,
  String destinationLabel = 'Ashrafieh, Beirut',
  String? itemsSummary,
  int? etaMinutes,
}) =>
    ClientHomeRequest(
      id: id,
      title: title,
      status: status,
      destinationLabel: destinationLabel,
      itemsSummary: itemsSummary,
      etaMinutes: etaMinutes,
      progressStep: progressStep,
      tier: tier,
    );

/// The happy path: two live deliveries at different points of the same journey.
/// Two rows rather than one because the card is a `Column` of stacked `Row`s
@JeebPreview(
  group: 'home_client',
  name: 'Two active rows',
  size: _inProgressTabTwoCardBox,
)
Widget inProgressTabTwoRows() => _inProgressTabHosted(
      _InProgressTabSeededHomeRepository(<ClientHomeRequest>[
        _inProgressTabRow(
          id: 'ip-1',
          title: 'Pharmacy run',
          etaMinutes: 12,
        ),
        _inProgressTabRow(
          id: 'ip-2',
          title: 'Grocery run',
          status: ClientRequestStatus.accepted,
          progressStep: 0,
          tier: ClientRequestTier.express,
        ),
      ]),
    );

/// AC2: nothing in flight.
/// The `OmdsEmptyState` here is the tab's *whole* surface — icon, title,
@JeebPreview(
  group: 'home_client',
  name: 'Empty · no active deliveries',
  size: _inProgressTabPlaceholderBox,
)
Widget inProgressTabEmpty() => _inProgressTabHosted(
      const _InProgressTabSeededHomeRepository(<ClientHomeRequest>[]),
    );

/// AC6: the cold load failed.
/// Worth its own preview because the tab's error copy is NOT the screen's:
@JeebPreview(
  group: 'home_client',
  name: 'Failed · cold load',
  size: _inProgressTabPlaceholderBox,
)
Widget inProgressTabFailed() =>
    _inProgressTabHosted(const _InProgressTabFailingHomeRepository());

/// The load is still in flight — an indeterminate spinner, centred.
/// Held open by a future that never completes, so it is the one preview that
@JeebPreview(
  group: 'home_client',
  name: 'Loading · spinner',
  size: Size(_inProgressTabPhoneWidth, 200),
)
Widget inProgressTabLoading() =>
    _inProgressTabHosted(const _InProgressTabNeverResolvingHomeRepository());

/// JEBV4-218 / Q-085 (ratified): a still-`searching` row — no Jeeber engaged —
/// STILL shows "Track my order", and must NOT show "Open chat".
@JeebPreview(
  group: 'home_client',
  name: 'Searching · track without chat',
  size: _inProgressTabOneCardBox,
)
Widget inProgressTabSearching() => _inProgressTabHosted(
      _InProgressTabSeededHomeRepository(<ClientHomeRequest>[
        _inProgressTabRow(
          id: 'ip-searching',
          title: 'Birthday cake, Hamra',
          status: ClientRequestStatus.searching,
          progressStep: 0,
          tier: ClientRequestTier.standard,
        ),
      ]),
    );

/// The layout ceiling: the longest plausible title and subtitle a real request
/// produces, on a row that shows BOTH action pills.
@JeebPreview(
  group: 'home_client',
  name: 'Long title + both CTAs',
  size: _inProgressTabOneCardBox,
)
Widget inProgressTabLongContent() => _inProgressTabHosted(
      _InProgressTabSeededHomeRepository(<ClientHomeRequest>[
        _inProgressTabRow(
          id: 'ip-long',
          title: 'Prescription refill from Pharmacie Al-Muhandis Ashrafieh',
          itemsSummary:
              '2 boxes paracetamol, 1 kilo potato, water gallon, coffee blend',
          etaMinutes: 47,
        ),
      ]),
    );
