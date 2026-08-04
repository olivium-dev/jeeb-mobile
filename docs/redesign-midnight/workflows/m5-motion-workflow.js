export const meta = {
  name: 'midnight-m5-motion',
  description: 'M5 — motion pass: audit every screen against the board-measured notes, then fix from the audit grouping',
  phases: [
    { title: 'Audit', detail: 'motion vs 03-MOTION-NOTES · Lottie/asset navy audit · reduced-motion' },
    { title: 'Fix', detail: 'lanes derived from the audit output' },
  ],
}

const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const TILES = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/export-rich-ui/screens'
const BOARD = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/Jeeb Rich UI.dc.html'

const MOTION_AUDIT = `You are the M5 MOTION AUDIT lane for the Jeeb MIDNIGHT redesign in ${REPO}, branch feat/redesign-midnight.
**You write NO production code this run.** Your deliverable is an evidence-backed discrepancy list. NEVER run git commit/checkout/stash/branch.

\`docs/redesign-midnight/03-MOTION-NOTES.md\` is AUTHORITATIVE, per element, board-measured. Read it in full first. Its headline fact: **20 of the 30 in-scope tiles have ZERO animation** — motion is deliberately concentrated in R2 (voice), R5/W1-W3 (onboarding art) and E1-E4 (empty states). All 84 declarations use the 8 §2.6 primitives; there are no others.

AUDIT BOTH DIRECTIONS — under-wiring and over-wiring are both defects:
1. **MISSING**: every element the notes list must be present, with its primitive, duration and delay. The delay LADDERS are the design, not decoration — e.g. the R5/W1 bubble pair is 4s and 4.4s **with a 1.2s offset**, W2's two orbit rings share 3.2s **with a .6s offset**, E2's rings walk **1 / .5 / 0** outward-to-inward. A pair wired at the right durations with the offset dropped is a defect.
2. **EXTRA**: any animation on a screen whose tile the notes mark zero-animation. Per §7.5 item 6 adding motion the board does not draw is a review-bounce. Check especially for: a typing indicator on R20, star twinkle on R15, a marching dash on R3's route, and any pulsing on R1 (its "Broadcasting" dot and orbit ring are STATIC on the board — a fact that contradicts the plan's own §4 text, and the notes win).
3. **WRONG SHAPE**: two rules the notes call out as repeat offenders — \`jWave\` goes on the waveform CONTAINER with static bars beneath it (never per-bar stagger), and \`jHalo\` goes on a ring SIBLING, never on the disc it surrounds.
4. **M3 screens**: they have no tile, and the M3 standing ruling is no motion beyond what kit widgets bring. Flag any M3 screen that animates something itself.

Method: grep for the motion primitives and the module in \`lib/core/motion/\`, then read each consuming screen. Cross-reference \`${BOARD}\` where you need a value the notes do not carry.

For EVERY discrepancy record: file:line · screen · which notes section governs · MISSING/EXTRA/WRONG-SHAPE · what the board says · what the code does · and a verdict.
Then **GROUP the fixes by top-level feature directory with a count per dir** — the next phase fans out one lane per group and the grouping IS the work plan. (The orchestrator hardcoded a grouping in M4 and three directories got no lane; do not let that happen here — your grouping is what drives the fan-out.)
Be honest about limits: say which angles found nothing, and flag anything you suspect exists that your method could not see.
RETURN: the discrepancy table · the per-dir grouping with counts · a list of screens VERIFIED correct (so the fix phase does not redo them) · what you could not see.`

