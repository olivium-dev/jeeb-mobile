import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Greeting line at the top of the client home tab. Pure presentation; the
/// cubit decides whether to pass a name or `null`.
class ClientHomeGreeting extends StatelessWidget {
  const ClientHomeGreeting({
    super.key,
    required this.name,
  });

  /// First name to address the user with. `null` falls back to the generic
  /// "Welcome back" copy so the line still reads well for accounts that
  /// haven't completed the profile step.
  final String? name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final greeting = (name == null || name!.isEmpty)
        ? l10n.homeGreetingFallback
        : l10n.homeGreetingNamed(name!);
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
          Text(
            greeting,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Spacing.twoXSmall),
          Text(
            l10n.homeGreetingSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
