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
  const JeeberHomeGreeting({super.key, this.name, this.avatarUrl});

  static const Key rootKey = Key('jeeber-home-greeting-root');

  /// Profile display name. `null` shows the generic "Welcome back" fallback.
  final String? name;

  /// Optional profile avatar (cdn-service URL) shown leading the greeting
  /// line, matching the Figma deliveryman home header (screens 23-26). When
  /// `null` the greeting renders without an avatar (existing call sites).
  final String? avatarUrl;

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
          _GreetingRow(name: name, avatarUrl: avatarUrl),
          const SizedBox(height: Sizes.threeXSmall),
          const _GreetingHeadline(),
        ],
      ),
    );
  }
}

class _GreetingRow extends StatelessWidget {
  const _GreetingRow({required this.name, required this.avatarUrl});

  final String? name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null) return _GreetingLine(name: name);
    return Row(
      children: [
        _GreetingAvatar(name: name, avatarUrl: avatarUrl),
        const SizedBox(width: Spacing.xSmall),
        Flexible(child: _GreetingLine(name: name)),
      ],
    );
  }
}

class _GreetingAvatar extends StatelessWidget {
  const _GreetingAvatar({required this.name, required this.avatarUrl});

  final String? name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trimmed = name?.trim() ?? '';
    return Semantics(
      identifier: 'jeeber_home_avatar',
      child: OmdsProfileAvatar(
        initial: trimmed.isEmpty ? '?' : trimmed[0].toUpperCase(),
        profilePicUrl: avatarUrl,
        size: Sizes.twoXLarge,
        backgroundColor: colorScheme.surfaceContainerHigh,
        initialColor: colorScheme.primary,
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
