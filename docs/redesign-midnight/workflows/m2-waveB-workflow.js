export const meta = {
  name: 'midnight-m2-waveB',
  description: 'M2 wave B: R10/E2, R3, R13, R14, R15, R16/E3 + wave-A l10n merge — seven parallel lanes',
  phases: [{ title: 'Screens', detail: '6 screens (router owned by R15) + l10n merge lane (owns arb)' }],
}

const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const TILES = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/export-rich-ui/screens'
const COMMON = `
You are implementing ONE screen item of the Jeeb MIDNIGHT redesign (dark navy design language) in ${REPO}, branch feat/redesign-midnight (verify with \`git status -sb\`; NEVER run git commit/checkout/stash/branch — leave all changes in the working tree).
GOLDEN RULE (user mandate): comments max 2 lines, only when super necessary.

STEP 0 — MANDATORY before any code:
1. Read your tile PNG(s) with the Read tool — the bottom caption band is the designer's spec note. Write down 8+ concrete observations (whatISaw): background layers/glow placement, where orange appears (BUDGETED), ink hierarchy, glass surfaces, radii, spacing, Arabic runs, empty/loading/error treatment, copy literals.
2. Read docs/redesign-midnight/03-MOTION-NOTES.md — YOUR tile's section is the motion authority (most of these tiles are STATIC; add NOTHING the notes don't list).
3. Read docs/redesign-midnight/01-TOKEN-SHEET.md + 02-STUDY-NOTES.md (ALL rulings bind you — including Wave-A rulings: JeebCtaButton.accent exists now for tile-drawn orange CTAs, JeebEmptyState has compact variant + two-tone medallions, glass chips sanctioned where measured) and your carry-ins in docs/redesign-2026-08/13-DESIGN-VS-IMPLEMENTATION.md.
4. Confirm your files are reachable from lib/main.dart (docs/redesign-2026-08/screen-repo-map.md wins).

CONSTRAINTS:
- Tokens/kit only; ZERO raw hex, ZERO Colors.* (transparent ok). Do NOT modify lib/core/theme or kit APIs — return the question instead.
- ALL states restyled (default/loading/empty/error); empty family = JeebEmptyState.
- Preserve frozen test identifiers by re-homing; then delete identifier-only chrome.
- Copy = tile literals. NEW l10n keys: do NOT edit lib/l10n/*.arb (a dedicated lane owns them) — write keys+EN/AR to docs/redesign-midnight/l10n-queue/<your-item>.md and use the nearest existing key with TODO(midnight): l10n-queued.
- Missing wire data → designed slot + TODO(midnight): omitted, not faked.
- RTL-safe; respect MediaQuery.disableAnimations (screen tests: pump(duration), never pumpAndSettle on looping surfaces).
- Do NOT touch lib/core/router/app_router.dart unless you own it (stated below). Do NOT touch other screens' feature dirs.
- Baseline note: if your lane contains one of the named baseline-red tests (client_offers_screen_test, mutual_rating_tag_chips_l10n_test, jeeber_feed_card_test) and your change alters its failure MODE (or fixes it), say so explicitly.

AFTER IMPLEMENTING — selfCritique: re-Read the tile, list 4+ px/hex-specific deltas, fix what you can, report the rest.

VERIFY: flutter analyze --no-pub <your dirs> → 0 errors · targeted tests · git diff --stat (primary file non-zero) · re-capture your screens: flutter test test/tools/catalog_capture_test.dart --update-goldens --plain-name "<filter>" then copy PNGs to docs/redesign-midnight/captures/<your-item>/.

RETURN raw data: whatISaw · files+diffstat · changes per file · selfCritique deltas · test results · l10n queued · TODOs · open questions.`

