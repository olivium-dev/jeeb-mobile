import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import 'social_provider.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';

// Brand colors MUST NOT be mapped to colorScheme. Google Blue = #4285F4, Apple = black/white per HIG.

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width, with room for the title, the note, the 48 dp pill and its tap
/// readout. The pill itself is only 48 dp tall — the rest of the height is for
const Size _socialSignInButtonSpecimenBox = Size(390, 260);

/// Title + note + the button + a live count of the taps that actually landed.
/// Stateful only so the canvas is interactive and so the readout is fed by the
/// widget's own `onTap`. There is no controller, no ticker and nothing to
class _SocialSignInButtonSpecimen extends StatefulWidget {
  const _SocialSignInButtonSpecimen({
    required this.title,
    required this.note,
    required this.provider,
    required this.isBusy,
    required this.isEnabled,
  });

  final String title;
  final String note;
  final SocialProvider provider;
  final bool isBusy;
  final bool isEnabled;

  @override
  State<_SocialSignInButtonSpecimen> createState() =>
      _SocialSignInButtonSpecimenState();
}

class _SocialSignInButtonSpecimenState
    extends State<_SocialSignInButtonSpecimen> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.title, style: theme.textTheme.titleSmall),
          const SizedBox(height: Spacing.twoXSmall),
          Text(
            widget.note,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.medium),
          SocialSignInButton(
            provider: widget.provider,
            isBusy: widget.isBusy,
            isEnabled: widget.isEnabled,
            identifier: 'preview_social_${widget.provider.wireName}',
            onTap: () => setState(() => _taps++),
          ),
          const SizedBox(height: Spacing.xSmall),
          Text('taps landed: $_taps', style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

Widget _socialSignInButtonHosted({
  required String title,
  required String note,
  required SocialProvider provider,
  bool isBusy = false,
  bool isEnabled = true,
}) =>
    _SocialSignInButtonSpecimen(
      title: title,
      note: note,
      provider: provider,
      isBusy: isBusy,
      isEnabled: isEnabled,
    );

/// The state every registration screen opens on, and the only one most reviews
/// ever look at.
@JeebPreview(
  group: 'auth',
  name: 'Google idle',
  size: _socialSignInButtonSpecimenBox,
)
Widget socialSignInButtonGoogleIdle() => _socialSignInButtonHosted(
      title: 'Google idle',
      note: 'The default reading. Blue G disc, navy label, white OMDS pill.',
      provider: SocialProvider.google,
    );

/// **The state that breaks.** In flight: the label is replaced by a literal
/// `'…'`.
@JeebPreview(
  group: 'auth',
  name: 'Google busy',
  size: _socialSignInButtonSpecimenBox,
)
Widget socialSignInButtonGoogleBusy() => _socialSignInButtonHosted(
      title: 'Google busy',
      note: 'Native sheet is up. Label collapses to a hardcoded ellipsis.',
      provider: SocialProvider.google,
      isBusy: true,
    );

/// Disabled because a *different* provider is signing in.
/// This is the real production combination: [SocialSignInSection] passes
@JeebPreview(
  group: 'auth',
  name: 'Google disabled',
  size: _socialSignInButtonSpecimenBox,
)
Widget socialSignInButtonGoogleDisabled() => _socialSignInButtonHosted(
      title: 'Google disabled',
      note: 'Another provider is in flight. Only the glyph disc greys out.',
      provider: SocialProvider.google,
      isEnabled: false,
    );

/// **The state that breaks.** Apple, whose glyph colour is inverted.
/// `build` computes `isDark` from the theme brightness and paints the mark
@JeebPreview(
  group: 'auth',
  name: 'Apple idle',
  size: _socialSignInButtonSpecimenBox,
)
Widget socialSignInButtonAppleIdle() => _socialSignInButtonHosted(
      title: 'Apple idle',
      note: 'Light theme paints a white Apple mark on the white pill.',
      provider: SocialProvider.apple,
    );

/// Facebook, whose label never names the provider.
/// There is no `socialContinueWithFacebook` key yet, so the button reuses the
@JeebPreview(
  group: 'auth',
  name: 'Facebook generic label',
  size: _socialSignInButtonSpecimenBox,
)
Widget socialSignInButtonFacebookGenericLabel() => _socialSignInButtonHosted(
      title: 'Facebook generic label',
      note: 'No dedicated key: the label is the generic Continue string.',
      provider: SocialProvider.facebook,
    );
