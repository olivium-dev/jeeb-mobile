import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:omds/omds.dart';

import '../l10n/app_localizations.dart';

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
