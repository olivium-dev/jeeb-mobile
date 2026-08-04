# w4-rating — legacy `/feedback` RatingScreen onto the Jeeb design system

**Lane:** w4-rating · **Branch:** `feat/redesign-24-migration` (no branch/commit/push)
**Scope:** `lib/features/rating/` — `presentation/rating_screen.dart` +
`presentation/widgets/feedback_{avatar,header,star_input}.dart` (all only consumed by this screen).
**Reference:** no render exists for this screen. The neighbour render
`screens/15-mutual-rating.png` and the already-redesigned **sibling in the same directory**
(`presentation/mutual_rating_screen.dart`) are the language source. Where a treatment already
shipped on `MutualRatingScreen`, it was copied rather than re-invented — the two rating terminals
now draw the same screen family.

## What the neighbour does (and what this screen did instead)

| Neighbour (15) | This screen, before |
|---|---|
| No app bar — opens with an in-body headline at the 24px gutter | `OMDSAppBar` titled `mutualRatingTitle` (a *different* title from the body's own) |
| Ø74 navy hero disc + Ø26 orange completion mark, centred | Ø96 `OmdsProfileAvatar`, no mark |
| Headline `jeebText.h2`; muted line under the hero | `headlineSmall.copyWith(color: secondaryContainer, w800)` — a **fill role used as text ink**; subtitle on `onSecondaryContainer` = the periwinkle-on-white pairing `color_role_contrast_test` pins as **below AA** |
| Stars → note box → docked CTA, in that order | comment box sat **between** the header and the rating prompt |
| Bare grey note box (`surfaceContainerHigh`, r16), no counter chrome | default-bordered `OmdsTextField` with a `0/1000` counter |
| Docked `JeebCtaFooter` (24/32) + `JeebCtaButton.primary`, disabled until a star is picked | `Padding(all: 20)` + `OmdsLoadingButton`, always enabled but silently no-op at 0 stars |
| 24px gutters, ~28px block rhythm | 20px symmetric gutters, uniform 24px gaps |

## Changes

**`rating_screen.dart`**
- Removed `OMDSAppBar`. It carried `automaticallyImplyLeading: false`, so it held **no affordance**
  — D56 is untouched: still `PopScope(canPop: false)`, still no close/skip/dismiss control. Same
  removal already shipped on `MutualRatingScreen`.
- Footer → `JeebCtaFooter.single` + `JeebCtaButton.primary` (`isLoading` preserved).
  `isEnabled: stars > 0` now *surfaces* the gate `_onSubmit` already enforced silently
  (`if (_stars == 0) return`) — same behaviour, now visible, matching the sibling.
- Scroll padding → `EdgeInsetsDirectional.fromSTEB(24, 16, 24, 24)` (directional, board gutters).
- Block rhythm: 24 between bands, 12 prompt→stars, 32 stars→note.
- Comment field: `fillColor: surfaceContainerHigh`, `borderRadius: Sizes.medium`, `minLines: 3`;
  the 1000-char cap moved from `maxLength:` to `LengthLimitingTextInputFormatter` so the counter
  chrome disappears. **The cap is unchanged** (named `_commentMaxLength`).
- `_FeedbackRateName` → `jeebText.titleProminent`, ambient ink (was `secondaryContainer` as text).
  `MixedDirectionText` kept — it is a name-only line.
- **One reorder:** the comment field moved from *above* the rating prompt to *below* the stars.
  Same elements, same actions, no new/removed steps — a note annotates a score and cannot precede
  it. This is the board's order on 15.

**`widgets/feedback_avatar.dart`** — `OmdsProfileAvatar(Ø96)` → kit `JeebAvatar.hero`
(Ø74 + `JeebAvatarBadge.completed`). The local `_initial` getter was dropped in favour of
`JeebAvatar.initialFrom`, which the kit documents as byte-matching it. The kit avatar is given no
`identifier`/`semanticLabel`, so the existing wrapper stays the single node.

**`widgets/feedback_header.dart`** — start-aligned (board headline alignment); title →
`jeebText.h2` with ambient ink; subtitle → `jeebText.body` on **`onSurfaceVariant`**, the migrated
AA-safe label role, replacing the failing periwinkle `onSecondaryContainer`.

**`widgets/feedback_star_input.dart`** — `spacing: Spacing.xSmall` +
`inactiveColor: surfaceContainerHighest`, byte-matching `MutualRatingScreen._StarSection` so both
terminals draw one star row. Active colour still not passed (app-wide token).

## Constraints held

- **D56** — no close/skip/dismiss anywhere; `PopScope(canPop: false)` intact; the removed app bar
  had no leading. `rating_skip_cta` / `feedback_close_button` still absent (asserted green).
- **Semantics preserved byte-identically** — `rating_root`, `rating_submit_cta`
  (incl. `button: true, container: true, explicitChildNodes: true`), `feedback_ratee_avatar`,
  `feedback_star_rating`, `feedback_comment_field`. No new interactive widgets, so no new ids.
- **No new strings** — every label reuses an existing ARB key. No `l10n.yaml`, no `gen-l10n`.
- **No shared-file edits** — no router, DI, theme, kit or pubspec change ⇒ **no wiring request**.
- **No invented data** — the board's recap line (item · duration · fare) is *not* rendered: neither
  `RatingScreen` nor `RatingRepository` carries a delivery summary. Same refusal the sibling logged.
- **No new functionality** — the board's "What stood out?" tag chips are **not** added here. The
  screen's `submitRating` call passes no `tags`, and adding them would be new product surface plus a
  gateway wire contract, not a re-skin.
- RTL: directional insets only; `Wrap`/`Row` mirroring unchanged.

## Verification

- `dart analyze lib/features/rating` → **No issues found!**
- `flutter test test/feedback_screen_test.dart test/semantics_identifier_surfacing_test.dart
  test/features/rating/ test/decision_violations_test.dart
  test/core/theme/color_role_contrast_test.dart` → **82 pass, 0 fail.**
- Visual check: rendered the reskinned screen at 440×956 (empty + 4-star states) via a throwaway
  golden harness, compared against `screens/15-mutual-rating.png`, then deleted the harness. Band
  structure, hero + orange completion mark, grey note box and the docked navy pill line up with the
  neighbour.

## Known remaining inconsistencies

1. **Stars paint terracotta, not the board's amber `#FFC107`.** `OmdsStarRating` defaults to
   `OmdsColorTokens.starRatingColor`. Four selected stars is a larger orange area than "rationed"
   allows. **Identical on `MutualRatingScreen`** — a token/kit-level issue, not fixable per-screen.
2. **Empty stars are `Icons.star_border`, the board draws filled grey.** OMDS limitation; the
   sibling carries the same `TODO(redesign-24)` awaiting `JeebStarInput`.
3. **No per-star semantics ids** (OMDS renders an un-ided `Row`); the container announces `n / 5`.
4. **No verdict word** under the stars (the board's "Great"), no tag chips, no delivery recap — see
   the refusals above.
5. The subtitle is a two-sentence legacy paragraph where the board wants one short muted line; the
   copy is out of a re-skin's scope.
6. This screen still duplicates `MutualRatingScreen`. It is now visually consistent with it, but the
   real cleanup is retiring `/orders/:id/feedback` in favour of the canonical `/mutual-rate` — a
   routing decision, out of lane.
