# Gap lane — shell bottom tab bar (`_JeebBottomBar`)

Branch `feat/redesign-24-migration`. Files owned: `lib/features/shell/`.
Nothing committed, no branch touched, no shared file edited, no new dependency.

## What the render actually shows (measured, not eyeballed)

Both boards (`04-client-home.png`, `16-jeeber-home.png`) are 880×1912 @2x. Pixel measurements:

| Element | Board (@2x) | Logical | Implemented |
|---|---|---|---|
| Top rule | y1732–1733, `rgb(229,225,229)` | 1px `#E5E1E5` | `Border(top:)` in `colorScheme.outlineVariant` (= `#E5E1E5`) |
| Rule → glyph | 1734→1758 | ~12 | `_kBarTopPadding = Spacing.small` (12) |
| Selected pill | x50–153, y1758–1817, `rgb(234,231,235)` | 52×30 `#EAE7EB` | 52×30 `colorScheme.surfaceContainerHigh` (= `#EAE7EB`) |
| Pill corner | top-row chord 58px ⇒ r≈28px | r14 (**not** a stadium — a stadium r15 predicts a 55px chord) | `BorderRadius.all(Radius.circular(14))` |
| Glyph → label | pill bottom 1817 → text box ~1827 | ~5 | `Spacing.twoXSmall` (4) — 1px tighter, see below |
| Label ink (selected) | `rgb(11,19,81)` | `#0B1351` | `colorScheme.primary` |
| Label ink (unselected) | `rgb(119,127,192)` | `#777FC0` periwinkle | `colorScheme.onSecondaryContainer` |
| Label below → frame | 1859→1912 | ~26 | `_kBarBottomPadding = 26` |
| Item centres | 51.5 / … / 388 | fifths of (440 − 2×8) | `Expanded` ×5 inside `EdgeInsetsDirectional` 8 |

Rendered geometry after the change (widget-test probe at 440×950, since deleted):
items `y873→924`, pill `LTRB(24.4, 873, 76.4, 903)` = **52×30**, unselected glyph box 22×22 centred
in the same 52×30 footprint, label box `y907→924`. Item centres 50.4 / 135.2 / 220 / 304.8 / 389.6
against the board's 51.5 … 388.

## What changed

1. **Top shadow → 1px rule.** `Container(boxShadow: shadow.withAlpha(13))` became a `DecoratedBox`
   with `Border(top: BorderSide(color: outlineVariant))` (outline over shadow).
2. **Selected pill.** Every glyph now sits in a constant 52×30 box; the selected one fills it with
   `surfaceContainerHigh` at r14. Unselected boxes carry no decoration, so all five glyphs stay on
   one baseline.
3. **Type.** `textTheme.labelSmall` (11/w500 + ls 0.2) → `context.jeebText.bodySmall`, which *is*
   12/w600; only the selected weight is overridden to w700. No `fontSize:` literal.
4. **Ink.** Was `primary` / `colorScheme.outline` (the warm brown `#916F66`) — the brown was simply
   wrong. Now navy / periwinkle.
5. **Glyph size** 24 → 22, and **one filled glyph per tab in both states.** The board never swaps in
   an outlined variant: 04's selected Requests tray and 16's unselected one are the same solid
   shape, only the ink differs. `_Tab.selectedIcon` was therefore folded into `_Tab.icon`.
6. **Layout** `MainAxisAlignment.spaceAround` → five `Expanded` columns inside pad `12/8/26`, which
   is both the board's spacing and a full-width hit target per tab (84.8×51).
7. **Height is no longer a guess.** The bar was a `SizedBox(height: Sizes.fiveXLarge)` (56) inside a
   `SafeArea`; the redesigned bar is 12+51+26 = **89** above the system inset. `_NavBarContentInset`
   used to reserve the same hardcoded 56 for every tab body (VIS-P1-2) — it now takes the real
   `_barHeight(systemInset)`, so a redesigned bar cannot start clipping the last row of a tab.
