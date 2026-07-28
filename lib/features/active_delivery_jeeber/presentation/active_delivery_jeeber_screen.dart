import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../background_gps/application/background_gps_cubit.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../application/active_delivery_cubit.dart';
import '../domain/active_delivery_repository.dart';
import '../domain/jeeber_delivery.dart';
import '../domain/jeeber_delivery_status.dart';
import 'widgets/delivery_status_stepper.dart';
import 'widgets/mark_delivered_panel.dart';

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
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Post-frame + mounted-guard so a refresh scheduled during teardown never
    // touches a defunct element.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ActiveDeliveryCubit>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
