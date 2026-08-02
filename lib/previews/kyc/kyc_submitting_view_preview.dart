/// Widget previews for [KycSubmittingView] — run with
/// `flutter widget-preview start`.
///
/// This is the spinner the wizard shows while `POST /v1/kyc/submit` is in
/// flight (`KycWizardStep.submitting`), and it is also the owner of the
/// JEBV4-259/271 submit-hang SAFETY NET: a bounded poller — five scheduled
/// probes 2 s apart plus three app-resume probes — that re-reads
/// `GET /v1/kyc/status` and advances the wizard off the spinner when the server
/// shows the submission already recorded.
///
/// **The whole point of these previews is that the four wired states below are
/// PIXEL-IDENTICAL.** The body is a fixed icon + headline + copy + spinner; it
/// takes no arguments and reads nothing off the cubit, so a healthy two-second
/// submit, a submit whose upload has stalled, a submit whose automatic recovery
/// budget is fully spent, and a submit the safety net has already rescued all
/// render exactly the same frame. Open them side by side in the canvas and look
/// for the difference — there is none, and there is no retry, no cancel, no
/// elapsed-time hint and no error branch. That is the finding, held as an
/// assertion in `test/previews/kyc/kyc_submitting_view_preview_test.dart`.
///
/// **What else the canvas shows.** Two things that only appear away from the
/// default reading, both pinned in the render test:
///
/// * **200% text puts the spinner off the bottom of the phone.**
///   `_SubmittingBody` is a centred [Column] with no scroll view, so on the
///   390x700 body below it overflows by 84 dp in EN and 124 dp in AR at the
///   accessibility ceiling, laying the spinner out at y=740 — below a 700 dp
///   viewport, with nothing to scroll it back. On the 320 dp small-phone box
///   the overflow is 528 dp (EN) / 344 dp (AR). At 100% text both boxes fit.
///   The one element that says "something is still happening" is the first
///   thing to leave the screen.
/// * **The live region stutters.** The [Semantics] container sets `label` and
///   `hint` from the same two ARB keys the body already renders as [Text], and
///   excludes neither, so the descendants merge into the container's label: a
///   screen reader announces the headline TWICE, then the body, then the body
///   again as the hint.
///
/// **Network-free by construction.** Every wired state is an ambient
/// [KycWizardCubit] built over [_PreviewKycGateway], a canned in-memory
/// [KycGateway]; no [Dio], no DI, no [DioKycGateway]. The guard in
/// [jeebPreviewHost] is the net, not the plan.
///
/// **Why [_FrameClock] exists.** Unlike [KycStatusView] — which takes an
/// injectable `KycPollSchedule` a preview can shorten to 10 ms — this view
/// hardcodes its schedule as private `static const`s (2 s grace, 2 s interval),
/// so a preview cannot shorten it and must instead let the clock run. The
/// spinner itself is frozen with [TickerMode] (an indeterminate
/// `CircularProgressIndicator` never stops scheduling frames, so the render
/// tests' `pumpAndSettle` would hang on it), which leaves nothing driving the
/// frame clock — and a frozen canvas would then park every state before its
/// first probe. [_FrameClock] keeps frames scheduled for exactly as long as the
/// state under review needs, and nothing longer.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/kyc/application/kyc_wizard_cubit.dart';
import '../../features/kyc/application/kyc_wizard_state.dart';
import '../../features/kyc/domain/kyc_contract_template.dart';
import '../../features/kyc/domain/kyc_form_schema.dart';
import '../../features/kyc/domain/kyc_gateway.dart';
import '../../features/kyc/domain/kyc_submission.dart';
import '../../features/kyc/presentation/widgets/kyc_submitting_view.dart';
import '../../features/photo_attachment/data/stub_photo_picker_service.dart';
import '../harness/jeeb_preview.dart';

/// A phone body box: 390 dp wide, and as tall as an 844 dp phone leaves once
/// the wizard's own AppBar, status bar and home indicator are taken out. Same
/// box as the [KycStatusView] previews, so the two halves of the KYC tail are
/// reviewed at the same scale.
const Size _wizardBody = Size(390, 700);

/// The small-phone floor: a 320x568 handset (iPhone SE 1 / a 320 dp Android)
/// minus the same chrome. The copy here is three lines of prose in a `Column`
/// with no scroll view, so this is where it stops fitting first.
const Size _smallBody = Size(320, 480);

/// How long the safety net needs to reach each state, in frames.
///
/// `2 s` grace + `2 s` × 5 scheduled probes = the full automatic budget at
/// t=10 s; the small margin on top is so the *last* probe has resolved rather
/// than being in flight when the canvas settles.
const Duration _firstProbe = Duration(milliseconds: 2200);
const Duration _budgetSpent = Duration(milliseconds: 10500);

/// Canned, in-memory [KycGateway] for previews.
///
/// It answers exactly one endpoint — `GET /v1/kyc/status` — because that is the
/// only one this view can reach (through [KycWizardCubit.refreshWhileSubmitting]).
/// Submit / schema / sign throw: this view is mounted BECAUSE a submit is
/// already in flight, so a preview that reached them would be wrong, and a loud
/// failure beats a plausible fake.
///
/// [resolvedReads] is how the hung state is pinned. Reads past that count are
/// held open forever — never erroring, never resolving — which is what a status
/// probe against a silent gateway looks like on a stalled upload, and what
/// leaves the poller parked mid-request with no timer armed.
class _PreviewKycGateway implements KycGateway {
  _PreviewKycGateway(this.snapshot, {this.resolvedReads = 1 << 20});

