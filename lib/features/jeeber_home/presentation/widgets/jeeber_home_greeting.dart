import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/friendly_reference.dart';
import '../../../../core/session/greeting_profile_cubit.dart';
import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for the dashboard title: phone width, header height with
/// enough slack that the 200%-text rendering is not clipped by the box itself.
const Size _jeeberHomeGreetingHeaderBox = Size(390, 110);

Widget _jeeberHomeGreetingHosted({
  String? name,
  String? avatarUrl,
  GreetingProfileState? profile,
}) {
  final Widget greeting = JeeberHomeGreeting(name: name, avatarUrl: avatarUrl);
  if (profile == null) return greeting;
  return BlocProvider<GreetingProfileCubit>(
    create: (_) => GreetingProfileCubit(seed: profile),
    child: greeting,
  );
}

/// The happy path the DashboardTab produces once getMe resolves: a live profile
/// with a name and an avatar on file.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Named + avatar',
  size: _jeeberHomeGreetingHeaderBox,
)
Widget jeeberHomeGreetingNamedWithAvatar() => _jeeberHomeGreetingHosted(
      profile: const GreetingProfileState(
        name: 'Sami Fawaz',
        avatarUrl: 'https://cdn.jeeb.app/avatars/sami.png',
      ),
    );

/// Cold start: no ambient cubit has emitted and nothing is threaded, so the
/// header degrades to the localized generic greeting — with NO avatar at all.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Generic fallback',
  size: _jeeberHomeGreetingHeaderBox,
)
Widget jeeberHomeGreetingFallback() => _jeeberHomeGreetingHosted();

/// The unregistered upsell path (`JeeberUnregisteredView` /
/// `JeeberNoRequestsView`): a name threaded down, no avatar ever.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Threaded name, no avatar',
  size: _jeeberHomeGreetingHeaderBox,
)
Widget jeeberHomeGreetingThreadedNameOnly() =>
    _jeeberHomeGreetingHosted(name: 'Kamal');

/// P0-X06 precedence, made visible: the ambient profile must WIN over a stale
/// threaded name.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Ambient profile wins',
  size: _jeeberHomeGreetingHeaderBox,
)
Widget jeeberHomeGreetingAmbientWins() => _jeeberHomeGreetingHosted(
      name: 'Kamal',
      profile: const GreetingProfileState(name: 'Layla'),
    );

/// Audit §T5 regression guard, made visible — plus the fallback-chain gap it
/// sits on.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Synthetic handle suppressed',
  size: _jeeberHomeGreetingHeaderBox,
)
Widget jeeberHomeGreetingSyntheticHandle() => _jeeberHomeGreetingHosted(
      name: 'Rami',
      profile: const GreetingProfileState(
        name: 'jeeb-e1a35ea8a520',
        avatarUrl: 'https://cdn.jeeb.app/avatars/anon.png',
      ),
    );

/// Layout ceiling: a long name must ellipsize on one line and must not push the
/// avatar out of the header.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Long name ellipsis',
  size: _jeeberHomeGreetingHeaderBox,
)
Widget jeeberHomeGreetingLongName() => _jeeberHomeGreetingHosted(
      profile: const GreetingProfileState(
        name: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        avatarUrl: 'https://cdn.jeeb.app/avatars/abdulrahman.png',
      ),
    );
