# Apply report — screen 15 · Mutual rating (`15-mutual-rating`)

**Status: applied** (the full §4 task list landed). One hard dependency remains open and is by
design: the screen does not compile until the `l10n` block of
`docs/redesign-2026-08/wiring/15-mutual-rating.md` is applied — the same pattern screen 11 shipped.

## Files

- edited: `lib/features/rating/presentation/mutual_rating_screen.dart`
- created: `test/features/rating/mutual_rating_redesign_test.dart`
- created: `docs/redesign-2026-08/wiring/15-mutual-rating.md`

No new files under `lib/features/rating/presentation/widgets/` — every §2 fallback that would have
needed one (the Ø74 avatar + completed badge) is satisfied by the shipped kit.

## Kit consumed (no hand-rolled copies)

`JeebAvatar.hero` + `JeebAvatarBadge.completed` · `JeebSectionLabel` · `JeebSelectChip`
(`JeebChipRole.inlineAction`) · `JeebInfoNote.outlined` · `JeebCtaFooter.single` ·
`JeebCtaButton.primary` (`isEnabled`).

Requests **A, B and C** of the instruction set's §7 were written when `lib/core/widgets/jeeb/` was
empty; all three are **already shipped** in the Wave-1 kit (verified file/line in the wiring doc), so
no kit change is requested for them and no interim fallback is compiled in. Request **D**
(`JeebStarInput`) is the one real gap and is the only kit request emitted; the screen ships the
sanctioned `OmdsStarRating` fallback.

## What changed, against the §4 task list

1. **Wiring file written first** — route (`?name=`), l10n (10 new keys + 2 value edits + the
   `app_localizations.dart` `_get` getters), the `JeebStarInput` + jm-034 kit request, and a
   deferred note for `chat_detail_screen.dart` (no change requested).
2. **`rateeName` field added** — `const MutualRatingScreen({super.key, this.rateeName = ''})`,
   constructor before field. The `''` default keeps `const MutualRatingScreen()` valid at
   `app_router.dart:1460`, `batch_09_entries.dart:365` and all four existing tests. Threaded to
   `_InputView` → `_InputScrollArea` via constructor params.
3. **App bar deleted** — only the `appBar: OMDSAppBar(...)` argument. The D56 spine
   (`BackButtonListener` → `PopScope(canPop: false)` → `Scaffold` → `Semantics('rating_root')` →
   `BlocConsumer`) is otherwise unchanged, plus one comment line recording why the removal is
   D56-safe. `l10n.mutualRatingTitle` stays alive for `rating_screen.dart:135`.
   The now-unused `final l10n` local in `build` was removed (it existed only for the app-bar title).
4. **`_InputScrollArea` rebuilt** to the §3 tree with
   `EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.medium, Spacing.xLarge, Spacing.xLarge)`
   and the §3 gaps, every `SizedBox` const.
5. **`_RatingHeadline`** (new) — `jeebText.h2`, start-aligned, named → role-aware fallback read from
   the cubit's public `isClient`.
6. **`_RateeIdentity`** (new) — `JeebAvatar.hero(badge: completed)`, centred. The kit avatar emits
   the `Semantics(identifier: 'mutual_rating_ratee_avatar', label:, image: true)` node itself, so no
   second wrapper was added (that would have doubled the node). The recap-line TODO sits directly
   above it.
7. **`_StarSection` restyled** — `OmdsStarRating(starSize: Sizes.threeXLarge, spacing:
   Spacing.xSmall, inactiveColor: colorScheme.surfaceContainerHighest)`, centred, `activeColor`
   deliberately not passed. The frozen `Semantics('mutual_rating_stars', container: true)` wrapper
   and `Key('mutualRating.stars')` survive; the hardcoded English a11y label is now
   `l10n.mutualRatingStarsA11yLabel(stars)`.
8. **`_StarVerdict`** (new) — `SizedBox.shrink()` at 0, else `bodySmall` + `w700`, centred, driven by
   `state.stars`; `_starVerdict` is a pure switch with a safe default.
