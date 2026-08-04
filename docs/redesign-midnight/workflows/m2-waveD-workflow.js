export const meta = {
  name: 'midnight-m2-waveD',
  description: 'M2 wave D — the last 6 rows: R22, R23, R5+W1-3, R6+R7, R8 + wave-C l10n merge + endMid kit fixup',
  phases: [{ title: 'Screens', detail: '5 screen lanes (router owned by registration) + l10n merge + kit fixup' }],
}

const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const TILES = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/export-rich-ui/screens'

const COMMON = `
You are implementing ONE item of the Jeeb MIDNIGHT redesign (dark navy design language) in ${REPO}, branch feat/redesign-midnight (verify with \`git status -sb\`; NEVER run git commit/checkout/stash/branch — leave all changes in the working tree).
GOLDEN RULE (user mandate): comments max 2 lines, only when super necessary.

STEP 0 — MANDATORY before any code:
1. Read your tile PNG(s) with the Read tool — the bottom caption band is the designer's spec note. Write 8+ concrete observations (whatISaw): background layers and glow placement, where orange appears (BUDGETED), ink hierarchy, glass surfaces, radii, spacing, Arabic runs, empty/loading/error treatment, copy literals.
2. Read docs/redesign-midnight/03-MOTION-NOTES.md — YOUR tile's section is the motion authority. Add NOTHING it does not list, and ship every tile it marks zero-animation completely still.
3. Read docs/redesign-midnight/01-TOKEN-SHEET.md + 02-STUDY-NOTES.md. ALL rulings bind you. Note especially the field anchors now available: JeebFieldGlowPlacement{topEnd, centerUpper, bottom, topStart} and JeebFieldWashPlacement{startMid, bottomEnd, topStart}. MEASURE your tile's bloom before choosing — the board is directional per tile, and a wash (periwinkle) is NOT a glow (orange). Several screens shipped mirrored because that distinction was missed.
4. Confirm your files are reachable from lib/main.dart (docs/redesign-2026-08/screen-repo-map.md wins).

CONSTRAINTS:
- Tokens/kit only; ZERO raw hex, ZERO Colors.* (transparent ok). Do NOT modify lib/core/** — it is re-frozen; return the question instead.
- ALL states restyled (default/loading/empty/error); empty family = JeebEmptyState (variants: e1, radar, street, parcel, pocket, balcony, beacon).
- Preserve frozen test identifiers by re-homing; then delete identifier-only chrome.
- Copy = tile literals. NEW l10n keys: do NOT edit lib/l10n/*.arb (a dedicated lane owns it) — write keys + EN/AR to docs/redesign-midnight/l10n-queue/<your-item>.md and use the nearest existing key with TODO(midnight): l10n-queued.
- Missing wire data → designed slot + TODO(midnight): omitted, not faked.
- RTL-safe; respect MediaQuery.disableAnimations. Screen tests advance with pump(duration), never pumpAndSettle on a looping surface; any harness mounting ShellScreen must set disableAnimations (there is now a guard test that will catch you).
- Do NOT touch lib/core/router/app_router.dart unless you own it (stated below). Do NOT touch other lanes' feature dirs.

**STANDING RULE — goldens are evidence, not gates.** Our comparator tolerates 5% pixel diff, so a token re-point on a small element passes a golden unchanged (an R18 ink swap moved 0.097% and three goldens stayed green carrying the wrong colour). Land a per-element assertion that reads the actual colour/geometry off the widget, and PROVE it discriminates by reverting the value and confirming red. Never cite a green golden as proof your change took.

Analyze baseline: 0 errors / 30 known infos. Known-red and NOT yours: test/features/chat/chat_header_contrast_test.dart (5 pre-existing, Q-022).
CONCURRENCY: an l10n lane owns lib/l10n and regenerates getters mid-wave. If analyze or a test reports an error inside lib/l10n or a missing AppLocalizations getter you did not introduce, re-run ONCE; report only if it reproduces.

AFTER IMPLEMENTING — selfCritique: re-Read the tile, list 4+ px/hex-specific deltas, fix what you can, report the rest honestly.
VERIFY: flutter analyze --no-pub <your dirs> → 0 errors · targeted tests (report before/after) · git diff --stat (primary file MUST be non-zero) · re-capture your screens: flutter test test/tools/catalog_capture_test.dart --update-goldens --plain-name "<filter>" --tags capture, then copy PNGs to docs/redesign-midnight/captures/<your-item>/.
RETURN raw data: whatISaw · files+diffstat · changes per file · selfCritique deltas · test results · discrimination proof · l10n queued · TODOs · open questions.`

