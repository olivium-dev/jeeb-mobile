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
  const LiveTrackingScreen({
    super.key,
    required this.deliveryId,
    this.useLiveMap = true,
  });

  final String deliveryId;

  /// T-MOB-017 / sprint-009 P0: when false the deterministic map placeholder is
  /// rendered instead of a live GoogleMap.
  ///
  /// DEFAULTS TO TRUE. The sprint-009 stop-the-bleed default of `false` guarded
  /// against a keyless-map native SIGKILL: mounting a live GoogleMap with no
  /// `com.google.android.geo.API_KEY` makes the native Maps SDK throw an
  /// UNCAUGHT `IllegalStateException` off the platform thread — a native FATAL
  /// no Dart try/catch can contain. That precondition is now satisfied:
  /// `AndroidManifest.xml` wires `com.google.android.geo.API_KEY` from the
  /// gitignored `android/local.properties` `${MAPS_API_KEY}`, and Google-Cloud
  /// billing is enabled on the `jeeb-5a293` project, so the Maps SDK serves. The
  /// customer tracking surface now renders the live courier map by default;
  /// callers can still pass `useLiveMap: false` explicitly (e.g. tests, or a
  /// deliberate placeholder) to fall back to the static tile.
  final bool useLiveMap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'tracking_root',
      container: true,
      // Keep terminal-state and CTA identifiers as addressable descendants
      // instead of folding them into the screen-signature node.
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.trackingTitle,
          showBackButton: true,
          centerTitle: true,
        ),
        // JEBV4-282: force an immediate re-fetch when the app returns to the
        // foreground (the 5s poll timer is suspended while backgrounded), so the
        // customer's status stepper reflects a transition that happened off-screen
        // instead of staying stale.
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
        // sprint-009 scenario matrix #9 + P6/A1+A3: cancelled, expired and
        // under-review each get their OWN body instead of a live "Ordered"
        // stepper that polls a dead row forever (or, worse, one that rewinds an
        // escalated delivery to step 1).
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

/// Terminal state for a CANCELLED delivery (scenario matrix #9). Neutral copy
/// + a single "back home" affordance; no retry (there is nothing to retry — the
/// row is terminal) and no stepper/map (nothing is moving). P6/A3: `expired`
/// no longer lands here — it has [_TrackingExpiredBody].
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
                  // `context.go('/')` resolves the role-aware shell home — the
                  // same terminal destination the cancel-request sheet uses.
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

/// P6/A3: terminal state for an EXPIRED request. Structurally identical to
/// [_TrackingCancelledBody] but with its own ids + copy — cancel and expire
/// carry different fee/strike semantics and must never share a message.
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

