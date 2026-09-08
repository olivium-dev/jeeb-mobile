import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/app_failure_mapper.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/app_failure_copy.dart';
import '../../../core/widgets/jeeb/jeeb_code_cells.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_state_host.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../application/otp_handover_cubit.dart';
import '../application/otp_handover_state.dart';
import '../domain/otp_handover_repository.dart';
import 'widgets/handover_arrival_banner.dart';
import 'widgets/handover_code_display.dart';

/// R13's own glow: `520x440 at 50% 42%, rgba(215,59,0,.26)` (`tpl 799`) — one
/// step above the `content` variant's .22, because the code tiles sit on it.
const double _kFieldGlowAlpha = 0.26;

/// Board `margin:18px` under the header, less the bar's 4dp tap overhang.
const double _kBannerTopGap = 18 - JeebTopBar.tapOverhang;

/// Board `padding:36px` above "Say it or show it" (`tpl 805`). Measured from
/// the banner; without one it falls under the bar and loses the overhang.
const double _kInstructionTopGap = 36;
const double _kInstructionTopGapNoBanner =
    _kInstructionTopGap - JeebTopBar.tapOverhang;

/// Board `margin-top:5px` under the instruction headline (`tpl 807`).
const double _kInstructionSubtitleGap = 5;

/// Board `padding:26px` above the code tiles (`tpl 808`).
const double _kCodeTopGap = 26;

/// Board `margin:22px` above the safety note (`tpl 813`).
const double _kSafetyNoteTopGap = 22;

/// Board `margin-top:14px` between the SMS sentence and the dispute pill
/// (`tpl 819`).
const double _kFooterStackGap = 14;

