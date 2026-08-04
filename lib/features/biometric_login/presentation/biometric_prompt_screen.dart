import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_navy_surface_card.dart';
import '../../../l10n/app_localizations.dart';
import '../application/biometric_cubit.dart';

/// The glass disc carrying the fingerprint mark inside the navy band. Ø56 —
/// the band is a header, not 01's full-bleed stage, so it takes the small
/// hero-mark scale rather than `biometric_lock_screen`'s Ø118 disc.
const double _kMarkDiameter = Sizes.fiveXLarge;

/// On-navy glass fill/border alphas — the same pair `biometric_lock_screen`
/// (and 01's navy stage) use, so the two biometric surfaces read as one.
const double _kGlassFill = 0.10;
const double _kGlassBorder = 0.18;

// ORPHAN (JEBV4-227, verified 2026-07-12): superseded by biometric_auth/biometric_lock_cubit — see docs/project-understanding/reconciliation/orphans.md
//
// Redesign-2026-08 (W4): re-skinned onto the Jeeb design system to match its
// live successor `BiometricLockScreen` and the board's screen 02 — navy top
// band (mark → headline → subtitle), white top-aligned body, docked CTA pill.
// Same states, same copy, same single affordance.
class BiometricPromptScreen extends StatelessWidget {
  const BiometricPromptScreen({super.key, this.cubit});

  /// Catalog/test seam: inject a pre-built cubit (e.g. seeded into a specific
  /// state) instead of the self-constructed one. Defaults to null — production
  /// behavior (construct + `checkAvailability()`) is unchanged.
  final BiometricCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<BiometricCubit>.value(
        value: provided,
        child: const _BiometricPromptScaffold(),
      );
    }
    return BlocProvider(
      create: (_) => BiometricCubit()..checkAvailability(),
      child: const _BiometricPromptScaffold(),
    );
  }
}

class _BiometricPromptScaffold extends StatelessWidget {
  const _BiometricPromptScaffold();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BiometricCubit, BiometricState>(
      builder: (context, state) {
        return Semantics(
          identifier: 'biometric_prompt_root',
          container: true,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            // The band bleeds under BOTH bands: raw `.light` paints the
            // Android nav bar black instead of page navy.
            value: AppTheme.systemOverlayStyle,
            child: Scaffold(body: _PromptColumn(state: state)),
          ),
        );
      },
    );
  }
}

/// R1/§3 structure: band → top-aligned body → real emptiness → docked footer.
/// The band is full-bleed to the top edge, so no `SafeArea` sits above it.
///
/// The LayoutBuilder/ConstrainedBox/IntrinsicHeight trio is screen 02's — it
/// is what makes the [Spacer] legal inside a scroll view: the column fills the
/// viewport when it fits and degrades to a real scroll at large text scales.
class _PromptColumn extends StatelessWidget {
  const _PromptColumn({required this.state});
  final BiometricState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _PromptHeader(),
                _PromptBody(state: state),
                // Real emptiness (plan R1) — never fill it.
                const Spacer(),
                _PromptAction(state: state),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The navy welcome band (board `tpl 66-76`, as screen 02 builds it): bottom-
/// only r36, two off-canvas decorative rings, mark → headline → subtitle.
class _PromptHeader extends StatelessWidget {
  const _PromptHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return JeebNavySurfaceCard.topBand(
      rings: const [JeebNavyRing.bandOuter, JeebNavyRing.bandInner],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            dimension: _kMarkDiameter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.onPrimary.withValues(alpha: _kGlassFill),
                border: Border.all(
                  color: colorScheme.onPrimary.withValues(alpha: _kGlassBorder),
                  width: UIConstants.strokeWidthThin,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.fingerprint,
                  size: Sizes.twoXLarge,
                  color: colorScheme.onPrimary,
                  semanticLabel: l10n.biometricPromptSemanticLabel,
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.medium),
          Text(
            l10n.useBiometrics,
            style: context.jeebText.h1.copyWith(color: colorScheme.onPrimary),
          ),
          const SizedBox(height: Spacing.xSmall),
          Text(
            l10n.biometricPromptSubtitle,
            // Periwinkle is the board's on-navy pairing; the AA guard bans it
            // on light surfaces only.
            style: context.jeebText.body.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// The white body. Only two states put anything here — the CTA lives in the
/// docked footer, and the residual space below stays white (R1).
class _PromptBody extends StatelessWidget {
  const _PromptBody({required this.state});
  final BiometricState state;

  /// 24px gutters, one block below the band (§4.3).
  static const EdgeInsetsGeometry _padding = EdgeInsetsDirectional.fromSTEB(
    Spacing.xLarge,
    Spacing.xLarge,
    Spacing.xLarge,
    0,
  );

  @override
  Widget build(BuildContext context) {
    if (state == BiometricState.checking) {
      return const Padding(
        padding: _padding,
        child: Center(child: OmdsLoadingState()),
      );
    }
    if (state == BiometricState.unavailable) {
      return Padding(
        padding: _padding,
        child: JeebInfoNote.muted(
          icon: Icons.info_outline,
          text: AppLocalizations.of(context).biometricNotAvailable,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// The docked footer — the one affordance this screen has ever offered.
class _PromptAction extends StatelessWidget {
  const _PromptAction({required this.state});
  final BiometricState state;

  @override
  Widget build(BuildContext context) {
    if (state != BiometricState.available) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: JeebCtaFooter.single(
        child: Semantics(
          identifier: 'biometric_prompt_authenticate_cta',
          button: true,
          container: true,
          child: JeebCtaButton.primary(
            // Existing key, byte-identical EN copy to the literal it replaces.
            label: AppLocalizations.of(context).biometricUnlockAuthenticateCta,
            leadingIcon: Icons.fingerprint,
            onTap: () => context.read<BiometricCubit>().authenticate(),
          ),
        ),
      ),
    );
  }
}
