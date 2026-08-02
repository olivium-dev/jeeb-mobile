import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/countdown_format.dart';
import '../../../core/lifecycle/route_resume_refetch.dart';
import '../../../core/network/single_flight_get.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../../cancel_request/presentation/cancel_request_sheet.dart';
import '../application/waiting_cubit.dart';
import '../application/waiting_state.dart';
import '../data/dio_waiting_repository.dart';
import '../data/fake_waiting_repository.dart';
import '../domain/waiting_repository.dart';
import '../domain/waiting_request.dart';

typedef WaitingCubitFactory =
    WaitingCubit Function(WaitingRepository repository, String requestId);

class NoOfferTimeoutScreen extends StatelessWidget {
  const NoOfferTimeoutScreen({
    super.key,
    required this.requestId,
    this.repository,
    this.cubitFactory,
  });

  final String requestId;

  final WaitingRepository? repository;

  final WaitingCubitFactory? cubitFactory;

  WaitingRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<WaitingRepository>()) return sl<WaitingRepository>();
    if (sl.isRegistered<Dio>()) {
      return DioWaitingRepository(
        sl<Dio>(),
        coalescer: sl.isRegistered<SingleFlightGet>()
            ? sl<SingleFlightGet>()
            : null,
      );
    }
    return FakeWaitingRepository();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _resolveRepository();
    return BlocProvider<WaitingCubit>(
      create: (_) {
        final cubit =
            cubitFactory?.call(repo, requestId) ??
            WaitingCubit(
              repository: repo,
              requestId: requestId,
              refreshSignals: resolvePushRefreshStream(
                topics: const {RefreshTopic.order, RefreshTopic.offers},
              ),
            );
        cubit.load();
        return cubit;
      },
      child: RouteResumeRefetch(
        onResume: (context) => context.read<WaitingCubit>().refreshOnResume(),
        child: _WaitingView(requestId: requestId),
      ),
    );
  }
}

class _WaitingView extends StatelessWidget {
  const _WaitingView({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<WaitingCubit, WaitingState>(
      builder: (context, state) => Scaffold(
        appBar: OMDSAppBar(
          title: state.isTerminal
              ? l10n.offersRequestClosedTitle
              : l10n.waitingTitle,
        ),
        body: SafeArea(child: _body(context, state)),
      ),
    );
  }

  Widget _body(BuildContext context, WaitingState state) {
    if (state.isLoading) return const _WaitingLoading();
    if (state.status == WaitingScreenStatus.failed) {
      return _WaitingError(
        failure: state.error,
        onRetry: () => context.read<WaitingCubit>().retry(),
      );
    }
    if (state.isTerminal) {
      return _WaitingTerminal(
        requestId: requestId,
        phase: state.request!.phase,
      );
    }
    return _WaitingLoaded(requestId: requestId, state: state);
  }
}

class _WaitingLoading extends StatelessWidget {
  const _WaitingLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(Spacing.large),
        child: OmdsShimmer(width: 220, height: 120),
      ),
    );
  }
}

class _WaitingError extends StatelessWidget {
  const _WaitingError({required this.onRetry, this.failure});

  final VoidCallback onRetry;

  final WaitingFailure? failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = failure == WaitingFailure.contractViolation
        ? l10n.waitingErrorContractBody
        : l10n.waitingErrorBody;
    return Padding(
      padding: const EdgeInsets.all(Spacing.large),
      child: Semantics(
        identifier: 'waiting_error_state',
        container: true,
        child: OmdsErrorState(message: message, onRetry: onRetry),
      ),
    );
  }
}

class _WaitingTerminal extends StatelessWidget {
  const _WaitingTerminal({required this.requestId, required this.phase});

