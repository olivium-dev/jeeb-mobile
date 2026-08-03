# W4 apply report — `jeeber-request-feed`

**Lane:** w4-jeeber-request-feed · **Branch:** `feat/redesign-24-migration` (no commits, no branch ops)
**Neighbour reference:** `screens/16-jeeber-home.png` / `.html` (there is no render for this screen)

---

## 1. Scope correction (read this first)

The prompt assigned one file and warned *"the feed CARDS in this directory were already redesigned in
a prior wave — read them first and match."*

That is true of **`jeeber_feed_card.dart`** — the card the LIVE dashboard feed
(`jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart`) renders. It is fully on the kit
(`JeebOutlinedCard` + `JeebTierChip` + `JeebCtaButton` + `context.jeebText`) and **I did not touch it.**

It is **not** true of **`request_card.dart`**, the card *this* screen hosts. That file was still
100% pre-redesign (`Container` + `BoxDecoration`, `colorScheme.tertiaryContainer` tier tints,
`textTheme.labelMedium`, `OmdsPrimaryButton`). Its **only** consumer is `request_feed_screen.dart`.
Re-skinning the host and leaving its only card in the old vocabulary would have been a no-op —
the card *is* the screen visually. So I migrated both files. Both are inside my owned directory.

## 2. What I saw (before editing)

Neighbour (`16-jeeber-home.png`):
* Predominantly white page, hard 24px side gutters, no page-level shadows anywhere except the one
  accent CTA glow. Cards are **outlined** (1.5px warm-brown `outline`, r16), never elevated.
* Exactly **one** orange fill on the whole screen — the freshest row's `Make offer` pill. The
  navy `Manage` pill, the navy selected chip and the navy headlines carry all the other weight.
* Tier is a neutral grey `⚡ Flash` pill — one treatment for every tier, no colour-coded severity.
* Secondary information (`1.2 km · Achrafieh`, `2 min ago`) is periwinkle-muted at ~12px; body
  headlines are bold navy.
* Rows breathe: ~16px between cards, generous internal padding, and the empty area below the last
  card just stays white — no centred illustration filling it.

This screen (before):
* `Scaffold(appBar: OMDSAppBar(...))` — a Material app bar with a centred-ish 22/w400 title, which
  is the one header shape the redesign explicitly replaced with the in-body `JeebTopBar` row.
* A **full-bleed amber slab** for the reconnecting state (`Container(color: warningContainer)`,
  16/8 padding, edge-to-edge) — the "system error bar" look the redesign removed everywhere else.
* Cards at a **16px** gutter (`Spacing.medium`), not 24.
* Tier chip painted from `tertiaryContainer` / `secondaryContainer` / `primaryContainer` — i.e. a
  **colour-coded tier severity**, exactly what the board rejects. (`tertiaryContainer` is orange-family:
  a large tinted fill of the rationed accent, on every card.)
* Every text style a raw `textTheme.*.copyWith(fontWeight:)` — zero `context.jeebText`.
* Two `OmdsPrimaryButton`s (12px-radius-era stadium buttons), not kit pills.
* A centred `OmdsEmptyState` with a big inbox glyph — while the redesigned sibling feed
  (`_EmptyTabState`) had already been moved to two start-aligned lines on the white body.

## 3. Changes

### `presentation/request_feed_screen.dart`

| Before | After | Why |
|---|---|---|
| `Scaffold(appBar: OMDSAppBar(title, centerTitle:false))` | `Scaffold(body: SafeArea(Column[JeebTopBar(title, identifier:'request_feed_back'), Expanded(...)]))` | §5 #1. In-body row, h2 20/w700 start-aligned title, Ø40 tonal back circle, 14/24/0 padding. Back behaviour is identical (kit default = `Navigator.maybeOf(ctx)?.maybePop()`, same as the AppBar's implied leading). Sits **above** the `BlocConsumer` so feed state never rebuilds it. |
| `_ReconnectingBanner` = full-bleed `Container(color: jeebRoles.warningContainer)` + hand-rolled icon/text row | `JeebInfoNote.warning(icon: Icons.wifi_off_outlined, text: …)` inset on the 24px gutter | §5 #22. Same warning role, same copy, same `Key('requestFeed.reconnectingBanner')`. Byte-for-byte the treatment `jeeber_feed_tab_view.dart::_OfflineBanner` already ships for the same class of state. `_ReconnectingRow` deleted (it existed only to paint the slab). |
| `_EmptyFeed` = centred `OmdsEmptyState` + inbox glyph | two start-aligned lines (`titleProminent` navy + `bodySmall` muted) at the 24/24 gutter, still inside the always-scrollable/`ConstrainedBox` shell | Mirrors `jeeber_feed_tab_view.dart::_EmptyTabState`, the redesigned twin of this exact state. Same two l10n keys, same `Key('requestFeed.empty')`. Pull-to-refresh over an empty feed still works (the scroll shell is untouched). |
| `import jeeb_color_roles.dart` | `jeeb_semantic_colors.dart`, `jeeb_text_styles.dart`, `jeeb_info_note.dart`, `jeeb_top_bar.dart` | — |

