import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:omds/omds.dart';

import '../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../core/previews/jeeb_preview.dart';

class BrandedSplash extends StatelessWidget {
  const BrandedSplash({super.key});

  static const String _logoAsset = 'assets/brand/jeeb_logo.svg';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Semantics(
        identifier: '_splash_screen',
        container: true,
        child: ColoredBox(
          color: colorScheme.secondaryContainer,
          child: const SafeArea(child: _SplashBody()),
        ),
      ),
    );
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Spacer(flex: 10),
        _SplashLogo(),
        Spacer(flex: 9),
        _SplashTagline(),
        SizedBox(height: Spacing.fourXLarge),
      ],
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: '_splash_logo',
      label: l10n.splashLogoSemantic,
      image: true,
      container: true,
      child: Center(
        child: SvgPicture.asset(
          BrandedSplash._logoAsset,
          width: Sizes.twoHundredLarge,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _SplashTagline extends StatelessWidget {
  const _SplashTagline();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: '_splash_tagline',
      container: true,
      child: Text(
        l10n.splashTagline,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The Figma frame the widget is specified against (node `56572:1711`), and the
/// surface size `client_home_screen_test.dart` and friends pump at.
const Size _brandedSplashFigmaFrame = Size(440, 956);

/// The smallest phone the app is still expected to look right on — the width
/// `jeeber_feed_card_test.dart` uses for its compact case.
const Size _brandedSplashCompactFrame = Size(360, 640);

/// A modern notched phone (iPhone 15 Pro class) in portrait.
const Size _brandedSplashNotchedFrame = Size(393, 852);

/// The same device rotated. A cold launch in landscape is a real path on
/// Android tablets and on any phone with rotation unlocked.
const Size _brandedSplashLandscapeFrame = Size(852, 393);

/// A tablet in portrait (iPad Air class).
const Size _brandedSplashTabletFrame = Size(834, 1194);

/// Status-bar + home-indicator insets of a notched phone in portrait.
const EdgeInsets _brandedSplashNotchInsets = EdgeInsets.only(top: 59, bottom: 34);

/// Rotated: the notch moves to a side, the home indicator thins out.
const EdgeInsets _brandedSplashLandscapeInsets = EdgeInsets.only(
  left: 59,
  right: 59,
  bottom: 21,
);

// Each `@JeebPreview` below declares a canvas box of `frame + (12, 44)`: the

/// Simulates one window around [BrandedSplash].
/// The splash is full-bleed and sizes itself to whatever it is given, so a
/// preview that just returned `const BrandedSplash()` would render the host's
class _BrandedSplashDeviceFrame extends StatelessWidget {
  const _BrandedSplashDeviceFrame({
    required this.label,
    required this.frame,
    this.insets = EdgeInsets.zero,
  });

  final String label;
  final Size frame;
  final EdgeInsets insets;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: frame,
              padding: insets,
              viewPadding: insets,
              viewInsets: EdgeInsets.zero,
            ),
            child: SizedBox.fromSize(
              size: frame,
              child: const BrandedSplash(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Unbounds both axes so a simulated frame wider or taller than the host is
/// rendered at its real size instead of being clamped down to the host.
Widget _brandedSplashHosted({
  required String label,
  required Size frame,
  EdgeInsets insets = EdgeInsets.zero,
}) =>
    SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _BrandedSplashDeviceFrame(label: label, frame: frame, insets: insets),
      ),
    );

/// The reference reading: the exact Figma frame the widget is specified
/// against, with no system chrome claimed.
@JeebPreview(group: 'app', name: 'Figma frame 440 × 956', size: Size(452, 1000))
Widget brandedSplashFigmaFrame() => _brandedSplashHosted(
      label: 'Figma frame · 440 × 956 · no insets',
      frame: _brandedSplashFigmaFrame,
    );

/// The small end of the range: a 360 pt phone.
/// `Sizes.twoHundredLarge` is a fixed 200 pt, so the wordmark is now **55.6 %**
@JeebPreview(group: 'app', name: 'Compact 360 × 640', size: Size(372, 684))
Widget brandedSplashCompactPhone() => _brandedSplashHosted(
      label: 'Compact phone · 360 × 640 · no insets',
      frame: _brandedSplashCompactFrame,
    );

/// The state ~every iOS user actually sees: a notched phone with a 59 pt status
/// bar and a 34 pt home indicator.
@JeebPreview(group: 'app', name: 'Notched 393 × 852 · inset 59/34', size: Size(405, 896))
Widget brandedSplashNotchedPhone() => _brandedSplashHosted(
      label: 'Notched phone · 393 × 852 · inset 59/34',
      frame: _brandedSplashNotchedFrame,
      insets: _brandedSplashNotchInsets,
    );

/// The short viewport: the same device rotated, launched cold.
/// This is the state the vertical composition was never drawn for. `_SplashBody`
@JeebPreview(group: 'app', name: 'Landscape 852 × 393', size: Size(864, 438))
Widget brandedSplashLandscape() => _brandedSplashHosted(
      label: 'Landscape · 852 × 393 · inset 59/59/21',
      frame: _brandedSplashLandscapeFrame,
      insets: _brandedSplashLandscapeInsets,
    );

/// The large end of the range: a tablet in portrait.
/// The other half of the fixed-token problem. The wordmark is still 200 pt, so
@JeebPreview(group: 'app', name: 'Tablet 834 × 1194', size: Size(846, 1238))
Widget brandedSplashTablet() => _brandedSplashHosted(
      label: 'Tablet portrait · 834 × 1194 · no insets',
      frame: _brandedSplashTabletFrame,
    );
