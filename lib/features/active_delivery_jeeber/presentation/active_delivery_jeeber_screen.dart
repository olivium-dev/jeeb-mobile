import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/lifecycle/app_resume_signals.dart';
import '../../../l10n/app_localizations.dart';
import '../../background_gps/application/background_gps_cubit.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../application/active_delivery_cubit.dart';
import '../domain/active_delivery_repository.dart';
import '../domain/jeeber_delivery.dart';
import '../domain/jeeber_delivery_status.dart';
import 'widgets/delivery_status_stepper.dart';
import 'widgets/gps_permission_banner.dart';
import 'widgets/mark_delivered_panel.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/active_delivery_jeeber_screen_fixtures.dart';

/// Minimum width needed to keep the two quick actions on one row without
/// truncating their localized labels at the default text scale.
const double _kInlineQuickActionsMinWidth = 448;

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

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(title: l10n.activeDeliveryTitle),
      // mark_delivered_root is exposed even on the unavailable shell so a cold
      // deep-link / seam pin can still assert the screen rendered.
      body: Semantics(
        identifier: 'mark_delivered_root',
        child: Center(child: Text(l10n.activeDeliveryUnavailable)),
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
    final raw = state.transitionError;
    if (raw != null) {
      // EXEMPT: OMDS exports no standalone toast/snackbar widget; ScaffoldMessenger
      // + showOmdsSnackbar is the approved fleet pattern for transient feedback.
      // P6/B4: prefer the kind-specific LOCALIZED copy; the cubit's English
      // literal is only the fallback for an unclassified failure.
      final l10n = AppLocalizations.of(context);
      showOmdsSnackbar(
        context,
        message: _localizedTransitionError(l10n, state.transitionErrorKind) ??
            raw,
      );
      context.read<ActiveDeliveryCubit>().acknowledgeTransitionError();
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
  ) =>
      switch (kind) {
        ActiveDeliveryFailure.invalidTransition =>
          l10n.activeDeliveryErrorInvalidTransition,
        ActiveDeliveryFailure.badRequest => l10n.activeDeliveryErrorBadRequest,
        ActiveDeliveryFailure.network => l10n.activeDeliveryErrorNetwork,
        ActiveDeliveryFailure.otpRequired =>
          l10n.activeDeliveryErrorOtpNeeded,
        ActiveDeliveryFailure.server => l10n.activeDeliveryErrorGeneric,
        _ => null,
      };

  Widget _buildScaffold(BuildContext context, ActiveDeliveryState state) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(title: l10n.activeDeliveryTitle, showBackButton: true),
      // mark_delivered_root (JM-051) — root of the active-delivery /
      // mark-delivered screen, asserted on first frame by the seam route pin.
      body: Semantics(
        identifier: 'mark_delivered_root',
        explicitChildNodes: true,
        child: _buildBody(context, state, l10n),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ActiveDeliveryState state,
    AppLocalizations l10n,
  ) {
    switch (state.mode) {
      case ActiveDeliveryMode.loading:
        return const Center(child: OmdsLoadingState());
      case ActiveDeliveryMode.error:
        return OmdsErrorState(
          message: state.errorMessage ?? l10n.activeDeliveryLoadError,
          onRetry: () => context.read<ActiveDeliveryCubit>().loadDelivery(),
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
    return ListView(
      padding: const EdgeInsets.all(Spacing.medium),
      children: [
        // P0 (live tracking): FIRST item, above everything, whenever the GPS
        // uploader is parked on a missing background-location grant. While this
        // is visible the customer's tracking map is empty and only the jeeber
        // can fix it — the previous behaviour was to show nothing at all and
        // let the delivery run blind. Not dismissible, by design.
        if (state.isGpsBlocked) ...[
          GpsPermissionBanner(
            needsSystemSettings: state.gpsNeedsSystemSettings,
            onOpenSettings: onOpenGpsSettings,
            onRetry: onRetryGpsPermission,
          ),
          const SizedBox(height: Spacing.large),
        ],
        if (isCompleted) ...[
          _CompletedPanel(l10n: l10n),
          const SizedBox(height: Spacing.large),
        ],
        _AddressCard(delivery: delivery, l10n: l10n),
        const SizedBox(height: Spacing.large),
        OMDSSectionCard(
          title: l10n.activeDeliveryProgressTitle,
          showDivider: false,
          content: DeliveryStatusStepper(
            currentStatus: delivery.status,
            isTransitioning: state.isTransitioning,
            onAdvance: onAdvance,
          ),
        ),
        const SizedBox(height: Spacing.large),
        // JM-051 AC1/AC2: surface the mark-delivered panel — proof photo (D3)
        // + optional note + cash-receipt copy (D11) + the CTA.
        if (showMarkDelivered) ...[
          MarkDeliveredPanel(
            delivery: delivery,
            proofPhotoStatus: state.proofPhotoStatus,
            proofPhotoBytes: state.proofPhotoBytes,
            isMarking: state.isTransitioning,
            onCaptureProof: onCaptureProof,
            onNoteChanged: onNoteChanged,
            onMarkDelivered: onMarkDelivered,
            // iter6 close-tail: surface the door-OTP entry when the gateway
            // demands the recipient code to complete `AtDoor → Done`.
            otpRequired: state.otpRequired,
            isVerifyingOtp: state.isVerifyingOtp,
            otpError: state.otpError,
            onSubmitOtp: onSubmitOtp,
            l10n: l10n,
          ),
          const SizedBox(height: Spacing.large),
        ],
        _ActionButtons(
          onOpenMaps: onOpenMaps,
          onOpenChat: onOpenChat,
          onEnterGoodsCost: onEnterGoodsCost,
          l10n: l10n,
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
          OmdsEmptyState(
            key: ValueKey<String>(_identifier),
            icon: _icon,
            title: _title,
            subtitle: _body,
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

  IconData get _icon => switch (status) {
    JeeberDeliveryStatus.cancelled => Icons.cancel_outlined,
    JeeberDeliveryStatus.expired => Icons.timer_off_outlined,
    JeeberDeliveryStatus.disputed => Icons.report_problem_outlined,
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
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'delivery_completed_state',
      container: true,
      label: l10n.deliveryCompletedBanner,
      child: Container(
        padding: const EdgeInsets.all(Spacing.medium),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: OmdsBorderRadius.medium,
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: theme.colorScheme.onPrimaryContainer,
              size: Sizes.large,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Text(
                l10n.deliveryCompletedBanner,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.delivery, required this.l10n});

  final JeeberDelivery delivery;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return OMDSSectionCard(
      title: l10n.activeDeliveryDropOffLabel,
      showDivider: false,
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.location_on_outlined,
            color: colorScheme.primary,
            size: Sizes.xLarge,
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delivery.dropOff.label,
                  style: theme.textTheme.titleMedium,
                ),
                if (delivery.dropOff.detail != null) ...[
                  const SizedBox(height: Spacing.xSmall),
                  Text(
                    delivery.dropOff.detail!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.identifier,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String identifier;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: identifier,
      container: true,
      button: true,
      child: OmdsPrimaryButton(
        text: label,
        variant: OmdsButtonVariant.outlined,
        icon: Icon(icon, color: colorScheme.primary),
        onTap: onTap,
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onOpenMaps,
    required this.onOpenChat,
    required this.l10n,
  });

  final VoidCallback onOpenMaps;
  final VoidCallback onOpenChat;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final maps = _QuickAction(
      identifier: 'mark_delivered_open_maps_cta',
      label: l10n.activeDeliveryOpenMapsButton,
      icon: Icons.map_outlined,
      onTap: onOpenMaps,
    );
    final chat = _QuickAction(
      identifier: 'mark_delivered_open_chat_cta',
      label: l10n.activeDeliveryOpenChatButton,
      icon: Icons.chat_bubble_outline,
      onTap: onOpenChat,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackActions =
            constraints.maxWidth < _kInlineQuickActionsMinWidth ||
            MediaQuery.textScalerOf(context).scale(Spacing.medium) >
                Spacing.large;
        if (stackActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              maps,
              const SizedBox(height: Spacing.small),
              chat,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: maps),
            const SizedBox(width: Spacing.small),
            Expanded(child: chat),
          ],
        );
      },
    );
  }
}

class _GoodsCostAction extends StatelessWidget {
  const _GoodsCostAction({required this.onTap, required this.l10n});

  final VoidCallback onTap;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return _QuickAction(
      identifier: 'mark_delivered_goods_cost_cta',
      label: l10n.activeDeliveryEnterGoodsCostButton,
      icon: Icons.receipt_long_outlined,
      onTap: onTap,
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onOpenMaps,
    required this.onOpenChat,
    required this.l10n,
    this.onEnterGoodsCost,
  });

  final VoidCallback onOpenMaps;
  final VoidCallback onOpenChat;
  final VoidCallback? onEnterGoodsCost;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final enterGoodsCost = onEnterGoodsCost;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuickActions(
          onOpenMaps: onOpenMaps,
          onOpenChat: onOpenChat,
          l10n: l10n,
        ),
        // Sprint 2 Stream G: goods-cost entry point (D11). Only shown when the
        // caller wired the navigation closure — keeps existing tests/callers
        // (which omit it) rendering exactly the prior two buttons.
        if (enterGoodsCost != null) ...[
          const SizedBox(height: Spacing.small),
          _GoodsCostAction(onTap: enterGoodsCost, l10n: l10n),
        ],
      ],
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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests:
// test/previews/active_delivery_jeeber/active_delivery_jeeber_screen_preview_test.dart
// ===========================================================================
//
// [ActiveDeliveryJeeberScreen] has exactly ONE axis: the [ActiveDeliveryState]
// its cubit holds. Every preview below is that state and nothing else — the
// screen reads no other source, and `_ReadyContent` is a pure function of the
// state plus the localizations.
//
// The states are NOT declared here. They live in
// `lib/devtool/catalog/fixtures/active_delivery_jeeber_screen_fixtures.dart`,
// shared with the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_01_entries.dart`), so the designer's browser
// and this canvas name the same states with the same data. The first four —
// in transit, at door, delivered, load failed — are the catalog's, moved
// verbatim; the rest are new and previewed here first.
//
// Three things about this harness are worth knowing before editing it:
//
//  * **Every state is EMITTED, never fetched.** The screen takes both seams
//    (`repository:` and `cubit:`) and they are not equivalent: a canned
//    repository can only produce what `loadDelivery()` produces, which is two
//    of the fourteen states below. [ActiveDeliveryJeeberScreenSeededCubit]
//    emits the designed state directly and the repository under it throws on
//    every method, so nothing can reach a gateway even in principle — network-
//    free by construction, not by the [CatalogNetworkGuard] in
//    [jeebPreviewHost]. No `gpsUploader` is wired either; the two fields the
//    banner needs are mirrored into the state, which is what makes the parked-
//    GPS states previewable at all.
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and this
//    screen's `Scaffold + OMDSAppBar` paints inside it — the same nesting the
//    Screen Catalog produces. The frame is therefore pinned in the TREE as well
//    as in `size:`, because an unpinned screen is 800 pt wide in the render
//    tests and none of the layout under review applies there. (The render
//    surface is 800x600, so the phone box's 844 is clamped to what the host
//    has; the compact 320x568 box fits and is exact.)
//  * **The ticker is muted.** [_activeDeliveryJeeberScreenFramed] wraps every
//    state in `TickerMode(enabled: false)`. The loading state paints
//    [OmdsLoadingState], an indeterminate `CircularProgressIndicator` that
//    never stops scheduling frames, and the door-OTP entry autofocuses its
//    first cell, which starts a blinking cursor and asks the enclosing
//    `ListView` to reveal it — `pumpAndSettle` in the render tests would hang
//    on either. A still preview wants a still spinner anyway.
//
// What these previews were written to make visible:
//
//  * **With neither seam wired the screen is a DEAD END.**
//    [activeDeliveryJeeberScreenUnavailable] is what `build` returns when
//    `cubit` and `repository` are both null: an app bar and the single sentence
//    "Delivery details unavailable." No retry, no reload, no route out, and no
//    hint that the jeeber is one route-builder bug away from being unable to
//    complete a delivery they are physically standing at the door of. It keeps
//    the `mark_delivered_root` identifier, so a flow that only asserts the seam
//    pin passes on this surface.
//  * **The loading state has NO TEXT AT ALL.** A bare centred spinner: no
//    title, no "loading your delivery", nothing for a screen reader to
//    announce and nothing to cancel. It is also the state a cold deep-link
//    from a `type=delivery` push opens on.
//  * **`Done` + in-flight must NOT flash the delivered banner** (JEBV4-276).
//    [activeDeliveryJeeberScreenCompletingOptimistically] is the frame between
//    the optimistic emit and the server's verdict, and the OTP path REVERTS
//    from exactly there back to `AtDoor`. If that preview ever paints
//    "Delivered successfully" next to a spinner, the `!state.isTransitioning`
//    guard on `isCompleted` has been dropped and the jeeber is being told the
//    handover succeeded before anything confirmed it.
//  * **The GPS park was invisible for months.** The uploader parked on a
//    missing `ACCESS_BACKGROUND_LOCATION` grant on every delivery and NOTHING
//    on this screen said so, while the customer's tracking map stayed empty.
//    The two banner states are previewed side by side because the CTA is the
//    load-bearing half: Android 11+ grants "Allow all the time" only from the
//    OS settings page, so "Allow location" on a permanently denied device
//    would fire a request the platform silently drops.
//  * **Three unsuccessful terminals, one code path.** Cancelled, expired and
//    disputed all render `_UnsuccessfulTerminalContent`, and the ONLY
//    difference is the icon and two strings — worth seeing next to each other,
//    because it is also where every action disappears: a disputed delivery
//    (support actively reviewing it) offers the jeeber no way to open the chat
//    or reach the drop-off.
//  * **The quick actions never sit on one row on a phone.** `_QuickActions`
//    stacks below `_kInlineQuickActionsMinWidth` (448), and a 390 pt phone
//    gives the list 358 pt — so the `Row` branch is unreachable on every
//    supported handset and only a tablet/landscape canvas shows it.
//  * **The layout ceiling** is the longest drop-off + concierge detail +
//    recipient name the gateway will hand over, at the 320 pt floor, on the
//    state that already carries the most content.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _activeDeliveryJeeberScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports, and roughly what an Android
/// multi-window split leaves a foreground app. The stepper gives its five stage
/// labels 1/5 of the content width each, so this is where they wrap first.
const Size _activeDeliveryJeeberScreenCompactBox = Size(320, 568);

/// Owns one preview card's seeded cubit for the life of the card.
///
/// Stateful, and the cubit is built once and closed with the host: a cubit
/// rebuilt on every frame would leak one per rebuild in the canvas, and one
/// closed too early would leave `BlocProvider.value` holding a dead bloc.
class _ActiveDeliveryJeeberScreenHost extends StatefulWidget {
  const _ActiveDeliveryJeeberScreenHost({
    required this.seed,
    this.showGoodsCost = false,
  });

  final ActiveDeliveryState seed;

  /// Wires `onEnterGoodsCost`, which the screen hides when it is null (Sprint 2
  /// Stream G). Off by default so the common previews show the two-button stack
  /// every existing caller produces.
  final bool showGoodsCost;

  @override
  State<_ActiveDeliveryJeeberScreenHost> createState() =>
      _ActiveDeliveryJeeberScreenHostState();
}

class _ActiveDeliveryJeeberScreenHostState
    extends State<_ActiveDeliveryJeeberScreenHost> {
  late final ActiveDeliveryCubit _cubit =
      ActiveDeliveryJeeberScreenSeededCubit(widget.seed);

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ActiveDeliveryJeeberScreen(
        deliveryId: ActiveDeliveryJeeberScreenFixtures.deliveryId,
        cubit: _cubit,
        // Inert. In production these push the order chat and the goods-cost
        // declaration; tapping in the canvas must do neither. `mapsUrlBuilder`
        // is deliberately left null — `_launchMaps` then builds the URL and
        // launches nothing, which is exactly what a preview should do with a
        // deep link into Google Maps.
        onOpenChat: () {},
        onEnterGoodsCost: widget.showGoodsCost ? () {} : null,
      );
}

/// Pins a screen to a device-sized frame inside whatever box the canvas gives
/// it, with the ticker muted (see the section note).
Widget _activeDeliveryJeeberScreenFramed(Widget screen, Size box) {
  return TickerMode(
    enabled: false,
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: box.width, height: box.height, child: screen),
    ),
  );
}

/// The standard host: one designed state, one phone-sized frame.
Widget _activeDeliveryJeeberScreenHosted(
  ActiveDeliveryState seed, {
  Size box = _activeDeliveryJeeberScreenPhoneBox,
  bool showGoodsCost = false,
}) =>
    _activeDeliveryJeeberScreenFramed(
      _ActiveDeliveryJeeberScreenHost(seed: seed, showGoodsCost: showGoodsCost),
      box,
    );

/// Cold open — the state the cubit is constructed in, before the first read
/// resolves.
///
/// A centred spinner and nothing else: no title, no message, no cancel, and
/// nothing a screen reader can announce. Every delivery opens on this frame,
/// and a slow or stalled `GET /v1/deliveries/{id}` holds it for as long as it
/// lasts, because the screen has no timeout of its own.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Loading · cold open',
  size: _activeDeliveryJeeberScreenPhoneBox,
)
Widget activeDeliveryJeeberScreenLoading() => _activeDeliveryJeeberScreenHosted(
      ActiveDeliveryJeeberScreenFixtures.loading,
    );

/// Neither seam wired — the `_Unavailable` shell.
///
/// Not a synthetic state: `build` returns this whenever `cubit` AND
/// `repository` are both null, which is what a route builder that failed to
/// resolve DI hands the jeeber. One sentence, no retry, no reload and no way
/// back to the delivery. It still carries `mark_delivered_root`, so a seam pin
/// or a Maestro flow that only asserts "the screen rendered" cannot tell this
/// apart from a working delivery.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Unavailable · no seam wired',
  size: _activeDeliveryJeeberScreenPhoneBox,
)
Widget activeDeliveryJeeberScreenUnavailable() =>
    _activeDeliveryJeeberScreenFramed(
      ActiveDeliveryJeeberScreen(
        deliveryId: ActiveDeliveryJeeberScreenFixtures.deliveryId,
        onOpenChat: () {},
      ),
      _activeDeliveryJeeberScreenPhoneBox,
    );

