import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/friendly_reference.dart';
import '../../../../core/session/greeting_profile_cubit.dart';
import '../../../../l10n/app_localizations.dart';

class ClientHomeGreeting extends StatelessWidget {
  const ClientHomeGreeting({
    super.key,
    required this.name,
    this.onAddPressed,
    this.avatarSemanticsIdentifier,
  });

  final String? name;
  final VoidCallback? onAddPressed;
  final String? avatarSemanticsIdentifier;

  @override
  Widget build(BuildContext context) {
    final profile = _readGreetingProfile(context);
    final rawName = (profile?.name?.trim().isNotEmpty ?? false)
        ? profile!.name
        : name;
    final resolvedName = displayNameOrNull(rawName);
    final avatarUrl = profile?.avatarUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.medium,
        Spacing.medium,
        Spacing.medium,
        Spacing.xSmall,
      ),
      child: Row(
        children: [
          Expanded(
            child: _GreetingLine(
              name: resolvedName,
              avatarUrl: avatarUrl,
              avatarSemanticsIdentifier: avatarSemanticsIdentifier,
            ),
          ),
          const SizedBox(width: Spacing.small),
          _AddRequestButton(onPressed: onAddPressed),
        ],
      ),
    );
  }

  static GreetingProfileState? _readGreetingProfile(BuildContext context) {
    try {
      return context.watch<GreetingProfileCubit>().state;
    } on Object {
      return null;
    }
  }
}

class _GreetingLine extends StatelessWidget {
  const _GreetingLine({
    required this.name,
    required this.avatarSemanticsIdentifier,
    this.avatarUrl,
  });

  final String? name;
  final String? avatarUrl;
  final String? avatarSemanticsIdentifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final firstName = _firstName(name);
    final greeting = (firstName == null || firstName.isEmpty)
        ? l10n.homeGreetingFallback
        : l10n.homeGreetingNamed(firstName);
    return Row(
      children: [
        _GreetingAvatar(
          initial: firstName,
          avatarUrl: avatarUrl,
          semanticsIdentifier: avatarSemanticsIdentifier,
        ),
        const SizedBox(width: Spacing.xSmall),
        Flexible(child: _GreetingText(text: greeting)),
      ],
    );
  }

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
  const _GreetingAvatar({
    required this.initial,
    required this.semanticsIdentifier,
    this.avatarUrl,
  });

  final String? initial;
  final String? avatarUrl;
  final String? semanticsIdentifier;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trimmed = initial?.trim();
    final seed = (trimmed != null && trimmed.isNotEmpty)
        ? trimmed[0].toUpperCase()
        : '?';
    final url = avatarUrl?.trim();
    final avatar = OmdsProfileAvatar(
      key: const Key('client-home-greeting-avatar'),
      initial: seed,
      profilePicUrl: (url == null || url.isEmpty) ? null : url,
      size: Sizes.large,
      backgroundColor: colorScheme.surfaceContainerHigh,
      initialColor: colorScheme.primary,
    );
    final identifier = semanticsIdentifier;
    if (identifier == null) return avatar;
    return Semantics(identifier: identifier, image: true, child: avatar);
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
      container: true,
      explicitChildNodes: true,
      button: true,
      label: l10n.homeEmptyCta,
      child: IconButton(
        key: const Key('client-home-greeting-add'),
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: Sizes.xLarge),
        style: OmdsButtonStyles.iconButtonFilled(colorScheme),
      ),
    );
  }
}
