export const meta = {
  name: 'midnight-m5-gap',
  description: 'M5 gap — audit items my hardcoded fix grouping missed, plus the orchestrator rulings on Tier A/B/D',
  phases: [{ title: 'Gap', detail: 'kyc + delivery_receipt + otp_handover · kit dead-motion deletion' }],
}
const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'

const RULINGS = `
**ORCHESTRATOR RULINGS on the M5 audit — these bind you.**

The audit found ZERO missing motion and ZERO wrong-shape: all 76 in-scope board declarations are wired at the exact period AND delay, every ladder correct. All 18 findings are motion the board does not draw. I split them on a principle worth stating, because it decides several of them:

**The board is a STATIC artifact. Its silence about one-shot transitions is not evidence against them.**
- **Idle / infinite motion**: the board CAN express this (CSS keyframes), so where a tile declares none, that silence IS evidence the designer chose stillness. Tier A items are therefore defects → REMOVE.
- **One-shot, user-triggered transitions** (a success beat after confirming, a page-dot slide, a selection tick): a frozen HTML export cannot depict these at all, so its silence says nothing. Rule 6's "no enter/exit or one-shot animations anywhere on the board" describes what was *observable in the export*, not a prohibition. Tier B items are therefore KEPT — except where the code is dead.

RULINGS:
- **A4 KycReviewMark — REMOVE.** R23 is board-static and rule 5 says all 20 zero-motion tiles ship completely still. An infinite scan-line Lottie on a wizard status head is exactly the novelty §7.5 item 6 bounces. A still \`_GlyphMark\` fallback already exists at \`kyc_status_view.dart:358\` — use it.
- **B3 KycApprovedMark (one-shot success-check) — KEEP.** User-triggered completion feedback. Verify it is reduce-motion safe and reads on navy.
- **B1 receipt confirmed overlay — KEEP**, same reasoning. Verify reduce-motion + navy.
- **B10 otp_handover error shake — KEEP.** Off-tile error feedback; the file's own comment says the jeeber leg is not on the board. Verify reduce-motion safe.
- **B9 \`AnimatedSlide(offset: Offset.zero)\` in otp_at_door_card — DELETE.** The offset is a compile-time constant, so it never animates: pure cruft on a zero-motion tile.
- **D1 \`JeebLottieMark\` + the unreferenced animation JSONs — DELETE.** Dead infrastructure from the retired 08-MOTION-SPEC.
- **A5 delivery_status \`pulseActive\` — SKIP.** That dir is production-dead pending owner ruling Q-043; animating or de-animating dead code is waste.
`

