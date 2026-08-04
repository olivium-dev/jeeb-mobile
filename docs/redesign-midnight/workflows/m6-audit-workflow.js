export const meta = {
  name: 'midnight-m6-audits',
  description: 'M6 phase 1 — four independent audits producing grouped finding lists; the fix wave is composed from their output',
  phases: [{ title: 'Audits', detail: 'token purity · Material leaks · 30-tile glow survey · AA + RTL' }],
}
const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const TILES = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/export-rich-ui/screens'
const BOARD = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/Jeeb Rich UI.dc.html'

const COMMON = `
Repo ${REPO}, branch feat/redesign-midnight. **You write NO production code unless your brief says so** — your deliverable is an evidence-backed finding list. NEVER run git commit/checkout/stash/branch.
Read docs/redesign-midnight/01-TOKEN-SHEET.md and 02-STUDY-NOTES.md first; every ruling there binds your verdicts.
**END EVERY REPORT with a per-top-level-directory grouping of your findings, with a count per dir.** The fix wave is composed FROM that grouping — the orchestrator hardcoded groupings in M4 and M5 and left directories uncovered both times, so your grouping is load-bearing.
**EXCLUDE from all findings** (production-dead pending owner ruling Q-043, annotate rather than fix): lib/features/delivery_status/, lib/features/tier_selection/presentation/, lib/features/prohibited_acknowledgment/.
Be honest about limits: say which angles found nothing, and flag anything you suspect exists that your method cannot see.`

const TOKENS = `You are the M6 TOKEN-PURITY audit.
Sweep all of lib/ for four defect classes and report every instance with file:line:
1. **Raw hex** — \`Color(0x…)\` outside the sanctioned homes (the palette/theme/motion files). §5's bar is ZERO outside theme files. List each with its owning file so the fix lane knows whether it is sanctioned.
2. **\`Colors.*\`** — beyond \`Colors.transparent\` and the small sanctioned set of field-canvas paints recorded in the G-M1 gate. Anything else is a light-theme survivor.
3. **\`colorScheme.primary\` on a NON-CTA element.** This is the session's most productive signature: under Midnight \`primary\` IS \`#D73B00\`, so any pass-1 code or comment treating it as navy/cool now renders ORANGE. Already found on 8+ screens — one ledger drew three orange elements per row, a wallet drew 3 solid orange step discs under a comment reading "navy disc", loading spinners inked themselves orange. Distinguish a legitimate accent CTA from a leak, and say which.
4. **\`Theme.of(context).extension<…>()!\`** — a bang on that nullable lookup throws under any theme lacking the extension; it cost 9 latent crashes. The kit's own pattern is \`?? JeebSemanticColors.midnight()\`.
Also flag any pass-1 COMMENT that is now false under Midnight (e.g. asserting primary is navy, or that periwinkle fails on white) — those mislead the next reader even where the code is right.`

const MATERIAL = `You are the M6 MATERIAL-LEAK audit. Walk plan §2.4 surface by surface and report what actually renders.
The plan's own words: *"every Material widget that auto-consumes primary (FAB, filled buttons, progress, selection, focus rings, switches, sliders, text cursors, chips) must be checked"* and **"No white flash: check route transitions, first frame, dialogs, keyboards — anything that betrays a light Material default underneath."**
Cover at minimum: dialogs · bottom sheets · date/time pickers · snackbars · popup menus · dropdowns · tooltips · scroll glow/stretch (Android) · text selection handles + cursor · keyboard appearance (iOS \`Brightness.dark\`) · status + nav bar chrome · route transition backgrounds · first frame / splash.
02-STUDY-NOTES §Theme ruling 5 lists sub-themes that were NEVER AUDITED and were explicitly deferred to this sweep: **drawer, rail, search, dropdown, segmentedButton, expansionTile, scrollbar, badge, banner.** Audit each: is it themed, or does it fall through to a Material default?
**Prove a white flash rather than asserting it** — mount the surface in a test and read the pixel, or explain precisely why a given surface cannot be reached in a widget test (that itself is a finding: an unreachable surface is one nobody has ever verified).`

