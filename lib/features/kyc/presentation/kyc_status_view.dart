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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../photo_attachment/data/stub_photo_picker_service.dart';
import '../domain/kyc_contract_template.dart';
import '../domain/kyc_form_schema.dart';
import '../domain/kyc_gateway.dart';

/// Terminal-state view for the wizard: pending, approved, or rejected (JM-042).
///
/// Hosted inside [KycWizardScreen] at `/profile/kyc?step=status` (route name
/// `kyc-status`) — the wizard provides the Scaffold/AppBar, so this view only
/// renders the body. The body root carries `Semantics(identifier:
/// 'kyc_status_root')` (65_W2_TEST_PLAN §2 JM-042).
///
/// Status is read from `KycWizardCubit` state, which is hydrated by
/// `KycWizardCubit.loadStatus()` → `KycGateway.fetchStatus()` →
/// `GET /v1/kyc/status` (DioKycGateway, bound to the real Dio in DI). The mock
/// returns `{ state, rejection_reason?, submitted_at }` and 404 when none.
///
/// Per-variant CTAs + edges (21_NAV_PLAN §C JM-042; D38/D39/D52/D67):
///   approved → `kyc_status_feed_cta`    → jeeber-requests-home (`shell`)
///           → `kyc_status_wallet_cta`   → wallet-hub (`wallet`)
///           → `kyc_status_topup_cta`    → wallet-charge-info (`wallet-charge-info`)
///   pending  → `kyc_status_topup_cta`   → wallet-charge-info (top-up allowed
///              pre-approval, D38/D39) + `kyc_status_topup_allowed_note`
///   rejected → `kyc_status_view_rejection` → kyc-rejected (`kyc-rejected`)
///
/// D52/D87: rejection is FINAL — there is NO resubmit CTA here. The old
/// `kyc-status-resubmit` path was removed for JM-042/043; the rejected branch
/// now hands off to the dedicated `kyc-rejected` screen (appeal-via-support).
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

  /// Optional close callback wired by the host (router) — defaults to a
  /// `Navigator.maybePop` so the view works standalone in tests. Used as the
  /// secondary "back to profile" exit on the pending/rejected variants.
  final VoidCallback? onClose;

  final KycPollSchedule pollSchedule;

  @override
  State<KycStatusView> createState() => _KycStatusViewState();
}

