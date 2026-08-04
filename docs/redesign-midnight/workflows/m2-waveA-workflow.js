export const meta = {
  name: 'midnight-m2-waveA',
  description: 'M2 wave A: shell + R1/E1 + R2 + R9 + R11 + R12 — six parallel screen implementers',
  phases: [{ title: 'Screens', detail: '6 disjoint feature dirs; router owned by R11, l10n by R12' }],
}

const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const TILES = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/export-rich-ui/screens'
const COMMON = `
You are implementing ONE screen item of the Jeeb MIDNIGHT redesign (dark navy design language) in ${REPO}, branch feat/redesign-midnight (verify with \`git status -sb\`; NEVER run git commit/checkout/stash/branch — leave all changes in the working tree).
GOLDEN RULE (user mandate): comments max 2 lines, only when super necessary.

STEP 0 — MANDATORY before any code:
1. Read your tile PNG(s) listed below with the Read tool — the bottom caption band is the designer's spec note. Write down 8+ concrete observations (whatISaw): background layers/glow placement, where orange appears (BUDGETED: mic/active-tab/live accents/tile-drawn CTAs only), ink hierarchy, glass surfaces, radii, spacing, Arabic runs, empty/loading/error treatment, copy literals.
2. Read docs/redesign-midnight/03-MOTION-NOTES.md — YOUR tile's section is the motion authority (many tiles are fully STATIC; add NOTHING the notes don't list).
3. Read docs/redesign-midnight/01-TOKEN-SHEET.md + 02-STUDY-NOTES.md (rulings bind you) and your screen's carry-ins in docs/redesign-2026-08/13-DESIGN-VS-IMPLEMENTATION.md.
4. Confirm your files are reachable from lib/main.dart (docs/redesign-2026-08/screen-repo-map.md wins over any other map).

CONSTRAINTS:
- Tokens/kit only: theme roles, context.jeebText, JeebRadii, the frozen kit (JeebMidnightField, JeebGlassCard/Capsule, JeebEmptyState, JeebPillNav, restyled widgets). ZERO raw hex, ZERO Colors.* (transparent ok), zero light-theme remnants. Do NOT modify lib/core/theme or kit public APIs — return the question instead.
- Every state (default/loading/empty/error) restyled; empty family = JeebEmptyState.
- Preserve frozen test identifiers by re-homing onto board-drawn elements or zero-size semantics nodes; then delete chrome that existed only to host them.
- Copy = tile literals (sentence case). NEW l10n keys: do NOT edit lib/l10n/*.arb (another agent owns them this wave) unless you are told you own l10n — instead write needed keys+EN/AR values to docs/redesign-midnight/l10n-queue/<your-item>.md and reference the nearest existing key with a TODO(midnight): l10n-queued comment.
- Missing wire data → render the designed slot with TODO(midnight): omitted, not faked.
- RTL-safe (EdgeInsetsDirectional/start-end). Respect MediaQuery.disableAnimations.
- Do NOT touch lib/core/router/app_router.dart unless you own it this wave (stated below). Do NOT touch other screens' feature dirs.

AFTER IMPLEMENTING — selfCritique: re-Read the tile, list 4+ px/hex-specific deltas between your result and the tile, fix what you can, report the rest honestly.

VERIFY: flutter analyze --no-pub <your dirs> → 0 errors · run your targeted tests · git diff --stat (primary file MUST be non-zero) · re-capture YOUR screen's catalog states: flutter test test/tools/catalog_capture_test.dart --update-goldens --plain-name "<filter matching your entries>" then copy your screens' PNGs from docs/redesign-2026-08/actual/ to docs/redesign-midnight/captures/<your-item>/.

RETURN raw data: whatISaw · files+diffstat · what changed per file · selfCritique deltas · test results · l10n keys queued · TODOs added · open questions.`