const GLOW = `You are the M6 GLOW SURVEY. **This one produces a RULING, not just a list**, and it has been deferred through four milestones.
Open questions Q-027 / Q-034 / Q-036 and five independent data points recorded in 02-STUDY-NOTES all say the same thing: the kit's two-value glow split may be wrong.
- Kit ships \`content\` alpha .22 / \`hero\` .28, one \`_glowRadiusFactor\` 1.18, one \`_glowFade\` .60.
- Board-declared alphas so far: R4 .26 · R9 .24 · R17 .24 · **R22 .20**; pixel fits 0.246 / 0.249 / 0.259. All cluster BETWEEN the two kit constants.
- R22 also declares a 480×380 ellipse (rx factor 1.091) — BELOW the 500–560 cluster 1.18 came from — and a **58%** fade against the shipped .60; three tiles have now measured 58%.
**Survey ALL 30 in-scope tiles** in ${BOARD} (canvas 440×956; the two lengths before \`at\` in a radial-gradient are RADII, not diameters — an early ruling of mine got this wrong and made every screen's glow ~14% too wide). For each tile record: glow rx/ry, its factor against 440, alpha, fade stop, anchor; and separately the periwinkle wash where present.
Then RULE, with the distribution in front of you: is a single alpha right, or two, or per-variant? Is 1.18 the right radius factor? Is the fade .60 or .58? **A ruling of "the current values are correct and the outliers are outliers" is a legitimate outcome** — say what the data supports, not what would be tidy. Note 02-STUDY-NOTES already ruled the periwinkle WASH has no single ratifiable factor (board draws rx 460–900, no cluster); check whether the ORANGE GLOW is genuinely tighter or whether that conclusion should extend.
You may write NO code — the fix lane applies your ruling. Give exact constants.`

const AA_RTL = `You are the M6 AA + RTL audit.
**AA:** re-test every ink/surface pair the token sheet §9 gates, plus every pair introduced since (danger CTA, washed stepper ink, accent-tint frame, glass avatar, the success-check composition on navy). Report measured ratios, not assertions.
**Q-022 is yours to settle:** \`test/features/chat/chat_header_contrast_test.dart\` has been 5-red all engagement — a pass-1 instrument pinning LIGHT-ERA role values against Midnight. Two of its rows measure a genuine sub-AA pair (\`onPrimary\` on an orange-blended chip at **3.87:1**). Decide: is that a real defect needing a token fix, or is it large-text (AA large = 3:1) and therefore passing? Then re-cut the instrument for Midnight the way M0-8 re-cut the theme gate — it should measure the palette we actually ship. **You own that test file**; make it green by making it CORRECT, never by loosening a threshold.
**Also settle the R15 chip a11y question**, explicitly routed here: \`JeebSelectChip\` renders under 48dp and the kit doc says wrap in \`MinTapTarget\` at the call site, but doing so inflates the board's measured 8dp run gap to ~22dp and breaks the 3+2 rhythm. It was ruled board-faithful per-screen and deferred to this sweep "to decide it once for all inline chip rows". Decide it once. WCAG 2.5.8 has an inline exception — determine whether these qualify.
**RTL:** sweep for hard-coded \`EdgeInsets\` (non-directional) on layout-bearing padding, \`Alignment\` instead of \`AlignmentDirectional\`, and any \`Row\` whose order carries meaning. Report by directory.
You MAY edit \`test/features/chat/chat_header_contrast_test.dart\` and nothing else in production code.`

phase('Audits')
const r = await parallel([
  () => agent(`${TOKENS}\n${COMMON}`, { label: 'audit:tokens', phase: 'Audits', model: 'opus' }),
  () => agent(`${MATERIAL}\n${COMMON}`, { label: 'audit:material', phase: 'Audits', model: 'opus' }),
  () => agent(`${GLOW}\n${COMMON}`, { label: 'audit:glow-survey', phase: 'Audits', model: 'opus' }),
  () => agent(`${AA_RTL}\n${COMMON}`, { label: 'audit:aa-rtl', phase: 'Audits', model: 'opus' }),
])
return { tokens: r[0], material: r[1], glow: r[2], aaRtl: r[3] }
