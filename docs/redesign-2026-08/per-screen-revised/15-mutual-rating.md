# 15 · Mutual rating — REVISED instruction set (authoritative)

**Screen id:** `15-mutual-rating`
**File you own:** `lib/features/rating/presentation/mutual_rating_screen.dart` (353 LOC today)
plus new files under `lib/features/rating/presentation/widgets/` and your tests under
`test/features/rating/`.
**Verdict:** rebuild of the input view. Same cubit, same route, same three controls. No data-layer
change, no cubit change, no state change.

Reviewer verification status: every `file:line` in the original proposal was checked against the
tree. The design evidence (HTML/render/note) is accurate. Corrections and cuts are listed at the
bottom (§9) — the tasks below already have them applied. **Follow this document, not the original
proposal, where they differ.**

---

## 1. Guardrails — read before writing a line

### 1.1 Frozen Semantics identifiers (all five survive, spelled identically)

| Identifier | Today at | Pinned by |
|---|---|---|
| `rating_root` | `:58` | `test/decision_violations_test.dart` (~:111), `test/qa_keys_batch_test.dart` (~:222), maestro jm-034 AC4 |
| `mutual_rating_stars` | `:161` | `qa_keys_batch_test.dart` (~:228) |
| `mutual_rating_comment` | `:182` | `qa_keys_batch_test.dart` (~:233) |
| `mutual_rating_tag_<wire-key>` ×5 | `:301` | tag-chips l10n test taps by label, reads the wire key |
| `rating_submit_cta` | `:328` | `qa_keys_batch_test.dart` (~:238), maestro AC1/AC2/AC3 |

Also frozen: the three widget `Key`s `mutualRating.stars` / `mutualRating.comment` /
`mutualRating.submit` (`qa_keys_batch_test.dart` asserts all three).

Must remain **absent**: `rating_skip_cta`, `rating_close_cta`, any `BackButton`/`CloseButton`,
and the literal text `Skip` in any locale's copy (`decision_violations_test.dart` uses
`find.text('Skip')`). None of the new copy in §5 contains it — keep it that way.

New identifiers are **additive only**: `mutual_rating_ratee_avatar`, `mutual_rating_blind_note`,
and (only if `JeebStarInput` lands) `mutual_rating_star_1`…`_5`.

### 1.2 Locked decisions

- **D56**: the `BackButtonListener` → `PopScope(canPop: false)` → `Scaffold` →
  `Semantics('rating_root')` → `BlocConsumer` spine at `:48-73` stays **byte-for-byte** (only the
  `appBar:` line inside it is removed). It is pinned by
  `test/features/rating/mutual_rating_back_suppression_test.dart` and
  `decision_violations_test.dart`. Deleting the app bar is D56-safe: there was never a leading
  control.
- **JEBV4-297**: `kMutualRatingTags` (`:219-225`) — do not touch keys, labels, or **order**. The
  wire-contract test (`test/features/rating/mutual_rating_tag_wire_contract_test.dart`) pins it and
  the gateway 400s on anything else. The render's chip order is a `flex-wrap` artefact; do not
  reorder the const list.
- **JEBV4-296**: keep `Wrap(textDirection: Directionality.of(context))` at `:270` AND its
  explanatory comment at `:263-267`. The only change to that `Wrap` is adding
  `runSpacing: Spacing.xSmall`.
- **No fabrication**: the render's recap line (`Medicine · delivered in 38 mins · $8`) has no data
  source (`MutualRatingState`, `RatingRepository`, `RatingStatus` carry none of it — verified).
  Omit it with the TODO in §4 step 6. Do **not** pass money or duration through the query string.

### 1.3 Ownership

You may edit only `lib/features/rating/**` and `test/features/rating/**` (plus
`test/mutual_rating_cubit_test.dart` if a compile fix is ever needed — none is expected; no cubit
change). Everything else is a wiring request (§7):
`lib/core/router/app_router.dart`, `lib/l10n/*.arb`, `lib/core/widgets/jeeb/*`,
`lib/features/deep_link_targets/*`, `lib/devtool/*`, `.maestro/*`.

### 1.4 Test-harness trap (affects every kit widget you consume)