const ASSET_AUDIT = `You are the M5 ASSET / LOTTIE lane in ${REPO}, branch feat/redesign-midnight. NEVER run git commit/checkout/stash/branch. GOLDEN RULE: comments max 2 lines, only when super necessary.
YOU OWN \`assets/\` and any \`lib/\` file that only needs a reference updated to follow an asset you change.

Master plan §4 M5: *"Audit pass-1 Lotties on navy"* — the design language went from a light theme to a deep navy field, so art authored against white can be invisible, muddy, or a glaring bright block. Known flags carried forward:
- \`assets/illustrations/delivery_3d.png\` was imported at M0-7 and **flagged navy-hostile** in 02-STUDY-NOTES §Map rulings: *"cyan/magenta 3D art (not the navy/orange pair) — flagged for the M5 navy-hostility audit before any screen uses it."* Determine whether anything uses it now, and whether it can live on navy.
- \`assets/illustrations/onboarding_trusted_jeebers.svg\` and \`onboarding_live_tracking.svg\` have **zero importers** since M2-21 replaced them with drawn art (Q-040). Confirm and recommend.
- Pass-1 Lotties: the plan records that **2 are deliberately unwired and must stay unwired and unregistered**. Identify them, confirm they are still unwired, and audit the rest against the navy field.

For each asset: where it is used (or that it is orphaned) · does it read correctly on \`#070C33\`–\`#0B1351\` · verdict RECOLOUR / REPLACE / DELETE / KEEP, with evidence (sample the actual pixels; do not judge from the filename).
**\`lottie\` must stay pinned EXACTLY 3.3.1** — a caret resolves to 3.5.1 and breaks CI at Flutter 3.38.9. If anything you do would perturb that, STOP and report.
Deleting an asset is a real change: confirm zero importers first and update \`pubspec.yaml\` asset declarations if a whole directory empties.
VERIFY: flutter analyze --no-pub → 0 errors · flutter test test/core/widgets/jeeb test/features/onboarding → green · confirm \`grep -A1 "  lottie:" pubspec.lock\` still resolves 3.3.1.
RETURN: per-asset table with verdicts and pixel evidence · what you changed · what you recommend but did not do · lottie pin confirmation.`

const REDUCED_MOTION = `You are the M5 REDUCED-MOTION lane in ${REPO}, branch feat/redesign-midnight. NEVER run git commit/checkout/stash/branch. GOLDEN RULE: comments max 2 lines, only when super necessary.
YOU OWN \`lib/core/motion/\` and its tests. Treat the rest of \`lib/core\` as FROZEN.

The standing rule (02-STUDY-NOTES §Motion): Midnight primitives loop ∞ board-faithfully, so **screen tests advance with \`tester.pump(duration)\` and \`pumpAndSettle\` is only legal under reduce motion**; captures run with \`disableAnimations: true\` so every capture is the deterministic REST FRAME. That rule has already cost two waves real time when harnesses omitted it, so verify it actually holds:
1. Every primitive in \`lib/core/motion/\` must pin a deterministic rest frame under \`MediaQuery.disableAnimations\`, and must not merely freeze mid-cycle at whatever phase it happened to reach.
2. **Settle open question Q-037.** \`jTwinkle\` and \`jArcPulse\` rest at ~0.2 opacity, so a UI element carrying one is nearly invisible in every still — W2's *verified badge* is the concrete case (\`jTwinkle\` on a badge, not a star). \`jBlink\` already pins its LIT keyframe rather than its dark one. The question: should reduce-motion pin **UI-bearing** elements at their lit keyframe, while decorative sparkles keep resting dark? Decide it from the principle that reduce-motion must not destroy information a sighted user needs — a verified badge is information, a sparkle is not. Implement your ruling, and say plainly what you chose and what it changes.
3. Confirm nothing regressed: run the motion suite and the screens with real motion (R2 voice, onboarding/walkthrough, the empty states).

PROVE each new assertion discriminates: revert the value, confirm red, restore. **Goldens are evidence, not gates** (5% tolerance) — assert on the widget.
VERIFY: flutter analyze --no-pub lib/core/motion → 0 errors · flutter test test/core/motion test/core/widgets/jeeb → green (before/after) · flutter test test/features/onboarding test/voice_recording_screen_test.dart test/features/client_offers → green.
RETURN: rest-frame verification per primitive · your Q-037 ruling and its reasoning · what changed · before/after counts · discrimination proof · anything left.`

phase('Audit')
const p1 = await parallel([
  () => agent(MOTION_AUDIT, { label: 'audit:motion', phase: 'Audit', model: 'opus' }),
  () => agent(ASSET_AUDIT, { label: 'audit:assets', phase: 'Audit', model: 'opus' }),
  () => agent(REDUCED_MOTION, { label: 'fix:reduced-motion', phase: 'Audit', model: 'opus' }),
])

