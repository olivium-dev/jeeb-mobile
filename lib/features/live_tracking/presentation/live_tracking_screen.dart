import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/lifecycle/app_resume_signals.dart';
import '../../../l10n/app_localizations.dart';
import '../../delivery_status/domain/jeeber_summary.dart';
import '../../delivery_status/presentation/widgets/delivery_jeeber_card.dart';
import '../application/live_tracking_cubit.dart';
import '../application/live_tracking_state.dart';
import '../domain/delivery_tracking_info.dart';
import 'live_tracking_l10n.dart';
import 'widgets/delivery_tracking_panel.dart';
import 'widgets/order_summary_pinned_header.dart';
import 'widgets/order_tracking_stepper.dart';
import 'widgets/tracking_map_surface.dart';
import 'widgets/tracking_noshow_sheet.dart';
import 'widgets/otp_at_door_card.dart';

class LiveTrackingScreen extends StatelessWidget {
  const LiveTrackingScreen({
    super.key,
    required this.deliveryId,
    this.useLiveMap = true,
  });

  final String deliveryId;

  final bool useLiveMap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'tracking_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.trackingTitle,
          showBackButton: true,
          centerTitle: true,
        ),
        body: _ResumeRefresh(
          child: BlocConsumer<LiveTrackingCubit, LiveTrackingState>(
            listenWhen: _hasNewEvent,
            listener: _onEvent,
            builder: (context, state) => _TrackingStateView(
              state: state,
              deliveryId: deliveryId,
              useLiveMap: useLiveMap,
            ),
          ),
        ),
      ),
    );
  }

  bool _hasNewEvent(LiveTrackingState prev, LiveTrackingState next) =>
      next.pendingEvent != LiveTrackingEvent.none;

  void _onEvent(BuildContext context, LiveTrackingState state) {
    final l10n = AppLocalizations.of(context);
    switch (state.pendingEvent) {
      case LiveTrackingEvent.jeeberOnTheWay:
        showOmdsSnackbar(context, message: l10n.trackingJeeberOnTheWay);
        break;
      case LiveTrackingEvent.deliveredAutoAdvance:
        context.goNamed(
          'delivered-receipt',
          pathParameters: {'id': deliveryId},
        );
        break;
      case LiveTrackingEvent.none:
      case LiveTrackingEvent.jeeberAtDoor:
        break;
    }
  }
}

class _TrackingStateView extends StatelessWidget {
  const _TrackingStateView({
    required this.state,
    required this.deliveryId,
    required this.useLiveMap,
  });

  final LiveTrackingState state;
  final String deliveryId;
  final bool useLiveMap;

  @override
  Widget build(BuildContext context) {
    switch (state.mode) {
      case LiveTrackingViewMode.loading:
        return const Center(child: OmdsLoadingState());
      case LiveTrackingViewMode.error:
        return _TrackingErrorBody(
          message: state.errorMessage,
          title: state.errorTitle,
          onRetry: () => context.read<LiveTrackingCubit>().retry(),
        );
      case LiveTrackingViewMode.ready:
        final info = state.trackingInfo!;
        if (info.isCancelled) return const _TrackingCancelledBody();
        if (info.isExpired) return const _TrackingExpiredBody();
        if (info.isUnderReview) return const _TrackingUnderReviewBody();
        return _TrackingBody(
          info: info,
          isAtDoor: state.isAtDoor,
          deliveryId: deliveryId,
          useLiveMap: useLiveMap,
          handoverCode: state.handoverCode,
        );
    }
  }
}

class _TrackingCancelledBody extends StatelessWidget {
  const _TrackingCancelledBody();

