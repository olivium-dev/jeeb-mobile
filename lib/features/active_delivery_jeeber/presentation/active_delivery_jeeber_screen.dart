import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/lifecycle/app_resume_signals.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/app_failure_mapper.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import '../../../core/widgets/jeeb/jeeb_snack.dart';
import '../../../core/widgets/jeeb/jeeb_state_host.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../background_gps/application/background_gps_cubit.dart';
import '../../background_gps/application/background_gps_state.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../application/active_delivery_cubit.dart';
import '../domain/active_delivery_repository.dart';
import '../domain/jeeber_delivery.dart';
import '../domain/jeeber_delivery_status.dart';
import 'active_delivery_jeeber_l10n.dart';
import 'active_delivery_muted_ink.dart';
import 'widgets/delivery_status_stepper.dart';
import 'widgets/gps_permission_banner.dart';
import 'widgets/mark_delivered_panel.dart';

/// Minimum width needed to keep the quick-action pills on one row.
///
/// Was 448 — which no phone in portrait ever reaches inside 24pt gutters, so
/// the "inline" row was unreachable and every device got the stacked column.
/// The board's row is the default; 320 is the width below which three pills
/// genuinely cannot hold their labels.
const double _kInlineQuickActionsMinWidth = 320;

/// Drop-off card padding — the board's `padding: 14px 16px` (`tpl 1057`).
/// `Spacing` has no 14 rung, and the card's own default is 13 vertical.
const EdgeInsetsGeometry _kDropOffCardPadding = EdgeInsetsDirectional.symmetric(
  horizontal: Spacing.medium,
  vertical: 14,
);

/// R18's own bottom glow, re-read in the M6 census: `rgba(215,59,0,.26)` under
/// the pill row — one notch above the ratified single glow alpha .24.
const double _kFieldGlowAlpha = 0.26;

/// Jeeber active-delivery / mark-delivered screen (T-MOB-031, JM-051).
///
/// Route: `/jeeber/deliveries/:id/active` (seam-pinned for the
/// `jeeber_active_delivery` journey → `mark_delivered_root` on first frame).
///
/// Shows the drop-off address, the status stepper (Ordered→…→AtDoor), and — at
/// `AtDoor` — the mark-delivered panel: a proof-of-delivery photo capture (D3),
/// an optional note, the "customer confirms receipt + pays cash" copy (D11),
/// and the "Complete Delivery" CTA. P6/B1: that CTA walks the ladder only as
/// far as `AtDoor` and then raises the door-OTP entry — `AtDoor → Done` is not
/// a client-patchable edge. Once the verified handover lands the row on `Done`
/// the screen routes to `feedback-rate-delivery` (the mandatory mutual rating,
/// JM-034 / D56).
class ActiveDeliveryJeeberScreen extends StatelessWidget {
  const ActiveDeliveryJeeberScreen({
    super.key,
    required this.deliveryId,
    required this.onOpenChat,
    this.onMarkedDelivered,
    this.onOpenOtp,
    this.onEnterGoodsCost,
    this.repository,
    this.photoPicker,
    this.cubit,
    this.mapsUrlBuilder,
    this.gpsUploader,
  });

  final String deliveryId;
  final VoidCallback onOpenChat;

  /// Sprint 2 Stream G: opens the goods-cost declaration for this delivery
  /// (the amount the Client reimburses on receipt, D11). Optional — when null
  /// the action button is hidden, so existing callers/tests are unaffected.
  final VoidCallback? onEnterGoodsCost;

  /// JM-051 AC2: fired once the delivery reaches `Done` — routes to
  /// `feedback-rate-delivery` (mutual rating, `mode=jeeber`). When null (route
  /// not yet rewired — see 50_ROUTE_REQUESTS.md JM-051) the done transition
  /// still completes; the rating chain lights up once the integrator wires it.
  final VoidCallback? onMarkedDelivered;

  /// DEPRECATED for JM-051: the legacy OTP-handover edge. The mark-delivered
  /// flow no longer routes to OTP (D56). Retained only so the existing route
  /// builder compiles until the integrator swaps it for [onMarkedDelivered].
  final VoidCallback? onOpenOtp;

  /// Injectable repo — production uses DI; tests supply a fake.
  final ActiveDeliveryRepository? repository;