/// The read failed — `OmdsErrorState` with the cubit's own mapped message and
/// a retry that calls `loadDelivery()` again.
///
/// The message is NOT localized: `ActiveDeliveryCubit._mapLoadError` returns an
/// English literal ("Unable to load delivery" / "No internet connection" /
/// "Delivery not found") and the screen only falls back to the localized
/// `activeDeliveryLoadError` when that literal is null — which it never is. So
/// the AR rendering of this state is an Arabic app bar over an English error,
/// which is the whole reason the render suite pumps both locales.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Load failed · retry',
  size: _activeDeliveryJeeberScreenPhoneBox,
)
Widget activeDeliveryJeeberScreenLoadFailed() =>
    _activeDeliveryJeeberScreenHosted(
      ActiveDeliveryJeeberScreenFixtures.loadFailed,
    );

/// Pre-pickup (`Ordered`) — the only stage group that still owns an inline
/// advance CTA.
///
/// The button names the NEXT status ("Mark as Picked"), not the current one,
/// and it is the only affordance on the screen at this stage: no mark-delivered
/// panel, because JM-051 mounts that for `InTransit`/`AtDoor` only.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Ordered · advance CTA',
  size: _activeDeliveryJeeberScreenPhoneBox,
)
Widget activeDeliveryJeeberScreenOrdered() => _activeDeliveryJeeberScreenHosted(
      ActiveDeliveryJeeberScreenFixtures.ordered,
    );

