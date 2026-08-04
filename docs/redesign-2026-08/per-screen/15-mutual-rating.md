# 15 · Mutual rating — change proposal

**Screen id:** `15-mutual-rating`
**File:** `lib/features/rating/presentation/mutual_rating_screen.dart` (353 LOC, 9 widgets, 5 identifier values)
**Route:** `/orders/:id/mutual-rate` (name `mutual-rating`), `?mode=jeeber` flips audience — `app_router.dart:1448-1462`
**Verdict:** **rebuild** of the input view. Same cubit, same route, same controls — but the app bar is
deleted, four new presentational blocks appear above the fold, the section order changes, and the
footer becomes a docked pill. Nothing about the data layer moves.

Sources read in full: `15-mutual-rating.png`, `15-mutual-rating.html`, `15-mutual-rating.note.md`,
the screen, `mutual_rating_cubit.dart`, `mutual_rating_state.dart`, `rating_repository.dart`,
`rating_status.dart`, the sibling `rating_screen.dart` + its three widgets, and all five tests plus
`.maestro/flows/jm-034-rating.yaml`.

---

## 0. Executive summary

The designer note claims four changes; the render demands seven. The note is right that the blind
mechanic gets one line, that a delivery recap appears, that star labels confirm the tap, and that the
tag taxonomy matches the gateway's five (it already does — `kMutualRatingTags` is the gateway
`JeebRatingVocabulary.AllowedTags` verbatim, and a wire-contract test pins it).

What the note does not say, and the render does:

1. **The `OMDSAppBar` is gone.** The headline is in-body, 20/w700 navy, and it is a *question about a
   person* ("How was Karim?") rather than a screen title ("Rate your experience").
2. **A centred identity block is new** — Ø74 navy avatar + orange completion badge + a recap line.
3. **The section order flips**: tags now sit *above* the note field, not below it.
4. **The submit CTA docks** at the bottom with `JeebShadows.ctaNavy`, with real empty space above it
   (R1) — today the button is glued to the end of a scrolling column.
5. Two things on the render are **not buildable from current state**: the recap line
   (`Medicine · delivered in 38 mins · $8`) and the counterpart's name. The name has a cheap, honest
   plumbing path (the `/feedback` route already carries `?name=`); the recap does not — omit it.

**The one thing that will silently break if nobody reads this:** `.maestro/flows/jm-034-rating.yaml`
taps the 4th star **by point** (`38%,21%`) because OMDS exposes no per-star identifier. This layout
moves the star row to roughly `61%,25%`. Maestro is not in CI, so AC2 and AC3 of jm-034 will rot
silently. §6 proposes per-star identifiers and §8 flags the flow edit.

---

## 1. Layout & structure

### 1.1 What is deleted

| What | Where | Why |
|---|---|---|
| `OMDSAppBar(title: l10n.mutualRatingTitle, automaticallyImplyLeading: false)` | `mutual_rating_screen.dart:51-54` | The render has no app bar. Title is in-body at `padding: 18px 24px 0`, `20/w700` navy (HTML:15). Deleting it is D56-safe — there was never a leading control, and `decision_violations_test.dart:117-118` asserts `BackButton`/`CloseButton` find nothing, which stays true |
| The top subtitle `Text(l10n.mutualRatingSubtitle, style: textTheme.bodyMedium)` | `:135-138` | The blind-reveal explanation moves to the bottom, into an outlined info note with an eye glyph (HTML:35-38). Same idea, different position and shape — the string is reused as a fallback (§4.2) |
| `maxLength: 500` on the comment field | `:189` | `maxLength` renders a `0/500` counter under the field; the render shows none. Keep the cap as `inputFormatters: [LengthLimitingTextInputFormatter(500)]` — behaviour identical, chrome gone |

### 1.2 What is added

| Block | Design evidence |
|---|---|
| `_RatingHeadline` — in-body question, `jeebText.h2`, `colorScheme.onSurface`, start-aligned | HTML:15 `padding:18px 24px 0; font-size:20px; font-weight:700; color:var(--jeeb-navy)` |
| `_RateeIdentity` — centred Ø74 navy disc, initial 26/w800 white, Ø26 `jeebRoles.accent` badge with a 3px white ring and a 13px white check at the bottom-END | HTML:17 |
| Recap line slot — 14/w600 periwinkle, `margin-top:10` | HTML:18. **No data source — omitted with a TODO (§4.3)** |
| `_StarVerdict` — 13/w700 navy word under the stars, `margin-top:8` | HTML:22 `Great`; note: "star labels ('Great') confirm the tap" |
| `JeebInfoNote` (outlined) — eye glyph + the blind-reveal sentence | HTML:35-38 |
| A real docked footer with `flex:1` above it | HTML:39-42 |