  /// Injectable proof-photo camera picker (JEBV4-200) — production passes the
  /// real `image_picker` binding from DI; when null the cubit falls back to its
  /// canned-bytes stub (devtool/tests).
  final PhotoPickerService? photoPicker;

  /// Pre-built cubit — optional test seam.
  final ActiveDeliveryCubit? cubit;

  /// Override for url_launcher in tests.
  final Future<void> Function(String url)? mapsUrlBuilder;

  /// JEBV4-269: the jeeber's live-GPS uploader, handed in by the route builder
  /// (production). Ownership transfers to the [ActiveDeliveryCubit] built below,
  /// which starts it while the delivery is `InTransit` and closes it on dispose.
  /// Null in tests/devtool that seed their own [cubit] or don't exercise GPS.
  final BackgroundGpsCubit? gpsUploader;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider.value(
        value: provided,
        child: _Body(
          deliveryId: deliveryId,
          onOpenChat: onOpenChat,
          onMarkedDelivered: onMarkedDelivered,
          onEnterGoodsCost: onEnterGoodsCost,
          mapsUrlBuilder: mapsUrlBuilder,
        ),
      );
    }
    final repo = repository;
    if (repo == null) {
      return const _Unavailable();
    }
    return BlocProvider<ActiveDeliveryCubit>(
      create: (_) => ActiveDeliveryCubit(
        repository: repo,
        deliveryId: deliveryId,
        photoPicker: photoPicker,
        // b02 wave C / N6: the 5s LifecyclePoller is gone. A `type=delivery`
        // push re-reads the row, through the ONE existing resolver. The
        // `_ResumeRefresh` observer below stays as the dropped-push backstop.
        //
        // b02 wave D — `{order}`. This screen paints ONE delivery's lifecycle.
        // The jeeber is chatting with the customer while on it, so before the
        // topic filter every message the customer sent fired an extra
        // `GET /v1/deliveries/{id}` here.
        refreshSignals: resolvePushRefreshStream(
          topics: const {RefreshTopic.order},
        ),
        // JEBV4-269: stream the jeeber's GPS to the gateway while InTransit.
        gpsUploader: gpsUploader,
      )..loadDelivery(),
      child: _Body(
        deliveryId: deliveryId,
        onOpenChat: onOpenChat,
        onMarkedDelivered: onMarkedDelivered,
        onEnterGoodsCost: onEnterGoodsCost,
        mapsUrlBuilder: mapsUrlBuilder,
      ),
    );
  }
}

