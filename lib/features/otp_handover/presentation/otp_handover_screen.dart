import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/otp_handover_cubit.dart';
import '../application/otp_handover_state.dart';
import 'widgets/handover_code_display.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/otp_handover_screen_fixtures.dart';
import '../domain/handover_code_store.dart';
import '../domain/otp_handover_repository.dart';

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
      explicitChildNodes: true,
      child: Scaffold(
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
      ),
    );
  }

  bool _shouldListen(OtpHandoverState prev, OtpHandoverState next) =>
      next.escalate && !prev.escalate ||
      next.mode == OtpHandoverViewMode.success &&
          prev.mode != OtpHandoverViewMode.success;

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
            Semantics(
              identifier: 'otp_done_rate_now',
              container: true,
              button: true,
              child: OmdsLoadingButton(
                text: l10n.otpRateNowCta,
                isLoading: false,
                isEnabled: true,
                onTap: () => context.go(_mutualRateRoute(deliveryId, isClient)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    if (!isClient) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.xLarge),
        child: _JeeberOtpEntry(state: state),
      );
    }
    final code = state.handoverCode;
    return Padding(
      padding: const EdgeInsets.all(Spacing.xLarge),
      child: code != null
          ? _ClientOtpDisplay(code: code, deliveryId: deliveryId)
          : _ClientSmsFallback(state: state),
    );
  }
}

class _ClientSmsFallback extends StatelessWidget {
  const _ClientSmsFallback({required this.state});

