import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

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

/// Pure black for the Apple glyph when it sits on a white button.
const Color _appleBrandBlack = Color(0xFF000000);

/// Pure white for the Apple glyph when it sits on a black button.
const Color _appleBrandWhite = Color(0xFFFFFFFF);

/// Apple HIG specifies a 17pt glyph in a 44pt button; we ship a 22dp
/// raster glyph which keeps the visual weight inside the OMDS 48dp
/// button container. Cannot be mapped to `Sizes.*` (no 22dp token).
const double _appleGlyphIconSize = 22.0;

/// Renders a single OMDS-styled social sign-in button. Hosts the Apple
/// platform gate (the Apple button is hidden on Android per UX direction —
/// Apple's Sign-In on Android requires a separate web fallback the gateway
/// does not host yet).
class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton({
    super.key,
    required this.provider,
    required this.onTap,
    this.isBusy = false,
    this.isEnabled = true,
  });

  final SocialProvider provider;
  final VoidCallback onTap;
  final bool isBusy;
  final bool isEnabled;

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
    final brightness = Theme.of(context).brightness;
    final effectiveOnTap = (isEnabled && !isBusy) ? onTap : () {};

    switch (provider) {
      case SocialProvider.google:
        return Semantics(
          button: true,
          enabled: isEnabled && !isBusy,
          label: l10n.registrationContinueWithGoogle,
          child: OmdsSocialButtons.google(
            icon: _GoogleGlyph(enabled: isEnabled && !isBusy),
            text: isBusy ? '…' : l10n.registrationContinueWithGoogle,
            onTap: effectiveOnTap,
          ),
        );
      case SocialProvider.facebook:
        return Semantics(
          button: true,
          enabled: isEnabled && !isBusy,
          // Visible label reuses the locale-safe generic `actionContinue`
          // ("Continue") — no dedicated Facebook key exists yet (requested in
          // 50_ROUTE_REQUESTS.md for a copy-polish swap to
          // `socialContinueWithFacebook`). Maestro asserts on the caller's
          // `*_social_facebook` identifier, never this text.
          label: l10n.actionContinue,
          child: OmdsSocialButtons.facebook(
            // Facebook brand "f" mark on the brand-blue button. White glyph per
            // the Facebook Brand Guidelines — see the EXEMPT block at top.
            icon: _FacebookGlyph(enabled: isEnabled && !isBusy),
            text: isBusy ? '…' : l10n.actionContinue,
            onTap: effectiveOnTap,
          ),
        );
      case SocialProvider.apple:
        final isDark = brightness == Brightness.dark;
        return Semantics(
          button: true,
          enabled: isEnabled && !isBusy,
          label: l10n.registrationContinueWithApple,
          child: OmdsSocialButtons.apple(
            // Apple HIG mandates a black glyph on the light "Sign in with
            // Apple" button and a white glyph on the dark variant — see
            // the brand-color EXEMPT block at the top of this file.
            icon: _AppleGlyph(
              color: isDark ? _appleBrandBlack : _appleBrandWhite,
            ),
            text: isBusy ? '…' : l10n.registrationContinueWithApple,
            onTap: effectiveOnTap,
            isDark: isDark,
          ),
        );
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
