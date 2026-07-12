import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Zero-orders hero empty state for the client home (Figma node 56535:1514).
///
/// Composition top-to-bottom:
/// 1. Greeting header — avatar + "Hello, {name}" + "Everything, One Place"
///    (no add button; the empty-state header is read-only).
/// 2. Hero illustration ("shop (1) 1", aspect 743/756) — decorative.
/// 3. "No orders yet" title + "Everything you order shows up here." body.
/// 4. Full-width navy "New Order" primary CTA, pinned above the bottom nav.
///
/// Rendered when the client has zero requests across every tab. The
/// illustration + title + body + CTA cluster is delegated to [OmdsEmptyState]
/// via its `illustration` slot so the empty-state contract stays in OMDS.
class ClientHomeEmptyView extends StatelessWidget {
  const ClientHomeEmptyView({
    super.key,
    required this.name,
    this.onNewOrder,
  });

  /// Client first name for the greeting; `null` falls back to "Welcome back".
  final String? name;

  /// Starts the new-order flow from the primary CTA.
  final VoidCallback? onNewOrder;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: '_request_empty_state_root',
      container: true,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.medium,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: _EmptyHomeColumn(name: name, onNewOrder: onNewOrder),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHomeColumn extends StatelessWidget {
  const _EmptyHomeColumn({required this.name, required this.onNewOrder});

  final String? name;
  final VoidCallback? onNewOrder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Spacing.medium),
        _EmptyHomeHeader(name: name),
        Expanded(child: _EmptyHomeHero(name: name)),
        _NewOrderButton(onPressed: onNewOrder),
        const SizedBox(height: Spacing.medium),
      ],
    );
  }
}

/// Read-only greeting header: avatar + "Hello, {name}" + tagline. Mirrors the
/// populated-home greeting minus the add button (not present in 56535:1514).
class _EmptyHomeHeader extends StatelessWidget {
  const _EmptyHomeHeader({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GreetingLine(name: name),
        const SizedBox(height: Sizes.threeXSmall),
        _GreetingTagline(),
      ],
    );
  }
}

class _GreetingLine extends StatelessWidget {
  const _GreetingLine({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasName = name != null && name!.trim().isNotEmpty;
    final greeting =
        hasName ? l10n.homeGreetingNamed(name!) : l10n.homeGreetingFallback;
    return Row(
      children: [
        _GreetingAvatar(name: name),
        const SizedBox(width: Spacing.xSmall),
        Flexible(child: _GreetingText(text: greeting)),
      ],
    );
  }
}

class _GreetingAvatar extends StatelessWidget {
  const _GreetingAvatar({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final seed =
        (name != null && name!.trim().isNotEmpty) ? name!.trim() : '?';
    return Semantics(
      identifier: '_request_empty_state_avatar',
      image: true,
      label: l10n.homeAvatarA11yLabel(seed),
      child: OmdsProfileAvatar(
        initial: seed,
        size: Sizes.large,
        backgroundColor: colorScheme.surfaceContainerHigh,
        initialColor: colorScheme.primary,
      ),
    );
  }
}

class _GreetingText extends StatelessWidget {
  const _GreetingText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleLarge?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w400,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _GreetingTagline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.homeGreetingSubtitle,
      style: theme.textTheme.titleLarge?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// Centered hero cluster: decorative illustration + "No orders yet" + body.
/// Delegates layout to [OmdsEmptyState]'s `illustration`/`title`/`subtitle`
/// slots so the empty-state contract is owned by OMDS, not hand-rolled.
class _EmptyHomeHero extends StatelessWidget {
  const _EmptyHomeHero({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: OmdsEmptyState(
        illustration: const _HeroIllustration(),
        spacing: Spacing.medium,
        title: l10n.homeEmptyOrdersTitle,
        subtitle: l10n.homeEmptyOrdersBody,
        titleStyle: _titleStyle(theme),
        subtitleStyle: _subtitleStyle(theme),
      ),
    );
  }

  TextStyle? _titleStyle(ThemeData theme) =>
      theme.textTheme.headlineSmall?.copyWith(
        color: theme.colorScheme.secondaryContainer,
        fontWeight: FontWeight.w800,
      );

  TextStyle? _subtitleStyle(ThemeData theme) =>
      theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );
}

/// Decorative raster hero. Excluded from semantics — the title + body carry
/// the meaning, so screen readers skip the image (spec §6).
class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: FractionallySizedBox(
        widthFactor: _kHeroWidthFactor,
        child: AspectRatio(
          aspectRatio: _kHeroAspect,
          child: Image.asset(
            'assets/illustrations/empty_orders.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _NewOrderButton extends StatelessWidget {
  const _NewOrderButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: '_request_empty_state_new_order_button',
      button: true,
      child: OmdsPrimaryButton(
        text: l10n.homeNewOrderCta,
        borderRadius: OmdsBorderRadius.uiSmall,
        onTap: () => onPressed?.call(),
      ),
    );
  }
}

/// Hero spans the content column at ~87% width (Figma 341/392), preserving the
/// 743/756 source aspect so it never stretches across device widths.
const double _kHeroWidthFactor = 0.87;
const double _kHeroAspect = 743 / 756;
