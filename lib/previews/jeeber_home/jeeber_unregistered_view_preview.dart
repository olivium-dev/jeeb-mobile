/// Widget previews for [JeeberUnregisteredView] — run with
/// `flutter widget-preview start`.
///
/// This is State 1 of the Jeeber home (Figma 56614:18920): the upsell a user
/// sees on the DELIVERY tab before they have registered as a delivery man. Its
/// whole input surface is three values — `onRegister`, `profileName`,
/// `ctaIdentifier` — and every string comes from the ARB. There is no cubit and
/// no repository to seed: [JeeberHomeGreeting] *looks* for an ambient
/// `GreetingProfileCubit` but falls back to the threaded name when none is
/// mounted, and no provider is mounted here. These previews are network-free
/// because there is nothing to fetch, not merely because [jeebPreviewHost]
/// guards them.
///
/// What varies between states is therefore the **name** and the **box**, and
/// the box is the half that breaks. The view is
/// `SafeArea > Column[greeting, Expanded(hero), CTA, 20pt gap]` with no scroll
/// view anywhere, and the hero it puts in that [Expanded] is an
/// [OmdsEmptyState] whose illustration is a hard-coded 200×200 circle plus 24pt
/// of padding a side. That subtree cannot shrink: hand the [Expanded] less than
/// its content and the inner [Column] paints the overflow stripe and clips.
///
/// The arithmetic, measured rather than guessed: the greeting takes 48pt, the
/// CTA a hard-coded 48pt and the trailing gap 20pt, so the hero is handed
/// `height − 116`. Its own minimum is `296 + title + subtitle` — 380pt at 390pt
/// wide, 412pt at 320pt wide, where the headline needs a third line. The view
/// therefore needs a body of about **496pt** (390pt wide) or **528pt** (320pt
/// wide) before anything clips, and every pt of that floor is spent by the
/// illustration.
///
/// Height comes from the annotation `size` only — never baked into the tree —
/// following the precedent in `gps_denied_state_preview.dart`: a short height
/// compiled into the widget would make the render suite throw on every run
/// instead of on the case under review. Width IS baked where the state is about
/// a narrow device, because a 320pt phone is a real device and a state that is
/// only compact in the canvas is not a state.
///
/// Every state carries a different profile name on purpose. The rest of the
/// copy — headline, subtitle, CTA — is identical in all five, so the greeting
/// line is the only thing that can prove a preview rendered ITS OWN state
/// rather than the previous one; the render suite pins exactly that.
library;

import 'package:flutter/material.dart';

import '../../features/jeeber_home/presentation/widgets/jeeber_unregistered_view.dart';
import '../harness/jeeb_preview.dart';

/// The slot the DELIVERY tab hands this view on a modern phone: full body
/// height once the status bar and the bottom nav are gone.
const Size _phoneBody = Size(390, 680);

/// The narrowest device the app still supports, same generous height.
const Size _compactPhone = Size(320, 600);

/// A short body — a small phone in a locale with a tall system font, or any
/// host that keeps chrome above and below. This is the box the view does not
/// fit.
const Size _shortBody = Size(390, 420);

/// One state: the view with a name, optionally the JM-036 gate identifier, and
/// optionally a baked device width.
///
/// `onRegister` is a no-op — the production callback pushes the delivery-man
/// onboarding route, and a preview has no router. Nothing else is stubbed:
/// this is the production widget with production copy.
Widget _hosted({String? profileName, String? ctaIdentifier, double? width}) {
  final Widget view = JeeberUnregisteredView(
    onRegister: () {},
    profileName: profileName,
    ctaIdentifier: ctaIdentifier,
  );
  if (width == null) return view;
  // `height: double.infinity` against the loose constraints [Center] passes
  // down keeps the height bounded, which the view's [Expanded] requires.
  return Center(
    child: SizedBox(width: width, height: double.infinity, child: view),
  );
}

/// Cold start, and the most common first frame of this screen.
///
/// The DELIVERY-tab gate builds the prompt as soon as it knows the user has no
/// KYC record, which is before `GET /users/me` has resolved a display name —
/// so `profileName` is null and the greeting degrades to the localized generic
/// line. Every other state below is what the same screen looks like a few
/// hundred milliseconds later.
@JeebPreview(group: 'jeeber_home', name: 'Cold start · no name', size: _phoneBody)
Widget jeeberUnregisteredViewColdStart() => _hosted();

