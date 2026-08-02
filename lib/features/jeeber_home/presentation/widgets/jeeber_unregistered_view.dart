import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import 'jeeber_home_greeting.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// State 1 of the Jeeber home (Figma node 56614:18920 — "Delivery screen,
/// User not registered as delivery man"): the user has not yet completed the
/// delivery-man registration.
///
/// Visual: shared greeting header → large scooter-out-of-phone hero illo →
/// "Register as a delivery man" headline → "Start earning money" subtitle →
/// "Register now" primary button pinned toward the bottom. The illustration is
/// rendered as a themed placeholder until the branded scooter asset ships
/// through `omds-flutter`.
///
/// `onRegister` is wired to the host's delivery-man onboarding route — the home
/// screen itself stays route-agnostic per the existing `onOpenFeedRequest`
/// pattern. Closes the JEEB-66 hardcoded-string debt: all copy is now keyed in
/// `app_en.arb` + `app_ar.arb`.
class JeeberUnregisteredView extends StatelessWidget {
  const JeeberUnregisteredView({
    super.key,
    required this.onRegister,
    this.profileName,
    this.ctaIdentifier,
  });

  static const Key rootKey = Key('jeeber-unregistered-view-root');
  static const Key registerButtonKey =
      Key('jeeber-unregistered-view-register');

  /// Tapped when the Jeeber taps the primary "Register now" CTA.
  final VoidCallback onRegister;

  /// Optional profile display name passed through to the greeting.
  final String? profileName;

  /// JM-036: optional additional Semantics identifier wrapped around the
  /// "Register now" CTA, in addition to the W0 `jeeber_unregistered_register_button`.
  /// The DELIVERY-tab gate (`dashboard_tab.dart`) passes `delivery_register_now_cta`
  /// (65_W2_TEST_PLAN §2) so the JM-036 flow can tap the prompt's CTA by its
  /// coined screen id while screen-19's flow keeps using the widget id. Null
  /// for non-gate callers (e.g. the dev-seam capture path) — the CTA then
  /// carries only the W0 id.
  final String? ctaIdentifier;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: rootKey,
      container: true,
      // explicitChildNodes makes this identified container a NON-merging
      // boundary so the nested `jeeber_unregistered_register_button` (and any
      // other identified descendant) surfaces as its own queryable
      // SemanticsNode instead of being folded into the root. Without it,
      // `container: true` still merges the subtree's semantics into this node
      // and the CTA identifier is swallowed (CAP-3 / same pattern as 8b81dc1
      // fixed for screens 16/17/22/26/27).
      explicitChildNodes: true,
      identifier: 'jeeber_unregistered_root',
      child: SafeArea(
        child: Column(
          children: [
            JeeberHomeGreeting(name: profileName),
            const Expanded(child: _UnregisteredHero()),
            _UnregisteredCta(
              onRegister: onRegister,
              extraIdentifier: ctaIdentifier,
            ),
            const SizedBox(height: Spacing.large),
          ],
        ),
      ),
    );
  }
}

class _UnregisteredHero extends StatelessWidget {
  const _UnregisteredHero();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsEmptyState(
      illustration: const _UnregisteredIllustration(),
      title: l10n.jeeberRegisterTitle,
      subtitle: l10n.jeeberRegisterSubtitle,
    );
  }
}

class _UnregisteredIllustration extends StatelessWidget {
  const _UnregisteredIllustration();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.jeeberRegisterHeroSemantic,
      image: true,
      child: const _UnregisteredIllustrationArt(),
    );
  }
}

class _UnregisteredIllustrationArt extends StatelessWidget {
  const _UnregisteredIllustrationArt();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: Sizes.twoHundredLarge,
      height: Sizes.twoHundredLarge,
      decoration: BoxDecoration(
        // Accent PAINT + its own tint halo, not a container fill — same
        // #D73B00 as before the palette fix.
        color: colorScheme.tertiary.withValues(
          alpha: UIConstants.opacityPrimaryLight,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.delivery_dining,
        size: Sizes.elevenXLarge,
        color: colorScheme.tertiary,
      ),
    );
  }
}

class _UnregisteredCta extends StatelessWidget {
  const _UnregisteredCta({required this.onRegister, this.extraIdentifier});

  final VoidCallback onRegister;

