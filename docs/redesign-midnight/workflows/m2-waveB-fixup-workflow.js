export const meta = {
  name: 'midnight-m2-waveB-fixup',
  description: 'Wave-B fixup: 7 sanctioned kit/theme changes, router-harness regression, pin-value defect, then consumer adoption',
  phases: [
    { title: 'Kit+Fix', detail: 'kit variants · kit metrics + glow factor · router harness · pin defect' },
    { title: 'Adopt', detail: 'client_offers radar · jeeber_home street · live_tracking stepper' },
  ],
}

const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const TILES = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/export-rich-ui/screens'
const BOARD = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/Jeeb Rich UI.dc.html'

const COMMON = `
Repo ${REPO}, branch feat/redesign-midnight. Verify with \`git status -sb\`. NEVER run git commit/checkout/stash/branch — leave changes in the working tree.
GOLDEN RULE (user mandate): code comments max 2 lines, only when super necessary.
Read docs/redesign-midnight/01-TOKEN-SHEET.md + 02-STUDY-NOTES.md §"Wave-B review rulings" first — that section is what authorises your work; do not re-litigate it.
Analyze baseline: 0 errors / 30 known infos. Your bar: 0 errors, no NEW warnings.
Other lanes are editing other dirs concurrently. Touch ONLY the files listed as yours. If analyze/tests report an error in a file that is not yours, re-run ONCE; report it only if it reproduces.
RETURN raw data: what changed per file · API added (exact signatures) · test results · deltas you could not close · open questions.`

const KIT_VARIANTS = `YOU OWN: lib/core/widgets/jeeb/jeeb_empty_state.dart, lib/core/widgets/jeeb/jeeb_avatar.dart and their tests in test/core/widgets/jeeb/.
The kit is RE-FROZEN; these three additions are explicitly sanctioned (02-STUDY-NOTES §Wave-B rulings 1-3). Additive only — do not change existing variant behaviour, and re-freeze by extending the kit tests.

1. \`JeebEmptyStateVariant.radar\` — E2's waiting state. Read the tile ${TILES}/28-e2-empty-waiting-for-offers.png AND docs/redesign-midnight/03-MOTION-NOTES.md §E2 (authoritative, 7 animated elements). Board geometry, from the HTML at ${BOARD} lines ~1746-1794: three concentric rings 300/216/132px, 1px, rgba(215,59,0,.12/.20/.32), each \`jArcPulse\` 3s with delays 1s / .5s / 0s (outward-to-inward, so the pulse reads as travelling toward the centre — keep the ladder exactly); a 150px centre glow radial rgba(215,59,0,.35)→0 on \`jBreathe\` 3s; a 58px orange centre disc with a \`0 0 0 8px rgba(215,59,0,.22)\` bloom ring which does NOT move; three 36px avatar discs on \`jBreathe\` 2.6s at 0 / .8s / 1.6s with fill .12/.09/.06 and ink 1.0/.7/.45 stepping down together; one 6px orange satellite dot that does NOT twinkle. Tokens only — no raw hex.
2. \`JeebEmptyStateVariant.street\` — E3. Tile ${TILES}/29-e3-empty-no-requests-nearby.png, motion notes §E3, board lines ~1795-1888. A night-street scene: streetlamp bulb (r7, #FFC107 → amber token) and its light cone (#FFC107 @ .12) breathe as ONE composed element, \`jBreathe\` 3.6s no delay; two listening arcs (#D73B00 → accent, 3.5px) \`jArcPulse\` 2.2s at 0 and .45s. The delivery box, ground line, road dashes, the emitter dot and THIS TILE'S SPARKLES ARE ALL STATIC (unlike E1/E4 — do not reuse the sparkle ladder here).
3. \`JeebAvatarFill.glass\` — a new rung: white ~22% fill with a WHITE initial (existing \`primary\` is opaque navy and invisible on the field; \`dormant\` also forces periwinkle ink). Needed by R15's Ø74 disc and by the radar variant's initial-bearing discs. Also give \`JeebEmptyState\`'s medallion a way to carry a letter/initial rather than only an \`IconData\` — the radar avatars are "K"/"N"/"R".

Consumers adopt these in a later phase — your job is the kit API + tests. Report the EXACT public signatures you added; the adopting lanes are given your report verbatim.
VERIFY: flutter analyze --no-pub lib/core/widgets/jeeb → 0 errors · flutter test test/core/widgets/jeeb → ALL green (the suite was 588 after wave-A fixup; it must not regress).`

