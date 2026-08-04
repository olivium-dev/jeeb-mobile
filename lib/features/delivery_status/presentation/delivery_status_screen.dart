import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../application/delivery_status_cubit.dart';
import '../application/delivery_status_state.dart';
import '../domain/delivery_snapshot.dart';
import '../domain/delivery_status_gateway.dart';
import 'widgets/delivery_details_card.dart';
import 'widgets/delivery_eta_badge.dart';
import 'widgets/delivery_jeeber_card.dart';
import 'widgets/delivery_lifecycle_banner.dart';
import 'widgets/delivery_stage_indicator.dart';

/// The board's block rhythm (`_ds/readme.md` — "24px side gutters, ~28px block
/// rhythm"). Between the banner, the ETA strip, the stepper and the two cards.
const double _kBlockRhythm = 28;

/// Public callback the screen invokes when the user taps the contact CTA.
///
/// Production wires this to a `tel:` launcher; widget tests pass a no-op
/// recorder so they can assert the call was attempted with the right
/// number without depending on `url_launcher`.
typedef ContactJeeberHandler = void Function(String phoneE164);

/// Renders the delivery status experience for [deliveryId].
///
/// Owns its own [DeliveryStatusCubit] — wiring is intentionally thin so
/// widget tests can inject either a pre-built cubit or a scripted gateway.
// ORPHAN (JEBV4-227, verified 2026-07-12): dead parallel re-implementation of tracking, zero external refs — see docs/project-understanding/reconciliation/orphans.md
class DeliveryStatusScreen extends StatelessWidget {
  const DeliveryStatusScreen({
    super.key,
    required this.deliveryId,
    this.cubit,
    this.gateway,
    this.onContactJeeber,
  }) : assert(
          cubit == null || gateway == null,
          'Provide either a cubit or a gateway, not both.',
        );

  /// The delivery to display. Echoed in the cubit and the app-bar subtitle.
  final String deliveryId;

  /// Optional pre-built cubit — widget tests use this to keep state under
  /// their control. When null, the screen builds one from [gateway] (or a
  /// demo in-memory gateway as a last resort so the route can render
  /// during the UI-only milestone).
  final DeliveryStatusCubit? cubit;

  /// Gateway used to build the cubit when one isn't supplied.
  final DeliveryStatusGateway? gateway;