/// The Midnight page: transparent scaffold over the `content` field, its one
/// quiet glow anchored bottom-centre exactly where the board draws it.
class _Field extends StatelessWidget {
  const _Field({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: JeebMidnightField(
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.bottom,
        glowColor: context.jeebRoles.accent.withValues(alpha: _kFieldGlowAlpha),
        child: SafeArea(child: child),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Field(
      child: Column(
        children: [
          JeebTopBar.back(
            title: l10n.activeDeliveryTitle,
            identifier: 'mark_delivered_back',
          ),
          // mark_delivered_root is exposed even on the unavailable shell so a
          // cold deep-link / seam pin can still assert the screen rendered.
          Expanded(
            child: Semantics(
              identifier: 'mark_delivered_root',
              child: JeebStateHost(
                child: JeebEmptyState(
                  status: JeebEmptyStateStatus.error,
                  headline: l10n.activeDeliveryUnavailableHeadline,
                  body: l10n.activeDeliveryUnavailable,
                  identifier: 'active_delivery_unavailable',
                  action: JeebCtaFooter.single(
                    child: JeebCtaButton.primary(
                      label: l10n.actionBack,
                      identifier: 'active_delivery_exit_cta',
                      onTap: () => _popOrHome(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.deliveryId,
    required this.onOpenChat,
    this.onMarkedDelivered,
    this.onEnterGoodsCost,
    this.mapsUrlBuilder,
  });

  final String deliveryId;
  final VoidCallback onOpenChat;
  final VoidCallback? onMarkedDelivered;
  final VoidCallback? onEnterGoodsCost;
  final Future<void> Function(String url)? mapsUrlBuilder;

  @override
  Widget build(BuildContext context) {
    // JEBV4-282: force an immediate re-fetch when the app returns to the
    // foreground (the cubit's periodic poll timer is suspended while
    // backgrounded), so a stepper advanced server-side lands on resume.
    return _ResumeRefresh(
      child: BlocConsumer<ActiveDeliveryCubit, ActiveDeliveryState>(
        listener: _onStateChange,
        builder: _buildScaffold,
      ),
    );
  }

  void _onStateChange(BuildContext context, ActiveDeliveryState state) {
    final kind = state.transitionErrorKind;
    if (kind != null) {
      final l10n = AppLocalizations.of(context);
      final String? copy = _localizedTransitionError(l10n, kind);
      if (copy != null) {
        showJeebErrorSnack(
          context,
          message: copy,
          identifier: 'active_delivery_transition_error',
        );
      } else {
        showJeebErrorSnack(
          context,
          failure: activeDeliveryFailureOf(kind),
          identifier: 'active_delivery_transition_error',
        );
      }
      context.read<ActiveDeliveryCubit>().acknowledgeTransitionError();
    }
    final photoFailure = state.proofPhotoFailure;
    if (photoFailure != null &&
        state.proofPhotoStatus == ProofPhotoStatus.failed) {
      final l10n = AppLocalizations.of(context);
      showJeebErrorSnack(
        context,
        message: photoFailure == PhotoPickFailure.permissionDenied
            ? l10n.activeDeliveryProofPhotoPermission
            : l10n.activeDeliveryProofPhotoUnavailable,
        identifier: 'active_delivery_proof_photo_error',
      );
      context.read<ActiveDeliveryCubit>().acknowledgeProofPhotoFailure();
    }
    // JM-051 AC2: done → mandatory rating (NOT OTP). One-shot signal.
    if (state.delivered) {
      context.read<ActiveDeliveryCubit>().acknowledgeDelivered();
      onMarkedDelivered?.call();
    }
  }

  /// P6/B4: maps the typed failure onto its own localized string. Returns null
  /// for kinds that never surface here (they render the cubit fallback).
  String? _localizedTransitionError(
    AppLocalizations l10n,
    ActiveDeliveryFailure? kind,
  ) => switch (kind) {
    ActiveDeliveryFailure.invalidTransition =>
      l10n.activeDeliveryErrorInvalidTransition,
    ActiveDeliveryFailure.badRequest => l10n.activeDeliveryErrorBadRequest,
    ActiveDeliveryFailure.network => l10n.activeDeliveryErrorNetwork,
    ActiveDeliveryFailure.otpRequired => l10n.activeDeliveryErrorOtpNeeded,
    ActiveDeliveryFailure.server => l10n.activeDeliveryErrorGeneric,
    ActiveDeliveryFailure.invalidOtp => l10n.errorInvalidCode,
    ActiveDeliveryFailure.otpLocked => l10n.otpHandoverLockedBody,
    ActiveDeliveryFailure.notFound => l10n.errorNotFoundBody,
    ActiveDeliveryFailure.otpCodeRequired =>
      l10n.activeDeliveryOtpCodeTooShort,
    _ => null,
  };

  Widget _buildScaffold(BuildContext context, ActiveDeliveryState state) {
    final l10n = AppLocalizations.of(context);
    return _Field(
      // mark_delivered_root (JM-051) — root of the active-delivery /
      // mark-delivered screen, asserted on first frame by the seam route pin.
      child: Semantics(
        identifier: 'mark_delivered_root',
        explicitChildNodes: true,
        // The bar is hoisted ABOVE the mode switch on purpose: loading, error
        // and terminal all used to inherit it from `appBar:`, and an in-body
        // bar built inside the ready branch would leave those three modes with
        // no title and no way back.
        child: Column(
          children: [
            JeebTopBar.back(
              title: _titleForState(l10n, state),
              identifier: 'mark_delivered_back',
            ),
            Expanded(child: _buildBody(context, state, l10n)),
          ],
        ),
      ),
    );
  }

  String _titleForState(AppLocalizations l10n, ActiveDeliveryState state) {
    final status = state.delivery?.status;
    if (state.mode == ActiveDeliveryMode.transitioning || status == null) {
      return l10n.activeDeliveryTitle;
    }
    return switch (status) {
      JeeberDeliveryStatus.done => l10n.deliveryCompletedBanner,
      JeeberDeliveryStatus.cancelled => l10n.activeDeliveryCancelledTitle,
      JeeberDeliveryStatus.expired => l10n.activeDeliveryExpiredTitle,
      JeeberDeliveryStatus.disputed => l10n.activeDeliveryDisputedTitle,
      _ => l10n.activeDeliveryTitle,
    };
  }

  Widget _buildBody(
    BuildContext context,
    ActiveDeliveryState state,
    AppLocalizations l10n,
  ) {
    switch (state.mode) {
      case ActiveDeliveryMode.loading:
        return JeebStateHost(
          child: JeebEmptyState(
            status: JeebEmptyStateStatus.loading,
            headline: l10n.activeDeliveryLoadingHeadline,
            identifier: 'active_delivery_loading',
          ),
        );
      case ActiveDeliveryMode.error:
        return JeebStateHost(
          child: JeebFailureBlock(
            failure: activeDeliveryFailureOf(state.loadFailureKind),
            identifier: 'active_delivery_error',
            onRetry: () => context.read<ActiveDeliveryCubit>().loadDelivery(),
            onExit: () => _popOrHome(context),
          ),
        );
      case ActiveDeliveryMode.ready:
      case ActiveDeliveryMode.transitioning:
        final delivery = state.delivery;
        if (delivery == null) return const SizedBox.shrink();
        return _ReadyContent(
          state: state,
          delivery: delivery,
          onAdvance: () => context.read<ActiveDeliveryCubit>().advanceStatus(),
          onCaptureProof: () =>
              context.read<ActiveDeliveryCubit>().captureProofPhoto(),
          onNoteChanged: (v) => context.read<ActiveDeliveryCubit>().setNote(v),
          onMarkDelivered: () =>
              context.read<ActiveDeliveryCubit>().markDelivered(),
          // iter6 close-tail: submit the recipient door OTP to complete the
          // phone-bearing delivery `AtDoor → Done` (then the rating chain fires).
          onSubmitOtp: (code) =>
              context.read<ActiveDeliveryCubit>().submitDoorOtp(code),
          onOpenChat: onOpenChat,
          onOpenMaps: () => _launchMaps(delivery),
          // P0 (live tracking): the two recovery affordances behind the
          // background-location banner.
          onOpenGpsSettings: () =>
              context.read<ActiveDeliveryCubit>().openGpsSettings(),
          onResumeGps: () => context.read<ActiveDeliveryCubit>().resumeGps(),
          onDismissRefreshFailure: () => context
              .read<ActiveDeliveryCubit>()
              .acknowledgeRefreshFailure(),
          onRetryRefresh: () => context.read<ActiveDeliveryCubit>().refresh(),
          onRetryGpsPermission: () =>
              context.read<ActiveDeliveryCubit>().retryGpsPermission(),
          onEnterGoodsCost: onEnterGoodsCost,
          l10n: l10n,
        );
    }
  }

  Future<void> _launchMaps(JeeberDelivery delivery) async {
    final lat = delivery.dropOff.lat;
    final lng = delivery.dropOff.lng;
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    final launch = mapsUrlBuilder;
    if (launch != null) {
      await launch(url);
    }
    // Production: url_launcher.launchUrl called from the router/page.
  }
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    required this.state,
    required this.delivery,
    required this.onAdvance,
    required this.onCaptureProof,
    required this.onNoteChanged,
    required this.onMarkDelivered,
    required this.onSubmitOtp,
    required this.onOpenChat,
    required this.onOpenMaps,
    required this.onOpenGpsSettings,
    required this.onRetryGpsPermission,
    required this.onResumeGps,
    required this.onDismissRefreshFailure,
    required this.onRetryRefresh,
    required this.l10n,
    this.onEnterGoodsCost,
  });

  final ActiveDeliveryState state;
  final JeeberDelivery delivery;
  final VoidCallback onAdvance;
  final VoidCallback onCaptureProof;
  final ValueChanged<String> onNoteChanged;
  final VoidCallback onMarkDelivered;
  final ValueChanged<String> onSubmitOtp;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenMaps;

  /// [GpsPermissionBanner] CTA — opens the app's OS settings page.
  final VoidCallback onOpenGpsSettings;

  /// [GpsPermissionBanner] CTA — re-runs the in-app permission escalation.
  final VoidCallback onRetryGpsPermission;

  /// Re-arms an uploader that tore itself down after repeated failures.
  final VoidCallback onResumeGps;

  /// Clears `refreshFailure`; the rows stay on screen.
  final VoidCallback onDismissRefreshFailure;

  /// Re-runs the warm refresh behind the strip.
  final VoidCallback onRetryRefresh;

  final VoidCallback? onEnterGoodsCost;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (delivery.status.isUnsuccessfulTerminal) {
      return _UnsuccessfulTerminalContent(status: delivery.status, l10n: l10n);
    }
    // JM-051: the mark-delivered panel is surfaced during the delivering phase
    // (InTransit or AtDoor) — the seam seeds `jeeber_active_delivery` at
    // InTransit, and the flow asserts the panel on first frame. P6/B1:
    // `markDelivered` walks the SM-1 forward steps only up to AtDoor (stamping
    // the proof evidenceUrl on that last patched step) and then hands over to
    // the door OTP, which is what completes the row to Done.
    final showMarkDelivered =
        delivery.status == JeeberDeliveryStatus.inTransit ||
        delivery.status == JeeberDeliveryStatus.atDoor;
    // Core Flow step 7 (jeeber terminal): once the handover OTP completes the
    // delivery to V3 `Done`, render an explicit delivered/completed final state
    // so a re-entry / poll-update lands on a clear terminal UI (not a stale
    // "advance" affordance). Gated on !isTransitioning so an OPTIMISTIC
    // AtDoor→Done still awaiting server/OTP confirmation does not flash the
    // "Delivered" panel prematurely (JEBV4-276) — the OTP path reverts to
    // AtDoor and surfaces the OTP entry instead.
    final isCompleted =
        delivery.status == JeeberDeliveryStatus.done && !state.isTransitioning;
    final copy = ActiveDeliveryJeeberL10n.of(context);
    // R1: the stepper is pinned under the bar, the cards scroll between it and
    // the docked footer, and the bottom ~40% of the board stays white. Never a
    // Spacer between the cards and never a centred column — the content is
    // top-aligned and the emptiness underneath is the design.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.xLarge,
            Spacing.medium,
            Spacing.xLarge,
            0,
          ),
          child: DeliveryStatusStepper(
            currentStatus: delivery.status,
            isTransitioning: state.isTransitioning,
            onAdvance: onAdvance,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Spacing.xLarge,
              Spacing.medium,
              Spacing.xLarge,
              Spacing.medium,
            ),
            children: [
              // A warm poll failed while these rows stayed up (F28): the strip
              // says so instead of the refresh failing silently.
              if (state.refreshFailure != null) ...[
                JeebRefreshFailedNote(
                  failure: activeDeliveryFailureOf(state.refreshFailure),
                  identifier: 'active_delivery_refresh_failed',
                  onDismiss: onDismissRefreshFailure,
                  onRetry: onRetryRefresh,
                ),
                const SizedBox(height: Spacing.small),
              ],
              // P0 (live tracking): FIRST item, above everything, whenever the
              // GPS uploader is parked on a missing background-location grant.
              // While this is visible the customer's tracking map is empty and
              // only the jeeber can fix it — the previous behaviour was to show
              // nothing at all and let the delivery run blind. Not dismissible,
              // by design.
              if (state.isGpsBlocked) ...[
                GpsPermissionBanner(
                  needsSystemSettings: state.gpsNeedsSystemSettings,
                  onOpenSettings: onOpenGpsSettings,
                  onRetry: onRetryGpsPermission,
                ),
                const SizedBox(height: Spacing.small),
              ] else if (state.gpsPhase == BackgroundGpsPhase.error) ...[
                // The uploader tore itself down after repeated failures and
                // nothing rendered that before: the delivery ran blind.
                JeebInfoNote.error(
                  title: l10n.activeDeliveryGpsStoppedTitle,
                  text: l10n.activeDeliveryGpsStoppedBody,
                  identifier: 'active_delivery_gps_stopped',
                  trailing: JeebCtaButton.outline(
                    label: l10n.activeDeliveryGpsStoppedRetry,
                    identifier: 'active_delivery_gps_resume_cta',
                    expand: false,
                    onTap: onResumeGps,
                  ),
                ),
                const SizedBox(height: Spacing.small),
              ],
              if (isCompleted) ...[
                _CompletedPanel(l10n: l10n),
                const SizedBox(height: Spacing.small),
              ],
              _AddressCard(delivery: delivery, l10n: l10n, copy: copy),
              // JM-051 AC1/AC2: the handoff card — proof photo (D3), optional
              // note, and either the CTA or the door-code block.
              if (showMarkDelivered) ...[
                const SizedBox(height: Spacing.small),
                MarkDeliveredPanel(
                  delivery: delivery,
                  proofPhotoStatus: state.proofPhotoStatus,
                  proofPhotoBytes: state.proofPhotoBytes,
                  isMarking: state.isTransitioning,
                  onCaptureProof: onCaptureProof,
                  onNoteChanged: onNoteChanged,
                  onMarkDelivered: onMarkDelivered,
                  // iter6 close-tail: surface the door-OTP entry when the
                  // gateway demands the recipient code for `AtDoor → Done`.
                  otpRequired: state.otpRequired,
                  isVerifyingOtp: state.isVerifyingOtp,
                  otpErrorKind: state.otpErrorKind,
                  otpAttemptsRemaining: state.otpAttemptsRemaining,
                  onSubmitOtp: onSubmitOtp,
                  l10n: l10n,
                ),
              ],
            ],
          ),
        ),
        _QuickActionFooter(
          onOpenMaps: onOpenMaps,
          onOpenChat: onOpenChat,
          onEnterGoodsCost: onEnterGoodsCost,
          l10n: l10n,
          copy: copy,
        ),
      ],
    );
  }
}

/// Neutral terminal treatment for deliveries that did not complete
/// successfully. Mirrors the existing live-tracking cancelled-state precedent:
/// an [OmdsEmptyState], with no success banner, progress stepper, or delivery
/// actions. Cancellation, expiry, and dispute remain visually and semantically
/// distinguishable.
class _UnsuccessfulTerminalContent extends StatelessWidget {
  const _UnsuccessfulTerminalContent({
    required this.status,
    required this.l10n,
  });

  final JeeberDeliveryStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: _identifier,
      container: true,
      child: ListView(
        padding: const EdgeInsets.all(Spacing.large),
        children: [
          JeebEmptyState(
            key: ValueKey<String>(_identifier),
            variant: JeebEmptyStateVariant.street,
            headline: _title,
            body: _body,
          ),
        ],
      ),
    );
  }

  String get _identifier => switch (status) {
    JeeberDeliveryStatus.cancelled => 'delivery_cancelled_state',
    JeeberDeliveryStatus.expired => 'delivery_expired_state',
    JeeberDeliveryStatus.disputed => 'delivery_disputed_state',
    _ => throw StateError('Expected an unsuccessful terminal status'),
  };

  String get _title => switch (status) {
    JeeberDeliveryStatus.cancelled => l10n.activeDeliveryCancelledTitle,
    JeeberDeliveryStatus.expired => l10n.activeDeliveryExpiredTitle,
    JeeberDeliveryStatus.disputed => l10n.activeDeliveryDisputedTitle,
    _ => throw StateError('Expected an unsuccessful terminal status'),
  };

  String get _body => switch (status) {
    JeeberDeliveryStatus.cancelled => l10n.activeDeliveryCancelledBody,
    JeeberDeliveryStatus.expired => l10n.activeDeliveryExpiredBody,
    JeeberDeliveryStatus.disputed => l10n.activeDeliveryDisputedBody,
    _ => throw StateError('Expected an unsuccessful terminal status'),
  };
}

/// `delivery_completed_state` — the jeeber-side delivered/completed terminal
/// panel (Core Flow step 7). Shown once the delivery reaches V3 `Done`. Carries
/// a stable Semantics identifier so a UI driver can assert the terminal state.
class _CompletedPanel extends StatelessWidget {
  const _CompletedPanel({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'delivery_completed_state',
      container: true,
      label: l10n.deliveryCompletedBanner,
      // Success, not "primary": a completed delivery is a green outcome, and
      // primaryContainer here rendered the same navy as an active affordance.
      child: JeebInfoNote.success(
        icon: Icons.check_circle,
        text: l10n.deliveryCompletedBanner,
      ),
    );
  }
}

/// The drop-off card (`tpl 1057-1062`). MIDNIGHT draws pin + address + collect
/// line and NO trailing circle — the docked `Maps` pill owns that action.
class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.delivery,
    required this.l10n,
    required this.copy,
  });

  final JeeberDelivery delivery;
  final AppLocalizations l10n;
  final ActiveDeliveryJeeberL10n copy;

  @override
  Widget build(BuildContext context) {
    final mutedText = jeebMutedInk(context);
    // Run-22 P1-A: never fabricate an amount. `?? \'\'` used to render
    // "Pay  cash to ..." on a snapshot with no amount, and the old party
    // fallback addressed the *address* as the payer.
    final amount = delivery.amountText;
    final cash = amount == null || amount.isEmpty
        ? copy.collectCashNoAmount
        : copy.collectCash(amount);
    final detail = delivery.dropOff.detail;
    final line = detail == null ? cash : '$detail \u00b7 $cash';
    // TODO(redesign-24): the board's collect line splits fee and goods cost
    // ("$8 + $6.50 goods"). `JeeberDelivery` carries `amountText` only and no
    // gateway field exposes the goods cost here — omitted, not faked.
    return JeebOutlinedCard(
      padding: _kDropOffCardPadding,
      semanticLabel: l10n.activeDeliveryDropOffLabel,
      child: Row(
        children: [
          // MIDNIGHT measures the pin at `#FF5252` — the board's danger red,
          // which IS a token. Pass-1's orange stand-in also spent the budget.
          Icon(
            Icons.location_on,
            color: Theme.of(context).colorScheme.error,
            size: Sizes.large,
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delivery.dropOff.label,
                  style: context.jeebText.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // `mark_delivered_cash_note` re-homes here from the deleted
                // slab: the cash instruction belongs next to the address it
                // qualifies. Still emitted at InTransit (Maestro jm-051).
                Semantics(
                  identifier: 'mark_delivered_cash_note',
                  child: Text(
                    line,
                    style: context.jeebText.bodySmall.copyWith(
                      color: mutedText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One footer pill. The `Semantics(identifier:, container:, button:)` wrapper is
/// the shipped idiom and stays; the long localized sentence moves onto the
/// button's own node so the board's one-word label never reaches TalkBack bare.
///
/// MIDNIGHT draws these as **label-only** glass pills — the pass-1 glyphs are
/// gone, which also retires the queued `Icons.map` → `Icons.directions` swap.
class _QuickActionPill extends StatelessWidget {
  const _QuickActionPill({
    required this.identifier,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  final String identifier;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      container: true,
      button: true,
      child: JeebCtaButton.outline(
        label: label,
        semanticLabel: semanticLabel,
        height: JeebCtaButton.outlineHeight,
        onTap: onTap,
      ),
    );
  }
}

/// The docked 3-pill footer (`tpl 1085-1092`).
///
/// Screen-local on purpose: this row shape exists on 18 only, so a kit footer
/// variant would have exactly one consumer.
class _QuickActionFooter extends StatelessWidget {
  const _QuickActionFooter({
    required this.onOpenMaps,
    required this.onOpenChat,
    required this.l10n,
    required this.copy,
    this.onEnterGoodsCost,
  });

  final VoidCallback onOpenMaps;
  final VoidCallback onOpenChat;
  final VoidCallback? onEnterGoodsCost;
  final AppLocalizations l10n;
  final ActiveDeliveryJeeberL10n copy;

  @override
  Widget build(BuildContext context) {
    final enterGoodsCost = onEnterGoodsCost;
    final pills = <Widget>[
      _QuickActionPill(
        identifier: 'mark_delivered_open_maps_cta',
        label: copy.quickActionMaps,
        semanticLabel: l10n.activeDeliveryOpenMapsButton,
        onTap: onOpenMaps,
      ),
      _QuickActionPill(
        identifier: 'mark_delivered_open_chat_cta',
        label: copy.quickActionChat,
        semanticLabel: l10n.activeDeliveryOpenChatButton,
        onTap: onOpenChat,
      ),
      // TODO(midnight): the tile draws this third pill, but `GoodsCostScreen`
      // has no route, so production still renders two — owner Q7 pending.
      if (enterGoodsCost != null)
        _QuickActionPill(
          identifier: 'mark_delivered_goods_cost_cta',
          label: copy.quickActionCosts,
          semanticLabel: l10n.activeDeliveryEnterGoodsCostButton,
          onTap: enterGoodsCost,
        ),
    ];
    return Padding(
      // The board draws 30 at the bottom; 32 is the rung and the
      // 02-PLAN-ENHANCED §3.2 resolution. Noted divergence.
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        0,
        Spacing.xLarge,
        Spacing.twoXLarge,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackActions =
              constraints.maxWidth < _kInlineQuickActionsMinWidth ||
              MediaQuery.textScalerOf(context).scale(Spacing.medium) >
                  Spacing.large;
          if (stackActions) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var index = 0; index < pills.length; index++) ...[
                  if (index > 0) const SizedBox(height: Spacing.small),
                  pills[index],
                ],
              ],
            );
          }
          return Row(
            children: <Widget>[
              for (var index = 0; index < pills.length; index++) ...[
                if (index > 0) const SizedBox(width: Spacing.small),
                Expanded(child: pills[index]),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// JEBV4-282: re-fetches the active delivery when the app returns to the
/// foreground. Mounted between the [ActiveDeliveryCubit] provider and the body,
/// so its [State] resolves the cubit via `context.read`. The cubit's periodic
/// poll keeps the stepper fresh while the screen is on-screen; this covers the
/// gap where the OS suspends Dart timers in the background (a delivery advanced
/// server-side while backgrounded surfaces immediately on resume). Outside a
/// lifecycle event it is a transparent pass-through.
class _ResumeRefresh extends StatefulWidget {
  const _ResumeRefresh({required this.child});

  final Widget child;

  @override
  State<_ResumeRefresh> createState() => _ResumeRefreshState();
}

class _ResumeRefreshState extends State<_ResumeRefresh>
    with ResumeRefetchMixin {
  /// b02 P0 — this used to own a binding observer and fire on EVERY `resumed`
  /// notification. It was one of the three surfaces in the measured 60-read
  /// storm (`/v1/deliveries/{id}`, seq 59..116, the last one a 429), and
  /// `ActiveDeliveryCubit.refresh`'s in-flight latch did not collapse a single
  /// one of them: the reads were ~20 ms apart in duration but ~105 ms apart in
  /// time, so they never overlapped. The rate floor lives in
  /// [AppResumeSignals]; the latch stays as the concurrency guard it always was.
  ///
  /// Called directly, NOT via `addPostFrameCallback`. The old hook deferred to
  /// the next frame for teardown safety, which [ResumeRefetchMixin]'s
  /// `mounted` guard already provides — and the deferral was load-bearing in
  /// the wrong direction: a post-frame callback registered while the scheduler
  /// is idle does not itself schedule a frame, so the refetch waits for
  /// whatever schedules the next one. On a quiescent screen (this one, once the
  /// poll was deleted) that is nothing at all.
  @override
  void onAppResumed() {
    final cubit = context.read<ActiveDeliveryCubit>();
    cubit.refresh();
    // P0 (live tracking): re-read the location permission on resume. The ONLY
    // way to reach "Allow all the time" on Android 11+ is the OS settings page,
    // which necessarily backgrounds the app — so without this the jeeber grants
    // the permission, returns, and the banner is still there and the uploader
    // is still parked, because nothing re-asked. Guarded on the parked phase so
    // an ordinary resume never re-prompts a healthy delivery.
    if (cubit.state.isGpsBlocked) cubit.retryGpsPermission();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The copy-family failure an [ActiveDeliveryFailure] renders as. Shared with
/// the fixtures and the tests so one mapping is asserted, not three.
AppFailure activeDeliveryFailureOf(ActiveDeliveryFailure? kind) =>
    switch (kind) {
      ActiveDeliveryFailure.network => networkFailureFromReachability(),
      ActiveDeliveryFailure.notFound => const NotFoundFailure(),
      ActiveDeliveryFailure.otpLocked => const ForbiddenFailure(),
      ActiveDeliveryFailure.invalidOtp ||
      ActiveDeliveryFailure.otpCodeRequired ||
      ActiveDeliveryFailure.badRequest ||
      ActiveDeliveryFailure.invalidTransition ||
      ActiveDeliveryFailure.otpRequired => const ValidationFailure(),
      ActiveDeliveryFailure.server => const ServerFailure(status: 500),
      null => const UnknownFailure(),
    };

/// Exit that survives a deep-link root: `maybePop` alone is a silent no-op
/// when this screen IS the stack, which is exactly the 404/403 case.
void _popOrHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}
