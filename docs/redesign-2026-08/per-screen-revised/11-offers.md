# 11 · Offers — REVISED instruction set (authoritative)

Reviewed against: `screens/11-offers.{png,html,note.md}`, the live source of all five lane files,
every cited test, `_BASELINE.md`, `00-MIGRATION-PLAN.md` §5/§7.2, `02-PLAN-ENHANCED.md`, the OMDS
library source, and `lib/l10n/app_localizations.dart`. Every `file:line` below was re-checked on
2026-08-03. Where this document contradicts the original proposal, **this document wins**.

Verdict: **rebuild** of the presentation tree in place. Domain/data/cubit survive with the small
additive changes in tasks 2–4. Route exists (`app_router.dart:805-810`, name `offer-review`;
`backFallbacks:466` already has `'offer-review': '/'`) — **no route, DI, or theme wiring**.

## What changed vs the original proposal

- **CUT** the "usually replies in 1 min" refusal row — `02-PLAN-ENHANCED.md:274` attributes that
  string to screen **21**, not 11. Nothing to refuse.
- **CUT** the `JeebOutlinedCard` and `JeebAvatar` kit dependencies for this screen. The offer card
  is "not shared" per plan §5; restyle the existing `Card` in place and keep `OmdsProfileAvatar`
  directly (its `backgroundColor` / `initialColor` / `size` params are verified present). Two
  fewer Wave-1 blockers.
- **CORRECTED** the `offersWindowStrip` l10n shape: this repo's `AppLocalizations` is hand-rolled
  (`_get` + `replaceFirst`, see `app_localizations.dart:1541-1546`) and does **not** parse ICU
  `{count, plural, …}`. Plurals here are six suffixed keys + a Dart selector (precedent:
  `pendingCardOffersBadge`, `app_localizations.dart:1852-1869`). The wiring request below uses
  that pattern.
- **CORRECTED** the sort-chip test description: the assertion is
  `lessThan(tester.getSize(target).height)` where the target is ≥ `UIConstants.buttonHeight`
  (`client_offers_screen_test.dart:152-190`) — not a literal `lessThan(48.0)`. Same consequence:
  the new chip's visual capsule must render strictly shorter than its 48dp hit target.
- **CORRECTED** the baseline: `_BASELINE.md` supersedes the "11 issues / 6 errors" framing. Real
  bar: `flutter analyze` = 5 pre-existing infos, 0 errors, **no new issue**; `flutter test` = no
  failure beyond the four named in `_BASELINE.md`. The sort-chip failure is one of the four, is
  **inside this lane**, and this rebuild is expected to flip it red→green — report that flip
  explicitly.
