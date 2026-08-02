import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/friendly_reference.dart';
import '../../../../core/session/greeting_profile_cubit.dart';
import '../../../../l10n/app_localizations.dart';

class JeeberHomeGreeting extends StatelessWidget {
  const JeeberHomeGreeting({super.key, this.name, this.avatarUrl});

  static const Key rootKey = Key('jeeber-home-greeting-root');

  final String? name;

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final profile = _readGreetingProfile(context);
    final rawName = (profile?.name?.trim().isNotEmpty ?? false)
        ? profile!.name
        : name;
    final resolvedName = displayNameOrNull(rawName);
    final resolvedAvatar = (profile?.avatarUrl?.trim().isNotEmpty ?? false)
        ? profile!.avatarUrl
        : avatarUrl;
    return Padding(
      key: rootKey,
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        Spacing.medium,
        Spacing.medium,
        Spacing.twoXSmall,
      ),
      child: _GreetingRow(name: resolvedName, avatarUrl: resolvedAvatar),
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
    final firstName = trimmed.split(RegExp(r'\s+')).first;
    return l10n.homeGreetingNamed(firstName);
  }
}