const motionAudit = p1[0] || '(motion audit returned nothing)'
log('Motion audit complete — fanning the fix phase out over ITS grouping, not a hardcoded one.')

const FIX = `You are a FIX lane for MIDNIGHT **M5 — the motion pass** in ${REPO}, branch feat/redesign-midnight. NEVER run git commit/checkout/stash/branch. GOLDEN RULE: comments max 2 lines, only when super necessary.

An audit lane just checked every screen against \`docs/redesign-midnight/03-MOTION-NOTES.md\` (board-measured, authoritative per element). **Its report is below — the discrepancies in YOUR directories are your work list.** Fix MISSING, EXTRA and WRONG-SHAPE items. Do not touch anything it marked verified-correct.

--- M5 MOTION AUDIT ---
${motionAudit}
--- END AUDIT ---

THE RULES THAT GOVERN YOU:
- **20 of 30 tiles are STATIC.** Removing motion the board does not draw is as much a fix as adding motion it does. §7.5 item 6 makes added novelty motion a review-bounce.
- **Delay ladders ARE the design.** Right durations with the offset dropped is still a defect: R5/W1 bubbles 4s + 4.4s @1.2s · W2 rings 3.2s @.6s · E2 rings 3s @ 1/.5/0 outward-to-inward · E1/E4 sparkles 2.4/2.8/3.0s @ 0/.7/1.3s.
- **\`jWave\` on the CONTAINER**, static bars beneath — never per-bar stagger. **\`jHalo\` on a ring SIBLING**, never on the disc, which does not move. Both are named repeat offenders.
- Consume \`lib/core/motion/\` — do NOT hand-roll an AnimationController for something the module already provides, and do NOT modify \`lib/core/**\` (FROZEN; another lane owns the motion module this wave).
- Respect \`MediaQuery.disableAnimations\`; screen tests use \`pump(duration)\`, never \`pumpAndSettle\` on a looping surface.

**Captures are REST-FRAME by design and cannot show motion.** Your evidence must be per-element assertions — the widget is present, its primitive type, its duration, its delay — proved by mutation: change the value, confirm the test goes red, restore. **Goldens tolerate 5% and do NOT gate.**

Analyze baseline: 0 errors / 30 known infos. KNOWN-RED and NOT yours: chat_header_contrast (5) · dio_tier_repository (2) · gesture_log (1) · 12 files under test/previews/ (2 of them tier_card, inside dead code).
**Do NOT touch \`delivery_status/\`, \`tier_selection/presentation/\` or \`prohibited_acknowledgment/\`** — all three are production-dead pending an owner ruling (Q-043); animating dead code is waste.

VERIFY: flutter analyze --no-pub <your dirs> → 0 errors · targeted tests before/after · flutter test test/core/motion → still green.
RETURN: audit items handled (file:line each) · what changed · MISSING added / EXTRA removed / WRONG-SHAPE corrected, counted separately · before/after counts · discrimination proof · anything you could not close.`

phase('Fix')
const GROUPS = [
  'lib/features/voice_request, lib/features/transcription, lib/features/home_client',
  'lib/features/onboarding, lib/features/registration',
  'lib/features/client_offers, lib/features/jeeber_home, lib/features/jeeber_request_feed, lib/features/no_offer_timeout',
  'lib/features/order_history, lib/features/wallet, lib/features/earnings, lib/features/live_tracking, lib/features/chat, lib/features/deep_link_targets',
]
const p2 = await parallel(GROUPS.map((dirs) => () => agent(
  `YOUR DIRECTORIES: ${dirs}.\nHandle every discrepancy the audit lists in those dirs. **If the audit lists none in one of your dirs, say so explicitly and do NOT invent work** — on a board where 20 of 30 tiles are static, "nothing to change here" is the expected answer for most screens.\n${FIX}`,
  { label: `fix: ${dirs.split(',')[0].replace('lib/features/', '')}…`, phase: 'Fix', model: 'opus' },
)))

return { motionAudit: p1[0], assetAudit: p1[1], reducedMotion: p1[2], fixes: p2 }
