import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/jeeb_radii.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../l10n/app_localizations.dart';
import '../application/biometric_lock_cubit.dart';
import '../application/biometric_lock_state.dart';

/// The hero glass disc carrying the fingerprint mark. 118 is the kit's own
/// large hero-disc diameter (`JeebMicHero.sizeLarge`).
const double _kMarkDiameter = 118.0;

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
///     and the screen routes to `/register` [AC3].
///
/// The screen consumes the **app-level** [BiometricLockCubit] already provided
/// by `app.dart` (`BlocProvider.value`) — the SAME instance the router watches
/// in its `refreshListenable`. It must NOT spin up a fresh DI instance, or the
/// unlock would never reach the gate.
///
/// **Navigation is NOT handled in a listener.** AC2 (success): the router gate
/// redirects `/lock` → `/` the instant the cubit reports `phase == unlocked`,
/// so a screen-side `context.go` would only race the central gate (guardrail
/// §12 — "don't police a screen's reachability inside the screen"). AC3
/// (password): handled inline in the link's tap handler
/// ([_usePasswordFallback]), where the release-then-`goNamed` ordering is
/// guaranteed. The `BlocBuilder` exists only to disable the CTA while
/// prompting and to surface the in-flight line and the failure note.
///
/// **MIDNIGHT M3-35 — derived from R7 (OTP verify), the nearest ratified tile:**
/// a centred, single-purpose auth surface with no top bar (a gate must not
/// offer BACK, `app_router.dart` §"gate screens"). It takes R7's field verbatim
/// — periwinkle wash top-START and NO orange glow, a least-squares fit having
/// found no orange radial in R7's field at all (wave-D ruling) — and R7's
/// shape: copy straight on the field, one real empty band, a docked footer.
///
/// The pass-1 navy stage + docked white sheet are GONE (§10 retires the light
/// palette), and so are the two hand-painted orange décor rings: an orange
/// non-CTA is an orange-budget spend (§2.2) and glow belongs only where a tile
/// draws it. The three states are the cubit's: locked (default), prompting
/// (loading) and failed (error). There is no empty state — the route only
/// exists while `phase == locked`, so the surface can never be dataless.
class BiometricLockScreen extends StatelessWidget {
  const BiometricLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The field bleeds under both bands; raw `.light` paints the Android
      // nav bar black, and a transparent one leaves the OS scrim on top.
      value: AppTheme.systemOverlayStyle,
      child: Semantics(
        identifier: 'biometric_unlock_prompt',
        container: true,
        explicitChildNodes: true,
        child: Scaffold(
          // §1: scaffoldBackgroundColor is a fallback — the field is the ground.
          backgroundColor: Colors.transparent,
          body: JeebMidnightField(
            variant: JeebFieldVariant.content,
            glowColor: Colors.transparent,
            washPlacement: JeebFieldWashPlacement.topStart,
            animateDecor: false,
            child: SafeArea(
              child: BlocBuilder<BiometricLockCubit, BiometricLockState>(
                builder: (context, state) => _LockBody(state: state),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The whole surface: the hero mark and its copy centred in the band above a
/// docked CTA stack. The scroll view is what keeps that shape legal at 200%
/// text scale — the two spacers collapse and the column scrolls instead.
class _LockBody extends StatelessWidget {
  const _LockBody({required this.state});

  final BiometricLockState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Center(child: _LockMark()),
                const SizedBox(height: Spacing.xLarge),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: Spacing.xLarge,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.biometricUnlockTitle,
                        textAlign: TextAlign.center,
                        style: context.jeebText.h1
                            .copyWith(color: colorScheme.onSurface),
                      ),
                      const SizedBox(height: Spacing.xSmall),
                      Text(
                        l10n.biometricLockBody,
                        textAlign: TextAlign.center,
                        style: context.jeebText.body
                            .copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      if (state.isPrompting) ...[
                        const SizedBox(height: Spacing.small),
                        Text(
                          l10n.biometricLockPrompting,
                          key: const Key('biometricLock.promptingLine'),
                          textAlign: TextAlign.center,
                          style: context.jeebText.bodySmall
                              .copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                      if (state.hasFailed) ...[
                        const SizedBox(height: Spacing.medium),
                        JeebInfoNote.error(
                          icon: Icons.error_outline,
                          text: l10n.biometricLockFailure,
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                _LockActions(state: state),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The hero glass disc — §4's hero recipe (`glassFillEmphasis` 10% behind a 1px
/// `glassBorderStrong` 16%, real blur 10), which is exactly where the pass-1
/// hand-rolled .10 / .18 alphas snap on the ratified ladder. One of the two
/// `BackdropFilter`s §4 allows a screen, and the only one here.
class _LockMark extends StatelessWidget {
  const _LockMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _kMarkDiameter,
      child: JeebGlassCapsule(
        padding: EdgeInsets.zero,
        radius: JeebRadii.pill,
        // §7 scopes `floatNav` to the pill nav and sheets; under the mark it
        // pooled black and read as a dark ball rather than glass.
        shadow: JeebGlassCapsule.noShadow,
        child: Center(
          child: Icon(
            Icons.fingerprint,
            size: Sizes.fiveXLarge,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// The docked CTA stack: the authenticate pill over the password-fallback link.
///
/// The pill is PERIWINKLE ([JeebCtaButton.primary]): no tile draws an orange
/// act on this surface, and the standing theme ruling is "when in doubt: not
/// orange". Tapping it raises the platform dialog; on success the cubit flips
/// `phase → unlocked` and the central router gate lands the user on `/`
/// (last-used tab, D75) [AC2].
class _LockActions extends StatelessWidget {
  const _LockActions({required this.state});

  final BiometricLockState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebCtaFooter.single(
      below: Semantics(
        identifier: 'biometric_unlock_use_password_link',
        button: true,
        child: JeebCtaButton.text(
          label: l10n.biometricUnlockUsePasswordLink,
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
          onTap: () => context.read<BiometricLockCubit>().authenticate(),
        ),
      ),
    );
  }
}

void _usePasswordFallback(BuildContext context) {
  context.read<BiometricLockCubit>().usePasswordFallback();
  // EDGE: biometric-unlock → phone-OTP re-auth entry (`/register`). The
  // email/password `/login` funnel was removed in JEBV4-199 (Q-044).
  context.goNamed('register');
}
