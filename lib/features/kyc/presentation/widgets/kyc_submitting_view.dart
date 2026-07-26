import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/kyc_wizard_cubit.dart';
import '../../application/kyc_wizard_state.dart';

enum _ProbeSource { scheduled, resume }

/// Loading state rendered while [KycWizardCubit.submit] is in flight.
///
/// The bare [CircularProgressIndicator] previously used here gave no signal
/// that the upload was running, what was being sent, or how long it would
/// take — users tapped Submit a second time mid-upload. This view restores
/// design parity with the other capture steps: an icon, a headline, body
/// copy, and a single in-line spinner row, with a live region semantic so
/// VoiceOver / TalkBack announce the state change.
///
/// JEBV4-259/271 — it also owns the submit-hang SAFETY NET. A healthy submit
/// (the gateway auto-approves at t+0) leaves this view within a few seconds, so
/// the net never fires. Only when `submit()` HANGS past [_graceBeforePoll] —
/// e.g. a stalled CDN upload or a 201 the client never receives — does the
/// poller start re-reading `GET /v1/kyc/status`; the moment the server shows
/// the submission recorded it advances the wizard off this spinner (see
/// [KycWizardCubit.refreshWhileSubmitting]) so an approved jeeber comes online
/// with NO force-stop+relaunch. Five scheduled probes and three app-resume
/// probes bound the mounted view to eight automatic requests. After both
/// budgets, recovery remains with the submit future, the CDN-upload timeout,
/// and [KycWizardCubit.onJeeberRoleGranted], not additional polling.
class KycSubmittingView extends StatefulWidget {
  const KycSubmittingView({super.key});

  static const Key rootKey = Key('kyc-submitting-root');
  static const Key titleKey = Key('kyc-submitting-title');
  static const Key spinnerKey = Key('kyc-submitting-spinner');

  @override
  State<KycSubmittingView> createState() => _KycSubmittingViewState();
}

class _KycSubmittingViewState extends State<KycSubmittingView>
    with WidgetsBindingObserver {
  /// Let the normal (fast, auto-approving) submit win before the net probes, so
  /// a healthy in-flight submit is never yanked off the spinner prematurely.
  ///
  /// JEBV4-271 (round 3): the reconcile poll is now a SHORT, BOUNDED retry
  /// (2s × [_maxProbes]) instead of the old 12s-grace + unbounded 3s cadence —
  /// the on-device rev2 spinner sat for minutes, so recovery must be prompt.
  /// The bound keeps it from polling forever if the server never records the
  /// submission (that branch is resolved by the CDN-upload timeout, not this
  /// poll); the app-root role-arrived listener ([KycWizardCubit.onJeeberRoleGranted])
  /// remains the timer-independent backstop.
  static const Duration _graceBeforePoll = Duration(seconds: 2);
  static const Duration _pollInterval = Duration(seconds: 2);
  static const int _maxProbes = 5;
  static const int _maxResumeProbes = 3;
  Timer? _timer;
  int _scheduledProbes = 0;
  int _resumeProbes = 0;
  bool _inFlight = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer(
      _graceBeforePoll,
      () => unawaited(_probe(_ProbeSource.scheduled)),
    );
  }

  void _armScheduledProbe() {
    _timer?.cancel();
    _timer = null;
    if (!_canArmScheduledProbe()) return;
    _timer = Timer(
      _pollInterval,
      () => unawaited(_probe(_ProbeSource.scheduled)),
    );
  }

  bool _canArmScheduledProbe() {
    if (!mounted || !_foreground || _inFlight) return false;
    if (_scheduledProbes >= _maxProbes) return false;
    final cubit = context.read<KycWizardCubit?>();
    return cubit?.state.step == KycWizardStep.submitting;
  }

  /// Cancel the pending scheduled probe without spending either request budget.
  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _onForeground();
    } else if (state != AppLifecycleState.inactive) {
      _onBackground();
    }
  }

  // ── FM-3 ADOPTION SEAM ────────────────────────────────────────────────────
  // The ONLY lifecycle entry points. When FM-3's pause/resume contract lands,
  // delete the WidgetsBindingObserver wiring and point its callbacks here.
  void _onForeground() {
    if (_foreground) return;
    _foreground = true;
    unawaited(_probe(_ProbeSource.resume));
    _armScheduledProbe();
  }

  void _onBackground() {
    _foreground = false;
    _stopPolling();
  }

  /// Ask the cubit to reconcile against the server while we are still stuck on
  /// the spinner. Concurrency deliberately lives here: guarding the shared
  /// cubit would drop a user refresh racing a poll, while this flag covers every
  /// scheduled and resume request owned by the view.
  Future<void> _probe(_ProbeSource source) async {
    if (!_canIssueProbe(source)) return;
    final cubit = context.read<KycWizardCubit?>();
    if (cubit == null) return;
    if (cubit.state.step != KycWizardStep.submitting) {
      _stopPolling();
      return;
    }
    _inFlight = true;
    _recordIssuedProbe(source);
    try {
      await cubit.refreshWhileSubmitting();
    } finally {
      _finishProbe(cubit);
    }
  }

  bool _canIssueProbe(_ProbeSource source) {
    if (!mounted || !_foreground || _inFlight) return false;
    return switch (source) {
      _ProbeSource.scheduled => _scheduledProbes < _maxProbes,
      _ProbeSource.resume => _resumeProbes < _maxResumeProbes,
    };
  }

  void _recordIssuedProbe(_ProbeSource source) {
    switch (source) {
      case _ProbeSource.scheduled:
        _scheduledProbes++;
      case _ProbeSource.resume:
        _resumeProbes++;
    }
  }

  void _finishProbe(KycWizardCubit cubit) {
    _inFlight = false;
    if (!mounted) return;
    if (cubit.state.step != KycWizardStep.submitting) {
      _stopPolling();
      return;
    }
    _armScheduledProbe();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: KycSubmittingView.rootKey,
      container: true,
      liveRegion: true,
      label: l10n.kycSubmittingTitle,
      hint: l10n.kycSubmittingBody,
      child: const Padding(
        padding: EdgeInsets.all(Spacing.large),
        child: _SubmittingBody(),
      ),
    );
  }
}

class _SubmittingBody extends StatelessWidget {
  const _SubmittingBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SubmittingIcon(scheme: theme.colorScheme),
        const SizedBox(height: Spacing.large),
        _SubmittingTitle(text: l10n.kycSubmittingTitle, theme: theme),
        const SizedBox(height: Spacing.small),
        _SubmittingBodyText(text: l10n.kycSubmittingBody, theme: theme),
        const SizedBox(height: Spacing.xLarge),
        const _SubmittingSpinner(),
      ],
    );
  }
}

class _SubmittingIcon extends StatelessWidget {
  const _SubmittingIcon({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: Sizes.nineXLarge,
        height: Sizes.nineXLarge,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.cloud_upload_outlined,
          size: Sizes.fourXLarge,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _SubmittingTitle extends StatelessWidget {
  const _SubmittingTitle({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      key: KycSubmittingView.titleKey,
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SubmittingBodyText extends StatelessWidget {
  const _SubmittingBodyText({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _SubmittingSpinner extends StatelessWidget {
  const _SubmittingSpinner();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        key: KycSubmittingView.spinnerKey,
        width: Sizes.xLarge,
        height: Sizes.xLarge,
        child: OmdsLoadingState(
          size: Sizes.xLarge,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
