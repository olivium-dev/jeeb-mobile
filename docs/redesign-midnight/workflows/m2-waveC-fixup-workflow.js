export const meta = {
  name: 'midnight-m2-waveC-fixup',
  description: 'Wave-C fixup: 4 sanctioned kit changes + the harness root-cause fix, then consumer adoption across 6 screens',
  phases: [
    { title: 'Kit+Infra', detail: 'field topStart + stepper washed · empty parcel + frame fill · repo latency + guard test' },
    { title: 'Adopt', detail: 'R14/R17/R4/R9 field · R18 · R21 · R16+R20 frames' },
  ],
}

const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const TILES = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/export-rich-ui/screens'
const BOARD = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/Jeeb Rich UI.dc.html'

const COMMON = `
Repo ${REPO}, branch feat/redesign-midnight. Verify with \\\`git status -sb\\\`. NEVER run git commit/checkout/stash/branch — leave changes in the working tree.
GOLDEN RULE (user mandate): code comments max 2 lines, only when super necessary.
Read docs/redesign-midnight/01-TOKEN-SHEET.md and 02-STUDY-NOTES.md section "Wave-C review rulings" FIRST — that section authorises your work; do not re-litigate it.
Analyze baseline: 0 errors / 30 known infos. Your bar: 0 errors, no NEW warnings.
Known-red and NOT yours: test/features/chat/chat_header_contrast_test.dart is 5-red pre-existing (a pass-1 instrument on a pre-Midnight palette, Q-022). Do not try to fix it; do not count it as your regression.
Other lanes edit other dirs concurrently. Touch ONLY the files listed as yours. If analyze or a test reports an error in a file that is not yours, re-run ONCE; report it only if it reproduces.
When you change a shared default or a widget many screens consume, prove the change is safe by running the consumers, not by reasoning about them.
RETURN raw data: what changed per file · exact public signatures added · before/after test counts · what you could not close · questions.`

const KIT_FIELD_STEPPER = `YOU OWN: lib/core/widgets/jeeb/jeeb_midnight_field.dart, lib/core/widgets/jeeb/jeeb_stepper.dart and their tests under test/core/widgets/jeeb/. Both changes are sanctioned (02-STUDY-NOTES "Wave-C review rulings" 8 and 11). Additive only; existing callers must not move.

1. \\\`JeebFieldWashPlacement.topStart\\\` — a new anchor at approximately (0.10, 0.03). This was sanctioned in the WAVE-B rulings but was never briefed to a lane, so it never shipped; R14 shipped on \\\`startMid\\\` (right edge, wrong height) and R17 hit the same wall. It is NOT a one-screen convenience: the board is directional per tile — R4/R9/R17 draw the decorative bloom top-START, while R1/R6/R8/R12/R19/R22/R23 draw it top-END. Measure the real anchor from the board HTML at ${BOARD} (grep the per-tile \\\`radial-gradient(... at X% Y%, ...)\\\` declarations; the phone canvas is 440x956 and the two lengths before \\\`at\\\` are RADII) and use the measured value rather than my approximation if they disagree — say which you used and why.
2. \\\`JeebStepperDoneInk.washed\\\` — a third enum value for R18's PASSED bars, which measure white ~33% (#626794) rather than the ratified periwinkle #8A93D8. RULING: this is a stepper-level enum value, NOT a new glass-fill rung — the glass ladder is 7/10/14 and a 33% fill would blow it open. \\\`periwinkle\\\` stays the default; R3 keeps \\\`accent\\\`.

Add tests for both, and PROVE each new test discriminates (change the value back, confirm the test fails, restore). That standard exists because the old _glowRadiusFactor shipped wrong with no test holding it.
VERIFY: flutter analyze --no-pub lib/core → 0 errors · flutter test test/core/widgets/jeeb test/core/theme → all green (757 before this wave).`

