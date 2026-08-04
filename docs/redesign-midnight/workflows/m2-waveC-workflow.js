export const meta = {
  name: 'midnight-m2-waveC',
  description: 'M2 wave C: R17, R18, R19, R20, R21/E4, R4 + wave-B l10n merge — seven parallel lanes',
  phases: [{ title: 'Screens', detail: '6 screens (router owned by R20) + l10n merge lane (owns arb)' }],
}

const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const TILES = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/export-rich-ui/screens'
const COMMON = `
You are implementing ONE screen item of the Jeeb MIDNIGHT redesign (dark navy design language) in ${REPO}, branch feat/redesign-midnight (verify with \`git status -sb\`; NEVER run git commit/checkout/stash/branch — leave all changes in the working tree).
GOLDEN RULE (user mandate): comments max 2 lines, only when super necessary.

STEP 0 — MANDATORY before any code:
1. Read your tile PNG(s) with the Read tool — the bottom caption band is the designer's spec note. Write down 8+ concrete observations (whatISaw): background layers/glow placement, where orange appears (BUDGETED), ink hierarchy, glass surfaces, radii, spacing, Arabic runs, empty/loading/error treatment, copy literals.
2. Read docs/redesign-midnight/03-MOTION-NOTES.md — YOUR tile's section is the motion authority. R17/R18/R19/R20/R21/R4 are ALL zero-animation tiles; E4 has exactly 4 animated elements. Add NOTHING the notes don't list (explicitly banned: R20 typing indicator, R21 row motion, R19 chart grow-in).
3. Read docs/redesign-midnight/01-TOKEN-SHEET.md + 02-STUDY-NOTES.md (ALL rulings bind you — including Wave-A/B rulings: JeebCtaButton.accent exists for tile-drawn orange CTAs, JeebEmptyState has compact variant + two-tone medallions, glass chips sanctioned where measured, JeebWaveform has a playbackBand profile) and your carry-ins in docs/redesign-2026-08/13-DESIGN-VS-IMPLEMENTATION.md.
4. Confirm your files are reachable from lib/main.dart (docs/redesign-2026-08/screen-repo-map.md wins).

CONSTRAINTS:
- Tokens/kit only; ZERO raw hex, ZERO Colors.* (transparent ok). Do NOT modify lib/core/theme or kit APIs — return the question instead.
- ALL states restyled (default/loading/empty/error); empty family = JeebEmptyState.
- Preserve frozen test identifiers by re-homing; then delete identifier-only chrome.
- Copy = tile literals. NEW l10n keys: do NOT edit lib/l10n/*.arb (a dedicated lane owns them) — write keys+EN/AR to docs/redesign-midnight/l10n-queue/<your-item>.md and use the nearest existing key with TODO(midnight): l10n-queued.
- Missing wire data → designed slot + TODO(midnight): omitted, not faked.
- RTL-safe; respect MediaQuery.disableAnimations (screen tests: pump(duration), never pumpAndSettle on looping surfaces).
- Do NOT touch lib/core/router/app_router.dart unless you own it (stated below). Do NOT touch other screens' feature dirs.
- Analyze baseline on this branch: 0 errors / 30 known infos. Your bar is 0 errors and no NEW warnings.
- CONCURRENCY: an l10n lane is running at the same time and owns lib/l10n — it regenerates app_localizations.dart mid-wave. If analyze or tests report an error inside lib/l10n, or a missing AppLocalizations getter you did not introduce, re-run that command ONCE before reporting it; only report it if it reproduces.

AFTER IMPLEMENTING — selfCritique: re-Read the tile, list 4+ px/hex-specific deltas, fix what you can, report the rest.

VERIFY: flutter analyze --no-pub <your dirs> → 0 errors · targeted tests · git diff --stat (primary file non-zero) · re-capture your screens: flutter test test/tools/catalog_capture_test.dart --update-goldens --plain-name "<filter>" then copy PNGs to docs/redesign-midnight/captures/<your-item>/.

RETURN raw data: whatISaw · files+diffstat · changes per file · selfCritique deltas · test results · l10n queued · TODOs · open questions.`