const SCREENS = [
  {
    item: 'M2-01-shell', label: 'shell+nav',
    prompt: `YOUR ITEM: M2-01 Shell / floating nav. Files: lib/features/shell/shell_screen.dart (+ its tab bar internals; shell frames all 5 tabs). Tile: ${TILES}/01-r1-client-home.png (the nav is drawn at its bottom; study ONLY the nav + framing here, R1's content is another agent's item — do NOT edit lib/features/home_client).
Work: replace the current tab bar with the kit JeebPillNav (frozen API); tabs float over the tab content on the Midnight field (each tab screen owns its own field — the shell must not double-paint; verify no white flash between tabs). Tab ROUTES and semantics identifiers are FROZEN — map the 5 existing tabs positionally to the tile's visual order; if an existing label string conflicts with the tile literal (Requests · Delivery · Dashboard · Earnings · Profile), keep the existing l10n key wired, queue the new literal per the l10n rule, and report the mismatch. Existing failing test shell_tab_bar_redesign_test asserts old inks — re-cut it to the JeebPillNav contract. Also verify SystemUiOverlayStyle stays light over all tabs.`,
  },
  {
    item: 'M2-02-r1-e1', label: 'R1+E1 home',
    prompt: `YOUR ITEM: M2-02 R1+E1 Client home + empty. Files: lib/features/home_client/presentation/client_home_screen.dart, client_home_empty_view.dart, pending_requests_tab.dart, replies_card.dart. Tiles: ${TILES}/01-r1-client-home.png AND ${TILES}/27-e1-empty-no-requests.png. Do NOT edit lib/features/shell (another agent owns the nav).
Carry-ins: doc-13 P0-6 (hold-to-talk promise — the capsule says "Hold to talk / or tap to type" and must actually offer both), P0-7 (single "View offers" pill). Waveform/reach counts are Pattern-A: designed slot + TODO(midnight): omitted, not faked.
Field: JeebMidnightField hero. MOTION: R1 is FULLY STATIC on the board (03-MOTION-NOTES) — the field's animated decor must not run: add \`animateDecor\` (bool, default true) to JeebMidnightField — this ONE kit API addition is Fable-sanctioned for you alone; keep it minimal (skips the animated painter loop, static layers unchanged) and update the field test. E1 empty state = kit JeebEmptyState default composition; its motion per the E1 notes section ONLY. Segmented Pending/Replies per study-notes ruling 3 (active=white fill+navy ink).`,
  },
  {
    item: 'M2-03-r2', label: 'R2 voice',
    prompt: `YOUR ITEM: M2-03 R2 Voice recording. Files: lib/features/voice_request/presentation/voice_recording_screen.dart (+ its widgets/cubit presentation surface as needed). Tile: ${TILES}/02-r2-voice-recording.png.
Carry-ins: doc-13 P0-5 — ship the LIVE TRANSCRIPT band: the designed awaiting-state card + the jBlink caret (1.1s step-end). Motion per 03-MOTION-NOTES R2 section (4 animated elements: consume lib/core/motion — jWave is CONTAINER-level per ruling, jHalo mic, exact durations from the notes). Mic disc + glow = kit JeebMicHero (recording state → micActive glow). Field: hero or content per your tile read — state which and why. The existing voice_recording_redesign_test failure is yours to re-cut. Cursor/caret ink: check the tile — if the caret is orange it is tile-sanctioned; report the measured color.`,
  },
  {
    item: 'M2-04-r9', label: 'R9 request type',
    prompt: `YOUR ITEM: M2-04 R9 Request type + tier catalog section. Files: lib/features/request_type/presentation/request_type_screen.dart. Tile: ${TILES}/09-r9-request-type.png.
Carry-ins: doc-13 P0-3/P0-4 — compact radio rows via JeebTierRow.compact, "Most picked" badge on Standard, Standard PRE-SELECTED. The kit now has the accent selected state (JeebCardState.accentSelected: orange 20% fill + 2px accent border + glow) — the selected row uses it; verify against the tile. Tier hues/lexicon UNCHANGED (owner Q4 pending). Field: content. Motion: R9 is STATIC per notes. tier_selection preview tests that assert old values: re-cut only the ones your diff breaks.`,
  },
  {
    item: 'M2-05-r11', label: 'R11 location',
    prompt: `YOUR ITEM: M2-05 R11 Location picker — HIGHEST-RISK item. Files: lib/features/location/presentation/client_location_screen.dart + capture_location_screen.dart (+ widgets/google_map_capture_view.dart already dark-styled). Tile: ${TILES}/11-r11-location-picker.png.
YOU OWN lib/core/router/app_router.dart THIS WAVE (no other agent may touch it). Ratified deletions (ORPHAN ruling, study notes): DELETE the legacy /location route (app_router.dart:966-971 area) + lib/features/location/presentation/screens/location_picker_screen.dart (the routed placeholder) + lib/features/location/presentation/location_picker_screen.dart (the 626-LOC devtool-only twin) + its catalog entry import in lib/devtool/catalog/entries/batch_06_entries.dart + the placeholder fixtures + the 'location-picker' backFallbacks entry. Update no_raw_semantic_colors_test.dart pinned paths if they name deleted files.
Carry-ins: P0-1/P0-2 — wire the real map builder (GoogleMapPickerLauncher path) so the screen shows the Midnight-styled map, not a stub. Field: map variant over the GoogleMap; dark style already applied via JeebMapStyle. Motion: R11 per notes (2 animated elements — check which). Two-leg vs one-coordinate flow shape is owner Q2 — do NOT redraw the flow; restyle what exists.`,
  },
  {
    item: 'M2-06-r12', label: 'R12 summary',
    prompt: `YOUR ITEM: M2-06 R12 Request summary. Files: lib/features/request_summary/presentation/request_summary_screen.dart. Tile: ${TILES}/12-r12-request-summary.png.
YOU OWN lib/l10n/*.arb THIS WAVE: fix doc-13 P0-8(c) — '{count} photo(s) attached' becomes a proper ICU plural in app_en.arb (+ the AR counterpart; follow existing plural key patterns). Also apply P0-8(b): GoRouter.maybeOf(context)?.canPop() ?? false hardening in the request ticket widget (lib/features/request_summary/... request_ticket.dart:95 area). The capture harness for this screen was already fixed (M0-9) — your captures must render all 3 states.
Field: content. Motion: R12 is STATIC per notes. Money formatting: keep the app's MoneyFormat as-is (owner Q1 pending) — do not reformat amounts. The failing request_summary_screen_test cluster from the theme re-cut is yours to re-cut to Midnight values.`,
  },
]

phase('Screens')
const results = await parallel(SCREENS.map((s) => () => agent(
  `${s.prompt}\n${COMMON}\nYour capture/report item id: ${s.item}.`,
  { label: s.label, phase: 'Screens', model: 'opus' },
)))

return Object.fromEntries(SCREENS.map((s, i) => [s.item, results[i]]))
