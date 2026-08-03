import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/friendly_reference.dart';
import '../../../../core/session/greeting_profile_cubit.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../core/widgets/jeeb/jeeb_profile_header.dart';
import '../../../../l10n/app_localizations.dart';

/// The Jeeber dashboard's header band (redesign-2026-08 §5 #23).
///
/// `[Ø46 avatar] [eyebrow "Jeeber dashboard" / "Ahlan, {name}"] [trailing]` —
/// the board has no top bar on this screen, this row IS the top bar.
///
/// P0-X06: when an ambient [GreetingProfileCubit] is provided above this widget
/// (the DashboardTab shell wires it from the live `GET /users/me`), its real
/// name + avatar take precedence over the threaded [name]/[avatarUrl] so the
/// header shows the real person instead of "Welcome back" + a "?" placeholder.
/// With no ambient cubit (bare widget tests, the unregistered upsell path) the
/// threaded values apply unchanged.
class JeeberHomeGreeting extends StatelessWidget {
  const JeeberHomeGreeting({super.key, this.name, this.avatarUrl});

  static const Key rootKey = Key('jeeber-home-greeting-root');

  /// Profile display name. `null` shows the generic "Welcome back" fallback.
  final String? name;

  /// Optional profile avatar (cdn-service URL). The disc renders either way —
  /// a `null` URL is the initial-letter case, not an absent avatar.
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final profile = _readGreetingProfile(context);
    final rawName = (profile?.name?.trim().isNotEmpty ?? false)
        ? profile!.name
        : name;
    // Suppress synthetic account handles (`jeeb-89a486f968ed`) / internal
    // emails so the dashboard header never greets a raw hash (audit §T5).
    final resolvedName = displayNameOrNull(rawName);
    final resolvedAvatar = (profile?.avatarUrl?.trim().isNotEmpty ?? false)
        ? profile!.avatarUrl
        : avatarUrl;
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: rootKey,
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.medium,
        Spacing.xLarge,
        0,
      ),
      child: JeebProfileHeader(
        eyebrow: l10n.jeeberDashboardEyebrow,
        name: _resolveGreeting(l10n, resolvedName),
        avatar: JeebAvatar.header(
          initial: resolvedName ?? '',
          imageUrl: resolvedAvatar,
        ),
        avatarIdentifier: 'jeeber_home_avatar',
        // TODO(redesign-24): rating pill blocked on shell header overlay +
        // GreetingProfileState.rating — both are out of this lane.
        // The shell overlays `delivery_tab_wallet_chip` + `delivery_tab_bell`
        // on this exact top-end corner (`shell_screen.dart` `_HeaderedTab`),
        // so the name line reserves their width instead of running under them.
        trailingReserve: Spacing.fourXLarge * 2,
      ),
    );
  }

  /// Reads the ambient [GreetingProfileCubit] state, or `null` when no provider
  /// is mounted above this widget (e.g. a bare widget test / the upsell path).
  static GreetingProfileState? _readGreetingProfile(BuildContext context) {
    try {
      return context.watch<GreetingProfileCubit>().state;
    } on Object {
      return null;
    }
  }

  String _resolveGreeting(AppLocalizations l10n, String? resolvedName) {
    final trimmed = resolvedName?.trim();
    if (trimmed == null || trimmed.isEmpty) return l10n.homeGreetingFallback;
    // Greet with the first name only ("Hello, Sami", not "Hello, Sami Fawaz").
    final firstName = trimmed.split(RegExp(r'\s+')).first;
    return l10n.homeGreetingNamed(firstName);
  }
}