  final String requestId;
  final WaitingRequestPhase phase;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'waiting_terminal_state',
      container: true,
      explicitChildNodes: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OmdsEmptyState(
                key: const Key('waiting-terminal-empty-state'),
                icon: _icon,
                title: _title(l10n),
                subtitle: _subtitle(l10n),
              ),
              const SizedBox(height: Spacing.large),
              Semantics(
                identifier: 'waiting_terminal_home_cta',
                container: true,
                button: true,
                child: OmdsPrimaryButton(
                  key: const Key('waiting-terminal-home-cta'),
                  text: l10n.trackingCancelledHomeCta,
                  onTap: () => context.go('/'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _icon => switch (phase) {
    WaitingRequestPhase.matched => Icons.check_circle_outline,
    WaitingRequestPhase.cancelled => Icons.cancel_outlined,
    WaitingRequestPhase.expired => Icons.timer_off_outlined,
    _ => Icons.lock_outline,
  };

  String _title(AppLocalizations l10n) => switch (phase) {
    WaitingRequestPhase.matched => l10n.deliveryStageMatched,
    WaitingRequestPhase.cancelled => l10n.deliveryStageCancelled,
    WaitingRequestPhase.expired => l10n.requestSummaryExpiredTitle,
    _ => l10n.offersRequestClosedTitle,
  };

  String? _subtitle(AppLocalizations l10n) => switch (phase) {
    WaitingRequestPhase.expired => l10n.requestSummaryExpiredBody,
    WaitingRequestPhase.cancelled ||
    WaitingRequestPhase.closed => l10n.requestNoLongerAvailable(requestId),
    _ => null,
  };
}

class _WaitingLoaded extends StatelessWidget {
  const _WaitingLoaded({required this.requestId, required this.state});

  final String requestId;
  final WaitingState state;

  void _openReviewOffers(BuildContext context) {
    context.pushNamed('offer-review', pathParameters: {'id': requestId});
  }

  void _retarget(BuildContext context) {
    context.pushNamed('request-type');
  }

  Future<void> _cancel(BuildContext context) async {
    await CancelRequestSheet.show(context, requestId: requestId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final request = state.request;
    final notifiedCount = request?.notifiedCount ?? 0;
    final showReviewOffers = state.hasOffers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Spacing.large),
          if (state.isNoOffersYet)
            const _NoOffersYetHeader()
          else
            _BroadcastHeader(
              notifiedCount: notifiedCount,
              remaining: state.remaining,
            ),
          if (request?.title != null && request!.title!.trim().isNotEmpty) ...[
            const SizedBox(height: Spacing.xLarge),
            _RequestSummaryCard(text: request.title!.trim()),
          ],
          const SizedBox(height: Spacing.twoXLarge),

          if (showReviewOffers) ...[
            Semantics(
              identifier: 'waiting_review_offers_cta',
              button: true,
              child: OmdsPrimaryButton(
                text: l10n.waitingReviewOffersCta,
                onTap: () => _openReviewOffers(context),
              ),
            ),
            const SizedBox(height: Spacing.small),
          ],

          Semantics(
            identifier: 'waiting_retarget_cta',
            button: true,
            child: OmdsPrimaryButton(
              text: l10n.waitingRetargetCta,
              variant: OmdsButtonVariant.outlined,
              onTap: () => _retarget(context),
            ),
          ),
          const SizedBox(height: Spacing.small),

          Semantics(
            identifier: 'waiting_cancel_cta',
            button: true,
            child: OmdsPrimaryButton(
              text: l10n.waitingCancelCta,
              variant: OmdsButtonVariant.text,
              textColor: theme.colorScheme.error,
              onTap: () => _cancel(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastHeader extends StatelessWidget {
  const _BroadcastHeader({
    required this.notifiedCount,
    required this.remaining,
  });

  final int notifiedCount;

  final Duration? remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          Icons.podcasts,
          size: Sizes.eightXLarge,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: Spacing.large),
        Text(
          l10n.requestSummaryFindingTitle,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.medium),
        Semantics(
          identifier: 'waiting_notified_count',
          child: Text(
            notifiedCount > 0
                ? l10n.requestSummaryFindingNotifiedCount(notifiedCount)
                : l10n.waitingReachingOutLabel,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: Spacing.small),
        Semantics(
          identifier: 'waiting_countdown',
          child: Text(
            remaining == null
                ? l10n.waitingCountdownPending
                : l10n.waitingCountdownLabel(
                    CountdownFormat.format(remaining!),
                  ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _RequestSummaryCard extends StatelessWidget {
  const _RequestSummaryCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'waiting_request_description',
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.medium),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: OmdsBorderRadius.uiLarge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.waitingRequestSummaryLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.xSmall),
            Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoOffersYetHeader extends StatelessWidget {
  const _NoOffersYetHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'waiting_no_coverage_state',
      container: true,
      child: Column(
        children: [
          Icon(
            Icons.location_off_outlined,
            size: Sizes.eightXLarge,
            color: context.jeebRoles.warning,
          ),
          const SizedBox(height: Spacing.large),
          Text(
            l10n.waitingNoCoverageTitle,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.small),
          Text(
            l10n.waitingNoCoverageBody,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
