# Wiring requests — screen 15 · Mutual rating (`15-mutual-rating`)

Everything below is outside `lib/features/rating/` and therefore not this lane's to edit. The screen
code is already written **as if the `route` + `l10n` blocks are granted**; until the integrator lands
the l10n block, `lib/features/rating/presentation/mutual_rating_screen.dart` does not compile
(10 undefined `AppLocalizations` members).

## Kit requests A–C from the revised instruction set are ALREADY SATISFIED — no kit change requested

Verified 2026-08-03 against the shipped Wave-1 kit (`lib/core/widgets/jeeb/`):

| §7 request | Status |
|---|---|
| A · `JeebInfoNoteTone.outlined` | **shipped** — `jeeb_info_note.dart:32` + `.outlined` ctor at `:240`; reads `JeebSurfaceTone`, which resolves `JeebSemanticColors` null-safely (`jeeb_surface_tone.dart:158-160`), so the `ThemeData.light()` harness is safe. |
| B · `JeebAvatar.hero` + `JeebAvatarBadge.completed` | **shipped** — `jeeb_avatar.dart:153` (Ø74, initial 26) and `:55-60` (Ø26 accent disc, 3px surface ring, white check, `PositionedDirectional`). |
| C · `JeebCtaButton.isEnabled` | **shipped** — `jeeb_cta_button.dart:76`, with the disabled paint and `isInteractive` gate. |

Only request D (below) is a real gap. The screen ships the sanctioned `OmdsStarRating` fallback in
the meantime.

---

### route
file: lib/core/router/app_router.dart
need: the `mutual-rating` builder must forward an optional `?name=` query param, mirroring the sibling `/orders/:id/feedback` route at :1441.
exact change: in the `mutual-rating` GoRoute builder (:1448-1462), replace `child: const MutualRatingScreen(),` with:
```dart
              child: MutualRatingScreen(
                rateeName: state.uri.queryParameters['name'] ?? '',
              ),
```
why: the redesigned headline ("How was Karim?"), the avatar initial and the blind-reveal note all name the counterpart; the screen ships a finished role-aware fallback when the param is absent (`rateeName` defaults to `''`), so this can land any time and nothing breaks if it never does.

### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart
need: 10 new keys + 2 value edits for the redesigned mutual-rating input view.
exact change — add to app_en.arb:
```json
  "mutualRatingHeadlineNamed": "How was {name}?",
  "@mutualRatingHeadlineNamed": { "description": "Screen-15 headline when the counterpart's display name is known (?name=). {name} is a person's display name.", "placeholders": { "name": { "type": "String", "example": "Karim" } } },
  "mutualRatingHeadlineJeeber": "How was your Jeeber?",
  "@mutualRatingHeadlineJeeber": { "description": "Screen-15 headline fallback on the customer leg (no ?name=)." },
  "mutualRatingHeadlineClient": "How was your customer?",
  "@mutualRatingHeadlineClient": { "description": "Screen-15 headline fallback on the ?mode=jeeber leg (no ?name=)." },
  "mutualRatingStarLabel1": "Poor",
  "@mutualRatingStarLabel1": { "description": "Screen-15 verdict word under a 1-star selection." },
  "mutualRatingStarLabel2": "Fair",
  "@mutualRatingStarLabel2": { "description": "Screen-15 verdict word under a 2-star selection." },
  "mutualRatingStarLabel3": "Okay",
  "@mutualRatingStarLabel3": { "description": "Screen-15 verdict word under a 3-star selection." },
  "mutualRatingStarLabel4": "Great",
  "@mutualRatingStarLabel4": { "description": "Screen-15 verdict word under a 4-star selection (pinned by the render)." },
  "mutualRatingStarLabel5": "Excellent",
  "@mutualRatingStarLabel5": { "description": "Screen-15 verdict word under a 5-star selection." },
  "mutualRatingBlindNoteNamed": "{name} rates you too. Both ratings reveal together — neither of you sees the other's first.",
  "@mutualRatingBlindNoteNamed": { "description": "Screen-15 blind-reveal info note when the counterpart's name is known. Falls back to mutualRatingSubtitle otherwise.", "placeholders": { "name": { "type": "String", "example": "Karim" } } },
  "mutualRatingStarsA11yLabel": "{stars} of 5 stars selected",
  "@mutualRatingStarsA11yLabel": { "description": "Accessibility label on the screen-15 star input (mutual_rating_stars). Replaces a hardcoded English literal.", "placeholders": { "stars": { "type": "int", "example": "4" } } },
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
  "mutualRatingStarsA11yLabel": "{stars} من 5 نجوم محددة",
```
app_localizations.dart (house `_get` pattern, insert in the "T-MOB-020: Mutual blind rating" block after `mutualRatingSubtitle` at :2034):
```dart
  String mutualRatingHeadlineNamed(String name) =>
      _get('mutualRatingHeadlineNamed').replaceFirst('{name}', name);
  String get mutualRatingHeadlineJeeber => _get('mutualRatingHeadlineJeeber');
  String get mutualRatingHeadlineClient => _get('mutualRatingHeadlineClient');
  String get mutualRatingStarLabel1 => _get('mutualRatingStarLabel1');
  String get mutualRatingStarLabel2 => _get('mutualRatingStarLabel2');
  String get mutualRatingStarLabel3 => _get('mutualRatingStarLabel3');
  String get mutualRatingStarLabel4 => _get('mutualRatingStarLabel4');
  String get mutualRatingStarLabel5 => _get('mutualRatingStarLabel5');
  String mutualRatingBlindNoteNamed(String name) =>
      _get('mutualRatingBlindNoteNamed').replaceFirst('{name}', name);
  String mutualRatingStarsA11yLabel(int stars) => _get(
        'mutualRatingStarsA11yLabel',
      ).replaceFirst('{stars}', stars.toString());
```
value edits (both files):
- `mutualRatingTagsLabel`: EN `"Quick tags (optional)"` → `"What stood out?"` (app_en.arb:729); AR `"وسوم سريعة (اختياري)"` → `"ما الذي تميّز؟"` (app_ar.arb:1217).
- `ratingCommentHint`: EN `"Anything else worth noting?"` → `"Add a note (optional)…"` (app_en.arb:681); AR `"هل لديك ملاحظات إضافية؟"` → `"أضف ملاحظة (اختياري)…"` (app_ar.arb:306).

