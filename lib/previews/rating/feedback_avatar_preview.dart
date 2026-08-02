/// Widget previews for [FeedbackAvatar] — run with
/// `flutter widget-preview start`.
///
/// [FeedbackAvatar] is a pure [StatelessWidget] over two plain fields
/// (`name`, `avatarUrl`), so every state below is a bare constructor call: no
/// cubit, no repository, nothing to seed. It is network-free by construction,
/// not merely by [jeebPreviewHost]'s guard — see the note on `avatarUrl` below.
///
/// **Why no state passes a real photo URL.** `avatarUrl` is the one field that
/// reaches the network: `OmdsProfileAvatar` hands a non-empty URL to
/// `OmdsCachedImage` → `CachedNetworkImage`, whose shimmer placeholder animates
/// forever under `pumpAndSettle` and whose CDN fetch resolves in neither the
/// canvas nor a test — both end up at the same initials placeholder the `null`
/// states already render, which is the "every preview looks identical" failure
/// `expectedText` exists to catch. It is also moot for this widget in
/// production: the only route that mounts it,
/// `/orders/:id/feedback` (`lib/core/router/app_router.dart:1433`), builds
/// `RatingScreen` with `deliveryId`, `isClient` and `rateeName` **and never
/// passes `rateeAvatarUrl`**, so the shipped feedback screen always renders the
/// initial. Every state here is therefore an initial, which is the widget's
/// real surface area. The photo path is left to the screen goldens.
///
/// Fixture names are the ones already used for this screen elsewhere —
/// 'Rami Chidiac' / 'Layla Haddad' from the Screen Catalog entry
/// (`lib/devtool/catalog/entries/batch_09_entries.dart:395`) — so the previews
/// and the catalog describe the same two people.
///
/// **Measured geometry** (from the render tree, bundled Inter — not eyeballed).
/// The avatar is a fixed 96 dp circle (`Sizes.tenXLarge`) and the initial is
/// drawn at `size / 2.5` = 38.4 dp. That font size is *not* scale-locked, so
/// the glyph grows with the text scaler while the circle does not:
///
/// | rendering | circle | initial line box     |
/// |-----------|--------|----------------------|
/// | 1x        | 96 dp  | 38.7 × 55.0 dp       |
/// | 200% text | 96 dp  | 77.1 × 96.0 dp\*     |
///
/// \* clamped. The unconstrained line box at 200% is 110 dp tall against a
/// 96 dp circle, so `Center` hands the paragraph the 96 dp it has and the glyph
/// paints past the circle's edge — `Container` sets no `clipBehavior`, so the
/// overshoot lands on the page background in the same white the initial is
/// painted in. That is what the **EN 200% text** rendering of every state below
/// is for; it is the one rendering where this widget has a real layout budget.
///
/// **Read the EN light rendering first, and read it for contrast.**
/// `OmdsProfileAvatar` defaults `initialColor` to a hardcoded `Colors.white`
/// and this widget overrides nothing, so the initial is white ink on
/// `colorScheme.primaryContainer`. Since the b02 tone-pair correction that role
/// is the M3 tone-90 #FFDBD1, and white on #FFDBD1 measures **1.29:1** — under
/// the 3:1 WCAG floor for large text, in the theme this screen ships in. The
/// dark scheme's generated #3C4279 measures 9.34:1, so the AR RTL dark
/// rendering looks correct and the defect is visible only in the light one.
/// Pinned in `test/previews/rating/feedback_avatar_preview_test.dart`.
library;

import 'package:flutter/material.dart';

import '../harness/jeeb_preview.dart';
import '../../features/rating/presentation/widgets/feedback_avatar.dart';

/// Phone width, and tall enough to frame the 96 dp circle plus the room the
/// initial takes at 200% text — an overflow stripe in the canvas is a real
/// regression, not a box that was drawn too small.
const Size _avatarBox = Size(390, 160);

/// One specimen. Mirrors the call site at
/// `lib/features/rating/presentation/rating_screen.dart:226`
/// (`FeedbackAvatar(name: data.rateeName, avatarUrl: data.rateeAvatarUrl)`), so
/// a preview cannot drift from how the screen builds it.
Widget _hosted(String name, {String? avatarUrl}) =>
    FeedbackAvatar(name: name, avatarUrl: avatarUrl);

/// The happy path: a named ratee with no photo on file.
///
/// Renders the uppercased first letter on the primary container fill — 'R' for
/// 'Rami Chidiac'. This is what a client sees after a completed delivery, and
/// the only state that looks the way the Figma frame (56614:20132) does. It is
/// also the cleanest place to see the 1.29:1 white-on-#FFDBD1 problem described
/// in the library doc: a full-height letter that is barely there.
@JeebPreview(name: 'Named ratee', size: _avatarBox)
Widget feedbackAvatarNamed() => _hosted('Rami Chidiac');