/// En route (`InTransit`) — the delivering phase, and the busiest surface the
/// screen has: address, stepper (no advance button), proof-photo slot, note
/// field, cash line, "Complete Delivery", then the action stack.
///
/// Matrixed because this is the state a jeeber spends the whole delivery on and
/// the one with the most text: the AR rendering mirrors an address `Row`, a
/// cash `Row` and five stage labels at once, and the 200% rendering is where
/// the `ListView` earns its keep.
///
/// Note the heading on the mark-delivered panel: it is
/// `l10n.activeDeliveryStatusDone` — the STAGE label — so the panel is titled
/// "Done" while the delivery is in transit, directly under a stepper whose
/// fifth stage is also labelled "Done".
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'In transit · mark delivered',
  size: _activeDeliveryJeeberScreenPhoneBox,
  matrix: true,
)
Widget activeDeliveryJeeberScreenInTransit() =>
    _activeDeliveryJeeberScreenHosted(
      ActiveDeliveryJeeberScreenFixtures.inTransit,
    );

/// At the door, holding for the recipient's 4-digit code.
///
/// `AtDoor → Done` is not a client-patchable edge (P6/B1 — the frozen SM opens
/// it for `otp_verified` alone), so the panel swaps its CTA for the door-OTP
/// entry. Both buttons carry the SAME label: `activeDeliveryOtpSubmit` and
/// `activeDeliveryMarkDone` are both "Complete Delivery", so the only visible
/// difference between this state and the one above it is the four cells and the
/// instruction line.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'At door · door OTP',
  size: _activeDeliveryJeeberScreenPhoneBox,
)
Widget activeDeliveryJeeberScreenAtDoorOtp() =>
    _activeDeliveryJeeberScreenHosted(
      ActiveDeliveryJeeberScreenFixtures.atDoorOtpRequired,
    );

