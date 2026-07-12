import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/active_delivery_cubit.dart';
import '../domain/active_delivery_repository.dart';
import '../domain/jeeber_delivery.dart';
import '../domain/jeeber_delivery_status.dart';
import 'widgets/delivery_status_stepper.dart';
import 'widgets/mark_delivered_panel.dart';

/// Jeeber active-delivery / mark-delivered screen (T-MOB-031, JM-051).
///
/// Route: `/jeeber/deliveries/:id/active` (seam-pinned for the
/// `jeeber_active_delivery` journey → `mark_delivered_root` on first frame).
///
/// Shows the drop-off address, the status stepper (Ordered→…→AtDoor), and — at
/// `AtDoor` — the mark-delivered panel: a proof-of-delivery photo capture (D3),
/// an optional note, the "customer confirms receipt + pays cash" copy (D11),
/// and the "Mark as delivered" CTA. When the delivery reaches `Done` the screen
/// routes to `feedback-rate-delivery` (the mandatory mutual rating, JM-034 /
/// D56) — **NOT** the OTP handover.
class ActiveDeliveryJeeberScreen extends StatelessWidget {
  const ActiveDeliveryJeeberScreen({
    super.key,
    required this.deliveryId,
    required this.onOpenChat,
    this.onMarkedDelivered,
    this.onOpenOtp,
    this.onEnterGoodsCost,
    this.repository,
    this.cubit,
    this.mapsUrlBuilder,
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

  /// Pre-built cubit — optional test seam.
  final ActiveDeliveryCubit? cubit;

  /// Override for url_launcher in tests.
  final Future<void> Function(String url)? mapsUrlBuilder;

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
      create: (_) =>
          ActiveDeliveryCubit(repository: repo, deliveryId: deliveryId)
            ..loadDelivery(),
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
    if (state.transitionError != null) {
      // EXEMPT: OMDS exports no standalone toast/snackbar widget; ScaffoldMessenger
      // + showOmdsSnackbar is the approved fleet pattern for transient feedback.
      showOmdsSnackbar(context, message: state.transitionError!);
      context.read<ActiveDeliveryCubit>().acknowledgeTransitionError();
    }
    // JM-051 AC2: done → mandatory rating (NOT OTP). One-shot signal.
    if (state.delivered) {
      context.read<ActiveDeliveryCubit>().acknowledgeDelivered();
      onMarkedDelivered?.call();
    }
  }

  Widget _buildScaffold(BuildContext context, ActiveDeliveryState state) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.activeDeliveryTitle,
        showBackButton: true,
      ),
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
          onAdvance: () =>
              context.read<ActiveDeliveryCubit>().advanceStatus(),
          onCaptureProof: () =>
              context.read<ActiveDeliveryCubit>().captureProofPhoto(
                    'proof_${DateTime.now().millisecondsSinceEpoch}.jpg',
                  ),
          onNoteChanged: (v) =>
              context.read<ActiveDeliveryCubit>().setNote(v),
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
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
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
    // JM-051: the mark-delivered panel is surfaced during the delivering phase
    // (InTransit or AtDoor) — the seam seeds `jeeber_active_delivery` at
    // InTransit, and the flow asserts the panel on first frame. `markDelivered`
    // walks the remaining SM-1 forward steps (InTransit → AtDoor → Done),
    // stamping the proof evidenceUrl on the final transition.
    final showMarkDelivered =
        delivery.status == JeeberDeliveryStatus.inTransit ||
            delivery.status == JeeberDeliveryStatus.atDoor;
    // Core Flow step 7 (jeeber terminal): once the handover OTP completes the
    // delivery to V3 `Done`, render an explicit delivered/completed final state
    // so a re-entry / poll-update lands on a clear terminal UI (not a stale
    // "advance" affordance).
    final isCompleted = delivery.status == JeeberDeliveryStatus.done;
    return ListView(
      padding: const EdgeInsets.all(Spacing.medium),
      children: [
        if (isCompleted) ...[
          _CompletedPanel(l10n: l10n),
          const SizedBox(height: Spacing.large),
        ],
        _AddressCard(delivery: delivery, l10n: l10n),
        const SizedBox(height: Spacing.large),
        DeliveryStatusStepper(
          currentStatus: delivery.status,
          isTransitioning: state.isTransitioning,
          onAdvance: onAdvance,
        ),
        const SizedBox(height: Spacing.large),
        // JM-051 AC1/AC2: surface the mark-delivered panel — proof photo (D3)
        // + optional note + cash-receipt copy (D11) + the CTA.
        if (showMarkDelivered) ...[
          MarkDeliveredPanel(
            delivery: delivery,
            proofPhotoStatus: state.proofPhotoStatus,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.activeDeliveryDropOffLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: Spacing.xSmall),
            Text(
              delivery.dropOff.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (delivery.dropOff.detail != null) ...[
              const SizedBox(height: Spacing.xSmall),
              Text(
                delivery.dropOff.detail!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final enterGoodsCost = onEnterGoodsCost;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OmdsPrimaryButton(
          text: l10n.activeDeliveryOpenMapsButton,
          // `OmdsPrimaryButton` only colors its text child, not a passed icon,
          // so the leading icon must be given the on-navy token explicitly —
          // otherwise it inherits the ambient (near-black) IconTheme color and
          // renders black-on-navy. Match the white text via `onPrimary`.
          icon: Icon(Icons.map_outlined, color: colorScheme.onPrimary),
          onTap: onOpenMaps,
        ),
        const SizedBox(height: Spacing.small),
        OmdsPrimaryButton(
          text: l10n.activeDeliveryOpenChatButton,
          variant: OmdsButtonVariant.outlined,
          icon: const Icon(Icons.chat_bubble_outline),
          onTap: onOpenChat,
        ),
        // Sprint 2 Stream G: goods-cost entry point (D11). Only shown when the
        // caller wired the navigation closure — keeps existing tests/callers
        // (which omit it) rendering exactly the prior two buttons.
        if (enterGoodsCost != null) ...[
          const SizedBox(height: Spacing.small),
          OmdsPrimaryButton(
            text: l10n.activeDeliveryEnterGoodsCostButton,
            variant: OmdsButtonVariant.outlined,
            icon: const Icon(Icons.receipt_long_outlined),
            onTap: enterGoodsCost,
          ),
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
