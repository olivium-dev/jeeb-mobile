import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/friendly_reference.dart';
import '../../../../core/session/greeting_profile_cubit.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../core/widgets/jeeb/jeeb_profile_header.dart';
import '../../../../core/widgets/jeeb/jeeb_surface_tone.dart';
import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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

  /// The band while `GET /users/me` is still out — it greets nobody.
  static const String loadingIdentifier = 'jeeber_home_greeting_loading';

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
    // F4: the profile read has not landed, so there is no person to greet —
    // "Welcome back" over a '?' disc is a fabricated identity, not a fallback.
    final pending = _readPending(profile, rawName);
    final Widget band = Padding(
      key: rootKey,
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.medium,
        Spacing.xLarge,
        0,
      ),
      child: JeebProfileHeader(
        eyebrow: l10n.jeeberDashboardEyebrow,
        name: pending ? '' : _resolveGreeting(l10n, resolvedName),
        avatar: pending
            ? const _PendingAvatarDisc()
            : JeebAvatar.header(
                initial: resolvedName ?? '',
                imageUrl: resolvedAvatar,
              ),
        avatarIdentifier: 'jeeber_home_avatar',
        // TODO(midnight): omitted — R16's ★ pill needs `JeebProfileHeader
        // .ratingLabel` + a rating on GreetingProfileState, and the shell
        // overlays ShellHeaderActions on this exact corner (see §open).
        trailingReserve: Spacing.fourXLarge * 2,
      ),
    );
    if (!pending) return band;
    return Semantics(
      identifier: loadingIdentifier,
      container: true,
      child: band,
    );
  }

  /// Pending only while the cubit says the read is out; every terminal state —
  /// landed, landed nameless, failed — falls through to the fallback greeting.
  static bool _readPending(GreetingProfileState? profile, String? rawName) {
    if (profile == null || !profile.isLoading) return false;
    return (rawName ?? '').trim().isEmpty;
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
    // Greet with the first name only ("Ahlan, Sami", not "Ahlan, Sami Fawaz").
    final firstName = trimmed.split(RegExp(r'\s+')).first;
    return l10n.jeeberGreetingAhlan(firstName);
  }
}

/// The identity disc before any profile has landed: the dormant fill with no
/// letter — [JeebAvatar] normalises an empty name to '?', which is a claim.
class _PendingAvatarDisc extends StatelessWidget {
  const _PendingAvatarDisc();

  @override
  Widget build(BuildContext context) {
    final tone = JeebSurfaceTone.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: JeebAvatar.headerDiameter,
      height: JeebAvatar.headerDiameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tone.onNavy ? tone.chipFill : scheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, not shipped. Previews are tree-shaken out of release builds.

const Size _jeeberHomeGreetingBox = Size(390, 120);

/// Hosts the band under an ambient cubit the way DashboardTab does, so the
/// pending band is reachable without a live repository.
Widget _jeeberHomeGreetingHosted(GreetingProfileState? profile) {
  const Widget greeting = JeeberHomeGreeting();
  if (profile == null) return greeting;
  return BlocProvider<GreetingProfileCubit>(
    create: (_) => GreetingProfileCubit(seed: profile),
    child: greeting,
  );
}

@JeebPreview(
  group: 'jeeber_home',
  name: 'getMe in flight · greets nobody',
  size: _jeeberHomeGreetingBox,
)
Widget jeeberHomeGreetingPending() => _jeeberHomeGreetingHosted(
      const GreetingProfileState(status: GreetingProfileStatus.loading),
    );

@JeebPreview(
  group: 'jeeber_home',
  name: 'Landed nameless · fallback greeting',
  size: _jeeberHomeGreetingBox,
)
Widget jeeberHomeGreetingResolvedNameless() => _jeeberHomeGreetingHosted(
      const GreetingProfileState(status: GreetingProfileStatus.resolved),
    );

@JeebPreview(
  group: 'jeeber_home',
  name: 'Landed named',
  size: _jeeberHomeGreetingBox,
)
Widget jeeberHomeGreetingNamed() => _jeeberHomeGreetingHosted(
      const GreetingProfileState(
        name: 'Karim Haddad',
        status: GreetingProfileStatus.resolved,
      ),
    );

@JeebPreview(
  group: 'jeeber_home',
  name: 'No ambient cubit · fallback greeting',
  size: _jeeberHomeGreetingBox,
)
Widget jeeberHomeGreetingNoCubit() => _jeeberHomeGreetingHosted(null);
