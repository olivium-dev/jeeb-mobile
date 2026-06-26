import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

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

/// JM-032 — `order-tracking`. The customer's live order-tracking surface.
///
/// AC1: a 4-step `tracking_stepper` (Ordered → Picked → In Transit → Delivered,
///      D70) is the PRIMARY visual + an `order_summary_pinned` header (JM-031).
/// AC2: when the Jeeber marks delivered, the screen auto-advances to
///      `delivered-receipt-confirm` (`delivered-receipt` route, JM-033).
/// AC3: `tracking_dispute_cta` → dispute-open-evidence (`escalate` route, W4).
/// AC4: `tracking_noshow_cta` opens the `tracking_noshow_sheet` →
///      reassign (`offer-review`) / re-broadcast (`waiting-no-coverage`) [D88].
///
/// The live map + at-door OTP card + GPS-lost retry (T-MOB-017) are retained
/// beneath the stepper. Navigation side-effects live in the `BlocListener`
/// (gated by `listenWhen`), never the builder (40_GUARDRAILS_ARCH §3).
class LiveTrackingScreen extends StatelessWidget {
  const LiveTrackingScreen({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.trackingTitle,
        showBackButton: true,
        centerTitle: true,
      ),
      body: BlocConsumer<LiveTrackingCubit, LiveTrackingState>(
        listenWhen: _hasNewEvent,
        listener: _onEvent,
        builder: (context, state) => _TrackingStateView(
          state: state,
          deliveryId: deliveryId,
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
        // JM-032 AC2: terminal delivered → auto-advance to the receipt prompt.
        // EDGE: order-tracking → delivered-receipt-confirm (JM-033,
        // 21_NAV_PLAN §C). `goNamed` replaces tracking so back doesn't return
        // to a stale stepper.
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
  });

  final LiveTrackingState state;
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    switch (state.mode) {
      case LiveTrackingViewMode.loading:
        return const Center(child: OmdsLoadingState());
      case LiveTrackingViewMode.error:
        return _TrackingErrorBody(
          message: state.errorMessage,
          onRetry: () => context.read<LiveTrackingCubit>().retry(),
        );
      case LiveTrackingViewMode.ready:
        return _TrackingBody(
          info: state.trackingInfo!,
          isAtDoor: state.isAtDoor,
          deliveryId: deliveryId,
        );
    }
  }
}

class _TrackingBody extends StatelessWidget {
  const _TrackingBody({
    required this.info,
    required this.isAtDoor,
    required this.deliveryId,
  });

  final DeliveryTrackingInfo info;
  final bool isAtDoor;
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          // JM-031: pinned summary header at the very top (visible in both chat
          // + tracking contexts). Only mounted once the row carries the summary.
          if (info.hasSummary)
            OrderSummaryPinnedHeader(
              info: info,
              // EDGE: order_summary_open_chat → order-chat (JM-025). Resolves
              // the conversation id, falling back to the delivery id (the
              // `/chat/:id` route resolves either, per the mock convention).
              onOpenChat: () => context.goNamed(
                'chat-detail',
                pathParameters: {
                  'id': (info.conversationId?.isNotEmpty ?? false)
                      ? info.conversationId!
                      : (info.requestId ?? deliveryId),
                },
              ),
              // The Track CTA is the current surface — omitted to avoid a
              // self-navigating button (JM-031 renders it on the chat surface).
            ),
          // JM-032 AC1: the 4-step stepper is the PRIMARY visual.
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Spacing.medium,
              Spacing.medium,
              Spacing.medium,
              Spacing.xSmall,
            ),
            child: OrderTrackingStepper(currentStep: info.trackingStepIndex4),
          ),
          // T-MOB-017: live map (half-collapsed at_door). Fed the latest
          // courier GPS fix + route polyline straight from the tracking feed.
          Expanded(
            flex: isAtDoor ? 1 : 2,
            child: TrackingMapSurface(
              jeeberPosition: info.jeeberPosition,
              routePoints: info.polyline,
            ),
          ),
          if (info.jeeber != null) _TrackingJeeberSection(jeeber: info.jeeber!),
          if (isAtDoor)
            OtpAtDoorCard(deliveryId: deliveryId)
          else
            _TrackingPanelSection(info: info),
          // JM-032 AC3/AC4: dispute + no-show CTAs.
          _TrackingActionBar(info: info, deliveryId: deliveryId),
        ],
      ),
    );
  }
}

/// JM-032 AC3 (dispute) + AC4 (no-show). Both controls carry their coined ids
/// from 63_W1_TEST_PLAN §2.12. Dispute routes to the registered `escalate`
/// route (its `dispute_reason` body is JM-060/W4); no-show opens the sheet.
class _TrackingActionBar extends StatelessWidget {
  const _TrackingActionBar({required this.info, required this.deliveryId});

  final DeliveryTrackingInfo info;
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = LiveTrackingL10n.of(context);
    // The no-show recovery routes are request-scoped; the delivery row carries
    // requestId (mock convention: deliveryId == accepted-request-id when null).
    final requestId =
        (info.requestId?.isNotEmpty ?? false) ? info.requestId! : deliveryId;
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
                  // AC4a: reassign → offer-review-list.
                  onReassign: () => context.goNamed(
                    'offer-review',
                    pathParameters: {'id': requestId},
                  ),
                  // AC4b: re-broadcast → waiting-no-coverage.
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
                // EDGE: tracking_dispute_cta → dispute-open-evidence
                // (`escalate` route, JM-060/W4). 21_NAV_PLAN §C.
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

/// The matched-Jeeber card rendered above the panel / OTP card. Mounted ONLY
/// when a jeeber is assigned, so [DeliveryJeeberCard]'s "looking for a Jeeber…"
/// placeholder never shows on an already GPS-streaming delivery.
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
  const _TrackingErrorBody({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: OmdsErrorState(
        message: message ?? l10n.trackingGpsLostBody,
        icon: Icons.location_off_outlined,
        onRetry: onRetry,
        retryLabel: l10n.trackingGpsLostRetry,
      ),
    );
  }
}