/// The GPS uploader is PARKED and the customer's map is empty — recoverable
/// in-app.
///
/// First item in the list, above everything, not dismissible. The CTA is
/// "Allow location" because the state says the permission can still be
/// escalated from inside the app.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'GPS blocked · in-app retry',
  size: _activeDeliveryJeeberScreenPhoneBox,
)
Widget activeDeliveryJeeberScreenGpsBlockedRetryable() =>
    _activeDeliveryJeeberScreenHosted(
      ActiveDeliveryJeeberScreenFixtures.gpsBlockedRetryable,
    );

/// The same park, permanently denied — only the OS settings page can lift it.
///
/// The CTA becomes "Open settings" and the body grows the longer explanation,
/// which is what pushes the address card and the stepper down the fold. Read it
/// next to the retryable state: one bool moves the banner's height, its copy
/// and the button a jeeber has to find.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'GPS blocked · settings only',
  size: _activeDeliveryJeeberScreenPhoneBox,
  matrix: true,
)
Widget activeDeliveryJeeberScreenGpsBlockedSettingsOnly() =>
    _activeDeliveryJeeberScreenHosted(
      ActiveDeliveryJeeberScreenFixtures.gpsBlockedSettingsOnly,
    );

/// Handed over and verified (`Done`) — the `delivery_completed_state` banner
/// above the address, the stepper at step 5, and no advance affordance.
///
/// The mark-delivered panel is gone (it mounts for `InTransit`/`AtDoor` only),
/// so the proof photo the jeeber captured is no longer visible anywhere on this
/// screen even though the delivery still carries its `evidenceUrl`.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Delivered · completed',
  size: _activeDeliveryJeeberScreenPhoneBox,
)
Widget activeDeliveryJeeberScreenCompleted() =>
    _activeDeliveryJeeberScreenHosted(
      ActiveDeliveryJeeberScreenFixtures.completed,
    );