const KIT_EMPTY_FRAME = `YOU OWN: lib/core/widgets/jeeb/jeeb_empty_state.dart, lib/core/widgets/jeeb/jeeb_accent_frame_card.dart and their tests under test/core/widgets/jeeb/. Both sanctioned (02-STUDY-NOTES "Wave-C review rulings" 9 and 10). Additive only.

1. \\\`JeebEmptyStateVariant.parcel\\\` — E4's subject: an open glass parcel box with the mic glowing inside. Tile ${TILES}/30-e4-empty-no-orders-yet.png; motion authority docs/redesign-midnight/03-MOTION-NOTES.md section E4 (4 animated elements: a 170px centre glow on jBreathe 3.2s, and the three-sparkle ladder 2.4/2.8/3.0s at 0/.7/1.3s delay — the 250px orbit ring does NOT pulse). Board lines ~1889-1932. E4 is one of the four canonical empty states in plan section 2.7, which is the same argument that carried radar and street. M2-17 currently ships \\\`e1\\\`, which keeps E4's exact timings but over-draws the waveform ears and 2 star dots — those must not appear on parcel. The three-sparkle ladder is identical to E1's, so reuse that recipe rather than re-deriving it.
2. \\\`JeebAccentFrameCard\\\` frame fill — R21's in-motion row measures an ORANGE 10-12% (\\\`accentTint\\\`) fill INSIDE the accent frame; the widget currently keeps JeebOutlinedCard's white-7% glass. \\\`accentSelectedFill\\\` (20%) is too hot. Add the rung so the frame form can carry the accent tint, defaulting to today's behaviour so existing callers do not move. **R16, R18 and R20 are the other frame consumers** — a later lane re-measures them against your API, so make it expressible for all four, and say in your report exactly how a consumer opts in.

Add tests for both and PROVE they discriminate (revert the value, confirm failure, restore).
VERIFY: flutter analyze --no-pub lib/core → 0 errors · flutter test test/core/widgets/jeeb → all green.`

const HARNESS_ROOT = `YOU OWN: lib/features/home_client/data/in_memory_client_home_repository.dart, plus any TEST file that passes or drains its latency, plus one new guard test you will create under test/. You do NOT own lib/features/home_client presentation code.

1. **Kill the Edit-B class at its source.** \\\`InMemoryClientHomeRepository\\\`'s constructors default to \\\`latency: const Duration(milliseconds: 150)\\\` (lines 9 and 18). That is a FRAMELESS \\\`Future.delayed\\\`: it schedules no frame, so \\\`pumpAndSettle\\\` never advances to it, and every widget test that mounts the shell has to know to drain it with an explicit \\\`pump(200ms)\\\`. It cost two lanes real time and produced 15 compensating harnesses. Change the DEFAULT to \\\`Duration.zero\\\` and have any caller that genuinely wants latency opt IN by passing it. Check every construction site in lib/ first (a real app path may depend on the delay to mask a flash — if so, say so and pass the 150ms explicitly there rather than changing behaviour silently).
2. Then find every test that carries the compensating \\\`await tester.pump(const Duration(milliseconds: 200));\\\` drain added for this repo (commit 73ed7471 and the shell-harness commit added them across ~13 files). Remove the ones that are now unnecessary — but ONLY where the suite stays green afterwards, verified by running it. Keep any drain that is still load-bearing and say which and why. Do NOT remove the reduce-motion \\\`builder:\\\` wrappers; those are for infinite animation and remain required.
3. **Build the guard test.** The reduce-motion wrapper (\\\`MediaQuery.of(context).copyWith(disableAnimations: true)\\\` in a MaterialApp \\\`builder:\\\`) is now load-bearing in 15 harnesses, trivially omitted on a new one, and when omitted it fails as a \\\`pumpAndSettle timed out\\\` that reads like a product bug. Write a test that makes this mechanical rather than procedural — assert that a tree mounting ShellScreen under a harness WITHOUT disableAnimations does not settle, and that the sanctioned wrapper makes it settle. Aim for a guard that would catch a future shell-mounting harness that forgets it. If a static assertion over test sources is more reliable than a behavioural one, do that instead and justify the choice.
VERIFY: flutter analyze --no-pub → 0 errors / 30 infos · flutter test test/core/router test/features/shell test/shell_role_tabs_test.dart test/shell_role_toggle_mounted_test.dart test/app_shell_test.dart test/core/deep_link test/features/home_client → report before/after counts. All must stay green.`