Unchanged on purpose: the cubit wiring, the 1Hz ticker, `_onEffect`/snackbars, `OmdsPullToRefresh`,
`OmdsLoadingState`, `OmdsErrorState` (**the kit has no loading/error-state primitive** — §5 of
03-WAVE1-KIT lists neither), the `ListView` structure and its `vertical: Spacing.small` padding.

### `presentation/request_card.dart`

| Before | After |
|---|---|
| `Container` + `BoxDecoration(surface, OmdsBorderRadius.medium, outlineVariant@38%)` | `JeebOutlinedCard` (r16, 1.5px `colorScheme.outline`, no shadow ever, border-box padding correction) |
| `margin: horizontal Spacing.medium` (16) | `Padding(rowPadding)` = **24** horizontal / 8 vertical → 16px inter-card gap |
| `_TierChip` painting `tertiaryContainer`/`secondaryContainer`/`primaryContainer` per tier | `JeebTierChip(tier: …, label: …)` — one neutral pill for every tier. Same app-tier→kit-glyph pairing `JeeberFeedCard` uses (flash→flash, light→eco, standard→standard, bulk→express), so the two feeds cannot drift. |
| Countdown `labelMedium` + `onSurfaceVariant` | `context.jeebText.caption` + `JeebSemanticColors.mutedText` |
| `_LocationText` caption = `labelSmall` + `onSurfaceVariant` | `JeebSectionLabel(label, small: true)` — kit owns the uppercase (locale-gated, AR passes through) and the tracking |
| `_LocationText` value = `bodyMedium.copyWith` | `context.jeebText.body` + `onSurface` |
| distance = `bodyMedium` w500 + `onSurface`, icon `onSurfaceVariant` | `context.jeebText.bodySmall` + muted ink, icon muted (one secondary ink, not two) |
| earnings = `bodyMedium` w600 navy | `context.jeebText.cardTitle` (15.5/w700) navy — the card's most-read number, **still navy, not orange** |
| two `OmdsPrimaryButton`s in a bare `Row` | `JeebCtaButton.outline` (Decline) + `JeebCtaButton.primary` (Accept) at `outlineHeight` 50 with a shared `cardTitle` label style, hosted in **`JeebOutlinedCard.actions`** so the kit owns the body→decision gap |

## 4. Constraint compliance

* **Semantics identifiers** — `request_feed_root`, `request_feed_accept_<id>`,
  `request_feed_decline_<id>` are byte-identical. The two button ids moved from a hand-rolled
  `Semantics(identifier:, container: true, button: true)` wrapper onto `JeebCtaButton`'s
  `identifier:` param, which emits **the same node** (`identifier` + `button: true` +
  `container: true`, plus `enabled:`). One **new** id added, per the naming rule:
  `request_feed_back` on the top bar's leading circle.
* **Widget keys** — all preserved: `requestFeed.list`, `requestFeed.card.<id>`,
  `requestFeed.card.tierChip`, `requestFeed.card.distance`, `requestFeed.card.earnings`,
  `requestFeed.card.accept.<id>`, `requestFeed.card.decline.<id>`, `requestFeed.reconnectingBanner`,
  `requestFeed.empty`.
* **No flow change.** Same states, same order, same two actions, same lock semantics
  (`actionStatus != idle || secondsRemaining <= 0` → both pills disabled and the callbacks no-op'd,
  exactly as before). An expired card deliberately does **not** become `JeebCardState.dormant` —
  dormant drops the `actions` slot structurally, which would *remove* an affordance.
* **No l10n change.** Zero new/renamed/removed keys; `app_en.arb`/`app_ar.arb`/the parser untouched.
* **No pubspec, no shared files, no wiring request needed** — everything landed inside
  `lib/features/jeeber_request_feed/`.
* **D20 / D52 / D56 / fee-only framing** — not reachable from this screen; nothing added that
  touches them.
* **`no_raw_semantic_colors_test`** — `request_feed_screen.dart` is on its migrated list. After the
  change it contains no `.tertiary*`, no `Color(0x`, no `Colors.<palette>`, no container-role-as-ink.
  Green. As a bonus, `request_card.dart` lost its three `*Container` tier fills (it is not on the
  list, but it was the file actually painting orange-family tints on every row).
* **RTL** — all new insets are `EdgeInsetsDirectional`; no `left`/`right` anywhere in either file.

## 5. Verification

* `dart analyze lib/features/jeeber_request_feed/` → **No issues found!**
* Diffstat: `+297 / −500` across the two files — the card lost ~220 lines of
  `ColorScheme`/`TextTheme` prop-drilling wrappers (`_CardSections`, `_Header`, `_MetadataRow`,
  `_Actions`, `_DeclineButton`, `_AcceptButton`, `_ReconnectingRow`) that the kit now owns.
* `flutter test` over this lane's surface, **re-run after every edit** — **114/114 pass, 0 new
  failures**:
  `test/features/jeeber_request_feed/` (4 files), `test/request_feed_cubit_test.dart`,
  `test/core/theme/no_raw_semantic_colors_test.dart`, `test/jeeber_feed_card_test.dart`,
  `test/jeeber_feed_empty_ptr_test.dart`, `test/jeeber_feed_make_offer_test.dart`,
  `test/jeeber_feed_tier_filter_test.dart`, `test/jeeber_feed_search_input_test.dart`,
  `test/semantics_identifier_surfacing_test.dart`, `test/feed_resume_refetcher_test.dart`.
