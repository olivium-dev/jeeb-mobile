import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import 'jeeber_home_greeting.dart';

/// State 1 of the Jeeber home (Figma node 56614:18920 — "Delivery screen,
/// User not registered as delivery man"): the user has not yet completed the
/// delivery-man registration.
///
/// Visual: shared greeting header → large scooter-out-of-phone hero illo →
/// "Register as a delivery man" headline → "Start earning money" subtitle →
/// "Register now" primary button pinned toward the bottom. The illustration is
/// rendered as a themed placeholder until the branded scooter asset ships
/// through `omds-flutter`.
///
/// `onRegister` is wired to the host's delivery-man onboarding route — the home
/// screen itself stays route-agnostic per the existing `onOpenFeedRequest`
/// pattern. Closes the JEEB-66 hardcoded-string debt: all copy is now keyed in
/// `app_en.arb` + `app_ar.arb`.
class JeeberUnregisteredView extends StatelessWidget {
  const JeeberUnregisteredView({
    super.key,
    required this.onRegister,
    this.profileName,
  });

  static const Key rootKey = Key('jeeber-unregistered-view-root');
  static const Key registerButtonKey =
      Key('jeeber-unregistered-view-register');

  /// Tapped when the Jeeber taps the primary "Register now" CTA.
  final VoidCallback onRegister;

  /// Optional profile display name passed through to the greeting.
  final String? profileName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: rootKey,
      container: true,
      // explicitChildNodes makes this identified container a NON-merging
      // boundary so the nested `jeeber_unregistered_register_button` (and any
      // other identified descendant) surfaces as its own queryable
      // SemanticsNode instead of being folded into the root. Without it,
      // `container: true` still merges the subtree's semantics into this node
      // and the CTA identifier is swallowed (CAP-3 / same pattern as 8b81dc1
      // fixed for screens 16/17/22/26/27).
      explicitChildNodes: true,
      identifier: 'jeeber_unregistered_root',
      child: SafeArea(
        child: Column(
          children: [
            JeeberHomeGreeting(name: profileName),
            const Expanded(child: _UnregisteredHero()),
            _UnregisteredCta(onRegister: onRegister),
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
        color: colorScheme.primaryContainer.withValues(
          alpha: UIConstants.opacityPrimaryLight,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.delivery_dining,
        size: Sizes.elevenXLarge,
        color: colorScheme.primaryContainer,
      ),
    );
  }
}

class _UnregisteredCta extends StatelessWidget {
  const _UnregisteredCta({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
      child: Semantics(
        identifier: 'jeeber_unregistered_register_button',
        button: true,
        child: OmdsPrimaryButton(
          key: JeeberUnregisteredView.registerButtonKey,
          text: l10n.jeeberRegisterCta,
          onTap: onRegister,
        ),
      ),
    );
  }
}