  /// What every resolved status read answers with. [KycStatus.notSubmitted] is
  /// "the server has no record of this submission yet", which is precisely the
  /// answer that does NOT advance the wizard (see `refreshWhileSubmitting`).
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
class _SubmittingCubit extends KycWizardCubit {
  _SubmittingCubit(KycGateway gateway)
      : super(pickerService: StubPhotoPickerService(), gateway: gateway) {
    emit(state.copyWith(step: KycWizardStep.submitting));
  }
}

/// Keeps frames scheduled for [duration], then stops.
///
/// The view arms a real [Timer] in `initState` and exposes no seam to shorten
/// it, so the only way to see a state that lives past the 2 s grace window is
/// to let the clock run. It sits ABOVE the [TickerMode] that freezes the
/// spinner, so freezing the spinner does not also freeze the clock. It paints
/// nothing.
class _FrameClock extends StatefulWidget {
  const _FrameClock({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  State<_FrameClock> createState() => _FrameClockState();
}

class _FrameClockState extends State<_FrameClock>
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

/// Mounts the view the way [KycWizardScreen] does — as the whole body of the
/// wizard, under an ambient [KycWizardCubit] sitting on
/// [KycWizardStep.submitting].
///
/// Pass a null [gateway] for the unwired reading (no cubit in scope at all).
/// [TickerMode] is disabled because the in-line `OmdsLoadingState` is an
/// indeterminate spinner that never stops scheduling frames; a still preview
/// wants a still spinner anyway.
Widget _hosted({KycGateway? gateway, Duration runFor = _firstProbe}) {
  const Widget view = TickerMode(
    enabled: false,
    child: KycSubmittingView(),
  );
  return _FrameClock(
    duration: runFor,
    child: gateway == null
        ? view
        : BlocProvider<KycWizardCubit>(
            lazy: false,
            create: (_) => _SubmittingCubit(gateway),
            child: view,
          ),
  );
}

/// The view's own pixels, with no wizard around it.
///
/// This is the reading to review for layout, contrast and RTL: an 88 dp icon
/// disc, a centred headline, two-to-three lines of body copy and a 24 dp
/// spinner, centred in the wizard body. It is also an honest state — the poller
/// reads `context.read<KycWizardCubit?>()` nullably, so with no cubit in scope
/// the safety net silently does nothing at all and the spinner is terminal.
@JeebPreview(name: 'Spinner only · no wizard cubit', size: _wizardBody)
Widget kycSubmittingViewDetached() => _hosted();

/// The normal few seconds: the submit is in flight and the server has no record
/// of it yet, so every safety-net probe comes back `notSubmitted` and correctly
/// declines to advance the wizard.
///
/// The clock is run past the FULL automatic budget (t=10 s, five scheduled
/// probes), which is the state worth staring at: the eight-request budget is
/// spent, nothing is polling any more, and the screen looks precisely as it did
/// at t=0. From here the only recoveries left are the submit future itself, the
/// CDN-upload timeout, and `KycWizardCubit.onJeeberRoleGranted` — none of which
/// the user can trigger, because this screen has no control on it.
@JeebPreview(name: 'Probe budget spent · nothing recorded', size: _wizardBody)
Widget kycSubmittingViewBudgetSpent() => _hosted(
      gateway: _PreviewKycGateway(
        const KycSubmission(status: KycStatus.notSubmitted),
      ),
      runFor: _budgetSpent,
    );

/// JEBV4-259/271, the defect this view was built around: `submit()` HANGS — a
/// half-open CDN-upload socket — and the status read hangs with it.
///
/// The poller issues its first probe at t=2 s and never gets an answer, so it
/// parks mid-request with no timer armed and no budget spent. On rev2 this is
/// the spinner that "sat for minutes". Rendered, it is indistinguishable from
/// [kycSubmittingViewDetached] and from every other state here.
@JeebPreview(name: 'Submit HUNG · status read never answers', size: _wizardBody)
Widget kycSubmittingViewHung() => _hosted(
      gateway: _PreviewKycGateway(
        const KycSubmission(status: KycStatus.notSubmitted),
        resolvedReads: 0,
      ),
    );

/// The safety net doing its job: the client never saw the 201, but the server
/// has the submission recorded (`pending`), so the first probe at t=2 s advances
/// the wizard onto [KycWizardStep.status] — no force-stop, no relaunch.
///
/// In the app that swaps the body to [KycStatusView]. In the canvas this preview
/// mounts the submitting view directly, so what you see AFTERWARDS is still the
/// spinner: the state change is real (the render test asserts the cubit left
/// `submitting`) but this widget has no way to show it. Worth knowing before
/// debugging a device that "stayed on the spinner" — the step may already have
/// moved on underneath.
@JeebPreview(name: 'Safety net fires · server recorded it', size: _wizardBody)
Widget kycSubmittingViewSelfHeal() => _hosted(
      gateway: _PreviewKycGateway(
        const KycSubmission(status: KycStatus.pending),
      ),
    );

/// Layout ceiling: the same body on the 320 dp small-phone floor.
///
/// Nothing here scrolls — `_SubmittingBody` is a bare centred [Column] — so the
/// narrower the box, the more lines the body copy takes and the sooner the
/// column outgrows the viewport. This is the box where the 200% rendering of
/// the matrix stops fitting; the exact overflow is pinned in the render test.
@JeebPreview(name: 'Small phone body (320x480)', size: _smallBody)
Widget kycSubmittingViewSmallPhone() => _hosted();
