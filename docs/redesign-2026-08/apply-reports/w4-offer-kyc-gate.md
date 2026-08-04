# w4 · offer-kyc-gate — apply report

**Status: applied, one wiring request outstanding.**
No render exists for these two screens; the reference used was the neighbour they hand off to,
`screens/22-become-a-jeeber.{png,html}`, plus the already-migrated `transcription_screen.dart` and
`kyc_identity_step.dart` for house structure.

Scope: **re-skin only.** No new step, no reordered action, no removed affordance, no copy change,
no navigation or behaviour change, no new l10n key, no new endpoint or field.

---

## Files changed (both inside `lib/features/offer_kyc_gate/`, this lane's own directory)

| File | What |
|---|---|
| `presentation/offer_kyc_gate_screen.dart` | `OMDSAppBar` → `JeebTopBar.back`; `ListView` → `Expanded > SingleChildScrollView` + docked `JeebCtaFooter.single`; centred hero glyph dropped; headline/body onto `context.jeebText`; the KYC status line and the D67 top-up note onto `JeebInfoNote`; `OmdsPrimaryButton`/`TextButton` → `JeebCtaButton`. |
| `presentation/delivery_register_prompt_screen.dart` | Same treatment; `delivery_dining` hero glyph dropped. |

Nothing else was touched — no router, no DI, no `lib/l10n/*`, no `lib/core/**`, no kit file, no
`pubspec.yaml`, no `.maestro/**`.

---

## What was actually wrong before

Both screens were a `ListView` of centred content: a `Sizes.sixXLarge` navy outline glyph, a centred
`headlineSmall.copyWith(w700)` headline, centred `bodyMedium` body, a centred `bodySmall` note, then
`OmdsPrimaryButton` + two `TextButton`s stacked in the scroll flow at 16px gutters, under a Material
`OMDSAppBar` with a **centre-aligned** title. Every one of those is off-board: the redesign has no
oversized outline glyph on any of its 24 screens, no centred body column, no 16px gutter, no
centred app-bar title, and it ends 22 of 24 screens in a docked footer under a real `flex: 1` band
of white.

The token layer was already partly clean (zero hex literals, `jeebRoles` for state colour), so this
change is mostly **shape and rhythm**, not colour.

---

## Kit widgets consumed (no private copies, nothing hand-rolled)

`JeebTopBar.back` · `JeebCtaFooter.single` · `JeebCtaButton.primary` · `JeebCtaButton.text` ·
`JeebInfoNote` (`.muted` + `warning`/`error` tones).

Tokens: `context.jeebText.h1` / `.body`, `colorScheme.onSurface` / `.onSurfaceVariant`,
OMDS `Spacing.*` for the 24px gutter and the block rhythm. Zero raw `TextStyle`, zero `fontSize:`,
zero `Color(0x…)`, zero hardcoded left/right.

---

## Semantics — every existing identifier byte-identical

`offer_kyc_gate` · `gate_topup_note` · `gate_start_kyc_cta` · `gate_register_link` ·
`gate_back_cta` · `delivery_register_prompt` · `delivery_register_prompt_cta` ·
`delivery_register_prompt_back`. Same spelling, same wrapper idiom
(`Semantics(identifier:, button:, container:)` on each exit), same wrapper on the root
(`container: true, explicitChildNodes: true`). Verified by mounting both screens and asserting
`find.bySemanticsIdentifier(id) → findsOneWidget` for all eight.