### 1.3 The target tree

`MutualRatingScreen.build` (`:24-73`) is **untouched** apart from removing `appBar:`. The
`BackButtonListener` → `PopScope(canPop:false)` → `Scaffold` → `Semantics('rating_root')` →
`BlocConsumer` spine stays byte-for-byte; it is pinned by `mutual_rating_back_suppression_test.dart`
and `decision_violations_test.dart:114-115`.

```
_InputView                                  // :106-121, unchanged shape
  SafeArea
    Column
      Expanded(child: _InputScrollArea)
      _SubmitButton                          // becomes JeebCtaFooter.single

_InputScrollArea                             // :123-149, REORDERED
  SingleChildScrollView(
    padding: EdgeInsetsDirectional.fromSTEB(
      Spacing.xLarge, Spacing.medium, Spacing.xLarge, Spacing.xLarge),   // 24 / 16 / 24 / 24
  )
    Column(crossAxisAlignment: CrossAxisAlignment.stretch)
      _RatingHeadline(name: rateeName, isClient: …)      // NEW
      SizedBox(height: Spacing.large)                    // 20 ≈ HTML 22
      _RateeIdentity(name: rateeName)                    // NEW (centred)
      SizedBox(height: Spacing.large)                    // 20 ≈ HTML 18
      _StarSection(stars: state.stars)                   // MOVED UP + recoloured
      SizedBox(height: Spacing.xSmall)                   // 8  = HTML 8
      _StarVerdict(stars: state.stars)                   // NEW
      SizedBox(height: Spacing.xLarge)                   // 24 = HTML 24
      JeebSectionLabel(l10n.mutualRatingTagsLabel)       // NEW widget, existing key
      SizedBox(height: Spacing.small)                    // 12 = HTML 12
      _TagsSection(selectedTags: state.tags)             // MOVED UP (was last)
      SizedBox(height: Spacing.large)                    // 20 ≈ HTML 18
      _CommentField(comment: state.comment)              // MOVED DOWN + refilled
      SizedBox(height: Spacing.large)                    // 20 ≈ HTML 18
      JeebInfoNote(...)                                  // NEW
```

**Do not put a `Spacer()` in that column.** The HTML's `flex:1` (HTML:39) is satisfied by
`Expanded(child: SingleChildScrollView)` + the docked footer: on a real 956pt phone the content ends
around 60% and the rest is white (R1), while on the 800×600 widget-test surface it still scrolls.
An `IntrinsicHeight`/`Spacer` construction would overflow every existing widget test.

### 1.4 Section-order change is load-bearing, not cosmetic

Today the order is `subtitle → stars → comment → tags` (`:135-144`). The render is
`stars → tags → note`. Beyond matching the board, moving the chips above the note field is what pulls
them inside the 800×600 test viewport — see §8.1, where it very likely turns a pre-existing red test
green.

---

## 2. Tokens

The file is already colour-clean (zero `Color(0x…)`, zero `Colors.*`). The token work here is the
**type ramp, the spacing bridge and two star colours**, not a palette swap.