/// T-MOB-018: OTP handover screen — client display + Jeeber entry.
///
/// AC1: 4-digit code rendered large for the client.
/// AC2: on success, transitions to celebratory done state + rate-now CTA.
/// AC3: wrong code → shake animation + inline error + attempt counter.
/// AC4: 3 wrong codes → escalate dialog (→ dispute).
/// AC5: client code announced via Semantics liveRegion; OTP input navigable.
/// AC6: OTP code is never logged (raw string stays in ephemeral widget state).
///
/// MIDNIGHT R13: the client surface is the board's "handoff moment" — the
/// content field's orange glow behind four backlit-glass code tiles, ONE solid
/// orange block (the arrival banner), one glass safety note, then real
/// emptiness down to a docked footer. The Jeeber entry, SMS fallback and done
/// bodies follow the same grammar; the board draws the client leg only.
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
    return Semantics(
      identifier: 'otp_handover_root',
      container: true,
      // The root signature must not merge away the code-display and CTA
      // identifiers that Maestro targets inside this screen.
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // The board's header is an in-body row, not a Material app bar.
        body: JeebMidnightField(
          variant: JeebFieldVariant.content,
          glowPlacement: JeebFieldGlowPlacement.centerUpper,
          glowColor:
              context.jeebRoles.accent.withValues(alpha: _kFieldGlowAlpha),
          child: SafeArea(
            child: Column(
              children: [
                JeebTopBar.back(
                  title: isClient
                      ? l10n.otpHandoverClientTitle
                      : l10n.otpHandoverJeeberTitle,
                  identifier: 'otp_handover_back',
                  onLeadingPressed: () => _back(context),
                ),
                Expanded(
                  child: BlocConsumer<OtpHandoverCubit, OtpHandoverState>(
                    listenWhen: _shouldListen,
                    listener: _onStateChange,
                    builder: (context, state) => _OtpBody(
                      state: state,
                      isClient: isClient,
                      deliveryId: deliveryId,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `maybePop` is a silent no-op when this screen is the stack root (a push
  /// notification or a deep link lands here directly), and `RootAwareBackScope`
  /// only intercepts the SYSTEM back gesture — never the in-app circle. So the
  /// bar gets an explicit handler mirroring `backFallbacks['otp-handover']`.
  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  bool _shouldListen(OtpHandoverState prev, OtpHandoverState next) =>
      next.escalate && !prev.escalate ||
      next.mode == OtpHandoverViewMode.success &&
          prev.mode != OtpHandoverViewMode.success;

  void _onStateChange(BuildContext context, OtpHandoverState state) {
    if (state.escalate) {
      _showEscalateDialog(context, state.escalationId);
    }
  }

  Future<void> _showEscalateDialog(
    BuildContext context,
    String? escalationId,
  ) async {
    final l10n = AppLocalizations.of(context);
    // A 423 means the gateway ALREADY opened a case: offering to open a second
    // one is the wrong act, so the dialog points at the existing one.
    final bool locked = escalationId != null;
    final confirmed = await OmdsConfirmationDialog.show(
      context: context,
      title: locked ? l10n.otpHandoverLockedTitle : l10n.otpEscalateDialogTitle,
      content: locked ? l10n.otpHandoverLockedBody : l10n.otpEscalateDialogBody,
      confirmText: locked
          ? l10n.otpHandoverLockedContactSupport
          : l10n.otpEscalateConfirm,
      cancelText: l10n.otpEscalateDismiss,
      barrierDismissible: false,
    );
    if (!context.mounted) return;
    if (confirmed) {
      context.go(
        locked ? '/disputes/$escalationId' : '/orders/$deliveryId/escalate',
      );
    } else {
      context.read<OtpHandoverCubit>().dismissEscalate();
    }
  }
}

/// R13's page shape: content at the top, ONE spacer, one docked footer.
///
/// A bare `Column` + `Spacer` asserts once the text scale pushes the content
/// past the viewport, so the whole thing sits in a scroll view whose child is
/// forced to at least the viewport height. At 1× that reproduces the board's
/// genuinely empty lower band; at 200 % it scrolls instead of overflowing.
class _HandoffPage extends StatelessWidget {
  const _HandoffPage({required this.content, required this.footer});

  final Widget content;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [content, const Spacer(), footer],
            ),
          ),
        ),
      ),
    );
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
        return _LoadingBody(isClient: isClient);
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

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.isClient});

  final bool isClient;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebStateHost(
      child: JeebEmptyState(
        status: JeebEmptyStateStatus.loading,
        headline: l10n.otpHandoverLoadingHeadline,
        identifier: 'otp_handover_loading',
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.state, required this.onRetry});

  final OtpHandoverState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return JeebStateHost(
      child: JeebFailureBlock(
        failure: otpHandoverFailure(state.errorKind),
        identifier: 'otp_handover_error',
        onRetry: onRetry,
        onExit: () => _backOut(context),
      ),
    );
  }

  void _backOut(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}

/// The load/submit failure the copy family renders. Kept beside the screen so
/// the fixtures and the tests agree on one mapping.
AppFailure otpHandoverFailure(OtpHandoverErrorKind? kind) => switch (kind) {
  OtpHandoverErrorKind.network => networkFailureFromReachability(),
  OtpHandoverErrorKind.notFound => const NotFoundFailure(),
  OtpHandoverErrorKind.invalidOtp ||
  OtpHandoverErrorKind.notAtDoor ||
  OtpHandoverErrorKind.wrongParty => const ValidationFailure(),
  OtpHandoverErrorKind.locked => const ForbiddenFailure(),
  OtpHandoverErrorKind.unauthorized => const UnauthorizedFailure(),
  OtpHandoverErrorKind.server => const ServerFailure(status: 500),
  OtpHandoverErrorKind.parse || null => const UnknownFailure(),
};

/// T-MOB-018 AC2: Celebratory done state shown after successful OTP verify.
///
/// JEEBER-LOOP F1: navigation targets the blind mutual-rating screen
/// (`/orders/:id/mutual-rate`, T-MOB-020) and threads [isClient] so the Jeeber
/// leg carries `?mode=jeeber` (the router resolves `isClient = mode !=
/// 'jeeber'`). This is the ONE post-verify forward path the board's silence
/// leaves room for, so it keeps the full CTA weight — unlike the client
/// code-display's demoted twin (Pattern D).
class _DoneBody extends StatelessWidget {
  const _DoneBody({required this.deliveryId, required this.isClient});

  final String deliveryId;
  final bool isClient;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _HandoffPage(
      content: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.xLarge,
          Spacing.twoXLarge,
          Spacing.xLarge,
          0,
        ),
        child: JeebInfoNote.success(
          icon: Icons.check_circle,
          title: l10n.otpDoneTitle,
          text: l10n.otpDoneBody,
        ),
      ),
      footer: JeebCtaFooter.single(
        child: Semantics(
          // Post-verify success-state rate-now CTA (shared by both legs).
          // Distinct from the client OTP-display's `client_otp_rate_now`.
          identifier: 'otp_done_rate_now',
          container: true,
          button: true,
          child: JeebCtaButton.primary(
            label: l10n.otpRateNowCta,
            onTap: () => context.go(_mutualRateRoute(deliveryId, isClient)),
          ),
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
    // G4 (sprint-009 P0): the code-ENTRY grid is the JEEBER's surface, full
    // stop. The customer either sees their code (accept-time persisted, or
    // returned by the gateway) or the honest SMS-fallback ("we've sent your
    // code by SMS") — never an entry grid for a code they were never shown
    // (the removed iter6 `allowManualEntry` dead end).
    if (!isClient) {
      return _JeeberOtpEntry(state: state);
    }
    final code = state.handoverCode;
    return code != null
        ? _ClientOtpDisplay(
            code: code,
            deliveryId: deliveryId,
            state: state,
          )
        : _ClientSmsFallback(state: state);
  }
}

/// G4: honest customer fallback when the app holds no code (e.g. reinstalled
/// mid-delivery). The `GET /otp` call the cubit just made TRIGGERED an SMS to
/// the recipient, so the surface says exactly that + offers a resend. There is
/// deliberately NO code-entry grid here — entering the code is the Jeeber's
/// job; the customer's job is to receive and share it.
class _ClientSmsFallback extends StatelessWidget {
  const _ClientSmsFallback({required this.state});

  final OtpHandoverState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      // QA: uiautomator-addressable handle for the SMS-fallback surface.
      identifier: 'otp_sms_fallback',
      container: true,
      child: _HandoffPage(
        content: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.xLarge,
            Spacing.twoXLarge,
            Spacing.xLarge,
            0,
          ),
          child: Semantics(
            liveRegion: true,
            child: JeebInfoNote.muted(
              icon: Icons.sms,
              title: l10n.otpClientSmsSentTitle,
              text: l10n.otpClientSmsSentBody,
            ),
          ),
        ),
        footer: JeebCtaFooter.single(
          child: Semantics(
            identifier: 'otp_sms_resend',
            container: true,
            child: JeebCtaButton.primary(
              key: const Key('otpHandover.resendSms'),
              label: l10n.otpClientResendSms,
              // The resend runs on its own axis now — `mode` no longer flips
              // to loading, so the surface stays readable while it is in
              // flight.
              isLoading: state.resending,
              isEnabled: !state.resending,
              onTap: () => context.read<OtpHandoverCubit>().resendSms(),
            ),
          ),
        ),
      ),
    );
  }
}

