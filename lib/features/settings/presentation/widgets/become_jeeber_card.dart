import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class BecomeJeeberCard extends StatelessWidget {
  const BecomeJeeberCard({
    super.key,
    required this.onTap,
    this.isAlreadyJeeber = false,
  });

  static const Key rootKey = Key('become-jeeber-card-root');
  static const Key ctaKey = Key('become-jeeber-card-cta');

  final bool isAlreadyJeeber;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isAlreadyJeeber) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: rootKey,
      identifier: 'become_jeeber_card_cta',
      label: l10n.becomeJeeberCardSemantic,
      button: true,
      container: true,
      child: ExcludeSemantics(
        child: _BecomeJeeberCardBody(l10n: l10n, onTap: onTap),
      ),
    );
  }
}

class _BecomeJeeberCardBody extends StatelessWidget {
  const _BecomeJeeberCardBody({
    required this.l10n,
    required this.onTap,
  });

  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      child: _CardSurface(
        colorScheme: colorScheme,
        onTap: onTap,
        child: _CardContent(
          l10n: l10n,
          onTap: onTap,
          colorScheme: colorScheme,
        ),
      ),
    );
  }
}

class _CardSurface extends StatelessWidget {
  const _CardSurface({
    required this.colorScheme,
    required this.onTap,
    required this.child,
  });

  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: OmdsBorderRadius.large,
      child: InkWell(
        onTap: onTap,
        borderRadius: OmdsBorderRadius.large,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.medium),
          child: child,
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.l10n,
    required this.onTap,
    required this.colorScheme,
  });

  final AppLocalizations l10n;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CardIcon(colorScheme: colorScheme),
        const SizedBox(width: Spacing.medium),
        Expanded(child: _CardText(l10n: l10n)),
        OmdsPrimaryButton(
          key: BecomeJeeberCard.ctaKey,
          text: l10n.becomeJeeberCardCta,
          onTap: onTap,
        ),
      ],
    );
  }
}

class _CardIcon extends StatelessWidget {
  const _CardIcon({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: Sizes.threeXLarge / 2,
      backgroundColor: colorScheme.primaryContainer,
      child: Icon(
        Icons.delivery_dining,
        color: colorScheme.onPrimaryContainer,
        size: Sizes.twoXLarge,
      ),
    );
  }
}

class _CardText extends StatelessWidget {
  const _CardText({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.becomeJeeberCardTitle,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: Spacing.twoXSmall),
        Text(
          l10n.becomeJeeberCardSubtitle,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// A typical phone — the width the card is designed against.
const double _becomeJeeberCardPhoneWidth = 390;

/// The narrowest width the app still has to survive (iPhone SE 1st gen and the
/// small Android estate). This is the card's squeeze point.
const double _becomeJeeberCardNarrowPhoneWidth = 320;

/// Tablet / landscape: the only width at which the card's single [Row] has room
/// for the layout its design implies.
const double _becomeJeeberCardWideWidth = 700;

/// 390 pt wide, tall enough for the measured 204 pt card plus breathing room.
const Size _becomeJeeberCardPhoneBox = Size(_becomeJeeberCardPhoneWidth, 240);

/// 320 pt wide. Deliberately 440 pt tall: the card really is 412 pt here, and a
/// box that hid that would hide the bug.
const Size _becomeJeeberCardNarrowBox = Size(
  _becomeJeeberCardNarrowPhoneWidth,
  440,
);

/// 700 pt wide, and only 140 pt tall — because at this width the card finally
/// collapses to 96 pt.
const Size _becomeJeeberCardWideBox = Size(_becomeJeeberCardWideWidth, 140);

/// Phone width, sized for two neighbour rows and no card.
const Size _becomeJeeberCardHiddenBox = Size(_becomeJeeberCardPhoneWidth, 180);

/// Pins the width the card is laid out against, so the canvas and the render
/// tests see the same line breaks. Top-aligned so the card keeps its natural
/// height instead of being centred in whatever box it is given.
class _BecomeJeeberCardViewport extends StatelessWidget {
  const _BecomeJeeberCardViewport({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(width: width, child: child),
    );
  }
}

/// Preview-only stand-in for the settings rows that sit under the card in
/// `ProfileTab`.
/// It exists for one state — [becomeJeeberCardAlreadyJeeber] — where the card
class _BecomeJeeberCardNeighbourRow extends StatelessWidget {
  const _BecomeJeeberCardNeighbourRow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

Widget _becomeJeeberCardHosted({
  required double width,
  bool isAlreadyJeeber = false,
}) {
  return _BecomeJeeberCardViewport(
    width: width,
    child: BecomeJeeberCard(
      isAlreadyJeeber: isAlreadyJeeber,
      onTap: () {},
    ),
  );
}

/// The shipping state: a client on a normal phone.
/// This is the default reading, and it is already wrong. The text column is
@JeebPreview(
  group: 'settings',
  name: 'Client · 390',
  size: _becomeJeeberCardPhoneBox,
)
Widget becomeJeeberCardPhone() =>
    _becomeJeeberCardHosted(width: _becomeJeeberCardPhoneWidth);

/// The squeeze point: the same card at 320 pt.
/// 70 pt narrower than [becomeJeeberCardPhone], and every one of those pixels
@JeebPreview(
  group: 'settings',
  name: 'Narrow 320',
  size: _becomeJeeberCardNarrowBox,
)
Widget becomeJeeberCardNarrowPhone() =>
    _becomeJeeberCardHosted(width: _becomeJeeberCardNarrowPhoneWidth);

/// The control: the same widget, same copy, at tablet width.
/// Title on one line, card 96 pt tall — the design as drawn. Keeping this state
@JeebPreview(
  group: 'settings',
  name: 'Wide 700',
  size: _becomeJeeberCardWideBox,
)
Widget becomeJeeberCardWide() =>
    _becomeJeeberCardHosted(width: _becomeJeeberCardWideWidth);

/// T-MOB-027 AC2, made visible: once the user's `available_roles` already
/// include Jeeber, the card must disappear ENTIRELY — not grey out, not say
@JeebPreview(
  group: 'settings',
  name: 'Already a Jeeber · hidden',
  size: _becomeJeeberCardHiddenBox,
)
Widget becomeJeeberCardAlreadyJeeber() => _BecomeJeeberCardViewport(
      width: _becomeJeeberCardPhoneWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _BecomeJeeberCardNeighbourRow('Settings row above the card'),
          BecomeJeeberCard(isAlreadyJeeber: true, onTap: () {}),
          const _BecomeJeeberCardNeighbourRow('Settings row below the card'),
        ],
      ),
    );
