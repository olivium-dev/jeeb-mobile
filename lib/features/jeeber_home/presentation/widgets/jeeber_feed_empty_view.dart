import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import 'jeeber_home_greeting.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/previews/jeeb_preview.dart';
import '../../../../core/session/greeting_profile_cubit.dart';

/// Deliveryman home empty state matching the Figma "Delivery Screen - Empty
/// State [Delivery Man]" frame (file ZOi3kKtw7sd42ssSVX3Kn4, node 56559:930,
/// screen 23).
///
/// Layout: greeting header (avatar + "Hello, {name}" + tagline) → an inline
/// "Accept orders" availability switch → a hero illustration → a centered
/// "No Requests yet" / "All requests will show up here" block. Distinct from
/// the availability-toggle-heavy [JeeberNoRequestsView]: this is the lean
/// Figma-parity surface a registered, available Jeeber sees with zero
/// incoming requests.
class JeeberFeedEmptyView extends StatelessWidget {
  const JeeberFeedEmptyView({
    super.key,
    this.profileName,
    this.profileAvatarUrl,
    this.acceptOrders = true,
    this.onAcceptOrdersChanged,
  });

  static const Key rootKey = Key('jeeber-feed-empty-view-root');

  /// Greeting display name.
  final String? profileName;

  /// Greeting avatar URL (cdn-service).
  final String? profileAvatarUrl;

  /// Whether the "Accept orders" availability switch is ON.
  final bool acceptOrders;

  /// Toggle handler for the availability switch.
  final ValueChanged<bool>? onAcceptOrdersChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: rootKey,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: _EmptyColumn(
              profileName: profileName,
              profileAvatarUrl: profileAvatarUrl,
              acceptOrders: acceptOrders,
              onAcceptOrdersChanged: onAcceptOrdersChanged,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyColumn extends StatelessWidget {
  const _EmptyColumn({
    required this.profileName,
    required this.profileAvatarUrl,
    required this.acceptOrders,
    required this.onAcceptOrdersChanged,
  });

  final String? profileName;
  final String? profileAvatarUrl;
  final bool acceptOrders;
  final ValueChanged<bool>? onAcceptOrdersChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JeeberHomeGreeting(name: profileName, avatarUrl: profileAvatarUrl),
        _AcceptOrdersRow(
          value: acceptOrders,
          onChanged: onAcceptOrdersChanged,
        ),
        const SizedBox(height: Spacing.large),
        const _EmptyHero(),
        const SizedBox(height: Spacing.large),
        const _EmptyText(),
        const SizedBox(height: Spacing.large),
      ],
    );
  }
}

class _AcceptOrdersRow extends StatelessWidget {
  const _AcceptOrdersRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.small,
      ),
      child: Semantics(
        identifier: 'jeeber_home_accept_orders_switch',
        toggled: value,
        child: OmdsSwitchTile(
          key: const Key('jeeber-home-accept-orders-switch'),
          title: AppLocalizations.of(context).jeeberFeedAcceptOrdersLabel,
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
      ),
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.asset(
            'assets/illustrations/empty_orders.png',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _EmptyTitle(text: l10n.jeeberFeedEmptyTitle),
        const SizedBox(height: Spacing.xSmall),
        _EmptySubtitle(text: l10n.jeeberFeedEmptySubtitle),
      ],
    );
  }
}

