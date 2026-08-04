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
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/domain/role_switch_repository.dart';
import '../application/kyc_poll_schedule.dart';
import '../application/kyc_status_poll_controller.dart';
import '../application/kyc_wizard_cubit.dart';
import '../application/kyc_wizard_state.dart';
import '../domain/kyc_submission.dart';
import 'widgets/kyc_state_art.dart';
import 'widgets/kyc_status_marks.dart';

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
///
/// redesign-2026-08 (screen 22's companion; no render exists for this one, so
/// it applies the language of `22-become-a-jeeber` rather than a picture): a
/// re-skin only. 24px gutters, the mark/title/copy band top-aligned over a real
/// empty band (R1 — never vertically centre), notes as [JeebInfoNote], the
/// "what to fix" list as [JeebListRow]s in a grouped [JeebOutlinedCard], and
/// every CTA as a [JeebCtaButton] in a docked [JeebCtaFooter]. Same four
/// bodies, same CTA order, same edges, all identifiers unmoved.
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
          body = Center(
            child: SingleChildScrollView(
              child: JeebEmptyState(
                identifier: 'kyc_status_loading',
                variant: kycStateVariant,
                medallions: kycStateMedallions,
                status: JeebEmptyStateStatus.loading,
                // TODO(midnight): l10n-queued `kycStatusLoadingHeadline`; the
                // gate's key is the only shipped string for this exact read.
                headline: l10n.offerKycGateStatusChecking,
              ),
            ),
          );
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

/// The board's 24px side gutters with a block of air above the mark and below
/// the last note (§4.3 `--screen-gutter: 24`).
const EdgeInsetsGeometry _kStatusBodyPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.xLarge,
  Spacing.xLarge,
  Spacing.large,
);

/// Shared scaffolding for a status body: mark + title + body copy over a real
/// empty band, with the CTAs docked in a [JeebCtaFooter]. Keeps the four
/// variants visually consistent.
class _StatusScaffold extends StatelessWidget {
  const _StatusScaffold({
    required this.titleKey,
    required this.icon,
    required this.iconColor,
    required this.iconTint,
    required this.title,
    required this.body,
    required this.actions,
    this.extra,
    this.mark,
  });

  /// Matches the two authored marks' display size (88 / 100) so a glyph
  /// terminal and a Lottie terminal occupy the same head band.
  static const double glyphDiameter = 88;

  final Key titleKey;
  final IconData icon;

  /// Glyph ink — always the `on…Container` half of [iconTint]'s role pair, so
  /// the head reads as a soft tinted disc rather than a raw red slab.
  final Color iconColor;
  final Color iconTint;
  final String title;
  final String body;

  /// CTA widgets, top-to-bottom (the promoted one first — it becomes the
  /// footer's `child`, the rest stack beneath it in order).
  final List<Widget> actions;
  final Widget? extra;

  /// Optional Lottie mark that takes the head slot instead of [icon]
  /// (08-MOTION-SPEC §2.8/§2.5). The icon params stay required so the two
  /// bodies with no authored composition keep their glyph.
  final Widget? mark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jeebText = context.jeebText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          // Scrolls instead of overflowing when a looping mark, a long Arabic
          // reason and a large text scale meet on a short device; whatever is
          // left over stays white and top-aligned (R1).
          child: ListView(
            padding: _kStatusBodyPadding,
            children: [
              mark ?? _GlyphMark(icon: icon, ink: iconColor, tint: iconTint),
              const SizedBox(height: Spacing.large),
              Text(
                title,
                key: titleKey,
                textAlign: TextAlign.center,
                style: jeebText.h1.copyWith(color: theme.colorScheme.primary),
              ),
              const SizedBox(height: Spacing.small),
              Text(
                body,
                textAlign: TextAlign.center,
                style: jeebText.body.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (extra != null) ...[
                const SizedBox(height: Spacing.xLarge),
                extra!,
              ],
            ],
          ),
        ),
        JeebCtaFooter.single(
          spacing: Spacing.small,
          below: _stackedActions(),
          child: actions.first,
        ),
      ],
    );
  }

  /// The secondary CTAs, in order, under the footer's promoted one.
  Widget? _stackedActions() {
    if (actions.length < 2) return null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 1; i < actions.length; i++) ...[
          if (i > 1) const SizedBox(height: Spacing.small),
          actions[i],
        ],
      ],
    );
  }
}

/// The head slot for a terminal with no authored composition: the glyph on a
/// soft role-tinted disc, sized to the Lottie marks it sits beside.
class _GlyphMark extends StatelessWidget {
  const _GlyphMark({
    required this.icon,
    required this.ink,
    required this.tint,
  });

