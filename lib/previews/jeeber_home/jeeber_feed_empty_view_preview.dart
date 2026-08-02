/// Widget previews for [JeeberFeedEmptyView] — run with
/// `flutter widget-preview start`.
///
/// [JeeberFeedEmptyView] is the Figma-parity deliveryman empty state (screen
/// 23): greeting header → "Accept orders" switch → hero illustration → the
/// "No Requests yet" block. Its whole input surface is four constructor
/// arguments (name, avatar URL, switch value, switch callback) plus ONE
/// invisible input — the ambient [GreetingProfileCubit] that [JeeberHomeGreeting]
/// reads with `context.watch` when a provider happens to be mounted above it.
/// That ambient read is why these previews carry a cubit at all; it is seeded
/// with a fixed [GreetingProfileState] and no repository, so `load()` returns
/// immediately and nothing subscribes. Network-free by construction, not merely
/// by the guard in [jeebPreviewHost].
///
/// What counts as a "state" here is therefore: **who the greeting resolves to**
/// (threaded name / ambient profile / nothing) and **whether the availability
/// switch is live**. The empty copy itself never varies — every state renders
/// "No Requests yet" — so each preview below is pinned in the render suite by
/// its greeting line instead.
///
/// The fixture values (`Kamal`, the pravatar URL) are the ones the only current
/// host passes: the `jeeb.seam.*` dev-seam feed path in
/// `lib/features/shell/tabs/dashboard_tab.dart`. The live registered-jeeber home
/// still renders `JeeberNoRequestsView`, so the states below are also a preview
/// of what the first production host will get when this surface is wired up —
/// including the one it gets wrong today (see [jeeberFeedEmptyViewDeadToggle]).
///
/// **Read the `AR RTL dark` rendering of any state below before the light one.**
/// The empty copy is painted with the wrong pair of color roles: `_EmptyTitle`
/// uses `colorScheme.secondaryContainer` — a *container* (background) role — as
/// the headline's foreground, and `_EmptySubtitle` uses `onSecondaryContainer`
/// as body text on the scaffold surface. Neither role is defined against
/// `surface`, so each one collapses in the theme the other survives: measured
/// against `AppTheme`, "No Requests yet" is **1.98:1** on the dark surface
/// (WCAG AA wants 3:1 even for large text — the headline is very nearly
/// invisible), while "All requests will show up here" is **3.76:1** on the light
/// surface (AA wants 4.5:1 for body). Reviewing in one theme only ever shows one
/// of the two, which is why the matrix renders both.
///
/// Directionality is genuinely clean, which is worth recording so nobody
/// re-checks it: every inset is `EdgeInsetsDirectional`, and the AR rendering
/// mirrors the header (avatar 342→374 instead of 16→48) and the switch tile
/// (track 28→88 instead of 302→362) exactly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/session/greeting_profile_cubit.dart';
import '../../features/jeeber_home/presentation/widgets/jeeber_feed_empty_view.dart';
import '../harness/jeeb_preview.dart';

/// A phone body slot: 390 pt wide, and the height left for the Dashboard tab
/// once the status bar and the shell's bottom navigation are gone.
const Size _phoneBody = Size(390, 720);

/// The same phone with far less height — a landscape split, a small device, or
/// a keyboard-inset body. The widget answers this with a
/// [SingleChildScrollView], so this state is here to prove the scroll actually
/// engages rather than the column clipping.
const Size _shortBody = Size(390, 380);

/// The avatar the dev-seam host passes today (`_DevFeedScaffold._avatarUrl`).
const String _avatarUrl = 'https://i.pravatar.cc/150?img=12';

/// One state, hosted the way a production shell hosts it.
///
/// [profile] seeds the ambient [GreetingProfileCubit] the Dashboard tab mounts;
/// pass `null` for the hosts that mount no cubit (bare widget tests, the
/// dev-seam feed path) so the threaded [name]/[avatarUrl] apply unchanged.
/// [wired] decides whether `onAcceptOrdersChanged` is supplied — the difference
/// between a switch a jeeber can flip and one that silently ignores the tap.
Widget _hosted({
  String? name,
  String? avatarUrl,
  bool acceptOrders = true,
  bool wired = true,
  GreetingProfileState? profile,
}) {
  final Widget view = _AvailabilityHost(
    name: name,
    avatarUrl: avatarUrl,
    acceptOrders: acceptOrders,
    wired: wired,
  );
  if (profile == null) return view;
  return BlocProvider<GreetingProfileCubit>(
    create: (_) => GreetingProfileCubit(seed: profile),
    child: view,
  );
}

/// The intended state: an approved jeeber, online, with nothing in range.
///
/// This is the exact configuration the dev-seam host passes (`Kamal` + the
/// pravatar avatar) except that the switch is wired, so it moves when tapped.
/// Flip it in the canvas and compare against [jeeberFeedEmptyViewPaused] — the
/// only thing that changes on a 720 pt surface is a 40 pt track, which is worth
/// knowing before deciding this screen communicates availability well enough.
///
/// At default text size the whole surface fits with room to spare: the header
/// ends at y≈48, the hero is a 358×358 square, and the copy block closes at
/// y≈602 of the 720 pt slot. Nothing here is tight — which is exactly why the
/// `EN 200% text` rendering (see [jeeberFeedEmptyViewLongName]) is surprising.
@JeebPreview(name: 'Online · nothing in range', size: _phoneBody)
Widget jeeberFeedEmptyViewAccepting() =>
    _hosted(name: 'Kamal', avatarUrl: _avatarUrl);

