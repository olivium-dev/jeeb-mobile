export const meta = {
  name: 'midnight-m3-tier5',
  description: 'M3 Tier 5 — the last 14 rows: edge/support surfaces, 2 lib/core carve-outs, the ratified rating_prompt deletion',
  phases: [{ title: 'Screens', detail: '10 screen lanes + l10n merge' }],
}

const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const TILES = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/export-rich-ui/screens'

const COMMON = `
You are restyling MIDNIGHT rows in ${REPO}, branch feat/redesign-midnight (verify with \`git status -sb\`; NEVER run git commit/checkout/stash/branch).
GOLDEN RULE (user mandate): code comments max 2 lines, only when super necessary.

**M3 ROWS HAVE NO TILE — derive, do not invent.** STEP 0: read docs/redesign-midnight/01-TOKEN-SHEET.md and 02-STUDY-NOTES.md in full (they ARE your spec) · name your NEAREST TILE PATTERN and read that PNG under ${TILES} · list 6+ derived decisions each traced to a token value or a standing ruling · confirm reachability from lib/main.dart. An untraceable decision is an ambiguity: STOP and return the question.

**Most of this tier is tiny placeholder/edge screens.** For those the right answer is usually: mount the field, move ink to the ratified roles, put the body on JeebEmptyState, and change nothing else. Resist inventing structure a 30-line screen does not have.

**KNOWN DEFECT SIGNATURE — grep your files:** any pass-1 code or comment treating \`colorScheme.primary\` as cool/navy is FALSE — under Midnight \`primary\` IS \`#D73B00\`. Found on 8 screens so far (one ledger drew three orange elements per row). \`colorScheme.primary\` on a non-CTA is an orange-budget leak. Report every instance.

MOTION: none beyond what kit widgets animate; \`animateDecor: false\` unless you name a reason.
FIELD anchors: JeebFieldGlowPlacement{topEnd, centerUpper, bottom, topStart} · JeebFieldWashPlacement{startMid, bottomEnd, topStart, endMid}. A wash is PERIWINKLE, a glow is ORANGE — different layers.
CTA: \`JeebCtaVariant.danger\` exists for destructive acts. NOTE its known limit: \`JeebCtaButton\` force-overrides \`labelStyle.color\` with \`_ink\`, so a \`.text\` variant cannot be re-inked — if you need a bare dim-red label, use R22's TextButton construction and say so.

CONSTRAINTS:
- Tokens/kit only; ZERO raw hex, ZERO Colors.* (transparent ok). **lib/core/** is FROZEN except where your lane explicitly carves out a file.
- ALL states: default, loading, empty, error. Empty family = JeebEmptyState (e1, radar, street, parcel, pocket, balcony, beacon). **KIT FACT: \`_pocketLayers()\` IGNORES the \`center\` slot and hard-draws a solid orange mic** — only \`_e1Layers()\` honours \`center\`.
- Preserve frozen test identifiers by re-homing; delete chrome that existed only to host them.
- NEW l10n keys → docs/redesign-midnight/l10n-queue/<item>.md + nearest existing key with TODO(midnight): l10n-queued. Do NOT edit lib/l10n/*.arb.
- Missing wire data → designed slot + TODO(midnight): omitted, not faked. NEVER fabricate.
- RTL-safe. Respect MediaQuery.disableAnimations; a guard test enforces it for ShellScreen harnesses.

**STANDING RULE — goldens are evidence, NOT gates** (5% tolerance). Land per-element assertions read off the widget and PROVE each discriminates by reverting and confirming red.

Analyze baseline: 0 errors / 30 known infos. KNOWN-RED and NOT yours: chat_header_contrast (5) · dio_tier_repository (2) · gesture_log (1) · 14 files under test/previews/ · 2 in catalog_capture_test.
CONCURRENCY: an l10n lane owns lib/l10n. Error there that you did not introduce → re-run ONCE, report only if it reproduces.

AFTER IMPLEMENTING — selfCritique: 4+ specific deltas vs your nearest tile, fix what you can, report the rest.
VERIFY: flutter analyze --no-pub <your dirs> → 0 errors · targeted tests (before/after) · non-zero diff on primary files · re-capture states into docs/redesign-midnight/captures/<item>/.
RETURN: nearest tile + why · traced decisions · files+per-row diffstat · changes per file · selfCritique · test results · discrimination proof · primary-leaks fixed · l10n queued · questions.`