const SCREENS = [
  {
    item: 'M2-19-r22', label: 'R22 settings',
    prompt: `YOUR ITEM: M2-19 R22 Settings. Files: lib/features/settings/presentation/screens/settings_screen.dart (223 LOC) + its widgets. NOT live_settings_screen.dart — that is an M3 row (it delegates to this screen and is the sole live mount).
Tile: ${TILES}/22-r22-settings.png. Carry-in: the MORE-band restructure (doc-13 P1). Standing CF rulings apply.
MOTION: R22 is fully static — rows, switches and the MORE band all still.
Note lib/features/settings/ has an M3 subtree (profile_edit, notification_prefs, language_settings, password_security, saved_locations, address_detail_form). Restyle ONLY the hub screen and widgets it owns directly; if you touch a shared widget, say which and why.`,
  },
  {
    item: 'M2-20-r23', label: 'R23 become a jeeber',
    prompt: `YOUR ITEM: M2-20 R23 Become a Jeeber (KYC wizard). Files: lib/features/kyc/presentation/kyc_wizard_screen.dart (384 LOC) + its widgets.
Tile: ${TILES}/23-r23-become-a-jeeber.png. Carry-in: the ID-band relocation (doc-13 P1). **The encryption clause is under a LEGAL HOLD — do not reword, move or restyle away any encryption/consent copy; if the board's layout would displace it, keep the clause and report the conflict.**
MOTION: R23 is fully static — the wizard stepper does NOT animate, the ID band and upload tiles are still.
The KYC funnel (dm_onboarding, onboarding_funding, offer_kyc_gate, kyc_rejected, account_status) is M3 — do not restyle those here.`,
  },
  {
    item: 'M2-21-r5-w123', label: 'R5+W1-3 onboarding',
    prompt: `YOUR ITEM: M2-21 R5 Onboarding + W1/W2/W3 walkthrough slides. File: lib/features/onboarding/presentation/onboarding_screen.dart (1087 LOC) + its widgets.
Tiles: ${TILES}/05-r5-onboarding.png, ${TILES}/24-w1-walkthrough-say-it.png, ${TILES}/25-w2-walkthrough-trusted-jeebers.png, ${TILES}/26-w3-walkthrough-live-tracking.png.

**THIS IS THE MOTION LANE — 19 of the board's 76 in-scope animated elements are on your four tiles, more than every other M2 screen combined.** Read 03-MOTION-NOTES sections R5, W1, W2, W3 in full and wire EXACTLY what they list, with their exact delays. The delay ladders ARE the design — copying 4s/4.4s but dropping the 1.2s offset destroys the effect. Highlights, but read the notes yourself:
- R5 and W1 are structurally identical (same art, shifted positions) — **ship ONE widget with two placements**, per the notes' own cheat-sheet.
- Glass bubble pair: jFloat 4s and 4.4s with a **1.2s delay on the second** (that delay is what de-syncs them).
- jWave goes on the waveform CONTAINER, never per bar — the bars are static children. This is a repeat offender; do not stagger them.
- jHalo goes on a **ring sibling**, never on the disc it surrounds. The mic disc itself does NOT move.
- W2: two orbit rings jArcPulse 3.2s with a **.6s offset between them** — that offset is the whole effect; a verified badge on jTwinkle 2.6s (jTwinkle on a UI badge, not a star); float chips 4s/4.4s at 1.3s; the orange chip BREATHES (2.8s) rather than floating.
- W3: the **only route dash on any R/W tile** — jDash 2.6s linear. R3 draws the same path without it, so do not propagate. Courier halo 2.2s is the fastest halo on the board.
Everything else on these tiles is STILL: mic discs, wordmark, the عربي language pill, bubble contents, headlines, CTAs, page dots.

Carry-ins: slide art copy comes from the tile literals; there is an AR retranslation flag on this screen — check it and report.
Because captures are rest-frame by design, your motion evidence must be per-element assertions (widget present, primitive type, duration, delay), not the PNGs.`,
  },
  {
    item: 'M2-22-23-r6-r7', label: 'R6+R7 registration+OTP',
    prompt: `YOUR ITEM: TWO checklist rows, one lane because they share a directory — M2-22 R6 Registration AND M2-23 R7 OTP verify. Files: lib/features/registration/presentation/registration_screen.dart (780 LOC) and lib/features/registration/presentation/otp_verification_screen.dart (539 LOC, mounted by R6's file).
Tiles: ${TILES}/06-r6-registration.png and ${TILES}/07-r7-otp-verify.png.
YOU OWN lib/core/router/app_router.dart THIS WAVE (no other lane may touch it) — auth routing is yours if the work genuinely needs it; if not, say so.

⛔ **NEVER build L1 Log in or L2 Sign up** (tiles 34/35). The email/password funnel was REMOVED in JEBV4-199 (Q-044 RATIFIED). Auth is phone-OTP + social only. If any code path still reaches an email/password form, report it — do not restyle it.
Carry-ins: R6 — fix the social-pill labels and the box-in-a-box field (doc-13 P1). R7 — the pass-1-added Verify pill is Pattern D chrome: DELETE it and re-home its frozen identifier onto a board-drawn element or a zero-size semantics node.
MOTION: both tiles are fully static. R7 specifically — the 13 backdrop-filter OTP digit boxes are glass but STILL: no focus pulse, no caret blink. jBlink belongs to R2's transcript caret only.
Report both rows' diffstats separately so each checklist row can be ticked on its own evidence.`,
  },
  {
    item: 'M2-24-r8', label: 'R8 transcription',
    prompt: `YOUR ITEM: M2-24 R8 Transcription review. Files: lib/features/transcription/presentation/transcription_screen.dart (285 LOC) + its widgets.
Tile: ${TILES}/08-r8-transcription-review.png.
Carry-ins: the low-confidence underline is Pattern-A (designed slot + TODO omitted-not-faked if the wire carries no confidence data — check before assuming). **REMOVE the injected waveform from the scrubber row** — the board draws none there.
MOTION: R8 is fully static, including the scrubber row. 03-MOTION-NOTES says this explicitly reinforces the carry-in: the injected waveform must be removed, and it certainly must not animate.
Note: JeebWaveform has a \`playbackBand\` profile (added in wave A for R12's playback summary). If your tile genuinely draws a playback band somewhere, use it; if it draws none, remove rather than re-point.`,
  },
]

