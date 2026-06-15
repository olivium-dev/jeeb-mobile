import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/otp_handover_cubit.dart';
import '../application/otp_handover_state.dart';

/// T-MOB-018: OTP handover screen — client display + Jeeber entry.
///
/// AC1: 4-digit code rendered large for the client.
/// AC2: on success, transitions to celebratory done state + rate-now CTA.
/// AC3: wrong code → shake animation + inline error + attempt counter.
/// AC4: 3 wrong codes → escalate dialog (→ dispute).
/// AC5: client code announced via Semantics liveRegion; OTP input navigable.
/// AC6: OTP code is never logged (raw string stays in ephemeral widget state).
class OtpHandoverScreen extends StatelessWidget {
  const OtpHandoverScreen({
    super.key,
    required this.deliveryId,
    required this.isClient,
  });

  final String deliveryId;
  final bool isClient;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: isClient
            ? l10n.otpHandoverClientTitle
            : l10n.otpHandoverJeeberTitle,
        showBackButton: true,
      ),
      body: BlocConsumer<OtpHandoverCubit, OtpHandoverState>(
        listenWhen: _shouldListen,
        listener: _onStateChange,
        builder: (context, state) => _OtpBody(
          state: state,
          isClient: isClient,
          deliveryId: deliveryId,
        ),
      ),
    );
  }

  bool _shouldListen(OtpHandoverState prev, OtpHandoverState next) =>
      next.escalate && !prev.escalate ||
      next.mode == OtpHandoverViewMode.success && prev.mode != OtpHandoverViewMode.success;

  void _onStateChange(BuildContext context, OtpHandoverState state) {
    if (state.escalate) {
      _showEscalateDialog(context);
    }
  }

  Future<void> _showEscalateDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await OmdsConfirmationDialog.show(
      context: context,
      title: l10n.otpEscalateDialogTitle,
      content: l10n.otpEscalateDialogBody,
      confirmText: l10n.otpEscalateConfirm,
      cancelText: l10n.otpEscalateDismiss,
      barrierDismissible: false,
    );
    if (!context.mounted) return;
    if (confirmed) {
      context.go('/orders/$deliveryId/escalate');
    } else {
      context.read<OtpHandoverCubit>().dismissEscalate();
    }
  }
}

class _OtpBody extends StatelessWidget {
  const _OtpBody({
    required this.state,
    required this.isClient,
    required this.deliveryId,
  });

  final OtpHandoverState state;
  final bool isClient;
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    switch (state.mode) {
      case OtpHandoverViewMode.loading:
        return const Center(child: OmdsLoadingState());
      case OtpHandoverViewMode.error:
        return _ErrorBody(
          state: state,
          onRetry: () => context.read<OtpHandoverCubit>().retry(),
        );
      case OtpHandoverViewMode.success:
        return _DoneBody(deliveryId: deliveryId, isClient: isClient);
      case OtpHandoverViewMode.ready:
      case OtpHandoverViewMode.submitting:
        return _ReadyBody(
          state: state,
          isClient: isClient,
          deliveryId: deliveryId,
        );
    }
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.state, required this.onRetry});

  final OtpHandoverState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: OmdsErrorState(
        message: _mapMessage(l10n, state.errorMessage),
        onRetry: onRetry,
        retryLabel: l10n.otpRetry,
      ),
    );
  }

  String _mapMessage(AppLocalizations l10n, String? key) {
    switch (key) {
      case 'network':
        return l10n.otpErrorNetwork;
      case 'server':
        return l10n.otpErrorServer;
      default:
        return l10n.otpErrorGeneric;
    }
  }
}

