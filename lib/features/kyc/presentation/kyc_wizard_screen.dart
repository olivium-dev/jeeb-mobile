import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/role/role_availability_cubit.dart';
import '../../../l10n/app_localizations.dart';
import '../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../application/kyc_wizard_cubit.dart';
import '../application/kyc_wizard_state.dart';
import '../domain/kyc_gateway.dart';
import 'kyc_status_view.dart';
import 'widgets/kyc_identity_step.dart';
import 'widgets/kyc_submitting_view.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/kyc_wizard_screen_fixtures.dart';
import '../domain/kyc_submission.dart';

/// Hosts the KYC identity wizard at `/profile/kyc` (route name `kyc-status`).
///
class KycWizardScreen extends StatelessWidget {
  const KycWizardScreen({
    super.key,
    this.cubit,
    this.pickerService,
    this.gateway,
    this.onSubmitted,
  }) : assert(
          cubit == null || (pickerService == null && gateway == null),
          'Provide either a cubit or the (pickerService, gateway) pair, not both.',
        );

  final KycWizardCubit? cubit;
  final PhotoPickerService? pickerService;
  final KycGateway? gateway;

  final void Function(BuildContext context)? onSubmitted;

  static const Key rootKey = Key('kyc-wizard-root');
  static const Key progressKey = Key('kyc-wizard-progress');
  static const Key backLeadingKey = Key('kyc-wizard-back');

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<KycWizardCubit>.value(
        value: provided,
        child: _WizardScaffold(onSubmitted: onSubmitted),
      );
    }
    return BlocProvider<KycWizardCubit>(
      create: (_) => KycWizardCubit(
        pickerService: pickerService ?? _resolvePicker(),
        gateway: gateway ?? _resolveGateway(),
      )..loadStatus(),
      child: _WizardScaffold(onSubmitted: onSubmitted),
    );
  }

  PhotoPickerService _resolvePicker() {
    if (sl.isRegistered<PhotoPickerService>()) return sl<PhotoPickerService>();
    return StubPhotoPickerService();
  }

  KycGateway _resolveGateway() {
    if (sl.isRegistered<KycGateway>()) return sl<KycGateway>();
    return FakeKycGateway();
  }
}

class _WizardScaffold extends StatelessWidget {
  const _WizardScaffold({this.onSubmitted});