  final OtpHandoverState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Semantics(
        identifier: 'otp_sms_fallback',
        container: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sms_outlined,
              size: Sizes.fiveXLarge,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: Spacing.large),
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.otpClientSmsSentTitle,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: Spacing.small),
            Text(
              l10n.otpClientSmsSentBody,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.xLarge),
            Semantics(
              identifier: 'otp_sms_resend',
              container: true,
              child: OmdsLoadingButton(
                key: const Key('otpHandover.resendSms'),
                text: l10n.otpClientResendSms,
                isLoading: state.mode == OtpHandoverViewMode.loading,
                isEnabled: state.mode != OtpHandoverViewMode.loading,
                onTap: () => context.read<OtpHandoverCubit>().resendSms(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          HandoverCodeDisplay(code: code),
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

class _ClientRateNowButton extends StatelessWidget {
  const _ClientRateNowButton({required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'client_otp_rate_now',
      child: OmdsPrimaryButton(
        key: const Key('otpHandover.clientRateNow'),
        text: l10n.otpRateNowCta,
        onTap: () => context.go(_mutualRateRoute(deliveryId, true)),
      ),
    );
  }
}

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
    return Semantics(
      liveRegion: hasError,
      child: Text(
        hasError ? _errorText(l10n) : l10n.otpJeeberInstruction,
        style: theme.textTheme.titleMedium?.copyWith(
          color: hasError ? theme.colorScheme.error : null,
        ),
        textAlign: TextAlign.center,
      ),
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
          // string across the N separate fields). Additive — mirrors the
          identifier: 'otp_handover_input',
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
      child: Semantics(
        liveRegion: true,
        child: Text(
          l10n.otpAttemptsRemaining(remaining),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/otp_handover/otp_handover_screen_preview_test.dart
// ===========================================================================
//
// [OtpHandoverScreen] is the at-door handover (T-MOB-018 / sprint-009 G4) and it
// is really TWO screens behind one class: `isClient` picks the customer's
// SHOW-a-code surface or the jeeber's ENTER-a-code surface, and the two share
// nothing but the app bar and the loading/error branches. Every state below
// names its side, because a mis-set `isClient` is the defect this screen has
// already shipped once (G4: the customer was flipped into the jeeber's entry
// grid — a dead end for a code they were never shown).
//
// The scripted repository, the in-memory code store and the cubit pre-drives are
// NOT declared here. They live in
// `lib/devtool/catalog/fixtures/otp_handover_screen_fixtures.dart`, shared with
// the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_08_entries.dart`), so the designer's in-app
// browser and this canvas cannot drift into showing two different "Jeeber —
// Wrong Code". Nothing there can reach the network: every answer is a const
// value, an error, or a `Completer` that is never completed.
//
// Four things about this harness are worth knowing before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and this
//    screen's `Scaffold + OMDSAppBar` paints inside it. Same nesting the Screen
//    Catalog produces.
//  * **The frame is pinned in the TREE, not just in `size:`.**
//    [_otpHandoverScreenFramed] pins the same box the annotation asks for, so a
//    render test measures a phone rather than the 800x600 test surface. NOTHING
//    on this screen scrolls — every body is a `Center` over a bare `Column` —
//    so here the HEIGHT is load-bearing too.
//  * **There is no seed seam.** `OtpHandoverCubit` takes a repository and starts
//    working in its constructor, so a state is reached by scripting the
//    collaborator and pre-driving the cubit, exactly as production reaches it.
//    The pre-drive is fire-and-forget (a `create:` callback cannot await), which
//    is why the escalate transition lands after the first frame — and therefore
//    why the dialog opens at all.
//  * **Tapping is not previewing.** Both CTAs that leave this screen — the
//    dialog's Escalate and "Rate your Jeeber" — call `context.go`, and there is
//    no [GoRouter] above a preview card, so tapping them throws. (The app bar's
//    back arrow is safe: `OMDSAppBar` defaults to `Navigator.maybePop`, which
//    no-ops when nothing can be popped.) Every state below is reached by
//    pre-driving instead.
//
// The states are the seven the Screen Catalog names plus five it does not, and
// the extra five are where this screen is worth looking at:
//
//   * **The customer's cold read** — the first frames of every entry on the
//     client side, and the state a slow gateway leaves up indefinitely.
//   * **The verify POST in flight** — the only state where the jeeber's OTP grid
//     is live under a button that has stopped accepting taps.
//   * **Past the cap** — a fourth wrong attempt, which the attempts hint counts
//     into the NEGATIVE.
//   * **The shipping code on the 320 pt floor** — where 200% text pushes the
//     rate-now CTA off a screen that cannot scroll.
//   * **A widened code on the same floor** — the customer's hero panel with more
//     digits than it was designed for, which wraps mid-number at 1x already.

/// The phone this screen is designed against.
const Size _otpHandoverScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _otpHandoverScreenCompactBox = Size(320, 568);

/// Pins [screen] to a device-sized frame inside whatever box the host gives it.
Widget _otpHandoverScreenFramed(Widget screen, Size box) => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: box.width, height: box.height, child: screen),
    );

/// Mounts the screen under the [OtpHandoverCubit] its route provides, scripted
/// into one designed state.
///
/// [muteTicker] freezes indefinite animations. Both spinners on this screen —
/// the full-screen [OmdsLoadingState] and the one [OmdsLoadingButton] paints
/// over its label — are `CircularProgressIndicator`s, which never stop
/// scheduling frames, and the render tests' `pumpAndSettle` would hang on them.
/// Muting still paints the arc; it just stops it turning, which is what a static
/// canvas wanted anyway.
Widget _otpHandoverScreenHosted({
  required bool isClient,
  required OtpHandoverRepository repository,
  HandoverCodeStore? codeStore,
  Future<void> Function(OtpHandoverCubit cubit)? drive,
  Size box = _otpHandoverScreenPhoneBox,
  bool muteTicker = false,
}) {
  final Widget screen = BlocProvider<OtpHandoverCubit>(
    create: (_) => OtpHandoverScreenPreviewFixtures.cubit(
      isClient: isClient,
      repository: repository,
      codeStore: codeStore,
      drive: drive,
    ),
    child: OtpHandoverScreen(
      deliveryId: OtpHandoverScreenPreviewFixtures.deliveryId,
      isClient: isClient,
    ),
  );
  return _otpHandoverScreenFramed(
    muteTicker ? TickerMode(enabled: false, child: screen) : screen,
    box,
  );
}

/// Runs a pre-drive to completion BEFORE the screen is mounted over the cubit.
///
/// Every other state uses [_otpHandoverScreenHosted], where the drive runs after
/// the first frame and the screen's `BlocConsumer` therefore sees each
/// transition. That is the honest mount path, and for one state it is in the
/// way: reaching a FOURTH wrong attempt means passing the escalate cap four
/// times, and each pass opens a dialog that nothing in a preview can dismiss —
/// four stacked modals over the body the preview exists to show.
///
/// Mounting late is not a cheat, it is the same state a jeeber is looking at
/// after they tap Cancel: `escalate` cleared, the attempts spent, the body back.
/// It is deliberately NOT used for [otpHandoverScreenJeeberEscalated], where the
/// dialog IS the state under review.
class _OtpHandoverScreenPreDriven extends StatefulWidget {
  const _OtpHandoverScreenPreDriven({
    required this.repository,
    required this.drive,
  });

  final OtpHandoverRepository repository;
  final Future<void> Function(OtpHandoverCubit cubit) drive;

  @override
  State<_OtpHandoverScreenPreDriven> createState() =>
      _OtpHandoverScreenPreDrivenState();
}

class _OtpHandoverScreenPreDrivenState
    extends State<_OtpHandoverScreenPreDriven> {
  late final OtpHandoverCubit _cubit = OtpHandoverScreenPreviewFixtures.cubit(
    isClient: false,
    repository: widget.repository,
  );

  bool _driven = false;

  @override
  void initState() {
    super.initState();
    _drive();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _drive() async {
    await widget.drive(_cubit);
    if (mounted) setState(() => _driven = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_driven) return const SizedBox.shrink();
    return BlocProvider<OtpHandoverCubit>.value(
      value: _cubit,
      child: const OtpHandoverScreen(
        deliveryId: OtpHandoverScreenPreviewFixtures.deliveryId,
        isClient: false,
      ),
    );
  }
}

// ─────────────────────────────── client side ────────────────────────────────

/// The customer's reference reading: the code is on the device, so the screen
/// resolves without touching the gateway at all.
///
/// `_loadHandoverCode` reads the [HandoverCodeStore] FIRST and returns on a hit,
/// which is the only path that reaches this body quickly — and the only one
/// left for a delivery whose SMS already went out. The hero panel is
/// [HandoverCodeDisplay] at `displayLarge`, sized to be read at arm's length off
/// a phone held up to a stranger.
@JeebPreview(
  group: 'otp_handover',
  name: 'Client · code ready',
  size: _otpHandoverScreenPhoneBox,
)
Widget otpHandoverScreenClientCodeReady() => _otpHandoverScreenHosted(
      isClient: true,
      repository: OtpHandoverScreenPreviewFixtures.accepting(),
      codeStore: OtpHandoverScreenPreviewFixtures.codeStore(),
    );

/// What the LIVE gateway actually answers (G4): `GET /otp` triggers an SMS and
/// returns no code, so the customer's own screen never shows one.
///
/// This is the default reading of the customer side, not an edge case — and it
/// is the one the copy has to carry alone: `otpClientSmsSentBody` is the longest
/// string on either side of this screen, a full sentence in EN and a longer one
/// in AR, over a centred `Column` with no scroll view anywhere above it. It
/// still clears a 390 x 844 phone at 200% text (measured through the real Inter
/// and Noto faces), which is why the matrix slots went to the two compact states
/// instead.
///
/// The resend button under it is worth a second look. `isLoading` is wired to
/// `state.mode == loading`, but `_OtpBody` switches the WHOLE body to the
/// full-screen spinner in that mode — so the in-place loading state of this
/// button cannot be reached, and a customer who taps resend loses the sentence
/// that told them why they are waiting.
@JeebPreview(
  group: 'otp_handover',
  name: 'Client · SMS fallback',
  size: _otpHandoverScreenPhoneBox,
)
Widget otpHandoverScreenClientSmsFallback() => _otpHandoverScreenHosted(
      isClient: true,
      repository: OtpHandoverScreenPreviewFixtures.accepting(),
    );

/// The cold read FAILED on the transport: the classified network copy with a
/// Retry.
///
/// The customer is at the door when this appears, so the retry is the whole
/// surface — and it is the only affordance on it. Note the error body is a bare
/// `Center` with no pull-to-refresh and nothing that scrolls; whether the retry
/// is reachable is a pure question of how tall the frame is.
@JeebPreview(
  group: 'otp_handover',
  name: 'Client · load failed',
  size: _otpHandoverScreenPhoneBox,
)
Widget otpHandoverScreenClientLoadError() => _otpHandoverScreenHosted(
      isClient: true,
      repository: OtpHandoverScreenPreviewFixtures.failingFetch(),
    );

/// The cold read still in flight — the first frames of every customer entry.
///
/// `OtpHandoverCubit` emits [OtpHandoverViewMode.loading] from its constructor
/// and stays there until `GET /otp` answers, so every customer sees this; on a
/// slow network they see it for as long as the gateway takes, with no timeout
/// behind it. What they get is a bare spinner under the app bar: no copy, no
/// "sending your code", nothing that says an SMS is being triggered on their
/// behalf.
///
/// Its ticker is muted so the render tests can settle — see
/// [_otpHandoverScreenHosted].
@JeebPreview(
  group: 'otp_handover',
  name: 'Client · code still loading',
  size: _otpHandoverScreenPhoneBox,
)
Widget otpHandoverScreenClientLoading() => _otpHandoverScreenHosted(
      isClient: true,
      repository: OtpHandoverScreenPreviewFixtures.stalledFetch(),
      muteTicker: true,
    );

// ─────────────────────────────── jeeber side ────────────────────────────────

/// The jeeber's reference reading: an empty 4-cell grid and a disabled Verify.
///
/// Jeeber mode never fetches — the cubit emits `ready` synchronously in its
/// constructor — so this is the first frame, not a resolved one. `Verify OTP`
/// is disabled until `code.length == 4`; that gate and the grid's fixed four
/// cells are the WHOLE of the 4-digit contract in this feature. The customer's
/// side enforces nothing and shows whatever the gateway sent — see
/// [otpHandoverScreenWidenedCodeCompact].
@JeebPreview(
  group: 'otp_handover',
  name: 'Jeeber · code entry',
  size: _otpHandoverScreenPhoneBox,
)
Widget otpHandoverScreenJeeberCodeEntry() => _otpHandoverScreenHosted(
      isClient: false,
      repository: OtpHandoverScreenPreviewFixtures.accepting(),
    );

/// One rejected verify (AC3): the instruction turns into the error copy and an
/// attempts hint appears under the grid.
///
/// Three things change at once and only two of them are visible in a still
/// frame — the instruction swaps to `otpWrongCode` in `colorScheme.error`, the
/// hint appears reading 2 remaining, and the grid shakes (a 400 ms
/// [TweenSequence] driven off `state.shakeKey`). The hint is the only thing on
/// screen that counts, which is why the render test pins the NUMBER rather than
/// the sentence.
@JeebPreview(
  group: 'otp_handover',
  name: 'Jeeber · wrong code',
  size: _otpHandoverScreenPhoneBox,
)
Widget otpHandoverScreenJeeberWrongCode() => _otpHandoverScreenHosted(
      isClient: false,
      repository: OtpHandoverScreenPreviewFixtures.rejectingSubmit(),
      drive: OtpHandoverScreenPreviewFixtures.driveWrongCode,
    );

/// The verify POST in flight: the button paints a spinner over its label.
///
/// The state to look at is what stays LIVE underneath. `OmdsOtpInput` is never
/// disabled — its cells still take focus and still accept digits while a verify
/// is in flight, so the jeeber can rewrite the code they just sent and watch it
/// change under a request that is already gone. Nothing is re-submitted (both
/// `_onCompleted` and `OtpHandoverCubit.submitOtp` guard on
/// `mode == submitting`), which is the point: the input responds and means
/// nothing. The button is the only control that visibly stops.
///
/// There is no timeout on this path either: `submitOtp` awaits the repository
/// and nothing else, so a request that never answers leaves the jeeber here with
/// the customer's door open in front of them.
///
/// Its ticker is muted so the render tests can settle — see
/// [_otpHandoverScreenHosted].
@JeebPreview(
  group: 'otp_handover',
  name: 'Jeeber · verifying',
  size: _otpHandoverScreenPhoneBox,
)
Widget otpHandoverScreenJeeberSubmitting() => _otpHandoverScreenHosted(
      isClient: false,
      repository: OtpHandoverScreenPreviewFixtures.stalledSubmit(),
      drive: OtpHandoverScreenPreviewFixtures.driveSuccessfulSubmit,
      muteTicker: true,
    );

/// The cap (AC4): three wrong codes, and the escalate dialog over the grid.
///
/// The dialog is not decoration — it is the only thing standing between the
/// jeeber and a dispute, and `submitOtp` returns early while `escalate` is set,
/// so the screen is genuinely blocked until one of its two buttons is tapped.
/// Escalate routes to `/orders/:id/escalate`; Cancel calls `dismissEscalate`,
/// which clears the flag AND the inline error but NOT the attempts — leaving the
/// hint at 0 remaining over an instruction that no longer mentions a problem.
///
/// Behind the modal, the hint reads `0 attempt(s) remaining` while the dialog
/// itself offers a Cancel that lets the jeeber try again. The two disagree, and
/// [otpHandoverScreenPastTheCap] is what the disagreement costs.
@JeebPreview(
  group: 'otp_handover',
  name: 'Jeeber · attempts spent',
  size: _otpHandoverScreenPhoneBox,
)
Widget otpHandoverScreenJeeberEscalated() => _otpHandoverScreenHosted(
      isClient: false,
      repository: OtpHandoverScreenPreviewFixtures.rejectingSubmit(),
      drive: OtpHandoverScreenPreviewFixtures.driveToEscalation,
    );

/// A FOURTH wrong attempt, after the dialog was cancelled — the hint has gone
/// negative.
///
/// `_AttemptHint` renders `maxAttempts - wrongAttempts` with no floor
/// (`OtpHandoverState.maxAttempts` is 3), and nothing caps `wrongAttempts`:
/// `_incrementWrongAttempts` adds one every time and re-arms `escalate`, while
/// `dismissEscalate` clears the flag so the next submit gets through. So the
/// count runs 2 → 1 → 0 → **-1**, and the copy is `{count} attempt(s)
/// remaining` — a plain substitution, in EN and in AR.
///
/// The instruction above it is the second half of the defect: `dismissEscalate`
/// passes `clearError: true`, so the red "Incorrect code" line is gone and the
/// screen reads as neutral while the hint under it reports a negative budget.
///
/// Mounted through [_OtpHandoverScreenPreDriven] so the four dialogs this took
/// are not stacked over the body — see that class for why that is honest.
@JeebPreview(
  group: 'otp_handover',
  name: 'Jeeber · past the cap',
  size: _otpHandoverScreenPhoneBox,
)
Widget otpHandoverScreenPastTheCap() => _otpHandoverScreenFramed(
      _OtpHandoverScreenPreDriven(
        repository: OtpHandoverScreenPreviewFixtures.rejectingSubmit(),
        drive: OtpHandoverScreenPreviewFixtures.driveBeyondCap,
      ),
      _otpHandoverScreenPhoneBox,
    );

/// The accepted verify: the handover is done.
///
/// The terminal state of the whole delivery journey, and the only body on this
/// screen with a positive tone. Note it is JEEBER-side: `isClient` is threaded
/// into the rate-now route (`?mode=jeeber`) but not into the copy, so the
/// customer — who cannot reach this body at all, having never submitted
/// anything — would be told "Rate your Jeeber" if they ever did.
@JeebPreview(
  group: 'otp_handover',
  name: 'Jeeber · handover done',
  size: _otpHandoverScreenPhoneBox,
)
Widget otpHandoverScreenJeeberSuccess() => _otpHandoverScreenHosted(
      isClient: false,
      repository: OtpHandoverScreenPreviewFixtures.accepting(),
      drive: OtpHandoverScreenPreviewFixtures.driveSuccessfulSubmit,
    );

// ────────────────────────────── layout ceiling ──────────────────────────────
//
// Both states below are the SHIPPING customer body on the 320 pt floor, and
// they are the two the matrix flag is spent on, because the English 1x reading
// of this screen looks fine long after the other two columns have broken.
//
// Measured on the 320 x 568 frame through the REAL Inter and Noto faces (the
// test face is ~2x too wide for Latin and ~2.4x for Arabic, so numbers taken
// under it describe no device):
//
// | state | code panel | body overflow |
// |---|---|---|
// | 4 digits, 1.0  | 184.1 x 64, one line   | fits |
// | 4 digits, 2.0  | 208 x 256, two lines   | 96 pt EN / 66 pt AR |
// | 6 digits, 1.0  | 208 x 128, two lines   | fits |
// | 6 digits, 2.0  | 208 x 384, three lines | 224 pt EN / 194 pt AR |
//
// The overflow is not a clip: `_ClientOtpDisplay` is a `Center` over a bare
// `Column` inside `EdgeInsets.all(Spacing.xLarge)`, and NOTHING on this screen
// scrolls — so what runs off the bottom is the "Rate your Jeeber" CTA, and there
// is no gesture that brings it back.

/// The shipping four-digit code on the narrowest phone the app supports.
///
/// At 1x this is unremarkable, which is the point of matrixing it: the state
/// that breaks is the 200% column, where the panel's glyphs double while its
/// fixed 12 pt letter-spacing and 64 pt of padding do not. The code re-flows
/// onto two lines and the body runs 96 pt past the bottom of the frame, taking
/// the rate-now CTA with it. A customer on a small phone with large text set is
/// exactly the customer who most needs to read these four digits.
///
/// The AR column is the second reason: the screen mirrors around the panel and
/// the digits must NOT, which the [Directionality] pin inside
/// [HandoverCodeDisplay] is all that holds.
@JeebPreview(
  group: 'otp_handover',
  name: 'Client · code ready · compact 320',
  size: _otpHandoverScreenCompactBox,
  matrix: true,
)
Widget otpHandoverScreenClientCodeReadyCompact() => _otpHandoverScreenHosted(
      isClient: true,
      repository: OtpHandoverScreenPreviewFixtures.accepting(),
      codeStore: OtpHandoverScreenPreviewFixtures.codeStore(
        OtpHandoverScreenPreviewFixtures.compactCode,
      ),
      box: _otpHandoverScreenCompactBox,
    );

/// Longest content: a code the gateway widened past four digits, on the same
/// floor.
///
/// Nothing on the customer's path enforces the 4-digit contract — the parsers
/// keep whatever string the accept response carried and [HandoverCodeDisplay]
/// renders it verbatim — so this is one gateway change away from shipping. Only
/// the JEEBER's submit button carries the contract (`code.length == 4`), which
/// means a widened code would leave the customer showing digits the jeeber's
/// grid cannot accept.
///
/// Here the failure is already visible at 1x: six digits want 283.6 pt of the
/// 208 pt the panel can give them, and the panel cannot shrink (no `FittedBox`,
/// no `maxLines`), so the code RE-FLOWS MID-NUMBER — `4819` over `02`, which
/// reads as two numbers rather than one. At 200% it is three lines and 224 pt of
/// the body is off-screen.
@JeebPreview(
  group: 'otp_handover',
  name: 'Longest content · widened code · compact 320',
  size: _otpHandoverScreenCompactBox,
  matrix: true,
)
Widget otpHandoverScreenWidenedCodeCompact() => _otpHandoverScreenHosted(
      isClient: true,
      repository: OtpHandoverScreenPreviewFixtures.accepting(),
      codeStore: OtpHandoverScreenPreviewFixtures.codeStore(
        OtpHandoverScreenPreviewFixtures.widenedCode,
      ),
      box: _otpHandoverScreenCompactBox,
    );