9. **Tags** — `JeebSectionLabel(l10n.mutualRatingTagsLabel)` (default size, not `small`) replaces the
   bare `Text`; `runSpacing: Spacing.xSmall` added to the `Wrap`; `spacing`, `textDirection`, the
   JEBV4-296 comment and `kMutualRatingTags` order untouched. `_TagChip` now wraps
   `JeebSelectChip(role: JeebChipRole.inlineAction)` inside the existing frozen
   `Semantics('mutual_rating_tag_<key>', container/button/selected)` node — no identifier passed to
   the kit chip.
10. **`_CommentField` restyled** — `fillColor: colorScheme.surfaceContainerHigh`,
    `borderRadius: Sizes.medium`, `minLines: 3`, `maxLines: 4`; `maxLength: 500` replaced by
    `inputFormatters: [LengthLimitingTextInputFormatter(_commentMaxLength)]` (same 500 cap, no
    `0/500` counter). `LengthLimitingTextInputFormatter` is **not** a const constructor, so the list
    is non-const — the only deviation from the literal instruction text.
11. **Footer** — `JeebCtaFooter.single` + `JeebCtaButton.primary(isEnabled: stars > 0)`, keeping the
    `Semantics('rating_submit_cta', container: true)` wrapper, `Key('mutualRating.submit')` and the
    existing `submit()` tap.
12. **`_BlindRevealNote`** (new, last child) — `JeebInfoNote.outlined(icon: Icons.visibility, ...)`
    inside `Semantics('mutual_rating_blind_note', container: true)`. **`Icons.visibility` (filled),
    not `visibility_outlined`** — R10 says filled glyphs and the HTML's eye path is solid; the
    instruction called the outlined form merely "acceptable". Body is
    `mutualRatingBlindNoteNamed(name)` when a name arrived, else the reused `mutualRatingSubtitle`.
13. **New tests** — `test/features/rating/mutual_rating_redesign_test.dart`: verdict mapping
    (0/1..5/EN+AR), headline fallback (both roles, named, `{name}` never leaks, AR + Latin name),
    the two new ids in both locales, and an `ar` smoke that re-asserts all five frozen ids, the
    three frozen `Key`s and the D56 absences.

## Frozen contracts — all intact

`rating_root` · `mutual_rating_stars` · `mutual_rating_comment` · `mutual_rating_tag_<wire-key>` ×5 ·
`rating_submit_cta`; `Key('mutualRating.stars'|'.comment'|'.submit')`. Still absent:
`rating_skip_cta`, `rating_close_cta`, `BackButton`/`CloseButton`, the literal `Skip`.
`kMutualRatingTags` keys/labels/order unchanged. New ids added: `mutual_rating_ratee_avatar`,
`mutual_rating_blind_note`.

## Gates

| Gate | Result |
| --- | --- |
| `dart analyze lib/features/rating test/features/rating` | **10 issues, all `undefined_getter`/`undefined_method` on `AppLocalizations`** — exactly the 10 keys in the wiring `l10n` block. Zero other errors, zero warnings, zero lints. |
| design-token patterns (all 12 from `tool/check_design_tokens.sh`) run against the edited file | **0 hits** |
| `flutter test test/features/rating …` | **NOT RUN — cannot compile.** The 10 undefined `AppLocalizations` members block the whole `lib/features/rating` library until the integrator applies the l10n block. |

### `mutual_rating_tag_chips_l10n_test` (pre-existing red, `_BASELINE.md`)

Its failure mode is a tap whose target clips below the 800×600 viewport. The redesign moves the tag
chips **up**, from last-but-one to roughly y≈275 in the scroll column (headline 28 + 20 + avatar 74 +
20 + stars 40 + 8 + verdict 0 at 0 stars + 24 + label 16 + 12), well inside the ~512px the scroll
area gets. It is therefore **expected to turn green incidentally** — but this is a layout estimate,
**not a measured result**: the test cannot run until the l10n wiring lands. The integrator must
re-check it; if it stays red after the reorder, the layout is wrong, not the test.

## Deferred / not done

- The render's recap line (`Medicine · delivered in 38 mins · $8`) — no data source exists on
  `MutualRatingState`, `RatingRepository` or `RatingStatus`. Omitted with a `TODO(redesign-24)`,
  not faked and not smuggled through query params.
- Filled grey empty star + per-star ids — `JeebStarInput` wiring request; `OmdsStarRating` draws
  `Icons.star_border` until then, and jm-034's two coordinate taps stay as they are (Maestro is not
  in CI, and `.maestro/*` is outside this lane).
