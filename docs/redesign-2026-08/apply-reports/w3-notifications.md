# W3 · notifications-list — implementation report

**Status: applied.** Branch `feat/redesign-24-migration`. Two files touched, presentation only.
Cubit / state / domain / data / l10n untouched. Zero new endpoints, zero new user-visible strings,
zero shared-file edits, **no wiring request needed**.

There is **no board render for this screen** (the board drew 24; this is one of the 46 it never
drew). The reference is its neighbour in the shell, **24 · Order history**
(`screens/24-order-history.png` / `.html`), plus the house precedents
`order_history_card.dart` (the outlined-card row) and `wallet_hub_screen.dart` (the in-body
`JeebTopBar` that renders in every state).

## Files

- `lib/features/notifications/presentation/notifications_list_screen.dart` — header + list/empty
  chrome re-skinned in place.
- `lib/features/notifications/presentation/widgets/notification_row.dart` — the row moved onto
  `JeebOutlinedCard`.

No file created, none deleted, no private copy of a kit widget.

## What changed

| Before | After |
|---|---|
| `Scaffold(appBar: OMDSAppBar(title:, showBackButton:))` — centred M3 bar, absent from nothing but visually a different product | in-body `JeebTopBar(identifier: 'notifications_back', title:)` inside `SafeArea`, mounted **above** the state switch so it renders identically in loading / failed / loaded; 24px gutter, h2 navy title, Ø40 leading circle |
| back = `onBackPressed: canPop ? pop : go('/')` | **identical logic**, moved to `onLeadingPressed`; `leadingTooltip` = `MaterialLocalizations.backButtonTooltip` (no new ARB key) |
| list = full-bleed `InkWell` rows, `Divider(height: 1)` between them, `vertical: Spacing.small` padding only | `ListView.separated` with a 24px gutter, 16 top / 24 bottom, `SizedBox(height: Spacing.small)` separators — **R7/R12: the card outlines are the separation** |
| row = bare `Row` in a `Padding`, `Ø56 surfaceContainerHighest` icon tile at `OmdsBorderRadius.small` | `JeebOutlinedCard(radius: 18, padding: 14/16)` — 24's exact row shell; the icon tile is gone, the glyph now sits inline at `Sizes.medium` |
| category eyebrow `textTheme.labelMedium` + `colors.primary` + w600 | `context.jeebText.bodySmall` on `colorScheme.onSecondaryContainer` (periwinkle) — 24's meta ink |
| title `textTheme.titleSmall`, w600/w400 | `context.jeebText.cardTitle` on `colorScheme.primary`, w700 unread / w600 read (**weight steps, never size** — a row must not change height when it is marked read) |
| body `textTheme.bodyMedium` on `onSurfaceVariant` (**`#5C4038` warm brown**) | `context.jeebText.body` on `colorScheme.onSurface` (`#0B0E53` ink). The palette reserves brown for outlines/dividers; body copy is ink (`_ds/readme.md` §Color) |
| timestamp = a fourth stacked line, `bodySmall` on brown | moved to the **trailing edge of the meta line**, `bodySmall` periwinkle — where 24 puts a row's trailing value (`$8`). Same string, same `_timestamp` id |
| unread dot `Ø12 colors.primary` (navy) | `Ø9 context.jeebRoles.accent` — 24's live-dot size, and the **only orange on the screen** |
| empty = `SizedBox(height: MediaQuery.height * 0.18)` + `OmdsEmptyState` | same `OmdsEmptyState`, top-aligned in a 24-gutter / 64-vertical band (R1: the residual space stays white and top-aligned, no viewport-fraction spacer) |

Kit widgets consumed: `JeebTopBar` · `JeebOutlinedCard`.
Tokens: `context.jeebText.cardTitle / .body / .bodySmall`, `context.jeebRoles.accent`,
`colorScheme.primary / .onSurface / .onSecondaryContainer`, `Spacing.*` / `Sizes.*`.
Every inset is `EdgeInsetsDirectional`. Zero `Color(0x…)`, zero raw `TextStyle`, zero `fontSize:`.

## What deliberately did NOT change

Behaviour, navigation and business logic are untouched: the 4-state machine, `OmdsPullToRefresh`,
`OmdsLoadingState` / `OmdsErrorState`, the optimistic mark-read, and the **entire D84 dispatch
switch** are byte-identical. No step added, no affordance removed, no copy meaning changed.

## Refusals (things the neighbour has that this screen must not invent)

1. **No filter chip row** (24's Active / Completed / Cancelled). The inbox has no filter dimension
   in `NotificationsRepository` and no ARB keys for one — building "Unread / All" would be a new
   product surface plus new strings, not a re-skin.
2. **No date-range chip** in the header. Same reason; there is no query parameter behind it.
3. **No trailing action pill** (24's `Track` / `Jeeb it again`). A row's one honest action is the
   whole-row D84 tap; a second visible affordance would be a new edge.
4. **No `Today` / `Earlier` `JeebSectionLabel` grouping.** It needs two new user-visible strings and
   changes the list's structure — a product change, and the parity gate would need an ARB edit.
5. **No `JeebAccentFrameCard` for unread rows.** 24 spends the orange frame on the *one* row that is
   physically moving; an inbox can be entirely unread, and a wall of orange frames is precisely the
   rationing rule §3 forbids. The unread mark stays a Ø9 dot.
6. **No `JeebListRow`.** The row carries four text elements plus a badge; `JeebListRow` is
   title/subtitle/icon/trailing. Bespoke content inside a kit card is the sanctioned house pattern
   (`OrderHistoryCard` does exactly this).
7. **Outlined leading glyphs kept** (`Icons.local_offer_outlined`, …) rather than R10's filled set:
   the glyph identity is contract-pinned by the FM1 RTL mirroring test, and 24's own empty state
   keeps an outlined glyph. Cosmetic; noted in the self-critique.

## Frozen contracts

All four dynamic identifiers are byte-identical: `notifications_root` ·
`notif_row_<id>` · `notif_row_<id>_timestamp` · `notif_row_<id>_unread_badge`.
`notif_row_<id>` is re-homed onto `JeebOutlinedCard`'s own wrapper, which emits
`Semantics(identifier:, button:, container:, explicitChildNodes:)` — the same shape as the
hand-rolled wrapper it replaces (the `OrderHistoryCard` precedent), so the nested timestamp and
unread-badge ids still surface. One id added: `notifications_back` (the top bar's leading circle),
in the `<screen>_<element>` form.

## Verification

- `dart analyze lib/features/notifications` → **No issues found!**
- `flutter test test/features/notifications` → **64/64 pass**, including the FM1 Arabic-RTL row test
  (icon mirrors to the start edge, unread dot to the end edge, no overflow) and the P0-X08
  eyebrow≠title test. No assertion was relaxed and no test file was edited.
- `flutter test test/core/router/w3_w4_routes_resolve_test.dart` → pass (`/notifications` still
  resolves to `NotificationsListScreen`).
- `bash tool/check_design_tokens.sh` → zero hits in `lib/features/notifications`.
- Visual check: rendered at 440×956 against `screens/24-order-history.png` via a throwaway golden
  (harness deleted afterwards) — card shell, gutter, 12px rhythm and the single orange mark line up
  with the neighbour.
