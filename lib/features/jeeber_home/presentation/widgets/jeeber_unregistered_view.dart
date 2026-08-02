import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import 'jeeber_home_greeting.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// ===========================================================================

/// The slot the DELIVERY tab hands this view on a modern phone: full body
/// height once the status bar and the bottom nav are gone.
const Size _jeeberUnregisteredViewPhoneBody = Size(390, 680);

/// The narrowest device the app still supports, same generous height.
const Size _jeeberUnregisteredViewCompactPhone = Size(320, 600);

/// A short body — a small phone in a locale with a tall system font, or any
/// host that keeps chrome above and below. This is the box the view does not
const Size _jeeberUnregisteredViewShortBody = Size(390, 420);

/// One state: the view with a name, optionally the JM-036 gate identifier, and
Widget _jeeberUnregisteredViewHosted({
  String? profileName,
  String? ctaIdentifier,
  double? width,
}) {
  final Widget view = JeeberUnregisteredView(
    onRegister: () {},
    profileName: profileName,
    ctaIdentifier: ctaIdentifier,
  );
  if (width == null) return view;
  // `height: double.infinity` against the loose constraints [Center] passes
  return Center(
    child: SizedBox(width: width, height: double.infinity, child: view),
  );
}

/// Cold start, and the most common first frame of this screen.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Cold start · no name',
  size: _jeeberUnregisteredViewPhoneBody,
)
Widget jeeberUnregisteredViewColdStart() => _jeeberUnregisteredViewHosted();

/// The settled happy path: a named user who has not registered yet.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Named jeeber',
  size: _jeeberUnregisteredViewPhoneBody,
)
Widget jeeberUnregisteredViewNamed() =>
    _jeeberUnregisteredViewHosted(profileName: 'Kamal');

/// How `dashboard_tab.dart` really builds it: the CTA additionally wrapped in
@JeebPreview(
  group: 'jeeber_home',
  name: 'JM-036 gate CTA id',
  size: _jeeberUnregisteredViewPhoneBody,
)
Widget jeeberUnregisteredViewGateCta() => _jeeberUnregisteredViewHosted(
      profileName: 'Zeina',
      ctaIdentifier: 'delivery_register_now_cta',
    );

/// Longest plausible content on the narrowest supported device: a three-part
@JeebPreview(
  group: 'jeeber_home',
  name: 'Long name · 320pt phone',
  size: _jeeberUnregisteredViewCompactPhone,
)
Widget jeeberUnregisteredViewLongNameCompact() => _jeeberUnregisteredViewHosted(
      profileName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
      width: 320,
    );

/// **The state that breaks**: the same view in a 420pt-tall body.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Short body (420pt)',
  size: _jeeberUnregisteredViewShortBody,
)
Widget jeeberUnregisteredViewShortBody() =>
    _jeeberUnregisteredViewHosted(profileName: 'Nour');