const SCREENS = [
  {
    item: 'M2-07-r10-e2', label: 'R10+E2 offers',
    prompt: `YOUR ITEM: M2-07 R10+E2 Offers + waiting-for-offers empty. Files: lib/features/client_offers/presentation/client_offers_screen.dart + its waiting/empty surface (verify the exact waiting-state widget in your STUDY — the §3 map says "verify in STUDY"). Tiles: ${TILES}/10-r10-offers.png AND ${TILES}/28-e2-empty-waiting-for-offers.png.
Carry-ins: doc-13 P1 offer-row layout fixes; distance is Pattern-A (designed slot + TODO omitted-not-faked). E2 waiting state = JeebEmptyState (variant per tile). Accept CTA: use JeebCtaButton.accent ONLY if the tile draws it orange.`,
  },
  {
    item: 'M2-08-r3', label: 'R3 tracking',
    prompt: `YOUR ITEM: M2-08 R3 Live tracking. Files: lib/features/live_tracking/presentation/live_tracking_screen.dart (+ widgets/tracking_google_map.dart is already dark-styled — do not re-style the map JSON). Tile: ${TILES}/03-r3-live-tracking.png.
MOTION: R3 is FULLY STATIC on the board (03-MOTION-NOTES) — the route does NOT march; draw the dotted route + courier marker static. Field: map variant. Carry-ins: header meta P1; courier card facts are Pattern-A TODOs. The live position stream/SSE plumbing is NOT yours to change — presentation only.`,
  },
  {
    item: 'M2-09-r13', label: 'R13 handover',
    prompt: `YOUR ITEM: M2-09 R13 OTP handover. Files: lib/features/otp_handover/presentation/otp_handover_screen.dart. Tile: ${TILES}/13-r13-otp-handover.png.
Carry-ins: DEMOTE the pass-1-added rating CTA (Pattern D — the board draws no post-handover forward path; owner Q5 pending, so keep a demoted text action only); arrival banner fixture. OTP display = kit JeebCodeCells (statDisplay 44/w800). Field: content unless the tile says otherwise.`,
  },
  {
    item: 'M2-10-r14', label: 'R14 receipt',
    prompt: `YOUR ITEM: M2-10 R14 Receipt confirm. Files: lib/features/delivery_receipt/presentation/delivery_receipt_screen.dart. Tile: ${TILES}/14-r14-receipt-confirm.png.
Carry-ins: money emphasis — w800 + the ramp's size step (price 22/w800; Inter ExtraBold is bundled). Money FORMATTING stays MoneyFormat as-is (owner Q1 pending). JeebMoneyBreakdown is restyled in the kit — consume it. Field: content.`,
  },
  {
    item: 'M2-11-r15', label: 'R15 rating',
    prompt: `YOUR ITEM: M2-11 R15 Mutual rating. Files: lib/features/rating/presentation/mutual_rating_screen.dart. Tile: ${TILES}/15-r15-mutual-rating.png.
YOU OWN lib/core/router/app_router.dart THIS WAVE (no other lane may touch it): carry-in P1 — counterpart-name plumbing through the 3 route builders that mount this screen (pass the real counterpart display name instead of the placeholder). Star fill P2 → kit amber token. MOTION RULING: R15's stars do NOT twinkle (board-absent; banned novelty). mutual_rating_tag_chips_l10n_test is a named baseline red — report its mode. Field: content.`,
  },
  {
    item: 'M2-12-r16-e3', label: 'R16+E3 jeeber home',
    prompt: `YOUR ITEM: M2-12 R16+E3 Jeeber home + no-requests-nearby empty. Files: lib/features/jeeber_home/presentation/jeeber_home_screen.dart, jeeber_feed_tab_view.dart, widgets/availability_card.dart, widgets/jeeber_feed_card.dart. Tiles: ${TILES}/16-r16-jeeber-home.png AND ${TILES}/29-e3-empty-no-requests-nearby.png.
Carry-ins: doc-13 P1 cluster — availability strip, rating pill, the "Make of…" text squeeze. "Broadcasting"/online dot = the live accent (jBreathe ONLY if the E3/R16 motion notes list it — check). E3 empty = JeebEmptyState. jeeber_feed_card_test is a named baseline red — report its mode. Field: hero or content per your tile read (state which).`,
  },
]

const L10N = `You are the l10n merge lane for MIDNIGHT wave B in ${REPO}, branch feat/redesign-midnight (NEVER run git mutations). GOLDEN RULE: comments max 2 lines, only when super necessary.
YOU OWN lib/l10n/*.arb this wave. Work:
1. Read every file in docs/redesign-midnight/l10n-queue/ (wave-A queues: M2-02, M2-03, M2-04, M2-05). Apply the queued keys to app_en.arb + app_ar.arb following existing key conventions (metadata blocks if the file uses them; AR values as queued — flag any AR string that looks machine-weak rather than inventing better copy).
2. Run flutter gen-l10n (or the repo's codegen path — check how app_localizations.dart is produced) so the generated files match.
3. Swap every call site marked "TODO(midnight): l10n-queued" in lib/features/{home_client,voice_request,request_type,location} to its real new key; remove those TODOs. Do NOT touch other feature dirs (6 screen lanes are working there concurrently) — if a queue row points elsewhere, apply the key but leave the call site and report it.
4. Delete the processed queue files.
VERIFY: flutter analyze --no-pub lib/l10n lib/features/home_client lib/features/voice_request lib/features/request_type lib/features/location → 0 errors · flutter test test/l10n test/features/home_client test/features/request_type test/features/location test/voice_recording_screen_test.dart → green.
RETURN: keys applied per file · call sites swapped · AR strings flagged for review · test results · questions.`

phase('Screens')
const results = await parallel([
  ...SCREENS.map((s) => () => agent(
    `${s.prompt}\n${COMMON}\nYour capture/report item id: ${s.item}.`,
    { label: s.label, phase: 'Screens', model: 'opus' },
  )),
  () => agent(L10N, { label: 'l10n-merge', phase: 'Screens', model: 'opus' }),
])

return Object.fromEntries([...SCREENS.map((s, i) => [s.item, results[i]]), ['l10n-merge', results[6]]])
