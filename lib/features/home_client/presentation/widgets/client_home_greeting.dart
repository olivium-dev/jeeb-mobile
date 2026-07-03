import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/friendly_reference.dart';
import '../../../../core/session/greeting_profile_cubit.dart';
import '../../../../l10n/app_localizations.dart';

/// Greeting header matching the Figma design (node 56611:18771).
///
/// Layout: "Hello, **{name}**" with a small [OmdsProfileAvatar] prefix,
/// then "**Everything, One Place**" in extrabold with a filled circular
/// "+" icon button (themed via [OmdsButtonStyles.iconButtonFilled]).
///
/// P0-X06: the greeting name + avatar are sourced from the signed-in user's
/// real profile via the ambient [GreetingProfileCubit] when one is provided
/// above this widget (the HomeTab shell wires it). The cubit's live `getMe`
/// name takes precedence over the cubit-fed [name]; the avatar renders the real
/// `avatarUrl` instead of a bare "?" placeholder. With NO ambient cubit (bare
/// widget tests) the widget falls back to the passed [name] and the initials
/// avatar — preserving the prior contract.
class ClientHomeGreeting extends StatelessWidget {
  const ClientHomeGreeting({super.key, required this.name, this.onAddPressed});

  final String? name;
  final VoidCallback? onAddPressed;

  @override
  Widget build(BuildContext context) {
    // Read the ambient personalized-greeting profile if the shell provided one.
    // A bare widget test without the provider falls back to the passed name and
    // a null avatar (no "?" when a name is known).
    final profile = _readGreetingProfile(context);
    final rawName = (profile?.name?.trim().isNotEmpty ?? false)
        ? profile!.name
        : name;
    // Suppress synthetic account handles (`jeeb-<hash>`) / internal emails so
    // the header never greets "Hello, jeeb-e1a35ea8a520" (audit §T5). When the
    // only name on file is an internal identifier we fall back to the generic
    // greeting + initials avatar via a null name.
    final resolvedName = displayNameOrNull(rawName);
    final avatarUrl = profile?.avatarUrl;
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
          _GreetingLine(name: resolvedName, avatarUrl: avatarUrl),
          const SizedBox(height: Sizes.threeXSmall),
          _GreetingHeadline(onAddPressed: onAddPressed),
        ],
      ),
    );
  }

  /// Reads the ambient [GreetingProfileCubit] state, or `null` when no provider
  /// is mounted above this widget (e.g. a bare widget test).
  static GreetingProfileState? _readGreetingProfile(BuildContext context) {
    try {
      return context.watch<GreetingProfileCubit>().state;
    } on Object {
      return null;
    }
  }
}

class _GreetingLine extends StatelessWidget {
  const _GreetingLine({required this.name, this.avatarUrl});

  final String? name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Greet with the first name only ("Hello, Sami", not "Hello, Sami Fawaz").
    final firstName = _firstName(name);
    final greeting = (firstName == null || firstName.isEmpty)
        ? l10n.homeGreetingFallback
        : l10n.homeGreetingNamed(firstName);
    return Row(
      children: [
        _GreetingAvatar(initial: firstName, avatarUrl: avatarUrl),
        const SizedBox(width: Spacing.xSmall),
        Flexible(child: _GreetingText(text: greeting)),
      ],
    );
  }

  /// First whitespace-delimited token of [full], or `null` when blank.
  static String? _firstName(String? full) {
    final trimmed = full?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\s+')).first;
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
  const _GreetingAvatar({required this.initial, this.avatarUrl});

  final String? initial;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trimmed = initial?.trim();
    // First initial of the name when known; '?' only as a last resort when the
    // user has neither a name nor an avatar on file.
    final seed = (trimmed != null && trimmed.isNotEmpty)
        ? trimmed[0].toUpperCase()
        : '?';
    final url = avatarUrl?.trim();
    return OmdsProfileAvatar(
      key: const Key('client-home-greeting-avatar'),
      initial: seed,
      profilePicUrl: (url == null || url.isEmpty) ? null : url,
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
