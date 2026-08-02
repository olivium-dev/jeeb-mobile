/// Widget previews for [JeeberHomeGreeting] — run with
/// `flutter widget-preview start`.
///
/// The jeeber dashboard title has TWO input paths and the states below exercise
/// both, because they produce visibly different headers:
///
/// * the ambient [GreetingProfileCubit] the DashboardTab wires from the live
///   `GET /users/me` (name + avatar, P0-X06), and
/// * the threaded [JeeberHomeGreeting.name] / `avatarUrl` the feed, empty,
///   no-requests and unregistered views pass down.
///
/// A cubit built with no repository is inert — `load()` returns immediately and
/// nothing subscribes — so these previews are network-free by construction, not
/// just by the guard in [jeebPreviewHost].
///
/// Unlike `ClientHomeGreeting`, this header has NO avatar of its own when no
/// `avatarUrl` resolves: `_GreetingRow` returns the bare text line instead of a
/// "?" placeholder. Three of the five call sites never pass an avatar, so the
/// avatar-less renderings below are the common case, not an edge case.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/session/greeting_profile_cubit.dart';
import '../harness/jeeb_preview.dart';
import '../../features/jeeber_home/presentation/widgets/jeeber_home_greeting.dart';

/// The canvas box for the dashboard title: phone width, header height with
/// enough slack that the 200%-text rendering is not clipped by the box itself.
const Size _headerBox = Size(390, 110);

Widget _hosted({
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
@JeebPreview(group: 'jeeber_home', name: 'Named + avatar', size: _headerBox)
Widget jeeberHomeGreetingNamedWithAvatar() => _hosted(
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
@JeebPreview(group: 'jeeber_home', name: 'Generic fallback', size: _headerBox)
Widget jeeberHomeGreetingFallback() => _hosted();

/// The unregistered upsell path (`JeeberUnregisteredView` /
/// `JeeberNoRequestsView`): a name threaded down, no avatar ever.
///
/// 'Kamal' is the literal placeholder `DashboardTab` threads on this path, so
/// this preview is the real screen-19 header, not an invented one.
@JeebPreview(group: 'jeeber_home', name: 'Threaded name, no avatar', size: _headerBox)
Widget jeeberHomeGreetingThreadedNameOnly() => _hosted(name: 'Kamal');

/// P0-X06 precedence, made visible: the ambient profile must WIN over a stale
/// threaded name.
///
/// The shell keeps dashboard tabs alive in an IndexedStack, so the threaded
/// value can be older than the cubit's. If this preview ever renders
/// "Hello, Kamal", the ambient read in `build` has stopped taking precedence
/// and every jeeber would be greeted by the placeholder after a profile edit.
@JeebPreview(group: 'jeeber_home', name: 'Ambient profile wins', size: _headerBox)
Widget jeeberHomeGreetingAmbientWins() => _hosted(
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
@JeebPreview(group: 'jeeber_home', name: 'Synthetic handle suppressed', size: _headerBox)
Widget jeeberHomeGreetingSyntheticHandle() => _hosted(
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
@JeebPreview(group: 'jeeber_home', name: 'Long name ellipsis', size: _headerBox)
Widget jeeberHomeGreetingLongName() => _hosted(
      profile: const GreetingProfileState(
        name: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        avatarUrl: 'https://cdn.jeeb.app/avatars/abdulrahman.png',
      ),
    );