/// The settled happy path: a named user who has not registered yet.
///
/// 'Kamal' is the fixture `test/jeeber_unregistered_view_test.dart` already
/// uses, kept identical so the preview and the widget test describe the same
/// user. Greets the first name only.
///
/// Look at the `EN 200% text` rendering of this one before anything else. At
/// 390×680 — an ordinary phone body — the English headline goes from two lines
/// to four (64pt → 256pt) while the 200pt illustration does not give an inch
/// back, and the view **overflows by 136pt**. It needs roughly 816pt of body
/// height to survive 200% text in English — the Galaxy S22 the team tests on is
/// 360×780 logical, leaving about 676pt once the status bar and bottom nav are
/// gone, and it is narrower than this preview besides, so the real device clips
/// harder than the canvas does. The `AR RTL dark` rendering does not reproduce
/// it, because "سجّل كموصِّل" still fits on one line — this is an English-only
/// accessibility break that an Arabic-first spot check would miss.
@JeebPreview(group: 'jeeber_home', name: 'Named jeeber', size: _phoneBody)
Widget jeeberUnregisteredViewNamed() => _hosted(profileName: 'Kamal');

/// How `dashboard_tab.dart` really builds it: the CTA additionally wrapped in
/// the JM-036 coined id `delivery_register_now_cta`.
///
/// Deliberately identical to [jeeberUnregisteredViewNamed] on screen — the
/// state under review is the semantics tree, not the pixels. The root sets
/// `explicitChildNodes: true` so the extra wrapper does NOT swallow the W0
/// `jeeber_unregistered_register_button` id the way CAP-3 swallowed it before
/// commit 8b81dc1; both ids must stay individually queryable, because Maestro
/// flow 19 taps the inner one and the JM-036 gate flow taps the outer one. The
/// render suite asserts both survive.
@JeebPreview(group: 'jeeber_home', name: 'JM-036 gate CTA id', size: _phoneBody)
Widget jeeberUnregisteredViewGateCta() => _hosted(
      profileName: 'Zeina',
      ctaIdentifier: 'delivery_register_now_cta',
    );

/// Longest plausible content on the narrowest supported device: a three-part
/// Arabic name in Latin transliteration, on a 320pt phone.
///
/// Two different clipping rules meet here. The greeting is `maxLines: 1` with
/// an ellipsis, and it greets the FIRST name only — but "Abdulrahman" is long
/// enough on its own to reach the ceiling: measured, the line fills all 288pt
/// of the content width against 242pt for "Hello, Nour", so this is the state
/// where the ellipsis appears rather than a comfortable margin. The headline
/// underneath has no `maxLines` at all, so it wraps instead, and at 320pt
/// (minus 24pt of empty-state padding a side) "Register as a delivery man"
/// needs a THIRD line — 96pt against 64pt on a 390pt phone — which the fixed
/// 200pt illustration above it does not give back. Compare against
/// [jeeberUnregisteredViewShortBody]: this is the same squeeze arriving from
/// the width axis.
@JeebPreview(group: 'jeeber_home', name: 'Long name · 320pt phone', size: _compactPhone)
Widget jeeberUnregisteredViewLongNameCompact() => _hosted(
      profileName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
      width: 320,
    );

/// **The state that breaks**: the same view in a 420pt-tall body.
///
/// The greeting, the CTA and the 20pt trailing gap take their intrinsic height
/// first; the hero gets the remaining 304pt and needs 380pt, so it **overflows
/// by 76pt** — silently clipped in release, because nothing scrolls. The
/// `AR RTL dark` rendering overflows by only 44pt, since the shorter Arabic
/// headline saves a line; the defect is the same, the English copy just hits it
/// harder.
///
/// 420pt is not a strawman: it is a phone in landscape, a small phone with the
/// system font one notch up, or any host that keeps chrome above and below.
/// The fix belongs to the view — wrap the column in a scroll view, or drop the
/// illustration under a height threshold — not to its hosts.
///
/// Note what this preview deliberately does NOT do: bake 420pt into the tree.
/// The short height is declared to the canvas only, so the render suite (which
/// pumps at 800×600) sees a view that fits and stays green, and the overflow
/// shows up where a human is looking at it.
@JeebPreview(group: 'jeeber_home', name: 'Short body (420pt)', size: _shortBody)
Widget jeeberUnregisteredViewShortBody() => _hosted(profileName: 'Nour');