  /// JM-036: when set, the CTA is additionally wrapped in a Semantics node
  /// carrying this identifier (`delivery_register_now_cta`) so the DELIVERY-tab
  /// gate flow can tap the same button by the coined screen id. The inner
  /// `jeeber_unregistered_register_button` node stays queryable because the
  /// root view sets `explicitChildNodes: true`.
  final String? extraIdentifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget cta = Semantics(
      identifier: 'jeeber_unregistered_register_button',
      button: true,
      child: OmdsPrimaryButton(
        key: JeeberUnregisteredView.registerButtonKey,
        text: l10n.jeeberRegisterCta,
        onTap: onRegister,
      ),
    );
    final extraId = extraIdentifier;
    if (extraId != null) {
      cta = Semantics(
        identifier: extraId,
        button: true,
        explicitChildNodes: true,
        child: cta,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
      child: cta,
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
// test/previews/jeeber_home/jeeber_unregistered_view_preview_test.dart
// ===========================================================================
//
// Widget previews for [JeeberUnregisteredView] — run with
// `flutter widget-preview start`.
//
// This is State 1 of the Jeeber home (Figma 56614:18920): the upsell a user
// sees on the DELIVERY tab before they have registered as a delivery man. Its
// whole input surface is three values — `onRegister`, `profileName`,
// `ctaIdentifier` — and every string comes from the ARB. There is no cubit and
// no repository to seed: [JeeberHomeGreeting] *looks* for an ambient
// `GreetingProfileCubit` but falls back to the threaded name when none is
// mounted, and no provider is mounted here. These previews are network-free
// because there is nothing to fetch, not merely because [jeebPreviewHost]
// guards them.
//
// What varies between states is therefore the **name** and the **box**, and
// the box is the half that breaks. The view is
// `SafeArea > Column[greeting, Expanded(hero), CTA, 20pt gap]` with no scroll
// view anywhere, and the hero it puts in that [Expanded] is an
// [OmdsEmptyState] whose illustration is a hard-coded 200×200 circle plus 24pt
// of padding a side. That subtree cannot shrink: hand the [Expanded] less than
// its content and the inner [Column] paints the overflow stripe and clips.
//
// The arithmetic, measured rather than guessed: the greeting takes 48pt, the
// CTA a hard-coded 48pt and the trailing gap 20pt, so the hero is handed
// `height − 116`. Its own minimum is `296 + title + subtitle` — 380pt at 390pt
// wide, 412pt at 320pt wide, where the headline needs a third line. The view
// therefore needs a body of about **496pt** (390pt wide) or **528pt** (320pt
// wide) before anything clips, and every pt of that floor is spent by the
// illustration.
//
// Height comes from the annotation `size` only — never baked into the tree —
// following the precedent in `gps_denied_state_preview.dart`: a short height
// compiled into the widget would make the render suite throw on every run
// instead of on the case under review. Width IS baked where the state is about
// a narrow device, because a 320pt phone is a real device and a state that is
// only compact in the canvas is not a state.
//
// Every state carries a different profile name on purpose. The rest of the
// copy — headline, subtitle, CTA — is identical in all five, so the greeting
// line is the only thing that can prove a preview rendered ITS OWN state
// rather than the previous one; the render suite pins exactly that.

/// The slot the DELIVERY tab hands this view on a modern phone: full body
/// height once the status bar and the bottom nav are gone.
const Size _jeeberUnregisteredViewPhoneBody = Size(390, 680);

/// The narrowest device the app still supports, same generous height.
const Size _jeeberUnregisteredViewCompactPhone = Size(320, 600);

/// A short body — a small phone in a locale with a tall system font, or any
/// host that keeps chrome above and below. This is the box the view does not
/// fit.
const Size _jeeberUnregisteredViewShortBody = Size(390, 420);

/// One state: the view with a name, optionally the JM-036 gate identifier, and
/// optionally a baked device width.
///
/// `onRegister` is a no-op — the production callback pushes the delivery-man
/// onboarding route, and a preview has no router. Nothing else is stubbed:
/// this is the production widget with production copy.
Widget _jeeberUnregisteredViewHosted({
  String? profileName,
  String? ctaIdentifier,
  double? width,
}) {
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
@JeebPreview(
  group: 'jeeber_home',
  name: 'Cold start · no name',
  size: _jeeberUnregisteredViewPhoneBody,
)
Widget jeeberUnregisteredViewColdStart() => _jeeberUnregisteredViewHosted();

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
@JeebPreview(
  group: 'jeeber_home',
  name: 'Named jeeber',
  size: _jeeberUnregisteredViewPhoneBody,
)
Widget jeeberUnregisteredViewNamed() =>
    _jeeberUnregisteredViewHosted(profileName: 'Kamal');

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
@JeebPreview(
  group: 'jeeber_home',
  name: 'JM-036 gate CTA id',
  size: _jeeberUnregisteredViewPhoneBody,
)
Widget jeeberUnregisteredViewGateCta() => _jeeberUnregisteredViewHosted(
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
@JeebPreview(
  group: 'jeeber_home',
  name: 'Long name · 320pt phone',
  size: _jeeberUnregisteredViewCompactPhone,
)
Widget jeeberUnregisteredViewLongNameCompact() => _jeeberUnregisteredViewHosted(
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
@JeebPreview(
  group: 'jeeber_home',
  name: 'Short body (420pt)',
  size: _jeeberUnregisteredViewShortBody,
)
Widget jeeberUnregisteredViewShortBody() =>
    _jeeberUnregisteredViewHosted(profileName: 'Nour');
