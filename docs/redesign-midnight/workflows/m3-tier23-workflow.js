export const meta = {
  name: 'midnight-m3-tier23',
  description: 'M3 Tiers 2+3 — wallet subtree, the ratified settlement DELETION, the 6-screen KYC funnel, + a danger-CTA kit lane',
  phases: [{ title: 'Screens', detail: '1 wallet lane + 1 deletion lane + 6 KYC lanes + kit danger CTA + l10n' }],
}

const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const TILES = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/export-rich-ui/screens'

const COMMON = `
You are restyling MIDNIGHT rows in ${REPO}, branch feat/redesign-midnight (verify with \`git status -sb\`; NEVER run git commit/checkout/stash/branch — leave changes in the working tree).
GOLDEN RULE (user mandate): code comments max 2 lines, only when super necessary.

**M3 ROWS HAVE NO TILE.** You derive, you do not invent. STEP 0:
1. Read docs/redesign-midnight/01-TOKEN-SHEET.md and 02-STUDY-NOTES.md **in full** — they ARE your spec, and every ruling binds you.
2. Name your NEAREST TILE PATTERN, read that tile PNG (under ${TILES}), and state which patterns you carry over: field variant + glow/wash placement, surface rungs, ink hierarchy, CTA treatment, row rung, empty-state variant.
3. List 6+ derived decisions, each traced to a token-sheet value or a study-notes ruling — not to taste. Untraceable decision = ambiguity: STOP and return the question.
4. Confirm reachability from lib/main.dart (docs/redesign-2026-08/screen-repo-map.md wins).

**MOTION: none beyond what kit widgets already animate.** Use \`animateDecor: false\` unless you name a reason.
FIELD anchors: JeebFieldGlowPlacement{topEnd, centerUpper, bottom, topStart} · JeebFieldWashPlacement{startMid, bottomEnd, topStart, endMid}. A wash is PERIWINKLE, a glow is ORANGE — different layers; screens have shipped mirrored because that was missed.

**KNOWN DEFECT SIGNATURE — grep for it in your files:** any pass-1 code or comment treating \`colorScheme.primary\` as a cool/navy colour is now FALSE. Under Midnight \`primary\` IS \`#D73B00\`. \`colorScheme.primary\` on a non-CTA element is an orange-budget leak; it has already been found on four screens. Report every instance you fix.

CONSTRAINTS:
- Tokens/kit only; ZERO raw hex, ZERO Colors.* (transparent ok). **Do NOT modify lib/core/** — FROZEN; return the question. (One lane this wave owns the kit; it is not you unless stated.)
- ALL states: default, loading, empty, error. Empty family = JeebEmptyState (e1, radar, street, parcel, pocket, balcony, beacon) — pick the nearest subject and say why.
- Preserve frozen test identifiers by re-homing; delete chrome that existed only to host them.
- NEW l10n keys → docs/redesign-midnight/l10n-queue/<your-item>.md + nearest existing key with TODO(midnight): l10n-queued. Do NOT edit lib/l10n/*.arb.
- Missing wire data → designed slot + TODO(midnight): omitted, not faked. NEVER fabricate.
- RTL-safe. Respect MediaQuery.disableAnimations; any harness mounting ShellScreen must set it (a guard test enforces this).

**STANDING RULE — goldens are evidence, NOT gates** (5% tolerance; a real ink swap moved 0.097% and three goldens stayed green carrying the wrong colour). Land per-element assertions read off the widget, and PROVE each discriminates by reverting the value and confirming red.

Analyze baseline: 0 errors / 30 known infos. KNOWN-RED and NOT yours (all verified pre-existing at fc93ace9): test/features/chat/chat_header_contrast_test.dart (5) · test/language_settings_screen_test.dart (2) · test/dio_tier_repository_test.dart (2) · test/core/diagnostics/gesture_log_test.dart (1) · 14 files under test/previews/ · 2 in test/tools/catalog_capture_test.dart.
CONCURRENCY: an l10n lane owns lib/l10n. If an error appears inside lib/l10n or a missing getter you did not introduce, re-run ONCE; report only if it reproduces.

AFTER IMPLEMENTING — selfCritique: 4+ specific deltas vs your nearest tile, fix what you can, report the rest.
VERIFY: flutter analyze --no-pub <your dirs> → 0 errors · targeted tests (before/after counts) · non-zero diff on primary files · re-capture your states (--update-goldens --plain-name "<filter>" --tags capture) into docs/redesign-midnight/captures/<item>/.
RETURN: nearest tile + why · 6+ traced decisions · files+diffstat · changes per file · selfCritique · test results · discrimination proof · primary-leaks fixed · l10n queued · questions.`