  /// Handler invoked when the user confirms the Contact CTA. Tests inject
  /// a recorder; production wires a `tel:` launcher.
  final ContactJeeberHandler? onContactJeeber;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<DeliveryStatusCubit>.value(
        value: provided,
        child: _Scaffold(
          deliveryId: deliveryId,
          onContactJeeber: onContactJeeber,
        ),
      );
    }
    return BlocProvider<DeliveryStatusCubit>(
      create: (_) => DeliveryStatusCubit(
        deliveryId: deliveryId,
        gateway: gateway ??
            InMemoryDeliveryStatusGateway(
              seed: demoDeliverySnapshot(id: deliveryId),
            ),
      ),
      child: _Scaffold(
        deliveryId: deliveryId,
        onContactJeeber: onContactJeeber,
      ),
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.deliveryId, this.onContactJeeber});

  final String deliveryId;
  final ContactJeeberHandler? onContactJeeber;

  static const Key rootKey = Key('delivery-status-screen');
  static const Key bodyScrollKey = Key('delivery-status-scroll');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'delivery_status_root',
      container: true,
      child: Scaffold(
        key: rootKey,
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // redesign-2026-08: the Material app bar is gone — the back
              // affordance is the kit's in-body circle, mounted above the
              // builder so every view state (loading, error, ready) keeps a way
              // out. The delivery id rides along as the bar's subtitle, which is
              // 12's title/meta pattern, instead of a grey line floating over
              // the stepper.
              JeebTopBar.back(
                identifier: 'delivery_status_back',
                title: l10n.deliveryStatusTitle,
                titleScale: JeebTopBarTitleScale.compact,
                subtitle: l10n.deliveryStatusIdSubtitle(deliveryId),
              ),
              Expanded(
                child: BlocConsumer<DeliveryStatusCubit, DeliveryStatusState>(
                  listenWhen: (prev, curr) =>
                      prev.error != curr.error && curr.error != null,
                  listener: _surfaceError,
                  builder: (context, state) {
                    switch (state.mode) {
                      case DeliveryStatusViewMode.loading:
                        return _LoadingView(l10n: l10n);
                      case DeliveryStatusViewMode.error:
                        return _ErrorView(
                          l10n: l10n,
                          onRetry: () =>
                              context.read<DeliveryStatusCubit>().retry(),
                        );
                      case DeliveryStatusViewMode.ready:
                        final snapshot = state.snapshot;
                        if (snapshot == null) {
                          return _LoadingView(l10n: l10n);
                        }
                        return _ReadyView(
                          snapshot: snapshot,
                          isCancelling: state.isCancelling,
                          onContactJeeber: onContactJeeber,
                        );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _surfaceError(BuildContext context, DeliveryStatusState state) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DeliveryStatusCubit>();
    final message = _messageFor(l10n, state.error!);
    if (message != null) {
      showOmdsSnackbar(context, message: message);
    }
    cubit.acknowledgeError();
  }

  String? _messageFor(AppLocalizations l10n, DeliveryStatusError error) {
    switch (error) {
      case DeliveryStatusError.cancelTooLate:
        return l10n.deliveryErrorCancelTooLate;
      case DeliveryStatusError.cancelNetwork:
        return l10n.deliveryErrorCancelNetwork;
      case DeliveryStatusError.contactUnavailable:
        return l10n.deliveryErrorContactUnavailable;
      case DeliveryStatusError.streamLost:
        return l10n.deliveryErrorStreamLost;
    }
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.l10n});

  final AppLocalizations l10n;

  static const Key rootKey = Key('delivery-status-loading');

  @override
  Widget build(BuildContext context) {
    return Center(
      key: rootKey,
      child: OmdsLoadingState(message: l10n.deliveryStatusLoading),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.l10n, required this.onRetry});

  final AppLocalizations l10n;
  final VoidCallback onRetry;

  static const Key rootKey = Key('delivery-status-error');

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: rootKey,
      // The board's 24px side gutter.
      padding: const EdgeInsets.all(Spacing.xLarge),
      child: Center(
        // OMDS's OmdsErrorState owns the visual layout — we only feed it
        // localized copy. The retry button is OMDS-internal so we attach the
        // test key to the surrounding container instead.
        child: OmdsErrorState(
          title: l10n.deliveryStatusErrorTitle,
          message: l10n.deliveryStatusErrorBody,
          icon: Icons.cloud_off_outlined,
          retryLabel: l10n.deliveryStatusRetry,
          onRetry: onRetry,
        ),
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.snapshot,
    required this.isCancelling,
    this.onContactJeeber,
  });

  final DeliverySnapshot snapshot;
  final bool isCancelling;
  final ContactJeeberHandler? onContactJeeber;

  static const Key contactButtonKey = Key('delivery-status-contact-cta');
  static const Key cancelButtonKey = Key('delivery-status-cancel-cta');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: _Scaffold.bodyScrollKey,
            padding: const EdgeInsetsDirectional.fromSTEB(
              Spacing.xLarge,
              Spacing.medium,
              Spacing.xLarge,
              Spacing.xLarge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (snapshot.lifecycle != DeliveryLifecycle.active) ...[
                  DeliveryLifecycleBanner(lifecycle: snapshot.lifecycle),
                  const SizedBox(height: _kBlockRhythm),
                ],
                if (snapshot.isEtaVisible) ...[
                  DeliveryEtaBadge(minutes: snapshot.etaMinutes!),
                  const SizedBox(height: _kBlockRhythm),
                ],
                DeliveryStageIndicator(snapshot: snapshot),
                const SizedBox(height: _kBlockRhythm),
                DeliveryDetailsCard(snapshot: snapshot),
                const SizedBox(height: _kBlockRhythm),
                DeliveryJeeberCard(jeeber: snapshot.jeeber),
              ],
            ),
          ),
        ),
        // The CTAs dock at the foot of the screen (12 `tpl 781-783`) instead of
        // trailing the scroll — same two actions, same gating, same order.
        _ActionBar(
          snapshot: snapshot,
          isCancelling: isCancelling,
          onContactJeeber: onContactJeeber,
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.snapshot,
    required this.isCancelling,
    this.onContactJeeber,
  });

  final DeliverySnapshot snapshot;
  final bool isCancelling;
  final ContactJeeberHandler? onContactJeeber;

  Future<void> _onCancelPressed(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DeliveryStatusCubit>();
    final confirmed = await OmdsConfirmationDialog.show(
      context: context,
      title: l10n.deliveryCancelDialogTitle,
      content: l10n.deliveryCancelDialogBody,
      confirmText: l10n.deliveryCancelDialogConfirm,
      cancelText: l10n.deliveryCancelDialogDismiss,
      isDestructive: true,
      icon: Icons.cancel_outlined,
    );
    if (!confirmed) return;
    await cubit.cancel();
  }

  void _onContactPressed(BuildContext context) {
    final cubit = context.read<DeliveryStatusCubit>();
    final number = cubit.requestContactNumber();
    if (number == null) return;
    HapticFeedback.selectionClick();
    onContactJeeber?.call(number);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!snapshot.isInFlight) {
      // Terminal states (delivered / cancelled) hide both CTAs — the
      // upstream rate-prompt screen owns the next user action.
      return const SizedBox.shrink();
    }
    final contact = snapshot.canContactJeeber
        ? Semantics(
            identifier: 'delivery_status_contact_cta',
            container: true,
            button: true,
            child: JeebCtaButton.primary(
              key: _ReadyView.contactButtonKey,
              label: l10n.deliveryActionContact,
              leadingIcon: Icons.phone,
              onTap: () => _onContactPressed(context),
            ),
          )
        : null;
    final cancel = snapshot.canCancel
        ? Semantics(
            identifier: 'delivery_status_cancel_cta',
            container: true,
            button: true,
            child: JeebCtaButton.outline(
              key: _ReadyView.cancelButtonKey,
              // The label swap stays the progress signal (not `isLoading`):
              // "Cancelling…" is the one word the user needs while the gateway
              // decides, and a spinner would swallow it.
              label: isCancelling
                  ? l10n.deliveryActionCancellingLabel
                  : l10n.deliveryActionCancel,
              isEnabled: !isCancelling,
              onTap: () => _onCancelPressed(context),
            ),
          )
        : null;
    final primary = contact ?? cancel;
    if (primary == null) return const SizedBox.shrink();
    return JeebCtaFooter.single(
      // Contact leads when both are live; cancel is the quieter second line —
      // the same precedence the stacked column had.
      below: contact == null ? null : cancel,
      child: primary,
    );
  }
}
