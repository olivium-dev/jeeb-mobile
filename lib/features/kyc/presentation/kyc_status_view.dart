import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/role/jeeber_role_activator.dart';
import '../../../core/role/role_availability_cubit.dart';
import '../../../core/role/role_cubit.dart';
import '../../../core/role/role_sync.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/domain/role_switch_repository.dart';
import '../application/kyc_poll_schedule.dart';
import '../application/kyc_status_poll_controller.dart';
import '../application/kyc_wizard_cubit.dart';
import '../application/kyc_wizard_state.dart';
import '../domain/kyc_submission.dart';

class KycStatusView extends StatefulWidget {
  const KycStatusView({
    super.key,
    this.onClose,
    this.pollSchedule = KycPollSchedule.standard,
  });

  static const Key pendingTitleKey = Key('kyc-status-pending-title');
  static const Key approvedTitleKey = Key('kyc-status-approved-title');
  static const Key rejectedTitleKey = Key('kyc-status-rejected-title');
  static const Key resubmitTitleKey = Key('kyc-status-resubmit-title');
  static const Key backCtaKey = Key('kyc-status-back');
  static const Key checkAgainCtaKey = Key('kyc-status-check-again');
  static const Key rejectionReasonKey = Key('kyc-status-rejection-reason');

  final VoidCallback? onClose;

  final KycPollSchedule pollSchedule;

  @override
  State<KycStatusView> createState() => _KycStatusViewState();
}

class _KycStatusViewState extends State<KycStatusView>
    with WidgetsBindingObserver {
  /// JEBV4-271 / JEBV4-279 — auto-online after auto-KYC with NO re-login.
  ///
  KycStatusPollController? _pollController;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    final cubit = context.read<KycWizardCubit?>();
    if (cubit == null) return;
    _started = true;
    _pollController = _createPollController();
    if (_isPending(cubit.state.submission.status)) {
      _pollController!.start();
    }
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

  KycStatusPollController _createPollController() {
    return KycStatusPollController(
      intervalAt: widget.pollSchedule.intervalAt,
      maxResumeProbes: widget.pollSchedule.maxResumeProbes,
      probe: _probeStatus,
      onChanged: _onPollChanged,
    );
  }

  Future<bool> _probeStatus() async {
    final cubit = context.read<KycWizardCubit?>();
    if (!mounted || cubit == null) return false;
    await cubit.refreshStatus();
    if (!mounted) return false;
    return _isPending(cubit.state.submission.status);
  }

  bool _isPending(KycStatus status) {
    return status == KycStatus.pending || status == KycStatus.notSubmitted;
  }

  void _onPollChanged() {
    if (mounted) setState(() {});
  }

  void _onForeground() {
    _pollController?.resume();
  }

  void _onBackground() {
    _pollController?.pause();
  }

  @override
  void dispose() {
    _pollController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<KycWizardCubit, KycWizardState>(
      builder: (context, state) {
        final Widget body;
        if (state.isLoadingStatus) {
          body = const Center(child: OmdsLoadingState());
        } else {
          body = _bodyFor(context, state, l10n);
        }
        return Semantics(
          identifier: 'kyc_status_root',
          container: true,
          child: body,
        );
      },
    );
  }

  Widget _bodyFor(
    BuildContext context,
    KycWizardState state,
    AppLocalizations l10n,
  ) {
    return switch (state.submission.status) {
      KycStatus.notSubmitted || KycStatus.pending => _PendingBody(
        pollController: _pollController,
        onBackToProfile: () => _close(context),
      ),
      KycStatus.approved => const _ApprovedBody(),
      KycStatus.resubmitRequested => _ResubmitBody(
        reason: state.submission.rejectionReason,
        steps: state.submission.resubmitSteps,
        onResubmit: () => context.read<KycWizardCubit>().resubmit(),
        onBackToProfile: () => _close(context),
      ),
      KycStatus.rejected => _RejectedBody(
        reason: state.submission.rejectionReason,
        onBackToProfile: () => _close(context),
      ),
    };
  }

  void _close(BuildContext context) {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }
    Navigator.of(context).maybePop();
  }
}

class _StatusScaffold extends StatelessWidget {
  const _StatusScaffold({
    required this.titleKey,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.actions,
    this.extra,
  });

  final Key titleKey;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  final List<Widget> actions;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Spacing.xLarge),
          Icon(icon, size: Sizes.sixXLarge, color: iconColor),
          const SizedBox(height: Spacing.large),
          Text(
            title,
            key: titleKey,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Spacing.small),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (extra != null) ...[const SizedBox(height: Spacing.large), extra!],
          const Spacer(),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: Spacing.small),
            actions[i],
          ],
        ],
      ),
    );
  }
}

