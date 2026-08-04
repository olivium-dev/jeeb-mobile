export const meta = {
  name: 'midnight-m3-tier4',
  description: 'M3 Tier 4 — the settings subtree (7 rows across 5 disjoint dirs) + l10n merge',
  phases: [{ title: 'Screens', detail: 'settings×3 · notification_prefs · password_security · language · location×2 · l10n' }],
}

const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const TILES = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/export-rich-ui/screens'

const COMMON = `
You are restyling MIDNIGHT rows in ${REPO}, branch feat/redesign-midnight (verify with \`git status -sb\`; NEVER run git commit/checkout/stash/branch).
GOLDEN RULE (user mandate): code comments max 2 lines, only when super necessary.

**M3 ROWS HAVE NO TILE — you derive, you do not invent.** STEP 0:
1. Read docs/redesign-midnight/01-TOKEN-SHEET.md and 02-STUDY-NOTES.md in full — they ARE your spec.
2. Name your NEAREST TILE PATTERN, read that tile PNG (under ${TILES}), state what you carry over.
3. List 6+ derived decisions, each traced to a token value or a standing ruling. Untraceable = STOP and return the question.
4. Confirm reachability from lib/main.dart.

**Your whole tier's nearest tile is R22 settings** (${TILES}/22-r22-settings.png), which is ALREADY Midnight (M2-19). **Read \`lib/features/settings/presentation/screens/settings_screen.dart\` and its widgets FIRST and carry the shipped treatment across** — do not re-derive what is already ratified. Its established facts: content field at \`topEnd\`, "stacked glass" is a FILL step not a shadow (identity 9%/18% over rows 7%/14%, no box-shadow anywhere), navigation rows on the kit's 11/14 rung, destructive text on \`onErrorContainer\` #FF7B7B (never \`error\`), and the board's own toggle geometry (46×26 track, Ø20 knob) because OMDS's switch row only forwards \`activeColor\` — the thumb — leaving the orange track unreachable.

**KNOWN DEFECT SIGNATURE — grep your files for it:** any pass-1 code or comment treating \`colorScheme.primary\` as cool/navy is now FALSE; under Midnight \`primary\` IS \`#D73B00\`. It has been found on 8 screens so far, including a ledger rendering three orange elements per row. \`colorScheme.primary\` on a non-CTA is an orange-budget leak. Report every instance you fix.

MOTION: none beyond what kit widgets animate. \`animateDecor: false\` unless you name a reason.
FIELD anchors: JeebFieldGlowPlacement{topEnd, centerUpper, bottom, topStart} · JeebFieldWashPlacement{startMid, bottomEnd, topStart, endMid}. A wash is PERIWINKLE, a glow is ORANGE — different layers.
CTA: \`JeebCtaVariant.danger\` now exists (Q-041) for destructive actions — use it where the act is destructive rather than leaving a terminal action reading like a neutral one.

CONSTRAINTS:
- Tokens/kit only; ZERO raw hex, ZERO Colors.* (transparent ok). Do NOT modify lib/core/** — FROZEN; return the question.
- ALL states: default, loading, empty, error. Empty family = JeebEmptyState (e1, radar, street, parcel, pocket, balcony, beacon). **KIT FACT: \`_pocketLayers()\` IGNORES the \`center\` slot and hard-draws a solid orange mic** — a previous lane shipped a bright orange mic on a read-only wallet before catching it. Only \`_e1Layers()\` honours \`center\`.
- Preserve frozen test identifiers by re-homing; delete chrome that existed only to host them.
- NEW l10n keys → docs/redesign-midnight/l10n-queue/<item>.md + nearest existing key with TODO(midnight): l10n-queued. Do NOT edit lib/l10n/*.arb.
- Missing wire data → designed slot + TODO(midnight): omitted, not faked. NEVER fabricate.
- RTL-safe. Respect MediaQuery.disableAnimations; a guard test enforces it for ShellScreen harnesses.

**STANDING RULE — goldens are evidence, NOT gates** (5% tolerance; a real ink swap moved 0.097% and three goldens stayed green carrying the wrong colour). Land per-element assertions read off the widget and PROVE each discriminates by reverting and confirming red.

Analyze baseline: 0 errors / 30 known infos. KNOWN-RED and NOT yours unless your row names it: chat_header_contrast (5) · dio_tier_repository (2) · gesture_log (1) · 14 files under test/previews/ · 2 in catalog_capture_test.
CONCURRENCY: an l10n lane owns lib/l10n. Error inside lib/l10n or a missing getter you did not introduce → re-run ONCE, report only if it reproduces.

AFTER IMPLEMENTING — selfCritique: 4+ specific deltas vs R22, fix what you can, report the rest.
VERIFY: flutter analyze --no-pub <your dirs> → 0 errors · targeted tests (before/after) · non-zero diff on primary files · re-capture states (--update-goldens --plain-name "<filter>" --tags capture) into docs/redesign-midnight/captures/<item>/.
RETURN: nearest tile + why · 6+ traced decisions · files+per-row diffstat · changes per file · selfCritique · test results · discrimination proof · primary-leaks fixed · l10n queued · questions.`

