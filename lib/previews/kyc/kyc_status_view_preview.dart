/// Widget previews for [KycStatusView] — run with
/// `flutter widget-preview start`.
///
/// The view is the terminal step of the KYC wizard (JM-042) and renders one of
/// five bodies off `KycWizardCubit` state: an in-flight status read, pending
/// (auto-checking or auto-check stopped), approved, rejected, or
/// resubmit-requested. Every state below is driven the way the wizard drives it
/// — an ambient [KycWizardCubit] hydrated by [KycWizardCubit.loadStatus] — so
/// what the canvas shows is the real branch, not a hand-built stand-in.
///
/// **Network-free by construction.** The cubit is built over
/// [_PreviewKycGateway], a canned in-memory [KycGateway]; no [Dio], no DI, no
/// [DioKycGateway]. The guard in [jeebPreviewHost] is the net, not the plan.
///
/// **Why the schedules are so short.** [KycStatusView] arms a real [Timer] for
/// as long as the decision is pending, so a pending body is reachable in a
/// *settled* frame only in one of the two states where the poller holds no
/// timer: a probe in flight, or the budget spent. [_previewSchedule] pulls the
/// production 3 s first interval down to 10 ms so both are reached in the first
/// frame instead of three seconds into the canvas.
///
/// **What to look at.** These are full-body layouts at phone width, and the
/// body is a plain [Column] with a [Spacer] and NO scroll view. On a 390x700
/// phone body that already overflows at the DEFAULT text size for two of the
/// states below, and at 200% text it overflows for ALL of them — by 180 dp on
/// the *shortest* one — which pushes the CTAs off the bottom with nothing to
/// scroll them back. The numbers are pinned in
/// `test/previews/kyc/kyc_status_view_preview_test.dart`.
///
/// Note also the two CTAs that borrow copy from other screens (the production
/// file marks both `L10N-REQ`): the approved primary reads "Available
/// requests", and the rejected primary reads "View status".
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/kyc/application/kyc_poll_schedule.dart';
import '../../features/kyc/application/kyc_wizard_cubit.dart';
import '../../features/kyc/domain/kyc_contract_template.dart';
import '../../features/kyc/domain/kyc_form_schema.dart';
import '../../features/kyc/domain/kyc_gateway.dart';
import '../../features/kyc/domain/kyc_submission.dart';
import '../../features/kyc/presentation/kyc_status_view.dart';
import '../../features/photo_attachment/data/stub_photo_picker_service.dart';
import '../harness/jeeb_preview.dart';

/// A phone body box: 390 dp wide, and as tall as a 844 dp phone leaves once the
/// wizard's own AppBar, status bar and home indicator are taken out. Sizing the
/// canvas to the real body is the whole point here — a taller box would hide
/// exactly the overflow this unscrollable column produces.
const Size _statusBox = Size(390, 700);

/// Poll schedule for previews: the first automatic re-check lands in 10 ms
/// instead of the production 3 s, so the canvas settles on the state under
/// review immediately. Nothing else about the schedule matters to the layout.
const KycPollSchedule _previewSchedule = KycPollSchedule(
  tiers: <KycPollTier>[
    KycPollTier(
      until: Duration(seconds: 1),
      interval: Duration(milliseconds: 10),
    ),
  ],
  tailInterval: Duration(milliseconds: 10),
  maxElapsed: Duration(seconds: 1),
  maxScheduledProbes: 45,
  maxResumeProbes: 8,
);

/// The same schedule with a budget of ONE automatic probe, so the view crosses
/// into its expired branch (`kyc_status_poll_expired`) after a single re-check
/// rather than after the production 38 probes / 15 minutes.
const KycPollSchedule _oneProbeSchedule = KycPollSchedule(
  tiers: <KycPollTier>[
    KycPollTier(
      until: Duration(seconds: 1),
      interval: Duration(milliseconds: 10),
    ),
  ],
  tailInterval: Duration(milliseconds: 10),
  maxElapsed: Duration(seconds: 1),
  maxScheduledProbes: 1,
  maxResumeProbes: 8,
);

/// Canned, in-memory [KycGateway] for previews.
///
/// It answers exactly one endpoint — `GET /v1/kyc/status` — because that is the
/// only one [KycStatusView] can reach (through [KycWizardCubit.loadStatus] and
/// [KycWizardCubit.refreshStatus]). Submit / schema / sign throw: a preview that
/// reached them would be wrong, and a loud failure beats a plausible fake.
///
/// [resolvedReads] is how the pending states are pinned. Reads past that count
/// are held open forever — never erroring, never resolving — which is what a
/// real status probe against a silent gateway looks like, and what leaves the
/// poller parked with no timer armed.
class _PreviewKycGateway implements KycGateway {
  _PreviewKycGateway(this.snapshot, {this.resolvedReads = 1});

  /// The decision every resolved status read returns.
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
    throw UnsupportedError('KycStatusView never loads the form schema.');
  }

  @override
  Future<KycContractTemplate> fetchContractTemplate() {
    throw UnsupportedError('KycStatusView never loads the ToS template.');
  }

  @override
  Future<KycSignStamp> signContract({
    required String templateId,
    required String tosVersion,
    required String signatureBlob,
  }) {
    throw UnsupportedError('KycStatusView never signs the ToS.');
  }

  @override
  Future<KycSubmission> submit(KycSubmission draft) {
    throw UnsupportedError('KycStatusView never submits.');
  }
}

