# Wiring requests — gap lane `request-type` (screens 07 + 08)

Closes out the two `partial` apply reports. Everything below is either a request on a file this
lane does not own, or an owner decision. Screen code was written as if granted.

---

### cross-feature — CORRECTS the open kit bug filed by both prior lanes (07 "W-7" / 08 kit request #4)
file: lib/core/widgets/jeeb/jeeb_tier_row.dart (Wave-1 kit lane)

need: the catalog row's first Row overflows horizontally when the badge and the price caption
compete for width. **The repro both prior lanes filed is wrong and should not be chased**: they
measured "5 horizontal overflows at 360×640, and one even at 1.0 scale" in a widget test with **no
font loaded**, so every string was measured with the fallback face (≈35% wider than Inter). Re-run
with the shipped Inter (`test/support/load_test_fonts.dart`), the real numbers are:

| viewport | text scale | overflow |
|---|---|---|
| 440×956 | 1.0 | none |
| 360×780 | 1.0 (en and ar) | none |
| 360×780 | 1.3 | none |
| 360×780 | 1.5 | none |
| 360×780 | **2.0** | **1 × 51px, on the badged row only** |
| 440×956 | 2.0 | none |

So this is **not** a normal-use defect — it is a 200%-text-scale accessibility defect, and it exists
on exactly one row (the one carrying `badgeLabel`).

exact change: in `_CatalogBody`, the first `Row`'s `Expanded` child holds
`emoji · Flexible(name) · _Badge`, and `_Badge` is unshrinkable, so past ~1.6× the badge's intrinsic
width exceeds the slack and the badge paints over `JeebPriceMeter`'s caption with a striped edge.
Wrapping `_Badge` in `Flexible` (and letting its `Text` ellipsize), or dropping the badge to the
second line above a threshold, both fix it. The feature side cannot: it only passes strings in.

why: at 200% text a customer sees a yellow-and-black striped bar across the recommended tier — the
one row the design most wants read.

---

### cross-feature — OWNER DECISION (unchanged, restated because it is now the most visible divergence)
file: lib/features/tier_selection/data/tier_repository.dart

need: both boards draw the badge on **Standard** (07 designer note: *"'Most picked' nudge on
Standard"*; 08 draws `Recommended` on Standard). The catalog flags **Flash**
(`tier_repository.dart:100` for the live parse, and the `FakeTierRepository` default catalog).
The screen renders `tier.recommended` and never hardcodes a tier, so this is a one-line data
decision, not a screen change.

exact change: `recommended: id == TierId.flash` → `recommended: id == TierId.standard`, and move
`recommended: true` from the Flash entry to the Standard entry in `FakeTierRepository`. Second call
in the same breath: the shipped badge word is `Most picked` (`requestTypeMostPickedBadge`), which
asserts unmeasured popularity; 08's board word is `Recommended`. Changing it is an ARB **value**
edit, no call-site change.

why: `lib/features/tier_selection/` is outside this lane's directory, and the value is also a
product claim.

---

### cross-feature — dead file inside this lane's directory, deliberately left in place
file: lib/features/request_type/presentation/selectable_radio_glyph.dart

need: the 07 lane deleted its last importer (`request_tier_card.dart`). A tree-wide grep still finds
zero importers today. It is unreachable code sitting in this lane's directory.

exact change: none applied. Deleting it is a one-line `rm`, but the 09 lane's option cards are being
edited concurrently and the file exists precisely to serve them; a delete now is a merge landmine
for zero user-visible gain.

why: flagged, not removed — same call the 07 lane made, restated so it does not get lost.

---

### theme / design — divergences from the board that this lane is NOT closing
file: (no file edit — for the design owner)

1. **`Deliver to` shows one line, not two.** The board draws `Home — Achrafieh, Beirut` over
   `Current location`. There is no resolved destination at this step — the flow picks it on the NEXT
   screen, and `ComposeRequestController` carries no address field. `RequestLocationRow` already
   takes `addressLabel`/`qualifierLabel`; the day the flow resolves a destination earlier, pass them.
   Omitted, not faked.
2. **The pin is navy, not `#E02020`.** Raw hex is banned in `lib/features`
   (`tool/check_design_tokens.sh`) and R10 restricts icons to navy/periwinkle. Needs a token if the
   owner wants the red pin.
3. **SLA chips come from `Tier.slaMinutes`**, so Express reads `≤ 3 hr` (board: `≤ 2 hr`) and Eco
   reads `≤ 48 hr` (board: `Today`). The board's literals disagree with the catalog the gateway
   serves; changing them is a catalog decision, not a screen one.
4. **The chrome is 07's.** Inside `/request-type` the top bar reads `Choose your request` and the
   docked CTA reads `Continue` — not 08's `Delivery tiers` / `Confirm tier`. There is one screen and
   one frozen CTA identifier.
5. **Nothing is pre-selected**, although both renders depict a chosen tier and 08's designer note
   says "Recommended pre-selected". Pinned by `request_type_deliberate_selection_test.dart` and the
   cubit invariant. Refusal upheld.
6. **`JeebTierRow.compact` is not used on this screen.** The live picker is the 08 catalog row
   (`02-PLAN-ENHANCED.md:24`: *"selection is a navy fill — not a radio"*, explicitly about the
   picker inside `request_type_screen.dart`). Consequence: the kit's `_Badge` tinted treatment —
   the one legitimate `accentTint` use board-wide — has **no consumer in the app today**; the badge
   here renders solid orange, which is 08's treatment and correct for this row.