class _PendingBody extends StatelessWidget {
  const _PendingBody({
    required this.pollController,
    required this.onBackToProfile,
  });

  final KycStatusPollController? pollController;
  final VoidCallback onBackToProfile;

  @override
  Widget build(BuildContext context) {
    final controller = pollController;
    final isExpired = controller?.isExpired ?? false;
    return Semantics(
      identifier: isExpired ? 'kyc_status_poll_expired' : null,
      container: true,
      child: _PendingContent(
        isExpired: isExpired,
        isChecking: controller?.isInFlight ?? false,
        onCheckAgain: _checkAgain,
        onBackToProfile: onBackToProfile,
      ),
    );
  }

  void _checkAgain() {
    final controller = pollController;
    if (controller != null) unawaited(controller.checkNow());
  }
}

class _PendingContent extends StatelessWidget {
  const _PendingContent({
    required this.isExpired,
    required this.isChecking,
    required this.onCheckAgain,
    required this.onBackToProfile,
  });

  final bool isExpired;
  final bool isChecking;
  final VoidCallback onCheckAgain;
  final VoidCallback onBackToProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return _StatusScaffold(
      titleKey: KycStatusView.pendingTitleKey,
      icon: Icons.hourglass_top_rounded,
      iconColor: colorScheme.primary,
      title: l10n.kycStatusPendingTitle,
      body: l10n.kycStatusPendingBody,
      extra: _PendingNotes(isExpired: isExpired),
      actions: [
        _PendingActions(
          isExpired: isExpired,
          isChecking: isChecking,
          onCheckAgain: onCheckAgain,
          onBackToProfile: onBackToProfile,
        ),
      ],
    );
  }
}

class _PendingNotes extends StatelessWidget {
  const _PendingNotes({required this.isExpired});

  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final topupNote = _TopupAllowedNote(text: l10n.gateTopupNote);
    if (!isExpired) return topupNote;
    return Column(
      children: [
        _AutoCheckStoppedNote(text: l10n.kycStatusAutoCheckStoppedNote),
        const SizedBox(height: Spacing.small),
        topupNote,
      ],
    );
  }
}

class _AutoCheckStoppedNote extends StatelessWidget {
  const _AutoCheckStoppedNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _PendingActions extends StatelessWidget {
  const _PendingActions({
    required this.isExpired,
    required this.isChecking,
    required this.onCheckAgain,
    required this.onBackToProfile,
  });

  final bool isExpired;
  final bool isChecking;
  final VoidCallback onCheckAgain;
  final VoidCallback onBackToProfile;

  @override
  Widget build(BuildContext context) {
    if (isExpired) {
      return _ExpiredPendingActions(
        isChecking: isChecking,
        onCheckAgain: onCheckAgain,
        onBackToProfile: onBackToProfile,
      );
    }
    return _ActivePendingActions(
      isChecking: isChecking,
      onCheckAgain: onCheckAgain,
      onBackToProfile: onBackToProfile,
    );
  }
}

class _ExpiredPendingActions extends StatelessWidget {
  const _ExpiredPendingActions({
    required this.isChecking,
    required this.onCheckAgain,
    required this.onBackToProfile,
  });

  final bool isChecking;
  final VoidCallback onCheckAgain;
  final VoidCallback onBackToProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CheckAgainCta(
          isChecking: isChecking,
          isPromoted: true,
          onTap: onCheckAgain,
        ),
        const SizedBox(height: Spacing.small),
        const _PendingTopupCta(),
        const SizedBox(height: Spacing.small),
        _PendingBackCta(onTap: onBackToProfile),
      ],
    );
  }
}

class _ActivePendingActions extends StatelessWidget {
  const _ActivePendingActions({
    required this.isChecking,
    required this.onCheckAgain,
    required this.onBackToProfile,
  });

  final bool isChecking;
  final VoidCallback onCheckAgain;
  final VoidCallback onBackToProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PendingTopupCta(),
        const SizedBox(height: Spacing.small),
        _CheckAgainCta(
          isChecking: isChecking,
          isPromoted: false,
          onTap: onCheckAgain,
        ),
        const SizedBox(height: Spacing.small),
        _PendingBackCta(onTap: onBackToProfile),
      ],
    );
  }
}

class _CheckAgainCta extends StatelessWidget {
  const _CheckAgainCta({
    required this.isChecking,
    required this.isPromoted,
    required this.onTap,
  });

