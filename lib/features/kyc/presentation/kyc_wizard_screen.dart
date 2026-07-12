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

/// Hosts the KYC identity wizard at `/profile/kyc` (route name `kyc-status`).
///
/// JM-040 (D20): the Vehicle step was removed. The flow is now
/// `schema → identity → submitting → status`. The single identity screen
/// collects gov-ID front/back + selfie + ToS acceptance, and `kyc_submit_cta`
/// posts the submission.
///
/// On a FRESH successful submit the wizard chains to `onboarding-funding`
/// (JM-041) rather than the standalone status view — the status view is kept
/// only for RE-ENTRY (e.g. opening KYC again while already pending/approved/
/// rejected from the profile or the funding screen's "Continue").
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

  /// Navigation hook fired once when a fresh submit succeeds. Defaults to
  /// `context.goNamed('onboarding-funding')`. Overridable so widget tests can
  /// assert the chain without a full router.
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
      // the KYC wizard. Wraps the whole body so it is visible on every step.
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
              // JEBV4-271 (round 3): the authoritative role-arrived signal. When
              // the getMe `available_roles` projection (published app-wide by
              // RoleSync on login/resume) gains `jeeber` while the wizard is
              // still on the submit spinner or a pending status view, advance
              // straight onto the approved status view — the exact on-device
              // rev2 gap where `/v1/users/me` returned `jeeber` yet nothing drove
              // the transition. Only wired when the app-root RoleAvailabilityCubit
              // is in scope (production shell); a bare wizard harness has none, so
              // this listener is simply not added.
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
    // Consume the one-shot signal so it cannot re-fire, then chain to funding.
    context.read<KycWizardCubit>().acknowledgeNavigation();
    final hook = onSubmitted;
    if (hook != null) {
      hook(context);
      return;
    }
    // EDGE → onboarding-funding (JM-041, D42/D1). `kyc_submit_cta` lands here,
    // NOT the standalone status view.
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
    // identity
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
          OMDSOutlinedButton(
            text: l10n.kycRetry,
            onTap: () => context.read<KycWizardCubit>().loadSchema(),
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
    // Display at least "Step 1 of 2" while the user is still capturing.
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