/// T-MOB-018 AC1/AC5: Client sees the code as four backlit-glass tiles,
/// announced via liveRegion.
///
/// MIDNIGHT R13 (`tpl 799-821`), top to bottom: arrival banner → "Say it or
/// show it" → the tiles → safety note → spacer → footer.
///
/// Footer hierarchy is the board's, restored: the SMS sentence, then the glass
/// dispute pill. The client's forward path to mutual rating survives as a
/// DEMOTED text action beneath it (doc-13 Pattern D — the board draws no
/// post-handover path; owner Q5 pending). There is no status polling, so
/// removing it outright would strand the client on this screen.
class _ClientOtpDisplay extends StatelessWidget {
  const _ClientOtpDisplay({
    required this.code,
    required this.deliveryId,
    required this.state,
  });

  final String code;
  final String deliveryId;
  final OtpHandoverState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = context.jeebText;
    final arrival = state.arrival;

    return _HandoffPage(
      content: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.xLarge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (arrival != null) ...[
              const SizedBox(height: _kBannerTopGap),
              HandoverArrivalBanner(arrival: arrival),
              const SizedBox(height: _kInstructionTopGap),
            ] else
              const SizedBox(height: _kInstructionTopGapNoBanner),
            Text(
              l10n.otpClientShareInstruction,
              style: text.titleProminent.copyWith(color: scheme.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: _kInstructionSubtitleGap),
            Text(
              // Never render a placeholder name: the arrival read is
              // best-effort, so the generic line is the honest default.
              arrival != null
                  ? l10n.otpClientShareSubtitleNamed(arrival.name)
                  : l10n.otpClientShareSubtitle,
              // Periwinkle IS the muted ink on navy — pass-1's brown AA
              // stopgap died with the light theme (plan §2.1).
              style: text.body.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: _kCodeTopGap),
            HandoverCodeDisplay(code: code),
            const SizedBox(height: _kSafetyNoteTopGap),
            JeebInfoNote.muted(
              icon: Icons.shield,
              text: l10n.otpClientDoNotShare,
              // The board draws this note on the stacked metrics even though
              // it has no title (`tpl 813`).
              padding: JeebInfoNote.stackedPadding,
              gap: JeebInfoNote.stackedGap,
              iconSize: JeebInfoNote.stackedIconSize,
            ),
          ],
        ),
      ),
      footer: JeebCtaFooter.single(
        spacing: _kFooterStackGap,
        below: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JeebCtaButton.outline(
              label: l10n.otpDisputeCta,
              identifier: 'otp_handover_dispute',
              // `push`, not `go`: BACK from the dispute form returns to the
              // code.
              onTap: () => context.push('/orders/$deliveryId/escalate'),
            ),
            Semantics(
              // QA: uiautomator-addressable handle for the client's rate-now
              // action. Kept in screen code, wrapping the kit button, so
              // `tester.getSemantics(find.byKey(...))` still resolves it.
              identifier: 'client_otp_rate_now',
              child: JeebCtaButton.text(
                key: const Key('otpHandover.clientRateNow'),
                label: l10n.otpRateNowCta,
                onTap: () => context.go(_mutualRateRoute(deliveryId, true)),
              ),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    l10n.otpClientResendSmsPrompt,
                    style: text.bodySmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                JeebCtaButton.accentText(
                  label: l10n.otpClientResendSmsAction,
                  identifier: 'otp_handover_send_sms',
                  // Tight inset so the two halves read as one sentence, the
                  // way the board draws them.
                  contentPadding: const EdgeInsetsDirectional.symmetric(
                    horizontal: Spacing.twoXSmall,
                  ),
                  isEnabled: !state.resending,
                  onTap: () => context.read<OtpHandoverCubit>().resendSms(),
                ),
              ],
            ),
            if (state.resendFailed)
              // The id, the label and liveRegion must sit on ONE node, or the
              // announcement reads out as silence.
              Semantics(
                identifier: 'otp_handover_resend_error',
                label: l10n.otpResendFailed,
                liveRegion: true,
                container: true,
                explicitChildNodes: true,
                child: JeebInfoNote.error(text: l10n.otpResendFailed),
              ),
          ],
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
    if (widget.state.shakeKey == _lastShakeKey) return;
    _lastShakeKey = widget.state.shakeKey;
    // Reduce motion: no shake. The error headline, its liveRegion and the
    // attempt counter carry the whole message without moving anything.
    if (MediaQuery.disableAnimationsOf(context)) return;
    _shakeCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _HandoffPage(
      content: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.xLarge,
          Spacing.twoXLarge,
          Spacing.xLarge,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OtpInstruction(state: widget.state),
            const SizedBox(height: Spacing.xLarge),
            _ShakingOtpInput(
              shakeAnim: _shakeAnim,
              hasError: widget.state.errorKind == OtpHandoverErrorKind.invalidOtp,
              onChanged: (v) => setState(() => _code = v),
              onCompleted: _onCompleted,
            ),
            _AttemptHint(state: widget.state),
          ],
        ),
      ),
      footer: JeebCtaFooter.single(
        child: _SubmitButton(
          code: _code,
          isSubmitting: widget.state.mode == OtpHandoverViewMode.submitting,
          onSubmit: _onSubmit,
        ),
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
    final scheme = Theme.of(context).colorScheme;
    final hasError = state.errorKind != null;
    return Semantics(
      liveRegion: hasError,
      child: Text(
        hasError ? _errorText(l10n) : l10n.otpJeeberInstruction,
        style: context.jeebText.titleProminent.copyWith(
          color: hasError ? scheme.error : scheme.onSurface,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _errorText(AppLocalizations l10n) => switch (state.errorKind) {
    OtpHandoverErrorKind.invalidOtp => l10n.errorInvalidCode,
    OtpHandoverErrorKind.notAtDoor => l10n.otpHandoverNotAtDoor,
    OtpHandoverErrorKind.wrongParty => l10n.otpHandoverWrongParty,
    OtpHandoverErrorKind.notFound => l10n.errorNotFoundBody,
    OtpHandoverErrorKind.locked => l10n.otpHandoverLockedBody,
    _ => failureCopy(l10n, otpHandoverFailure(state.errorKind)).body,
  };
}

class _ShakingOtpInput extends StatelessWidget {
  const _ShakingOtpInput({
    required this.shakeAnim,
    required this.hasError,
    required this.onChanged,
    required this.onCompleted,
  });

  final Animation<double> shakeAnim;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
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
        // Kept as OmdsOtpInput, restyled with the kit's own entry metrics:
        // only OMDS can land the per-cell ids on the editable TextField leaf
        // (RC-7), so `JeebCodeCells.input74` — which is presentation-only —
        // cannot replace it here.
        child: OmdsOtpInput(
          key: const Key('otpHandover.input'),
          length: 4,
          // RC-7: per-cell editable ids (`otp_handover_input_0..3`) so a UI
          // test driver can tap+inputText each cell of the jeeber at-door entry
          // (the single container id above cannot distribute a multi-digit
          // string across the N separate fields). Additive — mirrors the
          // `verify_code_input` / `phone_otp_input` entry surfaces.
          identifier: 'otp_handover_input',
          boxWidth: JeebCodeCells.inputBoxWidth,
          boxHeight: JeebCodeCells.inputBoxHeight,
          spacing: JeebCodeCells.inputCellGap,
          // Glass, matching JeebCodeCells' own cells — the jeeber leg is not
          // on the board, so it borrows the kit's grammar.
          fillColor: glass.glassFillEmphasis,
          focusedBorderColor: context.jeebRoles.accent,
          errorBorderColor: scheme.error,
          hasError: hasError,
          textStyle: context.jeebText.codeInput.copyWith(
            color: scheme.onSurface,
          ),
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
    if (state.wrongAttempts == 0 && state.attemptsRemaining == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final remaining = state.attemptsRemaining ??
        (OtpHandoverState.maxAttempts - state.wrongAttempts);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Spacing.small),
      child: Semantics(
        liveRegion: true,
        child: Text(
          l10n.otpHandoverAttemptsRemaining(remaining),
          style: context.jeebText.caption.copyWith(color: scheme.error),
          textAlign: TextAlign.center,
        ),
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
      // `button: true` here — the CTA already exposes the button role;
      // `container: true` keeps this identifier its own queryable node.
      identifier: 'otp_handover_submit',
      container: true,
      child: JeebCtaButton.primary(
        key: const Key('otpHandover.submit'),
        label: l10n.otpVerifyButton,
        isLoading: isSubmitting,
        isEnabled: code.length == 4 && !isSubmitting,
        onTap: onSubmit,
      ),
    );
  }
}