/// T-MOB-018 AC2: Celebratory done state shown after successful OTP verify.
///
/// JEEBER-LOOP F1: navigation now targets the blind mutual-rating screen
/// (`/orders/:id/mutual-rate`, T-MOB-020) — not the single-side `/feedback`
/// placeholder — and threads [isClient] so the Jeeber leg carries
/// `?mode=jeeber`. The router resolves `isClient = mode != 'jeeber'`, so an
/// absent `mode` lands the client and `?mode=jeeber` lands the delivery man on
/// his side of the two-party rating. Without the param the Jeeber would be
/// mis-routed to the client-facing rating screen.
class _DoneBody extends StatelessWidget {
  const _DoneBody({required this.deliveryId, required this.isClient});

  final String deliveryId;
  final bool isClient;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: Sizes.fiveXLarge,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: Spacing.large),
            Text(
              l10n.otpDoneTitle,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.small),
            Text(
              l10n.otpDoneBody,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.xLarge),
            OmdsLoadingButton(
              text: l10n.otpRateNowCta,
              isLoading: false,
              isEnabled: true,
              onTap: () => context.go(_mutualRateRoute(deliveryId, isClient)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Builds the mutual-rate route, appending `?mode=jeeber` for the delivery-man
/// leg so the router (`isClient = mode != 'jeeber'`) flips audience correctly.
String _mutualRateRoute(String deliveryId, bool isClient) =>
    '/orders/$deliveryId/mutual-rate${isClient ? '' : '?mode=jeeber'}';

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({
    required this.state,
    required this.isClient,
    required this.deliveryId,
  });

  final OtpHandoverState state;
  final bool isClient;
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.xLarge),
      child: isClient
          ? _ClientOtpDisplay(
              code: state.handoverCode ?? '----',
              deliveryId: deliveryId,
            )
          : _JeeberOtpEntry(state: state),
    );
  }
}

/// T-MOB-018 AC1/AC5: Client sees large 4-digit code; announced via liveRegion.
///
/// JEEBER-LOOP F2: the client OTP-display had no forward path — once the
/// Jeeber verified the code the client sat here indefinitely (there is no
/// status polling). A manual "Rate now" CTA lets the client advance to the
/// mutual-rate screen (`/orders/:id/mutual-rate`, client leg) after handover,
/// closing the client side of the two-party loop without introducing polling.
class _ClientOtpDisplay extends StatelessWidget {
  const _ClientOtpDisplay({required this.code, required this.deliveryId});

  final String code;
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.otpClientShareInstruction,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.xLarge),
          _OtpCodeDisplay(code: code),
          const SizedBox(height: Spacing.medium),
          Text(
            l10n.otpClientDoNotShare,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.xLarge),
          _ClientRateNowButton(deliveryId: deliveryId),
        ],
      ),
    );
  }
}

/// JEEBER-LOOP F2: post-handover "Rate now" CTA on the client OTP display.
/// Navigates the client leg to the blind mutual-rating screen (no `mode`
/// param → router resolves `isClient = true`).
class _ClientRateNowButton extends StatelessWidget {
  const _ClientRateNowButton({required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      // QA: uiautomator-addressable handle for the client's rate-now CTA.
      identifier: 'client_otp_rate_now',
      child: OmdsPrimaryButton(
        key: const Key('otpHandover.clientRateNow'),
        text: l10n.otpRateNowCta,
        onTap: () => context.go(_mutualRateRoute(deliveryId, true)),
      ),
    );
  }
}

class _OtpCodeDisplay extends StatelessWidget {
  const _OtpCodeDisplay({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      // QA: uiautomator-addressable handle for the client-facing code display.
      identifier: 'otp_handover_code_display',
      liveRegion: true,
      label: 'OTP code',
      value: code.split('').join(' '),
      child: Container(
        key: const Key('otpHandover.codeDisplay'),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.twoXLarge,
          vertical: Spacing.medium,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: OmdsBorderRadius.medium,
        ),
        child: Text(
          code,
          style: theme.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: Spacing.small,
          ),
        ),
      ),
    );
  }
}

/// T-MOB-018 AC3/AC5: Jeeber entry with shake on wrong code.
class _JeeberOtpEntry extends StatefulWidget {
  const _JeeberOtpEntry({required this.state});

  final OtpHandoverState state;