phase('Kit+Infra')
const p1 = await parallel([
  () => agent(`${KIT_FIELD_STEPPER}\n${COMMON}`, { label: 'kit:field+stepper', phase: 'Kit+Infra', model: 'opus' }),
  () => agent(`${KIT_EMPTY_FRAME}\n${COMMON}`, { label: 'kit:parcel+frame', phase: 'Kit+Infra', model: 'opus' }),
  () => agent(`${HARNESS_ROOT}\n${COMMON}`, { label: 'fix:harness-rootcause', phase: 'Kit+Infra', model: 'opus' }),
])

const fieldApi = p1[0] || '(field/stepper lane returned nothing — read the widget source before adopting)'
const emptyApi = p1[1] || '(parcel/frame lane returned nothing — read the widget source before adopting)'

const ADOPT = `
The kit changes landed in the SAME working tree you are editing. Kit lane reports follow — treat the signatures as source of truth but READ the widget source to confirm before calling.

--- FIELD + STEPPER LANE ---
${fieldApi}
--- PARCEL + FRAME LANE ---
${emptyApi}
--- END ---

GOLDEN RULE: comments max 2 lines, only when super necessary. Repo ${REPO}, branch feat/redesign-midnight; NEVER run git commit/checkout/stash/branch.
Tokens/kit only: ZERO raw hex, ZERO Colors.* (transparent ok). Do NOT modify lib/core/** — it is another lane's output and is re-frozen. RTL-safe. Respect MediaQuery.disableAnimations.
Motion authority is docs/redesign-midnight/03-MOTION-NOTES.md — R4/R16/R17/R18/R20/R21 are ALL zero-animation tiles.
Known-red and NOT yours: test/features/chat/chat_header_contrast_test.dart (5 pre-existing failures, Q-022).
RETURN: what changed per file · before/after test counts · captures re-baselined · what you could not close.`