const LANES = [
  {
    label: 'wallet subtree', item: 'M3-11..14',
    prompt: `YOUR ITEM: FOUR checklist rows, one lane because they share \`lib/features/wallet/\`:
  M3-11 wallet_activity_list_screen.dart (392) · M3-12 transaction_detail_screen.dart (388) · M3-13 wallet_charge_info_screen.dart (194) · M3-14 customer_wallet_stub_screen.dart (123)
Nearest tile: **R4 wallet** (${TILES}/04-r4-wallet.png), whose hub (\`wallet_hub_screen.dart\`) is ALREADY Midnight (M2-18) — read it first and carry its shipped treatment across rather than re-deriving. R4 draws TWO radials: an orange glow top-start and a periwinkle wash end-side at mid-height (\`JeebFieldWashPlacement.endMid\`) — both already adopted on the hub.
Money emphasis = price 22/w800; success/danger money ink from the token sheet §2. R19 earnings is the secondary pattern for row facts.
**Report each of the four rows' diffstat separately** so each checklist row can be ticked on its own evidence.`,
  },
  {
    label: 'settlement DELETE', item: 'M3-15..16',
    prompt: `YOUR ITEM: M3-15 and M3-16 — the settlement pair. **These are RATIFIED DELETIONS, not restyles** (02-STUDY-NOTES §ORPHAN rulings): *"DELETE (routes+screens+tests+catalog; keep cubit/repo only if referenced elsewhere) — zero inbound, no deep link, no Maestro; T-MOB-032 designed-never-linked — restorable from git."*
YOU OWN: lib/features/settlement/, lib/core/router/app_router.dart (routes only), the settlement catalog entries/fixtures, and settlement tests.
Work:
1. **Re-verify the evidence before deleting anything.** Grep for every inbound reference to both screens and their routes across lib/, test/, integration_test/ and .maestro/. If you find ANY live inbound path the sweep missed, STOP and report — do not delete on a stale ruling.
2. Delete screens, routes, tests and catalog entries. Keep the cubit/repository ONLY if something else references them; say which you kept and why.
3. Update the things deletions are known to break: \`no_raw_semantic_colors_test.dart\` pinned paths, back-fallback maps, and any Type-A gate list naming the files.
4. Report exactly what was removed, with the grep evidence, so the owner can restore from git if product ever wires it (owner confirm is §8 Q9).
Do NOT delete anything not named above.`,
  },
  { label: 'M3-17 dm onboarding', item: 'M3-17', prompt: `YOUR ITEM: M3-17 \`lib/features/jeeber_onboarding/presentation/dm_onboarding_screen.dart\` (258). Part of the KYC funnel. Nearest tile: **R23 become-a-jeeber** (${TILES}/23-r23-become-a-jeeber.png), already Midnight (M2-20) — read \`lib/features/kyc/\` and carry its shipped treatment. R5 onboarding is the secondary pattern for a welcome/intro shape.` },
  { label: 'M3-18 onboarding funding', item: 'M3-18', prompt: `YOUR ITEM: M3-18 \`lib/features/jeeber_onboarding_funding/presentation/onboarding_funding_screen.dart\` (202). A money surface inside the KYC funnel — nearest tiles: R4 wallet for the money treatment, R23 for the funnel chrome. Money emphasis = price 22/w800.` },
  { label: 'M3-19+20 kyc gate', item: 'M3-19..20', prompt: `YOUR ITEM: TWO rows sharing \`lib/features/offer_kyc_gate/\`: M3-19 offer_kyc_gate_screen.dart (260) and M3-20 delivery_register_prompt_screen.dart (96). Both are gates/prompts standing between a jeeber and an action. Nearest tiles: R23 (funnel chrome) and R17 offer composer (the action being gated). Report each row's diffstat separately.` },
  { label: 'M3-21 kyc rejected', item: 'M3-21', prompt: `YOUR ITEM: M3-21 \`lib/features/kyc_rejected/presentation/kyc_rejected_screen.dart\` (222). A failure/terminal state. Nearest tile: R23 for chrome; the danger ink roles from token sheet §2 for the rejection itself. Destructive/negative text uses \`onErrorContainer\` (#FF7B7B), not \`error\` — the R22 ruling. Consider JeebEmptyState's error status for the body.` },
  { label: 'M3-22 account status', item: 'M3-22', prompt: `YOUR ITEM: M3-22 \`lib/features/account_status/presentation/account_status_screen.dart\` (205). Renders suspended/locked states — read its existing catalog entries first. Nearest tile: R23 for chrome, R22 settings for the status-row rung. Danger ink per token sheet §2; the R22 destructive ruling applies.` },
]