**Two new ids** (the redesign's new in-body back circle, `<screen>_<element>`):
`offer_kyc_gate_back`, `delivery_register_prompt_top_back`.
The register prompt's circle is deliberately *not* `delivery_register_prompt_back` — that id is
already owned by the in-body text CTA on the same screen, and two nodes sharing one identifier
break both Maestro's `tapOn: id` and `find.bySemanticsIdentifier`.

`gate_topup_note` moved from a bare `Semantics > Text` to `JeebInfoNote(identifier:)`, whose kit
wrapper is `container: true, explicitChildNodes: true`. The id still resolves to exactly one node;
Maestro only asserts its visibility (`jm-044` AC5), never its label.

---

## Decisions honoured

- **D67 kept, verbatim.** The "you can still top up while in review" note is the load-bearing
  product copy on this screen. It changed *panel* (bare centred `bodySmall` → `JeebInfoNote.muted`
  with a wallet glyph) and nothing else — same key, same string, same position, still the last
  thing above the fold.
- **D38 invariant untouched.** All three exits still exist, in the same order, to the same
  destinations, by the same ids. `gate_register_link` still `go`es to the standalone
  `delivery-register-prompt` route rather than popping the tab (the W2 RD-1 fix); its long
  rationale comment moved with it.
- **D52 not touched and not tripped.** The rejected branch still renders the FINAL copy with **no**
  resubmit CTA. `kyc_rejected_resubmit_cta` does not exist here and was not introduced. The only
  CTA on the screen remains the pre-existing `gate_start_kyc_cta`.
- **D20 / fee wording:** neither screen names a vehicle or a commission; nothing added.

## Deliberate refusals

- **No orange.** The board rations `jeebRoles.accent` to "what is happening or expiring right now".
  A KYC gate has no countdown, no live state and no decaying action, so spending accent here to
  make the screen look more like the render would be decoration, not signal. Both screens ship
  navy + neutrals only. This is the most visible remaining difference from the neighbour and it is
  a choice, not an omission.
- **No invented content.** The neighbour's middle band is three capture rows; this gate has no
  per-document data to render and no endpoint that would supply it, so the band stays flat rather
  than gaining fabricated `JeebOutlinedCard` rows.
- **No `JeebSectionLabel`.** Neither screen has two sections to separate.

---

## Divergences from the design language, stated

1. **Two type levels compete.** The `JeebTopBar` title is `h2` (20/w700) and the body headline
   below it is `h1` (24/w700) — the second line is larger than the bar title, which the board
   generally avoids ("only four things on the spine exceed 20px"). Both strings exist today
   (`offerKycGateTitle` and `offerKycGateHeadline`), both must render, and the already-migrated
   `transcription_screen.dart` resolves the same collision the same way, so this follows the house
   precedent rather than inventing a third scale. Reversible in one line if the owner prefers
   `titleProminent`.
2. **The footer stacks three affordances** (h56 pill + two h48 text rows ≈ 162px). No board screen
   stacks two bare text CTAs. The alternative was leaving two exits mid-scroll while the third
   docked, which reads worse; removing one is forbidden (Maestro AC3/AC4 tap both).
3. **Secondary labels ellipsize at one line.** `JeebCtaButton` is `maxLines: 1` kit-wide.
   `"I haven't registered as a Jeeber yet"` fits at default scale with
   `contentPadding: EdgeInsetsDirectional.zero` (measured: no overflow at 360×640, RTL, 200% text —
   it ellipsizes rather than wrapping, where the old `TextButton` wrapped to two lines).
4. **`JeebInfoNote.muted` ink is periwinkle 12.5/w500 on `#EAE7EB`** — sub-AA, and this note
   carries the D67 promise. It is the kit's own paint and byte-matches the neighbour's identical
   "Review usually takes under 24 hours" panel, so the lane conformed rather than forking. Flagged
   for whoever owns the kit's contrast question.

---

## Verification

```
dart analyze lib/features/offer_kyc_gate            → No issues found!
flutter test test/core/theme/no_raw_semantic_colors_test.dart
              test/core/router/w2_routes_resolve_test.dart
              test/core/session/jeeber_kyc_status_gate_test.dart
              test/decision_violations_test.dart
              test/core/router/back_button_blank_surface_test.dart
              test/core/theme/color_role_contrast_test.dart      → all pass
flutter test test/back_arrow_dead_at_root_test.dart → 1 pass, 2 FAIL  ← see wiring/w4-offer-kyc-gate.md
```

`tool/check_design_tokens.sh` reports 3 violations repo-wide; **none are in this lane's files**
(`client_location_screen.dart`, `wallet_activity_list_screen.dart`, `reviews_list_screen.dart`).

A throwaway probe (written, run, deleted — not left in the tree) additionally verified, on both
screens: all eight frozen identifiers resolve to exactly one node; the new top-bar circle at stack
root still navigates to `/`; and neither screen throws or overflows at 360×640 under `ar` RTL at
200% text scale.

### The two failures

`back_arrow_dead_at_root_test.dart` finds the back affordance with
`find.widgetWithIcon(IconButton, Icons.arrow_back)`. `JeebTopBar` contains no `IconButton` — the
kit paints `Semantics(button:) > MinTapTarget > DecoratedBox > Icon`. **The guarded behaviour is
intact** (both screens still pass an explicit `onLeadingPressed` mirroring their own in-body exit,
and the probe above confirms the tap lands on `/` from stack root); only the finder is stale.
The one-line fix is written out paste-ready in
`docs/redesign-2026-08/wiring/w4-offer-kyc-gate.md` (WR-1). It touches a shared test file outside
this lane's directory, which is why it is a request and not a commit. `kyc-rejected`, the third
case in that file, still uses `OMDSAppBar` and keeps the existing finder.