All four widget tests that pump this screen build `ThemeData.light()` — NOT `AppTheme.light()`
(`test/support/sync_app_localizations.dart:42`, `mutual_rating_back_suppression_test.dart:75`,
`qa_keys_batch_test.dart`'s own `_harness`). `context.jeebText` and `context.jeebRoles` fall back
safely (verified: `jeeb_text_styles.dart` ~:211, `jeeb_color_roles.dart` ~:268), but
`JeebSemanticColors` documents bang-access and has **no safe accessor**. Therefore: in this
screen's own code use `colorScheme.*` inks only (periwinkle = `colorScheme.onSecondaryContainer`,
verified `#777FC0` in `app_theme.dart:140`). The kit-lane request in §7 carries the null-safe-read
requirement for the kit widgets.

---

## 2. Kit dependencies and their fallbacks

`lib/core/widgets/jeeb/` **does not exist yet** — the Wave-1 kit lane owns it. Sequence this screen
after kit steps 1–4 land. Consume, never fork; `tool/check_design_tokens.sh` bans `fontSize:`, hex,
and raw `BorderRadius.circular(N)` in `lib/features`, so design-exact px legally live only in the
kit.

| Need | Kit | If the kit lane refuses the gap |
|---|---|---|
| Section label 13/w700/ls1.2/uppercase periwinkle | `JeebSectionLabel` (#10, default 12.5 — plan says 13 on this screen is the same token; do NOT pass the `small` flag) | none needed — #10 is already specced |
| Chips: selected navy/white, unselected 1.5px outline + navy ink, pad 9/15, 13/w600 | `JeebSelectChip(role: JeebChipRole.inlineAction)` (#6) | none needed — #6 is already specced |
| Docked CTA: h56 navy pill, 17/w600 white, `JeebShadows.ctaNavy`, pad 0/24/32 | `JeebCtaFooter.single` + `JeebCtaButton.primary` (#2) — **needs `isEnabled`** (gap, §7 request C) | keep `Padding(EdgeInsets.all(Spacing.large))` + `OmdsPrimaryButton` unchanged, TODO(redesign-24) |
| Blind-reveal note: white, 1.5px `colorScheme.outline` border, r16, pad 12/16, gap 11, 18px eye glyph, 12.5/w500/lh18 muted ink | `JeebInfoNote` with an `outlined` tone (gap, §7 request A) | use tone `muted` (surfaceContainerHigh fill) — accepted interim divergence; never hand-roll the px |
| Ø74 avatar + Ø26 orange completed badge | `JeebAvatar.hero` + `badge: JeebAvatarBadge.completed` (gap, §7 request B) | screen-local widget (§4 step 6 fallback): Ø `Sizes.sevenXLarge` (72, verified) disc `colorScheme.primary`, initial `context.jeebText.h1` + `FontWeight.w800`, badge Ø `Sizes.xLarge` (24≈26) `context.jeebRoles.accent` with `Icons.check` white `Sizes.small`; token-legal, ~2px off |
| Star row: 5 filled ★ 38px, gap 10, empty star FILLED grey | `JeebStarInput` (new kit widget, §7 request D) | `OmdsStarRating(starSize: Sizes.threeXLarge, spacing: Spacing.xSmall, inactiveColor: colorScheme.surfaceContainerHighest)` — params verified in OMDS source; accepts the outline empty-star divergence (`Icons.star_border`) |

Star active colour: **never pass `activeColor`**. `OmdsColorTokens.starRatingColor` is already
`#FFC107` app-wide (verified `lib/app/app.dart:623`). The plan (§ token bridge, line 190) names 15
as one of only 3 screens where the yellow star is correct.

---

## 3. Target structure

`MutualRatingScreen.build` unchanged except: delete the `appBar:` argument (`:51-54`) and add the
`rateeName` field (§4 step 2). `_InputView` keeps `SafeArea → Column → Expanded(_InputScrollArea) +
footer`. **No `Spacer()`/`IntrinsicHeight` in the scroll column** — the HTML `flex:1` emptiness is
delivered by `Expanded` + docked footer on tall phones, and a Spacer would overflow the 800×600
widget tests. The bottom ~40% being empty is the design (R1); do not fill it.

```
_InputScrollArea  — SingleChildScrollView(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        Spacing.xLarge, Spacing.medium, Spacing.xLarge, Spacing.xLarge))
  Column(crossAxisAlignment: CrossAxisAlignment.stretch)
    _RatingHeadline                    NEW   start-aligned
    SizedBox(Spacing.large)                  // 20 ≈ HTML 22
    _RateeIdentity                     NEW   centred
    SizedBox(Spacing.large)                  // 20 ≈ HTML 18
    _StarSection                       MOVED UP, restyled
    SizedBox(Spacing.xSmall)                 // 8 = HTML 8
    _StarVerdict                       NEW
    SizedBox(Spacing.xLarge)                 // 24 = HTML 24
    JeebSectionLabel(tags label)       replaces bare Text at :258-261
    SizedBox(Spacing.small)                  // 12 = HTML 12
    _TagsSection                       MOVED UP (was last)
    SizedBox(Spacing.large)                  // 20 ≈ HTML 18
    _CommentField                      MOVED DOWN, restyled
    SizedBox(Spacing.large)                  // 20 ≈ HTML 18
    JeebInfoNote(blind-reveal)         NEW
```

The top subtitle `Text(l10n.mutualRatingSubtitle)` at `:135-138` is deleted; its string returns as
the info note's unnamed fallback body.

---

## 4. Tasks, in execution order

1. **Write the wiring file first.** Create
   `docs/redesign-2026-08/wiring/15-mutual-rating.md` with the six blocks in §7 verbatim. Then
   write all screen code as if requests A–D and the route/l10n requests are granted, with the §2
   fallbacks compiled-in only where a request is marked refusable.

2. **Add the `rateeName` field.**
   `const MutualRatingScreen({super.key, this.rateeName = ''});` + `final String rateeName;`
   (constructor before fields — `sort_constructors_first`). The `''` default keeps
   `const MutualRatingScreen()` valid for: the router builder (until wiring lands), 4 existing
   tests, and `lib/devtool/catalog/entries/batch_09_entries.dart:365`. Thread it down to
   `_InputView`/`_InputScrollArea` via constructor params (match the existing `state:` pattern).

3. **Delete the app bar.** Remove `appBar: OMDSAppBar(...)` at `:51-54` only. Touch nothing else
   in `build`. `l10n.mutualRatingTitle` remains in use by `rating_screen.dart:135` — do not delete
   the key.

4. **Rebuild `_InputScrollArea`** to the §3 tree: new padding
   (`EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.medium, Spacing.xLarge, Spacing.xLarge)`
   replaces `EdgeInsets.all(Spacing.large)` at `:131`), new child order, §3 gaps, all `SizedBox`es
   `const`.

5. **`_RatingHeadline`** (new, private, in-file). `Text(headline, style: context.jeebText.h2)`,
   ink default (`onSurface` via theme), start-aligned. Headline resolution:
   `rateeName.isNotEmpty ? l10n.mutualRatingHeadlineNamed(rateeName) : (isClient ?
   l10n.mutualRatingHeadlineJeeber : l10n.mutualRatingHeadlineClient)`. Get `isClient` from the
   cubit — it is a public final (`mutual_rating_cubit.dart:26`); read it once in `build` with
   `context.read<MutualRatingCubit>().isClient` (a final local — `prefer_final_locals`). A plain
   `Text` is bidi-correct for a Latin name inside an Arabic sentence; do not use
   `MixedDirectionText` (that is for name-only lines).

6. **`_RateeIdentity`.** Preferred: `JeebAvatar.hero` + `badge: JeebAvatarBadge.completed`
   (request B). Fallback (only if B refused): new file
   `lib/features/rating/presentation/widgets/mutual_rating_ratee_identity.dart` per §2. Either way:
   - initial derived like `FeedbackAvatar._initial`
     (`lib/features/rating/presentation/widgets/feedback_avatar.dart:19-22`): trimmed first
     character uppercased, `?` when empty;
   - badge positioned with `Stack` + `PositionedDirectional(end: -4, bottom: -4)` (RTL mirror);
   - wrap in `Semantics(identifier: 'mutual_rating_ratee_avatar', image: true, label: <name or
     localized fallback>)`;
   - the badge is a **completion** mark, never "verified" — on the `?mode=jeeber` leg the ratee is
     a customer with no KYC;
   - directly below the avatar, add the recap TODO where the render's recap line would sit:
     ```dart
     // TODO(redesign-24): recap line (item · duration · fare) needs a delivery
     // summary on the rating surface — omitted, not faked.
     ```

7. **Restyle `_StarSection`** (`:151-171`). Preferred: `JeebStarInput` (request D) with
   `identifierPrefix: 'mutual_rating_star'`; then add `explicitChildNodes: true` to the existing
   outer `Semantics` so the per-star ids are not swallowed. Fallback: keep `OmdsStarRating` with
   the §2 params. Both paths: keep the outer
   `Semantics(identifier: 'mutual_rating_stars', container: true)` wrapper and
   `Key('mutualRating.stars')`; centre the row; replace the hardcoded label at `:163` with
   `l10n.mutualRatingStarsA11yLabel(stars)`.

8. **`_StarVerdict`** (new, private, in-file). When `stars == 0` return
   `const SizedBox.shrink()`; otherwise
   `Text(_starVerdict(l10n, stars), textAlign: TextAlign.center, style:
   context.jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700))`. `_starVerdict` is a pure
   switch mirroring the `_tagLabel` idiom at `:231-246`, mapping 1..5 →
   `mutualRatingStarLabel1..5`. No cubit/state change — driven by `state.stars`.

9. **Tags block.** Replace the bare `Text(l10n.mutualRatingTagsLabel, labelMedium)` at `:258-261`
   with `JeebSectionLabel(l10n.mutualRatingTagsLabel)` (default size — NOT `small`). In the `Wrap`
   add `runSpacing: Spacing.xSmall` only; keep `spacing`, `textDirection`, the JEBV4-296 comment,
   and the map order. In `_TagChip`, swap `OmdsChip` for
   `JeebSelectChip(role: JeebChipRole.inlineAction, ...)`, keeping the existing outer
   `Semantics(identifier: 'mutual_rating_tag_${tag.key}', container: true, button: true,
   selected: selected)` wrapper and passing no identifier to the kit chip (avoids a double node and
   preserves `selected:` which the kit wrapper does not carry).

10. **Restyle `_CommentField`** (`:173-194`). Keep the `Semantics(identifier:
    'mutual_rating_comment', textField: true, label: l10n.ratingCommentHint)` wrapper and
    `Key('mutualRating.comment')`. On the `OmdsTextField` (params verified in OMDS source):
    `fillColor: colorScheme.surfaceContainerHigh`, `borderRadius: Sizes.medium`, `minLines: 3`,
    keep `maxLines: 4`, **replace** `maxLength: 500` with
    `inputFormatters: [LengthLimitingTextInputFormatter(500)]`
    (import `package:flutter/services.dart`) — same cap, no `0/500` counter chrome (the render has
    none).

11. **Footer.** Replace the `Padding` + `OmdsPrimaryButton` at `:322-336` with
    `JeebCtaFooter.single` wrapping `JeebCtaButton.primary(isEnabled: stars > 0, ...)` (request C).
    Keep the `Semantics(identifier: 'rating_submit_cta', container: true)` wrapper — no
    `button: true`, the role comes from the button — and `Key('mutualRating.submit')` and the
    existing `onTap: () => context.read<MutualRatingCubit>().submit()`. If C is refused, leave
    `_SubmitButton` byte-for-byte with a TODO(redesign-24).

12. **`JeebInfoNote`** (blind-reveal, last child). Tone `outlined` (request A; `muted` if refused).
    Body: `rateeName.isNotEmpty ? l10n.mutualRatingBlindNoteNamed(rateeName) :
    l10n.mutualRatingSubtitle`. Leading: eye glyph (`Icons.visibility_outlined` is acceptable if
    the kit takes an `IconData`). Wrap in
    `Semantics(identifier: 'mutual_rating_blind_note', container: true)`.

13. **New tests** (additive, in `test/features/rating/`):
    a. verdict mapping — 0 stars renders no verdict text; 4 stars renders `Great` (EN) and `رائع`
       (AR);
    b. headline fallback — `rateeName: ''` with client and jeeber cubits renders the role-aware
       question, and a named build renders the name with no literal `{name}`;
    c. `mutual_rating_blind_note` id surfaces in both locales;
    d. an `ar` smoke — pump, no exceptions/overflow, the five frozen ids still found.
    Use the existing `wrapForTest`/cubit-injection patterns from the sibling rating tests.

14. **Verify.**
    - `flutter analyze` — no NEW errors/warnings vs the 11-issue baseline;
    - `flutter test test/features/rating test/decision_violations_test.dart
      test/qa_keys_batch_test.dart test/core/router/integration_wiring_test.dart
      test/core/router/back_nav_all_routes_test.dart test/mutual_rating_cubit_test.dart`;
    - `test/features/rating/mutual_rating_tag_chips_l10n_test.dart` is a **pre-existing red**
      (listed in `_BASELINE.md`; the tap-offset clips below the 800×600 viewport). The reorder is
      expected to turn it green incidentally. Report its before/after state explicitly either way —
      if it stays red after the reorder, the layout is wrong, not the test;
    - `tool/check_design_tokens.sh` clean for the touched files.

---

## 5. l10n contract (all strings via wiring — none hardcoded)

New keys (exact JSON in §7): `mutualRatingHeadlineNamed{name}`, `mutualRatingHeadlineJeeber`,
`mutualRatingHeadlineClient`, `mutualRatingStarLabel1..5` (Poor/Fair/Okay/Great/Excellent — the
render pins 4 = Great), `mutualRatingBlindNoteNamed{name}`, `mutualRatingStarsA11yLabel{stars}`.

Value edits to existing keys (verified: this screen is the only `lib/` consumer of both):
`mutualRatingTagsLabel` → `What stood out?`; `ratingCommentHint` → `Add a note (optional)…`.
No test asserts the old strings (grepped).

Untouched: `mutualRatingTitle` (still used by `rating_screen.dart:135`), `mutualRatingSubtitle`
(reused as the unnamed info-note body), `mutualRatingSubmit`, `mutualRatingError`, the five
`mutualRatingTag*` labels.

---

## 6. Stop conditions

**Done means:** the input view matches §3 with §2 components; all five frozen ids + three Keys
survive; the new ids exist; every §4.14 command passes at baseline or better; the wiring file
contains exactly the §7 blocks; strings resolve through `AppLocalizations` (code compiles against
the requested getters); RTL (`ar`) renders mirrored without overflow.

**Do NOT touch:**
- the D56 spine `:48-73` (except removing `appBar:`), `_onPhaseChanged`, `_buildBody` — the
  submitting/submitted `OmdsLoadingState` behaviour at `:89-91` stays AS IS (the original
  proposal's §4.5 loading-state idea is CUT — not design-evidenced);
- `MutualRatingCubit`, `MutualRatingState`, `RatingRepository`, `kMutualRatingTags`,
  `MutualRatingTag`, `_tagLabel`'s wire-key switch;
- `lib/core/router/app_router.dart`, `lib/l10n/*.arb`, `lib/core/theme/*`, `pubspec.yaml`,
  `lib/features/deep_link_targets/*`, `lib/features/otp_handover/*`, `lib/devtool/*`,
  `.maestro/*`, anything in `lib/core/widgets/`;
- `rating_screen.dart` and its widgets (legacy `/feedback` surface — another card);
- the route table: `mutual-rating` stays out of `backFallbacks`
  (`test/core/router/back_nav_all_routes_test.dart:80,265` excludes it by design);
- no new dependency, no invented endpoint/field, no recap-line data smuggled via query params.

---

## 7. Wiring requests — paste these into `docs/redesign-2026-08/wiring/15-mutual-rating.md`

### route
file: lib/core/router/app_router.dart
need: the `mutual-rating` builder must forward an optional `?name=` query param, mirroring the sibling `/orders/:id/feedback` route at :1441.
exact change: in the `mutual-rating` GoRoute builder (~:1455-1461), replace `child: const MutualRatingScreen(),` with:
```dart
              child: MutualRatingScreen(
                rateeName: state.uri.queryParameters['name'] ?? '',
              ),
```
why: the redesigned headline ("How was Karim?") and the avatar initial use the counterpart's display name; the screen ships a finished role-aware fallback when the param is absent, so this can land any time.

### l10n
file: lib/l10n/app_en.arb and lib/l10n/app_ar.arb
need: 10 new keys + 2 value edits for the redesigned mutual-rating input view (getter regeneration included; parity gate needs both files in one batch).
exact change — add to app_en.arb:
```json
"mutualRatingHeadlineNamed": "How was {name}?",
"@mutualRatingHeadlineNamed": {"placeholders": {"name": {"type": "String"}}},
"mutualRatingHeadlineJeeber": "How was your Jeeber?",
"mutualRatingHeadlineClient": "How was your customer?",
"mutualRatingStarLabel1": "Poor",
"mutualRatingStarLabel2": "Fair",
"mutualRatingStarLabel3": "Okay",
"mutualRatingStarLabel4": "Great",
"mutualRatingStarLabel5": "Excellent",
"mutualRatingBlindNoteNamed": "{name} rates you too. Both ratings reveal together — neither of you sees the other's first.",
"@mutualRatingBlindNoteNamed": {"placeholders": {"name": {"type": "String"}}},
"mutualRatingStarsA11yLabel": "{stars} of 5 stars selected",
"@mutualRatingStarsA11yLabel": {"placeholders": {"stars": {"type": "int"}}}
```
add to app_ar.arb:
```json
"mutualRatingHeadlineNamed": "كيف كان {name}؟",
"mutualRatingHeadlineJeeber": "كيف كان الجيبر؟",
"mutualRatingHeadlineClient": "كيف كان الزبون؟",
"mutualRatingStarLabel1": "سيئ",
"mutualRatingStarLabel2": "مقبول",
"mutualRatingStarLabel3": "جيد",
"mutualRatingStarLabel4": "رائع",
"mutualRatingStarLabel5": "ممتاز",
"mutualRatingBlindNoteNamed": "{name} يقيّمك أيضًا. يُكشَف التقييمان معًا — لا أحد منكما يرى تقييم الآخر أولًا.",
"mutualRatingStarsA11yLabel": "{stars} من 5 نجوم محددة"
```
value edits (both files): `mutualRatingTagsLabel`: EN `"Quick tags (optional)"` → `"What stood out?"`, AR → `"ما الذي تميّز؟"`; `ratingCommentHint`: EN `"Anything else worth noting?"` → `"Add a note (optional)…"`, AR → `"أضف ملاحظة (اختياري)…"`. Verified: mutual_rating_screen.dart is the only lib/ consumer of both keys and no test asserts the old strings.
why: HTML:15/22/25/33/37 copy; constraint 5 (the stars a11y label at :163 is hardcoded EN today).

### cross-feature
file: lib/core/widgets/jeeb/jeeb_info_note.dart (Wave-1 kit lane)
need: an `outlined` tone on JeebInfoNote (#22): white fill, 1.5px `colorScheme.outline` border, r16, pad 12/16, gap 11, leading 18px glyph, body 12.5/w500/lh18 muted ink.
exact change: add `JeebInfoNoteTone.outlined` (or `bool outlined`) swapping the `muted` fill for the border; typography identical to `muted`. Must read `JeebSemanticColors` null-safely (`?? JeebSemanticColors.light()`) — screen 15's tests pump `ThemeData.light()`.
why: 15's blind-reveal note (HTML:35-38) is outlined, and R7 (outline is the default) suggests more consumers. Screen 15 ships tone `muted` as interim if refused.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_avatar.dart (Wave-1 kit lane)
need: a 4th size `JeebAvatar.hero` (Ø74, initial 26/w800 white on `colorScheme.primary`) and a 3rd badge semantic `JeebAvatarBadge.completed` (Ø26 `jeebRoles.accent` disc, 3px `colorScheme.surface` ring, 13px white check, `PositionedDirectional(end: -4, bottom: -4)`).
exact change: extend the size enum and the dot/badge enum per HTML:17 of screen 15; keep both directional.
why: 15's ratee identity block. Screen 15 falls back to a token-legal Ø72 screen-local widget if refused (2px off-spec).

### cross-feature
file: lib/core/widgets/jeeb/jeeb_cta_button.dart (Wave-1 kit lane)
need: `isEnabled` on `JeebCtaButton` (disabled visual + onTap suppression), matching `OmdsPrimaryButton.isEnabled`.
exact change: `this.isEnabled = true` on the primary variant at minimum.
why: 15's submit gates on `stars > 0` (D56 completeness, also enforced at mutual_rating_cubit.dart:43); without it the screen keeps `OmdsPrimaryButton` and the docked-pill footer diverges from the board.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_star_input.dart (Wave-1 kit lane, NEW widget) and .maestro/flows/jm-034-rating.yaml
need: a star input that matches the board (filled grey empty star — R10) with per-star identifiers; then retire jm-034's two coordinate taps.
exact change: `JeebStarInput`: 5 tappable `Icon(Icons.star)` size 38, gap 10, active `context.omdsColorTokens.starRatingColor`, empty `colorScheme.surfaceContainerHighest`, plain `Row` (auto-mirrors), each star wrapped `Semantics(identifier: '<prefix>_$n', button: true, container: true)`. In jm-034, replace both `point: "38%,21%"` taps (AC2 ~:71, AC3 ~:112) with `tapOn: id: "mutual_rating_star_4"`.
why: `OmdsStarRating` draws `Icons.star_border` (verified in OMDS source) and exposes no per-star id (gap disclosed at feedback_star_input.dart:7-10), which is why jm-034 taps by point; the redesign moves/centres the star row, so both point taps rot silently — Maestro is not in CI.

---

## 8. RTL checklist (all already reflected in the tasks)

- badge: `PositionedDirectional(end: -4, bottom: -4)`;
- scroll padding: `EdgeInsetsDirectional.fromSTEB`;
- star row: plain `Row` — in `ar` star 1 lands right, fill grows leftward; do NOT force
  `TextDirection.ltr`;
- keep `Wrap.textDirection` + JEBV4-296 comment;
- `JeebSectionLabel` uppercases internally; Arabic passes through unchanged;
- headline `Text` handles the mixed-direction name via the bidi algorithm — no special casing;
- no money/digit runs on this screen — one more reason the recap line stays out.

---

## 9. Reviewer changelog (what changed vs the original proposal)

**Cut:**
- §4.5 (keep `_InputView` mounted while submitting) — not on the render; touches phase handling on
  a mandatory terminal for zero design evidence.
- "Callers append `&name=`" at `otp_handover_screen.dart` / `delivery_detail_screen.dart` /
  `app_router.dart:1519` — verified those sites hold no display name; there is nothing to do
  there. The one real holder (`chat_detail_screen.dart` `_counterpartName`, verified :169/:1237/:1375)
  is **deferred** — it is another lane's file, the fallback copy is finished either way, and the
  route request already unblocks any future caller. No wiring block emitted for it; note left here
  for the integrator's discretion.
- Direct edit of `.maestro/flows/jm-034-rating.yaml` — outside ownership; folded into the
  JeebStarInput wiring block.

**Corrected:**
- File paths: chat detail is `lib/features/deep_link_targets/chat_detail_screen.dart` (not
  `lib/features/chat/...`); devtool catalog is `lib/devtool/catalog/entries/batch_09_entries.dart`
  (`const MutualRatingScreen()` at :365); route tests live under `test/core/router/`; cubit test at
  `test/mutual_rating_cubit_test.dart`; the baseline-red l10n test at
  `test/features/rating/mutual_rating_tag_chips_l10n_test.dart`.
- `isEnabled: stars > 0` is at `:333` (not :332); the cubit gate at `mutual_rating_cubit.dart:43`.
- `lib/core/widgets/jeeb/` does not exist yet — ALL five kit consumptions are Wave-1 dependencies,
  not just the three gaps; sequencing made explicit (§2).
- `borderRadius: 16` literal → `Sizes.medium` (token-legal in a feature file).
- Verdict at 0 stars: `SizedBox.shrink()`, not `Text('')` (which still takes a line height).

**Verified true (kept):** every `mutual_rating_screen.dart` line cite; the full HTML measurement
set; the `?name=` precedent at `app_router.dart:1441`; `starRatingColor` #FFC107 at `app.dart:623`;
`OmdsStarRating`/`OmdsTextField` API claims against OMDS source; `Sizes.sevenXLarge = 72`;
`onSecondaryContainer = #777FC0`, `outline = #916F66`, `surfaceContainerHigh/Highest` mappings;
the ThemeData.light() harness trap; the jm-034 point-taps (×2); `_BASELINE.md` listing the
tag-chips test as pre-existing red; both l10n edit keys having no other consumer and no test
asserting old strings; `find.text('Skip')` and the frozen/absent id set; D56/JEBV4-296/297 locks.