/// JEBV4-276 regression guard, made visible: `Done` with a write still in
/// flight.
///
/// The row reads Done optimistically and nothing is confirmed — the OTP path
/// reverts from exactly this frame back to `AtDoor` — so `isCompleted` is
/// gated on `!state.isTransitioning` and the "Delivered successfully" banner
/// must NOT appear here. If it ever does, the jeeber is being told the handover
/// succeeded before the server said anything.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Completing · no premature banner',
  size: _activeDeliveryJeeberScreenPhoneBox,
)
Widget activeDeliveryJeeberScreenCompletingOptimistically() =>
    _activeDeliveryJeeberScreenHosted(
      ActiveDeliveryJeeberScreenFixtures.completingOptimistically,
    );

/// Cancelled terminal — a neutral `OmdsEmptyState`, and nothing else at all.
///
/// No stepper, no address, no chat, no maps: the shortest surface this screen
/// can render. It is the right treatment for a delivery that ended, and it is
/// worth looking at next to the disputed state below, which uses the same
/// treatment for a case that is still open.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Cancelled · terminal',
  size: _activeDeliveryJeeberScreenPhoneBox,
)
Widget activeDeliveryJeeberScreenCancelled() =>
    _activeDeliveryJeeberScreenHosted(
      ActiveDeliveryJeeberScreenFixtures.cancelled,
    );