- **CORRECTED** the top-bar structure: the proposal's §2.1 sketch put the top bar inside the
  loaded body only, while its §2.9 needed it to survive a cold-load failure. Resolved: the top
  bar renders in **all** states (task 8's structure).
- **HARDENED** `DirectionalIcons.back` is a **method** — `DirectionalIcons.back(context)`
  (`lib/core/widgets/directional_icons.dart:16`). Matters for the stand-in top bar.
- **KEPT** (verified true, despite sounding wrong): the review count `(127)` is NOT a data gap —
  `Offer.ratingCount` is parsed (`dio_offers_repository.dart:234`) and rendered today as `(132)`
  (`offer_card_test.dart:40`). `02-PLAN-ENHANCED.md:272` is wrong on this point. What's missing
  on the live wire is gateway enrichment (O-list-enrich), which the card already handles honestly
  via `ratingCount > 0` → "No ratings yet".
- **KEPT** the C4 refusal, now stated as the plan's own rule: `00-MIGRATION-PLAN.md` §7.2 and its
  screen-11 row (line 475) already say *"do not ship that: every offer must stay acceptable"*.
  **All cards get a full action row. No `.75` opacity on any card** — dimming is an owner
  decision the plan left open; default is off. Do not implement a `dormant` state here.

---

## 0. Preconditions and kit policy

`lib/core/widgets/jeeb/` **does not exist yet** (checked 2026-08-03). This lane consumes, per plan
§5: `JeebTopBar` (#1), `JeebCtaFooter.textStack` (#2), `JeebSelectChip(role: sort)` (#6),
`JeebMeter` (#20), `JeebInfoNote` (#22).

Policy, in order:
1. At implementation start, re-check `lib/core/widgets/jeeb/`. **Consume every kit widget that
   exists.** You may not create or edit files there — it is a shared surface.
2. For each missing kit widget, build a **private stand-in in
   `lib/features/client_offers/presentation/widgets/`** (e.g. `_OfferReviewTopBar` inside the
   screen file, or `offer_review_meter.dart`) matching the kit spec's visuals for the `sort` /
   `textStack` / strip cases only — not the whole kit API. Mark each with
   `// TODO(redesign-24): replace with kit <name> when Wave 1 lands.` and file the matching
   cross-feature wiring request (§6) so the integrator can consolidate.
3. Design-exact pixels (the 70×5 r9 meter) belong in the kit; a stand-in may carry them
   temporarily under the TODO. Everything else uses `Spacing` / `Sizes` / `OmdsBorderRadius` /
   `UIConstants` tokens — `tool/check_design_tokens.sh` bans `Color(0x…)`, `Colors.*`,
   `SizedBox(width|height: <n>)`, `EdgeInsets.<x>(<n>…)`, `BorderRadius.circular(<n>)` and
   `fontSize:` throughout `lib/features/`.

Token access on this screen: `context.jeebText` and `context.jeebRoles` only (both fall back
safely — `jeeb_text_styles.dart:211`, `jeeb_color_roles.dart:258-272`). **Never
`Theme.of(context).extension<JeebSemanticColors>()!`** — `test/support/sync_app_localizations.dart`
builds widget tests on `ThemeData.light()`, where the bang null-crashes. Screen 11 needs nothing
from `JeebSemanticColors`; periwinkle = `colorScheme.onSecondaryContainer`, orange =
`context.jeebRoles.accent` / `.onAccent` (`.tertiary*` is banned in `offer_window_timer.dart` by
`test/core/theme/no_raw_semantic_colors_test.dart:21`).

Constructor seams are frozen: `ClientOffersScreen(requestId, repository,
cancelRepositoryOverride, cubitFactory)` — `lib/devtool/catalog/entries/batch_02_entries.dart`
(~250-300) mounts five variants through them and is not your file.

---

## 1. Semantics inventory — FROZEN (verified against source 2026-08-03)

Emitted today, must survive spelled identically:

| Identifier | Source today |
|---|---|
| `offer_review_list_root` | `client_offers_screen.dart:155` — wraps the body across ALL states; keep it that way |
| `offer_review_cancel_cta` | `:311` (with `container: true, button: true, label:, onTap:` — keep all four) |
| `offer_review_error_dismiss_cta` | `:499` (with `button: true, container: true` — keep both) |
| `offer_review_sort_price` / `offer_review_sort_rating` | `offer_sort_bar.dart:40,58` (with `button/selected/label/onTap` → `ExcludeSemantics` — keep the idiom verbatim) |
| `offer_card_<index>` + `offer_card_<jeeberId>` | `_DualId`, `offer_card.dart:121-124` |
| `…_name`, `…_price`, `…_eta`, `…_cash_on_delivery_label`, `…_note`, `…_accept_cta` | `_NameTapTarget` / `_IdWrap` / `_AcceptCta` |
| `offer_card_no_ratings` | `_NoRatingsYet`, `offer_card.dart:446` |
| `offer_accept_*` (sheet) | `offer_accept_sheet.dart` — **do not open that file** |

Frozen `Key`s: `offer-list`, `offer-window-timer`, `offer-request-closed-banner`,
`offer-error-banner`, `offer-empty-state`, `offer-load-error`, `offer-review-cancel-cta`,
`offer-sort-price`, `offer-sort-rating`, `offer-card-<id>`, `offer-card-accept-<id>`,
`offer-card-name-<name>`.

Frozen widget types (tests match on type): `OmdsProfileAvatar` (+ its `initial` value,
`offer_card_test.dart:219,225`), `OmdsStarRatingDisplay` (`:270,290`), `OmdsPrimaryButton` under
`offer-card-accept-<id>` (`.isEnabled` read by `offer_accept_double_accept_b01_test.dart:~326` and
two screen tests) and under `offer-review-cancel-cta`.

New identifiers (convention `<screen>_<element>`):

| New id | Element |
|---|---|
| `offer_review_back` | top-bar back circle (the OMDSAppBar back had no id) |
| `offer_review_window_strip` | the countdown strip |
| `offer_review_sort_best` | third sort chip |
| `offer_card_<index>_best_value_badge` + `offer_card_<jeeberId>_best_value_badge` | orange badge |
| `offer_card_<index>_fastest_badge` + `offer_card_<jeeberId>_fastest_badge` | Fastest chip |
| `offer_review_only_one_note` | footer's orange line |

---

## 2. Deliberate divergences from the board (all one-line reversals; note them in the PR)

| Board | Ship | Why |
|---|---|---|
| title `Offers` | keep `offersScreenTitle` ("Choose a Jeeber") | already translated; the strip below carries the "3 offers in" fact |
| `$8` | `MoneyFormat` → `⁦$8.00⁩` | pinned: `offer_card_test.dart:35`, `client_offers_screen_test.dart:496,564`; LTR-isolated for RTL |
| `in 40 mins` | `offersCardEtaMinutes` → `40 min ETA` | exists both locales, asserted twice |
| `04:12` | `CountdownFormat` → `4:12` | unpadded leading field is deliberate (see its library doc); bidi-safe WITHOUT an isolate — do not add one |
| `Accept only one offer.` | `chatOfferAcceptOnlyOne` ("Accept only one offer", no period) | exists both locales (`app_en.arb:129`, `app_ar.arb:54`); do not mint a near-duplicate key |
| `3 km away` | vehicle label in that slot | **no distance field exists** on `Offer`, the wire row (`dio_offers_repository.dart:210-242`), or the request row. TODO comment, never fake |
| subtitle `… — Pharmacie du Musée` | item title only | `title` IS on the already-fetched `/v1/requests/:id` row (same read as `dio_order_summary_repository.dart:128`); `dropoff.address` is not on this endpoint. TODO comment |
| third card dormant (`.75`, no actions) | full-strength card, full action row | plan §7.2-C4: every offer stays acceptable |

---

## 3. Task list — execute top to bottom

**Task 1 — Write the wiring file.** Create `docs/redesign-2026-08/wiring/11-offers.md` with the
exact blocks from §6. From here on, write code as if the l10n requests are granted (the file
won't compile clean until the integrator lands them — expected; say so in your report).

**Task 2 — `domain/offer_ranking.dart` (NEW, pure Dart, no Flutter import).**
```dart
List<Offer> rankByBestValue(List<Offer> offers); // Borda: fee asc, rating desc, ETA asc; newest-first tie-break
String? bestValueOfferId(List<Offer> offers);    // null when offers.length < 2
String? fastestOfferId(List<Offer> offers);      // null unless min ETA is unique AND != bestValueOfferId's card
```
Honesty rules: `ratingCount == 0` contributes a neutral rating rank (never a fabricated score);
no "best of one" badge; `Fastest` suppressed when it would land on the best-value card or the
minimum ETA ties. Doc comment: distance is deliberately absent — the gateway sends none.
Add `test/features/client_offers/offer_ranking_test.dart` (pure Dart, no pump).

**Task 3 — `requestTitle` thread (all files lane-owned).**
- `domain/offers_repository.dart`: add `final String? requestTitle;` to `OffersSnapshot`,
  **optional constructor param defaulting to null** — then `test/support/scripted_offers_repository.dart`
  (shared, not yours) compiles unchanged.
- `data/dio_offers_repository.dart` `_parseSnapshot`: read `requestData['title']` (trimmed,
  empty→null), pass through. No new call — `fetchOffers` already GETs `/v1/requests/:id`.
- `data/fake_offers_repository.dart`: surface a demo title.
- `application/`: carry `requestTitle` onto `ClientOffersState` (field + `copyWith` + `props`)
  via `_emitSnapshot`.
- One added case in `test/dio_offers_repository_test.dart` (or `test/features/` twin) for title parse.

**Task 4 — State + cubit.**
- `OfferSortMode` gains `best`; state default becomes `OfferSortMode.best`. This is a **product
  change** (which offer the customer sees first) — flag it in the PR notes.
- `_sortOffers` (`client_offers_cubit.dart:392-408`) gains a `best` branch delegating to
  `rankByBestValue`.
- Derived getters on the state: `String? get bestValueOfferId => bestValueOfferId(offers)`-style
  (no stored fields), `fastestOfferId` likewise.
- Meter denominator: new stored `Duration? windowTotal` (+ `copyWith` + `props`); cubit keeps
  `windowTotal = max(windowTotal, windowRemaining)` across emits. Documented contract in a short
  comment: zero = true server deadline; 100% = largest remaining observed this session. **Do not
  invent a window constant.** The strip must render track-only when `windowTotal` is null.
- Update `client_offers_cubit_test.dart:~53`: default-sort assertion `byPrice` → `best` (this
  test is the documentation of the product change).

**Task 5 — `offer_window_timer.dart`: rebuild IN PLACE.** Do not move, rename, or delete the file
— `no_raw_semantic_colors_test.dart:21` greps this exact path, and bans `.tertiary*`, `Color(0x`,
`Colors.*` inside it.
- New params: `offerCount` (int), `progress` (double?, null → track-only). Keep `remaining`,
  `expired`.
- Container: margin-top `Spacing.medium`, horizontal gutter `Spacing.xLarge` (applied by the
  host), padding `EdgeInsets.symmetric(horizontal: Spacing.medium, vertical: Spacing.small)`,
  `OmdsBorderRadius.medium`, normal fill `colorScheme.surfaceContainerHigh`.
- Row: Ø`Spacing.xSmall` dot (`jeebRoles.accent`) → `Expanded(Text(l10n.offersWindowStrip(count,
  CountdownFormat.format(remaining))))` in `jeebText.bodySmall.copyWith(fontWeight:
  FontWeight.w700)` + `FontFeature.tabularFigures()`, ink `colorScheme.onSurface` → meter
  (kit `JeebMeter` or stand-in): 70×5 r9, track `colorScheme.surfaceContainerHighest`, fill
  `jeebRoles.accent`, fraction clamped 0–1.
- **KEEP the role branches** (`:26-38`): expired → `errorContainer`/`onErrorContainer` +
  `l10n.offersWindowExpired`, meter hidden; urgent (≤30s) → `warningContainer`/
  `onWarningContainer`. These are a sprint-009 semantic fix; the board only draws the normal
  state.
- Keep `Key('offer-window-timer')`; add `Semantics(identifier: 'offer_review_window_strip')`.
- Rewrite `test/offer_window_timer_test.dart` (3 tests): normal renders the merged strip string;
  **the expired case must still assert the exact text `Offer window expired`** (also pinned at
  `client_offers_screen_test.dart:594`); add a null-`progress` track-only case.

**Task 6 — `offer_sort_bar.dart`: 2 chips → 3, label deleted.**
- Delete the `Text(l10n.offersSortLabel)` prefix (`:32-38`). Key stays in the ARBs — you cannot
  edit ARBs, and retiring a key is not your call.
- Three chips in a Row, `Spacing.xSmall` gaps: **Best** (`offersSortByBest`, new), **Lowest
  price**, **Top rated**. Selected: `colorScheme.primary` fill, `onPrimary` ink, w700.
  Unselected: white fill, `UIConstants.strokeWidthThin` (1.5) `colorScheme.outline` border,
  `colorScheme.onSurfaceVariant` ink, w600. Pill radius (`OmdsBorderRadius.pill`).
- Keep each chip inside `MinTapTarget` and keep the
  `Semantics(identifier/button/selected/label/onTap) → ExcludeSemantics` idiom verbatim. Keys
  `offer-sort-price` / `offer-sort-rating` survive; add `offer-sort-best` + id
  `offer_review_sort_best`.
- The visual capsule MUST render strictly under 48dp (~33dp at `8/15` padding) — this is what
  flips the pre-existing red hit-target test green.

**Task 7 — `offer_card.dart`: re-anatomise to two rows.** Class name, constructor, and every
identifier/key/type in §1 survive.
- Row 1 (gap `Spacing.small`): `OmdsProfileAvatar` (keep `Sizes.fourXLarge`; Ø42 is a kit-lane
  concern) → `Expanded(Column: name + optional Fastest chip; meta line)` → end-aligned money
  `Column(crossAxisAlignment: CrossAxisAlignment.end)`: price then ETA.
  - Name: `jeebText.cardTitle`, `colorScheme.onSurface`, **no underline** (delete `:568-570`'s
    `TextDecoration.underline`); keep `_NameTapTarget`'s `button: true` semantics + 48dp
    `ConstrainedBox` + `Key('offer-card-name-<name>')`.
  - Meta line: `Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: Spacing.twoXSmall)`
    of `OmdsStarRatingDisplay(averageRating:, starCount: 1, totalReviews: ratingCount,
    reviewsLabelBuilder: (c) => '$c', ratingTextStyle/reviewCountTextStyle:
    jeebText.bodySmall …onSecondaryContainer)` — the widget itself adds the parentheses
    (`omds_star_rating_display.dart:94`), so `'$c'` renders `(132)` and `find.text('4.7')` /
    `find.text('(132)')` keep resolving. Then a `·` separator `Text` and the vehicle label as its
    **own `Text`** so `find.text('Motorcycle')` resolves. Keep `_NoRatingsYet` (+ its id) for
    `ratingCount == 0`. Add `// TODO(redesign-24): needs gateway distanceKm — omitted, not faked.`
  - Money column: price = bare `Text` in `jeebText.price` + `colorScheme.onSurface`, wrapped in
    the existing `_IdWrap(_price)`; **delete `_FeePill` (`:629-661`)**. ETA below it =
    `l10n.offersCardEtaMinutes(...)` in `jeebText.caption` + `onSecondaryContainer`, wrapped in
    the existing `_IdWrap(_eta)`; **delete both `_MetaChip`s (`:663-701`)**.
- Optional note line: unchanged position/ids (`_OfferNoteLine` + `_IdWrap(_note)`).
- Row 2 (`SizedBox(height: Spacing.small)` above): `Expanded` cash line (`offerCardCashOnDelivery`,
  `jeebText.caption`, `onSecondaryContainer`, keep the `_IdWrap(_cash_on_delivery_label)`) +
  Accept pill. The pill stays an **`OmdsPrimaryButton`** under `Key('offer-card-accept-<id>')`
  with `isEnabled`/`onTap`/`icon: loading ? OmdsButtonLoading() : null` exactly as today — only
  drop the `SizedBox(width: double.infinity)` so it hugs. Recommended card: default (navy) filled
  variant. Every other card: `variant: OmdsButtonVariant.outlined`. Keep the `acceptDisabled` /
  `isAccepting` threading — it is the B-01 double-accept guard.
- Card shell: keep `Card`, `elevation: UIConstants.elevationNone`; border becomes
  `colorScheme.outline` @ `UIConstants.strokeWidthThin` (today's `outlineVariant` at `:131` is
  the divider role — fix it); radius `OmdsBorderRadius.large`. Recommended card
  (`offer.id == bestValueOfferId`): `colorScheme.primary` @ `UIConstants.strokeWidthNormal`.
  New card params: `isBestValue`, `isFastest` (host computes from state getters).
- `Best value` badge: `Stack(clipBehavior: Clip.none)` around the Card +
  `PositionedDirectional(end: Spacing.medium, top: -(Spacing.xSmall + 1))` — never `right:`.
  Pill, fill `jeebRoles.accent`, ink `jeebRoles.onAccent`, `jeebText.badge`. Ids per §1.
- `Fastest` chip inline after the name: pill, `colorScheme.surfaceContainerHigh` fill,
  `onSurface` ink, `jeebText.badge`. Ids per §1.
- Append the badge strings to the composed `semanticLabel` the way the note already is
  (`offer_card.dart:114-116`) — do not mint a new label key.
- Avatar fills (render vocabulary, small and optional to reverse): rotate
  `backgroundColor` by index `[colorScheme.primary, colorScheme.onSecondaryContainer]` with
  `initialColor: colorScheme.onPrimary`; when `ratingCount == 0` use
  `surfaceContainerHighest` + `onSecondaryContainer` initial (the R11 "unknown" treatment bound
  to a fact the app holds). Never touch the `initial` derivation — two tests match on it.
- 200% text discipline (`offer_card_overflow_test.dart` pins 411dp): identity column `Expanded`,
  money column `Flexible` + `TextAlign.end`, name/price `maxLines: 1` + ellipsis, meta line a
  `Wrap`, cash line `Expanded` + `maxLines: 2` + ellipsis.
- Card rhythm: margin `EdgeInsetsDirectional.only(bottom: Spacing.small)` (R12: lists breathe at
  9–12px).
- Extend `test/offer_card_test.dart` only additively: badge-present/absent cases and one `ar`
  pump of the badge row (`PositionedDirectional` mirroring). The existing 13 tests must pass
  unchanged.

**Task 8 — `client_offers_screen.dart`: restructure.**
```
Scaffold(                                            // NO appBar — delete OMDSAppBar (:146-153)
  body: Semantics(identifier: 'offer_review_list_root', explicitChildNodes: true,   // ALL states, as today
    child: SafeArea(bottom: false,                   // top inset only — see below
      child: BlocBuilder<ClientOffersCubit, ClientOffersState>(
        builder: (context, state) => Column(children: [
          _OfferReviewTopBar(                        // kit JeebTopBar or private stand-in
            title: l10n.offersScreenTitle,
            subtitle: state.requestTitle,            // null → line not rendered, never a placeholder
            onBack: () => context.canPop() ? context.pop() : context.go('/'),  // carry over VERBATIM (P2 fix)
          ),
          Expanded(
            key: const Key('offer-review-content'),  // one key, present in every state
            child: switch (state.status) { initial/loading → OmdsLoadingState,
                                           failed → existing Center+ConstrainedBox+OmdsErrorState block,
                                           loaded → _LoadedBody(...) }),
        ]),
      ))))
```
- Top bar: padding `Spacing.small`/`Spacing.xLarge`/0, gap `Spacing.small`; Ø`Spacing.threeXLarge`
  `colorScheme.surfaceContainerHigh` circle with `DirectionalIcons.back(context)` in
  `colorScheme.onSurface`; `Semantics(identifier: 'offer_review_back', button: true)` +
  `MinTapTarget`; title `jeebText.h2`; subtitle `jeebText.bodySmall` +
  `colorScheme.onSecondaryContainer`.
- `_LoadedBody` becomes: `Column[ OfferWindowTimer?, closed banner?, error banner?, OfferSortBar,
  Expanded(OmdsPullToRefresh(ListView(key: 'offer-list'))), _Footer? ]`.
  - Strip mount condition **unchanged**: `state.windowExpiresAt != null || state.requestIsExpired`
    (`client_offers_screen_test.dart:556` asserts absence for a deadline-less live payload).
  - Banners move out of the list into the fixed header; keep `Key('offer-request-closed-banner')`,
    `Key('offer-error-banner')`, the `offer_review_error_dismiss_cta` Semantics block verbatim,
    and radius → `OmdsBorderRadius.medium`. Use kit `JeebInfoNote` if landed, else keep the
    existing private `_Banner`/`_ErrorBanner` restyled — do NOT hand-roll a third variant.
  - ListView: keep `AlwaysScrollableScrollPhysics` + `OmdsPullToRefresh`; padding
    `EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.small, Spacing.xLarge,
    Spacing.medium)` — the `Spacing.small` top keeps the first card's −9 badge overhang unclipped;
    gutters go 16→24 per the board. **Do not shrinkWrap, do not Center anything into the
    remainder** — `Expanded(ListView)` lays children top-aligned and leaves the rest white, which
    is the render (R1); >3 offers still scroll.
  - Delete the section header `Text(l10n.offersPanelHeader)` (`:266-269`) — no test asserts it.
  - Empty state stays the ListView's only child (`Key('offer-empty-state')`), top-padded, never
    centred.
- Footer (docked, outside the scroll): render guard **unchanged** `if (state.hasOffers &&
  state.requestIsOpen)` — `client_offers_screen_test.dart:~594-607` asserts the cancel CTA is
  absent on a terminal snapshot. Structure: `Padding(EdgeInsetsDirectional.fromSTEB(Spacing.xLarge,
  0, Spacing.xLarge, Spacing.twoXLarge + context.scrollBodyBottomInset))` over a centred Column:
  `Semantics(identifier: 'offer_review_only_one_note', child: Text(l10n.chatOfferAcceptOnlyOne,
  style: jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700), color: jeebRoles.accent))`,
  `SizedBox(height: Spacing.small)`, then the existing `offer_review_cancel_cta` Semantics block
  **verbatim** (`:310-324`) with the `OmdsPrimaryButton(variant: text)` restyled via
  `textColor: colorScheme.onSurfaceVariant`.
- `SafeArea(bottom: false)` is load-bearing: with `bottom: true` the inset is consumed and
  `context.scrollBodyBottomInset` (= `MediaQuery.viewPadding.bottom`,
  `lib/core/layout/bottom_inset.dart:86`) returns 0, silently dropping the 48dp Android-nav
  clearance.
- Card mapping adds `isBestValue: entry.value.id == state.bestValueOfferId`,
  `isFastest: entry.value.id == state.fastestOfferId`. `_openAcceptSheet` / `_openJeeberProfile`
  / `_openCancelSheet` bodies are untouched.

**Task 9 — `client_offers_screen_test.dart` updates (mechanism changed, contracts kept):**
- Sort-chip hit-target test (`:152-190`): swap `find.byType(OmdsChip)` for the new chip type;
  keep BOTH assertions (target ≥ `UIConstants.buttonHeight`; visual < target). Expected red→green
  flip of a `_BASELINE.md` failure — say so in the report.
- First-paint (`:70`) and sort-toggle (`:108`) tests: with `best` as default, tap
  `Key('offer-sort-price')` first, then assert price order — the tests then state what they mean.
- Bottom-padding test (`:255-321`): the first assertion (`listView.padding.bottom ==
  Spacing.xLarge + 48`) targets a mechanism that no longer exists; replace with an assertion on
  the footer's resolved bottom padding (`Spacing.twoXLarge + inset`). **Keep the second half
  verbatim** — `screenBottom − ctaRect.bottom ≥ Spacing.xLarge + 48` is the user-facing contract.
- Centred-error test (`:342-375`): retarget the centring anchor from
  `offer_review_list_root` (now spans the top bar) to `find.byKey(Key('offer-review-content'))`.
  Keep the width and retry-height assertions.
- Add: badge lands on the ranked-first card + absent for a single-offer list; strip shows count.

**Task 10 — Gates.** `flutter analyze` (bar: the same 5 infos, nothing new);
`flutter test test/offer_card_test.dart test/offer_window_timer_test.dart
test/client_offers_cubit_test.dart test/client_offers_screen_test.dart test/features/client_offers/
test/dio_offers_repository_test.dart test/core/theme/no_raw_semantic_colors_test.dart
test/decision_violations_test.dart`; `bash tool/check_design_tokens.sh`;
`grep -rn "identifier:" lib/features/client_offers/` diffed against §1. Note in the report which
steps were blocked on the l10n wiring batch.

---

## 4. Stop conditions

**Done means:** the four lane files + state/cubit/domain/data additions match §3; every §1
identifier/key/type greps identically; the suites in Task 10 are green (modulo the l10n-wiring
compile dependency, reported); zero new analyze issues; token script clean; the sort-chip
baseline flip and the `best`-default product change are called out in the report.

**Do NOT touch:** `offer_accept_sheet.dart` (copy pinned by `offer_accept_sheet_tense_test.dart`);
`lib/core/router/app_router.dart`; `lib/core/di/injection_container.dart`; `lib/core/theme/*`;
`lib/l10n/*`; `pubspec.yaml`; `test/support/*`; `lib/devtool/*`; `lib/core/widgets/*` (request,
don't create); any other feature; the other three `_BASELINE.md` failures. Do not rename/move
`offer_window_timer.dart`. Do not add opacity/dimming to any card. Do not add a mock window
total, a distance value, a destination line, or any endpoint/field the wire does not carry.

---

## 5. Explicitly out of scope (cut from the original proposal)

- "usually replies in 1 min" — belongs to screen 21; never on this board.
- `JeebOutlinedCard` / `JeebAvatar` consumption — card is bespoke per plan §5; avatar stays
  `OmdsProfileAvatar`.
- Any `dormant` card state.
- Retiring `offersPanelHeader` / `offersSortLabel` / `offersWindowRemaining` from the ARBs —
  integrator's call; this lane merely stops calling them.

---

## 6. Wiring requests — final text for `docs/redesign-2026-08/wiring/11-offers.md`

### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart
need: three new strings and one six-branch plural family for the offers screen redesign.
exact change:
app_en.arb —
```json
  "offersSortByBest": "Best",
  "@offersSortByBest": { "description": "Third offer-review sort chip (offer_review_sort_best): composite best-value ranking (fee asc, rating desc, ETA asc)." },
  "offersCardBestValueBadge": "Best value",
  "@offersCardBestValueBadge": { "description": "Solid-orange badge on the top-ranked offer card (offer_card_<n>_best_value_badge). Suppressed for single-offer lists." },
  "offersCardFastestBadge": "Fastest",
  "@offersCardFastestBadge": { "description": "Muted pill after the Jeeber name on the unique-lowest-ETA card (offer_card_<n>_fastest_badge)." },
  "offersWindowStripZero": "No offers yet · window closes in {time}",
  "offersWindowStripOne": "1 offer in · window closes in {time}",
  "offersWindowStripTwo": "2 offers in · window closes in {time}",
  "offersWindowStripFew": "{count} offers in · window closes in {time}",
  "offersWindowStripMany": "{count} offers in · window closes in {time}",
  "offersWindowStripOther": "{count} offers in · window closes in {time}",
  "@offersWindowStripOther": { "description": "Offer-review countdown strip (offer_review_window_strip): live offer count + server-deadline countdown. Six Arabic CLDR plural branches; English reuses one/other. {time} is CountdownFormat output.", "placeholders": { "count": { "type": "int", "example": "3" }, "time": { "type": "String", "example": "4:12" } } },
```
app_ar.arb —
```json
  "offersSortByBest": "الأفضل",
  "offersCardBestValueBadge": "أفضل قيمة",
  "offersCardFastestBadge": "الأسرع",
  "offersWindowStripZero": "لا عروض بعد · تُغلق المهلة خلال {time}",
  "offersWindowStripOne": "وصل عرض واحد · تُغلق المهلة خلال {time}",
  "offersWindowStripTwo": "وصل عرضان · تُغلق المهلة خلال {time}",
  "offersWindowStripFew": "وصلت {count} عروض · تُغلق المهلة خلال {time}",
  "offersWindowStripMany": "وصل {count} عرضًا · تُغلق المهلة خلال {time}",
  "offersWindowStripOther": "وصل {count} عرض · تُغلق المهلة خلال {time}",
```
app_localizations.dart (house pattern, matches `pendingCardOffersBadge` at :1852) —
```dart
  String get offersSortByBest => _get('offersSortByBest');
  String get offersCardBestValueBadge => _get('offersCardBestValueBadge');
  String get offersCardFastestBadge => _get('offersCardFastestBadge');
  String offersWindowStrip(int count, String time) {
    String branch;
    if (count == 0) {
      branch = _get('offersWindowStripZero');
    } else if (count == 1) {
      branch = _get('offersWindowStripOne');
    } else if (count == 2) {
      branch = _get('offersWindowStripTwo');
    } else {
      final mod = count % 100;
      branch = mod >= 3 && mod <= 10
          ? _get('offersWindowStripFew')
          : mod >= 11 && mod <= 99
              ? _get('offersWindowStripMany')
              : _get('offersWindowStripOther');
    }
    return branch
        .replaceFirst('{count}', '$count')
        .replaceFirst('{time}', time);
  }
```
why: the redesigned sort bar's third chip, the two ranking badges, and the merged
count-plus-countdown strip are all user-visible strings; the strip is plural-sensitive in Arabic
and must pass `qa/t-mob-fix-002/ar_plurals_check.sh`.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_select_chip.dart (Wave-1 kit, when created)
need: the `sort`-role chip must render its visual capsule strictly under 48dp while wrapped in
`MinTapTarget`, accept a `Key`, and stay `find.byType`-addressable.
exact change: `JeebSelectChip(role: JeebChipRole.sort)` → capsule padding 8/15, pill radius,
selected `colorScheme.primary`+`onPrimary` w700, unselected white + 1.5px `colorScheme.outline` +
`onSurfaceVariant` w600; no internal min-height of 48.
why: `client_offers_screen_test.dart:152-190` (a `_BASELINE.md` pre-existing red this screen is
expected to fix) asserts the capsule is shorter than its 48dp hit target; `OmdsChip` renders at
exactly 48 and fails it.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_top_bar.dart (Wave-1 kit, when created)
need: `subtitle` (String?, line omitted when null) and `identifier` (String, applied to the back
circle's Semantics) parameters; back glyph via `DirectionalIcons.back(context)` — note it is a
method taking BuildContext, not a constant.
exact change: `JeebTopBar({required String title, String? subtitle, required String identifier,
required VoidCallback onBack, ...})`.
why: screen 11 renders `offersScreenTitle` + the request title as a subtitle and needs
`offer_review_back` on the circle; the screen ships a private stand-in until this exists.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_meter.dart (Wave-1 kit, when created)
need: a nullable `value` — null renders the track with no fill (never a fabricated fraction).
exact change: `JeebMeter({double? value, double width = 70, double height = 5})`, track
`surfaceContainerHighest`, fill `jeebRoles.accent`, r9.
why: screen 11's window meter has no server-carried window total on some paths
(`windowTotal` is session-observed); the honest degraded state is track-only.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_info_note.dart (Wave-1 kit, when created)
need: an `error` tone (the plan's tone list is muted/success/accent only) and a trailing-action
slot that can host an identified dismiss button.
exact change: add `JeebInfoNoteTone.error` → `colorScheme.errorContainer`/`onErrorContainer`,
and a `Widget? trailing` slot.
why: screen 11's fixed-header error banner keeps `offer_review_error_dismiss_cta` and re-tints to
Wave 0's soft `errorContainer`; without an error tone the screen must keep a private banner.