| Current | `file:line` | Becomes | Evidence |
|---|---|---|---|
| `OMDSAppBar` title | `:51-54` | `Text(headline, style: context.jeebText.h2)` in-body, ink `colorScheme.onSurface` | HTML:15 `20px/700/--jeeb-navy` |
| `EdgeInsets.all(Spacing.large)` (20) on the scroll area | `:131` | `EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.medium, Spacing.xLarge, Spacing.xLarge)` | `--screen-gutter: 24` (§4.3); the plan mandates a 24 gutter on every redesigned body |
| `textTheme.bodyMedium` on the subtitle | `:137` | deleted; the copy re-renders inside `JeebInfoNote` at `jeebText.bodySmall` (12/w600) with ink `colorScheme.onSecondaryContainer` | HTML:37 `12.5/500/lh18/--jeeb-periwinkle` |
| `SizedBox(height: Spacing.xLarge)` ×2, `Spacing.medium` ×1 | `:139,141,143` | the rhythm in §1.3 (`large` 20 / `xSmall` 8 / `xLarge` 24 / `small` 12) | measured HTML margins 22/18/8/24/12/18/18 (R12: this board spaces at 9–22, never 28/32) |
| `OmdsStarRating(rating:, onRatingChanged:)` with defaults | `:164-168` | `starSize: Sizes.threeXLarge` (40 ≈ HTML 38), `spacing: Spacing.xSmall` (8 ≈ HTML 10), `inactiveColor: colorScheme.surfaceContainerHighest` | HTML:19-20 `font-size:38; gap:10`; empty star `var(--jeeb-surface-highest)` = `#E5E1E5` = `surfaceContainerHighest` (§4.1) |
| star active colour | implicit | `context.omdsColorTokens.starRatingColor` — **already `#FFC107` app-wide** since Wave 0 (`lib/app/app.dart:621-624`). Do not pass `activeColor`, and never a literal | HTML:20 `rgb(255,193,7)`; §4.1 lists 15 as one of only three screens where the yellow star is correct |
| `textTheme.labelMedium` on the tags label | `:260` | `JeebSectionLabel` (kit #10, default 12.5/w700/ls 1.2/uppercase/`mutedText`) | HTML:25 `13px/700/ls 1.2/uppercase/--jeeb-periwinkle`. §4.2 says 13 and 12.5 are the same token; **do not use the shipped 11px `small` flag** |
| `Wrap(spacing: Spacing.xSmall)` with no `runSpacing` | `:268-269` | add `runSpacing: Spacing.xSmall` | HTML:26 `gap:8px` is both-axis; today the two chip rows have zero vertical gap |
| `OmdsChip` | `:305-310` | `JeebSelectChip(role: JeebChipRole.inlineAction)` | HTML:27-31 pad `9/15`, 13/w600; selected navy + white, unselected `1.5px var(--jeeb-brown-outline)` with **navy** ink. R2's `inlineAction` row (pad `9/16-18`, 13/w600, navy ink) is the matching scale — pass the role, never a padding |
| `OmdsTextField(maxLines: 4, maxLength: 500)` | `:185-191` | `fillColor: colorScheme.surfaceContainerHigh`, `borderRadius: 16`, `minLines: 3`, `inputFormatters: [LengthLimitingTextInputFormatter(500)]` | HTML:33 `padding 14/16; radius 16; background var(--jeeb-surface-high); min-height 64; 14/500; placeholder --jeeb-periwinkle` |
| `Padding(EdgeInsets.all(Spacing.large))` + bare `OmdsPrimaryButton` | `:322-336` | `JeebCtaFooter.single` (pad `0/24/32`) wrapping `JeebCtaButton.primary` — h56 navy pill, white `jeebText.button` (17/w600), `JeebShadows.ctaNavy` | HTML:40-41 `padding:0 24px 32px; height:56; radius:999; box-shadow: rgba(11,19,81,.28) 0 10px 24px` — an exact `JeebShadows.ctaNavy` match |
| `label: '$stars stars selected'` (hardcoded EN inside a Semantics label) | `:163` | `l10n.mutualRatingStarsA11yLabel(stars)` | Constraint 5 — this string reaches TalkBack/VoiceOver and is not localized today. Low-risk, no test asserts it |

**Colours NOT to introduce:** the 5th star's grey is `surfaceContainerHighest`, not
`JeebSemanticColors.mutedSurface`; the info-note border is `colorScheme.outline` (`#916F66`), not
`jeebRoles.accent`. There is **no orange fill on this screen except the Ø26 completion badge** — that
is R5-correct (orange marks what just happened), and adding orange anywhere else (e.g. the CTA)
would violate the "once per surface, on the action that decays" rule; submitting a rating does not
decay.

---

## 3. Shared components consumed

| Kit widget | Replaces | Notes |
|---|---|---|
| **#10 `JeebSectionLabel`** | the bare `Text(..., labelMedium)` at `:258-261` | default (12.5) variant, no `hint` slot |
| **#6 `JeebSelectChip`** (role `inlineAction`) | `OmdsChip` at `:305-310` | keep the existing outer `Semantics` wrapper (§6.2) |
| **#2 `JeebCtaButton` + `JeebCtaFooter`** (`single`) | `Padding` + `OmdsPrimaryButton` at `:322-336` | needs `isEnabled` — see §3.1 |
| **#22 `JeebInfoNote`** | new | needs an **outlined** tone — see §3.1 |
| **#9 `JeebAvatar`** | new | needs a Ø74 size and a completion badge — see §3.1 |

### 3.1 Three kit gaps this screen exposes (wiring requests to the Wave-1 lane)

These are **not** requests to fork the kit; they are spec holes the 15 render reveals. Building them
screen-locally is worse: `tool/check_design_tokens.sh` bans `fontSize:` and literal
`EdgeInsets`/`BorderRadius.circular` inside `lib/features`, so design-exact px legally live only in
`lib/core/widgets/jeeb/` (§4.4).

1. **`JeebInfoNote` needs an `outlined` tone.** The plan lists `muted` (`surfaceContainerHigh` fill),
   `success` and `accent`. 15's note is **white with a `1.5px colorScheme.outline` border**, r16, pad
   `12/16`, gap 11, leading 18px periwinkle eye glyph, text 12.5/w500/lh18 `mutedText` (HTML:35-38).
   Typography identical to `muted`, container inverted. Ask: a `bool outlined` (or a fourth tone
   `outlinedMuted`) that swaps the fill for the 1.5px border. This is R7-consistent — the outline is
   the default and a fill is the exception — so 15 is probably not the only consumer.
2. **`JeebAvatar` needs a 4th size and a 3rd dot semantic.** Spec'd sizes are Ø30/Ø42/Ø46; 15 draws
   **Ø74** with a 26/w800 initial (HTML:17). Spec'd dots are `presence` (green, bottom-END) and
   `unread` (orange, top-END); 15 draws a **Ø26 `jeebRoles.accent` disc with a 3px `surface` ring and
   a 13px white check at the bottom-END**. Ask: `JeebAvatar.hero` (Ø74) + `badge:
   JeebAvatarBadge.completed`. Both are `EdgeInsetsDirectional`/`PositionedDirectional` so they
   mirror.
   *Fallback if refused:* a screen-local `_RateeAvatar` using `Sizes.sevenXLarge` (72) and
   `context.jeebText.h1.copyWith(fontWeight: FontWeight.w800)` (24/w800 vs the designed 26/w800) —
   token-legal, 2px off.
3. **`JeebCtaButton` must expose `isEnabled`.** `_SubmitButton` gates on `stars > 0` (`:332`), which
   is the D56 completeness gate and is also enforced in the cubit (`mutual_rating_cubit.dart:42`).
   The §5 #2 spec lists variants and shadows but no disabled state. Without `isEnabled` this screen
   cannot adopt the kit button.

### 3.2 One kit addition proposed: `JeebStarInput`

`OmdsStarRating` (OMDS `lib/src/reviews/omds_star_rating.dart`) cannot render this screen correctly
and cannot be edited (CI pulls OMDS from GitHub):

- it draws `Icons.star_border` for empty stars — an **outline** glyph. R10 is explicit: "filled,
  single-colour, no outline or two-tone variants anywhere". HTML:20 draws the 5th star as a *filled*
  `★` in `--jeeb-surface-highest`;
- it exposes **no per-star Semantics identifier** — a gap already disclosed in
  `feedback_star_input.dart:7-10` — which is exactly why the Maestro flow point-taps (§8.2).

Ask the kit lane for **`JeebStarInput`** in `lib/core/widgets/jeeb/jeeb_star_input.dart`: 5 tappable
`Icon(Icons.star)` at size 38, gap 10, active `context.omdsColorTokens.starRatingColor`, empty
`colorScheme.surfaceContainerHighest`, a plain `Row` (auto-mirrors under RTL), each star wrapped in
`Semantics(identifier: '${identifierPrefix}_$n', button: true, container: true)`, the whole row
labelled with the current value.

**If refused,** keep `OmdsStarRating` with `starSize: Sizes.threeXLarge`, `spacing: Spacing.xSmall`,
`inactiveColor: colorScheme.surfaceContainerHighest` and accept the outline empty star — but then the
Maestro point-tap must still be re-measured (§8.2). Adopting the kit widget is strictly better.

---

## 4. New functionality

### 4.1 Star verdict labels — buildable today, no state change

`state.stars` already drives everything. Add a pure `_starVerdict(AppLocalizations, int)` switch
mirroring the existing `_tagLabel` idiom (`:231-246`), returning `''` at 0 so the row collapses
without inventing a prompt. Five new ARB keys (§4.4). The render's "Great" is at 4 stars, which fixes
the scale: 1 Poor · 2 Fair · 3 Okay · 4 **Great** · 5 Excellent.

**No cubit or state change.** `MutualRatingState` already carries `stars`, `comment`, `tags`.

### 4.2 The counterpart's name — needs plumbing, not an endpoint

The render's headline and avatar initial both need a name the screen does not have:
`MutualRatingCubit` holds only `deliveryId` and `isClient` (`mutual_rating_cubit.dart:17-26`).

**There is an existing, sanctioned pattern.** The sibling `/orders/:id/feedback` route already reads
`state.uri.queryParameters['name']` and passes it to `RatingScreen.rateeName`
(`app_router.dart:1436-1441`). Mirror it exactly:

1. `MutualRatingScreen` gains `final String rateeName;` with a `''` default (keeps `const
   MutualRatingScreen()` valid for the 4 tests and the 3 devtool catalog states at
   `batch_09_entries.dart:352-388`).
2. `app_router.dart:1460` becomes `child: MutualRatingScreen(rateeName: state.uri.queryParameters['name'] ?? '')`.
3. Callers append `&name=` where they already hold the string. Verified: `chat_detail_screen.dart`
   holds `_counterpartName` (`:169`, set at `:1375`) and calls `_mutualRateRoute` at `:1237`. The
   other three call sites (`otp_handover_screen.dart:205,374`,
   `delivery_detail_screen.dart:419,433`, `app_router.dart:1519`) do not obviously hold a name — they
   simply pass nothing and get the fallback.

**Fallback when the name is empty** (this is the common case at first, so it must read well): a
role-aware headline derived from `isClient`, which the screen *does* have — "How was your Jeeber?" /
"How was your customer?". Same precedent as `FeedbackHeader` (`feedback_header.dart:17-19`) swapping
copy on `isClient`. The avatar falls back to `?` exactly as `FeedbackAvatar._initial` does
(`feedback_avatar.dart:19-22`).

This is not fabrication: it is the same display string the user just saw in the chat header, carried
forward. It invents no field and calls nothing.

### 4.3 The recap line — REFUSED as drawn, TODO

`Medicine · delivered in 38 mins · $8` (HTML:18) needs an item title, an elapsed duration and a fare.
None exist on this surface:

- `MutualRatingState` has none of them;
- `RatingRepository` exposes only `submitRating` and `fetchRatingStatus`, and `RatingStatus` carries
  `deliveryId` / `revealState` / `counterpartRating` — nothing else
  (`rating_status.dart:42-60`);
- wiring a cross-feature delivery-summary repository into `MutualRatingCubit` would add a network
  read to a **mandatory terminal** the user cannot leave — a failure there strands them.

Per §7.6, render the surface without it:

```dart
// TODO(redesign-24): recap line (item · duration · fare) needs a delivery
// summary on the rating surface — omitted, not faked.
```

Do **not** pass the money through the query string. A stale `$8` in a URL is the JEBV4-176 lesson
repeating itself, and D41/D44 make money copy on this app a gated concern.

### 4.4 Copy / l10n (integrator batch — EN + real AR + getter, all four edits or the parity gate fails both ways)

**New keys**

| Key | EN | AR |
|---|---|---|
| `mutualRatingHeadlineNamed` (`{name}`) | `How was {name}?` | `كيف كان {name}؟` |
| `mutualRatingHeadlineJeeber` | `How was your Jeeber?` | `كيف كان الجيبر؟` |
| `mutualRatingHeadlineClient` | `How was your customer?` | `كيف كان الزبون؟` |
| `mutualRatingStarLabel1` | `Poor` | `سيئ` |
| `mutualRatingStarLabel2` | `Fair` | `مقبول` |
| `mutualRatingStarLabel3` | `Okay` | `جيد` |
| `mutualRatingStarLabel4` | `Great` | `رائع` |
| `mutualRatingStarLabel5` | `Excellent` | `ممتاز` |
| `mutualRatingBlindNoteNamed` (`{name}`) | `{name} rates you too. Both ratings reveal together — neither of you sees the other's first.` | `{name} يقيّمك أيضًا. يُكشَف التقييمان معًا — لا أحد منكما يرى تقييم الآخر أولًا.` |
| `mutualRatingStarsA11yLabel` (`{stars}`) | `{stars} of 5 stars selected` | `{stars} من 5 نجوم محددة` |

**Value edits to existing keys (no new keys, no getter churn)**

| Key | From | To | Why |
|---|---|---|---|
| `mutualRatingTagsLabel` | `Quick tags (optional)` / `وسوم سريعة (اختياري)` | `What stood out?` / `ما الذي تميّز؟` | HTML:25. No test asserts the old string (grepped) |
| `ratingCommentHint` | `Anything else worth noting?` / `هل لديك ملاحظات إضافية؟` | `Add a note (optional)…` / `أضف ملاحظة (اختياري)…` | HTML:33. Only consumer is this screen (`:184,187`) |

**Reused as-is:** `mutualRatingSubtitle` becomes the *unnamed* fallback body of the info note (it
already says "Your rating is confidential until both sides submit."), and `mutualRatingSubmit`,
`mutualRatingError`, the five `mutualRatingTag*` keys and `mutualRatingTitle` (still used by the
legacy `/feedback` screen) are untouched.

### 4.5 Optional: stop blanking the screen while submitting

`_buildBody` (`:89-91`) swaps the whole body for `Center(child: OmdsLoadingState())` during
`submitting`. On a mandatory terminal that reads as a crash. Recommended: keep `_InputView` mounted
and pass `isLoading` to `JeebCtaButton`. No test asserts `OmdsLoadingState` on this screen (grepped),
and the devtool catalog only drives `inputting` and `error` (`batch_09_entries.dart:305-310`).
Ship it only if `JeebCtaButton` has a loading variant; otherwise leave `:89-91` alone.

---

## 5. New routes

**None.** `/orders/:id/mutual-rate` exists and stays. The only router touch is reading an optional
`?name=` query parameter inside the existing builder (§4.2) — an integrator-owned one-line edit to
`app_router.dart:1460`, not a route addition. The screen must stay **out of `backFallbacks`**
(`back_nav_all_routes_test.dart:80,265` excludes `mutual-rating` because of `PopScope(canPop:false)`).

---

## 6. Semantics identifiers

### 6.1 Existing — all five must survive verbatim

| Identifier | `file:line` | Asserted by |
|---|---|---|
| `rating_root` | `:58` | `decision_violations_test.dart:111`, `qa_keys_batch_test.dart:222`, maestro `jm-034` AC4 |
| `mutual_rating_stars` | `:161` | `qa_keys_batch_test.dart:228` |
| `mutual_rating_comment` | `:182` | `qa_keys_batch_test.dart:233` |
| `mutual_rating_tag_{punctuality,communication,package_condition,courtesy,navigation}` | `:301` | dynamic form; the l10n test taps by label and reads the wire key |
| `rating_submit_cta` | `:328` | `qa_keys_batch_test.dart:238`, maestro `jm-034` AC1/AC2/AC3 |

Widget `Key`s also pinned by `qa_keys_batch_test.dart:248-250`: `mutualRating.stars`,
`mutualRating.comment`, `mutualRating.submit`. **Keep all three.**

Ids that must remain ABSENT: `rating_skip_cta` (`qa_keys_batch_test.dart:243`, maestro AC1) and
`rating_close_cta` (`decision_violations_test.dart:120`). The redesign adds no escape control, so
D56 holds.

### 6.2 How to keep them while swapping widgets

- `mutual_rating_comment`: the note field is the *same control restyled*. Keep the existing
  `Semantics(identifier: 'mutual_rating_comment', textField: true, label: …)` wrapper at `:180-184`
  around the restyled `OmdsTextField`. **Do not rename to `_note`.**
- `mutual_rating_tag_*`: keep the explicit wrapper at `:300-304` — `identifier` + `container: true` +
  `button: true` + `selected: selected` — and pass `identifier: null` to `JeebSelectChip`. The kit's
  own wrapper does not carry `selected:`, so wrapping externally preserves today's a11y exactly and
  avoids a double node.
- `rating_submit_cta`: keep the wrapper at `:327-329` (`container: true`, no `button: true` — the
  button role comes from the CTA widget) around `JeebCtaButton`.
- `mutual_rating_stars`: keep the container wrapper at `:157-163` around `JeebStarInput` /
  `OmdsStarRating`. If `JeebStarInput` lands, add `explicitChildNodes: true` so the five new per-star
  ids are not swallowed (§7.5's `active_request_card.dart` idiom).

### 6.3 New identifiers proposed

| Identifier | Element | Rationale |
|---|---|---|
| `mutual_rating_star_1` … `_5` | each star in `JeebStarInput` | Retires the Maestro point-tap (§8.2) and closes the a11y gap disclosed in `feedback_star_input.dart:7-10` |
| `mutual_rating_ratee_avatar` | the Ø74 identity disc (`image: true`, label = name) | Mirrors the existing `feedback_ratee_avatar` on the sibling screen |
| `mutual_rating_blind_note` | the `JeebInfoNote` container | The designer note calls the blind mechanic the point of the screen; QA should be able to assert it renders |

No `<screen>_back` id — this screen has no back control by design.

---

## 7. RTL

The render has three mirror hazards. All three are solvable with directional APIs; none needs a
special case.

| Hazard | Build it as |
|---|---|
| Avatar badge at `right:-4; bottom:-4` (HTML:17) | `Stack` + `PositionedDirectional(end: -4, bottom: -4)`. Handled inside `JeebAvatar` if §3.1-2 lands |
| Info-note glyph on the leading edge with an 11px gap (HTML:35-36) | `Row` + `EdgeInsetsDirectional`; handled inside `JeebInfoNote` |
| Screen gutters and footer padding | `EdgeInsetsDirectional.fromSTEB(...)` everywhere — the current `EdgeInsets.all` at `:131` and `:323` are symmetric so they are safe today, but the new top-only padding is not |

Already correct and must not regress:

- `Wrap(textDirection: Directionality.of(context))` at `:270` — the JEBV4-296 comment explains why it
  is explicit. **Keep the line and the comment**; only add `runSpacing`.
- The star row is a plain `Row`, so in `ar` star #1 lands on the right and the fill grows leftward —
  correct mirroring. Do not force `TextDirection.ltr` on it.
- Headline with an interpolated Latin name inside an Arabic sentence: a plain `Text` is right —
  Flutter runs the bidi algorithm within the paragraph using the ambient direction.
  `MixedDirectionText` (`lib/features/mixed_direction/presentation/mixed_direction_text.dart`, already
  imported by the sibling `rating_screen.dart`) is only needed for a *name-only* line, which this
  layout does not have.
- `JeebSectionLabel` applies `toUpperCase()` internally; Arabic has no case mapping so the AR string
  passes through unchanged.
- Nothing on this screen renders money or digits in a mixed run, so no LTR isolate is required — one
  more reason not to build the recap line from query params.

**Trap:** the four widget tests that pump this screen use `wrapForTest`, which builds
`ThemeData.light()` — **not** `AppTheme.light()`. `context.jeebText` and `context.jeebRoles` both
fall back safely (`jeeb_text_styles.dart:211-212`, `jeeb_color_roles.dart:264-270`), but
`JeebSemanticColors` has **no context accessor** and the plan's documented read is
`Theme.of(context).extension<JeebSemanticColors>()!`. That bang throws under `ThemeData.light()`.
Any kit widget this screen consumes (`JeebSectionLabel`, `JeebInfoNote`) must read it as
`?? JeebSemanticColors.light()`, and this screen should prefer `colorScheme.onSecondaryContainer`
(the same `#777FC0` per §4.1) for periwinkle ink. Flagged to the kit lane in §9.

---

## 8. Test impact

### 8.1 `test/features/rating/mutual_rating_tag_chips_l10n_test.dart` — pre-existing red, likely goes GREEN

This is one of the four `_BASELINE.md` failures and it sits inside this screen. Measured locally, the
failure is **not** an l10n bug:

```
Warning: A call to tap() with finder "Found 1 widget with text "ودود"" derived an
Offset (Offset(400.0, 524.0)) that would not hit test on the specified widget.
Expected: contains 'courtesy'   Actual: []
```

At 800×600 the last chip row falls **below the scroll viewport** (the footer occupies the bottom
~100px), so the tap is clipped and never reaches the chip. Moving the chips above the note field
(§1.4) puts row 2 at roughly y≈376 inside a ~512px viewport. **This proposal is expected to fix that
test incidentally.** Per `_BASELINE.md`, that is a change in failure mode I must state rather than
silently absorb: I am not fixing it deliberately, and if it does not go green the layout is wrong,
not the test.

### 8.2 `.maestro/flows/jm-034-rating.yaml` — WILL break silently. Needs an edit.

```yaml
# The 5 stars are a Row of GestureDetectors under the `mutual_rating_stars`
# container (no per-star id), so tap by point to land on the 4th star
# (~38% width, ~21% height) and set a rating.
- tapOn:
    point: "38%,21%"
```

Two occurrences (AC2 customer, AC3 jeeber). Today the stars sit left-aligned under an app bar; after
the redesign they are **centred** and lower (4th star ≈ 61% width, ≈ 25% height on the 440×956
canvas). Maestro is not in CI, so both ACs would rot without any red signal. Fix by landing
`JeebStarInput` (§3.2) and replacing both point taps with `tapOn: id: "mutual_rating_star_4"`. That
is an *addition* to the identifier surface, never a rename, so the freeze holds.

### 8.3 Tests that should keep passing unchanged

| Test | Why it survives |
|---|---|
| `mutual_rating_back_suppression_test.dart` | Only exercises the `BackButtonListener`/`PopScope` spine, which is untouched. It builds `MaterialApp.router` with `ThemeData.light()` — see the §7 trap |
| `decision_violations_test.dart:91-122` | `rating_root` present, `PopScope.canPop == false`, no `BackButton`/`CloseButton`, no `rating_close_cta`, no text `Skip`. Removing the `OMDSAppBar` *strengthens* all of these. **Watch the literal `find.text('Skip')`** — none of the new copy contains the word |
| `qa_keys_batch_test.dart:197-253` | Four ids + three `Key`s, all preserved (§6.2). The docked CTA stays on screen at 800×600 |
| `mutual_rating_tag_wire_contract_test.dart` | Pure unit test over `kMutualRatingTags`. **Do not touch `kMutualRatingTags` or `MutualRatingTag`** — the keys are the on-the-wire gateway taxonomy (JEBV4-297) |
| `mutual_rating_cubit_test.dart` | No cubit change proposed |
| `integration_wiring_test.dart:122-148` | Asserts `/orders/D123/rate` redirects onto `MutualRatingScreen`. A `rateeName` field with a `''` default keeps the type and the const constructor intact |
| `chat_detail_delivered_to_rating_test.dart`, `delivery_detail_rating_status_test.dart` | Route-level; unaffected unless a caller appends `&name=`, and even then the location prefix still matches — **verify** before landing §4.2 step 3 |

### 8.4 New tests to add (additive only)

1. star-verdict mapping: 0 → empty, 4 → "Great" (EN) and the AR equivalent;
2. headline fallback: `rateeName: ''` + `isClient: true/false` renders the role-aware question and
   never a stray `{name}`;
3. `mutual_rating_blind_note` renders in both locales;
4. an RTL smoke test at `ar` asserting no overflow at 200% text scale (§8 DoD).

**Goldens:** none exist for this screen (the committed goldens are 18 + the 24-sheet). Nothing to
regenerate.

---

## 9. Conflicts and refusals

| # | Design asks | Verdict |
|---|---|---|
| **A** | Nothing on the render conflicts with **D56** | ✅ **The board agrees with the lock.** No skip, no close, no back, and the note says "Mandatory by design — no skip, no back". The app-bar deletion makes the mandatory contract *more* obvious, not less. Keep `PopScope(canPop:false)` + `BackButtonListener` verbatim |
| **B** | `Medicine · delivered in 38 mins · $8` | ❌ **REFUSED as drawn** — no field, no endpoint, and adding a fetch to a mandatory terminal is a trap. Omit with `TODO(redesign-24)`. Do not smuggle the fare through a query param |
| **C** | `How was Karim?` | ⚠️ **Conditional.** Buildable only via the `?name=` plumbing (§4.2), which needs one integrator edit + one edit in another lane's file. Ships with a role-aware fallback until then |
| **D** | Orange check badge on the ratee avatar | ⚠️ **Build it as a *completion* mark, not a *verification* mark.** On the `?mode=jeeber` leg the ratee is the customer, who has no KYC — a badge read as "verified" would assert data the app does not have. Semantics label and the l10n description must say completed/delivered. R5-consistent: orange marks what just happened |
| **E** | Amber `#FFC107` stars | ✅ Allowed. §4.1 names 15 as one of only three screens where the yellow star is correct ("a specific person's rating drives a decision"). Read `context.omdsColorTokens.starRatingColor`, already set app-wide by Wave 0 |
| **F** | `What stood out?` replacing `Quick tags (optional)` | ✅ Copy-only. The five **wire keys** stay `punctuality`/`communication`/`package_condition`/`courtesy`/`navigation` — JEBV4-297 pins them and the gateway 400s on anything else. Only display labels may change |
| **G** | The board's five tags | ✅ Already exact. `Punctual · Friendly · Communication · Careful · Navigation` (HTML:27-31) is `kMutualRatingTags` in a different order. **Do not reorder the const list** — the JEBV4-296 comment at `:263-267` makes the logical order part of the RTL proof; the render's order is a layout artefact of `flex-wrap` |
| **H** | D41/D44, `kJeebCommissionRate`, B04, pinned-summary, tracking-privacy | Not applicable — this screen shows no money, no chat composer, no courier card |

---

## 10. Risks

1. **The Maestro point-tap (§8.2) is the only silent failure on this screen.** Everything else is
   caught by `flutter test`.
2. **Three kit gaps (§3.1) block a faithful build.** If the Wave-1 lane ships `JeebInfoNote` with
   fills only, `JeebAvatar` with three sizes only, and `JeebCtaButton` without `isEnabled`, this
   screen either hand-rolls (and trips `check_design_tokens.sh`) or diverges from the render.
   Sequence 15 **after** kit steps 1–4.
3. **`ThemeData.light()` in `wrapForTest` (§7).** A kit widget that does
   `extension<JeebSemanticColors>()!` crashes four of this screen's tests. This is a kit-wide
   landmine, not a 15-only one.
4. **Density (R1).** The content ends around 60% of a 956pt viewport and the rest is white. The
   temptation is to re-add the deleted subtitle or centre the column to "fill" it. Don't — the
   emptiness is the design.
5. **The empty-star shape.** If `JeebStarInput` is refused, `Icons.star_border` ships and 15 is the
   only screen on the board with an outline glyph.
6. **The name fallback is what most users will see** until the four call sites append `&name=`. The
   role-aware question must therefore read as finished copy in both locales, not as a placeholder.
