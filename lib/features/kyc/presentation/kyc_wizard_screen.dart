import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/role/role_availability_cubit.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_meter.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
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
    // The BlocBuilder sits ABOVE the Scaffold so `appBar:` can read the step:
    // the redesigned identity step owns its own JeebTopBar chrome, while the
    // schema/submitting/status steps keep the OMDS bar.
    return MultiBlocListener(
      listeners: [
        BlocListener<KycWizardCubit, KycWizardState>(
          listenWhen: (prev, curr) => !prev.justSubmitted && curr.justSubmitted,
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
                !prev.roles.contains('jeeber') && curr.roles.contains('jeeber'),
            listener: (context, _) =>
                context.read<KycWizardCubit>().onJeeberRoleGranted(),
          ),
      ],
      child: BlocBuilder<KycWizardCubit, KycWizardState>(
        builder: (context, state) => Scaffold(
          key: KycWizardScreen.rootKey,
          appBar: state.step == KycWizardStep.identity
              ? null
              : OMDSAppBar(title: l10n.kycWizardTitle, centerTitle: false),
          // `kyc_wizard_root` (65_W2_TEST_PLAN §2 JM-040): the asserted root id
          // of the KYC wizard. Wraps the whole body on EVERY step.
          body: Semantics(
            identifier: 'kyc_wizard_root',
            container: true,
            child: SafeArea(child: _buildBody(context, state, l10n)),
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
    // identity — owns its own chrome (no OMDSAppBar above it).
    return Column(
      children: [
        JeebTopBar(
          key: KycWizardScreen.backLeadingKey,
          title: l10n.kycWizardTitle,
          identifier: 'kyc_wizard_back',
          leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onLeadingPressed: () => _leaveWizard(context),
        ),
        _CaptureProgress(state: state),
        const Expanded(child: KycIdentityStep()),
      ],
    );
  }

  /// Mirrors `AppRouter.backFallbacks['kyc-status'] == '/'`: the wizard is
  /// reachable as a deep link, so a bare `Navigator.maybePop` (the kit's
  /// default) would leave the back circle dead at the stack root.
  void _leaveWizard(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
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
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.xLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.kycErrorSchemaLoadFailed,
              textAlign: TextAlign.center,
              style: context.jeebText.body.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.medium),
            Semantics(
              identifier: 'kyc_wizard_retry_cta',
              container: true,
              button: true,
              child: JeebCtaButton.outline(
                label: l10n.kycRetry,
                expand: false,
                onTap: () => context.read<KycWizardCubit>().loadSchema(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Step 1 of 2 — Your ID" · "then Selfie" over a two-segment bar
/// (`22 tpl 1300-1306`).
///
/// [KycWizardState.currentCaptureStep] is the single source for BOTH the label
/// and the fill, so the old off-by-one (label clamped to 1, bar showing 0)
/// cannot come back.
class _CaptureProgress extends StatelessWidget {
  const _CaptureProgress({required this.state});

  final KycWizardState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<JeebSemanticColors>() ??
        JeebSemanticColors.light();
    final jeebText = context.jeebText;
    final current = state.currentCaptureStep;
    final isLastStep = current >= KycWizardState.totalCaptureSteps;
    return Padding(
      key: KycWizardScreen.progressKey,
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.large,
        Spacing.xLarge,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Expanded (not Spacer) so the label wraps before it collides
              // with the hint under 200% text or a long Arabic step name.
              Expanded(
                child: Text(
                  l10n.kycWizardProgressStepLabel(
                    current: current,
                    total: KycWizardState.totalCaptureSteps,
                    stepName: isLastStep
                        ? l10n.kycWizardStepSelfieLabel
                        : l10n.kycWizardStepIdTitle,
                  ),
                  style: jeebText.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              if (!isLastStep) const SizedBox(width: Spacing.small),
              if (!isLastStep)
                Text(
                  l10n.kycWizardNextStepHint(
                    stepName: l10n.kycWizardStepSelfieLabel,
                  ),
                  style: jeebText.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: semantic.mutedText,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.xSmall),
          // Segment N is filled while the user is ON step N.
          JeebMeter.segmented(
            steps: KycWizardState.totalCaptureSteps,
            filled: current,
          ),
        ],
      ),
    );
  }
}
