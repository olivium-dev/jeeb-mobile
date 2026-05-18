import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import 'jeeber_home_greeting.dart';

/// State 1 of the Jeeber home (per the JEEB-66 design): the user has not
/// yet completed the delivery-man registration.
///
/// Visual: shared greeting header → large scooter-out-of-phone hero illo →
/// "Register as a delivery man" headline → "Start earning money" subtitle →
/// "Register now" primary button. The illustration is rendered as an
/// `Icon` placeholder against `colorScheme.primaryContainer` until the
/// branded scooter asset ships through `omds-flutter`.
///
/// `onRegister` is wired to the host's KYC route — the home screen itself
/// stays route-agnostic per the existing `onOpenFeedRequest` pattern.
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

  // String constants pending l10n. The host-side ARB will receive matching
  // keys (`jeeberRegisterTitle`, `jeeberRegisterSubtitle`,
  // `jeeberRegisterCta`) in the JEEB-66 follow-up; until then the Jeeber
  // home falls back to these English strings so the screen renders cleanly.
  // TODO(jeeb-l10n): replace with AppLocalizations getters once ARB lands.
  static const _kRegisterTitle = 'Register as a delivery man';
  static const _kRegisterSubtitle = 'Start earning money';
  static const _kRegisterCta = 'Register now';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: rootKey,
      container: true,
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
    return OmdsEmptyState(
      illustration: const _UnregisteredIllustration(),
      title: JeeberUnregisteredView._kRegisterTitle,
      subtitle: JeeberUnregisteredView._kRegisterSubtitle,
    );
  }
}

class _UnregisteredIllustration extends StatelessWidget {
  const _UnregisteredIllustration();

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
      child: OmdsPrimaryButton(
        key: JeeberUnregisteredView.registerButtonKey,
        text: JeeberUnregisteredView._kRegisterCta,
        onTap: onRegister,
      ),
    );
  }
}
