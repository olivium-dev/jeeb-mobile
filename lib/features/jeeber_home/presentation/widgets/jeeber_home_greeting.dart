import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/friendly_reference.dart';
import '../../../../core/session/greeting_profile_cubit.dart';
import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// The Jeeber dashboard's single page title.
///
/// The personalized "Hello, {name}" line replaces the former generic
/// "Jeeber Home" app-bar title and the marketing subtitle. Keeping one compact
/// title prevents three peer headings from competing above the request feed.
///
/// P0-X06: when an ambient [GreetingProfileCubit] is provided above this widget
/// (the DashboardTab shell wires it from the live `GET /users/me`), its real
/// name + avatar take precedence over the threaded [name]/[avatarUrl] so the
/// header shows "Hello, {name}" + the real avatar instead of "Welcome back" +
/// a "?" placeholder. With no ambient cubit (bare widget tests, the
/// unregistered upsell path) the threaded values apply unchanged.
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

  /// Reads the ambient [GreetingProfileCubit] state, or `null` when no provider
  /// is mounted above this widget (e.g. a bare widget test / the upsell path).
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
    // Greet with the first name only ("Hello, Sami", not "Hello, Sami Fawaz").
    final firstName = trimmed.split(RegExp(r'\s+')).first;
    return l10n.homeGreetingNamed(firstName);
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/jeeber_home/jeeber_home_greeting_preview_test.dart
// ===========================================================================
//
// Widget previews for [JeeberHomeGreeting] — run with
// `flutter widget-preview start`.
//
// The jeeber dashboard title has TWO input paths and the states below exercise
// both, because they produce visibly different headers:
//
// * the ambient [GreetingProfileCubit] the DashboardTab wires from the live
//   `GET /users/me` (name + avatar, P0-X06), and
// * the threaded [JeeberHomeGreeting.name] / `avatarUrl` the feed, empty,
//   no-requests and unregistered views pass down.
//
// A cubit built with no repository is inert — `load()` returns immediately and
// nothing subscribes — so these previews are network-free by construction, not
// just by the guard in [jeebPreviewHost].
//
// Unlike `ClientHomeGreeting`, this header has NO avatar of its own when no
// `avatarUrl` resolves: `_GreetingRow` returns the bare text line instead of a
// "?" placeholder. Three of the five call sites never pass an avatar, so the
// avatar-less renderings below are the common case, not an edge case.

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
///
/// Greets the FIRST name only ("Hello, Sami", never "Hello, Sami Fawaz"), and
/// this is the only shape where the header is a Row — avatar, gap, then a
/// [Flexible] greeting line.
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
///
/// This is what a jeeber sees for the first few hundred milliseconds of every
/// dashboard mount, and it is worth reviewing beside the state above: when
/// getMe lands, an avatar appears and the title reflows sideways.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Generic fallback',
  size: _jeeberHomeGreetingHeaderBox,
)
Widget jeeberHomeGreetingFallback() => _jeeberHomeGreetingHosted();

/// The unregistered upsell path (`JeeberUnregisteredView` /
/// `JeeberNoRequestsView`): a name threaded down, no avatar ever.
///
/// 'Kamal' is the literal placeholder `DashboardTab` threads on this path, so
/// this preview is the real screen-19 header, not an invented one.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Threaded name, no avatar',
  size: _jeeberHomeGreetingHeaderBox,
)
Widget jeeberHomeGreetingThreadedNameOnly() =>
    _jeeberHomeGreetingHosted(name: 'Kamal');

/// P0-X06 precedence, made visible: the ambient profile must WIN over a stale
/// threaded name.
///
/// The shell keeps dashboard tabs alive in an IndexedStack, so the threaded
/// value can be older than the cubit's. If this preview ever renders
/// "Hello, Kamal", the ambient read in `build` has stopped taking precedence
/// and every jeeber would be greeted by the placeholder after a profile edit.
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
///
/// Phone-only accounts carry a synthetic handle (`jeeb-<hash>`) or an internal
/// address (`…@jeeb.internal`) as their only "name". The header must NEVER
/// greet those — it falls back to the generic greeting.
///
/// Two things this state exposes beyond that:
///   * the ambient handle wins the precedence check BEFORE suppression runs, so
///     the perfectly good threaded 'Rami' is discarded and the header degrades
///     all the way to "Welcome back" instead of falling through to it. Latent
///     today (DashboardTab threads a name only on the unregistered path, which
///     has no cubit) — but it is one wiring change away from greeting a named
///     jeeber generically.
///   * the suppressed name also drops the avatar INITIAL to "?" while the real
///     profile picture still loads behind it, because the avatar is built from
///     the suppressed name and only the URL survives.
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
///
/// This is the state the AR RTL and 200%-text renderings of the matrix are
/// really for — the English light rendering looks fine long after the other two
/// have broken.
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
