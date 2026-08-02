import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import 'social_provider.dart';

// Brand colors MUST NOT be mapped to colorScheme. Google Blue = #4285F4, Apple = black/white per HIG.
// EXEMPTED from flutter-material3-colorscheme-discipline and flutter-no-magic-values-design-tokens.

const Color _googleBrandBlue = Color(0xFF4285F4);
const Color _googleGlyphForeground = Color(0xFFFFFFFF);
const Color _facebookBrandBlue = Color(0xFF1877F2);
const Color _facebookGlyphForeground = Color(0xFFFFFFFF);
const Color _appleBrandBlack = Color(0xFF000000);
const Color _appleBrandWhite = Color(0xFFFFFFFF);

/// 22dp glyph; no Sizes token exists.
const double _appleGlyphIconSize = 22.0;

class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton({
    super.key,
    required this.provider,
    required this.onTap,
    this.isBusy = false,
    this.isEnabled = true,
    this.identifier,
  });

  final SocialProvider provider;
  final VoidCallback onTap;
  final bool isBusy;
  final bool isEnabled;

  final String? identifier;

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
          identifier: identifier,
          container: true,
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
          identifier: identifier,
          container: true,
          button: true,
          enabled: isEnabled && !isBusy,
          label: l10n.actionContinue,
          child: OmdsSocialButtons.facebook(
            icon: _FacebookGlyph(enabled: isEnabled && !isBusy),
            text: isBusy ? '…' : l10n.actionContinue,
            onTap: effectiveOnTap,
          ),
        );
      case SocialProvider.apple:
        final isDark = brightness == Brightness.dark;
        return Semantics(
          identifier: identifier,
          container: true,
          button: true,
          enabled: isEnabled && !isBusy,
          label: l10n.registrationContinueWithApple,
          child: OmdsSocialButtons.apple(
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
        color: enabled ? _googleBrandBlue : tokens.greyScale400,
        shape: BoxShape.circle,
      ),
      child: Text(
        'G',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: _googleGlyphForeground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

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
    return Icon(Icons.apple, size: _appleGlyphIconSize, color: color);
  }
}