class _EmptyTitle extends StatelessWidget {
  const _EmptyTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _EmptySubtitle extends StatelessWidget {
  const _EmptySubtitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSecondaryContainer,
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
// Render tests:
// test/previews/jeeber_home/jeeber_feed_empty_view_preview_test.dart
// ===========================================================================
//
// Widget previews for [JeeberFeedEmptyView] — run with
// `flutter widget-preview start`.
//
// [JeeberFeedEmptyView] is the Figma-parity deliveryman empty state (screen
// 23): greeting header → "Accept orders" switch → hero illustration → the
// "No Requests yet" block. Its whole input surface is four constructor
// arguments (name, avatar URL, switch value, switch callback) plus ONE
// invisible input — the ambient [GreetingProfileCubit] that [JeeberHomeGreeting]
// reads with `context.watch` when a provider happens to be mounted above it.
// That ambient read is why these previews carry a cubit at all; it is seeded
// with a fixed [GreetingProfileState] and no repository, so `load()` returns
// immediately and nothing subscribes. Network-free by construction, not merely
// by the guard in [jeebPreviewHost].
//
// What counts as a "state" here is therefore: **who the greeting resolves to**
// (threaded name / ambient profile / nothing) and **whether the availability
// switch is live**. The empty copy itself never varies — every state renders
// "No Requests yet" — so each preview below is pinned in the render suite by
// its greeting line instead.
//
// The fixture values (`Kamal`, the pravatar URL) are the ones the only current
// host passes: the `jeeb.seam.*` dev-seam feed path in
// `lib/features/shell/tabs/dashboard_tab.dart`. The live registered-jeeber home
// still renders `JeeberNoRequestsView`, so the states below are also a preview
// of what the first production host will get when this surface is wired up —
// including the one it gets wrong today (see [jeeberFeedEmptyViewDeadToggle]).
//
// **Read the `AR RTL dark` rendering of any state below before the light one.**
// The empty copy is painted with the wrong pair of color roles: `_EmptyTitle`
// uses `colorScheme.secondaryContainer` — a *container* (background) role — as
// the headline's foreground, and `_EmptySubtitle` uses `onSecondaryContainer`
// as body text on the scaffold surface. Neither role is defined against
// `surface`, so each one collapses in the theme the other survives: measured
// against `AppTheme`, "No Requests yet" is **1.98:1** on the dark surface
// (WCAG AA wants 3:1 even for large text — the headline is very nearly
// invisible), while "All requests will show up here" is **3.76:1** on the light
// surface (AA wants 4.5:1 for body). Reviewing in one theme only ever shows one
// of the two, which is why the matrix renders both.
//
// Directionality is genuinely clean, which is worth recording so nobody
// re-checks it: every inset is `EdgeInsetsDirectional`, and the AR rendering
// mirrors the header (avatar 342→374 instead of 16→48) and the switch tile
// (track 28→88 instead of 302→362) exactly.

/// A phone body slot: 390 pt wide, and the height left for the Dashboard tab
/// once the status bar and the shell's bottom navigation are gone.
const Size _jeeberFeedEmptyViewPhoneBody = Size(390, 720);

/// The same phone with far less height — a landscape split, a small device, or
/// a keyboard-inset body. The widget answers this with a
/// [SingleChildScrollView], so this state is here to prove the scroll actually
/// engages rather than the column clipping.
const Size _jeeberFeedEmptyViewShortBody = Size(390, 380);

/// The avatar the dev-seam host passes today (`_DevFeedScaffold._avatarUrl`).
const String _jeeberFeedEmptyViewAvatarUrl = 'https://i.pravatar.cc/150?img=12';

/// One state, hosted the way a production shell hosts it.
///
/// [profile] seeds the ambient [GreetingProfileCubit] the Dashboard tab mounts;
/// pass `null` for the hosts that mount no cubit (bare widget tests, the
/// dev-seam feed path) so the threaded [name]/[avatarUrl] apply unchanged.
/// [wired] decides whether `onAcceptOrdersChanged` is supplied — the difference
/// between a switch a jeeber can flip and one that silently ignores the tap.
Widget _jeeberFeedEmptyViewHosted({
  String? name,
  String? avatarUrl,
  bool acceptOrders = true,
  bool wired = true,
  GreetingProfileState? profile,
}) {
  final Widget view = _JeeberFeedEmptyViewAvailabilityHost(
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
@JeebPreview(
  group: 'jeeber_home',
  name: 'Online · nothing in range',
  size: _jeeberFeedEmptyViewPhoneBody,
)
Widget jeeberFeedEmptyViewAccepting() => _jeeberFeedEmptyViewHosted(
      name: 'Kamal',
      avatarUrl: _jeeberFeedEmptyViewAvatarUrl,
    );

/// Availability OFF: the jeeber has stopped accepting orders.
///
/// The empty copy is IDENTICAL to the online state — "No Requests yet" / "All
/// requests will show up here" — even though the reason for the emptiness is
/// completely different, and here it is the jeeber's own doing. Compare with
/// `jeeberFeedOfflineBannerTitle` ("You are offline" / "Go online to see
/// available requests"), which the sibling feed surface shows for exactly this
/// case: the string exists in both ARBs and this view never reaches for it.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Offline · switch off',
  size: _jeeberFeedEmptyViewPhoneBody,
)
Widget jeeberFeedEmptyViewPaused() => _jeeberFeedEmptyViewHosted(
      name: 'Layla',
      avatarUrl: _jeeberFeedEmptyViewAvatarUrl,
      acceptOrders: false,
    );

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
@JeebPreview(
  group: 'jeeber_home',
  name: 'Toggle not wired · no avatar',
  size: _jeeberFeedEmptyViewPhoneBody,
)
Widget jeeberFeedEmptyViewDeadToggle() =>
    _jeeberFeedEmptyViewHosted(name: 'Nadia', wired: false);

/// Cold start: no name, no avatar, no ambient profile — `GET /users/me` has not
/// come back yet (or the account has no name on file).
///
/// The greeting degrades to the localized "Welcome back" rather than greeting a
/// blank, which is the state most jeebers see for the first few hundred
/// milliseconds of the Dashboard tab.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Cold start · generic greeting',
  size: _jeeberFeedEmptyViewPhoneBody,
)
Widget jeeberFeedEmptyViewColdStart() => _jeeberFeedEmptyViewHosted();

/// P0-X06 regression guard, made visible.
///
/// When the Dashboard tab mounts a [GreetingProfileCubit] over this view, the
/// live profile must WIN over whatever the host threaded in — that is the whole
/// point of the ambient read in [JeeberHomeGreeting]. Here the host threads the
/// old hardcoded placeholder (`Kamal`, no avatar) while the cubit carries the
/// real profile, so this preview must render "Hello, Rami" with the real avatar.
/// If it ever shows "Hello, Kamal", the precedence in `JeeberHomeGreeting.build`
/// has inverted and every jeeber is being greeted by a placeholder again.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Ambient profile wins (P0-X06)',
  size: _jeeberFeedEmptyViewPhoneBody,
)
Widget jeeberFeedEmptyViewAmbientProfile() => _jeeberFeedEmptyViewHosted(
      name: 'Kamal',
      profile: const GreetingProfileState(
        name: 'Rami Haddad',
        avatarUrl: _jeeberFeedEmptyViewAvatarUrl,
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
@JeebPreview(
  group: 'jeeber_home',
  name: 'Long name · short viewport',
  size: _jeeberFeedEmptyViewShortBody,
)
Widget jeeberFeedEmptyViewLongName() => _jeeberFeedEmptyViewHosted(
      name: 'Abdulrahman Al-Muhandis Al-Trabulsi',
      avatarUrl: _jeeberFeedEmptyViewAvatarUrl,
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
class _JeeberFeedEmptyViewAvailabilityHost extends StatefulWidget {
  const _JeeberFeedEmptyViewAvailabilityHost({
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
  State<_JeeberFeedEmptyViewAvailabilityHost> createState() =>
      _JeeberFeedEmptyViewAvailabilityHostState();
}

class _JeeberFeedEmptyViewAvailabilityHostState
    extends State<_JeeberFeedEmptyViewAvailabilityHost> {
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