const KIT_DANGER = `You are the kit lane for MIDNIGHT M3 Tiers 2+3 in ${REPO}, branch feat/redesign-midnight (NEVER run git mutations). GOLDEN RULE: comments max 2 lines, only when super necessary.
YOU OWN lib/core/widgets/jeeb/jeeb_cta_button.dart and test/core/widgets/jeeb/jeeb_cta_button_test.dart. Nothing else.

**Add a destructive rung to \`JeebCtaButton\`** — sanctioned as Q-041, and it is safety-shaped rather than cosmetic. Today \`JeebCtaButton._ink\` hard-overwrites any \`labelStyle\` colour and there is no glass-pill + \`onErrorContainer\` rung, so a cancellation screen's terminal destructive act renders in plain \`onSurface\` — **quieter than every affirmative CTA in the app.** The M3-04 lane correctly refused both workarounds (a local re-implementation of \`accentSelected\` in a different hue is the Theme-swap class wave-A deleted; a danger \`selectedShadow\` contradicts "glow only where a tile draws it").

Design it from the token sheet, not from taste:
- The board never draws a destructive CTA, so there is no tile to copy. Derive from §2 danger roles: \`error\` #FF5252 · \`onError\` #070C33 · \`errorContainer\` · \`onErrorContainer\` #FF7B7B. The R22 ruling is that destructive TEXT uses \`onErrorContainer\`, because #FF5252 as an ink on navy is the harsher pair.
- Match the existing rung geometry exactly (heights, radii, pressed states) — this is an ink change, not a new shape. Read how \`accent\` and \`outline\` are built and mirror that construction.
- Existing callers must not move: every current variant keeps its exact rendering. Additive only.
- State clearly in your report which ink you chose for fill vs label and why, and whether the rung is a filled or an outline/glass form (or both).

Also fix the underlying rigidity if it is cheap: \`_ink\` hard-overwriting \`labelStyle\` is what made this unfixable from a feature lane. If a narrow \`labelInk\` override is safe and does not let callers spend the orange budget, add it and say so; if it opens a hole, do NOT add it and explain.

PROVE the new rung discriminates: revert its ink and confirm the test goes red, then restore.
VERIFY: flutter analyze --no-pub lib/core → 0 errors · flutter test test/core/widgets/jeeb test/core/theme → all green (the kit was 804 at the last count; it must not regress) · run the CTA's consumers, do not reason about them: flutter test test/features/cancellation test/features/escalate test/features/client_offers test/features/offers.
RETURN: exact signature added · ink choices + their token traces · before/after counts · discrimination proof · whether labelInk was added and why.`

const L10N = `You are the l10n merge lane for MIDNIGHT M3 Tiers 2+3 in ${REPO}, branch feat/redesign-midnight (NEVER run git mutations). GOLDEN RULE: comments max 2 lines, only when super necessary.
YOU OWN lib/l10n/*.arb. Work:
1. Process EXACTLY the M3 Tier-1 queue files present in docs/redesign-midnight/l10n-queue/ **at the moment you start** — list them, then process only that list. (Nine screen lanes are running concurrently and WILL add files; those are next-wave work. NEVER glob after you have fixed your list.)
2. No \`flutter gen-l10n\` in this repo — the ARBs are pubspec assets parsed at runtime by the hand-authored lib/l10n/app_localizations.dart. Hand-add getters into the existing numbered sections.
3. Swap "TODO(midnight): l10n-queued" call sites in the M3 Tier-1 dirs ONLY: lib/features/{deep_link_targets,escalate,no_offer_timeout,cancellation,order_summary,jeeber_request_detail,customer_profile,notifications,rating,delivery_man_profile}. Do NOT touch this wave's dirs (wallet, settlement, jeeber_onboarding, jeeber_onboarding_funding, offer_kyc_gate, kyc_rejected, account_status). If a row points there, apply the KEY, leave the call site, report it.
4. Close any feature-local l10n stopgap whose keys have all landed byte-identical (as otp_handover and live_tracking were closed). Any mismatch → keep it, say why.
5. Delete ONLY the queue files you processed.
STANDING RULINGS: value changes in scope (change value, keep key id). Key marked "replaced" → grep after swapping; zero refs → delete from both ARBs; any left → KEEP and report. Never leave a dangling reference. A queue file naming a test that pins a literal via find.text → YOU own that test file, update the finder. **Sentence case is the DS rule** — expect stale Title Case pins and fix them.
VERIFY: flutter analyze --no-pub lib/l10n + the Tier-1 dirs → 0 errors · flutter test test/l10n + the Tier-1 suites → green (before/after).
RETURN: files processed · keys applied/deleted with grep evidence · call sites swapped · stopgaps closed · test finders updated · AR flags · counts · questions.`

phase('Screens')
const results = await parallel([
  ...LANES.map((l) => () => agent(`${l.prompt}\n${COMMON}\nYour capture/report item id: ${l.item}.`, { label: l.label, phase: 'Screens', model: 'opus' })),
  () => agent(KIT_DANGER, { label: 'kit:danger-cta', phase: 'Screens', model: 'opus' }),
  () => agent(L10N, { label: 'l10n-merge', phase: 'Screens', model: 'opus' }),
])

return Object.fromEntries([...LANES.map((l, i) => [l.item, results[i]]), ['kit-danger', results[7]], ['l10n', results[8]]])