const SCREENS = [
  {
    item: 'M2-13-r17', label: 'R17 offer composer',
    prompt: `YOUR ITEM: M2-13 R17 Offer composer. Files: lib/features/offers/presentation/offer_submission_screen.dart (+ its widgets). Tile: ${TILES}/17-r17-offer-composer.png.
Carry-ins: the 3 ETA pills + their default selection; l10n validation strings (queue new keys).
**PARKED REGRESSION YOU MUST FIX — not re-park:** the bigger Midnight type ramp broke \`test/features/offers/offer_composer_rtl_smoke_test.dart\` — test "mirrors and survives 200% text with no overflow" (AR locale, TextScaler.linear(2.0), view 1080x2400). Make it GREEN by fixing the LAYOUT (wrap/scroll/flex the offending row), never by loosening the assertion or shrinking the ramp. Report the exact widget that was overflowing and by how many px. Field: content.`,
  },
  {
    item: 'M2-14-r18', label: 'R18 active delivery',
    prompt: `YOUR ITEM: M2-14 R18 Active delivery — Jeeber. Files: lib/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart (+ its widgets). Tile: ${TILES}/18-r18-active-delivery-jeeber.png.
Carry-ins + TWO OPEN ESCALATIONS you must resolve by reporting, not by inventing:
(a) The board draws N action pills; the app has an \`onEnterGoodsCost\` third "Costs" pill that was never wired (owner Q7 pending). RULING: build exactly what the tile draws; if the tile draws only 2 pills, render 2 and leave the goods-cost entry point out with a TODO(midnight): omitted, not faked + report it. Do NOT wire new business logic.
(b) The 4-segment stepper: state in your report how many segments the tile draws and how many the app has, and match the tile visually WITHOUT changing the underlying state machine. **JeebStepper's bar form now takes a fill-through / done-ink parameter** (added in the wave-B fixup because R3 fills passed segments ORANGE and R18 fills them PERIWINKLE). Read lib/core/widgets/jeeb/jeeb_stepper.dart for the exact signature and drive it with R18's periwinkle — do NOT hand-paint a local bar row, and do NOT edit the kit.
MOTION: R18 is fully static — the segmented stepper does NOT animate its active segment. Field: content.`,
  },
  {
    item: 'M2-15-r19', label: 'R19 earnings',
    prompt: `YOUR ITEM: M2-15 R19 Earnings. Files: lib/features/earnings/presentation/earnings_dashboard_screen.dart (+ its widgets). Tile: ${TILES}/19-r19-earnings.png.
Carry-ins: hero stat #3 (the tile draws three hero stats); row facts are Pattern-A (designed slot + TODO omitted-not-faked). Money emphasis = price 22/w800 + statHero 40/w800 (Inter ExtraBold is bundled — use it).
**PARKED REGRESSION YOU MUST FIX — not re-park:** the bigger ramp broke \`test/features/earnings/earnings_dashboard_layout_test.dart\` — the "funded body fits a 390pt phone — ar @ <scale>" case (Locale('ar'), Size(390,844)). Fix the LAYOUT, never the assertion or the ramp. Report the offending widget + overflow px.
FIELD: use the token sheet's **success wash variant** (§8: rgba(59,178,115,.16) at (0.88,-0.06)) if your tile read shows a green/money glow; otherwise content. State which and why. MOTION: R19 is fully static — the bar chart does NOT grow in.`,
  },
  {
    item: 'M2-16-r20', label: 'R20 order chat',
    prompt: `YOUR ITEM: M2-16 R20 Order chat. Files: lib/features/deep_link_targets/chat_detail_screen.dart (the /chat/:id container, 1982 LOC) AND lib/features/chat/presentation/chat_screen.dart (1196 LOC). Tile: ${TILES}/20-r20-order-chat.png.
**ZERO-DIFF TRAP — this is where pass-1 silently failed:** the container (chat_detail_screen.dart) MUST show a non-zero diff. Restyling only chat_screen.dart is a REJECTED result. Report \`git diff --stat\` for BOTH files explicitly.
YOU OWN lib/core/router/app_router.dart THIS WAVE (no other lane may touch it) — use it only if the chat route genuinely needs it; if you do not need it, say so.
**ASSIGNED CARRY-IN from M2-11 (rating), a genuine one-liner:** app_router.dart now exports `mutualRatingLocation(deliveryId, {required isClient, String? counterpartName})`. `chat_detail_screen.dart:70` has a local `_mutualRateRoute(...)` called from `_navigateToRatingOnce()` (~:1240) which currently passes NO name — and this is the one site of three where the name IS in scope (`summary.jeeberName` / `counterpartName`, per dio_order_chat_summary_repository.dart:51). Route it through `mutualRatingLocation` and pass the real name. Never fabricate a name: if it is null/empty at that point, pass null and let the helper drop the param.
Carry-ins: the green success banner becomes a quiet timeline chip (Pattern D — it is chrome, demote it); B-04 "no mic in the composer" ruling STANDS (do not add a mic). Outgoing bubbles use the wave-A kit tint (bubbleOutFill 24% / bubbleOutBorder 45%, white body) — consume the kit, do not re-derive.
MOTION: R20 is fully static. **Do NOT add a typing indicator** — the board draws none and it is an explicitly banned novelty (02-STUDY-NOTES motion ruling 4).
**PARKED REGRESSION YOU MUST FIX — not re-park:** the bigger ramp broke \`test/features/chat/chat_header_overflow_test.dart\` — the "320x480 at a 2.0 text scale with the keyboard open" case. Fix the LAYOUT (the header chrome is meant to degrade by scrolling, per the neighbouring tests), never the assertion or the ramp. Report the offending widget + overflow px. Field: content.`,
  },
  {
    item: 'M2-17-r21-e4', label: 'R21+E4 order history',
    prompt: `YOUR ITEM: M2-17 R21+E4 Order history + no-orders empty. Files: lib/features/order_history/presentation/order_history_screen.dart (+ its widgets/rows). Tiles: ${TILES}/21-r21-order-history.png AND ${TILES}/30-e4-empty-no-orders-yet.png.
Carry-ins: row facts are Pattern-A (designed slot + TODO omitted-not-faked). E4 empty = JeebEmptyState — E4 is one of the few ANIMATED tiles: center glow jBreathe 3.2s + the three-sparkle ladder (2.4/2.8/3.0s at 0/.7/1.3s delay); its 250px orbit ring does NOT pulse. Reuse the E1 sparkle recipe (03-MOTION-NOTES says it is identical).
OPEN QUESTION (owner Q6, do NOT resolve yourself): expired-row dimming at 0.65 opacity vs AA. Ship the tile's dimming, add a TODO(midnight) naming Q6, and report it. R21 rows themselves are fully static. Field: content.`,
  },
  {
    item: 'M2-18-r4', label: 'R4 wallet',
    prompt: `YOUR ITEM: M2-18 R4 Wallet. Files: lib/features/wallet/presentation/wallet_hub_screen.dart (+ its widgets). Tile: ${TILES}/04-r4-wallet.png.
Scope guard: the wallet SUBTREE (wallet_activity_list, transaction_detail, wallet_charge_info, customer_wallet_stub) is M3 — restyle ONLY the hub screen and any widget it owns directly. If a shared widget is used by both, restyle it and say so.
Carry-ins: doc-13 P2 tints → the new semantic tokens (success/danger money ink, amber). Money emphasis = price 22/w800.
MOTION: R4 is fully static — including the field orbit ring and the radial glow behind the balance (use the field's animateDecor:false knob). Field: state which variant your tile read supports and why.`,
  },
]

