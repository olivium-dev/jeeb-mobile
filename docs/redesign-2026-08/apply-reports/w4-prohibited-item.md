# Apply report — w4 · prohibited-item report

**Lane:** `prohibited-item` · **Date:** 2026-08-03 · **Branch:** `feat/redesign-24-migration`
**Reference:** no render exists for this screen. Neighbour used as the language reference:
`screens/13-otp-handover.png` (the screen immediately adjacent in the jeeber's at-door journey).

## Files

| File | Change |
|---|---|
| `lib/features/prohibited_item_report/presentation/prohibited_item_report_screen.dart` | rewritten onto the kit (98 → 156 LOC, most of the growth is the R1 page shape + comments) |
| `lib/features/prohibited_item_report/presentation/prohibited_item_report_l10n.dart` | NEW — feature-local EN/AR stopgap for the five previously hardcoded strings |
| `test/features/prohibited_item_report/prohibited_item_report_screen_test.dart` | NEW — 5 tests (structure, enable rule, typing, AR locale, 2× text scale) |
| `docs/redesign-2026-08/wiring/w4-prohibited-item.md` | NEW — one open l10n request; no kit, no route requests |

## What the neighbour does, and what this screen did instead

| 13 OTP handover (the language) | This screen, before |
|---|---|
| In-body header: Ø40 tonal circle + navy `h2` title, 24px gutters | `OMDSAppBar` — a Material app bar with a centred M3 title |
| One quiet `JeebInfoNote` (r16 grey strip, 17px glyph, no shadow) | `Card` on `errorContainer` — an elevated red slab with a `bodyMedium` line |
| 24px side gutters, ~20px block rhythm | `EdgeInsets.all(16)` on everything |
| One `flex:1` spacer, then a footer docked at `0/24/32` | `Spacer()` then a full-bleed button flush against the 16px padding |
| Footer pills: navy primary, or a 1.5px brown outline for the escape hatch | `OmdsPrimaryButton` with `backgroundColor: colorScheme.error` |

## What changed

1. **`OMDSAppBar` → `JeebTopBar.back`**, in-body, inside a `SafeArea` + `Column` — the board's header
   grammar, identical construction to screen 13. Carries the new `prohibited_item_report_back` id.
2. **`_WarningCard` (private `Card` + `errorContainer` + `Row`) deleted → `JeebInfoNote.warning`.**
   The private widget is gone entirely; the kit owns the fill, radius, padding, gap, glyph size and
   the body style. Tone `warning` (not `error`) because the copy is guidance about *when* to use the
   screen, not a failure — and it keeps the caution the original red slab carried.
3. **`OmdsPrimaryButton(variant: outlined)` → `JeebCtaButton.outline`** for `Attach Photo`
   (same glyph, same no-op `onTap`, same full-width shape, now the kit's 1.5px brown pill).
4. **`OmdsPrimaryButton` → `JeebCtaFooter.single` + `JeebCtaButton.primary`** for `Report Item`.
   The footer's `0/24/32` dock and the R1 page shape (content → one real `Spacer` → footer, inside a
   viewport-height `SingleChildScrollView` so 200 % text scrolls instead of overflowing) are lifted
   verbatim from screen 13's `_HandoffPage`.
5. **Gutters 16 → 24** (`Spacing.xLarge`), block rhythm `Spacing.large` (note → field) and
   `Spacing.small` (field → attach, a deliberately tighter pair).
6. **Field radius 12 → 16** via `UIConstants.borderRadiusLarge`, so it matches the note above it.
7. **Copy off the literals** onto `ProhibitedItemReportL10n` (EN byte-identical, AR added) — the
   `OtpHandoverL10n`/`LiveTrackingL10n` precedent. Shared-ARB batch queued in the wiring file.
8. **Identifiers added** (there were none): `prohibited_item_report_root` / `_back` /
   `_description` / `_attach_photo` / `_submit`.

## Judgement calls a reviewer should check

- **The destructive red CTA became a navy pill.** The kit has four CTA variants — navy, outline,
  text, accent-text — and no destructive fill; §3 rations orange to what is happening or expiring
  *now*, which a report action is not. The caution is carried by the warning note above it instead.
  This is the one change with a semantic cost, and it is reversible in one line
  (`labelStyle`/`variant` swap) if the owner wants the red back.
- **`warning` over `muted` for the note.** The board's info panels are grey; this one is amber.
  Flattening it to `muted` would have been more render-faithful and less faithful to the original,
  which deliberately shouted. I kept the meaning.
- **`Attach Photo` stayed a full-width outline pill** rather than becoming an `inlineAction`
  `JeebSelectChip`. A chip would be more board-typical for a secondary in-form action, but it would
  shrink the hit area and demote an affordance — out of scope for a re-skin.

## Refusals / not done

- **No new copy.** The board's screens open with a navy `h1` + periwinkle subtitle; adding one here
  would invent user-visible strings. Refused.
- **No new data.** The screen has no repository — submit is `Navigator.pop(true)`, `requestId` is
  still unused (it was before too). Nothing was faked to fill the empty lower band.
- **No route.** The screen stays an orphan; the ORPHAN comment is preserved byte-for-byte.
- **No `pubspec`, no `lib/l10n/*`, no `lib/core/*`, no kit edits.**

## Verification

- `dart analyze lib/features/prohibited_item_report test/features/prohibited_item_report` → **No issues found!**
- `flutter test test/features/prohibited_item_report` → **5/5 pass** (the screen had zero tests before).
- Design-token gate patterns (`Color(0x…)`, `Colors.*`, literal `SizedBox`/`EdgeInsets`/
  `BorderRadius.circular`/`fontSize`, raw `AppBar`/`TextField`) grepped against the changed file →
  clean.
- Full suite and repo-wide analyze deliberately NOT run (≈20 sibling lanes editing concurrently).

## Remaining inconsistencies vs the neighbour

1. No headline/subtitle band — the page goes top bar → caution note → form. Needs new copy.
2. The amber note is the loudest element above the CTA; the board's panels are grey.
3. The description field is still OMDS's Material field (floating label, 16/12 inner padding).
   The board draws no multiline text area anywhere, so there is no design truth to match.
4. No orange anywhere. Correct rationing for a screen with nothing live or decaying, but it does
   read cooler than 13, where the arrival banner and the SMS link both carry accent.
5. Copy is stopgap-localized, not shared-ARB localized, until the wiring request lands.
6. Only reachable from the dev-tool catalog — the visual work ships to no user until someone routes
   it (out of this lane's scope).