phase('Gap')
const r = await parallel([
  () => agent(`You are the M5 GAP lane (features) in ${REPO}, branch feat/redesign-midnight. NEVER run git commit/checkout/stash/branch. GOLDEN RULE: code comments max 2 lines, only when super necessary.

**Why you exist:** I fanned the M5 fix phase out over a HARDCODED directory list instead of deriving it from the audit's own grouping — the second time I have made that exact mistake. Three audit-named dirs got no lane. Yours.

YOU OWN: lib/features/kyc/, lib/features/delivery_receipt/, lib/features/otp_handover/ and their tests.
${RULINGS}

YOUR WORK LIST:
- **A4** \`kyc/presentation/widgets/kyc_status_marks.dart:39\` (reached via kyc_status_view.dart:441 ← kyc_wizard_screen.dart:192) — infinite \`kyc-review.json\` Lottie on board-static R23. REMOVE per the ruling; fall back to the existing still glyph.
- **B3** \`kyc/presentation/widgets/kyc_status_marks.dart:111\` KycApprovedMark — KEEP; verify reduce-motion safety and that it reads on navy.
- **B1** \`delivery_receipt/presentation/widgets/receipt_confirmed_overlay.dart:69\` — KEEP; same verification.
- **B10** \`otp_handover/presentation/otp_handover_screen.dart:591\` error shake — KEEP; verify reduce-motion safety.
- **B9** \`live_tracking/presentation/widgets/otp_at_door_card.dart:25\` — **NOT YOURS** (another lane owns live_tracking); ignore it.

For anything you KEEP, "verify reduce-motion safe" means: under \`MediaQuery.disableAnimations\` it must not run, and a test must prove it. If a kept animation is NOT reduce-motion safe today, make it so — that is a real accessibility defect, not a style preference.
CONSTRAINTS: tokens/kit only; ZERO raw hex, ZERO Colors.* (transparent ok); do NOT modify lib/core/** (FROZEN — a sibling lane owns the kit this wave). Preserve frozen test identifiers by re-homing. RTL-safe.
**Captures are rest-frame and cannot show motion** — evidence is per-element assertions proved by mutation (revert the value, confirm red, restore). Goldens tolerate 5% and do NOT gate.
VERIFY: flutter analyze --no-pub on your three dirs → 0 errors · targeted tests before/after · flutter test test/core/motion → still green.
RETURN: items handled · what was removed vs kept and why · reduce-motion verification per kept animation · before/after counts · discrimination proof · anything left.`,
    { label: 'gap: kyc+receipt+handover', phase: 'Gap', model: 'opus' }),

  () => agent(`You are the M5 KIT DEAD-MOTION lane in ${REPO}, branch feat/redesign-midnight. NEVER run git commit/checkout/stash/branch. GOLDEN RULE: code comments max 2 lines, only when super necessary.
YOU OWN: lib/core/widgets/motion/, lib/features/home_client/presentation/widgets/client_home_motion.dart, lib/features/live_tracking/presentation/widgets/otp_at_door_card.dart, assets/animations/, pubspec.yaml asset declarations, and the matching tests.
${RULINGS}

YOUR WORK LIST — all deletions of provably dead code. **Verify each is dead before removing it; a previous deletion lane found a documented "FROZEN identifier" comment that was provably false, so check, do not trust comments.**
- **D1** \`lib/core/widgets/motion/jeeb_lottie_mark.dart\` — \`JeebLottieMark\`, reported ZERO call sites. Confirm with an import-graph style check (resolve relative AND package: imports; a plain grep gives false negatives), then delete.
- **D1b** The unreferenced \`assets/animations/*.json\`: reported as \`courier-in-transit\`, \`mic-listening\`, \`nearby-scan\`, \`onboarding-say-it\`, \`voice-waveform\`, and \`broadcasting\` (which survives only in a doc comment). Confirm each individually, delete the dead ones, and update pubspec asset declarations if a directory empties.
- **A2** \`client_home_motion.dart\` \`ClientHomeEmptyMark\` — reported zero call sites, and 02-STUDY-NOTES already deferred its death to "the M5 audit". Confirm and delete.
- **B9** \`otp_at_door_card.dart:25\` \`AnimatedSlide(offset: Offset.zero)\` — the offset is a compile-time constant so it never animates. Delete the wrapper, keep the child.

**The plan records that 2 Lotties are DELIBERATELY unwired and must STAY unwired and unregistered.** Identify them before you delete anything, and do NOT delete those two — confirm in your report which two you protected and on what evidence.
**\`lottie\` must stay pinned EXACTLY 3.3.1** (a caret resolves to 3.5.1 and breaks CI at Flutter 3.38.9). If your change would perturb that, STOP and report.
VERIFY: flutter analyze --no-pub → 0 errors · flutter test test/core/motion test/core/widgets/jeeb test/features/home_client test/features/live_tracking → green (before/after) · confirm \`grep -A1 "  lottie:" pubspec.lock\` still resolves 3.3.1.
RETURN: per-item dead-verification evidence · what was deleted · which 2 Lotties you protected and why · before/after counts · lottie pin confirmation · anything you refused to delete and why.`,
    { label: 'gap: kit dead motion', phase: 'Gap', model: 'opus' }),
])
return { features: r[0], kit: r[1] }
