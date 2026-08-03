import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../l10n/app_localizations.dart';
import '../application/biometric_lock_cubit.dart';
import '../application/biometric_lock_state.dart';

/// The glass disc carrying the fingerprint mark. Ø118 — the diameter 01 gives
/// its decorative mic, so the two navy fields read as the same surface.
const double _kMarkDiameter = 118.0;

/// The two faint accent rings behind the mark, copied from 01's navy stage
/// (Ø380 / Ø270 at 1.5px). Rationed orange: décor only, never a fill.
const double _kOuterRingRadius = 190.0;
const double _kInnerRingRadius = 135.0;
const double _kOuterRingAlpha = 0.10;
const double _kInnerRingAlpha = 0.18;

/// On-navy glass fill/border alphas — 01's `_kGlassFill` / `_kGlassBorder`.
const double _kGlassFill = 0.10;
const double _kGlassBorder = 0.18;

/// Ceiling for the docked sheet so a very large text scale scrolls the copy
/// instead of eating the navy field.
const double _kSheetMaxHeightFactor = 0.62;

/// `biometric-unlock` (JM-005, D23) — the real `/lock` gate screen.
///
/// A returning, biometric-enrolled user lands here on cold start (the
/// `app_router.dart` biometric gate holds them on `/lock` while the cubit
/// `phase == locked`, see 40_GUARDRAILS_ARCH §5.5). They either:
///
///   * tap `biometric_unlock_authenticate_cta` → the platform biometric dialog
///     (NO OTP, D23). On success the cubit flips `phase → unlocked`, which
///     releases the router gate → `/` (last-used tab, D75) [AC2]; or
///   * tap `biometric_unlock_use_password_link` → the cubit releases the gate
///     and the screen routes to `/login` [AC3].
///
/// The screen consumes the **app-level** [BiometricLockCubit] already provided
/// by `app.dart` (`BlocProvider.value`) — the SAME instance the router watches
/// in its `refreshListenable`. It must NOT spin up a fresh DI instance, or the
/// unlock would never reach the gate. Routing the success path through the
/// central redirect (not a screen-side `context.go`) honours the guardrail
/// "don't police a screen's reachability inside the screen" (§12).
///
/// Redesign-2026-08: the lock surface is the board's **full-bleed navy field**
/// (screen 01's treatment — accent rings, a glass hero mark, then a docked
/// white sheet carrying the copy and the CTA stack). Re-skin only: the same two
/// affordances, the same copy, the same routing.
class BiometricLockScreen extends StatelessWidget {
  const BiometricLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The upper band is the navy field, so the status-bar icons must paint
      // light; `main()` sets dark icons for the predominantly white screens.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Semantics(
        identifier: 'biometric_unlock_prompt',
        container: true,
        explicitChildNodes: true,
        child: Scaffold(
          // Navy under both bands: the sheet's rounded top corners let the
          // field show through, and the bottom inset stays white.
          backgroundColor: colorScheme.secondaryContainer,
          // Nav is NOT handled in a listener:
          //  * AC2 (success) — the router gate redirects `/lock` → `/` the
          //    instant the cubit reports `phase == unlocked`, so a screen-side
          //    `context.go` would only race the central gate (guardrail §12).
          //  * AC3 (password) — handled inline in the link's tap handler
          //    (`_usePasswordFallback`), where the release-then-`goNamed`
          //    ordering is guaranteed.
          // The builder exists only to disable the CTA while prompting and to
          // surface the failure hint.
          body: BlocBuilder<BiometricLockCubit, BiometricLockState>(
            builder: (context, state) {
              return Column(
                children: [
                  const Expanded(child: _LockStage()),
                  _LockSheet(state: state),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Band 1: the navy field — decorative accent rings behind the fingerprint
/// mark. Pure chrome; it carries no semantics and no tap target (the CTA in
/// the sheet is the only way to raise the platform prompt).
class _LockStage extends StatelessWidget {
  const _LockStage();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // MANDATORY: the Ø380 ring is wider than a 360dp device.
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _AccentRingsPainter(color: context.jeebRoles.accent),
              ),
            ),
          ),
          Center(
            child: SizedBox.square(
              dimension: _kMarkDiameter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.onPrimary.withValues(alpha: _kGlassFill),
                  border: Border.all(
                    color: colorScheme.onPrimary
                        .withValues(alpha: _kGlassBorder),
                    width: UIConstants.strokeWidthThin,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.fingerprint,
                    size: Sizes.fiveXLarge,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two faint accent rings centred on the mark.
///
/// A painter rather than two positioned circles: an Ø380 box inside a narrower
/// stage would need `UnconstrainedBox`, which throws debug overflow errors in
/// widget tests. A painter has no layout and no semantics, and the stage's
/// `ClipRect` bounds it.
class _AccentRingsPainter extends CustomPainter {
  const _AccentRingsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = UIConstants.strokeWidthThin;
    canvas.drawCircle(
      centre,
      _kOuterRingRadius,
      stroke..color = color.withValues(alpha: _kOuterRingAlpha),
    );
    canvas.drawCircle(
      centre,
      _kInnerRingRadius,
      stroke..color = color.withValues(alpha: _kInnerRingAlpha),
    );
  }

  @override
  bool shouldRepaint(_AccentRingsPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Band 2: the docked white sheet — headline, body, the failure hint and the
/// CTA stack. Same three pieces of copy the screen has always shown.
class _LockSheet extends StatelessWidget {
  const _LockSheet({required this.state});

  final BiometricLockState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Spacing.twoXLarge),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.sizeOf(context).height * _kSheetMaxHeightFactor,
          ),
          child: SingleChildScrollView(
            // The sheet never scrolls at 1.0x text scale; this only rescues
            // very large accessibility scales.
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Spacing.xLarge,
                Spacing.twoXLarge,
                Spacing.xLarge,
                Spacing.twoXLarge,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.biometricUnlockTitle,
                    textAlign: TextAlign.center,
                    style: context.jeebText.h1.copyWith(
                      letterSpacing: -0.6,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: Spacing.xSmall),
                  Text(
                    l10n.biometricLockBody,
                    textAlign: TextAlign.center,
                    // Warm brown, never periwinkle: periwinkle on white fails
                    // AA and a contrast test guards it (plan §4.1).
                    style: context.jeebText.body.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (state.hasFailed) ...[
                    const SizedBox(height: Spacing.medium),
                    JeebInfoNote.error(
                      icon: Icons.error_outline,
                      text: l10n.biometricLockFailure,
                    ),
                  ],
                  const SizedBox(height: Spacing.xLarge),
                  JeebCtaFooter.single(
                    // The sheet already owns the 24px gutters and the bottom
                    // inset, so the footer contributes no padding of its own.
                    padding: EdgeInsetsDirectional.zero,
                    below: Semantics(
                      identifier: 'biometric_unlock_use_password_link',
                      button: true,
                      child: JeebCtaButton.text(
                        label: l10n.biometricUnlockUsePasswordLink,
                        // AC3: release the routing gate FIRST (so the gate
                        // doesn't bounce us back to `/lock`), then route to
                        // `/register` (the phone-OTP re-auth entry; the
                        // email/password `/login` funnel was removed in
                        // JEBV4-199). The emit is synchronous, the
                        // `refreshListenable` notify is async, so the
                        // synchronous `goNamed('register')` redirect already
                        // sees a released (non-locked) phase + a non-`/lock`
                        // location → the entry sticks.
                        onTap: () => _usePasswordFallback(context),
                      ),
                    ),
                    child: Semantics(
                      identifier: 'biometric_unlock_authenticate_cta',
                      button: true,
                      enabled: !state.isPrompting,
                      child: JeebCtaButton.primary(
                        label: state.hasFailed
                            ? l10n.biometricLockRetry
                            : l10n.biometricUnlockAuthenticateCta,
                        isEnabled: !state.isPrompting,
                        // On success the cubit flips `phase → unlocked` and
                        // the central router gate lands the user on `/`
                        // (last-used tab, D75) [AC2]. No OTP (D23).
                        onTap: () =>
                            context.read<BiometricLockCubit>().authenticate(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _usePasswordFallback(BuildContext context) {
  context.read<BiometricLockCubit>().usePasswordFallback();
  // EDGE: biometric-unlock → phone-OTP re-auth entry (`/register`). The
  // email/password `/login` funnel was removed in JEBV4-199 (Q-044), so the
  // biometric fallback now re-authenticates via phone-OTP + social.
  context.goNamed('register');
}
