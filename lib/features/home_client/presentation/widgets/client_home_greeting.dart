import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Greeting header matching the Figma design (node 56611:18771).
///
/// Layout: "Hello, **{name}**" with a small [OmdsProfileAvatar] prefix,
/// then "**Everything, One Place**" in extrabold with a filled circular
/// "+" icon button (themed via [OmdsButtonStyles.iconButtonFilled]).
class ClientHomeGreeting extends StatelessWidget {
  const ClientHomeGreeting({super.key, required this.name, this.onAddPressed});

  final String? name;
  final VoidCallback? onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.medium,
        Spacing.medium,
        Spacing.medium,
        Spacing.xSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GreetingLine(name: name),
          const SizedBox(height: Sizes.threeXSmall),
          _GreetingHeadline(onAddPressed: onAddPressed),
        ],
      ),
    );
  }
}

class _GreetingLine extends StatelessWidget {
  const _GreetingLine({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final greeting = (name == null || name!.isEmpty)
        ? l10n.homeGreetingFallback
        : l10n.homeGreetingNamed(name!);
    return Row(
      children: [
        _GreetingAvatar(initial: name),
        const SizedBox(width: Spacing.xSmall),
        Flexible(child: _GreetingText(text: greeting)),
      ],
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

class _GreetingAvatar extends StatelessWidget {
  const _GreetingAvatar({required this.initial});

  final String? initial;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final seed = (initial != null && initial!.trim().isNotEmpty)
        ? initial!.trim()
        : '?';
    return OmdsProfileAvatar(
      key: const Key('client-home-greeting-avatar'),
      initial: seed,
      size: Sizes.large,
      backgroundColor: colorScheme.surfaceContainerHigh,
      initialColor: colorScheme.primary,
    );
  }
}

class _GreetingHeadline extends StatelessWidget {
  const _GreetingHeadline({required this.onAddPressed});

  final VoidCallback? onAddPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.homeGreetingSubtitle,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _AddRequestButton(onPressed: onAddPressed),
      ],
    );
  }
}

class _AddRequestButton extends StatelessWidget {
  const _AddRequestButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'orders_create_request_button',
      button: true,
      label: l10n.homeEmptyCta,
      child: IconButton.filled(
        key: const Key('client-home-greeting-add'),
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: Sizes.xLarge),
        style: OmdsButtonStyles.iconButtonFilled(colorScheme),
      ),
    );
  }
}
