# w4 — `jeeber-home` onto the Jeeb design system

**Lane:** `w4-jeeber-home` · **Branch:** `feat/redesign-24-migration` · **Date:** 2026-08-03
**Neighbour reference:** `docs/redesign-2026-08/screens/16-jeeber-home.png` / `.html`
**Status:** done — 0 analyzer errors in `lib/features/jeeber_home`, no new test failures.

---

## The situation this lane inherited

Screen 16 was already redesigned, but only *some* of its widgets were. Inside
`lib/features/jeeber_home/presentation/` there were two visual languages living side by side:

| Already on the system | Still pre-redesign |
|---|---|
| `jeeber_home_greeting.dart` → `JeebProfileHeader`, 24px gutter | `jeeber_home_screen.dart` `_LoadErrorContent` |
| `availability_card.dart` → `JeebNavySurfaceCard` + `JeebShadows.ctaNavy` | `jeeber_feed_empty_view.dart` |
| `jeeber_no_requests_view.dart` `_NoRequestsEmpty` → `titleProminent` / `bodySmall`, start-aligned | `jeeber_unregistered_view.dart` |
| `jeeber_feed_tab_view.dart` `_EmptyTabState` → same treatment | |

The brief for these three files was therefore **not** "invent a look" — it was "stop being the odd
one out inside your own directory". Every choice below is copied from a sibling in this same folder
or from the board, never freshly designed.

---

## What changed

### 1. `presentation/widgets/jeeber_unregistered_view.dart` — the pre-approval upsell

This is the surface a jeeber sees *most* before approval, and it was the furthest from the system.

| Before | After | Why |
|---|---|---|
| `OmdsEmptyState(illustration, title, subtitle)` — stock M3 `headlineSmall` w500 / `bodyMedium`, `EdgeInsets.all(24)`, 32/16 gaps | explicit column: `context.jeebText.h1` in `colorScheme.primary` → 8px → `context.jeebText.body` in `mutedText` | the ramp; navy headline is the board's only headline ink |
| hero disc filled `colorScheme.tertiary.withValues(alpha: UIConstants.opacityPrimaryLight)` (an ad-hoc 10% orange), glyph `tertiary` | `JeebSemanticColors.accentTint` (12%) fill + `accentRing` (30%) stroke + `context.jeebRoles.accent` glyph | the two sanctioned orange-rationing tokens; same treatment `wallet_hub_screen.dart` `_GiftPill` already ships. Removes the `tertiary`-as-brand-accent pattern `no_raw_semantic_colors_test.dart` guards elsewhere |
| `OmdsPrimaryButton` in `EdgeInsets.symmetric(horizontal: 16)` + a trailing `SizedBox(Spacing.large)` | `JeebCtaFooter.single(child: JeebCtaButton.primary(...))` | h56 navy pill, `JeebShadows.ctaNavy`, `JeebCtaFooter.docked` = 24/0/24/32 — the board's docked footer, and the trailing spacer disappears because the footer owns its bottom inset |

Net: the hero got **shorter** (no `EdgeInsets.all(24)` + 32/16 gaps → horizontal-only padding + 32/8),
so overflow headroom on small viewports improved rather than regressed.

### 2. `presentation/widgets/jeeber_feed_empty_view.dart` — the registered/empty surface

| Before | After | Why |
|---|---|---|
| full-width `AspectRatio(1)` `Image.asset('assets/illustrations/empty_orders.png')` hero | **removed** | both redesigned siblings state it explicitly: *"the empty feed is not an error, so it gets no centred icon slab"*. A 1:1 illustration slab where the first request card belongs was the single loudest "different product" signal on this screen. Decorative only (`ExcludeSemantics`, `errorBuilder` → `SizedBox.shrink`), no key, no test, no other reference — `pubspec.yaml` untouched |
| centred `theme.textTheme.headlineSmall` w800 inked `colorScheme.secondaryContainer`, subtitle `onSecondaryContainer` | start-aligned `titleProminent`/`colorScheme.primary` + 8px + `bodySmall`/`mutedText`, in `fromSTEB(24,24,24,0)` | byte-for-byte `_NoRequestsEmpty`. Also retires two flagged anti-patterns: a *container* role used as text ink (the exact regex `no_raw_semantic_colors_test.dart` forbids in migrated files) and `onSecondaryContainer` on white, which `color_role_contrast_test.dart` asserts is **below AA** |
| bare `OmdsSwitchTile` at a 12px gutter | the tile inside a `JeebOutlinedCard(padding: zero)` at `fromSTEB(24,16,24,0)`, tile `contentPadding` 16/12, `activeColor: context.jeebRoles.success` | r16 + 1.5px outline + 24px gutter + 16px top margin is exactly the band the board draws for the availability strip; the green track is the same `success` role `AvailabilityCard`'s switch uses |

### 3. `presentation/jeeber_home_screen.dart` — the availability load-error state

Composition deliberately left alone (it is the only error surface here and the board draws none);
only the tokens changed.