/// P6/A1: `FailedNeedsEscalation` used to parse into a lifecycle value NO
/// widget read, so the customer saw the normal active layout with the stepper
/// rewound to step 1 and a 5 s poll that never stopped. Render an explicit
/// "under review" body — and KEEP polling, because an admin can still resolve
/// the row to Done (SM edge 12) or cancel it (edge 13). Deliberately NO home
/// CTA: the delivery is still live, so this is not an exit.
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

  /// G4: the accept-time hand-over code, re-hydrated from local persistence.
  /// Rendered discoverably (compact row) before at-door and prominently
  /// (inline in [OtpAtDoorCard]) at the door. Null → surfaces degrade to the
  /// pre-fix layout and the OTP screen's SMS fallback.
  final String? handoverCode;

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
              // EDGE: order_summary_open_chat → order-chat (JM-025). Routes by
              // the REQUEST id (== correlationKey), falling back to the
              // delivery id — NEVER the conversationId. `ChatDetailScreen`
              // resolves the thread via
              // `GET /v1/conversations?correlationKey={requestId}`, so a
              // conversationId param guarantees a 404 on that lookup (BUG-17).
              onOpenChat: () => context.goNamed(
                'chat-detail',
                pathParameters: {
                  'id': (info.requestId?.isNotEmpty ?? false)
                      ? info.requestId!
                      : deliveryId,
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
            // P6/A5: at the door the third step RELABELS to "At Door" (its
            // identifier stays `tracking_step_in_transit`) — the 4-step
            // blueprint is unchanged, no fifth step.
            child: OrderTrackingStepper(
              currentStep: info.trackingStepIndex4,
              atDoor: info.currentStage == TrackingStage.atDoor,
            ),
          ),
          // T-MOB-017: live map (half-collapsed at_door). Fed the latest
          // courier GPS fix + route polyline straight from the tracking feed.
          Expanded(
            flex: isAtDoor ? 1 : 2,
            child: TrackingMapSurface(info: info, useLiveMap: useLiveMap),
          ),
          if (info.jeeber != null) _TrackingJeeberSection(jeeber: info.jeeber!),
          if (isAtDoor)
            // G4: at the door the code is PROMINENT — inline in the card.
            OtpAtDoorCard(deliveryId: deliveryId, handoverCode: handoverCode)
          else ...[
            // G4: as soon as the code is known (accept time) it is
            // discoverable — a quiet one-line row, not a hero banner.
            if (handoverCode != null)
              _HandoverCodeRow(code: handoverCode!, deliveryId: deliveryId),
            _TrackingPanelSection(info: info),
          ],
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

/// G4: compact, discoverable hand-over code row shown from accept time until
/// the at-door moment (where [OtpAtDoorCard] takes over prominently). One
/// quiet line — label + code + hint — tappable through to the full-screen
/// display. OMDS tokens only.
class _HandoverCodeRow extends StatelessWidget {
  const _HandoverCodeRow({required this.code, required this.deliveryId});

  final String code;
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
        value: code.split('').join(' '),
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
                    code,
                    key: const Key('tracking.codeRowValue'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: Spacing.xSmall,
                      color: theme.colorScheme.onSurface,
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
  const _TrackingErrorBody({
    required this.message,
    required this.onRetry,
    this.title,
  });

  final String? message;

  /// Distinct heading for the 404 "delivery not found" state; null renders the
  /// generic GPS/server error layout.
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
        // A 404 is a "nothing to track yet" state — use a neutral box icon
        // rather than the GPS-lost crosshair so it doesn't read as a fault.
        icon: isNotFound ? Icons.inbox_outlined : Icons.location_off_outlined,
        onRetry: onRetry,
        retryLabel: l10n.trackingGpsLostRetry,
      ),
    );
  }
}

/// JEBV4-282: re-fetches the tracked delivery when the app returns to the
/// foreground. Mounted between the [LiveTrackingCubit] provider and the body so
/// its [State] resolves the cubit via `context.read`. The cubit already polls
/// every 5s while on-screen; this closes the gap where the OS suspends Dart
/// timers in the background, so the customer's status stepper is never left
/// stale after a transition that landed while the app was away. A transparent
/// pass-through outside a lifecycle event.
class _ResumeRefresh extends StatefulWidget {
  const _ResumeRefresh({required this.child});

  final Widget child;

  @override
  State<_ResumeRefresh> createState() => _ResumeRefreshState();
}

class _ResumeRefreshState extends State<_ResumeRefresh>
    with ResumeRefetchMixin {
  /// b02 P0 — moved off the raw `resumed` notification onto the ONE coalesced
  /// resume bus. `LiveTrackingCubit.refreshNow`'s own in-flight latch (whose
  /// doc already noted that `resumed` "can fire MORE THAN ONCE for a single
  /// background→foreground trip") only collapses OVERLAPPING calls; the rate
  /// floor that collapses a burst lives in [AppResumeSignals].
  ///
  /// Direct call — see the note on the active-delivery twin: the old post-frame
  /// deferral only bought a `mounted` guard the mixin already gives, and cost a
  /// refetch that never lands on a screen with no other frame source.
  @override
  void onAppResumed() => context.read<LiveTrackingCubit>().refreshNow();

  @override
  Widget build(BuildContext context) => widget.child;
}