/// The route default, not an edge case.
///
/// `RatingScreen.rateeName` defaults to `''` and the `/orders/:id/feedback`
/// route fills it from `state.uri.queryParameters['name'] ?? ''`
/// (`app_router.dart:1441`). Nothing in the app pushes that route — it is
/// reached by deep link and by the capture harness — so any link that omits
/// `?name=` lands here: a bare '?' where the person being rated should be,
/// directly above a heading that reads "Rate " with nothing after it.
///
/// This is also the only state that takes the localized branch of the
/// `Semantics` label (`name.isEmpty ? l10n.feedbackScreenTitle : name`), so
/// VoiceOver announces "We appreciate your feedback" / "نقدّر ملاحظاتك" for the
/// image. Check it in **AR RTL dark**: it is the one string in this widget that
/// has to be translated at all.
@JeebPreview(name: 'No name (route default)', size: _avatarBox)
Widget feedbackAvatarNoName() => _hosted('');

/// An Arabic ratee name — the majority case for this app.
///
/// Two things this state proves that the Latin states cannot. `toUpperCase()`
/// is a no-op for Arabic, so the glyph must come through as authored — a lam,
/// not a case-folded substitute — and the initial must be the *first* letter of
/// the name as written, i.e. the rightmost glyph on screen, which is exactly
/// the kind of thing a Latin-only fixture cannot catch. The circle itself is
/// symmetric, so if anything in the **AR RTL dark** rendering moves off centre
/// it is the ambient [Directionality] leaking through `Center`, not the avatar.
@JeebPreview(name: 'Arabic name', size: _avatarBox)
Widget feedbackAvatarArabicName() => _hosted('ليلى حداد');

/// A phone-only account, as `getMe` returns it (sprint-009 §T5).
///
/// Jeeb mints `jeeb-<hash>` display names for OTP-only signups, and this widget
/// passes `name` straight to `OmdsProfileAvatar` without the
/// `displayNameOrNull` suppression that `ClientHomeGreeting` and the offer
/// cards apply. The result is worse than a blank avatar: the circle renders a
/// confident 'J', which reads as a person named something starting with J
/// rather than as "we do not know this user's name". The `?` fallback exists
/// for exactly this case and never fires, because the synthetic handle is a
/// non-empty string.
@JeebPreview(name: 'Phone-only synthetic handle', size: _avatarBox)
Widget feedbackAvatarSyntheticHandle() => _hosted('jeeb-e1a35ea8a520');

/// TRIPWIRE: a name whose first letter is a multi-code-unit grapheme — here the
/// decomposed (NFD) Arabic 'آ', an alef `ا` carrying a maddah `ٓ`,
/// which is what an iOS keyboard produces for 'آمنة'.
///
/// The two halves of this avatar disagree about what "first character" means.
/// [FeedbackAvatar] takes `trimmed.characters.first` — a *grapheme cluster*,
/// both code units — and hands it to `OmdsProfileAvatar`, which re-slices it
/// with `initial[0]`, a *code unit* index (`omds_profile_avatar.dart:135`).
/// The maddah is dropped and the circle shows a bare 'ا': a different letter
/// from the one the person types their name with.
///
/// The same slice is worse than cosmetic one code point up. A name that starts
/// outside the BMP (any emoji — the name arrives unsanitized from a `?name=`
/// query parameter) leaves `initial[0]` holding an unpaired high surrogate, and
/// the engine's paragraph builder throws
/// `ArgumentError: string is not well-formed UTF-16` during layout rather than
/// rendering a replacement box. That state is deliberately NOT previewed here:
/// it does not render at all, in the canvas or anywhere else.
///
/// The fixture spells its first letter as U+0627 + U+0653 instead of pasting
/// the precomposed U+0622, because the whole point of the state is that the
/// grapheme is two code units.
@JeebPreview(name: 'Decomposed first letter', size: _avatarBox)
Widget feedbackAvatarDecomposedName() => _hosted('ا\u0653منة');

/// `avatarUrl: ''` — what the gateway sends for "no photo", as distinct from
/// omitting the field.
///
/// `OmdsProfileAvatar` short-circuits on `profilePicUrl!.isEmpty` before it
/// builds `OmdsCachedImage`, so this renders the initial rather than the grey
/// broken-image placeholder `OmdsCachedImage` shows for an empty URL. That
/// short-circuit is load-bearing here: without it the feedback screen would put
/// a shimmer and a failed fetch where a perfectly good initial belongs, and
/// this preview would be the one that reaches the network.
@JeebPreview(name: 'Empty avatar URL', size: _avatarBox)
Widget feedbackAvatarEmptyUrl() => _hosted('Zeina Karam', avatarUrl: '');
