import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/kyc_wizard_cubit.dart';
import '../../application/kyc_wizard_state.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../domain/kyc_contract_template.dart';
import '../../domain/kyc_form_schema.dart';
import '../../domain/kyc_gateway.dart';
import '../../domain/kyc_submission.dart';

enum _ProbeSource { scheduled, resume }

/// Loading state rendered while [KycWizardCubit.submit] is in flight.
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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// A phone body box: 390 dp wide, and as tall as an 844 dp phone leaves once
/// the wizard's own AppBar, status bar and home indicator are taken out. Same
const Size _kycSubmittingViewWizardBody = Size(390, 700);

/// The small-phone floor: a 320x568 handset (iPhone SE 1 / a 320 dp Android)
/// minus the same chrome. The copy here is three lines of prose in a `Column`
const Size _kycSubmittingViewSmallBody = Size(320, 480);

/// How long the safety net needs to reach each state, in frames.
/// `2 s` grace + `2 s` × 5 scheduled probes = the full automatic budget at
const Duration _kycSubmittingViewFirstProbe = Duration(milliseconds: 2200);
const Duration _kycSubmittingViewBudgetSpent = Duration(milliseconds: 10500);

/// Canned, in-memory [KycGateway] for previews.
/// It answers exactly one endpoint — `GET /v1/kyc/status` — because that is the
/// only one this view can reach (through [KycWizardCubit.refreshWhileSubmitting]).
class _KycSubmittingViewPreviewGateway implements KycGateway {
  _KycSubmittingViewPreviewGateway(this.snapshot, {this.resolvedReads = 1 << 20});

  /// What every resolved status read answers with. [KycStatus.notSubmitted] is
  /// "the server has no record of this submission yet", which is precisely the
  final KycSubmission snapshot;

  /// How many status reads resolve before the gateway goes silent.
  final int resolvedReads;

  int _reads = 0;

  @override
  Future<KycSubmission> fetchStatus() {
    _reads++;
    if (_reads > resolvedReads) return Completer<KycSubmission>().future;
    return Future<KycSubmission>.value(snapshot);
  }

  @override
  Future<KycFormSchema> fetchFormSchema({String variant = 'national_id'}) {
    throw UnsupportedError('KycSubmittingView never loads the form schema.');
  }

  @override
  Future<KycContractTemplate> fetchContractTemplate() {
    throw UnsupportedError('KycSubmittingView never loads the ToS template.');
  }

  @override
  Future<KycSignStamp> signContract({
    required String templateId,
    required String tosVersion,
    required String signatureBlob,
  }) {
    throw UnsupportedError('KycSubmittingView never signs the ToS.');
  }

  @override
  Future<KycSubmission> submit(KycSubmission draft) {
    throw UnsupportedError(
      'KycSubmittingView is mounted because a submit is ALREADY in flight; '
      'it never starts one.',
    );
  }
}

/// A wizard cubit parked on the step this view renders, exactly as
/// `test/kyc_submitting_view_test.dart` builds it.
class _KycSubmittingViewCubit extends KycWizardCubit {
  _KycSubmittingViewCubit(KycGateway gateway)
      : super(pickerService: StubPhotoPickerService(), gateway: gateway) {
    emit(state.copyWith(step: KycWizardStep.submitting));
  }
}

/// Keeps frames scheduled for [duration], then stops.
/// The view arms a real [Timer] in `initState` and exposes no seam to shorten
/// it, so the only way to see a state that lives past the 2 s grace window is
class _KycSubmittingViewFrameClock extends StatefulWidget {
  const _KycSubmittingViewFrameClock({
    required this.duration,
    required this.child,
  });

  final Duration duration;
  final Widget child;

  @override
  State<_KycSubmittingViewFrameClock> createState() =>
      _KycSubmittingViewFrameClockState();
}

class _KycSubmittingViewFrameClockState
    extends State<_KycSubmittingViewFrameClock>
    with SingleTickerProviderStateMixin {
  AnimationController? _clock;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _clock?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Mounts the view the way `KycWizardScreen` does — as the whole body of the
/// wizard, under an ambient [KycWizardCubit] sitting on
Widget _kycSubmittingViewHosted({
  KycGateway? gateway,
  Duration runFor = _kycSubmittingViewFirstProbe,
}) {
  const Widget view = TickerMode(
    enabled: false,
    child: KycSubmittingView(),
  );
  return _KycSubmittingViewFrameClock(
    duration: runFor,
    child: gateway == null
        ? view
        : BlocProvider<KycWizardCubit>(
            lazy: false,
            create: (_) => _KycSubmittingViewCubit(gateway),
            child: view,
          ),
  );
}

/// The view's own pixels, with no wizard around it.
/// This is the reading to review for layout, contrast and RTL: an 88 dp icon
@JeebPreview(
  group: 'kyc',
  name: 'Spinner only · no wizard cubit',
  size: _kycSubmittingViewWizardBody,
)
Widget kycSubmittingViewDetached() => _kycSubmittingViewHosted();

/// The normal few seconds: the submit is in flight and the server has no record
/// of it yet, so every safety-net probe comes back `notSubmitted` and correctly
@JeebPreview(
  group: 'kyc',
  name: 'Probe budget spent · nothing recorded',
  size: _kycSubmittingViewWizardBody,
)
Widget kycSubmittingViewBudgetSpent() => _kycSubmittingViewHosted(
      gateway: _KycSubmittingViewPreviewGateway(
        const KycSubmission(status: KycStatus.notSubmitted),
      ),
      runFor: _kycSubmittingViewBudgetSpent,
    );

/// JEBV4-259/271, the defect this view was built around: `submit()` HANGS — a
/// half-open CDN-upload socket — and the status read hangs with it.
@JeebPreview(
  group: 'kyc',
  name: 'Submit HUNG · status read never answers',
  size: _kycSubmittingViewWizardBody,
)
Widget kycSubmittingViewHung() => _kycSubmittingViewHosted(
      gateway: _KycSubmittingViewPreviewGateway(
        const KycSubmission(status: KycStatus.notSubmitted),
        resolvedReads: 0,
      ),
    );

/// The safety net doing its job: the client never saw the 201, but the server
/// has the submission recorded (`pending`), so the first probe at t=2 s advances
@JeebPreview(
  group: 'kyc',
  name: 'Safety net fires · server recorded it',
  size: _kycSubmittingViewWizardBody,
)
Widget kycSubmittingViewSelfHeal() => _kycSubmittingViewHosted(
      gateway: _KycSubmittingViewPreviewGateway(
        const KycSubmission(status: KycStatus.pending),
      ),
    );

/// Layout ceiling: the same body on the 320 dp small-phone floor.
/// Nothing here scrolls — `_SubmittingBody` is a bare centred [Column] — so the
@JeebPreview(
  group: 'kyc',
  name: 'Small phone body (320x480)',
  size: _kycSubmittingViewSmallBody,
)
Widget kycSubmittingViewSmallPhone() => _kycSubmittingViewHosted();