const L10N = `You are the l10n merge lane for MIDNIGHT wave D in ${REPO}, branch feat/redesign-midnight (NEVER run git mutations). GOLDEN RULE: comments max 2 lines, only when super necessary.
YOU OWN lib/l10n/*.arb. Work:
1. Process EXACTLY these six queue files and NO others: docs/redesign-midnight/l10n-queue/M2-13-r17.md, M2-14-r18.md, M2-15-r19.md, M2-16-r20.md, M2-17-r21-e4.md, M2-18-r4.md. (Five screen lanes are running concurrently and WILL create new files in that directory — those are wave-E work, not yours. NEVER glob the directory.) Apply the keys to app_en.arb + app_ar.arb following existing conventions; AR values as queued — flag any AR string that looks machine-weak rather than inventing better copy.
2. This repo has NO \`flutter gen-l10n\` (no l10n.yaml, no generate: true) — the ARBs are pubspec assets parsed at runtime by the hand-authored lib/l10n/app_localizations.dart. Hand-add the getters into the existing numbered sections, as the last two merge lanes did.
3. Swap every call site marked "TODO(midnight): l10n-queued" in the wave-C feature dirs: lib/features/{offers,active_delivery_jeeber,earnings,chat,deep_link_targets,order_history}. **NOT lib/features/wallet — the kit-fixup lane owns it this wave.** If a queue row points at wallet or at a wave-D dir (settings, kyc, onboarding, registration, transcription), apply the KEY but leave the call site and report it.
4. If a queue file records that a feature-local l10n stopgap can now be deleted (the way otp_handover and live_tracking were closed out), verify every one of its keys landed with byte-identical values, then delete it. If any value differs, keep the stopgap and say why.
5. Delete ONLY the six queue files you processed.
STANDING RULINGS: value changes are in scope (change the value, keep the key id). For a key a row marks "replaced": after swapping, grep for remaining references — zero → delete from both ARBs; any left → KEEP and report where. Never leave a dangling reference. If a queue file names a test that pins a literal via find.text, YOU own that test file — update the finder in the same pass.
VERIFY: flutter analyze --no-pub lib/l10n lib/features/{offers,active_delivery_jeeber,earnings,chat,deep_link_targets,order_history} → 0 errors · flutter test test/l10n plus the targeted suites for those dirs → green (chat_header_contrast_test's 5 reds are pre-existing, Q-022).
RETURN: keys applied per file · keys deleted with grep evidence · call sites swapped · stopgaps closed · AR strings flagged · before/after test counts · questions.`

