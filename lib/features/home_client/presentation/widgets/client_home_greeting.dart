import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/friendly_reference.dart';
import '../../../../core/session/greeting_profile_cubit.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../core/widgets/jeeb/jeeb_profile_header.dart';
import '../../../../l10n/app_localizations.dart';

/// Customer home header (redesign-2026-08 screen 04, `04-client-home.html`
/// tpl 158-165): `[Ø46 avatar] [eyebrow / Hello, {name}]`.
///
/// This widget is the **adapter**, not the layout — the kit's
/// [JeebProfileHeader] owns every measurement. What lives here is the data
/// resolution the header cannot know about:
///
/// P0-X06: the greeting name + avatar are sourced from the signed-in user's
/// real profile via the ambient [GreetingProfileCubit] when one is provided
/// above this widget (the HomeTab shell wires it). The cubit's live `getMe`
/// name takes precedence over the cubit-fed [name]; the avatar renders the real
/// `avatarUrl` instead of a bare "?" placeholder. With NO ambient cubit (bare
/// widget tests) the widget falls back to the passed [name] and the initials
/// avatar — preserving the prior contract.
///
/// The create-request affordance is NOT here any more: the `+` icon button
/// became the mic hero (`ClientHomeRequestHero`), which now carries the frozen
/// `orders_create_request_button` identifier.
class ClientHomeGreeting extends StatelessWidget {
  const ClientHomeGreeting({
    super.key,
    required this.name,
    this.avatarSemanticsIdentifier,
  });

  /// Device-local hour at which the eyebrow flips morning → afternoon.
  static const int _afternoonHour = 12;

  /// Device-local hour at which the eyebrow flips afternoon → evening.
  static const int _eveningHour = 17;

  /// Vertical center of the Ø46 header avatar below SafeArea top — the line the
  /// shell's header actions center on.
  static const double avatarCenterFromSafeTop =
      Spacing.medium + JeebAvatar.headerDiameter / 2;

  final String? name;
  final String? avatarSemanticsIdentifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
    // Greet with the first name only ("Hello, Sami", not "Hello, Sami Fawaz").
    final firstName = _firstName(resolvedName);
    final greeting = (firstName == null || firstName.isEmpty)
        ? l10n.homeGreetingFallback
        : l10n.homeGreetingNamed(firstName);

    return Padding(
      // HTML tpl 158: `16px 24px 0`.
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.medium,
        Spacing.xLarge,
        0,
      ),
      child: JeebProfileHeader(
        name: greeting,
        eyebrow: _eyebrow(l10n),
        // TODO(redesign-24): the board draws an unread dot on this avatar.
        // There is no unread source on this surface (NotificationsListState
        // lives behind the notifications route) — omitted rather than faked;
        // the shell's bell is the notification affordance.
        avatar: JeebAvatar.header(
          // The board's own-user disc is grey + periwinkle, not a navy fill.
          fill: JeebAvatarFill.dormant,
          initial: firstName ?? '',
          imageUrl: avatarUrl,
          avatarKey: const Key('client-home-greeting-avatar'),
        ),
        avatarIdentifier: avatarSemanticsIdentifier,
        // The shell overlays its wallet chip + bell on top of this row
        // (`shell_screen.dart:301-325`), so the end gutter is reserved rather
        // than filled — otherwise a long name runs under them.
        trailingReserve: Spacing.fourXLarge * 2,
      ),
    );
  }

  /// Time-of-day eyebrow, derived from the DEVICE clock — it is a greeting, not
  /// server data, so there is nothing to fetch and nothing to be stale.
  String _eyebrow(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < _afternoonHour) return l10n.homeGreetingEyebrowMorning;
    if (hour < _eveningHour) return l10n.homeGreetingEyebrowAfternoon;
    return l10n.homeGreetingEyebrowEvening;
  }

  /// First whitespace-delimited token of [full], or `null` when blank.
  static String? _firstName(String? full) {
    final trimmed = full?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\s+')).first;
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
