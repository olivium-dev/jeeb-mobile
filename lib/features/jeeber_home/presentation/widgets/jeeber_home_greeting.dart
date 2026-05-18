import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Greeting header shown at the top of every Jeeber home state.
///
/// Mirrors the client-side `ClientHomeGreeting` so both roles share the
/// "Hello, {name}" + "Everything, One Place" branding (Figma node
/// 56535:1525). The header is intentionally identical across the three
/// Jeeber-home states (unregistered / available-no-requests /
/// available-with-requests) — only the body below it changes.
class JeeberHomeGreeting extends StatelessWidget {
  const JeeberHomeGreeting({super.key, this.name});

  static const Key rootKey = Key('jeeber-home-greeting-root');

  /// Profile display name. `null` shows the generic "Welcome back" fallback.
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: rootKey,
      padding: const EdgeInsetsDirectional.fromSTEB(
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
          const _GreetingHeadline(),
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
    final theme = Theme.of(context);
    final greeting = _resolveGreeting(context);
    return Text(
      greeting,
      style: theme.textTheme.titleLarge?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w400,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _resolveGreeting(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return l10n.homeGreetingFallback;
    return l10n.homeGreetingNamed(trimmed);
  }
}

class _GreetingHeadline extends StatelessWidget {
  const _GreetingHeadline();

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