const LANES = [
  { label: 'support ticket', item: 'M3-30', prompt: `YOUR ITEM: M3-30 \`lib/features/support/presentation/support_ticket_screen.dart\` (616). A form + thread surface. Nearest patterns: R20 order chat for a message thread, R22 for form rows. If it has a submitted/pending/failed lifecycle, all three are states you must restyle.` },
  { label: 'reviews list', item: 'M3-31', prompt: `YOUR ITEM: M3-31 \`lib/features/reviews/presentation/reviews_list_screen.dart\` (563). ORPHAN ruling: **KEEP+restyle, BOTH ROUTES** — the query-param route is LIVE (client_offers→profile→reviews) and the path-param twin is pinned by Maestro jm-068. Do not delete either; verify both still resolve after your change.
Nearest patterns: R15 mutual rating (amber stars + the radial-gradient halo — a BoxShadow halo paints NOTHING on the golden canvas) and R21 for the row rung. Stars do not twinkle.` },
  { label: 'dispute status', item: 'M3-32', prompt: `YOUR ITEM: M3-32 \`lib/features/dispute_status/presentation/dispute_status_screen.dart\` (423). A status/timeline surface — it mounts \`OrderTrackingStepper\`, which is already Midnight (M2-08/wave-C) and takes \`JeebStepperDoneInk\`; consume it, do not hand-paint a bar row. Nearest patterns: R3 for the stepper, R13 for glass status rows. Danger ink on \`onErrorContainer\`.` },
  { label: 'name + password', item: 'M3-33,34', prompt: `YOUR ITEM: TWO rows in two small dirs:
  **M3-33** \`lib/features/profile_name/presentation/display_name_setup_screen.dart\` (276) — a first-run name capture. Nearest: R6 registration (already Midnight) — carry its field + CTA treatment.
  **M3-34** \`lib/features/auth/presentation/set_password_screen.dart\` (244) — ⛔ **CAUTION: the email/password funnel was REMOVED in JEBV4-199 (Q-044 ratified); auth is phone-OTP + social only.** Before restyling, establish whether this screen is reachable from any live path. If it is dead code behind the removed funnel, **STOP and report it as an ORPHAN candidate with your grep evidence** rather than restyling a screen nobody can open. If it is live for some other purpose, restyle it and say what it actually sets.
Report each row separately.` },
  { label: 'biometric lock', item: 'M3-35', prompt: `YOUR ITEM: M3-35 \`lib/features/biometric_auth/presentation/biometric_lock_screen.dart\` (141). A full-screen lock gate. Nearest: R7 OTP verify (already Midnight) for a centred single-purpose auth surface. It likely has locked / authenticating / failed states — restyle all of them.` },
  { label: 'jeeber pending offers', item: 'M3-36', prompt: `YOUR ITEM: M3-36 \`lib/features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart\` (175). ORPHAN ruling: **KEEP+restyle** — it is the \`notification_deep_link.dart:57\` fallback, has dispatcher tests, and is pinned by Maestro jm-047. Nearest: R10 client offers (already Midnight) for the offer-row rung, R16 for the jeeber-side framing. Empty state matters here — a jeeber with no pending offers is the common case.` },
  { label: 'diagnostics (core carve-out)', item: 'M3-38', prompt: `YOUR ITEM: M3-38 \`lib/core/diagnostics/diagnostics_screen.dart\` (353). ORPHAN ruling: **KEEP+restyle** (Diag.enabled-gated, 19 tests, dev-support value).
**CARVE-OUT: you may edit \`lib/core/diagnostics/\` ONLY.** The rest of lib/core — theme, widgets/jeeb, router — remains FROZEN to you. If your restyle needs a kit change, STOP and return the question.
This is a developer surface, so legibility beats fidelity: dense monospace-ish rows are fine. Nearest: R22 settings for row rungs. Do not spend the orange budget on a dev tool.` },
  { label: 'unavailable placeholders', item: 'M3-39,40,41', prompt: `YOUR ITEM: THREE tiny placeholder screens, all "this thing is not available" surfaces:
  **M3-39** \`lib/features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart\` (62)
  **M3-40** \`lib/features/request_summary/presentation/request_summary_unavailable_screen.dart\` (29)
  **M3-41** \`lib/core/router/profile_unavailable_screen.dart\` (30) — **CARVE-OUT: you may edit THIS ONE FILE inside lib/core. \`app_router.dart\` is owned by another lane this wave — do NOT touch it;** if you need a route change, report it.
All three should land on the same treatment: field + \`JeebEmptyState\` with an appropriate status and variant. **They are 30-60 line screens — do not invent structure.** The win is consistency: three "unavailable" surfaces that currently look like three different apps should look like one. State explicitly which variant you chose for all three and why it is the same one.
Report each row separately.` },
  { label: 'rating_prompt DELETE', item: 'M3-42', prompt: `YOUR ITEM: M3-42 — **a ratified DELETION, not a restyle** (02-STUDY-NOTES §ORPHAN): *"DELETE screen+previews+fixtures; KEEP route+redirect (inline minimal builder; update Type-A gate list if it names the file) — builder unreachable behind an unconditional redirect; the redirect is the live rating-push path."*
YOU OWN: \`lib/features/deep_link_targets/rating_prompt_screen.dart\`, its previews/fixtures/catalog entries and tests, AND \`lib/core/router/app_router.dart\` (no other lane may touch the router this wave).
Work:
1. **Re-verify the evidence BEFORE deleting.** Grep every inbound reference across lib/, test/, integration_test/, .maestro/. Confirm the redirect really is unconditional and really is the live rating-push path. **If any live path reaches the builder, STOP and report** — a previous deletion lane found a documented \`// FROZEN identifier\` claim that was provably false, so verify rather than trust comments.
2. Delete screen + previews + fixtures + catalog entries + its tests. **KEEP the route and its redirect**, replacing the builder with a minimal inline one.
3. Update what deletions break: \`no_raw_semantic_colors_test.dart\` pinned paths, \`catalog_size_test.dart\` floors, back-fallback maps, any Type-A gate list naming the file.
4. **Before deleting any test, check whether it is the sole enforcement point of a product decision** — a prior lane caught that deleting a screen would have silently dropped the D41/D44 'Platform fee' lock, and re-homed it. Do the same if you find one.
5. NOTE: \`rating-prompt compact 320x568 200% text\` is one of our 2 remaining known-red catalog captures. If your deletion removes that catalog entry, that red closes — say so explicitly.
Report exactly what was removed with the grep evidence.` },
  { label: 'dev chat + voice shim', item: 'M3-44,45', prompt: `YOUR ITEM: TWO small rows:
  **M3-44** \`lib/features/chat/presentation/dev_chat_preview_screen.dart\` (148) — debug-gated. Style it if it is kept; it is a dev surface so legibility beats fidelity and it must not spend the orange budget. Confirm it is genuinely debug-gated before investing.
  **M3-45** \`lib/features/voice_request/presentation/voice_request_screen.dart\` (28) — a SHIM. The row's note is *"verify delegate covers it"*. **Verify first: if it merely delegates to the already-Midnight voice recording screen, the correct result is ZERO product diff plus a delegation-contract guard test** — exactly what M3-25 did this wave (a test that fails the moment chrome appears between wrapper and delegate). Do not restyle a pass-through.
Report each row separately.` },
]

