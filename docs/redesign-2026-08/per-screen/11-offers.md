# 11 · Offers — change proposal

Lane: Wave 3 · feature dir `lib/features/client_offers/`
Design: `screens/11-offers.{png,html,note.md}`
Route: `/requests/:id/offers` (name `offer-review`), already registered — **no new route**
Verdict: **rebuild** (the presentation tree is rewritten in place; domain/data/cubit survive, with three
additive changes named in §5)

---

## 0. Files this lane owns

| File | Fate |
|---|---|
| `presentation/client_offers_screen.dart` (512) | rebuilt body: app bar → in-body top bar, list → fixed header + `Expanded` list + docked footer |
| `presentation/widgets/offer_card.dart` (702) | re-anatomised in place (class name and every identifier survive) |
| `presentation/widgets/offer_sort_bar.dart` (77) | rebuilt: 2 chips → 3, OMDS chip → `JeebSelectChip(role: sort)` |
| `presentation/widgets/offer_window_timer.dart` (74) | rebuilt into the countdown **strip**. ⚠️ **DO NOT MOVE OR DELETE THIS FILE** — `test/core/theme/no_raw_semantic_colors_test.dart:21` lists it and asserts the path exists |
| `presentation/widgets/offer_accept_sheet.dart` (450) | **not in scope** — the board does not draw the sheet, and its copy is pinned by `offer_accept_sheet_tense_test.dart` |
| `application/client_offers_state.dart`, `client_offers_cubit.dart` | additive only (§5) |
| `domain/offer_ranking.dart` | **NEW** — pure Dart, no Flutter import (`40_GUARDRAILS_ARCH §1`) |
| `domain/offers_repository.dart`, `data/dio_offers_repository.dart` | one additive field (§5.4) |

Constructor seams (`repository`, `cancelRepositoryOverride`, `cubitFactory`) are load-bearing —
`lib/devtool/catalog/entries/batch_02_entries.dart:256–294` mounts five `ClientOffersScreen` variants
through them. Do not change the signature.

---

## 1. Semantics inventory — FROZEN

Every value below is emitted today and **must still be emitted** after the rebuild
(`grep -rn "identifier:" lib/features/client_offers/`, 2026-08-03):

| Identifier | Where today | Where after |
|---|---|---|
| `offer_review_list_root` | screen body wrapper | unchanged — wraps the whole `Column` |
| `offer_review_cancel_cta` | last ListView child | the docked footer's second line |
| `offer_review_error_dismiss_cta` | `_ErrorBanner` close button | the fixed-header error note |
| `offer_review_sort_price` | `OfferSortBar` | chip 2 of 3 |
| `offer_review_sort_rating` | `OfferSortBar` | chip 3 of 3 |
| `offer_card_<index>` / `offer_card_<jeeberId>` | `_DualId` card root | unchanged |
| `…_name` | `_NameTapTarget` | the navy name text (underline dropped, `button: true` kept) |
| `…_price` | `_FeePill` | the bare navy `$8.00` in the money column |
| `…_eta` | ETA `_MetaChip` | the `in {n} min` sub-line under the price |
| `…_cash_on_delivery_label` | cash row | the action-row cash line |
| `…_note` | note line | unchanged position (above the action row) |
| `…_accept_cta` | full-width CTA | the inline Accept pill |
| `offer_card_no_ratings` | `_NoRatingsYet` | unchanged (meta line) |
| `offer_accept_*` (7 values) | accept sheet | untouched |

Maestro depends on `offer_review_list_root` (4 flows), `offer_card_0`, `offer_card_0_price`,
`offer_card_0_eta`, `offer_card_0_cash_on_delivery_label`, `offer_review_sort_price`,
`offer_card_0_name`, `offer_card_0_accept_cta`, `offer_review_cancel_cta`
(`.maestro/flows/jm-028-offer-review.yaml`, `jm-029`, `jm-026`, `jm-027`, `jm-032`). Maestro is **not
in CI** — a silently dropped id rots undetected.

### New identifiers (convention `<screen>_<element>`)

| New id | Element |
|---|---|
| `offer_review_back` | in-body top-bar back circle (replaces the un-identified `OMDSAppBar` back) |
| `offer_review_window_strip` | the countdown strip (currently only `Key('offer-window-timer')`) |
| `offer_review_sort_best` | the new third sort chip — extends the AC's `offer_review_sort_<key>` pattern |
| `offer_card_<index>_best_value_badge` / `offer_card_<jeeberId>_best_value_badge` | the orange `Best value` tab |
| `offer_card_<index>_fastest_badge` / `offer_card_<jeeberId>_fastest_badge` | the `Fastest` chip |
| `offer_review_only_one_note` | the orange `Accept only one offer.` footer line |

Badges are non-interactive but get ids for the same reason `offer_card_no_ratings` has one: they are
the assertable evidence that the ranking rendered.

---

## 2. Layout & structure

### 2.1 The single biggest change: the list stops being the screen

Today `_LoadedBody` is **one `ListView`** holding the timer, banners, a section header, the sort bar,
every card, and the Cancel CTA (`client_offers_screen.dart:226-328`). Everything scrolls; nothing is
docked; with three offers the list stretches to fill the viewport.

The board is `column → fixed header → flex:1 list → docked footer` (R1). Target:

```
Scaffold(
  body: Semantics(identifier: 'offer_review_list_root', explicitChildNodes: true,
    child: SafeArea(bottom: false,                       // top inset only — see §2.6
      child: Column(children: [
        _OfferReviewTopBar(...),                          // in-body, was OMDSAppBar
        OfferWindowTimer(...),                            // strip, gutter 24
        _ClosedBanner / _ErrorNote,                       // fixed, no longer list items
        OfferSortBar(...),                                // 3 chips, gutter 24
        Expanded(                                         // ← the flex:1 spacer
          key: const Key('offer-review-content'),
          child: OmdsPullToRefresh(child: ListView(key: Key('offer-list'), ...)),
        ),
        _OfferReviewFooter(...),                          // docked textStack
      ]),
    ),
  ),
)
```

`Expanded(ListView)` is the correct reading of R1 for a variable-length list: children lay out
top-aligned and the remainder stays plain white, exactly as the render shows, while >3 offers still
scroll. **Do not `shrinkWrap` and do not `Center` anything into the remainder.**

**Design evidence:** `11-offers.html:86` `<div style="flex: 1 1 0%">` between the card column and the
footer; the render's bottom ~40% is empty white below the third card.

### 2.2 App bar → in-body top bar (`JeebTopBar`, `leading: back`)

`client_offers_screen.dart:146-153` `OMDSAppBar(title: l10n.offersScreenTitle, showBackButton: true,
onBackPressed: () => context.canPop() ? context.pop() : context.go('/'))` is **deleted**.

Replace with the kit `JeebTopBar(leading: JeebTopBarLeading.back, identifier: 'offer_review_back',
title: l10n.offersScreenTitle, subtitle: state.requestTitle, onBack: …)` — padding `12/24/0`, gap 12,
Ø40 `colorScheme.surfaceContainerHigh` circle, 20px navy `DirectionalIcons.back` glyph, title
`context.jeebText.h2`, subtitle `jeebText.bodySmall` in `colorScheme.onSecondaryContainer`.

**Carry the `onBackPressed` body over verbatim.** It is a P2 fix: this screen is a push-tap stack ROOT
(`go`, not `push`), so `maybePop()` is a dead arrow. `'offer-review': '/'` is also in
`AppRouter.backFallbacks:466`, which handles *system* back — the two are not redundant.

**Design evidence:** `11-offers.html:15-21` — the back circle and title are ordinary flow children with
`padding: 14px 24px 0`, not a bar. No `AppBar` chrome appears in the render.

**Copy divergence, deliberate:** the board's title is `Offers`; keep `offersScreenTitle`
(*"Choose a Jeeber"* / *"اختر جِيبرًا"*). It states the user's job, it is already translated, and the board's
"Offers" duplicates the strip directly beneath it, which already says "3 offers in". One-line reversal
if the owner wants literal parity.

### 2.3 Countdown badge → countdown strip (`offer_window_timer.dart`, rebuilt in place)

Today: a shrink-wrapped pill with a clock glyph and `Window: 2:05 left`.
Target: a full-width strip — `[● orange dot] [3 offers in · window closes in 4:12] [meter]`.

- container: margin-top `Spacing.medium`, gutter `Spacing.xLarge`, padding
  `EdgeInsets.symmetric(horizontal: Spacing.medium, vertical: Spacing.small)`,
  `OmdsBorderRadius.medium`, fill `colorScheme.surfaceContainerHigh`
- dot: Ø`Spacing.xSmall` circle, `context.jeebRoles.accent`
- text: `Expanded`, `jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700)`, ink `colorScheme.onSurface`
- meter: `JeebMeter(value: progress, width: 70, height: 5)` — track `surfaceContainerHighest`, fill
  `jeebRoles.accent`

Keep `Key('offer-window-timer')`; add `Semantics(identifier: 'offer_review_window_strip')`.

**Keep the existing urgent/expired role logic** (`offer_window_timer.dart:26-38`). The board only draws
the normal state; the `warningContainer` (≤30 s) and `errorContainer` (expired) variants are a
sprint-009 semantic-role fix, not legacy styling. Apply the board's treatment to the **normal** state
only, and keep `FontFeature.tabularFigures()` so the digits do not jitter.

Keep the mount condition `if (state.windowExpiresAt != null || state.requestIsExpired)` exactly as it
is (`client_offers_screen.dart:238`). `client_offers_screen_test.dart:556` asserts the strip is absent
for a live gateway payload that carries no deadline, and manufacturing one is precisely what the
sibling waiting screen refuses to do (`WaitingFailure.contractViolation`).

**Design evidence:** `11-offers.html:23-27` — `margin: 16px 24px 0; padding: 11px 16px; border-radius:
14px; background: var(--jeeb-surface-high)`, Ø8 `--jeeb-orange` dot, 13/w700 navy text, and a
`70×5 r9` track with a `65%` `--jeeb-orange` fill.

### 2.4 Sort bar: 2 chips → 3, label deleted

- Delete the `Text(l10n.offersSortLabel)` prefix (`offer_sort_bar.dart:32-38`). The board has no label;
  the chips are self-describing. (`offersSortLabel` stays in both ARBs, unused — do not delete an
  l10n key from a lane.)
- Three `JeebSelectChip(role: JeebChipRole.sort)` in a `Row` with `Spacing.xSmall` gaps and
  `Spacing.xLarge` gutters: **Best** (new), **Lowest price** (`offersSortByPrice`), **Top rated**
  (`offersSortByRating`).