class _KycStatusViewState extends State<KycStatusView>
    with WidgetsBindingObserver {
  /// JEBV4-271 / JEBV4-279 — auto-online after auto-KYC with NO re-login.
  ///
  /// On MSI the gateway auto-approves inline, so the submit RESPONSE already maps
  /// to `approved` and the wizard lands straight on [_ApprovedBody] (which fires
  /// [JeeberRoleActivator]). This poller is the SAFETY NET for every path that
  /// instead lands on the pending body: a best-effort auto-approve blip that
  /// returned `Submitted`, an idempotent replay, or a slower admin approval. While
  /// the status is still pending we re-read it on a timer AND on app-resume; the
  /// moment it flips to `approved` the cubit emits it, [_ApprovedBody] renders,
  /// and the jeeber goes online via `POST /v1/users/me/role/switch` — with NO
  /// re-login and NO dependence on an FCM push (bug JEBV4-281). Automatic checks
  /// use a bounded foreground schedule and stop earlier on a terminal status or
  /// disposal. The bound is per mounted view, so remounting starts a fresh
  /// bounded campaign.
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

  // ── FM-3 ADOPTION SEAM ────────────────────────────────────────────────────
  // The ONLY lifecycle entry points. When FM-3's pause/resume contract lands,
  // delete the WidgetsBindingObserver wiring and point its callbacks here.
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

/// Shared scaffolding for a status body: icon + title + body copy + a column of
/// CTAs pushed to the bottom. Keeps the three variants visually consistent.
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

  /// CTA widgets, top-to-bottom (primary first).
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

/// Pending / submitted: documents under review. Top-up is allowed pre-approval
/// (D38/D39) so the top-up CTA + the "allowed while pending" note both show.
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

/// Approved: the three post-approval entry points (feed / wallet / top-up).
///
/// ACTIVATION (jeeber role fix): reaching this body is the reliable "KYC just
/// approved" signal, so it fires [JeeberRoleActivator.activate] — a
/// `POST /v1/users/me/role/switch` that re-mints the jeeber-capable token and
/// flips [RoleAvailabilityCubit] / [RoleCubit] to the Jeeber surface. Without it
/// the token stayed client-scoped and `/v1/availability` 403'd ("Couldn't load
/// your availability"), so the approved jeeber could never go online. It fires
/// once on first render (so any CTA lands on the live jeeber surface) and again,
/// awaited, on the "Go to feed" tap so navigation never precedes the re-mint.
class _ApprovedBody extends StatefulWidget {
  const _ApprovedBody();

  @override
  State<_ApprovedBody> createState() => _ApprovedBodyState();
}

class _ApprovedBodyState extends State<_ApprovedBody> {
  /// The in-flight (or completed) activation. Cached so the auto-fire on first
  /// render and a later "Go to feed" tap share ONE switch call. Reset to null
  /// after a failure so a subsequent tap retries; stays null forever in a bare
  /// harness with no role cubits / DI (the view then degrades to plain nav).
  Future<JeeberActivationOutcome>? _activation;

  /// True while [_goToFeed] awaits activation, to disable the CTA meanwhile.
  bool _navigating = false;

  /// One-shot guard so the post-activation session refresh fires at most once.
  bool _sessionRefreshed = false;

  /// JEBV4-271 / JEBV4-279: the "do nothing" path must self-heal. The role grant
  /// commits on the gateway BEFORE the submit response returns, so the first
  /// switch normally succeeds — but a brief role-grant projection lag can answer
  /// the first `role/switch` with a 403 ([JeeberActivationOutcome.kycGated]) or a
  /// transient network blip ([failed]). Rather than strand an approved jeeber
  /// until they tap "Go to feed", the auto-fire retries a bounded number of times
  /// with a short backoff so the jeeber comes online on its own, no re-login.
  static const int _autoActivateMaxAttempts = 5;
  static const Duration _autoActivateRetryDelay = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    // Detect KYC=approved → activate the jeeber role the moment this view
    // renders, so the token is re-minted and the shell lights up the Jeeber
    // surface even before a CTA is tapped — with a bounded auto-retry so a
    // transient failure/projection-lag still resolves without a tap or re-login.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_autoActivate()),
    );
  }

  /// Fire the switch on first render and, on a transient failure or a
  /// still-propagating KYC gate, retry (bounded) so an approved jeeber goes
  /// online while doing NOTHING. Stops immediately on success, when there is no
  /// activator (bare harness), or once the widget is gone.
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
      // failed / kycGated → clear the cache so the next attempt re-issues the
      // switch, then back off briefly (the role grant may still be propagating).
      _activation = null;
      if (attempt < _autoActivateMaxAttempts - 1) {
        await Future<void>.delayed(_autoActivateRetryDelay);
        if (!mounted) return;
      }
    }
  }

  /// Resolve the activator from the app-level role cubits + DI and kick the
  /// switch once (cached). Returns null — a no-op — when the role cubits or a
  /// registered [RoleSwitchRepository] are absent (a bare widget test), so the
  /// approved view keeps working without an app shell.
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
    // onto a surface that will re-403; surface the error and let them retry.
    if (outcome == JeeberActivationOutcome.failed ||
        outcome == JeeberActivationOutcome.kycGated) {
      _activation = null; // allow the next tap to retry the switch
      showOmdsSnackbar(
        context,
        message: AppLocalizations.of(context).roleSettingSwitchError,
      );
      return;
    }
    // activated, or no activator in a bare harness → go to the jeeber feed.
    if (outcome == JeeberActivationOutcome.activated) _refreshSession();
    context.goNamed('shell');
  }

  /// JEBV4-271: once the `role/switch` has re-minted a jeeber-capable token,
  /// re-fetch the server session (`GET /v1/users/me` → `active_role` +
  /// `available_roles`) via [RoleSync] so the local role state is reconciled to
  /// the authoritative projection — keeping the additive shell, [RoleSync], and
  /// the live KYC gate (JEBV4-267) consistent with NO re-login. Runs only AFTER
  /// a confirmed [JeeberActivationOutcome.activated] (the token already encodes
  /// `jeeber`, so getMe returns the jeeber projection and cannot demote the
  /// just-activated jeeber). Fail-soft and fired at most once: [RoleSync.sync]
  /// never throws, and it self-resolves the getMe repository from DI's [Dio],
  /// degrading to a no-op in a bare harness that has no network wired.
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
        // → jeeber-requests-home. The feed lives in the DELIVERY tab of the
        // shell (no dedicated route); `shell` lands the approved jeeber on the
        // feed (`jeeber_feed_root`, JM-036) — now with a jeeber-capable token.
        Semantics(
          identifier: 'kyc_status_feed_cta',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            // L10N-REQ: kycStatusFeedCta ("Go to feed") — reusing
            // jeeberFeedSectionTitle ("Available requests").
            text: l10n.jeeberFeedSectionTitle,
            isEnabled: !_navigating,
            onTap: () => unawaited(_goToFeed()),
          ),
        ),
        // → wallet-hub (`wallet`, lands `wallet_available_balance`).
        Semantics(
          identifier: 'kyc_status_wallet_cta',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            // L10N-REQ: kycStatusWalletCta — reusing shellWalletChipLabel
            // ("Wallet").
            text: l10n.shellWalletChipLabel,
            variant: OmdsButtonVariant.secondary,
            onTap: () => context.goNamed('wallet'),
          ),
        ),
        // → wallet-charge-info (how to add funds; D92/D93).
        Semantics(
          identifier: 'kyc_status_topup_cta',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            // L10N-REQ: kycStatusTopupCta — reusing walletTopUpCta ("Top up").
            text: l10n.walletTopUpCta,
            variant: OmdsButtonVariant.text,
            onTap: () => context.goNamed('wallet-charge-info'),
          ),
        ),
      ],
    );
  }
}