phase('Adopt')
const p2 = await parallel([
  () => agent(`YOU OWN lib/features/delivery_receipt/, lib/features/offers/, lib/features/wallet/, lib/features/request_type/ and their tests.
Adopt the new \`JeebFieldWashPlacement.topStart\` where the tile measures it. The board is DIRECTIONAL PER TILE, so measure each before changing it — do not blanket-apply:
- R14 receipt (${TILES}/14-r14-receipt-confirm.png) — M2-10 shipped \`startMid\` and reported "right hue, right edge, wrong height". Expected to move.
- R17 offer composer (${TILES}/17-r17-offer-composer.png) — M2-13 measured the bloom top-START (#2A1C51 at (20,90) vs #0F175C top-end) but shipped top-END for lack of the anchor. Expected to move.
- R4 wallet (${TILES}/04-r4-wallet.png) and R9 request type (${TILES}/09-r9-request-type.png) — the M2-13 lane's cross-tile read says these are also top-start. RE-CHECK both against their tiles and change ONLY if your own measurement agrees. Report the measurement either way.
For each screen state: measured anchor, what you shipped, and the delta.
VERIFY: flutter analyze --no-pub on your four dirs → 0 errors · flutter test test/features/delivery_receipt test/features/offers test/features/wallet test/features/request_type → green · re-capture each changed screen with flutter test test/tools/catalog_capture_test.dart --update-goldens --plain-name "<filter>" --tags capture and copy PNGs into the matching docs/redesign-midnight/captures/<item>/ dir.
${ADOPT}`, { label: 'adopt:field-topStart', phase: 'Adopt', model: 'opus' }),

  () => agent(`YOU OWN lib/features/active_delivery_jeeber/ and its tests.
Two adoptions on R18 (${TILES}/18-r18-active-delivery-jeeber.png):
1. Move the stepper's passed bars to the new \`JeebStepperDoneInk.washed\` — M2-14 measured the board at white ~33% (#626794) and shipped the ratified periwinkle #8A93D8, which reads brighter and bluer. This closes Q-023.
2. R18 is one of the four \`JeebAccentFrameCard\` consumers. RE-MEASURE its accent-framed surface against the tile now that the frame can carry the orange 10-12% \`accentTint\` fill. Adopt ONLY if your measurement supports it; report the measured fill either way.
VERIFY: flutter analyze --no-pub lib/features/active_delivery_jeeber → 0 errors · flutter test test/features/active_delivery_jeeber → green (report before/after) · re-capture: --plain-name "active-delivery-jeeber" --tags capture, PNGs to docs/redesign-midnight/captures/M2-14-r18/.
${ADOPT}`, { label: 'adopt:R18', phase: 'Adopt', model: 'opus' }),

  () => agent(`YOU OWN lib/features/order_history/ and its tests, plus test/tools/m2_17_capture_test.dart and the order-history catalog entries/fixtures under lib/devtool/catalog/.
Four jobs on R21/E4 (${TILES}/21-r21-order-history.png, ${TILES}/30-e4-empty-no-orders-yet.png):
1. Adopt \`JeebEmptyStateVariant.parcel\` for the E4 empty (M2-17 shipped \`e1\`, which over-draws waveform ears and 2 star dots E4 does not have).
2. Adopt the \`JeebAccentFrameCard\` accent-tint fill on R21's in-motion row — measured orange 10-12% inside the frame vs the white-7% glass shipped.
3. **Restyle \`order_history_date_filter_sheet.dart\`** — it is still light-theme Material/OMDS on a screen we have marked done. Its 3 goldens were 99.87% stale at baseline and were re-baselined against the un-restyled sheet, so re-baseline them again once it is on the Midnight kit. Field/sheet treatment per the token sheet's sheet variant.
4. **Add Completed and Cancelled catalog states** for order history (the catalog has neither, which is why R21's completed-row and expired-row treatments have no official capture). This needs a tab-preselection seam on OrderHistoryScreen — add the smallest one that works, in the style of the existing catalog seams. THEN DELETE test/tools/m2_17_capture_test.dart, the one-off harness that existed only because those states were missing.
Do NOT change the expired-row dimming — 0.65 is shipped pending owner sign-off on Q-006.
VERIFY: flutter analyze --no-pub lib/features/order_history lib/devtool/catalog → 0 errors · flutter test test/features/order_history test/order_history_screen_test.dart test/devtool → green (report before/after) · re-capture: --plain-name "order-history" --tags capture, PNGs to docs/redesign-midnight/captures/M2-17-r21-e4/.
${ADOPT}`, { label: 'adopt:R21', phase: 'Adopt', model: 'opus' }),

  () => agent(`YOU OWN lib/features/jeeber_home/, lib/features/jeeber_request_feed/, lib/features/chat/, lib/features/deep_link_targets/ and their tests.
R16 (${TILES}/16-r16-jeeber-home.png) and R20 (${TILES}/20-r20-order-chat.png) are two of the four \`JeebAccentFrameCard\` consumers. The frame form can now carry an orange 10-12% \`accentTint\` fill instead of white-7% glass, because R21 measured that on the board.
RE-MEASURE R16's and R20's accent-framed surfaces against their tiles and adopt the tint ONLY where your own measurement supports it. Report the measured fill for each either way — a "no change needed" backed by a measurement is a perfectly good result here, and is much better than adopting it because a sibling screen did.
Change NOTHING else on these screens; M2-12 and M2-16 are committed and accepted. In particular do not add a typing indicator (banned) and do not re-open the E3 street adoption.
VERIFY: flutter analyze --no-pub on your four dirs → 0 errors · flutter test test/features/jeeber_home test/features/chat test/features/deep_link_targets test/jeeber_home_screen_test.dart → green (report before/after; chat_header_contrast_test's 5 reds are pre-existing and not yours) · re-capture only what you changed.
${ADOPT}`, { label: 'adopt:R16+R20-frames', phase: 'Adopt', model: 'opus' }),
])

return { kitFieldStepper: p1[0], kitParcelFrame: p1[1], harnessRoot: p1[2], adoptField: p2[0], adoptR18: p2[1], adoptR21: p2[2], adoptFrames: p2[3] }