const LANES = [
  {
    label: 'settings subtree', item: 'M3-23,25,37',
    prompt: `YOUR ITEM: THREE checklist rows, one lane because they share \`lib/features/settings/presentation/screens/\`:
  **M3-23** profile_edit_screen.dart (293) — ORPHAN ruling is **KEEP+restyle** (live row in SettingsScreen; 9 widget tests incl. a regression guard).
  **M3-25** notification_preferences_screen.dart (31) — a thin screen; check whether it merely delegates before restyling it.
  **M3-37** live_settings_screen.dart (228) — ORPHAN ruling is **KEEP+restyle, loading/error chrome ONLY**. It delegates to SettingsScreen (which is already Midnight) and is the SOLE LIVE MOUNT of it, plus the destination of 5 back-fallbacks. Do NOT restyle the delegated body twice.
Report each row's diffstat separately so each checklist row ticks on its own evidence.`,
  },
  {
    label: 'notification prefs', item: 'M3-24',
    prompt: `YOUR ITEM: M3-24 \`lib/features/notification_prefs/presentation/notification_prefs_screen.dart\` (324).
This is the real notification-preferences surface (distinct from M3-25's thin screen in the settings dir). R22's notification card is the direct precedent — it uses the board's own toggle geometry because OMDS's switch row cannot reach the orange track. **Carry that toggle treatment across rather than re-deriving it**, and check whether this screen has the same periwinkle-track defect R22 had.`,
  },
  {
    label: 'password security', item: 'M3-26',
    prompt: `YOUR ITEM: M3-26 \`lib/features/password_security/presentation/password_security_screen.dart\` (317).
⛔ **CAUTION:** the email/password funnel was REMOVED in JEBV4-199 (Q-044 ratified) — auth is phone-OTP + social only. Before restyling, establish whether this screen is still reachable from a live path. If it is dead code behind the removed funnel, STOP and report it as an ORPHAN candidate with your evidence rather than restyling a screen nobody can open. If it IS live (e.g. it manages biometrics or a PIN rather than an email password), restyle it and say what it actually manages.`,
  },
  {
    label: 'language settings', item: 'M3-27',
    prompt: `YOUR ITEM: M3-27 \`lib/features/language/presentation/screens/language_settings_screen.dart\` (130).
**THIS ROW OWNS TWO OF OUR KNOWN-RED TESTS.** \`test/language_settings_screen_test.dart\` has 2 failures that pin a PRE-MIDNIGHT purple segment ink (\`Color(0.4039, 0.3137, 0.6431)\` ≈ rgb(103,80,164)) and receive white. White is CORRECT — it is the ratified Midnight segmented-active treatment (kit ruling 3: active = white fill / navy ink). **The test is stale, the code is right.** Re-pin those assertions to the Midnight treatment as part of this row, and confirm the suite goes green. You own that test file.
Nearest pattern: R22's language track + the segmented toggle. The board's Arabic segment carries the brand Arabic face at 14/w700.`,
  },
  {
    label: 'location subtree', item: 'M3-28,29',
    prompt: `YOUR ITEM: TWO rows sharing \`lib/features/location/\`:
  **M3-28** saved_locations_screen.dart (593) — **doc-13 P0-9: this screen CRASHES. Triage it with the exception visible** and report the root cause. Fix it if the fix is in your dir and is clearly correct; if it is not, report the exception and stack precisely rather than papering over it with a try/catch.
  **M3-29** address_detail_form_screen.dart (493) — note its "Edit pin" calls \`GoogleMapPickerLauncher.pickOnMap()\`, which is the subject of open **Q-021**: a Confirm tap landing before the first \`onCameraIdle\` silently returns null, so the chosen coordinate is discarded. Do NOT try to fix Q-021 (it needs a product ruling) — but if your restyle can surface the failure to the user instead of silently discarding, say so as a proposal.
R11 location picker (already Midnight, M2-05) is your nearest pattern for map surfaces; R22 for the list rows.
Report each row's diffstat separately.`,
  },
]

