# Apply report — 16 · Jeeber home

Instruction set: `per-screen-revised/16-jeeber-home.md`. Wiring: `wiring/16-jeeber-home.md`
(already written; W-1…W-5 verbatim, no additions needed).

Status: **applied**, with Task 8 deferred (gated on W-2, which has not landed) and Task 11/12's
test *execution* blocked on W-1 (see "Cannot be executed yet").

---

## 1. What changed, band by band

| Band | Before | After |
|---|---|---|
| Header | Title-only row, avatar rendered ONLY when `avatarUrl != null` (so `jeeber_home_avatar` was absent on the live path) | `JeebProfileHeader` (kit #23) — eyebrow "Jeeber dashboard" 13/w600 periwinkle over the 19/w700 navy greeting, **unconditional** Ø46 `JeebAvatar.header`, gutter 24 |
| Availability | Two different silhouettes (`OmdsSwitchTile` when online / `OMDSSectionCard` otherwise) | ONE navy strip: `JeebNavySurfaceCard` + `JeebShadows.ctaNavy`, presence dot → headline (+ optional subtitle) → Material `Switch` on `jeebRoles.success` |
| Inactivity warning | A separate warning-container banner with an icon, a body paragraph and a full-width primary button | The strip's subtitle row: one muted line + `Extend` as its last tappable word |
| Active work | Grey avatar + outlined "Open chat" button rows under a count heading | `JeebAccentFrameCard` (kit #5) — 2px orange frame, Ø38 orange scooter disc, `Active: {order} → {dropoff}`, navy action pill |
| Filters | Search bar on its own row, then a chip row | One row: `Nearby n / Pending n / Replies n` (`JeebSelectChip(role: filter)`) + the Ø40 magnifier disc at the end edge; search field mounts only once the magnifier is tapped |
| Offline banner | Full-bleed warning slab | `JeebInfoNote.warning`, inset at the 24 gutter |
| Empty states | Centred `OmdsEmptyState` (icon + centred copy) | Two start-aligned lines at the top of the white body, where the first card would be |
| Gutters | `Spacing.medium` (16) | `Spacing.xLarge` (24) on every band |

Kit widgets consumed: `JeebProfileHeader`, `JeebAvatar`, `JeebNavySurfaceCard`, `JeebSelectChip`,
`JeebInfoNote`, `JeebAccentFrameCard`. No private copy of any kit widget was made.

## 2. Deviations from the instruction set (deliberate, each with a reason)

1. **The strip's outer gutter `Padding` sits OUTSIDE `Semantics(key: rootKey)`**, not inside as
   Task 4 draws it. Measured: with the padding inside, `rootKey` measures **80dp** and
   `availability_card_test.dart:198–203/:221–224` (`<= Sizes.sevenXLarge`) fails; outside, it
   measures **64dp**. Task 10 requires those height assertions to keep passing untouched, and the
   assertion is about the strip ("must remain a one-row dashboard control"), not the page margin.
   Verified with a throw-away geometry probe (card 64.0, `Switch` 48.0), which was then deleted.
2. **Card padding `vertical: Spacing.xSmall` (8), not `Spacing.small` (12).** The M3 `Switch`
   carries 8dp of its own padding around its 32dp track, so 8 here renders as the board's 14 —
   and 12 would put the strip at exactly the 72dp ceiling with no headroom for AR.
3. **`_OfflineBanner` uses `JeebInfoNote.warning`, not `tone: muted`.** Task 7 asks for the muted
   tone *and* the warning-role inks in the same sentence; the kit's own doc lists 16's offline
   banner under the warning tone, and `.warning` is the only tone that yields
   `warningContainer`/`onWarningContainer` without restyling from outside.
4. **`trailingReserve: Spacing.fourXLarge * 2` on the header.** The CUT decision drops the rating
   pill but leaves the shell's `delivery_tab_wallet_chip` + `delivery_tab_bell` overlaid on that
   exact corner (`shell_screen.dart` `_HeaderedTab('delivery_tab')`). 04 reserves the same width
   for the same reason; without it a long name runs under the overlay.
5. **The magnifier shows `Icons.close` while expanded.** Tapping it collapses *and clears* the
   query; a magnifier that hides search is a mis-affordance.
6. **The `SizedBox(height: Spacing.large)` above the no-requests empty block was dropped** — the
   block now owns a `Spacing.xLarge` top inset, and keeping both put 44dp between bands whose
   board rhythm is 12–16.
7. **`jebv4_284_keyboard_repro_test.dart` gained a search-toggle tap.** Not listed in Task 10, but
   it asserts `searchBarKey` is mounted at rest, which C8 makes false. Intent preserved exactly:
   the keyboard-open state it reproduces is now only reachable through the toggle, so the test
   expands search first and then asserts the same no-overflow + still-mounted contract.
8. **The lane-local active-deliveries fallback drops its "{n} active deliveries" heading.** The
   board draws no heading — each card says `Active: …` itself.

## 3. Frozen inventory — verified identical

`grep -rn "identifier: '" lib/features/jeeber_home` after the change yields exactly the §3 set
plus **one** new id, `jeeber_feed_search_toggle`. `jeeber_home_avatar` moved from a literal
wrapper to `JeebProfileHeader.avatarIdentifier` (the kit applies it through an explicit
`Semantics(identifier:)`), so the emitted value is byte-identical — and it now emits on the live
`avatarUrl == null` path, which is a latent gap this closes rather than a change.

Every Key constant kept its literal value: `JeeberHomeScreen.scaffoldKey/loadErrorRetryKey`,
`JeeberHomeGreeting.rootKey`, `AvailabilityCard.rootKey/toggleKey/spinnerKey`,
`InactivityWarningBanner.rootKey/ctaKey`, `JeeberNoRequestsView.rootKey`,
`Key('jeeber-no-requests-empty-state')`, all seven `JeeberFeedTabView` keys (`offlineBannerKey`
is now actually *attached* — it was declared and unused before), and
`Key('jeeber-active-open-chat-<routeId>')`.

Untouched as required: `availability_status_block.dart`, `jeeber_unregistered_view.dart`,
`jeeber_feed_empty_view.dart`, `pending_offer_row.dart`, `_LoadErrorView`/`_LoadErrorContent`,
`AvailabilityCubit`/gateway, the router, DI, theme, `.arb`, `pubspec.yaml`, the shell, the two
cross-lane feature directories, and `.maestro/`.

## 4. Gates

- `dart analyze lib/features/jeeber_home test/features/jeeber_home <touched tests>` → **8 issues,
  all of them the ungranted W-1 l10n getters**. Zero other errors, zero warnings, zero lints.
  This is the same state sibling lanes are in (`home_client`, `client_offers` currently show 11).
- `tool/check_design_tokens.sh` → no violations in `lib/features/jeeber_home`.
- `test/core/theme/no_raw_semantic_colors_test.dart` → **17/17 pass** (both gated lane files
  clean).
- `dart format` → `availability_card.dart` formatted. `jeeber_feed_tab_view.dart` and
  `jeeber_active_deliveries_banner.dart` were already format-dirty at HEAD and were left that way
  rather than adding unrelated reformat noise.

## 5. Cannot be executed yet

`flutter test` on any lane test fails at **compile** time until W-1 lands — the seven new
`AppLocalizations` getters/methods do not exist. This blocks the actual execution of Task 10's
edits, Task 11's RTL sweep and the remaining Task 12 test runs. The `.arb`/`app_localizations.dart`
files were deliberately **not** patched, not even temporarily, because they are shared and another
lane could be writing them concurrently.

**Integrator: after applying W-1, run**

```
flutter test test/features/jeeber_home/availability_card_test.dart \
             test/jeeber_home_screen_test.dart \
             test/jeeber_feed_search_input_test.dart \
             test/jeeber_feed_tier_filter_test.dart \
             test/jeeber_feed_make_offer_test.dart \
             test/jeeber_feed_empty_ptr_test.dart \
             test/jeeber_feed_empty_view_test.dart \
             test/jebv4_284_keyboard_repro_test.dart \
             test/features/shell/jeeber_dashboard_overflow_test.dart
```

## 6. Still open

- **Task 8** (`isFreshest` / `isVoice` pass-through into `JeeberFeedCard`) — deferred: the card
  has neither parameter yet. It lands with W-2, as the instruction set anticipates.
- The board's live countdown, zone name and cash figure stay unrendered (C-16.3/4/5 — no backing
  data; nothing faked).
- The rating pill and the bottom-bar restyle stay deferred owner decisions.