  final bool isChecking;
  final bool isPromoted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return OmdsLoadingButton(
      key: KycStatusView.checkAgainCtaKey,
      identifier: 'kyc_status_check_again_cta',
      text: l10n.kycStatusCheckAgainCta,
      isLoading: isChecking,
      backgroundColor: isPromoted
          ? colorScheme.primary
          : colorScheme.surfaceContainerHighest,
      textColor: isPromoted
          ? colorScheme.onPrimary
          : colorScheme.onSurfaceVariant,
      onTap: onTap,
    );
  }
}

class _PendingTopupCta extends StatelessWidget {
  const _PendingTopupCta();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'kyc_status_topup_cta',
      button: true,
      container: true,
      child: OmdsPrimaryButton(
        text: l10n.walletTopUpCta,
        variant: OmdsButtonVariant.secondary,
        onTap: () => context.goNamed('wallet-charge-info'),
      ),
    );
  }
}

class _PendingBackCta extends StatelessWidget {
  const _PendingBackCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'kyc_status_back',
      button: true,
      container: true,
      child: OmdsPrimaryButton(
        key: KycStatusView.backCtaKey,
        text: l10n.kycStatusBackToProfileCta,
        variant: OmdsButtonVariant.text,
        onTap: onTap,
      ),
    );
  }
}

class _ApprovedBody extends StatefulWidget {
  const _ApprovedBody();

  @override
  State<_ApprovedBody> createState() => _ApprovedBodyState();
}

class _ApprovedBodyState extends State<_ApprovedBody> {
  Future<JeeberActivationOutcome>? _activation;

  bool _navigating = false;

  bool _sessionRefreshed = false;

  static const int _autoActivateMaxAttempts = 5;
  static const Duration _autoActivateRetryDelay = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_autoActivate()),
    );
  }

  Future<void> _autoActivate() async {
    for (var attempt = 0; attempt < _autoActivateMaxAttempts; attempt++) {
      final pending = _activate();
      if (pending == null) return; // no activator wired — degrade to plain nav
      final outcome = await pending;
      if (!mounted) return;
      if (outcome == JeeberActivationOutcome.activated) {
        _refreshSession();
        return;
      }
      _activation = null;
      if (attempt < _autoActivateMaxAttempts - 1) {
        await Future<void>.delayed(_autoActivateRetryDelay);
        if (!mounted) return;
      }
    }
  }

  Future<JeeberActivationOutcome>? _activate() {
    if (!mounted) return _activation;
    final existing = _activation;
    if (existing != null) return existing;
    final roleCubit = context.read<RoleCubit?>();
    final availabilityCubit = context.read<RoleAvailabilityCubit?>();
    if (roleCubit == null ||
        availabilityCubit == null ||
        !sl.isRegistered<RoleSwitchRepository>()) {
      return null;
    }
    final activator = JeeberRoleActivator(
      roleSwitch: sl<RoleSwitchRepository>(),
      roleCubit: roleCubit,
      availabilityCubit: availabilityCubit,
    );
    return _activation = activator.activate();
  }

  Future<void> _goToFeed() async {
    if (_navigating) return;
    setState(() => _navigating = true);
    final pending = _activate();
    final outcome = pending == null ? null : await pending;
    if (!mounted) return;
    setState(() => _navigating = false);
    // A hard failure (network) or a still-gating 403 must NOT drop the jeeber
    if (outcome == JeeberActivationOutcome.failed ||
        outcome == JeeberActivationOutcome.kycGated) {
      _activation = null; // allow the next tap to retry the switch
      showOmdsSnackbar(
        context,
        message: AppLocalizations.of(context).roleSettingSwitchError,
      );
      return;
    }
    if (outcome == JeeberActivationOutcome.activated) _refreshSession();
    context.goNamed('shell');
  }

  void _refreshSession() {
    if (_sessionRefreshed || !mounted) return;
    final roleCubit = context.read<RoleCubit?>();
    final availabilityCubit = context.read<RoleAvailabilityCubit?>();
    if (roleCubit == null || availabilityCubit == null) return;
    _sessionRefreshed = true;
    unawaited(
      RoleSync(
        roleCubit: roleCubit,
        availabilityCubit: availabilityCubit,
      ).sync(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _StatusScaffold(
      titleKey: KycStatusView.approvedTitleKey,
      icon: Icons.verified_rounded,
      iconColor: theme.colorScheme.primary,
      title: l10n.kycStatusApprovedTitle,
      body: l10n.kycStatusApprovedBody,
      actions: [
        Semantics(
          identifier: 'kyc_status_feed_cta',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            text: l10n.jeeberFeedSectionTitle,
            isEnabled: !_navigating,
            onTap: () => unawaited(_goToFeed()),
          ),
        ),
        Semantics(
          identifier: 'kyc_status_wallet_cta',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            text: l10n.shellWalletChipLabel,
            variant: OmdsButtonVariant.secondary,
            onTap: () => context.goNamed('wallet'),
          ),
        ),
        Semantics(
          identifier: 'kyc_status_topup_cta',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            text: l10n.walletTopUpCta,
            variant: OmdsButtonVariant.text,
            onTap: () => context.goNamed('wallet-charge-info'),
          ),
        ),
      ],
    );
  }
}

