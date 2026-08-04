export const meta = {
  name: 'midnight-m6-preview-inversion',
  description: 'Invert 13 defect-characterization preview tests whose defects M4 actually fixed',
  phases: [{ title: 'Invert', detail: 'gps_denied_state + kyc_status_screen preview specs' }],
}
const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
phase('Invert')
const r = await agent(`You are the M6 PREVIEW-INVERSION lane in ${REPO}, branch feat/redesign-midnight. NEVER run git commit/checkout/stash/branch. GOLDEN RULE: code comments max 2 lines, only when super necessary.
YOU OWN exactly: test/previews/location/gps_denied_state_preview_test.dart and test/previews/deep_link_targets/kyc_status_screen_preview_test.dart.

**These 13 tests are now failing FOR A GOOD REASON, and that is the whole job.** They are defect-CHARACTERIZATION tests: each asserts that its screen is broken. The M4 states sweep restyled both screens and fixed the defects, so the characterizations are now false. Confirmed examples:
- "nothing here scrolls" → \`Expected: no matching candidates / Actual: Found 1 Scrollable\` — the sweep added scrolling.
- "a compact phone overflows a FULL screen body at 200%" → \`Expected: contains 'overflowed' / Actual: 'null'\` — it no longer overflows.
- "the copy is hardcoded English, so Arabic renders English" · "the screen contains no scrollable of any kind" · "the Semantics wrapper announces the copy twice" · "the 100 pt icon does not follow the text scaler" · "the CTA is tappable but carries no button role".

**INVERT each one to assert the CORRECT behaviour. Do NOT delete them and do NOT loosen them.** A test that said "this overflows" becomes one that says "this does not overflow"; "nothing scrolls" becomes "the body scrolls"; "the copy is hardcoded English" becomes "the copy is localized and Arabic renders Arabic". The value in these files is that somebody characterized real defects precisely — keep that precision pointing the other way. Rename each test so its name states the property that now holds; a test named for a defect that no longer exists is a trap for the next reader.

**Verify the defect is genuinely fixed before inverting.** For each, read the screen and confirm the fix is real. **If any defect is NOT actually fixed — the test fails for some other reason — say so and leave that test failing rather than inverting it into a false green.** That distinction is the point of this lane.
Two named in the list may be subtler than the rest: "the Semantics wrapper announces the copy twice" (double-announcement is an a11y defect — confirm it is genuinely gone, not merely re-shaped) and "the icon does not follow the text scaler" (confirm the icon now actually scales, rather than the assertion having drifted).

PROVE each inverted assertion discriminates: revert the screen-side behaviour it now claims, confirm the test goes red, restore. **Goldens tolerate 5% and do NOT gate.**
VERIFY: flutter analyze --no-pub on both files → 0 errors · flutter test on both files → all green · flutter test test/features/location test/features/deep_link_targets → still green (before/after).
RETURN: per-test — the old claim, whether the defect is genuinely fixed (with the screen-side evidence), the new claim, and the mutation that proves it · anything you refused to invert and why.`,
  { label: 'invert: preview defect specs', phase: 'Invert', model: 'opus' })
return { inverted: r }
