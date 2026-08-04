# Gap apply report — 07 · Request type + 08 · Tier catalog

Lane: `gap-request-type` · branch `feat/redesign-24-migration` · 2026-08-03
File: `lib/features/request_type/presentation/request_type_screen.dart` (+ its `widgets/`)
Status: **done for the code this lane owns** — with four named divergences carried forward as owner
/ kit decisions (`wiring/gap-request-type.md`).

---

## What the two `partial` reports were actually blocked on — and what that turned out to mean

Both prior reports (`apply-reports/07-request-type.md`, `.../08-tier-catalog.md`) shipped complete
implementations and then said the same thing: *"`AppLocalizations` is hand-authored, the screen does
not compile, so the lane test files could not be run"*, and both fell back to throwaway probes.

**That blocker is gone.** The l10n batch landed (`app_en.arb:4762+`, `app_ar.arb:1709+`, and the
hand-written getters in `app_localizations.dart:2590+`). Consequences, all verified this session:

* `dart analyze lib/features/request_type test/features/request_type` → **No issues found** (the
  8 + 16 `undefined_getter` hits the two reports carried are gone).
* Every test the two lanes deferred now runs and passes: `test/features/request_type/` +
  `test/delivery_create_screens_test.dart` + `test/semantics_identifier_surfacing_test.dart`
  → **34 passed, 0 failed**.
* `bash tool/check_design_tokens.sh` → zero violations in `request_type`.

So the screens were **not** shipping pre-redesign chrome. The rebuilt shell (`JeebTopBar.back`,
`JeebTierRow.catalog`, `JeebPriceMeter`, `JeebInfoNote.muted`, `JeebCtaButton.primary`, the filled
`Deliver to` card, the docked navy pill) is what runs at `/request-type` today. What was missing was
**verification** — and one real defect that only verification could surface.

---

## The one real defect found and fixed

**The catalog does not fit a 360dp phone, and the `Deliver to` card ended flush against the docked
CTA.** The board is drawn at 440×956, where the content stops well short of the footer; the device
the owner tests on is 360dp-class, where five two-line catalog rows + the pricing note push the
`Deliver to` block below the fold. It scrolls (verified reachable), but `_bodyPadding` had a bottom
inset of `0`, so at the end of the scroll the card's bottom edge sat at **exactly 0px** from the
Continue pill.

Fix: `_bodyPadding` bottom `0` → `Spacing.large`, with the reason recorded in the comment. On tall
viewports it costs nothing — the `Spacer` absorbs it and the board's deliberate empty tail is
unchanged (measured: address card bottom is 190px clear of the footer at 440×956).

Pinned by a new lane-owned test, `test/features/request_type/request_type_layout_test.dart`
(5 cases). Reverting the padding fails it with `Actual: <0.0>`.

---

## The kit bug both prior lanes filed does not exist at normal text scale

Both reports filed a horizontal-overflow bug against `jeeb_tier_row.dart` — 07 as "W-7", 08 as kit
request #4 — one of them claiming overflows on the **badged row at 1.0 scale**. Both measured in a
widget test **with no font loaded**, where every string is laid out with the fallback face (~35%
wider than Inter). Re-measured with the shipped Inter via the repo's own
`test/support/load_test_fonts.dart`:

| viewport | scale | overflow |
|---|---|---|
| 440×956 · 360×780 · 360 `ar` | 1.0 | **none** |
| 360×780 | 1.3 / 1.5 | **none** |
| 360×780 | 2.0 | 1 × 51px, badged row only |
| 440×956 | 2.0 | none |

The kit request stands, but as a **200%-text-scale accessibility defect on the badged row**, not a
normal-use one. Corrected repro in `wiring/gap-request-type.md`. Three of the new layout test's
cases lock the 1.0 result in so this cannot silently regress.

---

## Render re-review (goldens rendered, read back, then discarded)

Rendered the live screen at 440×956 (board parity), 360×780 (device), 360×780 scrolled, `ar` RTL and
2.0 text scale using the repo golden harness (`loadInterTestFont` + `withGoldenTestFonts`, which
also registers MaterialIcons), and compared each against `screens/07-request-type.png` and
`screens/08-tier-catalog.png`. **No golden was committed** — this repo's goldens are Linux-CI
baselines and a macOS-rendered file would break them.

Matches the board: top bar (Ø40 circle + 20/w700 title), periwinkle subtitle, five r16 rows on the
brown outline at 8px gaps, the four-dot orange meter with its caption right-aligned, the SLA chip +
vehicle line, the selected row as a navy **fill** with the shadow and the 15px white check at the
end of the second line, the solid-orange badge pill, the muted pricing note, `Deliver to` + the
filled address card, the empty tail, and the h56 navy pill. RTL mirrors correctly (top bar, meter,
chip, check all swap edges; the numeric SLA stays LTR-isolated).

Remaining differences are listed in `wiring/gap-request-type.md` §"divergences" — the badge sits on
Flash (data flags Flash, board draws Standard), the address card is one line (no destination exists
at this step), the pin is navy (hex ban), the SLA bands come from data, the chrome is 07's, and
nothing is pre-selected.

---

## Files changed

| File | Change |
|---|---|
| `lib/features/request_type/presentation/request_type_screen.dart` | `_bodyPadding` gains a `Spacing.large` bottom inset + the why-comment |
| `test/features/request_type/request_type_layout_test.dart` | **new**, 5 cases: no overflow at 360/360-ar/440 with the real font; the `Deliver to` card clears the docked CTA on a 360dp phone; the board viewport keeps its empty tail |
| `docs/redesign-2026-08/wiring/gap-request-type.md` | **new** — corrected kit request, owner decisions, divergences |
| `docs/redesign-2026-08/apply-reports/gap-request-type.md` | this file |

Nothing else was touched. `tier_selection_screen.dart` untouched, `/tier-selection` not resurrected,
no new route, no kit edit, no theme edit, no ARB edit, no new dependency.

## Frozen inventory — intact

`request_type_flash_radio` · `_express_` · `_standard_` · `_on_the_way_` · `_eco_radio` (via
`requestTypeRadioId`) · `request_type_continue_cta` · `request_type_back` ·
`request_type_current_location_label` · `request_type_change_location_button` ·
`Key('request-type-continue')`. No identifier added, renamed or removed by this lane.

## Still open (not this lane's to close)

* Kit: badge row overflow at 2.0 text scale.
* Owner: badge tier (Flash vs Standard) and badge wording (`Most picked` vs `Recommended`).
* Owner/kit: whether the picker should keep **radio** semantics — `.catalog`'s a11y node is
  `container + selected` where `.compact`'s was `inMutuallyExclusiveGroup + checked`. The 08 lane
  changed two tests to follow the kit. The identifiers are unchanged, but a screen reader now
  announces "selected" instead of "checked" on a mutually-exclusive list. Fixing it means the kit's
  `.catalog` node, not this screen.
* On-device: whether `🟦` (Standard) renders acceptably (plan §9-7). Widget-test goldens draw tofu
  for every emoji, so this genuinely needs the S22.
* `selectable_radio_glyph.dart` is now importer-less dead code in this directory; left in place.
