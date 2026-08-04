import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/accessibility/accessibility.dart';
import '../../../core/lifecycle/app_resume_signals.dart';
import '../../../core/theme/jeeb_radii.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_shadows.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_code_cells.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../delivery_status/domain/jeeber_summary.dart';
import '../application/live_tracking_cubit.dart';
import '../application/live_tracking_state.dart';
import '../domain/delivery_tracking_info.dart';
import 'live_tracking_l10n.dart';
import 'widgets/delivery_tracking_panel.dart';
import 'widgets/order_summary_pinned_header.dart';
import 'widgets/order_tracking_stepper.dart';
import 'widgets/tracking_courier_card.dart';
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
/// MIDNIGHT R3: the night map is the full background and every control lives on
/// a frosted bottom sheet. The pinned summary SLAB is gone — the board draws no
/// header — so its five facts are re-homed: the name onto the courier line, the
/// price/cash onto its qualifier, the ETA onto the map chip, the chat CTA onto
/// the courier row's circle, and the rest onto zero-size semantics nodes
/// ([OrderSummaryPinnedHeader]). Navigation side-effects live in the
/// `BlocListener` (gated by `listenWhen`), never the builder.
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
    return Semantics(
      identifier: 'tracking_root',
      container: true,
      // Keep terminal-state and CTA identifiers as addressable descendants
      // instead of folding them into the screen-signature node.
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
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
        return const _BackBarScaffold(child: _TrackingLoadingBody());
      case LiveTrackingViewMode.error:
        return _BackBarScaffold(
          child: _TrackingErrorBody(
            message: state.errorMessage,
            title: state.errorTitle,
            onRetry: () => context.read<LiveTrackingCubit>().retry(),
          ),
        );
      case LiveTrackingViewMode.ready:
        // sprint-009 scenario matrix #9 + P6/A1+A3: cancelled, expired and
        // under-review each get their OWN body instead of a live "Ordered"
        // stepper that polls a dead row forever (or, worse, one that rewinds an
        // escalated delivery to step 1).
        final info = state.trackingInfo!;
        if (info.isCancelled) {
          return const _BackBarScaffold(child: _TrackingCancelledBody());
        }
        if (info.isExpired) {
          return const _BackBarScaffold(child: _TrackingExpiredBody());
        }
        if (info.isUnderReview) {
          return const _BackBarScaffold(child: _TrackingUnderReviewBody());
        }
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

/// Mounts [_TrackingBackBar] above a body that has no map of its own, on the
/// Midnight `content` field.
///
/// [OrderTrackingStepper]'s sheet only exists in the ready state, so loading,
/// error and the three terminal bodies would otherwise have no way back.
class _BackBarScaffold extends StatelessWidget {
  const _BackBarScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return JeebMidnightField(
      variant: JeebFieldVariant.content,
      animateDecor: false,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _TrackingBackBar(),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// The bare back circle, for every state without a map to float over.
///
/// Exactly one of this widget and [TrackingMapSurface]'s floating circle is ever
/// mounted, so `tracking_back` never has two emitters.
class _TrackingBackBar extends StatelessWidget {
  const _TrackingBackBar();

  @override
  Widget build(BuildContext context) {
    return JeebTopBar.back(
      identifier: 'tracking_back',
      // `maybePop` alone no-ops when tracking IS the stack root (a push-
      // notification or deep-link landing), leaving a dead circle. `'/'` is
      // exactly `AppRouter.backFallbacks['live-tracking']`.
      onLeadingPressed: () => trackingBack(context),
    );
  }
}

/// The one back destination this screen has: pop when there is a stack, else
/// `AppRouter.backFallbacks['live-tracking']`.
void trackingBack(BuildContext context) =>
    context.canPop() ? context.pop() : context.go('/');

/// The cold read — the Midnight loading skeleton, not a bare spinner.
class _TrackingLoadingBody extends StatelessWidget {
  const _TrackingLoadingBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        child: JeebEmptyState.compact(
          status: JeebEmptyStateStatus.loading,
          headline: l10n.trackingTitle,
        ),
      ),
    );
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
    return _TerminalBody(
      stateKey: cancelledStateKey,
      identifier: 'tracking_cancelled_state',
      headline: l10n.deliveryCancelledBanner,
      body: l10n.trackingCancelledBody,
      ctaIdentifier: 'tracking_cancelled_home_cta',
      ctaKey: const Key('tracking-cancelled-home-cta'),
      ctaLabel: l10n.trackingCancelledHomeCta,
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
    return _TerminalBody(
      stateKey: expiredStateKey,
      identifier: 'tracking_expired_state',
      headline: l10n.trackingExpiredTitle,
      body: l10n.trackingExpiredBody,
      ctaIdentifier: 'tracking_expired_home_cta',
      ctaKey: const Key('tracking-expired-home-cta'),
      ctaLabel: l10n.trackingCancelledHomeCta,
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
    return _TerminalBody(
      stateKey: underReviewStateKey,
      identifier: 'tracking_under_review_state',
      headline: l10n.trackingUnderReviewTitle,
      body: l10n.trackingUnderReviewBody,
    );
  }
}

/// The shared shape of the three terminal bodies — one [JeebEmptyState] block
/// with an optional exit CTA.
class _TerminalBody extends StatelessWidget {
  const _TerminalBody({
    required this.stateKey,
    required this.identifier,
    required this.headline,
    required this.body,
    this.ctaIdentifier,
    this.ctaKey,
    this.ctaLabel,
  });

  final Key stateKey;
  final String identifier;
  final String headline;
  final String body;
  final String? ctaIdentifier;
  final Key? ctaKey;
  final String? ctaLabel;

  @override
  Widget build(BuildContext context) {
    final label = ctaLabel;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: Spacing.large),
        child: JeebEmptyState.compact(
          key: stateKey,
          identifier: identifier,
          headline: headline,
          body: body,
          action: label == null
              ? null
              : Semantics(
                  identifier: ctaIdentifier,
                  container: true,
                  button: true,
                  child: JeebCtaButton.accent(
                    key: ctaKey,
                    label: label,
                    expand: true,
                    // `context.go('/')` resolves the role-aware shell home — the
                    // same terminal destination the cancel-request sheet uses.
                    onTap: () => context.go('/'),
                  ),
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

  /// How much of the viewport the sheet may claim before it scrolls internally
  /// (board 0.22 at rest; the ceiling is for 200% text and the at-door card).
  static const double sheetMaxHeightFactor = 0.78;

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
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: TrackingMapSurface(
              info: info,
              useLiveMap: useLiveMap,
              fillViewport: true,
              onBack: () => trackingBack(context),
            ),
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * sheetMaxHeightFactor,
              ),
              child: _TrackingSheet(
                info: info,
                isAtDoor: isAtDoor,
                deliveryId: deliveryId,
                handoverCode: handoverCode,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// R3's frosted bottom sheet — the one place every control lives.
///
/// The screen's single real `BackdropFilter` besides the ETA chip (§4 budget:
/// ≤2), so the map genuinely blurs through the navy instead of faking it.
class _TrackingSheet extends StatelessWidget {
  const _TrackingSheet({
    required this.info,
    required this.isAtDoor,
    required this.deliveryId,
    required this.handoverCode,
  });

  /// The board insets the sheet from the phone edge by 4 and rounds its
  /// corners at 21 dp — the `xl` rung, not `sheet`.
  static const double edgeInset = 4;
  static const double cornerRadius = JeebRadii.xl;

  /// Grab-handle geometry (board 46×5 px at the export's 1.1x = 42×4 dp).
  static const double handleWidth = 42;
  static const double handleHeight = 4;

  /// Sheet fill opacity — the board composites to `surfaceContainerLow` over
  /// the dimmed map; the remainder is what the blur samples.
  static const double fillOpacity = 0.88;

  final DeliveryTrackingInfo info;
  final bool isAtDoor;
  final String deliveryId;
  final String? handoverCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantics = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final radius = BorderRadius.circular(cornerRadius);

    return Padding(
      padding: const EdgeInsets.all(edgeInset),
      child: DecoratedBox(
        // Outside the clip, or the clip eats the lift.
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: JeebShadows.floatNav,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: JeebGlassCapsule.heroBlur,
              sigmaY: JeebGlassCapsule.heroBlur,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow
                    .withValues(alpha: fillOpacity),
                borderRadius: radius,
                border: Border.all(color: semantics.glassBorder),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      Spacing.xLarge,
                      Spacing.large - Spacing.twoXSmall,
                      Spacing.xLarge,
                      Spacing.xLarge,
                    ),
                    child: _SheetContent(
                      info: info,
                      isAtDoor: isAtDoor,
                      deliveryId: deliveryId,
                      handoverCode: handoverCode,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetContent extends StatelessWidget {
  const _SheetContent({
    required this.info,
    required this.isAtDoor,
    required this.deliveryId,
    required this.handoverCode,
  });

  final DeliveryTrackingInfo info;
  final bool isAtDoor;
  final String deliveryId;
  final String? handoverCode;

  @override
  Widget build(BuildContext context) {
    final semantics = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final jeeber = info.jeeber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: semantics.glassBorderVivid,
              borderRadius: BorderRadius.circular(JeebRadii.pill),
            ),
            child: const SizedBox(
              width: _TrackingSheet.handleWidth,
              height: _TrackingSheet.handleHeight,
            ),
          ),
        ),
        const SizedBox(height: Spacing.large - Spacing.twoXSmall),
        // JM-032 AC1: the 4-step stepper is the PRIMARY visual.
        // P6/A5: at the door the third step RELABELS to "At Door" (its
        // identifier stays `tracking_step_in_transit`).
        OrderTrackingStepper(
          currentStep: info.trackingStepIndex4,
          atDoor: info.currentStage == TrackingStage.atDoor,
        ),
        if (jeeber != null || info.hasSummary) ...[
          const SizedBox(height: Spacing.medium),
          _TrackingCourierRow(info: info, jeeber: jeeber, deliveryId: deliveryId),
        ],
        const SizedBox(height: Spacing.medium),
        if (isAtDoor)
          // G4: at the door the code is PROMINENT — inline in the card.
          OtpAtDoorCard(deliveryId: deliveryId, handoverCode: handoverCode)
        else ...[
          // G4: as soon as the code is known (accept time) it is discoverable.
          //
          // P0 (2026-07-31): this row used to be gated on `handoverCode != null`
          // and [OtpAtDoorCard] on `isAtDoor`. Both gates failed at once on real
          // hardware, so the customer had NO path to the code and the delivery
          // dead-ended. The row is therefore UNCONDITIONAL: when the code is not
          // cached the trailing slot becomes the "Show OTP" CTA and the OTP
          // screen fetches it (proven — dev-e2e `a33/G4-11-show-otp.png`).
          _HandoverCodeRow(code: handoverCode, deliveryId: deliveryId),
          const SizedBox(height: Spacing.small),
          DeliveryTrackingPanel(info: info),
        ],
        // Zero-size carriers for the summary facts the board does not draw.
        OrderSummaryPinnedHeader(info: info),
        _TrackingActionBar(info: info, deliveryId: deliveryId),
      ],
    );
  }
}

/// The board's courier line: Ø50 avatar, name + qualifier, chat circle.
///
/// The row also mounts on a summary-bearing delivery with no [JeeberSummary]
/// yet — `order_summary_open_chat` is a contract that cannot depend on the
/// courier slice having landed.
class _TrackingCourierRow extends StatelessWidget {
  const _TrackingCourierRow({
    required this.info,
    required this.jeeber,
    required this.deliveryId,
  });

  final DeliveryTrackingInfo info;
  final JeeberSummary? jeeber;
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = LiveTrackingL10n.of(context);
    final courier = jeeber;
    // EDGE: order_summary_open_chat → order-chat (JM-025). Routes by the
    // REQUEST id (== correlationKey), falling back to the delivery id — NEVER
    // the conversationId, which guarantees a 404 on the thread lookup (BUG-17).
    final chat = _TrackingCircleAction(
      icon: Icons.chat_bubble,
      identifier: 'order_summary_open_chat',
      semanticLabel: l10n.summaryOpenChat,
      onTap: () => context.goNamed(
        'chat-detail',
        pathParameters: {
          'id': (info.requestId?.isNotEmpty ?? false)
              ? info.requestId!
              : deliveryId,
        },
      ),
    );

    if (courier == null) {
      return Align(alignment: AlignmentDirectional.centerEnd, child: chat);
    }
    return TrackingCourierCard(
      jeeber: courier,
      price: info.price,
      currency: info.currency,
      trailing: chat,
    );
  }
}

/// One Ø48 glass circle action, the board's own courier-row affordance.
class _TrackingCircleAction extends StatelessWidget {
  const _TrackingCircleAction({
    required this.icon,
    required this.identifier,
    required this.semanticLabel,
    required this.onTap,
  });

  /// Board Ø48 — already the a11y minimum, so the circle IS the tap target.
  static const double diameter = A11y.minTapTargetSize;

  /// Glyph size (`tpl 771`).
  static const double glyphSize = 19;

  final IconData icon;
  final String identifier;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantics = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return Semantics(
      identifier: identifier,
      label: semanticLabel,
      button: true,
      container: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          splashColor: semantics.glassFillPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: semantics.glassFillEmphasis,
              shape: BoxShape.circle,
              border: Border.all(color: semantics.glassBorder),
            ),
            child: SizedBox.square(
              dimension: diameter,
              child: Center(
                child: Icon(icon, size: glyphSize, color: scheme.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// JM-032 AC3 (dispute) + AC4 (no-show). Both controls carry their coined ids
/// from 63_W1_TEST_PLAN §2.12. The board does not draw them on R3; they ship as
/// the quietest pair in the sheet because the dispute exit is a product lock.
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
    return JeebCtaFooter.split(
      expandLeading: true,
      // The sheet already owns the 24 gutter and the safe-area inset.
      padding: const EdgeInsetsDirectional.fromSTEB(0, Spacing.medium, 0, 0),
      leading: Semantics(
        identifier: 'tracking_noshow_cta',
        button: true,
        child: JeebCtaButton.text(
          label: l10n.noShowCta,
          expand: true,
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
      trailing: Semantics(
        identifier: 'tracking_dispute_cta',
        button: true,
        child: JeebCtaButton.outline(
          label: l10n.disputeCta,
          // EDGE: tracking_dispute_cta → dispute-open-evidence
          // (`escalate` route, JM-060/W4). 21_NAV_PLAN §C.
          onTap: () => context.goNamed(
            'escalate',
            pathParameters: {'id': deliveryId},
          ),
        ),
      ),
    );
  }
}

/// G4: the board's door-code strip — key glyph, one label line, the code —
/// tappable through to the full-screen display.
///
/// P0 (2026-07-31): [code] is NULLABLE and the row renders either way. It is
/// this screen's only unconditional route to `/orders/{id}/otp`, so it must not
/// be hidden by a cache miss; with no cached code the trailing slot becomes the
/// "Show OTP" CTA and the OTP screen fetches it.
class _HandoverCodeRow extends StatelessWidget {
  const _HandoverCodeRow({required this.code, required this.deliveryId});

  final String? code;
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trackingL10n = LiveTrackingL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final semantics = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final knownCode = code;
    return Semantics(
      // Contract unchanged: one node, button, the chip label, and the code
      // read out digit-by-digit (or the CTA when there is none).
      identifier: 'tracking_handover_code_row',
      button: true,
      label: l10n.trackingCodeChipLabel,
      value: knownCode == null
          ? l10n.trackingAtDoorCta
          : knownCode.split('').join(' '),
      child: JeebInfoNote.muted(
        // The board draws this key in ink, not in the muted tone's periwinkle.
        icon: Icons.vpn_key_outlined,
        iconSize: Sizes.large,
        iconColor: scheme.onSurface,
        gap: Spacing.small,
        onTap: () => context.push('/orders/$deliveryId/otp'),
        label: Text(
          trackingL10n.doorCodeNote,
          style: context.jeebText.bodySmall
              .copyWith(color: semantics.mutedText),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Flexible: the note's trailing slot is inflexible, so an Arabic CTA at
        // 200% overflows the strip without it.
        trailing: knownCode == null
            ? Flexible(
                child: Text(
                  l10n.trackingAtDoorCta,
                  key: const Key('tracking.codeRowValue'),
                  style: context.jeebText.cardTitle
                      .copyWith(color: scheme.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            // ONE Text in an LTR isolate — never per-digit widgets: the tests
            // assert `find.text('1234')` on the visible run.
            : JeebCodeCells.strip(
                knownCode,
                textKey: const Key('tracking.codeRowValue'),
              ),
      ),
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: Spacing.large),
        child: JeebEmptyState.compact(
          key: errorStateKey,
          status: JeebEmptyStateStatus.error,
          identifier: 'tracking_error_state',
          headline: title ?? l10n.trackingGpsLostTitle,
          body: message ?? l10n.trackingGpsLostBody,
          action: JeebCtaButton.accent(
            label: l10n.trackingGpsLostRetry,
            expand: true,
            onTap: onRetry,
          ),
        ),
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
  /// resume bus. `LiveTrackingCubit.refreshNow`'s own in-flight latch only
  /// collapses OVERLAPPING calls; the rate floor that collapses a burst lives
  /// in [AppResumeSignals].
  @override
  void onAppResumed() => context.read<LiveTrackingCubit>().refreshNow();

  @override
  Widget build(BuildContext context) => widget.child;
}