/// Mounts the view over a cubit hydrated from [snapshot].
///
/// [TickerMode] is disabled because two branches render an indeterminate
/// [CircularProgressIndicator] (`OmdsLoadingState`, and `OmdsLoadingButton`
/// while a probe is in flight) which never stops scheduling frames — the render
/// tests' `pumpAndSettle` would hang on it. A still preview wants a still
/// spinner anyway.
///
/// `onClose` is stubbed so the secondary "Back to profile" exit does not reach
/// for a [Navigator] the canvas has not got.
Widget _hosted(
  KycSubmission snapshot, {
  int resolvedReads = 1,
  KycPollSchedule schedule = _previewSchedule,
}) {
  return TickerMode(
    enabled: false,
    child: BlocProvider<KycWizardCubit>(
      create: (_) {
        final KycWizardCubit cubit = KycWizardCubit(
          pickerService: StubPhotoPickerService(),
          gateway: _PreviewKycGateway(snapshot, resolvedReads: resolvedReads),
        );
        unawaited(cubit.loadStatus());
        return cubit;
      },
      child: KycStatusView(pollSchedule: schedule, onClose: () {}),
    ),
  );
}

/// The cold-start frame: `GET /v1/kyc/status` is in flight, so the body is a
/// bare centred spinner with no title, no copy and no accessible label.
///
/// This is not a cosmetic state. JEBV4-271 round 6: `isLoadingStatus` was left
/// stuck true by `loadStatus() → loadSchema()`, and because
/// [KycStatusView.build] short-circuits on that flag BEFORE the status switch,
/// an already-approved jeeber sat on exactly this spinner forever —
/// `_ApprovedBody` never built, so [JeeberRoleActivator] never fired and the
/// jeeber only came online after a force-restart. If this rendering is what a
/// device shows after a submit, that regression is back.
@JeebPreview(name: 'Status read in flight', size: _statusBox)
Widget kycStatusViewLoading() => _hosted(
      const KycSubmission(status: KycStatus.pending),
      resolvedReads: 0,
    );

/// Pending, with an automatic re-check in flight — the state the view spends
/// every probe in, and the one a user sees the moment they tap "Check again".
///
/// `OmdsLoadingButton` swaps its LABEL for the spinner, so "Check again"
/// disappears from the screen while the check runs: the button becomes an
/// unlabelled box, and a screen reader loses the only description it had.
///
/// Note the CTA order against [kycStatusViewPendingAutoCheckStopped]: while the
/// automatic poller still has budget, "Top up" is the primary and the re-check
/// sits under it (FM5-F11-W4).
@JeebPreview(name: 'Pending · re-check in flight', size: _statusBox)
Widget kycStatusViewPendingChecking() =>
    _hosted(const KycSubmission(status: KycStatus.pending));

/// Pending, budget spent: the poller has stopped and the screen now depends on
/// the user tapping (FM5-F11-W3).
///
/// Two things change at once — an extra note appears above the top-up card, and
/// the CTA stack INVERTS so the re-check is promoted to primary above "Top up".
/// The note is also what tips this body over the edge: the same body without it
/// ([kycStatusViewPendingChecking]) fits a 390x700 phone, and this one overflows
/// it by 40 dp at the DEFAULT text size, so "Back to profile" is already partly
/// clipped before accessibility settings enter the picture.
@JeebPreview(name: 'Pending · auto-check stopped', size: _statusBox)
Widget kycStatusViewPendingAutoCheckStopped() => _hosted(
      const KycSubmission(status: KycStatus.pending),
      resolvedReads: 2,
      schedule: _oneProbeSchedule,
    );

/// Approved: the three post-approval entry points.
///
/// The primary CTA is meant to read "Go to feed" but ships the borrowed key
/// `jeeberFeedSectionTitle` — so the button on the approval screen actually says
/// **"Available requests"**, a section heading, not an action. The production
/// file marks it `L10N-REQ`; this is what that shortcut looks like.
///
/// Reaching this body is also what fires [JeeberRoleActivator]. There are no
/// role cubits and no DI registration in a preview, so activation degrades to a
/// no-op exactly as it does in a bare widget test — nothing here touches the
/// network.
@JeebPreview(name: 'Approved', size: _statusBox)
Widget kycStatusViewApproved() =>
    _hosted(const KycSubmission(status: KycStatus.approved));

/// Rejected — FINAL (D52/D87). No resubmit CTA exists on this branch; the
/// hand-off is to the appeal-only `kyc-rejected` screen.
///
/// Same borrowed-copy problem as the approved body: the primary is supposed to
/// read "View rejection details" and instead ships `profileKycViewCta` —
/// **"View status"** — on a screen that IS the status.
@JeebPreview(name: 'Rejected · selfie mismatch', size: _statusBox)
Widget kycStatusViewRejected() => _hosted(
      const KycSubmission(
        status: KycStatus.rejected,
        rejectionReason: KycRejectionReason.selfieMismatch,
      ),
    );

/// Layout ceiling: resubmit-requested with a reason AND every document slot
/// flagged (E19 / Q-040).
///
/// Five "what to fix" lines is not a stress fixture — `request_resubmit` takes a
/// per-slot list and the back-office can tick all of them. It is the tallest
/// body the view can produce, and it is the preview that shows what the screen
/// does when content stops fitting: on a 390x700 phone body it overflows by
/// 100 dp at the DEFAULT text size (60 dp in Arabic, which sets shorter here)
/// and by over 1200 dp at 200% text. There is no scroll view, so the jeeber
/// cannot reach the resubmit CTA that is the entire point of this state.
@JeebPreview(name: 'Resubmit requested · all slots', size: _statusBox)
Widget kycStatusViewResubmitRequested() => _hosted(
      const KycSubmission(
        status: KycStatus.resubmitRequested,
        rejectionReason: KycRejectionReason.idUnreadable,
        resubmitSteps: <KycResubmitStep>[
          KycResubmitStep.idFront,
          KycResubmitStep.idBack,
          KycResubmitStep.selfie,
          KycResubmitStep.idNumber,
          KycResubmitStep.other,
        ],
      ),
    );
