import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../application/kyc_wizard_cubit.dart';
import '../application/kyc_wizard_state.dart';
import '../domain/kyc_gateway.dart';
import 'kyc_status_view.dart';
import 'widgets/kyc_id_step.dart';
import 'widgets/kyc_selfie_step.dart';
import 'widgets/kyc_submitting_view.dart';
import 'widgets/kyc_vehicle_step.dart';

/// Hosts the KYC wizard at `/profile/kyc`.
///
/// Builds a single [KycWizardCubit] per visit. The status step is rendered by
/// [KycStatusView]; the three capture steps share a labeled stepper progress
/// indicator pinned to the top.
class KycWizardScreen extends StatelessWidget {
  const KycWizardScreen({
    super.key,
    this.cubit,
    this.pickerService,
    this.gateway,
  }) : assert(
          cubit == null || (pickerService == null && gateway == null),
          'Provide either a cubit or the (pickerService, gateway) pair, not both.',
        );

  /// Optional override — production builds a fresh cubit with stub camera +
  /// fake gateway, widget tests inject one with a controlled gateway decision.
  final KycWizardCubit? cubit;
  final PhotoPickerService? pickerService;
  final KycGateway? gateway;

  static const Key rootKey = Key('kyc-wizard-root');
  static const Key progressKey = Key('kyc-wizard-progress');
  static const Key backLeadingKey = Key('kyc-wizard-back');

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<KycWizardCubit>.value(
        value: provided,
        child: const _WizardScaffold(),
      );
    }
    return BlocProvider<KycWizardCubit>(
      create: (_) => KycWizardCubit(
        pickerService: pickerService ?? _resolvePicker(),
        gateway: gateway ?? _resolveGateway(),
      )..loadStatus(),
      child: const _WizardScaffold(),
    );
  }

  // The wizard is reachable from a push deep link before bootstrap has had a
  // chance to register the singletons (cold-start path) and from boot tests
  // that don't configure GetIt at all. Falling back to in-process fakes keeps
  // the screen rendering instead of throwing a GetIt lookup error — once
  // configureDependencies runs, the registered singleton wins for new visits.
  PhotoPickerService _resolvePicker() {
    if (sl.isRegistered<PhotoPickerService>()) {
      return sl<PhotoPickerService>();
    }
    return StubPhotoPickerService();
  }

  KycGateway _resolveGateway() {
    if (sl.isRegistered<KycGateway>()) {
      return sl<KycGateway>();
    }
    return FakeKycGateway();
  }
}

class _WizardScaffold extends StatelessWidget {
  const _WizardScaffold();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: KycWizardScreen.rootKey,
      appBar: OMDSAppBar(
        title: l10n.kycWizardTitle,
        centerTitle: false,
        leading: BlocBuilder<KycWizardCubit, KycWizardState>(
          buildWhen: (prev, curr) => prev.step != curr.step,
          builder: (context, state) {
            final canGoBack = state.step == KycWizardStep.selfie ||
                state.step == KycWizardStep.vehicle;
            if (!canGoBack) return const BackButton();
            return IconButton(
              key: KycWizardScreen.backLeadingKey,
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.kycWizardBack,
              onPressed: () => context.read<KycWizardCubit>().goBack(),
            );
          },
        ),
      ),
      body: SafeArea(
        child: BlocConsumer<KycWizardCubit, KycWizardState>(
          listenWhen: (prev, curr) =>
              prev.error != curr.error && curr.error != null,
          listener: _surfaceError,
          builder: (context, state) {
            if (state.step == KycWizardStep.status) {
              return const KycStatusView();
            }
            return Column(
              children: [
                _ProgressHeader(state: state),
                Expanded(child: _stepFor(state.step)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _stepFor(KycWizardStep step) {
    switch (step) {
      case KycWizardStep.id:
        return const KycIdStep();
      case KycWizardStep.selfie:
        return const KycSelfieStep();
      case KycWizardStep.vehicle:
        return const KycVehicleStep();
      case KycWizardStep.submitting:
        return const KycSubmittingView();
      case KycWizardStep.status:
        // Handled by the early return above; defensive fall-through.
        return const SizedBox.shrink();
    }
  }

  void _surfaceError(BuildContext context, KycWizardState state) {
    final l10n = AppLocalizations.of(context);
    final error = state.error;
    if (error == null) return;
    final cubit = context.read<KycWizardCubit>();
    final message = _messageFor(l10n, error);
    if (message != null) {
      showOmdsSnackbar(context, message: message);
    }
    // The vehicle-registration error is an inline field error and is cleared
    // by the cubit's setVehicleRegistration on input; everything else is a
    // one-shot snackbar that we ack here.
    if (error != KycWizardError.vehicleRegistrationRequired) {
      cubit.acknowledgeError();
    }
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
      case KycWizardError.vehicleRegistrationRequired:
        // Rendered inline under the text field; no snackbar.
        return null;
    }
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.state});

  final KycWizardState state;

  int _currentStepNumber() {
    switch (state.step) {
      case KycWizardStep.id:
        return 1;
      case KycWizardStep.selfie:
        return 2;
      case KycWizardStep.vehicle:
      case KycWizardStep.submitting:
        return 3;
      case KycWizardStep.status:
        return KycWizardState.totalCaptureSteps;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
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
              current: _currentStepNumber(),
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
              l10n.kycWizardStepVehicleLabel,
            ],
          ),
        ],
      ),
    );
  }
}