* **Throwaway render smoke at 360×900 (EN / AR / 1.6× text scale / locked card / no-tier card /
  screen-level list + empty)** — this caught a real defect and is why the diff is bigger than the
  pure token swap:

  > **Defect found and fixed:** the card header `Row` (`[tier chip][spacer][countdown]`) **overflowed
  > 2px in EN, 44px in AR and 140px at 1.6× text scale.** It was a latent hazard in the original code
  > (both children non-flex, `Spacer` between them) that the taller kit chip made visible. Fixed by
  > (a) `Expanded` + `AlignmentDirectional.centerEnd` around the countdown so the slack collects
  > between the two and the countdown hugs the end edge in both directions, (b) `Flexible` +
  > `maxLines: 1` + ellipsis on the countdown label, and (c) shedding the tier chip above
  > **1.5× text scale** — the same threshold and the same reasoning `JeeberFeedCard._MetaRow` uses.
  > The distance/earnings row got the same `Flexible` treatment for the same reason.

  The smoke also pinned that `request_feed_back`, `request_feed_accept_<id>` and
  `request_feed_decline_<id>` are all independently queryable via `find.bySemanticsIdentifier`, and
  that a locked card reports `isButton` + `hasEnabledState` with the in-flight label.
  The temp test file was deleted afterwards and is **not** part of the diff.

  ⚠️ **Harness note for whoever writes the permanent test:** a widget test of anything in this repo
  must use `test/support/sync_app_localizations.dart` (`SyncAppLocalizationsDelegate` /
  `wrapForTest`). With the production `AppLocalizations.delegate` (the runtime ARB parser) the
  `MaterialApp` subtree **never builds at all** under `pump`/`pumpAndSettle` — the tree is just
  `WidgetsApp`, every finder returns zero, and `takeException()` is null, so the test silently
  "passes" while rendering nothing. That cost me three misleading runs.

  Screen-level (`RequestFeedScreen` + a seeded cubit) was **not** finished — the machine is running
  ~16 concurrent `flutter_tester` processes for the other lanes and the run did not complete inside
  the window. The screen's own structure is a two-child `Column(JeebTopBar, Expanded(...))` and its
  empty/loading branch was separately observed exception-free; the card, which is the whole layout
  risk, is fully covered above.
* The full suite and repo-wide analyze were **not** run — ~20 lanes are editing concurrently.

## 6. Remaining inconsistencies vs the neighbour (honest list)

Re-viewed `16-jeeber-home.png` after the change. These are still different, deliberately:

1. **The card's information model differs.** The board's feed card leads with the request CONTENT as
   a bold navy headline and gives it a relative timestamp; mine leads with tier + countdown and a
   two-line pickup/dropoff block. Aligning them would be a **product** redesign — this card's
   accept/decline contract genuinely needs both endpoints, and the redesign brief forbids reordering.
2. **Zero orange on the screen.** The board rations the accent to exactly one do-it-now fill per
   screen (the freshest offerable row). This screen has no "freshest" concept in its cubit, so I gave
   it none rather than invent one or paint every row orange. Net effect: the screen reads cooler and
   flatter than 16.
3. **Loading and error states are still OMDS** (`OmdsLoadingState`, `OmdsErrorState`) — the kit has
   no loading/error primitive (`03-WAVE1-KIT` §2 lists none), and building one would be a kit
   addition, which is out of lane.
4. **`OmdsPullToRefresh` and `showOmdsSnackbar` chrome is untouched** — same reason.
5. **The meta row keeps two leading icons** (route + payments) where the board's meta line is
   icon-free with a Ø3 dot separator (`JeeberFeedCard._MetaLine`). Kept because these are two
   *different* metrics on one line, not one `a · b` phrase — but it is a divergence.
6. **No profile band, no filter chip row, no search disc, no bottom nav.** The neighbour has all
   four; this screen has neither the data nor the product requirement for them, and adding them
   would be new surface, not a re-skin.
7. **`JeebTopBar` always draws the back circle**, whereas `OMDSAppBar` only implied a leading button
   when the route could pop. Harmless today (the only host is a pushed devtool route), but it would
   be a dead circle if this screen were ever mounted at a root.
8. **Card radius is the kit default 16**, not the 18 that 11/22/24 use. That is the correct pairing —
   screen 16 is explicitly a radius-16 screen and `JeeberFeedCard` also takes the default.

## 7. Standing note for whoever picks this up next

`RequestFeedScreen` is tagged **ORPHAN (JEBV4-227)**: its only reference in `lib/` is the devtool
catalog (`lib/devtool/catalog/entries/batch_05_entries.dart`). The live jeeber feed is
`jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart` + `jeeber_feed_card.dart`. This work
makes the orphan consistent with the system (so a devtool sweep or a future un-orphaning does not
resurrect the old vocabulary); it does **not** change anything a user sees today.