  @override
  State<_JeeberOtpEntry> createState() => _JeeberOtpEntryState();
}

class _JeeberOtpEntryState extends State<_JeeberOtpEntry>
    with SingleTickerProviderStateMixin {
  String _code = '';
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  int _lastShakeKey = 0;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = _buildShakeAnimation();
  }

  Animation<double> _buildShakeAnimation() => TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
      ]).animate(_shakeCtrl);

  @override
  void didUpdateWidget(_JeeberOtpEntry old) {
    super.didUpdateWidget(old);
    if (widget.state.shakeKey != _lastShakeKey) {
      _lastShakeKey = widget.state.shakeKey;
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _OtpInstruction(state: widget.state),
          const SizedBox(height: Spacing.xLarge),
          _ShakingOtpInput(
            shakeAnim: _shakeAnim,
            onChanged: (v) => setState(() => _code = v),
            onCompleted: _onCompleted,
          ),
          _AttemptHint(state: widget.state),
          const SizedBox(height: Spacing.xLarge),
          _SubmitButton(
            code: _code,
            isSubmitting: widget.state.mode == OtpHandoverViewMode.submitting,
            onSubmit: _onSubmit,
          ),
        ],
      ),
    );
  }

  void _onCompleted(String value) {
    if (widget.state.mode != OtpHandoverViewMode.submitting) {
      context.read<OtpHandoverCubit>().submitOtp(value);
    }
  }

  void _onSubmit() => context.read<OtpHandoverCubit>().submitOtp(_code);
}

class _OtpInstruction extends StatelessWidget {
  const _OtpInstruction({required this.state});

  final OtpHandoverState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasError = state.errorMessage == 'invalid_otp';
    return Text(
      hasError ? _errorText(l10n) : l10n.otpJeeberInstruction,
      style: theme.textTheme.titleMedium?.copyWith(
        color: hasError ? theme.colorScheme.error : null,
      ),
      textAlign: TextAlign.center,
    );
  }

  String _errorText(AppLocalizations l10n) => l10n.otpWrongCode;
}

class _ShakingOtpInput extends StatelessWidget {
  const _ShakingOtpInput({
    required this.shakeAnim,
    required this.onChanged,
    required this.onCompleted,
  });

  final Animation<double> shakeAnim;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // QA: uiautomator-addressable handle for the Jeeber OTP entry field.
      // `container: true` makes the identifier surface as its own queryable
      // SemanticsNode even though OmdsOtpInput renders multiple cell fields
      // (CAP-1: a non-boundary id over a multi-child widget can be folded into
      // an ancestor).
      identifier: 'otp_handover_input',
      container: true,
      child: AnimatedBuilder(
        animation: shakeAnim,
        builder: (_, child) => Transform.translate(
          offset: Offset(shakeAnim.value, 0),
          child: child,
        ),
        child: OmdsOtpInput(
          key: const Key('otpHandover.input'),
          length: 4,
          onChanged: onChanged,
          onCompleted: onCompleted,
        ),
      ),
    );
  }
}

class _AttemptHint extends StatelessWidget {
  const _AttemptHint({required this.state});

  final OtpHandoverState state;

  @override
  Widget build(BuildContext context) {
    if (state.wrongAttempts == 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final remaining = OtpHandoverState.maxAttempts - state.wrongAttempts;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.small),
      child: Text(
        l10n.otpAttemptsRemaining(remaining),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.code,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final String code;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      // QA: uiautomator-addressable handle for the verify/submit CTA. No
      // `button: true` here — OmdsLoadingButton already exposes the button
      // role; `container: true` keeps this identifier its own queryable node.
      identifier: 'otp_handover_submit',
      container: true,
      child: OmdsLoadingButton(
        key: const Key('otpHandover.submit'),
        text: l10n.otpVerifyButton,
        isLoading: isSubmitting,
        isEnabled: code.length == 4 && !isSubmitting,
        onTap: onSubmit,
      ),
    );
  }
}