const L10N = `You are the l10n merge lane for MIDNIGHT M3 Tier 4 in ${REPO}, branch feat/redesign-midnight (NEVER run git mutations). GOLDEN RULE: comments max 2 lines, only when super necessary.
YOU OWN lib/l10n/*.arb. Work:
1. LIST the queue files in docs/redesign-midnight/l10n-queue/ at the moment you start, then process ONLY that fixed list. (Five screen lanes are running concurrently and WILL add files — those are next-wave work. NEVER re-glob after fixing your list.)
2. No \`flutter gen-l10n\` here — ARBs are pubspec assets parsed at runtime by the hand-authored lib/l10n/app_localizations.dart. Hand-add getters into the existing numbered sections.
3. Swap "TODO(midnight): l10n-queued" call sites ONLY in dirs no lane is holding this wave: lib/features/{wallet,jeeber_onboarding,jeeber_onboarding_funding,offer_kyc_gate,kyc_rejected,account_status,deep_link_targets,escalate,no_offer_timeout,cancellation,order_summary,jeeber_request_detail,customer_profile,notifications,rating,delivery_man_profile}. Do NOT touch settings, notification_prefs, password_security, language or location. If a row points there, apply the KEY, leave the call site, report it.
4. Close any feature-local l10n stopgap whose keys all landed byte-identical. Any mismatch → keep it and say why.
5. Delete ONLY the queue files you processed.
STANDING RULINGS: value changes in scope (change value, keep key id). Key marked "replaced" → grep after swapping; zero refs → delete from both ARBs; any left → KEEP and report. Never leave a dangling reference. A queue file naming a test that pins a literal via find.text → YOU own that test file. **Sentence case is the DS rule** — expect stale Title Case pins.
VERIFY: flutter analyze --no-pub lib/l10n + the dirs you swapped → 0 errors · flutter test test/l10n + those suites → green (before/after).
RETURN: files processed · keys applied/deleted with grep evidence · call sites swapped · stopgaps closed · finders updated · AR flags · counts · questions.`

phase('Screens')
const results = await parallel([
  ...LANES.map((l) => () => agent(`${l.prompt}\n${COMMON}\nYour capture/report item id: ${l.item}.`, { label: l.label, phase: 'Screens', model: 'opus' })),
  () => agent(L10N, { label: 'l10n-merge', phase: 'Screens', model: 'opus' }),
])

return Object.fromEntries([...LANES.map((l, i) => [l.item, results[i]]), ['l10n', results[5]]])