  final void Function(BuildContext context)? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: KycWizardScreen.rootKey,
      appBar: OMDSAppBar(
        title: l10n.kycWizardTitle,
        centerTitle: false,
      ),
      // `kyc_wizard_root` (65_W2_TEST_PLAN §2 JM-040): the asserted root id of
      body: Semantics(
        identifier: 'kyc_wizard_root',
        container: true,
        child: SafeArea(
          child: MultiBlocListener(
            listeners: [
              BlocListener<KycWizardCubit, KycWizardState>(
                listenWhen: (prev, curr) =>
                    !prev.justSubmitted && curr.justSubmitted,
                listener: _onSubmitted,
              ),
              BlocListener<KycWizardCubit, KycWizardState>(
                listenWhen: (prev, curr) =>
                    prev.error != curr.error && curr.error != null,
                listener: _surfaceError,
              ),
              if (context.read<RoleAvailabilityCubit?>() != null)
                BlocListener<RoleAvailabilityCubit, RoleAvailability>(
                  listenWhen: (prev, curr) =>
                      !prev.roles.contains('jeeber') &&
                      curr.roles.contains('jeeber'),
                  listener: (context, _) =>
                      context.read<KycWizardCubit>().onJeeberRoleGranted(),
                ),
            ],
            child: BlocBuilder<KycWizardCubit, KycWizardState>(
              builder: (context, state) => _buildBody(context, state, l10n),
            ),
          ),
        ),
      ),
    );
  }

  void _onSubmitted(BuildContext context, KycWizardState state) {
    context.read<KycWizardCubit>().acknowledgeNavigation();
    final hook = onSubmitted;
    if (hook != null) {
      hook(context);
      return;
    }
    // EDGE → onboarding-funding (JM-041, D42/D1). `kyc_submit_cta` lands here,
    context.goNamed('onboarding-funding');
  }

  Widget _buildBody(
    BuildContext context,
    KycWizardState state,
    AppLocalizations l10n,
  ) {
    if (state.step == KycWizardStep.status) return const KycStatusView();
    if (state.step == KycWizardStep.submitting) {
      return const KycSubmittingView();
    }
    if (state.step == KycWizardStep.schema) {
      return _SchemaLoadingView(l10n: l10n, state: state);
    }
    return Column(
      children: [
        _ProgressHeader(state: state),
        const Expanded(child: KycIdentityStep()),
      ],
    );
  }

  void _surfaceError(BuildContext context, KycWizardState state) {
    final l10n = AppLocalizations.of(context);
    final error = state.error;
    if (error == null) return;
    final cubit = context.read<KycWizardCubit>();
    final message = _messageFor(l10n, error);
    if (message != null) showOmdsSnackbar(context, message: message);
    cubit.acknowledgeError();
  }

  String? _messageFor(AppLocalizations l10n, KycWizardError error) {
    switch (error) {
      case KycWizardError.pickCancelled:
        return null;
      case KycWizardError.permissionDenied:
        return l10n.kycErrorPermissionDenied;
      case KycWizardError.unavailable:
        return l10n.kycErrorUnavailable;
      case KycWizardError.compressionFailed:
        return l10n.kycErrorCompressionFailed;
      case KycWizardError.submitFailed:
        return l10n.kycErrorSubmitFailed;
      case KycWizardError.submitValidationFailed:
        return l10n.kycErrorSubmitValidationFailed;
      case KycWizardError.schemaLoadFailed:
        return l10n.kycErrorSchemaLoadFailed;
      case KycWizardError.contractLoadFailed:
        return l10n.kycErrorContractLoadFailed;
      case KycWizardError.signFailed:
        return l10n.kycErrorSignFailed;
      case KycWizardError.fileTooLarge:
        return l10n.kycErrorFileTooLarge;
      case KycWizardError.fileTypeNotAllowed:
        return l10n.kycErrorFileTypeNotAllowed;
    }
  }
}

class _SchemaLoadingView extends StatelessWidget {
  const _SchemaLoadingView({required this.l10n, required this.state});

  final AppLocalizations l10n;
  final KycWizardState state;

  @override
  Widget build(BuildContext context) {
    final hasError = state.error == KycWizardError.schemaLoadFailed;
    if (hasError) {
      return _SchemaErrorView(l10n: l10n);
    }
    return const Center(child: OmdsLoadingState());
  }
}