const KIT_METRICS = `YOU OWN: lib/core/widgets/jeeb/jeeb_code_cells.dart, lib/core/widgets/jeeb/jeeb_stepper.dart, lib/core/widgets/jeeb/jeeb_midnight_field.dart and their tests in test/core/widgets/jeeb/ and test/core/theme/.
All three changes are explicitly sanctioned (02-STUDY-NOTES §Wave-B rulings 4-7). Additive/parametric — do not change unrelated behaviour.

1. \`JeebCodeCells\` display-tile border: \`glassBorderStrong\` (.16) → \`glassBorderVivid\` (.22). R13 measures .22, which is the exact cluster glassBorderVivid was added for.
2. \`JeebStepper\` bar form: add a fill-through / done-ink parameter so the passed segments can be ORANGE (R3) or PERIWINKLE (R18) — two tiles genuinely disagree, so this is a parameter, not a per-screen repaint. Default must keep today's behaviour for existing callers. This unblocks M2-14 (R18) and lets live_tracking drop its feature-side duplicate in the next phase, so make the public API comfortable for both.
3. **\`_glowRadiusFactor\` 1.35 → 1.18** (jeeb_midnight_field.dart:173, and the explanatory comment at :171). See 01-TOKEN-SHEET §8 CORRECTION: CSS \`radial-gradient(520px 420px at …)\` gives RADII, the phone canvas is 440 wide, so 520/440 = 1.18. The board cluster is rx 500-560, mode 520; R1 itself is \`500px 380px\`. The shipped 1.35 renders 594px — wider than any glow on the board. Do NOT touch the periwinkle wash's own factor (its board ellipse is \`700px 560px\` = 1.59×) — check whether the \`startMid(0.0, 0.39, 0.18, 0.667, 1.35)\` tuple at :44 is the wash's own radius and leave it alone if so; say explicitly which 1.35s you changed and which you did not.

IMPORTANT — the field has ~27 tests, some described as "pixel-verified vs R1 within ~1%". Changing the factor may break them. That is expected: they were pinned to the wrong factor. Re-derive each failing expectation from the BOARD value (R1 draws \`radial-gradient(500px 380px at 85% -5%, …)\`), update it, and report exactly what each test asserted before and after. Do NOT weaken an assertion to make it pass.
VERIFY: flutter analyze --no-pub lib/core → 0 errors · flutter test test/core/widgets/jeeb test/core/theme → ALL green.`

const ROUTER_HARNESS = `YOU OWN: test/core/router/ (every file) — and NOTHING under lib/. This is a TEST-HARNESS fix only.
PROBLEM (already diagnosed — do not re-diagnose, verify and fix): \`flutter test test/core/router/\` is 95 pass / 38 fail. Every failure is \`pumpAndSettle timed out\`, thrown on the FIRST pumpAndSettle after mounting the app shell, before any navigation. Cause: the shell's home tab mounts \`JeebEmptyState\`, whose E1 illustration runs Midnight motion primitives that loop INFINITELY BY DESIGN (03-MOTION-NOTES §E1: 7 animated elements). pumpAndSettle can never settle against an infinite animation. This is NOT a product bug — R1's field decor is correctly static (\`animateDecor: false\`).
FIX: the sanctioned pattern from 02-STUDY-NOTES §Motion — screen tests advance with \`tester.pump(duration)\`, and \`pumpAndSettle\` is only legal under reduce motion. Mount these harnesses with \`MediaQuery(data: MediaQueryData(disableAnimations: true), …)\` (wave-B lanes did exactly this for their own suites: see test/features/live_tracking/tracking_cancelled_state_test.dart and test/features/jeeber_home/ for the in-repo precedent — follow it rather than inventing a new one).
Preserve every assertion. Do not delete or skip a test to make the suite green; if a test cannot be fixed this way, leave it failing and report why.
THEN SWEEP: this failure mode is almost certainly not confined to test/core/router/. Run the wider suite and find every OTHER test that fails with \`pumpAndSettle timed out\` on a tree containing the shell / home / any JeebEmptyState. Report the full list with file:test-name. Fix the ones inside test/core/router/ yourself; for anything outside it, REPORT ONLY (other lanes own those dirs) — a precise list is what I need.
VERIFY: flutter test test/core/router/ → report exact pass/fail before and after.`

