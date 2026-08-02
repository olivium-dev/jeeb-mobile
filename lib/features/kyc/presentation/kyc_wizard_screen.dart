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

/// The phone this screen is designed against.
const Size _kycWizardScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _kycWizardScreenCompactBox = Size(320, 568);

/// Long enough for `KycStatusView`'s first automatic re-check to fire.
/// The poll schedule is `KycPollSchedule.standard` (first interval 3 s) because
const Duration _kycWizardScreenPollGrace = Duration(milliseconds: 3600);

/// Long enough for `KycSubmittingView`'s safety-net probe to fire (2 s grace,
/// hardcoded in that view as a private `static const`).
const Duration _kycWizardScreenSubmitGrace = Duration(milliseconds: 2400);

/// Keeps frames scheduled for [duration], then stops.
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
/// The reference reading, and the state a jeeber actually lands on. What the
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
/// `KycStatusView` starts its bounded poller the moment this body mounts, and
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
/// Reaching this body is what fires `JeeberRoleActivator` in the app. There are
@JeebPreview(
  group: 'kyc',
  name: 'Status · approved',
  size: _kycWizardScreenPhoneBox,
)
Widget kycWizardScreenStatusApproved() => _kycWizardScreenHosted(
      KycWizardScreenPreviewFixtures.statusCubit(status: KycStatus.approved),
    );

/// Re-entry on a rejected KYC — FINAL (D52/D87), so there is no resubmit CTA.
/// The status bodies are the states to compare against the identity ones: the
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