class _SchemaErrorView extends StatelessWidget {
  const _SchemaErrorView({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.kycErrorSchemaLoadFailed),
          const SizedBox(height: Spacing.medium),
          Semantics(
            identifier: 'kyc_wizard_retry_cta',
            container: true,
            button: true,
            child: OMDSOutlinedButton(
              text: l10n.kycRetry,
              onTap: () => context.read<KycWizardCubit>().loadSchema(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.state});

  final KycWizardState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final displayStep = state.completedCaptureSteps < 1
        ? 1
        : state.completedCaptureSteps;
    return Padding(
      key: KycWizardScreen.progressKey,
      padding: const EdgeInsets.fromLTRB(
        Spacing.large,
        Spacing.medium,
        Spacing.large,
        Spacing.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.kycWizardProgressLabel(
              current: displayStep,
              total: KycWizardState.totalCaptureSteps,
            ),
            style: textTheme.labelMedium,
          ),
          const SizedBox(height: Spacing.small),
          OMDSLabeledStepperProgress(
            totalSteps: KycWizardState.totalCaptureSteps,
            completedSteps: state.completedCaptureSteps,
            stepLabels: [
              l10n.kycWizardStepIdLabel,
              l10n.kycWizardStepSelfieLabel,
            ],
          ),
        ],
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
// Render tests: test/previews/kyc/kyc_wizard_screen_preview_test.dart
// ===========================================================================
//
// [KycWizardScreen] is the whole of `/profile/kyc`: one Scaffold + AppBar over
// a body that switches on `KycWizardState.step` —
// `schema → identity → submitting → status`. Four different screens share one
// route, which is exactly why it is worth previewing as a screen and not only
// as its parts: `KycIdentityStep`, `KycSubmittingView` and `KycStatusView` all
// have their own preview sections, and none of them shows what the wizard puts
// AROUND them (the AppBar, the `ID | Selfie` progress header) or WHICH of them
// a given cubit state produces.
//
// The seeds, the canned gateway and the capture fixtures are NOT declared here.
// They live in `lib/devtool/catalog/fixtures/kyc_wizard_screen_fixtures.dart`,
// shared with the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_05_entries.dart`), so the designer's in-app
// browser and this canvas cannot drift into showing two different "designed
// states". Nothing there can reach the network: every answer is a const value,
// a throw, or a `Completer` that is never completed.
//
// Three things about this harness are worth knowing before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and this
//    screen's `Scaffold + OMDSAppBar` paints inside it. Same nesting the Screen
//    Catalog produces.
//  * **`onSubmitted` is stubbed on every state.** Its default is
//    `context.goNamed('onboarding-funding')`, and there is no [GoRouter] above
//    a preview card. No state below submits, but the hook is neutralised rather
//    than left armed.
//  * **[TickerMode] is disabled and some states run a frame clock.** Three
//    bodies here render an indeterminate `CircularProgressIndicator`, which
//    never stops scheduling frames and would hang a render test's
//    `pumpAndSettle`; a still preview wants a still spinner anyway. But
//    `KycStatusView` and `KycSubmittingView` both arm real `Timer`s that this
//    screen exposes no seam to shorten (the status poll schedule is injectable
//    on `KycStatusView` and NOT forwarded by `_WizardScaffold`; the submitting
//    view hardcodes its 2 s grace as a private `static const`), so the two
//    states that live past a grace window let the clock run —
//    [_KycWizardScreenFrameClock] sits ABOVE the [TickerMode] and keeps frames
//    scheduled for exactly as long as the state under review needs.
//
// **What to look at.** Two things this screen does that its parts cannot show:
//
//  * **The schema-load ERROR view is unreachable in the running app.**
//    `_SchemaErrorView` — the localized failure line plus the only
//    `kyc_wizard_retry_cta` in the feature — renders while
//    `state.error == schemaLoadFailed`. But `_WizardScaffold` also mounts a
//    `BlocListener` on `error` that raises a snackbar and then calls
//    `acknowledgeError()`, which CLEARS the flag in the same turn. So a jeeber
//    whose `GET /v1/kyc/jeeb/form-schema` fails sees a snackbar and then the
//    schema spinner again — forever, with no retry — because
//    `_SchemaLoadingView` falls back to the spinner the moment the error is
//    acknowledged. [kycWizardScreenSchemaLoadFailed] seeds the state before the
//    listener is mounted, which is the only way to hold the view still; put it
//    beside [kycWizardScreenSchemaLoading] and note that the second frame of
//    the first one IS the second one.
//  * **The progress header counts CAPTURES, not steps.**
//    `KycWizardState.completedCaptureSteps` returns `totalCaptureSteps` for
//    both `submitting` and `status`, and `_ProgressHeader` floors the display
//    at 1 — so the header reads "Step 1 of 2" from the first frame of a wholly
//    empty form, and the two ID sides plus the selfie collapse into two ticks.

/// The phone this screen is designed against.
const Size _kycWizardScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _kycWizardScreenCompactBox = Size(320, 568);

/// Long enough for `KycStatusView`'s first automatic re-check to fire.
///
/// The poll schedule is `KycPollSchedule.standard` (first interval 3 s) because
/// `_WizardScaffold` builds `const KycStatusView()` and forwards nothing. Once
/// that probe is issued against a gateway that never answers, the poller parks
/// mid-request with no timer armed — which is the only settled frame a PENDING
/// decision has.
const Duration _kycWizardScreenPollGrace = Duration(milliseconds: 3600);

/// Long enough for `KycSubmittingView`'s safety-net probe to fire (2 s grace,
/// hardcoded in that view as a private `static const`).
const Duration _kycWizardScreenSubmitGrace = Duration(milliseconds: 2400);

/// Keeps frames scheduled for [duration], then stops.
///
/// It sits ABOVE the [TickerMode] that freezes the spinners, so freezing them
/// does not also freeze the clock. It paints nothing.
class _KycWizardScreenFrameClock extends StatefulWidget {
  const _KycWizardScreenFrameClock({
    required this.duration,
    required this.child,
  });

  final Duration duration;
  final Widget child;

  @override
  State<_KycWizardScreenFrameClock> createState() =>
      _KycWizardScreenFrameClockState();
}

class _KycWizardScreenFrameClockState extends State<_KycWizardScreenFrameClock>
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

/// Mounts the whole wizard over [cubit], through the same `cubit:` seam the
/// Screen Catalog uses — no DI, no `sl<KycGateway>()`, no `DioKycGateway`.
Widget _kycWizardScreenHosted(KycWizardCubit cubit, {Duration? runFor}) {
  final Widget wizard = TickerMode(
    enabled: false,
    child: KycWizardScreen(cubit: cubit, onSubmitted: (_) {}),
  );
  if (runFor == null) return wizard;
  return _KycWizardScreenFrameClock(duration: runFor, child: wizard);
}

/// Cold entry on the identity step: nothing captured, nothing typed.
///
/// The reference reading, and the state a jeeber actually lands on. What the
/// wizard adds over the step's own preview is the AppBar and the
/// `_ProgressHeader` — and the header is the thing to read here, because it
/// already says "Step 1 of 2" over a form with zero of its four requirements
/// met, and both stepper labels ("ID", "Selfie") are rendered with neither of
/// them reachable as a tap target.
///
/// One of the two matrix states. In AR the AppBar title, the progress row, the
/// stepper and the whole scrolling form mirror together, and at 200% text the
/// header eats a growing share of a viewport the form below it has to scroll.
@JeebPreview(
  group: 'kyc',
  name: 'Identity · cold entry',
  size: _kycWizardScreenPhoneBox,
  matrix: true,
)
Widget kycWizardScreenIdentityColdEntry() => _kycWizardScreenHosted(
      KycWizardScreenPreviewFixtures.seededCubit(
        KycWizardScreenPreviewFixtures.identityState(),
      ),
    );

/// Everything captured, a contract-valid 12-digit national ID, ToS accepted —
/// the only state in this section where `kyc_submit_cta` is live.
///
/// This is the Screen Catalog's "Identity — ready to submit" state, and until
/// the fixtures were extracted it was not ready at all: the drive did captures
/// plus the ToS tick and stopped, while JEBV4-295/E3 had made a contract-valid
/// `id_number` a hard client gate, so the CTA under that label was dead. The
/// header now reads "Step 2 of 2" — which it also does with the ID number blank
/// and the CTA disabled, because `completedCaptureSteps` counts photos only.
@JeebPreview(
  group: 'kyc',
  name: 'Identity · ready to submit',
  size: _kycWizardScreenPhoneBox,
)
Widget kycWizardScreenIdentityReadyToSubmit() => _kycWizardScreenHosted(
      KycWizardScreenPreviewFixtures.seededCubit(
        KycWizardScreenPreviewFixtures.identityState(
          idNumber: KycWizardScreenPreviewFixtures.nationalIdNumber,
          govIdCaptured: true,
          selfieCaptured: true,
          tosAccepted: true,
        ),
      ),
    );

/// The very first frame of every cold entry: `GET /v1/kyc/jeeb/form-schema` is
/// in flight and the body is a bare centred spinner.
///
/// There is no title, no copy, no accessible label and nothing to cancel with —
/// the AppBar's back arrow is the only control on the screen. Worth holding
/// still because it is normally invisible (a fast schema read resolves before
/// anyone looks) and permanent on a slow one; and because it is ALSO what a
/// failed schema read degrades to one frame later — see
/// [kycWizardScreenSchemaLoadFailed].
@JeebPreview(
  group: 'kyc',
  name: 'Schema · load in flight',
  size: _kycWizardScreenPhoneBox,
)
Widget kycWizardScreenSchemaLoading() => _kycWizardScreenHosted(
      KycWizardScreenPreviewFixtures.schemaLoadingCubit(),
    );

/// The error branch: the schema read failed, so `_SchemaErrorView` offers the
/// localized failure line and `kyc_wizard_retry_cta`.
///
/// **A running app cannot reach this frame.** `_WizardScaffold` mounts a
/// `BlocListener` on `error` that raises a snackbar and then calls
/// `KycWizardCubit.acknowledgeError()`, so the flag `_SchemaLoadingView` keys
/// off is cleared in the same turn it is set and the body falls straight back
/// to [kycWizardScreenSchemaLoading] — an indefinite spinner with no retry,
/// after a snackbar that has already gone. This preview seeds the state before
/// the listener exists, which is the only way to see the view the feature ships
/// but never shows.
@JeebPreview(
  group: 'kyc',
  name: 'Schema · load FAILED (retry unreachable in-app)',
  size: _kycWizardScreenPhoneBox,
)
Widget kycWizardScreenSchemaLoadFailed() => _kycWizardScreenHosted(
      KycWizardScreenPreviewFixtures.seededCubit(
        KycWizardScreenPreviewFixtures.schemaLoadFailedState,
      ),
    );

/// `POST /v1/kyc/submit` in flight: the whole form is replaced by
/// `KycSubmittingView`'s icon, headline, copy and spinner.
///
/// The gateway here answers no status read at all, so this is the JEBV4-259/271
/// shape — the submit future hangs and the safety-net probe that fires at t=2 s
/// hangs with it, leaving the jeeber on a spinner with no retry, no cancel and
/// no elapsed-time hint. The clock is run just past that probe so the frame you
/// see is the one AFTER the automatic recovery has been tried, not before.
@JeebPreview(
  group: 'kyc',
  name: 'Submitting · POST hung',
  size: _kycWizardScreenPhoneBox,
)
Widget kycWizardScreenSubmitting() => _kycWizardScreenHosted(
      KycWizardScreenPreviewFixtures.seededCubit(
        KycWizardScreenPreviewFixtures.submittingState,
        gateway: KycWizardScreenPreviewGateway(statusReads: 0),
      ),
      runFor: _kycWizardScreenSubmitGrace,
    );

/// Re-entry on a submission the back-office has not decided yet.
///
/// `KycStatusView` starts its bounded poller the moment this body mounts, and
/// `_WizardScaffold` builds `const KycStatusView()` — it forwards no
/// `pollSchedule`, so the production 3 s cadence is the only one this screen
/// can have. A pending decision therefore has exactly two settled frames (a
/// probe in flight, or the 15-minute budget spent) and everything between them
/// holds a live `Timer`. The clock is run past the first probe and the gateway
/// then goes silent, which parks the poller on the first of the two.
///
/// Two things to know about this card. `OmdsLoadingButton` swaps the "Check
/// again" LABEL for its spinner while a check runs, so the only manual recovery
/// on the screen becomes an unlabelled box. And that swap is an
/// `AnimatedSwitcher`, which the disabled [TickerMode] freezes mid-cross-fade —
/// so the label you can still see UNDER the spinner here is a canvas artifact,
/// not what a device shows.
@JeebPreview(
  group: 'kyc',
  name: 'Status · pending review',
  size: _kycWizardScreenPhoneBox,
)
Widget kycWizardScreenStatusPending() => _kycWizardScreenHosted(
      KycWizardScreenPreviewFixtures.statusCubit(
        status: KycStatus.pending,
        statusReads: 1,
      ),
      runFor: _kycWizardScreenPollGrace,
    );

/// Re-entry on an approved KYC — the three post-approval entry points.
///
/// Reaching this body is what fires `JeeberRoleActivator` in the app. There are
/// no role cubits and no DI registration in a preview, so activation degrades
/// to a no-op exactly as it does in a bare widget test; nothing here touches
/// the network. Note the primary CTA reads "Available requests" — a borrowed
/// section heading the production code above marks `L10N-REQ`.
@JeebPreview(
  group: 'kyc',
  name: 'Status · approved',
  size: _kycWizardScreenPhoneBox,
)
Widget kycWizardScreenStatusApproved() => _kycWizardScreenHosted(
      KycWizardScreenPreviewFixtures.statusCubit(status: KycStatus.approved),
    );

/// Re-entry on a rejected KYC — FINAL (D52/D87), so there is no resubmit CTA.
///
/// The status bodies are the states to compare against the identity ones: the
/// identity step is a `SingleChildScrollView`, and this body is a bare `Column`
/// with a `Spacer` and nothing to scroll. Same route, same AppBar, opposite
/// behaviour when the content stops fitting: measured through the real faces on
/// a 320x568 phone at 200% text, the SHORTEST status body
/// ([kycWizardScreenStatusApproved]) overflows by 144 dp in EN and lays its
/// third CTA out at y=692 — off a 568 dp screen — while
/// [kycWizardScreenCompactCeiling] scrolls the same box clean. Both are pinned
/// in `test/previews/kyc/kyc_wizard_screen_preview_test.dart`.
@JeebPreview(
  group: 'kyc',
  name: 'Status · rejected',
  size: _kycWizardScreenPhoneBox,
)
Widget kycWizardScreenStatusRejected() => _kycWizardScreenHosted(
      KycWizardScreenPreviewFixtures.statusCubit(
        status: KycStatus.rejected,
        rejectionReason: KycRejectionReason.idUnreadable,
      ),
    );

/// Layout ceiling: the longest content this screen can hold, on the narrowest
/// phone the app supports.
///
/// A passport at the field's full 24-character cap, both ID sides and the
/// selfie captured, the ToS card expanded — at 320 dp. The part to watch is the
/// `_ProgressHeader`, because it is the only thing on the identity route that
/// does NOT scroll: a `Text` of `kycWizardProgressLabel` over an
/// `OMDSLabeledStepperProgress` carrying both step labels, inside
/// `Spacing.large` horizontal padding.
///
/// It does not clip — the form below it simply gets less room. Measured with
/// the real faces, the header is 84 dp at 100% text and 116 dp at 200%, which
/// on this 568 dp phone is 23% of the body spent before the first capture tile.
/// Read the AR RTL and 200% renderings for that, and for the 24-character
/// document number, which is the widest single line this screen can hold.
@JeebPreview(
  group: 'kyc',
  name: 'Longest content · compact 320',
  size: _kycWizardScreenCompactBox,
  matrix: true,
)
Widget kycWizardScreenCompactCeiling() => _kycWizardScreenHosted(
      KycWizardScreenPreviewFixtures.seededCubit(
        KycWizardScreenPreviewFixtures.identityState(
          idType: KycIdType.passport,
          idNumber: KycWizardScreenPreviewFixtures.passportNumber,
          govIdCaptured: true,
          selfieCaptured: true,
          tosAccepted: true,
        ),
      ),
    );
