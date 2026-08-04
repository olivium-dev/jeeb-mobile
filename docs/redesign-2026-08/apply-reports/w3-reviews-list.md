# w3 — reviews-list onto the Jeeb design system

**Target:** `lib/features/reviews/presentation/reviews_list_screen.dart` (+ `presentation/widgets/review_row.dart`)
**Reference:** no board render exists for this screen. `screens/15-mutual-rating.{png,html}` (the adjacent
redesigned rating surface) was used for the *language*, plus the in-repo redesigned neighbours
`order_history_screen.dart` / `order_history_card.dart` and `wallet_hub_screen.dart` for house conventions.
**Wiring requests filed:** none. Every edit is inside `lib/features/reviews`.

---

## What the neighbour does, and what this screen did differently

| 15-mutual-rating (the language) | reviews-list, before |
|---|---|
| In-body header, 24px gutters, ~28px block rhythm | Material `OMDSAppBar` + list bands on a 16px gutter |
| Outlined / filled cards, radius 16, **outline over shadow** | `OmdsReviewCard` blocks separated by `Divider`s, plus the card's own bottom `Border` |
| Weight carries hierarchy; every style from a token | `theme.textTheme.titleSmall?.copyWith(fontWeight: w600)`, `bodyMedium`, `bodySmall` |
| Notes = a bordered strip with a glyph + periwinkle body | Bare `Text` under an `OmdsChip` |
| Navy pill CTAs, brown secondary words | `FilledButton.icon` / `TextButton` |
| Bottom third deliberately empty | Loading skeletons flush to the top edge, no gutter at all |

The row also printed the reviewer **twice** (an explicit attribution `Text` above an `OmdsReviewCard` that
renders `userName` internally), and `OmdsReviewCard` lays its image strip out with a non-directional
`EdgeInsets.only(right:)`.

---

## What changed

### `reviews_list_screen.dart`
1. **`OMDSAppBar` → in-body `JeebTopBar`** inside `SafeArea` + `Column` (the wallet-hub idiom). The header now
   renders in *every* state, and `identifier: 'reviews_back'` lands on the kit's Ø40 leading circle — the
   frozen `<screen>_back` contract (03-WAVE1-KIT §1.1). `onLeadingPressed` keeps the exact
   `canPop() ? pop() : go('/')` behaviour; the kit supplies the a11y label from `MaterialLocalizations`,
   which the old bare `IconButton` did not have.
2. **One gutter constant** `_kListPadding` = `fromSTEB(24, 16, 24, 24)` for the loaded list and the loading
   skeletons; the empty state got the 24px horizontal gutter.
3. **Dividers → card gaps.** `separatorBuilder` is now `SizedBox(height: 20)` under the header and
   `SizedBox(height: 12)` between cards. R7/R12: outlined cards separate themselves; a divider between two
   of them draws a third line nobody asked for.
4. **D59 cold-start band:** `OmdsChip` → `JeebSystemChip.filled(center: false)` (`reviews_new_badge`), bare
   `Text` → `JeebInfoNote.outlined` (`reviews_hidden_score_note`) — the same brown-outline/periwinkle note
   treatment 15 uses for its blind-reveal explainer. The `auto_awesome` glyph moved onto the note.
5. **Aggregate line:** `titleSmall.copyWith(w600)` → `context.jeebText.titleProminent` in navy, star at
   `Sizes.large`, wrapped in `Expanded` so a long AR count string wraps instead of overflowing.
6. **Error state:** the 64px red `error_outline` slab + `FilledButton.icon` became
   `JeebInfoNote.error` (`reviews_error`) over a `JeebCtaButton.primary` (`reviews_retry_cta`). This is the
   soft `errorContainer` tint the migration's error family was added for.
7. **Skeletons:** first-load and load-more shimmers now sit inside `JeebOutlinedCard`, so the list does not
   re-flow its own geometry when the page lands.
8. **Load-more error footer:** tokenised copy (`jeebText.bodySmall` / periwinkle) + `JeebCtaButton.text` for
   `reviews_load_more_retry`.
9. **`RefreshIndicator` → `OmdsPullToRefresh`.** This was a *pre-existing* `tool/check_design_tokens.sh`
   violation in this file; the script now reports only the other lane's `client_location_screen.dart` hit.
10. Dropped the unused `copy` field on `_LoadingSkeletons` and the now-unused `DirectionalIcons` import.

