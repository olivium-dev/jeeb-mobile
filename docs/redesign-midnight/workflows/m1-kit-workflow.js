export const meta = {
  name: 'midnight-m1-kit',
  description: 'M1: restyle 31 kit widgets in 7 harness-disjoint groups + 3 new-widget builders, then barrier verify',
  phases: [
    { title: 'Restyle', detail: '7 widget groups + 3 builders, disjoint files' },
    { title: 'Verify', detail: 'full kit suite + analyze + hex/Colors greps' },
  ],
}

const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const COMMON = `
Work in ${REPO}, branch feat/redesign-midnight (verify with \`git status -sb\`; NEVER run git commit/checkout/stash/branch — leave everything in the working tree).
GOLDEN RULE (user mandate): comments max 2 lines, only when super necessary.
READ FIRST: docs/redesign-midnight/01-TOKEN-SHEET.md (all values) · docs/redesign-midnight/02-STUDY-NOTES.md (kit + theme rulings, incl. the RATIFIED shadow migration map) · docs/redesign-2026-08/13-DESIGN-VS-IMPLEMENTATION.md Pattern E (kit metric fixes) · lib/core/theme/jeeb_midnight_palette.dart, jeeb_radii.dart, app_theme.dart (consume, never edit).
RESTYLE CONTRACT for every widget you own:
- Colors ONLY via theme roles / context.jeebRoles / JeebSemanticColors / JeebMidnight palette import; text via context.jeebText; radii via JeebRadii. ZERO new raw hex, ZERO Colors.* (Colors.transparent allowed).
- Glass per sheet §4 (rest card: glassFill + 1px glassBorder, NO blur). Shadows: apply the ratified migration map — legacy JeebShadows entries your widgets use get re-pointed (card/raised/sheet/heroNavy/bubbleOut → none; fab/ctaNavy/accentBanner → ctaOrange; floatPill → floatNav/overlay; stepGlow → glowRest/micActive; focusRing → glassBorderStrong border).
- Orange budget (master plan §2.2): orange only for mic/active-tab/live accents/tile-drawn CTAs; default periwinkle/glass/navy. The 19 pre-existing kit test failures include stepper tests where done-nodes now read orange from colorScheme.primary — re-point such reads to the correct Midnight role instead of primary.
- Public API FROZEN: no signature changes, no renames. A needed API change → STOP and return the question. Preserve every Semantics identifier.
- Update YOUR widgets' test files (and ONLY your own harness) to assert Midnight values — expected values come from the token sheet, not from reading the implementation back.
VERIFY (scoped ONLY — other agents run concurrently): flutter analyze --no-pub <your lib files> <your test files> → 0 errors; flutter test <each of your test files> → green. If a shared file outside your ownership breaks you, note it and continue — do not edit it.
RETURN raw data: per widget — what changed (tokens/metrics), Pattern E fixes applied, test results, questions.`

const GROUPS = [
  { key: 'avatar', harness: 'jeeb_avatar_test_harness.dart', widgets: ['jeeb_avatar', 'jeeb_avatar_stack', 'jeeb_profile_header', 'jeeb_mic_hero', 'jeeb_waveform'], note: 'mic_hero: orange disc + glow IS tile-sanctioned (R1); waveform bars orangeSoft per R1/E1.' },
  { key: 'card', harness: 'jeeb_card_test_harness.dart', widgets: ['jeeb_info_note', 'jeeb_list_row', 'jeeb_money_breakdown', 'jeeb_navy_surface_card', 'jeeb_outlined_card', 'jeeb_surface_tone'], note: 'Pattern E JeebListRow padding fix is yours. money_breakdown: w800 money emphasis (Inter ExtraBold is bundled now).' },
  { key: 'chat', harness: 'jeeb_chat_test_harness.dart', widgets: ['jeeb_chat_bubble', 'jeeb_chat_composer', 'jeeb_quick_reply_row', 'jeeb_system_chip'], note: 'readTick cyan #20F0FF stays (semantic token). Composer field: frosted glass, no box-in-a-box.' },
  { key: 'code', harness: 'jeeb_code_test_harness.dart', widgets: ['jeeb_code_cells', 'jeeb_numeric_keypad', 'jeeb_top_bar', 'jeeb_select_chip'], note: 'code_cells: statDisplay is now 44/w800. top_bar: transparent over the Midnight field, white ink, no elevation.' },
  { key: 'cta', harness: 'jeeb_cta_test_harness.dart', widgets: ['jeeb_cta_button', 'jeeb_cta_footer', 'jeeb_stepper'], note: 'cta_button: accent (orange) variant only where tiles draw it; default variant periwinkle fill navy ink. stepper: 7 failing tests are yours — done nodes must NOT read colorScheme.primary.' },
  { key: 'meters', harness: 'jeeb_meters_test_harness.dart', widgets: ['jeeb_meter', 'jeeb_price_meter', 'jeeb_section_label', 'jeeb_tier_chip'], note: 'section_label ink = mutedText #8A93D8 (3 failing tests are yours). tier hues (jeeb_tier_colors) UNCHANGED this wave.' },
  { key: 'remainder', harness: 'jeeb_remainder_test_harness.dart', widgets: ['jeeb_accent_frame_card', 'jeeb_page_dots', 'jeeb_segmented_toggle', 'jeeb_stepper_pill', 'jeeb_tier_row'], note: 'segmented_toggle: RULED active = WHITE fill + navy ink, inactive glass (study notes). tier_row: Pattern E chip size classes + compact variant groundwork for R9.' },
]

