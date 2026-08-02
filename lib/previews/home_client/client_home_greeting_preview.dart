/// Widget previews for [ClientHomeGreeting] — run with
/// `flutter widget-preview start`.
///
/// Every state below is driven the way the production shell drives it: an
/// ambient [GreetingProfileCubit] seeded with a fixed [GreetingProfileState].
/// A cubit built with no repository is inert — `load()` returns immediately and
/// nothing subscribes — so these previews are network-free by construction, not
/// just by the guard in [jeebPreviewHost].
///
/// The states mirror the contract asserted in
/// `test/client_home_greeting_test.dart`; the previews exist so the *visual*
/// half of that contract (overflow, RTL mirroring, large text) is reviewable
/// without booting the app and signing in.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/session/greeting_profile_cubit.dart';
import '../harness/jeeb_preview.dart';
import '../../features/home_client/presentation/widgets/client_home_greeting.dart';

/// The canvas box for a home header: phone width, header height.
const Size _headerBox = Size(390, 120);

Widget _hosted(GreetingProfileState? profile, {String? name}) {
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
@JeebPreview(group: 'home_client', name: 'Named + avatar', size: _headerBox)
Widget clientHomeGreetingNamed() => _hosted(
      const GreetingProfileState(
        name: 'Sami Fawaz',
        avatarUrl: 'https://cdn.jeeb.app/avatars/sami.png',
      ),
    );

/// Cold start: `GET /users/me` has not resolved yet, so there is no name and no
/// avatar. Degrades to the localized generic greeting + the "?" avatar — this
/// is the state most users see for the first few hundred milliseconds.
@JeebPreview(group: 'home_client', name: 'Generic fallback', size: _headerBox)
Widget clientHomeGreetingFallback() => _hosted(null);

/// A name on file but no avatar — the initials avatar, not "?".
///
/// The distinction matters: "?" is reserved for "we know nothing about you",
/// and showing it to a named user reads as a broken profile.
@JeebPreview(group: 'home_client', name: 'Name, no avatar', size: _headerBox)
Widget clientHomeGreetingInitialsOnly() =>
    _hosted(const GreetingProfileState(name: 'Layla'));

/// Audit §T5 regression guard, made visible.
///
/// Phone-only accounts carry a synthetic handle (`jeeb-<hash>`) or an internal
/// address (`…@jeeb.internal`) as their only "name". The header must NEVER
/// greet those — it falls back to the generic greeting. If this preview ever
/// renders "Hello, jeeb-…", the suppression in `displayNameOrNull` has broken.
@JeebPreview(group: 'home_client', name: 'Synthetic handle suppressed', size: _headerBox)
Widget clientHomeGreetingSyntheticHandle() =>
    _hosted(const GreetingProfileState(name: 'jeeb-e1a35ea8a520'));

/// Layout ceiling: a long name must ellipsize and must not push the "+" button
/// off the trailing edge.
///
/// This is the state the AR RTL and 200%-text renderings of the matrix are
/// really for — the English light rendering looks fine long after the other two
/// have broken.
@JeebPreview(group: 'home_client', name: 'Long name overflow', size: _headerBox)
Widget clientHomeGreetingLongName() => _hosted(
      const GreetingProfileState(name: 'Abdulrahman Al-Muhandis Al-Trabulsi'),
    );