/// Rejected: FINAL decision (D52/D87). No resubmit. The reason notice plus a
/// hand-off to the dedicated `kyc-rejected` screen (appeal via support).
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
        // → kyc-rejected (JM-043): the appeal-only final screen. This REPLACES
        // the old resubmit CTA (D52/D87).
        Semantics(
          identifier: 'kyc_status_view_rejection',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            // L10N-REQ: kycStatusViewRejectionCta ("View rejection details") —
            // reusing profileKycViewCta ("View status").
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

/// Resubmit-requested (E19 / Q-040 tri-state): the back-office asked the jeeber
/// to fix specific documents and send them again. UNLIKE [_RejectedBody] (which
/// is FINAL/appeal-only per D52/D87 and offers NO resubmit), this body shows the
/// reason, the per-slot "what to fix" list, and a `kyc_status_resubmit_cta` that
/// re-opens the wizard via [KycWizardCubit.resubmit] (reset draft → identity
/// step) so the jeeber can resubmit in place — no re-login, no restart.
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

/// The "what to fix" checklist rendered under the resubmit reason: one
/// localized line per [KycResubmitStep] the back-office flagged.
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

/// "You can still top up while pending" informational note (D38/D39).
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
        // The D20-removed `vehicleDocumentMissing` reason now folds into "other".
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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/kyc/kyc_status_view_preview_test.dart
// ===========================================================================
//
// The view is the terminal step of the KYC wizard (JM-042) and renders one of
// five bodies off `KycWizardCubit` state: an in-flight status read, pending
// (auto-checking or auto-check stopped), approved, rejected, or
// resubmit-requested. Every state below is driven the way the wizard drives it
// — an ambient `KycWizardCubit` hydrated by `KycWizardCubit.loadStatus` — so
// what the canvas shows is the real branch, not a hand-built stand-in.
//
// **Network-free by construction.** The cubit is built over
// `_KycStatusViewPreviewGateway`, a canned in-memory `KycGateway`; no `Dio`, no
// DI, no `DioKycGateway`. The guard in `jeebPreviewHost` is the net, not the
// plan.
//
// **Why the schedules are so short.** `KycStatusView` arms a real `Timer` for
// as long as the decision is pending, so a pending body is reachable in a
// *settled* frame only in one of the two states where the poller holds no
// timer: a probe in flight, or the budget spent. `_kycStatusViewSchedule` pulls
// the production 3 s first interval down to 10 ms so both are reached in the
// first frame instead of three seconds into the canvas.
//
// **What to look at.** These are full-body layouts at phone width, and the
// body is a plain `Column` with a `Spacer` and NO scroll view. On a 390x700
// phone body that already overflows at the DEFAULT text size for two of the
// states below, and at 200% text it overflows for ALL of them — by 180 dp on
// the *shortest* one — which pushes the CTAs off the bottom with nothing to
// scroll them back. The numbers are pinned in
// `test/previews/kyc/kyc_status_view_preview_test.dart`.
//
// Note also the two CTAs that borrow copy from other screens (the production
// code above marks both `L10N-REQ`): the approved primary reads "Available
// requests", and the rejected primary reads "View status".

/// A phone body box: 390 dp wide, and as tall as a 844 dp phone leaves once the
/// wizard's own AppBar, status bar and home indicator are taken out. Sizing the
/// canvas to the real body is the whole point here — a taller box would hide
/// exactly the overflow this unscrollable column produces.
const Size _kycStatusViewBox = Size(390, 700);

/// Poll schedule for previews: the first automatic re-check lands in 10 ms
/// instead of the production 3 s, so the canvas settles on the state under
/// review immediately. Nothing else about the schedule matters to the layout.
const KycPollSchedule _kycStatusViewSchedule = KycPollSchedule(
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
const KycPollSchedule _kycStatusViewOneProbeSchedule = KycPollSchedule(
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
class _KycStatusViewPreviewGateway implements KycGateway {
  _KycStatusViewPreviewGateway(this.snapshot, {this.resolvedReads = 1});

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
Widget _kycStatusViewHosted(
  KycSubmission snapshot, {
  int resolvedReads = 1,
  KycPollSchedule schedule = _kycStatusViewSchedule,
}) {
  return TickerMode(
    enabled: false,
    child: BlocProvider<KycWizardCubit>(
      create: (_) {
        final KycWizardCubit cubit = KycWizardCubit(
          pickerService: StubPhotoPickerService(),
          gateway: _KycStatusViewPreviewGateway(
            snapshot,
            resolvedReads: resolvedReads,
          ),
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
@JeebPreview(
  group: 'kyc',
  name: 'Status read in flight',
  size: _kycStatusViewBox,
)
Widget kycStatusViewLoading() => _kycStatusViewHosted(
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
@JeebPreview(
  group: 'kyc',
  name: 'Pending · re-check in flight',
  size: _kycStatusViewBox,
)
Widget kycStatusViewPendingChecking() =>
    _kycStatusViewHosted(const KycSubmission(status: KycStatus.pending));

/// Pending, budget spent: the poller has stopped and the screen now depends on
/// the user tapping (FM5-F11-W3).
///
/// Two things change at once — an extra note appears above the top-up card, and
/// the CTA stack INVERTS so the re-check is promoted to primary above "Top up".
/// The note is also what tips this body over the edge: the same body without it
/// ([kycStatusViewPendingChecking]) fits a 390x700 phone, and this one overflows
/// it by 40 dp at the DEFAULT text size, so "Back to profile" is already partly
/// clipped before accessibility settings enter the picture.
@JeebPreview(
  group: 'kyc',
  name: 'Pending · auto-check stopped',
  size: _kycStatusViewBox,
)
Widget kycStatusViewPendingAutoCheckStopped() => _kycStatusViewHosted(
      const KycSubmission(status: KycStatus.pending),
      resolvedReads: 2,
      schedule: _kycStatusViewOneProbeSchedule,
    );

/// Approved: the three post-approval entry points.
///
/// The primary CTA is meant to read "Go to feed" but ships the borrowed key
/// `jeeberFeedSectionTitle` — so the button on the approval screen actually says
/// **"Available requests"**, a section heading, not an action. The production
/// code above marks it `L10N-REQ`; this is what that shortcut looks like.
///
/// Reaching this body is also what fires [JeeberRoleActivator]. There are no
/// role cubits and no DI registration in a preview, so activation degrades to a
/// no-op exactly as it does in a bare widget test — nothing here touches the
/// network.
@JeebPreview(group: 'kyc', name: 'Approved', size: _kycStatusViewBox)
Widget kycStatusViewApproved() =>
    _kycStatusViewHosted(const KycSubmission(status: KycStatus.approved));

/// Rejected — FINAL (D52/D87). No resubmit CTA exists on this branch; the
/// hand-off is to the appeal-only `kyc-rejected` screen.
///
/// Same borrowed-copy problem as the approved body: the primary is supposed to
/// read "View rejection details" and instead ships `profileKycViewCta` —
/// **"View status"** — on a screen that IS the status.
@JeebPreview(
  group: 'kyc',
  name: 'Rejected · selfie mismatch',
  size: _kycStatusViewBox,
)
Widget kycStatusViewRejected() => _kycStatusViewHosted(
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
@JeebPreview(
  group: 'kyc',
  name: 'Resubmit requested · all slots',
  size: _kycStatusViewBox,
)
Widget kycStatusViewResubmitRequested() => _kycStatusViewHosted(
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