const BUILDERS = [
  { key: 'glass', item: 'M1-2', prompt: `Create lib/core/widgets/jeeb/jeeb_glass_card.dart: JeebGlassCard (rest glass: glassFill fill, 1px glassBorder, JeebRadii.lg, NO blur) and JeebGlassCapsule (hero glass: glassFillEmphasis, glassBorderStrong, JeebRadii.capsule/pill, real BackdropFilter blur 10 — document the ≤2-per-screen budget in ONE short comment). Optional onTap with white-alpha splash. Tests: test/core/widgets/jeeb/jeeb_glass_card_test.dart — fills/borders/radii/blur presence, tap, no orange anywhere.` },
  { key: 'empty', item: 'M1-3', prompt: `Create lib/core/widgets/jeeb/jeeb_empty_state.dart: JeebEmptyState per master plan §2.7 + study-notes ruling 1. STEP 0: Read these tile PNGs with the Read tool and list 8+ observations BEFORE code: "/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/export-rich-ui/screens/27-e1-empty-no-requests.png", "31-e1-sample-a-the-empty-pocket.png", "32-e1-sample-b-ask-from-the-balcony.png", "33-e1-sample-c-the-beacon.png" (same dir). MOTION IS BOARD-MEASURED: read docs/redesign-midnight/03-MOTION-NOTES.md sections E1 + samples A/B/C and wire EXACTLY what they list — the route-dot ring and the 4 medallions are STATIC (no jDash march, no orbit); animation lives on the center (halo/breathe), twinkles, and floats only as the notes say per element. API: composed illustration (center widget default = orange mic disc w/ glow + flanking orangeSoft wave bars; STATIC dotted route-ring dash 1/9 carrying 4 configurable icon medallions) + white headline + mutedText body + optional CTA; variants enum for the 3 sample alternates (compose from palette shapes, NO baked PNGs); loading state = illustration skeleton with jBreathe; error = danger-tinted center. Consume lib/core/motion primitives per the notes, JeebRadii, palette; do NOT paint a JeebMidnightField (the field belongs to the screen). Reduce-motion safe. Tests: variant/state coverage, reduce-motion settles, identifiers slot.` },
  { key: 'nav', item: 'M1-4', prompt: `Create lib/core/widgets/jeeb/jeeb_pill_nav.dart: the floating pill nav per study-notes ruling 2. STEP 0: Read "/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/export-rich-ui/screens/01-r1-client-home.png" and list 6+ observations of the nav specifically. Detached capsule (JeebRadii.pill), navy surface + glassBorder, JeebShadows.floatNav; 5 fixed slots {icon, label, identifier}; active = orange rounded-square pill behind icon + white label; inactive periwinkle icon+label (~10.5 ramp label style); always-visible labels; RTL-safe; 48dp hit targets (hit-test, not layout — Pattern E). NO tab-to-route mapping (M2-01 owns semantics). Tests: active pill is the ONLY orange, identifiers, hit target size, RTL.` },
]

phase('Restyle')
const results = await parallel([
  ...GROUPS.map((g) => () => agent(
    `You are restyling ${g.widgets.length} Jeeb kit widgets for the MIDNIGHT redesign (dark navy design language).\n${COMMON}\nYOUR WIDGETS (exclusive ownership, lib/core/widgets/jeeb/<name>.dart + test/core/widgets/jeeb/<name>_test.dart): ${g.widgets.join(', ')}.\nYOUR shared harness (exclusive): test/core/widgets/jeeb/${g.harness} — no other agent may touch it; you may not touch any other harness.\nGroup notes: ${g.note}`,
    { label: `restyle:${g.key}`, phase: 'Restyle', model: 'opus' },
  )),
  ...BUILDERS.map((b) => () => agent(
    `You are building a NEW Jeeb kit widget for the MIDNIGHT redesign (${b.item}).\n${COMMON}\n${b.prompt}\nNew files only — you own them exclusively.`,
    { label: `build:${b.key}`, phase: 'Restyle', model: 'opus' },
  )),
])

phase('Verify')
const verify = await agent(
  `You are the M1 kit verifier for the Jeeb MIDNIGHT redesign in ${REPO} (branch feat/redesign-midnight; NEVER run git mutations).
Run and report raw results:
1. flutter analyze --no-pub lib/core/widgets/jeeb test/core/widgets/jeeb
2. flutter test test/core/widgets/jeeb  (full kit suite — report exact pass/fail counts and EVERY failing test name)
3. command grep -rn "Color(0x" lib/core/widgets/jeeb --include="*.dart" | command grep -v jeeb_midnight_palette  (raw hex outside palette — list hits)
4. command grep -rn "Colors\\." lib/core/widgets/jeeb --include="*.dart" | command grep -v "Colors.transparent"  (list hits)
5. command grep -rn "colorScheme.primary" lib/core/widgets/jeeb --include="*.dart"  (orange-budget leaks — list hits)
FIX NOTHING. Report only.`,
  { label: 'verify:kit', phase: 'Verify', model: 'opus' },
)

return { groupReports: results.filter(Boolean), verify }
