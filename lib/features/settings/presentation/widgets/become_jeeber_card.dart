import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

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