- gutter `Spacing.large` (20) → `EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge)` (24).
- title `theme.textTheme.titleMedium` → `context.jeebText.titleProminent` in `colorScheme.primary`.
- gap before the CTA `Spacing.medium` → `Spacing.xLarge` (the ~28px block rhythm).
- `OmdsPrimaryButton` → `JeebCtaButton.primary`, same `JeeberHomeScreen.loadErrorRetryKey`.

---

## Constraints honoured

- **Semantics identifiers byte-identical.** `jeeber_home_root`, `jeeber_unregistered_root`,
  `jeeber_unregistered_register_button`, the `delivery_register_now_cta` pass-through,
  `jeeber_home_load_error_retry_cta`, `jeeber_home_accept_orders_switch` — all unchanged, including
  the `explicitChildNodes: true` non-merging boundary the CAP-3 regression test pins. No new
  interactive widget was introduced, so no new ids were coined.
- **Widget `Key`s unchanged:** `rootKey`s, `registerButtonKey`, `loadErrorRetryKey`,
  `jeeber-home-accept-orders-switch`.
- **No pubspec edit. No l10n edit** — every string is an existing ARB key, no copy meaning changed.
- **No flow change:** no step added or removed, no reordering, no navigation change, no new
  affordance. The only subtraction is one decorative image.
- **No shared file touched** → no `wiring/w4-*.md` request was needed.
- **RTL:** `EdgeInsetsDirectional` throughout; grep for `left:`/`right:`/`EdgeInsets.only`/
  `Alignment.center{Left,Right}` across the three files returns nothing.
- **No invented data or endpoints.**
- D56 / D52 / D20 / fee-only framing: none of these three surfaces touch those screens.

## Verification

```
dart analyze lib/features/jeeber_home                    -> No issues found!
flutter test test/jeeber_unregistered_view_test.dart \
             test/jeeber_feed_empty_view_test.dart \
             test/jeeber_home_screen_test.dart \
             test/jeeber_feed_empty_ptr_test.dart        -> +15 All tests passed
flutter test test/features/jeeber_home \
             test/jebv4_284_keyboard_repro_test.dart \
             test/features/shell/jeeber_dashboard_overflow_test.dart \
             test/shell_role_tabs_test.dart \
             test/core/theme test/decision_violations_test.dart \
             test/semantics_identifier_surfacing_test.dart \
             test/qa_keys_batch_test.dart                -> +125 All tests passed
```

Design-token gate patterns (`tool/check_design_tokens.sh`) grepped over the three files: zero hits
(no `Color(0x…)`, no `Colors.*`, no literal `SizedBox`/`EdgeInsets`/`BorderRadius.circular`/
`fontSize`, no raw Material widgets).

---

## Remaining inconsistencies vs the neighbour render (honest list)

1. **The upsell hero is still a Material glyph.** `Icons.delivery_dining` in a Ø200 tinted disc.
   It is now painted from the sanctioned tokens instead of an ad-hoc `tertiary` alpha, but the
   board's illustration language is a bright literal 3D delivery render. This stays a placeholder
   until that asset ships through `omds-flutter`; the doc comment says so.
2. **The accept-orders row is an outlined card, not the board's navy strip.** The board draws
   availability as navy + white ink + green switch. `OmdsSwitchTile` hardcodes its title ink to
   `colorScheme.onSurface`, so on navy the label would be near-invisible, and the kit has no
   switch-row widget. Closing this needs either an OMDS `titleStyle`/tone hook or a `JeebListRow`
   trailing-switch form — both outside this lane. (Production's own path already uses the navy
   `AvailabilityCard`; this divergence is confined to the dev-seam capture surface.)
3. **Periwinkle on white.** The subtitle line uses `JeebSemanticColors.mutedText` (#777FC0) at
   12px — ~3.76:1 on white, below AA 4.5:1. I matched it **deliberately** because both
   already-redesigned siblings in this directory (`_NoRequestsEmpty`, `_EmptyTabState`) and ~60
   other redesigned call sites use exactly this pairing; diverging in one file would have put two
   different inks on the same role inside one screen. **This should be fixed once, globally** —
   `delivery_tracking_panel.dart:132` shows the escape hatch (`onSurfaceVariant`, which
   `color_role_contrast_test.dart` certifies AA on white).
4. **The header's `★ 4.8` rating pill is still absent.** `JeeberHomeGreeting` carries an existing
   `TODO(redesign-24)` — blocked on the shell header overlay + `GreetingProfileState.rating`. Not
   my lane, not faked.
5. **Two alignment idioms in one feature.** The upsell hero is centred; the empty states are
   start-aligned. Deliberate (a full-screen upsell hero vs. "where the first card would be"), and it
   matches how the board treats heroes elsewhere — but it is worth a second opinion.
6. **The load-error state remains a centred glyph + text + pill.** The board draws no error state
   for screen 16, so I re-inked rather than re-composed. A `JeebInfoNote.error` band under the
   greeting (keeping the dashboard chrome visible) would read more like the system, but that is a
   layout redesign, not a re-skin, so it is left as a suggestion.
