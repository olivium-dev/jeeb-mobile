import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import 'jeeber_home_greeting.dart';

class JeeberUnregisteredView extends StatelessWidget {
  const JeeberUnregisteredView({
    super.key,
    required this.onRegister,
    this.profileName,
    this.ctaIdentifier,
  });

  static const Key rootKey = Key('jeeber-unregistered-view-root');
  static const Key registerButtonKey =
      Key('jeeber-unregistered-view-register');

  final VoidCallback onRegister;

  final String? profileName;

  final String? ctaIdentifier;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: rootKey,
      container: true,
      explicitChildNodes: true,
      identifier: 'jeeber_unregistered_root',
      child: SafeArea(
        child: Column(
          children: [
            JeeberHomeGreeting(name: profileName),
            const Expanded(child: _UnregisteredHero()),
            _UnregisteredCta(
              onRegister: onRegister,
              extraIdentifier: ctaIdentifier,
            ),
            const SizedBox(height: Spacing.large),
          ],
        ),
      ),
    );
  }
}

class _UnregisteredHero extends StatelessWidget {
  const _UnregisteredHero();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsEmptyState(
      illustration: const _UnregisteredIllustration(),
      title: l10n.jeeberRegisterTitle,
      subtitle: l10n.jeeberRegisterSubtitle,
    );
  }
}

class _UnregisteredIllustration extends StatelessWidget {
  const _UnregisteredIllustration();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.jeeberRegisterHeroSemantic,
      image: true,
      child: const _UnregisteredIllustrationArt(),
    );
  }
}

class _UnregisteredIllustrationArt extends StatelessWidget {
  const _UnregisteredIllustrationArt();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: Sizes.twoHundredLarge,
      height: Sizes.twoHundredLarge,
      decoration: BoxDecoration(
        color: colorScheme.tertiary.withValues(
          alpha: UIConstants.opacityPrimaryLight,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.delivery_dining,
        size: Sizes.elevenXLarge,
        color: colorScheme.tertiary,
      ),
    );
  }
}

class _UnregisteredCta extends StatelessWidget {
  const _UnregisteredCta({required this.onRegister, this.extraIdentifier});

  final VoidCallback onRegister;

  final String? extraIdentifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget cta = Semantics(
      identifier: 'jeeber_unregistered_register_button',
      button: true,
      child: OmdsPrimaryButton(
        key: JeeberUnregisteredView.registerButtonKey,
        text: l10n.jeeberRegisterCta,
        onTap: onRegister,
      ),
    );
    final extraId = extraIdentifier;
    if (extraId != null) {
      cta = Semantics(
        identifier: extraId,
        button: true,
        explicitChildNodes: true,
        child: cta,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
      child: cta,
    );
  }
}