- Selected: `colorScheme.primary` fill + `colorScheme.onPrimary` 12.5/w700. Unselected: white,
  `1.5px colorScheme.outline` (`UIConstants.strokeWidthThin`), ink `colorScheme.onSurfaceVariant`.
- Keep each chip wrapped in `MinTapTarget` and keep the `Key('offer-sort-price')` /
  `Key('offer-sort-rating')` keys; add `Key('offer-sort-best')`.
- Keep the `Semantics(identifier:, button:, selected:, label:, onTap:) → ExcludeSemantics` idiom
  verbatim — three tests address these by identifier and by key.

**This fixes a currently-red test.** `client_offers_screen_test.dart:181-190` asserts the visual capsule
is *shorter* than the 48 dp hit target; `OmdsChip` renders at exactly `48.0`, so `lessThan(48.0)` fails
(verified by running the suite: `Expected: a value less than <48.0> / Actual: <48.0>`). This is one of
the four `_BASELINE.md` pre-existing failures. A `sort`-role chip is `8+8+~16 ≈ 32 dp` tall inside a
48 dp `MinTapTarget`, which is exactly what the assertion was written for. See §8.

**Design evidence:** `11-offers.html:28-32` — `padding: 8px 15px; border-radius: 999px`, selected =
`--jeeb-navy` fill + white 12.5/w700, unselected = `1.5px --jeeb-brown-outline` +
`--jeeb-brown-subtitle` 12.5/w600. Three chips, no label.

### 2.5 Card anatomy

Today the card is a 5-row stack: avatar+name row → rating/fee `Wrap` → ETA/vehicle chip `Wrap` → note →
cash row → full-width Accept.

Target (`11-offers.html:35-52`) is **two rows**:

```
Row(  gap 12
  OmdsProfileAvatar Ø42
  Expanded( Column( name 15.5/w700 navy [+ Fastest chip]
                    meta: ★ 4.9 (127) · Motorcycle   12/w600 periwinkle ) )
  Column( crossAxisAlignment.end
          $8.00      21/w800 navy      ← jeebText.price
          22 min ETA 11.5/w600 periwinkle ← jeebText.caption )
)
[ note line, when present ]
SizedBox(height: Spacing.small)          ← the board's margin-top: 12
Row( Expanded(cash line 11.5/w600 periwinkle)  Accept pill )
```

