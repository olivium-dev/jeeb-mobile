# w4 — `delivery-man-profile` (screen 27) onto the Jeeb design system

**Status: done.** `dart analyze lib/features/delivery_man_profile` → *No issues found*.
`flutter test test/delivery_man_profile_screen_test.dart test/features/delivery_man_profile/` → **16/16 pass**.
`test/semantics_identifier_surfacing_test.dart` (owns the B5 `DeliveryManMetaRow` lock) → **13/13 pass**.
`test/decision_violations_test.dart` → **4/4 pass**. `test/offer_card_test.dart` (the screen's caller) → **18/18 pass**.
No new failures; nothing outside `lib/features/delivery_man_profile/` was touched.

There is **no render for this screen** — the board drew 24 and this is not one of them. The reference
was the nearest neighbour in the journey, `16-jeeber-home`, and the language rules in `_ds/readme.md`
+ `00-MIGRATION-PLAN.md` §4/§5.

---

## What the neighbour does, and what this screen did instead

| 16 jeeber-home | 27 delivery-man-profile (before) |
|---|---|
| No Material app bar — an in-body identity band on a white page | `Scaffold(appBar: OMDSAppBar(title: ''))`, a bare Material bar whose only content was a trailing `IconButton(Icons.close)` |
| 24px side gutters everywhere (`padding: … 24px`) | 20px (`Spacing.large`) on the header and the list, 16px inside cards |
| Cards: `1.5px var(--jeeb-brown-outline)`, r16, **no shadow** | `Container` + `BoxDecoration(border: 1px outlineVariant, radius 12)` — a hairline grey box, not the board's outline |
| Type ramp: card title 15/w700 navy · meta 12/w600 periwinkle · timestamp 11.5/w600 periwinkle | `textTheme.headlineSmall` / `titleMedium` / `titleSmall` / `bodyMedium` — the stock M3 ramp, one `fontSize: Sizes.small` override |
| Ø44 navy identity disc with a white initial | `OmdsProfileAvatar(size: Sizes.nineXLarge)` = Ø88, `primaryContainer` fill |
| Orange appears **twice** on the whole screen, both "do-it-now" | Zero orange; the only affordance ("View all") was an `OmdsPrimaryButton` text variant in theme primary |

## What changed

**`delivery_man_profile_screen.dart`**
- `OMDSAppBar` → **`JeebTopBar.close`** mounted as the first child of `SafeArea > Column`, `Scaffold.appBar` left null (the house pattern — cf. `dispute_status_screen.dart:114-127`). `identifier: 'profile_close'` lands on the bar's leading circle, which is already `MinTapTarget`-lifted to 48dp.
- List gutters/rhythm: `top: Spacing.small`, a `Spacing.xLarge` block break between the identity band and the reviews band, `bottom: Spacing.xLarge`.
- `_close` moved onto the screen (the `_CloseButton` widget is gone); the go_router `canPop ? pop : go('/')` edge is byte-identical.

**`widgets/delivery_man_profile_header.dart`**
- `OmdsProfileAvatar(Ø88)` → **`JeebAvatar.hero`** (Ø74, navy fill + white initial, the kit's own `initialFrom` fallback). `avatarKey:` keeps `Key('delivery-man-profile-avatar')` on the composed `OmdsProfileAvatar`.
- Name: `textTheme.headlineSmall` (24) → **`context.jeebText.h2`** (20/w700) on `colorScheme.primary`.
- Gutter 20 → **24** (`Spacing.xLarge`).

**`widgets/delivery_man_meta_row.dart`**
- `textTheme.bodyMedium` → **`context.jeebText.bodySmall`** (12/w600) on `onSecondaryContainer` — the board's meta line verbatim (`1.2 km · Achrafieh`). Glyph ink stays `colorScheme.primary` (navy).

**`widgets/delivery_reviews_header.dart`**
- Title `titleMedium` → **`context.jeebText.h2`** navy.
- Count `bodyMedium` → **`context.jeebText.bodySmall`** periwinkle.
- "View all" `OmdsPrimaryButton(variant: text)` → **`JeebCtaButton.accentText`** with `contentPadding: zero`. This is the screen's single orange element and matches the board's inline-link family (`Edit`, `Change`, `Top up`, `How fees work`).

**`widgets/delivery_review_card.dart`**
- Hand-rolled `Container`+`BoxDecoration` → **`JeebOutlinedCard`** (1.5px `colorScheme.outline`, r16, no shadow, pad 13/16 border-box corrected).
- `OmdsProfileAvatar(Ø40)` → **`JeebAvatar.thread`** (Ø42); an anonymous reviewer gets `JeebAvatarFill.dormant`, the kit's honest unknown-person mark, instead of a coloured disc.
- Name → `cardTitle` navy · "Verified Client" and "N days ago" → `caption` periwinkle · body → `jeebText.body`. The `fontSize: Sizes.small` overrides are gone.

**`widgets/delivery_reviews_list.dart`** — gutters 20 → 24, empty-state inset 20 → 24.

## Refusals / deliberate non-changes

- **`JeebProfileHeader` is NOT used.** Its `name` is a `String` rendered as one `Text`; this screen must
  put `Semantics(identifier: 'delivery_man_profile_name')` on that line (asserted by
  `.maestro/flows/27-delivery-man-profile.yaml:52` and `jm-067`) **and** hang `JeebVerifiedBadge` off it
  (`delivery_man_profile_screen_test.dart:119`). The kit has no `nameSlot` and no badge slot, `trailing`
  is `xor ratingLabel`, and the kit is frozen. Hand-rolling a private copy is an explicit review defect,
  so the screen keeps its own row and takes the kit's *parts* (`JeebAvatar`) and *tokens* instead.
  **Kit gap worth filing separately: `JeebProfileHeader` needs a `nameSlot` (or `nameIdentifier` +
  `nameTrailing`) before any screen with a frozen name id can adopt it.** Not filed as a wiring request —
  nothing here is blocked on it.
- **`JeebSectionLabel` is NOT used for "Reviews".** It uppercases in EN; both
  `delivery_man_profile_screen_test.dart:104` (`find.text('Reviews')`) and the Maestro flow read the
  natural casing. Used `jeebText.h2` navy, which is what the neighbour's headings are anyway.
- **The rating star stays navy**, in the header meta row *and* in the 5-star review row
  (`colorScheme.primary`). §4.1 rations `starRatingColor` to the three screens where a specific
  person's score drives a decision; this profile is not one of them and the lane brief pins it.
- **No flow change.** Same routes, same edges, same copy, same order of sections, no affordance added
  or removed, no new l10n key, no pubspec touch.
- **All 8 Semantics identifiers survive byte-identically**: `delivery_man_profile_screen_root`,
  `profile_close`, `delivery_man_profile_name`, `profile_score`,
  `delivery_man_profile_rating_summary`, `delivery_man_profile_availability`,
  `profile_view_all_reviews`, `delivery_man_profile_review_card_$index` (+ `jeeb_verified_badge` from
  the shared badge). The three legacy `Key`s that survive are `delivery-man-profile-screen-root`
  (the RTL test reads Directionality off it), `-avatar`, `-view-all`, `-reviews-list`, `-reviews-empty`.

## Known divergences (see `selfCritique`)

1. The close **×** moved from the top-**right** to the top-**left** — `JeebTopBar.close` puts it in the
   leading circle, which is the board's only realized close treatment (17). Id-addressed everywhere,
   so no flow breaks, but it is the one perceptible layout move.
2. `Key('delivery-man-profile-close')` was dropped with the `IconButton` it lived on. Nothing in
   `lib/`, `test/`, or `.maestro/` referenced it; re-homing it onto the whole bar would have made
   `tester.tap(byKey(...))` hit dead space, which is worse than absent.
3. Ø74 avatar is larger than any header disc on the board (Ø44–46). It is a realized kit size
   (`JeebAvatar.hero`, screen 15's identity block) and this is a dedicated identity surface, but it is
   a judgement call, not a measurement.
4. The two meta rows still carry leading glyphs (`Icons.star`, `Icons.location_on`). The board writes
   meta lines as `·`-separated periwinkle runs with no glyph. Dropping them would have changed what the
   screen shows, so they stayed — re-inked navy at 16px.
5. The 5-star review row has no board precedent at all (no screen draws one). It kept its existing
   12px navy icons.