/// Expired terminal — a broadcast that timed out before it was completed.
///
/// Distinct icon, title and body from `cancelled` (the jeeber-side screen keeps
/// the three outcomes apart, unlike the customer-side hub, which folds every
/// non-delivered terminal into "cancelled").
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Expired · terminal',
  size: _activeDeliveryJeeberScreenPhoneBox,
)
Widget activeDeliveryJeeberScreenExpired() =>
    _activeDeliveryJeeberScreenHosted(
      ActiveDeliveryJeeberScreenFixtures.expired,
    );

/// `FailedNeedsEscalation` — "Delivery under review", support is looking at it.
///
/// The one "terminal" that can still move: SM edges 12/13 let an admin resolve
/// it to Done or cancel it, which is why the cubit keeps watching the row
/// (P6/A2). The SCREEN does not reflect that at all — it renders the same
/// dead-end empty state as a cancellation, with no chat, no support entry point
/// and no indication that anything is still in progress.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Disputed · under review',
  size: _activeDeliveryJeeberScreenPhoneBox,
)
Widget activeDeliveryJeeberScreenDisputed() =>
    _activeDeliveryJeeberScreenHosted(
      ActiveDeliveryJeeberScreenFixtures.disputed,
    );

/// The layout ceiling at the 320 pt floor: longest drop-off label, longest
/// concierge detail, longest recipient name, widest amount — and the goods-cost
/// action wired, so all THREE quick actions are stacked.
///
/// Everything that can wrap does. `_AddressCard` gives its column
/// `320 − 2×16 − 2×24 − 24 icon − 8` ≈ 208 pt, the cash line renders
/// "Pay 1,250,000.00 LBP cash to Abdulrahman Al-Muhandis Al-Trabulsi
/// Al-Shamali" inside an `Expanded`, and the five stage labels get ~41 pt each.
/// Matrixed because AR re-lengthens every string and the 200% rendering is the
/// accessibility ceiling the golden tests assert for this screen.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Longest content · compact 320 pt',
  size: _activeDeliveryJeeberScreenCompactBox,
  matrix: true,
)
Widget activeDeliveryJeeberScreenLongestContent() =>
    _activeDeliveryJeeberScreenHosted(
      ActiveDeliveryJeeberScreenFixtures.longestContent,
      box: _activeDeliveryJeeberScreenCompactBox,
      showGoodsCost: true,
    );