const L10N = `You are the l10n merge lane for MIDNIGHT wave C in ${REPO}, branch feat/redesign-midnight (NEVER run git mutations). GOLDEN RULE: comments max 2 lines, only when super necessary.
YOU OWN lib/l10n/*.arb this wave. Work:
1. Process EXACTLY these six queue files and NO others: docs/redesign-midnight/l10n-queue/M2-07-r10-e2.md, M2-08-r3.md, M2-09-r13.md, M2-10-r14.md, M2-11-r15.md, M2-12-r16-e3.md. (Six screen lanes are running concurrently and WILL create new files in docs/redesign-midnight/l10n-queue/ — those are wave-D work, not yours. Never glob the directory.) NOTE: M2-08's file is mostly a MAP of existing resolvers rather than new copy, and it carries forward 18 unlanded `LiveTrackingL10n` keys — landing those lets you delete the feature-local `live_tracking_l10n.dart` stopgap the way wave B deleted `otp_handover_l10n.dart`. Do that only if all 18 land with byte-identical values; otherwise leave the stopgap and say why. Apply the queued keys to app_en.arb + app_ar.arb following existing key conventions (metadata blocks if the file uses them; AR values as queued — flag any AR string that looks machine-weak rather than inventing better copy).
2. Run flutter gen-l10n (or the repo's codegen path — check how app_localizations.dart is produced) so the generated files match.
3. Swap every call site marked "TODO(midnight): l10n-queued" in the wave-B feature dirs (lib/features/client_offers lib/features/live_tracking lib/features/otp_handover lib/features/delivery_receipt lib/features/rating lib/features/jeeber_home lib/features/jeeber_request_feed) to its real new key; remove those TODOs. Do NOT touch the wave-C feature dirs (offers, active_delivery_jeeber, earnings, chat, deep_link_targets, order_history, wallet) — lanes are working there concurrently; if a queue row points there, apply the key but leave the call site and report it.
4. Delete ONLY the queue files you processed.
STANDING RULINGS: value changes are in scope (change the value, keep the key id). For any key a queue row marks "replaced": after swapping call sites, grep for remaining references — zero → delete the key from both ARBs; any left → KEEP it and report where. Never leave a dangling reference. If a queue file names a test that pins a literal via find.text, YOU own that test file — update the finder in the same pass and report it.
VERIFY: flutter analyze --no-pub lib/l10n lib/features/client_offers lib/features/live_tracking lib/features/otp_handover lib/features/delivery_receipt lib/features/rating lib/features/jeeber_home lib/features/jeeber_request_feed → 0 errors · the targeted suites for those dirs → green.
RETURN: keys applied per file · keys deleted (with grep evidence) · call sites swapped · test finders updated · AR strings flagged for review · test results · questions.`

