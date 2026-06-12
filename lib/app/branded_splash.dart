import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:omds/omds.dart';

import '../l10n/app_localizations.dart';

/// Jeeb branded splash — Figma node `56572:1711` ("Splash", 440×956).
///
/// Full-bleed brand-navy background with the Jeeb wordmark optically centered
/// and the localized tagline in the lower band. The wordmark is the bundled
/// brand vector (`assets/brand/jeeb_logo.svg`, Figma "Group 68" 56572:1821),
/// never re-drawn as `Text` glyphs.
///
/// Renders under the OMDS theme + [AppLocalizations] supplied by the splash
/// host, so every color is a `colorScheme` role and every string is an ARB
/// key — no literals. Direction-agnostic layout mirrors automatically in RTL.
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

/// Vertical composition: wordmark optically centered (slightly above true
/// centre via asymmetric [Spacer] weights), tagline anchored to the lower band.
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

/// Bundled Jeeb wordmark, clamped to a brand-sized max width and centred. The
/// SVG keeps its intrinsic aspect ratio (viewBox 182:73), so it scales down on
/// narrow devices without distortion. Marked as meaningful image artwork.
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
        // Token width; height derives from the SVG's intrinsic 182:73 ratio,
        // so the wordmark scales without distortion. ~45% of a 440dp frame —
        // the brand-sized analogue of Figma's 182px (≈41%) wordmark.
        child: SvgPicture.asset(
          BrandedSplash._logoAsset,
          width: Sizes.twoHundredLarge,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// Localized "Delivery App" tagline. Uses the theme `titleMedium` role on the
/// on-secondary (white) color so contrast holds against the navy fill.
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