const PIN_DEFECT = `YOU OWN: lib/features/location/presentation/capture_location_screen.dart and test/google_map_picker_launcher_test.dart. Nothing else.
LIVE DEFECT (pre-existing, verified byte-identical before M2-05): \`_onPin\` calls \`Navigator.of(context).maybePop()\` with NO VALUE. So \`GoogleMapPickerLauncher.pickOnMap()\` (lib/features/location/data/google_map_picker_launcher.dart) always resolves \`null\`. Its live consumer is \`address_detail_form_screen.dart:219\` ("Edit pin"), which therefore silently discards the coordinate the user just chose. \`test/google_map_picker_launcher_test.dart\` has 2 failing tests that assert exactly this (\`expect(result, isNotNull)\`).
FIX: pop the pinned \`LocationPoint\`. Mind the existing duality — the screen ALSO supports an \`onPinned\` VoidCallback used by the router path, and \`test/capture_location_map_injection_test.dart\` has a PASSING test ("Confirm drop-off CTA fires onPinned (the route returns the centre)") that must STAY passing. Both paths must work: callback callers keep their callback, pop callers get the value.
Read the screen and the launcher before editing; the centre coordinate the launcher expects is the map's current centre.
VERIFY: flutter test test/google_map_picker_launcher_test.dart test/capture_location_map_injection_test.dart test/delivery_create_screens_test.dart test/features/location → ALL green. flutter analyze --no-pub lib/features/location → 0 errors.`

phase('Kit+Fix')
const p1 = await parallel([
  () => agent(`${KIT_VARIANTS}\n${COMMON}`, { label: 'kit:variants', phase: 'Kit+Fix', model: 'opus' }),
  () => agent(`${KIT_METRICS}\n${COMMON}`, { label: 'kit:metrics+glow', phase: 'Kit+Fix', model: 'opus' }),
  () => agent(`${ROUTER_HARNESS}\n${COMMON}`, { label: 'fix:router-harness', phase: 'Kit+Fix', model: 'opus' }),
  () => agent(`${PIN_DEFECT}\n${COMMON}`, { label: 'fix:pin-value', phase: 'Kit+Fix', model: 'opus' }),
])

const variantsApi = p1[0] || '(kit variants lane returned nothing — inspect before adopting)'
const metricsApi = p1[1] || '(kit metrics lane returned nothing — inspect before adopting)'

const ADOPT = `
The kit fixup landed in the SAME working tree you are editing. Here is the kit lane's own report of what it added — treat these signatures as the source of truth and read the widget source to confirm before calling it:

--- KIT VARIANTS LANE REPORT ---
${variantsApi}
--- END ---

GOLDEN RULE: code comments max 2 lines, only when super necessary. Repo ${REPO}, branch feat/redesign-midnight; NEVER run git commit/checkout/stash/branch.
Tokens/kit only: ZERO raw hex, ZERO Colors.* (transparent ok). Do NOT modify lib/core/** — it is another lane's output and is now re-frozen again. RTL-safe. Respect MediaQuery.disableAnimations.
Analyze bar: 0 errors, no new warnings.
RETURN: what changed per file · before/after test results · captures re-baselined · anything you could not close.`