const KIT_FIXUP = `You are the kit-fixup lane for MIDNIGHT wave D in ${REPO}, branch feat/redesign-midnight (NEVER run git mutations). GOLDEN RULE: comments max 2 lines, only when super necessary.
YOU OWN: lib/core/widgets/jeeb/jeeb_midnight_field.dart + its test, lib/features/wallet/ + its tests, and lib/devtool/catalog/entries/batch_04_entries.dart.

1. **Add \`JeebFieldWashPlacement.endMid\`** — sanctioned in 02-STUDY-NOTES "Glow-anchor wave outcomes". R4's periwinkle wash is currently rendered by \`bottomEnd\` (0.90, 1.0) but the board declares, and a pixel fit confirms at fy **0.6503 exact**, an end-side wash at mid-height — **335px too low as shipped**. Ratified anchor: \`endMid(1.17, 0.65, 0.21, 1.78, 0.714)\` (fx, fy, alpha, radiusFactor, aspect — confirm the tuple order against the enum's constructor before using it). Board declaration: \`radial-gradient(700px 560px at 110% 65%, rgba(119,127,192,.2))\` on a 440x956 canvas. APPEND the value so existing indices hold; \`bottomEnd\` keeps its value and its callers.
2. **Adopt it on R4** — lib/features/wallet/presentation/wallet_hub_screen.dart. R4 draws TWO radials: the orange glow top-start (already adopted last wave, do not disturb it) and this periwinkle wash. A test already pins the current wash so the orange adoption could not drag it — update that pin to the new anchor rather than deleting it, and say which test.
3. **Add a 1-delivery active-deliveries catalog state** to lib/devtool/catalog/entries/batch_04_entries.dart. The existing banner state seeds **2** deliveries, which trips \`_disclosureThreshold = 2\` and collapses to a disclosure row rendering **zero cards** — so the entire active-delivery card treatment (accent-tint fill, frame, vehicle disc, action pill) has no catalog coverage at all, on either the jeeber_home or the jeeber_active_deliveries entry. Add the state; do not change the threshold.

**STANDING RULE — goldens are evidence, not gates** (5% tolerance; a 0.097% ink swap passed three goldens unchanged). Land per-element assertions and PROVE each discriminates by reverting the value and confirming red.
VERIFY: flutter analyze --no-pub lib/core lib/features/wallet lib/devtool/catalog → 0 errors · flutter test test/core/widgets/jeeb test/core/theme test/features/wallet test/devtool → green, report before/after · re-capture wallet and the new catalog state (--tags capture --update-goldens), PNGs to docs/redesign-midnight/captures/M2-18-r4/.
RETURN: exact signature added · what changed per file · before/after counts · discrimination proof · anything left.`

phase('Screens')
const results = await parallel([
  ...SCREENS.map((s) => () => agent(
    `${s.prompt}\n${COMMON}\nYour capture/report item id: ${s.item}.`,
    { label: s.label, phase: 'Screens', model: 'opus' },
  )),
  () => agent(L10N, { label: 'l10n-merge', phase: 'Screens', model: 'opus' }),
  () => agent(KIT_FIXUP, { label: 'kit:endMid+catalog', phase: 'Screens', model: 'opus' }),
])

return Object.fromEntries([
  ...SCREENS.map((s, i) => [s.item, results[i]]),
  ['l10n-merge', results[5]],
  ['kit-fixup', results[6]],
])