const SHELL_HARNESS = `You are the shell test-harness lane for MIDNIGHT wave C in ${REPO}, branch feat/redesign-midnight (NEVER run git commit/checkout/stash/branch). GOLDEN RULE: comments max 2 lines, only when super necessary.
YOU OWN EXACTLY these 6 test files and NOTHING else — no lib/, no other test file:
  test/shell_role_tabs_test.dart (5 failing)
  test/shell_role_toggle_mounted_test.dart (4)
  test/features/shell/shell_dual_role_landing_test.dart (3)
  test/app_shell_test.dart (3)
  test/features/shell/route_visibility_wire_test.dart (2)
  test/core/deep_link/deep_link_resolution_router_test.dart (1)

PROBLEM (already diagnosed AND already fixed once — copy the landed fix, do not re-derive): 18 tests across these files fail with \`pumpAndSettle timed out\`. Cause: the tree mounts ShellScreen (home tab → JeebEmptyState, whose E1 illustration loops ∞ BY DESIGN per 03-MOTION-NOTES §E1) or the real AppRouter landing on it. pumpAndSettle cannot settle against an infinite animation. This is NOT a product bug.

THE FIX IS ALREADY IN THE REPO — read commit 73ed7471 (\`git show 73ed7471\`) and copy its pattern exactly. It is TWO paired edits, and applying only the first will leave you with a different, confusing failure:
  EDIT A — reduce-motion wrapper on the harness's MaterialApp:
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    Use \`MediaQuery.of(context).copyWith(...)\`, NOT a bare \`MediaQueryData()\` — a bare one zeroes the view metrics and breaks layout. Note 5 of your files use \`MaterialApp(home: ShellScreen())\` rather than \`MaterialApp.router\`; the same \`builder:\` works unchanged there because MaterialApp.builder sits above the Navigator either way.
  EDIT B — once pumpAndSettle stops hanging it stops MASKING a pending timer: \`InMemoryClientHomeRepository.loadSnapshot\` resolves behind a 150ms fake latency that schedules NO frame, so pumpAndSettle never advances to it and the test dies on "A Timer is still pending even after the widget tree was disposed." Drain it explicitly before the settle, only in tests that actually mount Home:
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

PRESERVE EVERY ASSERTION. Do not delete, skip, or weaken a test to make the suite green. If a test cannot be fixed this way, leave it failing and report exactly why.
VERIFY: run each of the 6 files and report exact pass/fail BEFORE and AFTER. Then re-run once for stability. flutter analyze --no-pub on your 6 files → 0 errors.
RETURN: per-file before/after counts · which files needed Edit B and which did not · anything left failing · questions.`

phase('Screens')
const results = await parallel([
  ...SCREENS.map((s) => () => agent(
    `${s.prompt}\n${COMMON}\nYour capture/report item id: ${s.item}.`,
    { label: s.label, phase: 'Screens', model: 'opus' },
  )),
  () => agent(L10N, { label: 'l10n-merge', phase: 'Screens', model: 'opus' }),
  () => agent(SHELL_HARNESS, { label: 'fix:shell-harness', phase: 'Screens', model: 'opus' }),
])

return Object.fromEntries([
  ...SCREENS.map((s, i) => [s.item, results[i]]),
  ['l10n-merge', results[6]],
  ['shell-harness', results[7]],
])
