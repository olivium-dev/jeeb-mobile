import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_radii.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../l10n/app_localizations.dart';
import 'social_provider.dart';

// ─────────────────────────────────────────────────────────────────────
// EXEMPT(flutter-material3-colorscheme-discipline,
//        flutter-no-magic-values-design-tokens):
//
// The remaining constants below are *brand-required* values dictated by the
// Facebook Brand Guidelines and Apple HIG: Facebook blue and the pure-white
// glyph/backing colour are not themeable. Google's mark now comes from the
// vetted official four-colour SVG and shares the white backing plate. Mapping
// these remaining values to `colorScheme.*` or OMDS semantic tokens would
// recolour third-party identity marks. Tracked under JEEB-57; revisit if/when
// OMDS ships `OmdsBrandTokens` for third-party identity providers.
// ─────────────────────────────────────────────────────────────────────

/// Facebook Brand Blue (#1877F2) — required by the Facebook Brand Guidelines
/// for the "f" mark inside the sign-in button. Matches `OmdsSocialButtons.facebook`'s
/// background so the glyph disc reads as part of the button.
const Color _facebookBrandBlue = Color(0xFF1877F2);

/// Brand-locked pure white: Google's backing plate, Facebook's "f", and
/// Apple's HIG white-on-dark glyph on the MIDNIGHT R6 glass pill.
const Color _brandGlyphWhite = Color(0xFFFFFFFF);

/// Board-measured social pill: h54 at [JeebRadii.lg] (R6 tile y 560–619, corner
/// 19 at the 1.1 export scale).
const double _kSocialPillHeight = 54;

/// Apple HIG specifies a 17pt glyph in a 44pt button; we ship a 22dp
/// raster glyph which keeps the visual weight inside the OMDS 48dp
/// button container. Cannot be mapped to `Sizes.*` (no 22dp token).
const double _appleGlyphIconSize = 22.0;

/// Renders a single social sign-in button as a MIDNIGHT frosted pill (R6:
/// "socials go frosted"). Hosts the Apple platform gate (the Apple button is
/// hidden on Android per UX direction — Apple's Sign-In on Android requires a
/// separate web fallback the gateway does not host yet).
class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton({
    super.key,
    required this.provider,
    required this.onTap,
    this.isBusy = false,
    this.isEnabled = true,
    this.identifier,
    this.compact = false,
  });

  final SocialProvider provider;
  final VoidCallback onTap;
  final bool isBusy;
  final bool isEnabled;

  /// Renders the bare brand name ("Google") instead of "Continue with Google".
  ///
  /// doc-13 P1: in the two-up row the long label clipped to "Continue with" on
  /// BOTH pills, so the provider — the only thing that distinguishes them —
  /// was the part that disappeared. The a11y label keeps the full sentence.
  final bool compact;

  /// Screen-scoped Maestro/accessibility identifier the caller stamps on the
  /// button's own interactive node (e.g. `login_social_google`). Null leaves
  /// the button unlabelled for tests — the subtree is otherwise unchanged, so
  /// every existing call site is byte-identical.
  final String? identifier;

  /// Whether the Apple button should render on the current platform. Static
  /// helper so the registration screen can decide whether to add the widget
  /// at all (we don't even build a hidden one).
  static bool isAppleAvailable() {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final live = isEnabled && !isBusy;
    // EXEMPT(flutter-omds-design-system-usage): `OmdsSocialButtons` paints
    // every provider as a WHITE pill in both brightnesses (see the wiring-02
    // note that used to live here), which is the one thing a Midnight screen
    // cannot host. The pill is now the kit's rest glass; the brand marks and
    // their guideline colours are unchanged.
    return Semantics(
      identifier: identifier,
      container: true,
      button: true,
      enabled: live,
      label: _accessibleLabel(l10n),
      child: JeebGlassCard(
        radius: JeebRadii.lg,
        padding: EdgeInsets.zero,
        onTap: live ? onTap : null,
        child: SizedBox(
          height: _kSocialPillHeight,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _glyph(live),
                const SizedBox(width: Spacing.xSmall),
                Flexible(
                  child: Text(
                    isBusy ? '…' : _visibleLabel(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.jeebText.cardTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glyph(bool live) {
    switch (provider) {
      case SocialProvider.google:
        return _GoogleGlyph(enabled: live);
      case SocialProvider.facebook:
        return _FacebookGlyph(enabled: live);
      case SocialProvider.apple:
        // HIG white-on-dark: the pill is dark glass now, so the mark is white.
        return const _AppleGlyph(color: _brandGlyphWhite);
    }
  }

  /// Always the full sentence — shortening the visible label must not shorten
  /// what a screen reader announces.
  String _accessibleLabel(AppLocalizations l10n) {
    switch (provider) {
      case SocialProvider.google:
        return l10n.registrationContinueWithGoogle;
      case SocialProvider.facebook:
        // No dedicated Facebook key exists yet (50_ROUTE_REQUESTS.md).
        return l10n.actionContinue;
      case SocialProvider.apple:
        return l10n.registrationContinueWithApple;
    }
  }

  String _visibleLabel(AppLocalizations l10n) {
    if (!compact) return _accessibleLabel(l10n);
    switch (provider) {
      case SocialProvider.google:
        return l10n.registrationSocialGoogleShort;
      case SocialProvider.facebook:
        // Still no Facebook key (see _accessibleLabel); the brand name is the
        // same latin proper noun in every shipped locale.
        return 'Facebook';
      case SocialProvider.apple:
        return l10n.registrationSocialAppleShort;
    }
  }
}

/// Google's JEEB-57 slice uses the vetted official four-colour SVG asset.
/// Facebook's lightweight sibling below remains tracked under JEEB-57.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : UIConstants.opacityDisabled,
      child: Container(
        width: Sizes.large,
        height: Sizes.large,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: _brandGlyphWhite,
          shape: BoxShape.circle,
        ),
        child: SvgPicture.asset(
          'assets/brand/google_g_logo.svg',
          width: Sizes.medium,
          height: Sizes.medium,
          matchTextDirection: false,
        ),
      ),
    );
  }
}

/// Facebook "f" mark. This remains a lightweight text glyph for the MVP (real
/// branded asset tracked under JEEB-57). The white "f" sits on a Facebook-blue
/// disc that blends into the brand-blue button background.
class _FacebookGlyph extends StatelessWidget {
  const _FacebookGlyph({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.omdsColorTokens;
    return Container(
      width: Sizes.large,
      height: Sizes.large,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? _facebookBrandBlue : tokens.greyScale400,
        shape: BoxShape.circle,
      ),
      child: Text(
        'f',
        // Brand mark, not body copy — bypasses textTheme color intentionally
        // (see the top-of-file EXEMPT block).
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: _brandGlyphWhite,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _AppleGlyph extends StatelessWidget {
  const _AppleGlyph({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Glyph size matches Apple HIG-mandated logo proportions inside the
    // 48dp social button. Routed through the named `_appleGlyphIconSize`
    // constant at the top of the file because there is no `Sizes.*`
    // token at 22dp; promotion to `OmdsIconSizes.brandMark` is tracked
    // under JEEB-57.
    return Icon(Icons.apple, size: _appleGlyphIconSize, color: color);
  }
}
