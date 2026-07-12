import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/role/jeeber_role_activator.dart';
import '../../../core/role/role_availability_cubit.dart';
import '../../../core/role/role_cubit.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/domain/role_switch_repository.dart';
import '../application/kyc_wizard_cubit.dart';
import '../application/kyc_wizard_state.dart';
import '../domain/kyc_submission.dart';

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
  const KycStatusView({super.key, this.onClose});

  static const Key pendingTitleKey = Key('kyc-status-pending-title');
  static const Key approvedTitleKey = Key('kyc-status-approved-title');
  static const Key rejectedTitleKey = Key('kyc-status-rejected-title');
  static const Key backCtaKey = Key('kyc-status-back');
  static const Key rejectionReasonKey = Key('kyc-status-rejection-reason');

  /// Optional close callback wired by the host (router) — defaults to a
  /// `Navigator.maybePop` so the view works standalone in tests. Used as the
  /// secondary "back to profile" exit on the pending/rejected variants.
  final VoidCallback? onClose;

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
  /// re-login and NO dependence on an FCM push (bug JEBV4-281). Polling stops as
  /// soon as the status is terminal or the view is disposed, so it never runs
  /// unbounded.
  static const Duration _pollInterval = Duration(seconds: 3);
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(_pollInterval, (_) => _refreshWhilePending());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) _refreshWhilePending();
  }

  /// Re-read status only while it is still non-terminal; cancel the timer once a
  /// terminal decision is showing so a settled submission is never re-polled.
  void _refreshWhilePending() {
    if (!mounted) return;
    final cubit = context.read<KycWizardCubit?>();
    if (cubit == null) return;
    final status = cubit.state.submission.status;
    final isPending =
        status == KycStatus.pending || status == KycStatus.notSubmitted;
    if (!isPending) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    unawaited(cubit.refreshStatus());
  }

  @override
  void dispose() {
    _poll?.cancel();
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
    switch (state.submission.status) {
      case KycStatus.notSubmitted:
      case KycStatus.pending:
        return _PendingBody(onBackToProfile: () => _close(context));
      case KycStatus.approved:
        return const _ApprovedBody();
      case KycStatus.rejected:
        return _RejectedBody(
          reason: state.submission.rejectionReason,
          onBackToProfile: () => _close(context),
        );
    }
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
          if (extra != null) ...[
            const SizedBox(height: Spacing.large),
            extra!,
          ],
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
  const _PendingBody({required this.onBackToProfile});

  final VoidCallback onBackToProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _StatusScaffold(
      titleKey: KycStatusView.pendingTitleKey,
      icon: Icons.hourglass_top_rounded,
      iconColor: theme.colorScheme.primary,
      title: l10n.kycStatusPendingTitle,
      body: l10n.kycStatusPendingBody,
      // "Top-up allowed while pending" note (D38/D39). Reuses the gate's
      // top-up-in-review copy (L10N-REQ: kycStatusTopupAllowedNote — see
      // 50_ROUTE_REQUESTS JM-042).
      extra: _TopupAllowedNote(text: l10n.gateTopupNote),
      actions: [
        // → wallet-charge-info (D92/D93 — no in-app payment). Top-up is the
        // primary action a pending jeeber can take.
        Semantics(
          identifier: 'kyc_status_topup_cta',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            // L10N-REQ: kycStatusTopupCta — reusing walletTopUpCta ("Top up").
            text: l10n.walletTopUpCta,
            variant: OmdsButtonVariant.secondary,
            onTap: () => context.goNamed('wallet-charge-info'),
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
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_autoActivate()));
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
      if (outcome == JeeberActivationOutcome.activated) return;
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
    context.goNamed('shell');
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
  const _RejectedBody({
    required this.reason,
    required this.onBackToProfile,
  });

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