Verified: `mutual_rating_screen.dart` is the only `lib/` consumer of both edited keys, and no test asserts the old strings. `mutualRatingTitle` is NOT touched — `rating_screen.dart:135` still uses it.
why: HTML:15/22/25/33/37 copy; constraint 5 (the stars a11y label at the old :163 was a hardcoded English literal).

### kit
file: lib/core/widgets/jeeb/jeeb_star_input.dart (Wave-1 kit lane, NEW widget) and .maestro/flows/jm-034-rating.yaml
need: a star input that matches the board (**filled grey** empty star — R10; `OmdsStarRating` draws `Icons.star_border`) with per-star identifiers, so jm-034's two coordinate taps can be retired.
exact change: new `JeebStarInput`: 5 tappable `Icon(Icons.star)` size 38, gap 10, active `context.omdsColorTokens.starRatingColor`, empty `colorScheme.surfaceContainerHighest`, plain `Row` (auto-mirrors, no forced Directionality), each star wrapped `Semantics(identifier: '<identifierPrefix>_$n', button: true, container: true)`; params `int value`, `ValueChanged<int> onChanged`, `String? identifierPrefix`, `String? semanticLabel`. Then in `.maestro/flows/jm-034-rating.yaml` replace both `point: "38%,21%"` taps (AC2 ~:71, AC3 ~:112) with `tapOn: id: "mutual_rating_star_4"`.
why: the redesign moves and centres the star row, so jm-034's two point-taps rot silently (Maestro is not in CI). Screen 15 ships the sanctioned `OmdsStarRating(starSize: Sizes.threeXLarge, spacing: Spacing.xSmall, inactiveColor: colorScheme.surfaceContainerHighest)` fallback and accepts the outline-empty-star divergence until this lands. When it lands, `_StarSection` swaps the widget, adds `identifierPrefix: 'mutual_rating_star'` and `explicitChildNodes: true` on the existing `mutual_rating_stars` wrapper so the per-star ids are not swallowed — nothing else on the screen changes.

### cross-feature (deferred — integrator's discretion, no change requested here)
file: lib/features/deep_link_targets/chat_detail_screen.dart
need: nothing today. Noted only so the `?name=` route param has a known future caller.
exact change: none. `_counterpartName` (:169 / :1237 / :1375) is the one site in the app that actually holds the counterpart's display name; if a future lane routes to the rating terminal from chat it can append `&name=$_counterpartName`. Verified that `otp_handover_screen.dart`, `delivery_detail_screen.dart` and `app_router.dart:1519` hold no display name — there is nothing to do at those three sites.
why: the screen's role-aware fallback headline is finished, so this is an enhancement, not a dependency.