const L10N = `You are the l10n merge lane for MIDNIGHT M3 Tier 5 in ${REPO}, branch feat/redesign-midnight (NEVER run git mutations). GOLDEN RULE: comments max 2 lines, only when super necessary.
YOU OWN lib/l10n/*.arb. Work:
1. LIST the queue files in docs/redesign-midnight/l10n-queue/ at the moment you start, then process ONLY that fixed list. Ten screen lanes are running concurrently and WILL add files — those are next-wave work. NEVER re-glob after fixing your list.
2. No \`flutter gen-l10n\` here — ARBs are pubspec assets parsed at runtime by the hand-authored lib/l10n/app_localizations.dart. Hand-add getters into the existing numbered sections.
3. Swap "TODO(midnight): l10n-queued" call sites ONLY in dirs no lane holds this wave: lib/features/{settings,notification_prefs,password_security,language,location,wallet,jeeber_onboarding,jeeber_onboarding_funding,offer_kyc_gate,kyc_rejected,account_status,escalate,no_offer_timeout,cancellation,order_summary,customer_profile,notifications,rating,delivery_man_profile}. Do NOT touch support, reviews, dispute_status, profile_name, auth, biometric_auth, jeeber_pending_offers, jeeber_request_detail, request_summary, deep_link_targets, chat, voice_request or lib/core. If a row points there, apply the KEY, leave the call site, report it.
4. Close any feature-local l10n stopgap whose keys all landed byte-identical. Any mismatch → keep it, say why.
5. Delete ONLY the queue files you processed.
STANDING RULINGS: value changes in scope. Key marked "replaced" → grep after swapping; zero refs → delete from both ARBs; any left → KEEP and report. Never leave a dangling reference. A queue file naming a test that pins a literal via find.text → YOU own that test file. **Sentence case is the DS rule.**
VERIFY: flutter analyze --no-pub lib/l10n + the dirs you swapped → 0 errors · flutter test test/l10n + those suites → green (before/after).
RETURN: files processed · keys applied/deleted with grep evidence · call sites swapped · stopgaps closed · finders updated · AR flags · counts · questions.`

phase('Screens')
const results = await parallel([
  ...LANES.map((l) => () => agent(`${l.prompt}\n${COMMON}\nYour capture/report item id: ${l.item}.`, { label: l.label, phase: 'Screens', model: 'opus' })),
  () => agent(L10N, { label: 'l10n-merge', phase: 'Screens', model: 'opus' }),
])

return Object.fromEntries([...LANES.map((l, i) => [l.item, results[i]]), ['l10n', results[10]]])