  final IconData icon;
  final Color ink;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: _StatusScaffold.glyphDiameter,
        height: _StatusScaffold.glyphDiameter,
        decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: Sizes.threeXLarge, color: ink),
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
      iconTint: colorScheme.surfaceContainerHigh,
      // The scan-line loop says "your document is being checked" better than a
      // static hourglass; the glyph stays as the reduce-motion-free fallback
      // for any caller that omits the mark.
      mark: const KycReviewMark(),
      title: l10n.kycStatusPendingTitle,
      body: l10n.kycStatusPendingBody,
      extra: _PendingNotes(isExpired: isExpired),
      // Order is contract, not taste (FM5-F11-W3/W4): once the automatic
      // poller has expired, re-checking is the do-it-now action and takes the
      // promoted navy pill above top-up; before that it sits below it.
      actions: [
        if (isExpired)
          _CheckAgainCta(
            isChecking: isChecking,
            isPromoted: true,
            onTap: onCheckAgain,
          ),
        const _PendingTopupCta(),
        if (!isExpired)
          _CheckAgainCta(
            isChecking: isChecking,
            isPromoted: false,
            onTap: onCheckAgain,
          ),
        _BackToProfileCta(onTap: onBackToProfile),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
      style: context.jeebText.bodySmall.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// "Check again" — a navy pill once the automatic poller has expired (the
/// do-it-now moment), the outline treatment while it is still running.
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
    final l10n = AppLocalizations.of(context);
    return JeebCtaButton(
      key: KycStatusView.checkAgainCtaKey,
      identifier: 'kyc_status_check_again_cta',
      label: l10n.kycStatusCheckAgainCta,
      variant: isPromoted ? JeebCtaVariant.primary : JeebCtaVariant.outline,
      isLoading: isChecking,
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
      child: JeebCtaButton.outline(
        label: l10n.walletTopUpCta,
        onTap: () => context.goNamed('wallet-charge-info'),
      ),
    );
  }
}

class _BackToProfileCta extends StatelessWidget {
  const _BackToProfileCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'kyc_status_back',
      button: true,
      container: true,
      child: JeebCtaButton.text(
        key: KycStatusView.backCtaKey,
        label: l10n.kycStatusBackToProfileCta,
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
      iconTint: theme.colorScheme.surfaceContainerHigh,
      // The shared terminal mark (08-MOTION-SPEC §2.5): an approval must feel
      // identical to a delivered order and a landed top-up. One-shot.
      mark: const KycApprovedMark(),
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
          child: JeebCtaButton.primary(
            // L10N-REQ: kycStatusFeedCta ("Go to feed") — reusing
            // jeeberFeedSectionTitle ("Available requests").
            label: l10n.jeeberFeedSectionTitle,
            isEnabled: !_navigating,
            onTap: () => unawaited(_goToFeed()),
          ),
        ),
        // → wallet-hub (`wallet`, lands `wallet_available_balance`).
        Semantics(
          identifier: 'kyc_status_wallet_cta',
          button: true,
          container: true,
          child: JeebCtaButton.outline(
            // L10N-REQ: kycStatusWalletCta — reusing shellWalletChipLabel
            // ("Wallet").
            label: l10n.shellWalletChipLabel,
            onTap: () => context.goNamed('wallet'),
          ),
        ),
        // → wallet-charge-info (how to add funds; D92/D93).
        Semantics(
          identifier: 'kyc_status_topup_cta',
          button: true,
          container: true,
          child: JeebCtaButton.text(
            // L10N-REQ: kycStatusTopupCta — reusing walletTopUpCta ("Top up").
            label: l10n.walletTopUpCta,
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
      // Wave 0's soft error pair, never the legacy #B00020 slab.
      iconColor: theme.colorScheme.onErrorContainer,
      iconTint: theme.colorScheme.errorContainer,
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
          child: JeebCtaButton.primary(
            // L10N-REQ: kycStatusViewRejectionCta ("View rejection details") —
            // reusing profileKycViewCta ("View status").
            label: l10n.profileKycViewCta,
            onTap: () => context.goNamed('kyc-rejected'),
          ),
        ),
        _BackToProfileCta(onTap: onBackToProfile),
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
      iconColor: context.jeebRoles.onWarningContainer,
      iconTint: context.jeebRoles.warningContainer,
      title: l10n.kycStatusResubmitTitle,
      body: l10n.kycStatusResubmitBody,
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RejectionReasonNotice(reason: reason),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: Spacing.small),
            _ResubmitStepsList(steps: steps),
          ],
        ],
      ),
      actions: [
        Semantics(
          identifier: 'kyc_status_resubmit_cta',
          button: true,
          container: true,
          child: JeebCtaButton.primary(
            label: l10n.kycStatusResubmitRequestedCta,
            onTap: onResubmit,
          ),
        ),
        _BackToProfileCta(onTap: onBackToProfile),
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
    // The kit's grouped card draws the inset dividers, so the rows carry no
    // separator of their own. The glyph stays the bare `arrow_forward_rounded`
    // — it declares `matchTextDirection`, so `Icon` already mirrors it in
    // Arabic; resolving it through `DirectionalIcons` would flip it twice.
    return Semantics(
      identifier: 'kyc_status_resubmit_steps',
      container: true,
      child: JeebOutlinedCard.grouped(
        children: [
          for (final step in steps)
            JeebListRow(
              icon: Icons.arrow_forward_rounded,
              title: _label(l10n, step),
              showChevron: false,
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
    // The outer wrapper keeps `kyc_status_topup_allowed_note` (jm-042 Maestro)
    // exactly where it was, so the note itself takes no identifier.
    return Semantics(
      identifier: 'kyc_status_topup_allowed_note',
      container: true,
      child: JeebInfoNote.muted(
        icon: Icons.info_outline_rounded,
        text: text,
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
    // The kit's error tone is Wave 0's soft errorContainer pair — the decision
    // IS the message, so it keeps its role colour on every surface. The glyph
    // stays `info_outline` (not `error_outline`): the head of the rejected body
    // already owns that mark.
    return JeebInfoNote.error(
      key: KycStatusView.rejectionReasonKey,
      icon: Icons.info_outline_rounded,
      text: _label(l10n),
    );
  }
}
