import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/friendly_reference.dart';
import '../../../../core/session/greeting_profile_cubit.dart';
import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/home_client/client_home_greeting_preview_test.dart
// ===========================================================================
//
// Every state below is driven the way the production shell drives it: an
// ambient [GreetingProfileCubit] seeded with a fixed [GreetingProfileState].
// A cubit built with no repository is inert — `load()` returns immediately and
// nothing subscribes — so these previews are network-free by construction, not
// just by the guard in [jeebPreviewHost].
//
// The states mirror the contract asserted in
// `test/client_home_greeting_test.dart`; the previews exist so the *visual*
// half of that contract (overflow, RTL mirroring, large text) is reviewable
// without booting the app and signing in.

/// The canvas box for a home header: phone width, header height.
const Size _clientHomeGreetingHeaderBox = Size(390, 120);

Widget _clientHomeGreetingHosted(
  GreetingProfileState? profile, {
  String? name,
}) {
  final Widget greeting = ClientHomeGreeting(
    name: name,
    onAddPressed: () {},
  );
  if (profile == null) return greeting;
  return BlocProvider<GreetingProfileCubit>(
    create: (_) => GreetingProfileCubit(seed: profile),
    child: greeting,
  );
}

/// The happy path: a live profile with a name and an avatar on file.
///
/// Greets the FIRST name only ("Hello, Sami", never "Hello, Sami Fawaz").
@JeebPreview(
  group: 'home_client',
  name: 'Named + avatar',
  size: _clientHomeGreetingHeaderBox,
)
Widget clientHomeGreetingNamed() => _clientHomeGreetingHosted(
      const GreetingProfileState(
        name: 'Sami Fawaz',
        avatarUrl: 'https://cdn.jeeb.app/avatars/sami.png',
      ),
    );

/// Cold start: `GET /users/me` has not resolved yet, so there is no name and no
/// avatar. Degrades to the localized generic greeting + the "?" avatar — this
/// is the state most users see for the first few hundred milliseconds.
@JeebPreview(
  group: 'home_client',
  name: 'Generic fallback',
  size: _clientHomeGreetingHeaderBox,
)
Widget clientHomeGreetingFallback() => _clientHomeGreetingHosted(null);

/// A name on file but no avatar — the initials avatar, not "?".
///
/// The distinction matters: "?" is reserved for "we know nothing about you",
/// and showing it to a named user reads as a broken profile.
@JeebPreview(
  group: 'home_client',
  name: 'Name, no avatar',
  size: _clientHomeGreetingHeaderBox,
)
Widget clientHomeGreetingInitialsOnly() =>
    _clientHomeGreetingHosted(const GreetingProfileState(name: 'Layla'));

/// Audit §T5 regression guard, made visible.
///
/// Phone-only accounts carry a synthetic handle (`jeeb-<hash>`) or an internal
/// address (`…@jeeb.internal`) as their only "name". The header must NEVER
/// greet those — it falls back to the generic greeting. If this preview ever
/// renders "Hello, jeeb-…", the suppression in `displayNameOrNull` has broken.
@JeebPreview(
  group: 'home_client',
  name: 'Synthetic handle suppressed',
  size: _clientHomeGreetingHeaderBox,
)
Widget clientHomeGreetingSyntheticHandle() => _clientHomeGreetingHosted(
      const GreetingProfileState(name: 'jeeb-e1a35ea8a520'),
    );

/// Layout ceiling: a long name must ellipsize and must not push the "+" button
/// off the trailing edge.
///
/// This is the state the AR RTL and 200%-text renderings of the matrix are
/// really for — the English light rendering looks fine long after the other two
/// have broken.
@JeebPreview(
  group: 'home_client',
  name: 'Long name overflow',
  size: _clientHomeGreetingHeaderBox,
)
Widget clientHomeGreetingLongName() => _clientHomeGreetingHosted(
      const GreetingProfileState(name: 'Abdulrahman Al-Muhandis Al-Trabulsi'),
    );