8. **Bottom inset.** `SafeArea` was replaced by `_barBottomPadding(inset) = max(26, inset + 8)`. The
   board's frame has no gesture bar, so its 26 is the whole bottom gap; on a device the system inset
   takes over only once it needs more than 26 already gave — no doubled gap, never under the home
   indicator.

## Refusals / decisions

- **Tab sets NOT unified** (plan §9-Q1). The board draws one 5-tab bar on both boards; the app's tab
  model is additive-by-capability and the in-app role switch was deleted in July. Restyled in place.
- **`JeebSemanticColors.mutedText` not used**, although §5.1 words the unselected glyph as
  "mutedText". That token is documented decorative-only (the kit's `JeebSystemChip` makes the same
  call), and glyph + label must share one role or they drift apart in dark mode — both read
  `colorScheme.onSecondaryContainer`, which is the same `#777FC0` periwinkle in light.
- **No kit widget was hand-rolled.** The kit ships no bottom-nav primitive and OMDS has none, so the
  bar's metrics are local named consts (no raw literal reaches `SizedBox` / `EdgeInsets` /
  `BorderRadius.circular` / `fontSize`, so `tool/check_design_tokens.sh` stays clean for this file).
- **All `shell_tab_${tab.id}` and `shell_tab_${tab.id}_badge` identifiers preserved byte-identically.**
  The G3 badge now wraps the 22px icon rather than the 52-wide box, or it would float detached at
  the pill's far edge.

## Verification

- `dart analyze lib/features/shell test/features/shell/shell_tab_bar_redesign_test.dart` → **No issues found.**
- `bash tool/check_design_tokens.sh` → 6 violations, **all pre-existing and in other lanes'
  directories** (settlement ×3, location, wallet, reviews); zero in `lib/features/shell`.
- Tests run (mine only): `app_shell_test`, `shell_role_tabs_test`, `shell_role_toggle_mounted_test`,
  `shell_tab_badge_test`, `features/shell/{shell_dual_role_landing, route_visibility_wire,
  home_tab_create_request_fab, dashboard_tab_availability_provider, dashboard_tab_request_feed_provider,
  dashboard_tab_lifecycle_polling}` + the new `shell_tab_bar_redesign_test` → **39 passed, 0 failed.**
- New: `test/features/shell/shell_tab_bar_redesign_test.dart` (4 tests) locks the pill geometry/fill,
  the ink + 12/w700-vs-w600 type, the 1px `outlineVariant` rule with no shadow, and RTL mirroring.

### Not mine (verified)

- `test/widget_test.dart` fails to **compile** on `lib/features/deep_link_targets/chat_detail_screen.dart:1676`
  (`ChatResolutionErrorView` / `_ChatResolvingView` undefined) — screen-21 lane, mid-edit.
- `features/shell/jeeber_feed_banner_hides_requests_test` (×2) and `jeeber_active_card_push_render_test`
  started failing at 15:04 with a horizontal `RenderFlex` overflow in `Row-[<'jeeber-feed-card-footer'>]`
  inside `JeebOutlinedCard`. Cause: `lib/features/jeeber_request_feed/presentation/jeeber_feed_card.dart`
  (mtime 15:04:31, another lane). These files live under `test/features/shell/` by directory only —
  they never import or pump `ShellScreen`. They passed on this same shell change at 14:5x.

## Honest remainders

- Glyph→label gap is `Spacing.twoXSmall` (4) against a measured ~5; using the token beat matching to
  the pixel.
- The board's glyphs are custom SVGs; the closest filled Material icons are used
  (`move_to_inbox` / `local_shipping` / `dashboard` / `payments` / `person`). `dashboard` and
  `payments` match closely, the tray and truck are near-matches at 22px.
- Dark mode is off-spec by plan §9.4: `surfaceContainerHigh` / `onSecondaryContainer` come from the
  unbranded `fromSeed` dark scheme, so the pill and periwinkle are approximations there.
- Only the bar was touched. The rest of the shell (`_HeaderedTab`'s wallet/bell overlay, the tab
  bodies) belongs to other lanes.