phase('Adopt')
const p2 = await parallel([
  () => agent(`YOU OWN lib/features/client_offers/ and its tests.
Adopt the new \`JeebEmptyStateVariant.radar\` in lib/features/client_offers/presentation/widgets/offers_waiting_state.dart, replacing the E1-ring stand-in that M2-07 shipped. The M2-07 lane's own selfCritique listed the deltas to close: the rings are currently white/dotted instead of three orange \`jArcPulse\` rings on the 1/.5/0 ladder; the medallions are uniform instead of a 3-step brightness ladder; there is no 6px satellite dot; and E1's waveform "ears" are present but do not belong on E2. The three avatars carry initials K / N / R.
Tile: ${TILES}/28-e2-empty-waiting-for-offers.png. Motion authority: docs/redesign-midnight/03-MOTION-NOTES.md §E2.
Keep the loading and error states working off the same block (they share it today).
VERIFY: flutter analyze --no-pub lib/features/client_offers → 0 errors · flutter test test/features/client_offers test/client_offers_screen_test.dart test/offer_card_test.dart → green · re-capture: flutter test test/tools/catalog_capture_test.dart --update-goldens --plain-name "client-offers__client-offers-screen" --tags capture, then copy the PNGs to docs/redesign-midnight/captures/M2-07-r10-e2/.
${ADOPT}`, { label: 'adopt:E2-radar', phase: 'Adopt', model: 'opus' }),

  () => agent(`YOU OWN lib/features/jeeber_home/ and its tests.
Adopt the new \`JeebEmptyStateVariant.street\` in lib/features/jeeber_home/presentation/widgets/jeeber_no_requests_view.dart (and any other E3 mount in that dir), replacing the \`balcony\` stand-in M2-12 shipped. balcony draws a request bubble and a jDash route that E3 does not have; street is the real subject.
Tile: ${TILES}/29-e3-empty-no-requests-nearby.png. Motion authority: docs/redesign-midnight/03-MOTION-NOTES.md §E3 — note this tile's sparkles are STATIC.
Do not re-open anything else on this screen; M2-12 is committed and accepted.
VERIFY: flutter analyze --no-pub lib/features/jeeber_home → 0 errors · flutter test test/features/jeeber_home test/jeeber_home_screen_test.dart test/jeeber_feed_empty_ptr_test.dart → green · re-capture: flutter test test/tools/catalog_capture_test.dart --update-goldens --plain-name "jeeber-home__" --tags capture, then copy the PNGs to docs/redesign-midnight/captures/M2-12-r16-e3/.
${ADOPT}`, { label: 'adopt:E3-street', phase: 'Adopt', model: 'opus' }),

  () => agent(`YOU OWN lib/features/live_tracking/ and its tests.
M2-08 painted R3's stepper bar row FEATURE-SIDE from the kit's public metrics, because JeebStepper hardcoded the passed-segment colour and the kit was frozen. That parameter now exists. Adopt it: delete the duplicated bar painting in lib/features/live_tracking/presentation/widgets/order_tracking_stepper.dart and drive the kit widget with R3's ORANGE fill-through instead.
Here is the kit lane's report of the exact API it added:
--- KIT METRICS LANE REPORT ---
${metricsApi}
--- END ---
Behaviour must not change: passed segments orange, glow on the ACTIVE index only, labels spaceBetween with the active one accent/w800 and the rest mutedText/w700, and all four frozen semantics identifiers preserved with their value+selected flags. R3 is fully STATIC — the stepper must not animate its active segment.
If the new kit API cannot express R3's treatment, STOP and report exactly what is missing rather than re-adding a local painter.
VERIFY: flutter analyze --no-pub lib/features/live_tracking → 0 errors · flutter test test/features/live_tracking test/order_tracking_jeeber_card_test.dart test/tracking_google_map_test.dart → green (215 passed before) · re-capture: flutter test test/tools/catalog_capture_test.dart --update-goldens --plain-name "live-tracking__order-tracking" --tags capture, then copy the PNGs to docs/redesign-midnight/captures/M2-08-r3/.
${ADOPT}`, { label: 'adopt:R3-stepper', phase: 'Adopt', model: 'opus' }),
])

return {
  kitVariants: p1[0], kitMetrics: p1[1], routerHarness: p1[2], pinDefect: p1[3],
  adoptE2: p2[0], adoptE3: p2[1], adoptR3: p2[2],
}