  static const Key cancelledStateKey = Key('live-tracking-cancelled-state');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'tracking_cancelled_state',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OmdsEmptyState(
                key: cancelledStateKey,
                icon: Icons.cancel_outlined,
                title: l10n.deliveryCancelledBanner,
                subtitle: l10n.trackingCancelledBody,
              ),
              const SizedBox(height: Spacing.large),
              Semantics(
                identifier: 'tracking_cancelled_home_cta',
                container: true,
                button: true,
                child: OmdsPrimaryButton(
                  key: const Key('tracking-cancelled-home-cta'),
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
}

class _TrackingExpiredBody extends StatelessWidget {
  const _TrackingExpiredBody();

  static const Key expiredStateKey = Key('live-tracking-expired-state');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'tracking_expired_state',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OmdsEmptyState(
                key: expiredStateKey,
                icon: Icons.timer_off_outlined,
                title: l10n.trackingExpiredTitle,
                subtitle: l10n.trackingExpiredBody,
              ),
              const SizedBox(height: Spacing.large),
              Semantics(
                identifier: 'tracking_expired_home_cta',
                container: true,
                button: true,
                child: OmdsPrimaryButton(
                  key: const Key('tracking-expired-home-cta'),
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
}

class _TrackingUnderReviewBody extends StatelessWidget {
  const _TrackingUnderReviewBody();

  static const Key underReviewStateKey =
      Key('live-tracking-under-review-state');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'tracking_under_review_state',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OmdsEmptyState(
                key: underReviewStateKey,
                icon: Icons.report_problem_outlined,
                title: l10n.trackingUnderReviewTitle,
                subtitle: l10n.trackingUnderReviewBody,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingBody extends StatelessWidget {
  const _TrackingBody({
    required this.info,
    required this.isAtDoor,
    required this.deliveryId,
    required this.useLiveMap,
    this.handoverCode,
  });

  final DeliveryTrackingInfo info;
  final bool isAtDoor;
  final String deliveryId;
  final bool useLiveMap;

  final String? handoverCode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          if (info.hasSummary)
            OrderSummaryPinnedHeader(
              info: info,
              onOpenChat: () => context.goNamed(
                'chat-detail',
                pathParameters: {
                  'id': (info.requestId?.isNotEmpty ?? false)
                      ? info.requestId!
                      : deliveryId,
                },
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Spacing.medium,
              Spacing.medium,
              Spacing.medium,
              Spacing.xSmall,
            ),
            child: OrderTrackingStepper(
              currentStep: info.trackingStepIndex4,
              atDoor: info.currentStage == TrackingStage.atDoor,
            ),
          ),
          Expanded(
            flex: isAtDoor ? 1 : 2,
            child: TrackingMapSurface(info: info, useLiveMap: useLiveMap),
          ),
          if (info.jeeber != null) _TrackingJeeberSection(jeeber: info.jeeber!),
          if (isAtDoor)
            OtpAtDoorCard(deliveryId: deliveryId, handoverCode: handoverCode)
          else ...[
            // a best-effort local cache must not, between them, be able to
            _HandoverCodeRow(code: handoverCode, deliveryId: deliveryId),
            _TrackingPanelSection(info: info),
          ],
          _TrackingActionBar(info: info, deliveryId: deliveryId),
        ],
      ),
    );
  }
}

class _TrackingActionBar extends StatelessWidget {
  const _TrackingActionBar({required this.info, required this.deliveryId});

  final DeliveryTrackingInfo info;
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = LiveTrackingL10n.of(context);
    final requestId = (info.requestId?.isNotEmpty ?? false)
        ? info.requestId!
        : deliveryId;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        0,
        Spacing.medium,
        Spacing.medium,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              identifier: 'tracking_noshow_cta',
              button: true,
              child: OmdsPrimaryButton(
                text: l10n.noShowCta,
                variant: OmdsButtonVariant.text,
                onTap: () => TrackingNoShowSheet.show(
                  context: context,
                  onReassign: () => context.goNamed(
                    'offer-review',
                    pathParameters: {'id': requestId},
                  ),
                  onRebroadcast: () => context.goNamed(
                    'waiting-no-coverage',
                    pathParameters: {'id': requestId},
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Semantics(
              identifier: 'tracking_dispute_cta',
              button: true,
              child: OmdsPrimaryButton(
                text: l10n.disputeCta,
                variant: OmdsButtonVariant.outlined,
                onTap: () => context.goNamed(
                  'escalate',
                  pathParameters: {'id': deliveryId},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// hand-over cannot happen without it, so it must not be hidden by a cache
class _HandoverCodeRow extends StatelessWidget {
  const _HandoverCodeRow({required this.code, required this.deliveryId});

  final String? code;
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final knownCode = code;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        Spacing.small,
        Spacing.medium,
        0,
      ),
      child: Semantics(
        identifier: 'tracking_handover_code_row',
        button: true,
        label: l10n.trackingCodeChipLabel,
        value: knownCode == null
            ? l10n.trackingAtDoorCta
            : knownCode.split('').join(' '),
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: OmdsBorderRadius.medium,
          child: InkWell(
            borderRadius: OmdsBorderRadius.medium,
            onTap: () => context.push('/orders/$deliveryId/otp'),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: Spacing.medium,
                vertical: Spacing.small,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.key_outlined,
                    size: Sizes.medium,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.small),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.trackingCodeChipLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          l10n.trackingCodeChipHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.small),
                  Text(
                    knownCode ?? l10n.trackingAtDoorCta,
                    key: const Key('tracking.codeRowValue'),
                    style: (knownCode == null
                            ? theme.textTheme.titleSmall
                            : theme.textTheme.titleLarge)
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: knownCode == null ? null : Spacing.xSmall,
                      color: knownCode == null
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackingJeeberSection extends StatelessWidget {
  const _TrackingJeeberSection({required this.jeeber});

  final JeeberSummary jeeber;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.medium,
        Spacing.medium,
        Spacing.medium,
        0,
      ),
      child: DeliveryJeeberCard(jeeber: jeeber),
    );
  }
}

class _TrackingPanelSection extends StatelessWidget {
  const _TrackingPanelSection({required this.info});

  final DeliveryTrackingInfo info;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      child: DeliveryTrackingPanel(info: info),
    );
  }
}

class _TrackingErrorBody extends StatelessWidget {
  const _TrackingErrorBody({
    required this.message,
    required this.onRetry,
    this.title,
  });

  final String? message;

  final String? title;
  final VoidCallback onRetry;

  static const Key errorStateKey = Key('live-tracking-error-state');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isNotFound = title != null;
    return Center(
      child: OmdsErrorState(
        key: errorStateKey,
        title: title,
        message: message ?? l10n.trackingGpsLostBody,
        icon: isNotFound ? Icons.inbox_outlined : Icons.location_off_outlined,
        onRetry: onRetry,
        retryLabel: l10n.trackingGpsLostRetry,
      ),
    );
  }
}

class _ResumeRefresh extends StatefulWidget {
  const _ResumeRefresh({required this.child});

  final Widget child;

  @override
  State<_ResumeRefresh> createState() => _ResumeRefreshState();
}

class _ResumeRefreshState extends State<_ResumeRefresh>
    with ResumeRefetchMixin {
  @override
  void onAppResumed() => context.read<LiveTrackingCubit>().refreshNow();

  @override
  Widget build(BuildContext context) => widget.child;
}
