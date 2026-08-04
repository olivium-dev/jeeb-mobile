import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
// The constants below are *brand-required* values dictated by the
// Google Identity Branding Guidelines and the Apple HIG. They are NOT
// themeable — Google's blue MUST be #4285F4 ("Google Blue 500") and
// Apple's monochrome logo MUST be pure black on a white button or pure
// white on a black button. Mapping these to `colorScheme.*` or to OMDS
// semantic tokens would put us in breach of the developer guidelines
// for both platforms (Apple App Store review item 4.0; Google Identity
// review). Tracked under JEEB-57; revisit if/when OMDS ships
// `OmdsBrandTokens` for third-party identity providers.
// ─────────────────────────────────────────────────────────────────────

/// Google Blue 500 — required by the Google Identity Branding Guidelines
/// for the "G" mark inside the sign-in button.
const Color _googleBrandBlue = Color(0xFF4285F4);

/// Pure white text inside the Google "G" disc — required by the
/// Google Identity Branding Guidelines.
const Color _googleGlyphForeground = Color(0xFFFFFFFF);

/// Facebook Brand Blue (#1877F2) — required by the Facebook Brand Guidelines
/// for the "f" mark inside the sign-in button. Matches `OmdsSocialButtons.facebook`'s
/// background so the glyph disc reads as part of the button.
const Color _facebookBrandBlue = Color(0xFF1877F2);

/// Pure white "f" glyph on the Facebook-blue button — Facebook Brand Guidelines.
const Color _facebookGlyphForeground = Color(0xFFFFFFFF);

/// Pure white for the Apple glyph. MIDNIGHT R6 makes the button a dark glass
/// pill, which is exactly the HIG's white-on-dark case; the pre-Midnight black
/// glyph was for OMDS's white pill and would now be invisible.
const Color _appleBrandWhite = Color(0xFFFFFFFF);

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
        return const _AppleGlyph(color: _appleBrandWhite);
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
    // TODO(midnight): l10n-queued — registrationSocialGoogleShort /
    // registrationSocialAppleShort. Brand names are identical in every shipped
    // locale (both ARBs already carry them latin), so the literal is honest
    // until the queue lands.
    switch (provider) {
      case SocialProvider.google:
        return 'Google';
      case SocialProvider.facebook:
        return 'Facebook';
      case SocialProvider.apple:
        return 'Apple';
    }
  }
}

/// Lightweight glyphs so we don't need to bundle an SVG asset for the MVP.
/// `flutter_svg` is not yet a dependency; switching to a real branded asset
/// (per Google/Apple HIG) is tracked under JEEB-57.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.omdsColorTokens;
    return Container(
      width: Sizes.large,
      height: Sizes.large,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Google's "Sign in with Google" branding guidelines lock the
        // glyph background to Google Blue 500 regardless of app theme;
        // the disabled state falls back to the OMDS grey token. See
        // the brand-color EXEMPT block at the top of this file.
        color: enabled ? _googleBrandBlue : tokens.greyScale400,
        shape: BoxShape.circle,
      ),
      child: Text(
        'G',
        // The Google brand "G" is white on the Google Blue background.
        // Typography intentionally bypasses textTheme color — this glyph
        // is a brand mark, not body copy. See top-of-file EXEMPT block.
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: _googleGlyphForeground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Facebook "f" mark. Like [_GoogleGlyph] this is a lightweight text glyph so
/// we don't bundle an SVG for the MVP (real branded asset tracked under
/// JEEB-57). The white "f" sits on a Facebook-blue disc that blends into the
/// brand-blue button background.
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
              color: _facebookGlyphForeground,
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