class _RejectedBody extends StatelessWidget {
  const _RejectedBody({required this.reason, required this.onBackToProfile});

  final KycRejectionReason? reason;
  final VoidCallback onBackToProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _StatusScaffold(
      titleKey: KycStatusView.rejectedTitleKey,
      icon: Icons.error_outline_rounded,
      iconColor: theme.colorScheme.error,
      title: l10n.kycStatusRejectedTitle,
      body: l10n.kycStatusRejectedBody,
      extra: _RejectionReasonNotice(reason: reason),
      actions: [
        Semantics(
          identifier: 'kyc_status_view_rejection',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            text: l10n.profileKycViewCta,
            onTap: () => context.goNamed('kyc-rejected'),
          ),
        ),
        Semantics(
          identifier: 'kyc_status_back',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            key: KycStatusView.backCtaKey,
            text: l10n.kycStatusBackToProfileCta,
            variant: OmdsButtonVariant.text,
            onTap: onBackToProfile,
          ),
        ),
      ],
    );
  }
}

class _ResubmitBody extends StatelessWidget {
  const _ResubmitBody({
    required this.reason,
    required this.steps,
    required this.onResubmit,
    required this.onBackToProfile,
  });

  final KycRejectionReason? reason;
  final List<KycResubmitStep> steps;
  final VoidCallback onResubmit;
  final VoidCallback onBackToProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _StatusScaffold(
      titleKey: KycStatusView.resubmitTitleKey,
      icon: Icons.upload_file_rounded,
      iconColor: context.jeebRoles.warning,
      title: l10n.kycStatusResubmitTitle,
      body: l10n.kycStatusResubmitBody,
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RejectionReasonNotice(reason: reason),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: Spacing.medium),
            _ResubmitStepsList(steps: steps),
          ],
        ],
      ),
      actions: [
        Semantics(
          identifier: 'kyc_status_resubmit_cta',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            text: l10n.kycStatusResubmitRequestedCta,
            onTap: onResubmit,
          ),
        ),
        Semantics(
          identifier: 'kyc_status_back',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            key: KycStatusView.backCtaKey,
            text: l10n.kycStatusBackToProfileCta,
            variant: OmdsButtonVariant.text,
            onTap: onBackToProfile,
          ),
        ),
      ],
    );
  }
}

class _ResubmitStepsList extends StatelessWidget {
  const _ResubmitStepsList({required this.steps});

  final List<KycResubmitStep> steps;

  String _label(AppLocalizations l10n, KycResubmitStep step) {
    switch (step) {
      case KycResubmitStep.idFront:
        return l10n.kycResubmitStepIdFront;
      case KycResubmitStep.idBack:
        return l10n.kycResubmitStepIdBack;
      case KycResubmitStep.selfie:
        return l10n.kycResubmitStepSelfie;
      case KycResubmitStep.idNumber:
        return l10n.kycResubmitStepIdNumber;
      case KycResubmitStep.other:
        return l10n.kycResubmitStepOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'kyc_status_resubmit_steps',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final step in steps)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Spacing.xSmall),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: Sizes.small,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.small),
                  Expanded(
                    child: Text(
                      _label(l10n, step),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopupAllowedNote extends StatelessWidget {
  const _TopupAllowedNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'kyc_status_topup_allowed_note',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(Spacing.medium),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: OmdsBorderRadius.small,
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectionReasonNotice extends StatelessWidget {
  const _RejectionReasonNotice({required this.reason});

  final KycRejectionReason? reason;

  String _label(AppLocalizations l10n) {
    switch (reason) {
      case KycRejectionReason.idUnreadable:
        return l10n.kycRejectionReasonIdUnreadable;
      case KycRejectionReason.selfieMismatch:
        return l10n.kycRejectionReasonSelfieMismatch;
      case KycRejectionReason.expired:
        return l10n.kycRejectionReasonExpired;
      case KycRejectionReason.other:
      case null:
        return l10n.kycRejectionReasonOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      key: KycStatusView.rejectionReasonKey,
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.7),
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Text(
              _label(l10n),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