### `widgets/review_row.dart`
- `OmdsReviewCard` → a `JeebOutlinedCard` composition: `JeebAvatar` (Ø42) + the attribution name
  (`jeebText.cardTitle`, navy) + a five-glyph score + the relative time (`jeebText.bodySmall`, periwinkle)
  on one identity row, the body in `jeebText.body`, and the report link beneath.
- **The duplicate name is gone** — the D58 attribution node is now the visible name.
- The empty star is a **filled grey glyph** (`surfaceContainerHighest`), matching 15 `tpl 873`, not
  `Icons.star_border`.
- Report CTA: `TextButton.icon` → `JeebCtaButton.text` with `labelStyle: jeebText.bodySmall` and zero content
  padding — the board's "brown secondary interactive word". It sits in a `Row` (not an `Align`) because the
  bare-text variant centres its label in whatever width it is given; a Row lays it out against an unbounded
  main axis so it shrink-wraps onto the start edge. (Caught by rendering the screen, not by the analyzer.)

---

## What deliberately did NOT change

- **Behaviour, navigation, business logic, copy meaning.** Same 4-state machine, same `_confirmReport`
  dialog + one-shot snackbar, same infinite-scroll trigger, same route edges, same `ReviewsL10n` strings.
- **No new strings**, so no `lib/l10n` edit and no wiring request.
- **D57/D27/D58/D59/D73 all intact**; no Helpful/Reply control was introduced.
- `OmdsEmptyState` stays — the kit has no empty-state primitive and `order_history_screen` keeps it too.
- `lib/features/rating/presentation/widgets/recent_reviews_section.dart` still uses `OmdsReviewCard`; it is
  another lane's file.

## Identifiers — all 11 preserved byte-identically

`reviews_root` · `reviews_back` · `reviews_loading` · `reviews_error` · `reviews_retry_cta` ·
`reviews_empty` · `reviews_new_badge` · `reviews_hidden_score_note` · `reviews_aggregate` ·
`reviews_load_more` · `reviews_load_more_retry` · `review_<id>` · `review_<id>_reviewer_name` ·
`review_<id>_report_cta`

`reviews_back`, `reviews_error`, `reviews_retry_cta`, `reviews_new_badge`,
`reviews_hidden_score_note`, `reviews_load_more_retry` and `review_<id>_report_cta` now come from the kit's
own explicit `Semantics(identifier:)` wrapper instead of a hand-written one — same string, same node.

## Gates

| Gate | Result |
|---|---|
| `dart analyze lib/features/reviews` | **No issues found** |
| `dart analyze lib/devtool/catalog/entries/batch_10_entries.dart` (ReviewRow consumer) | No issues found |
| `flutter test test/features/reviews test/semantics_identifier_surfacing_test.dart test/core/router/w3_w4_routes_resolve_test.dart` | **24 passed, 0 failed** |
| `tool/check_design_tokens.sh` | reviews violation cleared (1 remaining, another lane's file) |
| Throwaway render pass (loaded / cold-start / empty / failed, EN + AR) | no exceptions, no overflow |

## Known deviations from the neighbour render

1. **Stars are navy, not amber.** 15 draws `#FFC107`. §4.1 rations the warm ink to the three surfaces where
   *a specific person's rating drives a decision* (11/12/15) and warns that tinting every ★ is a visible
   regression; this screen's direct parent, `delivery_man_profile_header.dart`, already ratified navy with
   that exact reasoning. If the owner decides a reviews list *is* a decision surface, the swap is two
   `scheme.primary` → `context.omdsColorTokens.starRatingColor` edits in `_ReviewStars` + `_AggregateHeader`.
2. **No `JeebSectionLabel` above the rows.** 15 opens its chip band with `WHAT STOOD OUT?`. An equivalent
   ("ALL REVIEWS") would be new user-visible copy, which needs an ARB + `app_localizations.dart` change;
   omitted rather than hardcoded.
3. **No deliberately-empty lower third on the loaded state.** A paginated list legitimately fills the
   viewport. The empty and cold-start states do show it.
4. The reviewer avatar is a single `JeebAvatarFill.primary` navy disc for every row — `JeebAvatarFill.forIndex`
   would give the board's 3-fill rotation, but `ReviewRow` has no index and inventing one from the id would
   reorder colours between pages.