/// Availability OFF: the jeeber has stopped accepting orders.
///
/// The empty copy is IDENTICAL to the online state — "No Requests yet" / "All
/// requests will show up here" — even though the reason for the emptiness is
/// completely different, and here it is the jeeber's own doing. Compare with
/// `jeeberFeedOfflineBannerTitle` ("You are offline" / "Go online to see
/// available requests"), which the sibling feed surface shows for exactly this
/// case: the string exists in both ARBs and this view never reaches for it.
@JeebPreview(name: 'Offline · switch off', size: _phoneBody)
Widget jeeberFeedEmptyViewPaused() =>
    _hosted(name: 'Layla', avatarUrl: _avatarUrl, acceptOrders: false);

/// **What the only real host actually renders today.**
///
/// `_DevFeedBody` constructs `JeeberFeedEmptyView(profileName:,
/// profileAvatarUrl:)` and passes no `onAcceptOrdersChanged`, so the callback is
/// `null` — [OmdsSwitchTile] then drops the `InkWell.onTap` and disables the
/// [Switch], but keeps `enabled: true`, which means the "Accept orders" title
/// stays at full `onSurface` opacity. The result reads as a live control that
/// ignores every tap rather than as a disabled one.
///
/// No avatar either, which is the second half of this state: with `avatarUrl`
/// null [JeeberHomeGreeting] drops the whole avatar row and the header collapses
/// to a bare line of text.
@JeebPreview(name: 'Toggle not wired · no avatar', size: _phoneBody)
Widget jeeberFeedEmptyViewDeadToggle() => _hosted(name: 'Nadia', wired: false);

/// Cold start: no name, no avatar, no ambient profile — `GET /users/me` has not
/// come back yet (or the account has no name on file).
///
/// The greeting degrades to the localized "Welcome back" rather than greeting a
/// blank, which is the state most jeebers see for the first few hundred
/// milliseconds of the Dashboard tab.
@JeebPreview(name: 'Cold start · generic greeting', size: _phoneBody)
Widget jeeberFeedEmptyViewColdStart() => _hosted();

/// P0-X06 regression guard, made visible.
///
/// When the Dashboard tab mounts a [GreetingProfileCubit] over this view, the
/// live profile must WIN over whatever the host threaded in — that is the whole
/// point of the ambient read in [JeeberHomeGreeting]. Here the host threads the
/// old hardcoded placeholder (`Kamal`, no avatar) while the cubit carries the
/// real profile, so this preview must render "Hello, Rami" with the real avatar.
/// If it ever shows "Hello, Kamal", the precedence in `JeeberHomeGreeting.build`
/// has inverted and every jeeber is being greeted by a placeholder again.
@JeebPreview(name: 'Ambient profile wins (P0-X06)', size: _phoneBody)
Widget jeeberFeedEmptyViewAmbientProfile() => _hosted(
      name: 'Kamal',
      profile: const GreetingProfileState(
        name: 'Rami Haddad',
        avatarUrl: _avatarUrl,
      ),
    );

/// The layout ceiling: the longest plausible name in the shortest plausible
/// body.
///
/// Two things are under review. The greeting is `maxLines: 1` + ellipsis inside
/// a [Flexible], so the name must clip rather than shove the header wider — and
/// it does, on one 28 pt line, in both directions (AR: 16→334 with the avatar
/// mirrored to 342→374).
///
/// The 380 pt box is the other half, and it is where the accessibility ceiling
/// bites. The hero is `AspectRatio(1)` on the full content width: 358×358 at
/// default text size, and **still 358×358 at 200%**, because an aspect ratio
/// does not follow the text scaler. Everything around it doubles, so the copy
/// block slides from y≈522 to y≈594 and the subtitle's baseline runs out to
/// y≈914 — past the bottom of even the 720 pt slot in
/// [jeeberFeedEmptyViewAccepting], let alone this one. There is no overflow
/// exception (the [SingleChildScrollView] absorbs it) and that is the problem:
/// at 200% the screen silently opens on an illustration, with the only two
/// strings that explain the emptiness parked below the fold.
@JeebPreview(name: 'Long name · short viewport', size: _shortBody)
Widget jeeberFeedEmptyViewLongName() => _hosted(
      name: 'Abdulrahman Al-Muhandis Al-Trabulsi',
      avatarUrl: _avatarUrl,
    );

// ---------------------------------------------------------------------------
// Fixtures. Nothing below is production code.
// ---------------------------------------------------------------------------

/// Holds the availability value so the switch moves when it is tapped in the
/// canvas.
///
/// [JeeberFeedEmptyView] is stateless and renders whatever `acceptOrders` it is
/// given; without this the switch would snap back on every tap and a reviewer
/// could not tell a wired toggle from the dead one in
/// [jeeberFeedEmptyViewDeadToggle]. No controller, no ticker, nothing to settle.
class _AvailabilityHost extends StatefulWidget {
  const _AvailabilityHost({
    required this.name,
    required this.avatarUrl,
    required this.acceptOrders,
    required this.wired,
  });

  final String? name;
  final String? avatarUrl;
  final bool acceptOrders;

  /// Whether `onAcceptOrdersChanged` is supplied at all.
  final bool wired;

  @override
  State<_AvailabilityHost> createState() => _AvailabilityHostState();
}

class _AvailabilityHostState extends State<_AvailabilityHost> {
  late bool _acceptOrders = widget.acceptOrders;

  @override
  Widget build(BuildContext context) {
    return JeeberFeedEmptyView(
      profileName: widget.name,
      profileAvatarUrl: widget.avatarUrl,
      acceptOrders: _acceptOrders,
      // The unwired state passes null on purpose: it is exactly what a host
      // that forgets the callback gets.
      onAcceptOrdersChanged: widget.wired
          ? (bool value) => setState(() => _acceptOrders = value)
          : null,
    );
  }
}