Deleted: `_FeePill` (the price is bare navy text, not a `primaryContainer` capsule), both `_MetaChip`s
(the ETA becomes the money column's sub-line; the vehicle moves into the meta line), the full-width
Accept, and the name's `TextDecoration.underline`.

Preserved: `OmdsProfileAvatar` (two tests match on its type + `initial`), `OmdsStarRatingDisplay`,
`OmdsPrimaryButton` under `Key('offer-card-accept-<id>')` (three tests read `.isEnabled` off it), the
`_DualId` / `_IdWrap` identifier scaffolding, and the honest `hasRatings` / `displayNameOrNull` guards.

**The meta line, exactly.** `OmdsStarRatingDisplay(averageRating:, starCount: 1, showRatingValue: true,
totalReviews: ratingCount, showReviewCount: true, reviewsLabelBuilder: (c) => '$c', spacing:
Spacing.twoXSmall, ratingTextStyle: …, reviewCountTextStyle: …)` renders `★ 4.9 (127)` in one widget —
`starCount: 1` because the board draws **one** star, not five (today's card renders five). Then a
`·` separator and the vehicle label as its own `Text`, so `find.text('Motorcycle')` keeps resolving.

**The board's "3 km away" has no source** — no distance field exists anywhere on the offer DTO, the
wire row, or the request row. Put the vehicle in that slot instead: it is real, decision-relevant data
(a bicycle cannot carry a fridge), it occupies the same dot-separated periwinkle qualifier position,
and it keeps the card from losing information the redesign never intended to delete. Leave
`// TODO(redesign-24): needs gateway distanceKm — omitted, not faked.`

**Emphasis levels.** Two, not three (see §9-C4):

| Level | Applies to | Treatment |
|---|---|---|
| recommended | `offer.id == state.bestValueOfferId` | `JeebOutlinedCard(border: 2px colorScheme.primary)` (`UIConstants.strokeWidthNormal`) + the `Best value` badge + a **navy filled** Accept |
| normal | everything else | `JeebOutlinedCard(border: 1.5px colorScheme.outline)` + an **outlined** Accept |

Today's border is `colors.outlineVariant` (`offer_card.dart:131`) — that is the 1 px divider role. The
board's card border is warm brown `#916F66` = `colorScheme.outline`. Fix it.

**The `Best value` badge** is a `PositionedDirectional(end: 14, top: -9)` child of a
`Stack(clipBehavior: Clip.none)` — `end`, never `right`, so it mirrors under `ar`. Padding `3/10`,
`OmdsBorderRadius.pill`, fill `jeebRoles.accent`, ink `jeebRoles.onAccent`, style `jeebText.badge`.
Give the ListView `Spacing.small` top padding so the −9 overhang of the first card never clips against
the viewport edge.

**The `Fastest` chip** sits inline after the name: padding `2/8`, pill, fill
`colorScheme.surfaceContainerHigh`, ink `colorScheme.onSurface`, style `jeebText.badge`.

**200 % text safety** (`offer_card_overflow_test.dart` pins this at 411 dp): the identity column is
`Expanded`, the money column is `Flexible` with `TextAlign.end`, name and price are `maxLines: 1` +
`ellipsis`, the meta line is a `Wrap(crossAxisAlignment: WrapCrossAlignment.center)` so it can run onto
a second line, and the action row's cash line is `Expanded` with `maxLines: 2` + `ellipsis`.

**Money divergence, deliberate:** the board writes `$8`; the app writes `$8.00` through `MoneyFormat`
(the currency-unification lane, LTR-isolated for RTL). Keep `MoneyFormat` — it is pinned by
`offer_card_test.dart:35` and `client_offers_screen_test.dart:496,564`.

**ETA divergence, deliberate:** the board writes `in 40 mins`; reuse the existing
`offersCardEtaMinutes` (`{minutes} min ETA`, already in both ARBs and asserted twice). It carries the
same fact in the same slot and saves an ICU plural plus an `ar_plurals_check.sh` round-trip.

### 2.6 Footer: `textStack`, docked

`client_offers_screen.dart:301-325` (the last ListView child) becomes a docked
`JeebCtaFooter.textStack` outside the scroll view:

```
Padding( EdgeInsetsDirectional.fromSTEB(
           Spacing.xLarge, 0, Spacing.xLarge,
           Spacing.twoXLarge + context.scrollBodyBottomInset)
  Column( crossAxisAlignment.center
    Semantics(identifier: 'offer_review_only_one_note',
      Text(l10n.chatOfferAcceptOnlyOne,                       // exists, both locales
           style: jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700),
           color: context.jeebRoles.accent) )
    SizedBox(height: Spacing.small)
    <existing offer_review_cancel_cta block, unchanged>
  ))
```

`SafeArea(bottom: false)` in §2.1 is load-bearing: with `bottom: true` the inset is consumed and
`context.scrollBodyBottomInset` correctly returns 0, which would drop the 48 dp Android-nav clearance
that `client_offers_screen_test.dart:255-321` exists to protect.

Keep the render guard `if (state.hasOffers && state.requestIsOpen)` on the **whole footer** —
`client_offers_screen_test.dart:603` asserts the Cancel CTA is absent on a terminal snapshot.

Keep `OmdsPrimaryButton(variant: text)` under `Key('offer-review-cancel-cta')`; it defaults to a 48 dp
height, which the ≥48 dp test reads. Restyle via `textStyle: jeebText.body.copyWith(fontWeight:
FontWeight.w600)` and `textColor: colorScheme.onSurfaceVariant`.

**Design evidence:** `11-offers.html:87-90` — `padding: 0 24px 30px; text-align: center`, orange 12/w700
line, then a 14.5/w600 `--jeeb-brown-subtitle` link. No pill, no border.

### 2.7 Deleted outright

| Deleted | Line | Why |
|---|---|---|
| `Text(l10n.offersPanelHeader)` | `client_offers_screen.dart:266-269` | the board has no section header; the strip carries the count. No test asserts it |
| `_FeePill` | `offer_card.dart:629-661` | the board's price is bare navy type, not a `primaryContainer` capsule |
| `_MetaChip` ×2 | `offer_card.dart:663-701` | ETA → money sub-line, vehicle → meta line |
| name underline | `offer_card.dart:568-570` | the board's name is plain 15.5/w700 navy. `button: true` + the 48 dp `ConstrainedBox` remain the affordance |
| `Text(l10n.offersSortLabel)` | `offer_sort_bar.dart:32-38` | no label on the board |

### 2.8 Banners move out of the list

`_Banner` (request-closed) and `_ErrorBanner` become `JeebInfoNote` instances in the **fixed header**,
between the strip and the sort row — a closed-request notice that scrolls away is a defect. Keep
`Key('offer-request-closed-banner')`, `Key('offer-error-banner')`, and the
`offer_review_error_dismiss_cta` identifier. The error note's `colorScheme.errorContainer` now resolves
to Wave 0's soft `#FFDAD6` instead of the `#B00020` slab — that re-tint is the intended outcome, not a
regression.

### 2.9 Empty and failed states

- Empty (`OmdsEmptyState`, `Key('offer-empty-state')`): stays the ListView's only child with top
  padding. **Do not centre it into the spacer** — R1.
- Failed (`OmdsErrorState`, `Key('offer-load-error')`): keeps its `Center` + 300 dp `ConstrainedBox`,
  but now lives inside the `Expanded` so the top bar (and its back path) survives a cold-load failure.
  The `Expanded` carries `Key('offer-review-content')` so the "centred in the remaining body"
  assertion can retarget (§8).

---

## 3. Tokens

The screen is already hex-free; the work is **wrong role → right role** and **ad-hoc `copyWith` →
`jeebText`**.

| Current | Location | Becomes |
|---|---|---|
| `colors.outlineVariant` card border | `offer_card.dart:131` | `colorScheme.outline` @ `UIConstants.strokeWidthThin` (1.5) — recommended card: `colorScheme.primary` @ `strokeWidthNormal` (2) |
| `colors.primaryContainer` fee pill | `offer_card.dart:648` | deleted; price = `jeebText.price` + `colorScheme.onSurface` |
| `colors.surfaceContainerHighest` meta chips | `offer_card.dart:679` | deleted; `Fastest` chip = `colorScheme.surfaceContainerHigh` |
| `textTheme.titleMedium.copyWith(w600)` name | `offer_card.dart:567` | `jeebText.cardTitle` (15.5/w700) |
| `textTheme.titleMedium.copyWith(bold)` fee | `offer_card.dart:654` | `jeebText.price` (21/w800) |
| `textTheme.bodySmall` rating / count / cash / note | `offer_card.dart:383,421,462,203` | `jeebText.bodySmall` (12/w600) for the meta line, `jeebText.caption` (11.5/w600) for cash + ETA; ink `colorScheme.onSecondaryContainer` |
| `textTheme.labelMedium` chip label | `offer_card.dart:692` | n/a (deleted) |
| `textTheme.titleMedium` panel header | `client_offers_screen.dart:268` | deleted |
| `textTheme.labelLarge` sort label | `offer_sort_bar.dart:36` | deleted |
| `textTheme.labelMedium` countdown | `offer_window_timer.dart:64` | `jeebText.bodySmall.copyWith(w700)`, keep `FontFeature.tabularFigures()` |
| `OmdsBorderRadius.small` (12) strip/banners | `offer_window_timer.dart:47`, `client_offers_screen.dart:446,484` | `OmdsBorderRadius.medium` (16 ≈ board's 14) |
| `OmdsBorderRadius.medium` card | `offer_card.dart:130` | `OmdsBorderRadius.large` (20 ≈ board's 18) at feature level; exact 18 inside `JeebOutlinedCard` |
| star color | `OmdsStarRatingDisplay` default | already `context.omdsColorTokens.starRatingColor` — Wave 0 set it to `#FFC107` app-wide. **Never a literal** |
| orange (badge, dot, meter, footer note) | — | `context.jeebRoles.accent` / `.onAccent` only. `.tertiary*` is banned in `offer_window_timer.dart` by the gate test and is off-spec everywhere else |
| periwinkle | — | `colorScheme.onSecondaryContainer` |

**Do not use `JeebSemanticColors` on this screen.** It has no context extension, so the sanctioned
access is `Theme.of(context).extension<JeebSemanticColors>()!` — and `test/support/sync_app_localizations.dart:42`
builds every widget test on `ThemeData.light()`, where that bang **null-crashes**. `context.jeebText`
and `context.jeebRoles` both fall back safely (`jeeb_text_styles.dart:211`, `jeeb_color_roles.dart:265`);
`JeebSemanticColors` does not. Screen 11 needs none of `mutedSurface` / `readTick` / `accentTint` /
`accentRing` — periwinkle comes from `colorScheme.onSecondaryContainer`.

**Gate reminders:** `tool/check_design_tokens.sh` bans `Color(0x…)`, `Colors.*`, `fontSize:`,
`BorderRadius.circular(N)`, `EdgeInsets.<x>(<number>)` and `SizedBox(width|height: <number>)` anywhere
in `lib/features`. Design-exact px (18 radius, Ø42 avatar, 70×5 meter) belong **inside
`lib/core/widgets/jeeb/`**, which the script does not scan.

---

## 4. Shared components consumed

`lib/core/widgets/jeeb/` **does not exist yet** — Wave 1 has not landed. This screen is blocked on
steps 1, 2, 5, 6 and 7 of the plan's build order (§5.1).

| Kit widget | Replaces | Notes for the kit lane |
|---|---|---|
| `JeebTopBar(leading: back, trailing: none)` | `OMDSAppBar` | must accept a `subtitle` and an `identifier` for the back circle |
| `JeebOutlinedCard` | `Card(shape: RoundedRectangleBorder(side:))` | needs `borderColor` + `borderWidth` params so the recommended card is a 2 px navy variant, and a `Stack`-friendly overflow so the badge's `top: -9` is not clipped. **11 does not use the `dormant` state** (§9-C4) |
| `JeebSelectChip(role: sort)` + `JeebChipRow` | `OmdsChip` | ⚠️ must keep `find.byType` addressable and render its capsule **strictly under 48 dp** — a currently-red test depends on it |
| `JeebMeter(value:)` | — | the strip's 70×5 r9 progress track |
| `JeebInfoNote(tone: muted / error)` | `_Banner`, `_ErrorBanner` | needs a trailing-action slot for the error note's dismiss button |
| `JeebCtaFooter.textStack` | the trailing ListView children | orange w700 line + brown w600 link, no pill |
| `JeebAvatar` (Ø42) | `OmdsProfileAvatar` | **must compose `OmdsProfileAvatar` internally, not replace it** — `offer_card_test.dart:217-228` matches `w is OmdsProfileAvatar && w.initial == 'N'`. If `JeebAvatar` hand-rolls a `Container`, those assertions die across five screens. Until the kit lands, screen 11 uses `OmdsProfileAvatar(backgroundColor:, initialColor:, size:)` directly — it already exposes every knob the three board fills need |

**Not shared:** the offer card itself stays in
`lib/features/client_offers/presentation/widgets/offer_card.dart` (plan §5, "Not shared").

---

## 5. New functionality and what it needs from the state layer

### 5.1 `Best value` ranking — buildable, with one honest substitution

The note asks for "price × rating × distance". **Distance does not exist** — not on `Offer`, not on the
wire row (`dio_offers_repository.dart:208-241` parses id, jeeberId, name, fee, currency, etaMinutes,
vehicle, rating, ratingCount, submittedAt, avatarUrl, note), and not on the request row. Substitute
**ETA**, which is present, is the same kind of signal, and is what the customer actually trades against
price.

NEW pure-Dart `domain/offer_ranking.dart`:

```dart
/// Borda rank over the three facts the offer DTO actually carries: fee asc,
/// rating desc, ETA asc. Lowest total wins; newest-first breaks ties.
/// Distance is deliberately absent — the gateway sends none (see §5.5).
List<Offer> rankByBestValue(List<Offer> offers);
String? bestValueOfferId(List<Offer> offers);   // null when offers.length < 2
String? fastestOfferId(List<Offer> offers);     // null unless the minimum ETA is unique
```

Rules that keep it honest: an unrated Jeeber (`ratingCount == 0`) contributes a neutral rating rank
rather than a fabricated score; the badge is suppressed for a single-offer list (a "best of one" badge
is noise); `Fastest` is suppressed when it would land on the same card as `Best value` (the board puts
them on different cards) or when the minimum ETA is not unique.

Wired as **derived getters** on `ClientOffersState` (`String? get bestValueOfferId` /
`get fastestOfferId`) — no new stored fields, no `props` change, no `copyWith` churn.

### 5.2 A third sort mode

`OfferSortMode` gains `best`, and it becomes the **default** (the render shows `Best` selected).
`ClientOffersCubit._sortOffers:392-408` gains the `best` branch delegating to `rankByBestValue`.
This is a real product change to the default ordering — see §8 and §10.

### 5.3 The progress meter's denominator — the one genuine gap in the strip

`windowExpiresAt` + injected `now` give an exact **countdown**; they do not give a **fraction**, because
nothing on the wire carries the window's start or total. The gateway sends only a deadline
(`windowExpiresAt` / `offerWindowExpiresAt` / `broadcastExpiresAt` / `expiresAt`,
`dio_offers_repository.dart:203-206`).

Proposal: `ClientOffersCubit` tracks `_windowTotal = max(_windowTotal, windowRemaining)` across emits
and publishes it as `Duration? windowTotal` on the state; the strip renders
`progress = remaining / windowTotal`. **Documented contract: the bar's zero is the true server
deadline; its 100 % is the largest remaining this session has observed.** On the dominant path
(the customer arrives straight from broadcasting) that is exact. On a mid-window re-entry the bar
starts full and drains to zero at the correct instant — it under-states elapsed *proportion* but never
misstates the deadline, and the exact digits sit beside it.

If the owner rejects that, the fallback is `JeebMeter(value: null)` → track only, plus
`// TODO(redesign-24): needs gateway windowTotalSeconds — omitted, not faked.` **Do not invent a
5-minute constant.** The sibling waiting screen has an explicit `WaitingFailure.contractViolation` for
exactly this and "NEVER manufactures a countdown".

This is the only new stored state field: `windowTotal` in `ClientOffersState` (+ `copyWith` + `props`).

### 5.4 The top-bar subtitle — buildable from the row this repo already reads

The board's subtitle is `Medicine — Pharmacie du Musée` (item — destination).

- **Item: available.** `DioOffersRepository.fetchOffers` already GETs `/v1/requests/{id}` and passes the
  body into `_parseSnapshot(data, requestData)` — it just reads `status` and the deadline off it. That
  row carries `title`, and two other repositories already read it from this exact endpoint
  (`dio_order_summary_repository.dart:130` `request?['title']`,
  `dio_order_chat_summary_repository.dart:135`). Add `String? requestTitle` to `OffersSnapshot`, parse
  `_str(requestData['title'])`, thread it through `_emitSnapshot` onto `ClientOffersState`. Rendering an
  existing field off an existing response is explicitly permitted (§7.6). **No new endpoint, no new
  call, no extra round trip.**
- **Destination: not available on this endpoint.** `dropoff.address` is parsed from the *conversations*
  DTO (`dio_accepted_conversations_repository.dart:64-67`), not from `/v1/requests/{id}`. Omit it with
  `// TODO(redesign-24): needs gateway dropoff on the request row — omitted, not faked.`
- When `requestTitle` is null the subtitle line is **not rendered** — never a placeholder (JEBV4-176).

`FakeOffersRepository` and `test/support/scripted_offers_repository.dart` need the new field defaulted
to `null`.

### 5.5 What is refused as unbuildable

| Board element | Verdict |
|---|---|
| `3 km away` | **no field exists.** Slot reused for the vehicle; TODO left |
| `(127)` review count | **not a gap — the enhanced plan is wrong here.** `Offer.ratingCount` exists, is parsed at `dio_offers_repository.dart:232`, and is rendered today as `(132)`. What is missing is *gateway enrichment* (the O-list-enrich gap), which the card already handles honestly via `ratingCount > 0` → "No ratings yet" |
| `usually replies in 1 min` | listed against 11 in `02-PLAN-ENHANCED.md §5` but **does not appear on 11's board at all** (`grep` of `11-offers.html`). Nothing to build |
| `$8` (no decimals), `04:12` (padded), `in 40 mins` | mock strings. `MoneyFormat` (2 dp, LTR-isolated), `CountdownFormat` (unpadded leading field, deliberately — see its library doc on the `1433:18` field defect) and `offersCardEtaMinutes` all win |

---

## 6. New routes

**None.** `/requests/:id/offers` (name `offer-review`) is registered at `app_router.dart:805-810` and
`'offer-review': '/'` is already in `backFallbacks:466`. Do not touch either. The two edges the screen
owns — the JM-029 accept sheet and the JM-030 cancel sheet — are `showModalBottomSheet`, not routes
(`40_GUARDRAILS_ARCH §5`).

---

## 7. RTL

| Hazard | Build it as |
|---|---|
| `Best value` badge at `right: 14; top: -9` | `Stack(clipBehavior: Clip.none)` + `PositionedDirectional(end: 14, top: -9)`. `right:` would strand it on the wrong edge in `ar` |
| back glyph | `DirectionalIcons.back` (never `Icons.arrow_back`) |
| right-aligned money column | `Column(crossAxisAlignment: CrossAxisAlignment.end)` + `TextAlign.end` — both mirror automatically |
| `$8.00` / `LBP 15,000.00` | already LTR-isolated by `MoneyFormat` (`⁦…⁩`, JEBV4-98/F10) — do not unwrap |
| `4:12` countdown | `CountdownFormat` output is digits + colons only and is documented bidi-safe without an isolate. **Do not add one** |
| all paddings | `EdgeInsetsDirectional` / `Spacing`; the screen already uses `EdgeInsetsDirectional.fromSTEB` at `client_offers_screen.dart:230` |
| meta line `★ 4.9 (127) · Motorcycle` | a plain `Wrap`/`Row` — child order mirrors for free. Do not force `TextDirection.ltr` |
| strip `[dot][text][meter]` | plain `Row`; the meter mirrors to the start edge in `ar`, which is correct (it drains toward the reading tail) |

`offer_card_test.dart:172-189` and `:297-317` already pump this card under `Locale('ar')` and assert
`قبول` / `دراجة هوائية` / `جِيبر جديد` / `لا تقييمات بعد`. Add an `ar` pump for the new badges.

---

## 8. Test impact

`test/offer_card_test.dart` (13 tests) **passes unchanged** if the card is built as specified — that is
the design constraint that shaped §2.5, not a coincidence. `starCount: 1` + `reviewsLabelBuilder:
(c) => '$c'` keeps `find.byType(OmdsStarRatingDisplay)`, `find.text('4.7')` and `find.text('(132)')`
resolving; a standalone `Text(vehicleLabel)` keeps `find.text('Motorcycle')`; the money column keeps
`find.text('18 min ETA')` and `⁦$42.50⁩`; `OmdsProfileAvatar` keeps both initial predicates.

| Test | Effect | Legitimate? |
|---|---|---|
| `client_offers_screen_test.dart:152` *sort chips hit targets* | **currently RED (`Actual: <48.0>`) → GREEN.** Swap `find.byType(OmdsChip)` → `find.byType(JeebSelectChip)`; both assertions (`≥48` target, visual `<` target) stay | Yes — this is the fix the assertion was written for. Report the flip explicitly per `_BASELINE.md` |
| `client_offers_screen_test.dart:70,108` *sorted offers / sort toggle* | `best` becomes the default; both fixtures still land in the asserted order, but by tie-break rather than by rule. **Add an explicit `tap(Key('offer-sort-price'))` first** so the tests state what they mean | Yes |
| `client_offers_screen_test.dart:255` *bottom padding at max scroll* | the `listView.padding.bottom == Spacing.xLarge + 48` assertion breaks — the Cancel CTA is docked, not a list item. **Keep the second half verbatim** (`screenBottom − ctaRect.bottom ≥ Spacing.xLarge + 48`, which is what actually protects the user) and replace the first half with an assertion on the footer's resolved bottom padding | Yes — mechanism changed, contract did not. Not a weakening |
| `client_offers_screen_test.dart:342` *failed load centred* | `getCenter(error) ≈ getCenter(offer_review_list_root)` breaks once the root also spans the top bar. Retarget to `find.byKey(const Key('offer-review-content'))` — same intent, correct region | Yes |
| `offer_window_timer_test.dart` (3 tests) | constructor gains `offerCount` + `progress`; `Window: 2:05 left` → the merged strip string. Rewrite all three; **keep the expired case asserting `Offer window expired`** (also asserted at `client_offers_screen_test.dart:594`) | Yes — the copy genuinely merged |
| `client_offers_cubit_test.dart:53` *default sortMode* | `byPrice` → `best` | Yes, and it is the assertion that documents the product change |
| `offer_accept_double_accept_b01_test.dart:326` | passes — `OmdsPrimaryButton` under `Key('offer-card-accept-<id>')` is preserved | — |
| `offer_card_overflow_test.dart` | must stay green; §2.5's Expanded/Flexible/Wrap rules exist for it | — |
| `client_offers_429_test`, `client_offers_push_driven_test`, `client_offers_resume_backstop_test`, `offers_failure_copy_test`, `dio_offers_repository_test` | unaffected (cubit/repo level). `dio_offers_repository_test` may need one added case for `requestTitle` | — |
| `test/core/theme/no_raw_semantic_colors_test.dart:21` | passes **only if `offer_window_timer.dart` stays at its path** and uses `jeebRoles`, not `.tertiary` / `Color(0x` / `Colors.*` | — |
| `w1_routes_resolve_test.dart:249` | passes — `offer_review_list_root` survives | — |

**New tests to add:** `rankByBestValue` / `fastestOfferId` unit tests (pure Dart, no widget pump);
a widget test asserting `offer_card_0_best_value_badge` is on the ranked-first card and absent for a
single-offer list; an `ar` pump of the badge row; a strip test for `progress` clamping when
`windowTotal` is null.

**Do not touch** the other three `_BASELINE.md` failures (`mutual_rating_tag_chips_l10n_test`,
`jeeber_feed_card_test`, `gesture_log_test`).

---

## 9. Conflicts

**C4 — the dormant third offer is REFUSED.** `11-offers.html:72` renders the third card at
`opacity: 0.75` **and deletes its entire action row** — no cash line, no Accept. Every offer must stay
acceptable; "Accept only one offer." is a statement about exclusivity, not about which offers are
actionable. **Build all cards with a full action row.**

I also decline the `.75` opacity, going one step beyond `00-MIGRATION-PLAN.md §7.2`'s "dimming may stay
as a pure rank signal": once the Accept button is back, a dimmed *actionable* card reads as a rendering
fault, and 75 % opacity drops the periwinkle cash line and the outlined Accept label below AA on white
in an app that gates contrast in CI.

**The board's own alternative is better and is data-backed.** R11 says a `surfaceContainerHighest` fill
with a periwinkle initial means *unknown/dormant* — which is exactly what the board draws on Rami's
avatar. Bind that avatar treatment to `ratingCount == 0` (a genuinely unknown Jeeber, which the card
already computes as `hasRatings`) instead of to a fabricated rank tier. That reproduces the render's
visual vocabulary using a fact the app actually holds, and it pairs with the existing honest
"No ratings yet" line. **Owner decision, one-line reversal either way.**

**No other conflict.** Checked and clear:
- `decision_violations_test.dart` pins D56 (mutual rating) and D52 (KYC) — neither touches this screen.
- The accept path stays a **sheet, not an inline accept** (D11/D71), and the sheet keeps its
  question-form title (`offer_accept_sheet_tense_test.dart`). `client_offers_screen_test.dart:193`
  asserts tapping Accept fires **no** accept call.
- The B-01 double-accept guard (`_openAcceptSheet`'s in-flight early return + `beginAccept` /
  `endAccept` disabling every sibling CTA) is untouched — it is the reason `acceptDisabled` exists on
  the card, and the restyle must keep threading it.
- D41/D44 ("Platform fee", never "Commission") and `kJeebCommissionRate` do not appear on this
  customer-facing surface, and must not be introduced.
- Cancel wording stays as-is: there is **no backend `POST /requests/:id/cancel`**; pre-accept cancel is
  locally authoritative, so no copy here may imply server confirmation.

---

## 10. Risks

1. **`best` as the default sort is a product change**, not a styling change — it changes which offer a
   customer sees first, forever. It is what the render shows and what the designer note leads with, but
   flag it in the PR notes.
2. **The meter's denominator is session-local** (§5.3). Honest and documented, but a mid-window
   re-entry under-states elapsed proportion. A `windowTotalSeconds` on the request row would remove the
   caveat entirely — worth one line to the gateway team.
3. **Wave 1 has not landed** (`lib/core/widgets/jeeb/` does not exist). This screen needs
   `JeebOutlinedCard`, `JeebSelectChip(role: sort)`, `JeebMeter`, `JeebInfoNote`, `JeebTopBar`,
   `JeebCtaFooter.textStack` and `JeebAvatar`. Starting before the kit means hand-rolling six of them.
4. **`JeebAvatar` must compose `OmdsProfileAvatar`.** If the kit lane hand-rolls it, two assertions in
   `offer_card_test.dart` break here and the same pattern breaks on 04, 12, 16 and 21.
5. **`JeebSelectChip`'s capsule must render under 48 dp.** If it inherits `OmdsChip`'s 48 dp height, the
   currently-red sort-chip test stays red and this lane will be blamed for it.
6. **Density is the invisible risk** (plan risk #13). With `Expanded(ListView)` the temptation is to let
   the list fill; the board's bottom 40 % is white. Review against the PNG at the same scale.
7. **`offer_window_timer.dart` is gate-listed.** Moving it, renaming it, or reaching for `.tertiary`
   fails `no_raw_semantic_colors_test.dart` with a "was moved/deleted" message that reads like an
   unrelated failure.
8. **The l10n batch is serialized through the integrator** — six of the seven strings this screen needs
   already exist, so only two new keys are required (§11). Landing a key without its getter and both
   locales fails the parity gate in both directions.

---

## 11. l10n (integrator batch)

**Reused, no change:** `offersScreenTitle`, `offersSortByPrice`, `offersSortByRating`,
`offersCardEtaMinutes`, `offerCardCashOnDelivery`, `offersCardAccept`, `offersCardJeeberFallback`,
`offersCardNoRatingsYet`, `offersWindowExpired`, `offerReviewCancelCta`, `chatOfferAcceptOnlyOne`,
`offersEmptyTitle/Body`, `offersRequestClosedTitle`, the five `offersError*` strings, both
`offersCardSemanticLabel*`.

**Retired from use (keys stay in both ARBs):** `offersPanelHeader`, `offersSortLabel`,
`offersWindowRemaining`.

**New (4-edit recipe each: EN + `@key` → real AR → `_get` getter → call site):**

| Key | EN | Notes |
|---|---|---|
| `offersSortByBest` | `Best` | the third sort chip |
| `offersWindowStrip` | `{count, plural, =1{1 offer in} other{{count} offers in}} · window closes in {time}` | ICU plural — **must pass `qa/t-mob-fix-002/ar_plurals_check.sh`**, so the AR value needs `zero`/`one`/`two`/`few`/`many`/`other` |
| `offersCardBestValueBadge` | `Best value` | badge |
| `offersCardFastestBadge` | `Fastest` | badge |

Also extend `offersCardSemanticLabel` / `offersCardSemanticLabelUnrated` consumers so the badges are
announced — append them to the composed `semanticLabel` the way `offer_card.dart:114-116` already
appends the note, rather than minting a new label string.
