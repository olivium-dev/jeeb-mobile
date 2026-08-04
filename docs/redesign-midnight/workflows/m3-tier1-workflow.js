export const meta = {
  name: 'midnight-m3-tier1',
  description: 'M3 Tier 1 — 10 tile-less screens system-derived from the nearest tile pattern, + wave-D l10n merge',
  phases: [{ title: 'Screens', detail: '10 screens (router owned by deep_link_targets) + l10n merge lane' }],
}

const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const TILES = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/export-rich-ui/screens'

const COMMON = `
You are restyling ONE screen of the Jeeb MIDNIGHT redesign in ${REPO}, branch feat/redesign-midnight (verify with \`git status -sb\`; NEVER run git commit/checkout/stash/branch — leave changes in the working tree).
GOLDEN RULE (user mandate): code comments max 2 lines, only when super necessary.

**THIS IS AN M3 ROW — YOUR SCREEN HAS NO TILE.** The board never drew it. You do NOT invent design; you derive it. STEP 0 is therefore different from M2:
1. Read docs/redesign-midnight/01-TOKEN-SHEET.md and 02-STUDY-NOTES.md **in full**. Every ruling binds you. These two files ARE your spec.
2. Identify the NEAREST TILE PATTERN for your screen and read that tile PNG (paths under ${TILES}). State explicitly in your report: which tile you chose, why, and which of its patterns you are carrying over (field variant + glow/wash placement, surface rungs, ink hierarchy, CTA treatment, row/list rung, empty-state variant).
3. List 6+ concrete decisions you derived, each traced to a token-sheet value or a study-notes ruling — not to taste. If you cannot trace a decision, it is an ambiguity: STOP and return the question rather than inventing.
4. Confirm your files are reachable from lib/main.dart (docs/redesign-2026-08/screen-repo-map.md wins over any other map).

**MOTION: M3 screens get NO motion beyond what the kit already animates.** 20 of the board's 30 tiles are completely still; a screen the board never drew does not earn novelty motion. The only animation on your screen should be whatever JeebEmptyState/kit widgets bring with them.

FIELD: pick the variant your nearest tile uses. Available anchors — JeebFieldGlowPlacement{topEnd, centerUpper, bottom, topStart} and JeebFieldWashPlacement{startMid, bottomEnd, topStart, endMid}. A wash is PERIWINKLE and a glow is ORANGE; they are different layers and several screens shipped mirrored because that was missed. Use \`animateDecor: false\` unless you can name a reason not to.

CONSTRAINTS:
- Tokens/kit only; ZERO raw hex, ZERO Colors.* (transparent ok). Do NOT modify lib/core/** — it is FROZEN; return the question instead.
- ALL states restyled: default, loading, empty, error. Empty family = JeebEmptyState (variants: e1, radar, street, parcel, pocket, balcony, beacon — pick the nearest subject and say why).
- Preserve frozen test identifiers by re-homing them onto a real element or a zero-size semantics node; then delete chrome that existed only to host them.
- NEW l10n keys: do NOT edit lib/l10n/*.arb (a dedicated lane owns it) — write keys + EN/AR to docs/redesign-midnight/l10n-queue/<your-item>.md and use the nearest existing key with TODO(midnight): l10n-queued.
- Missing wire data → render the designed slot + TODO(midnight): omitted, not faked. NEVER fabricate a value.
- RTL-safe (EdgeInsetsDirectional / start-end). Respect MediaQuery.disableAnimations. Any harness mounting ShellScreen must set disableAnimations — there is a guard test that will catch you.
- Do NOT touch lib/core/router/app_router.dart unless you own it (stated below). Do NOT touch other lanes' feature dirs.

**STANDING RULE — goldens are evidence, NOT gates.** The comparator tolerates 5% pixel diff, so a token re-point on a small element passes a golden unchanged (a real stepper-ink swap moved 0.097% and three goldens stayed green carrying the wrong colour). Land a per-element assertion that reads the actual colour/geometry off the widget, and PROVE it discriminates by reverting the value and confirming red. Never cite a green golden as proof.

Analyze baseline: 0 errors / 30 known infos. Your bar: 0 errors, no NEW warnings.
KNOWN-RED and NOT yours (all verified pre-existing at fc93ace9 — do not chase, do not count as your regression): test/features/chat/chat_header_contrast_test.dart (5) · test/language_settings_screen_test.dart (2) · test/dio_tier_repository_test.dart (2) · test/core/diagnostics/gesture_log_test.dart (1) · 14 files under test/previews/ · 2 in test/tools/catalog_capture_test.dart.
CONCURRENCY: an l10n lane owns lib/l10n and edits getters mid-wave. If analyze or a test reports an error inside lib/l10n or a missing AppLocalizations getter you did not introduce, re-run ONCE; report only if it reproduces.

AFTER IMPLEMENTING — selfCritique: re-read your nearest tile and list 4+ specific deltas between it and your result, fix what you can, report the rest honestly.
VERIFY: flutter analyze --no-pub <your dirs> → 0 errors · targeted tests (report before/after counts) · git diff --stat (primary file MUST be non-zero) · re-capture your screen's catalog states: flutter test test/tools/catalog_capture_test.dart --update-goldens --plain-name "<filter>" --tags capture, then copy PNGs to docs/redesign-midnight/captures/<your-item>/.
RETURN raw data: nearest tile + why · 6+ derived decisions with their traces · files+diffstat · changes per file · selfCritique deltas · test results · discrimination proof · l10n queued · TODOs · open questions.`

const SCREENS = [
  { item: 'M3-01', label: 'delivery detail', dirs: 'lib/features/deep_link_targets', extra: `YOUR ITEM: M3-01 \`lib/features/deep_link_targets/delivery_detail_screen.dart\` (707 LOC, route /orders/:id).
YOU OWN lib/core/router/app_router.dart THIS WAVE (no other lane may touch it).
**ASSIGNED CARRY-IN from M2-11:** \`delivery_detail_screen.dart:489\` calls a local \`_mutualRateLocation(context)\` that passes NO counterpart name. app_router.dart exports \`mutualRatingLocation(deliveryId, {required isClient, String? counterpartName})\`. Route through it and pass the real name IF the delivery-detail state actually holds one — audit that first and report what you found. If the name is not in scope, pass null (the helper drops the param) and say so; NEVER fabricate a name.
Nearest tile: this is the client's order-detail surface — R3 live tracking and R21 order history are the closest patterns.` },
  { item: 'M3-02', label: 'escalate', dirs: 'lib/features/escalate', extra: `YOUR ITEM: M3-02 \`lib/features/escalate/presentation/escalate_screen.dart\` (763 LOC).
A dispute/escalation funnel. Nearest patterns: R13 handover (glass rows + a docked action) for structure, and the danger ink roles from the token sheet §2 for destructive affordances. Destructive text uses \`onErrorContainer\` (#FF7B7B), not \`error\` — the R22 ruling.` },
  { item: 'M3-03', label: 'no offer timeout', dirs: 'lib/features/no_offer_timeout', extra: `YOUR ITEM: M3-03 \`lib/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart\` (685 LOC).
This is a WAITING/FAILURE surface — its nearest tile is **E2 (waiting for offers)**, and \`JeebEmptyStateVariant.radar\` exists precisely for that subject. Consider it seriously before anything else. Tile: ${TILES}/28-e2-empty-waiting-for-offers.png.` },
  { item: 'M3-04', label: 'cancellation', dirs: 'lib/features/cancellation', extra: `YOUR ITEM: M3-04 \`lib/features/cancellation/presentation/cancellation_screen.dart\` (339 LOC).
A destructive confirm flow. Destructive ink = \`onErrorContainer\`; the primary action is NOT orange unless it is genuinely the affirmative CTA — "when in doubt: not orange" (theme ruling 3).` },
  { item: 'M3-05', label: 'order summary', dirs: 'lib/features/order_summary', extra: `YOUR ITEM: M3-05 \`lib/features/order_summary/presentation/order_summary_screen.dart\` (354 LOC).
Nearest tile: R12 request summary (already Midnight, M2-06) — read \`lib/features/request_summary/\` for the shipped pattern and carry it over rather than re-deriving. Money emphasis = price 22/w800.` },
  { item: 'M3-06', label: 'jeeber request detail', dirs: 'lib/features/jeeber_request_detail', extra: `YOUR ITEM: M3-06 \`lib/features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart\` (196 LOC).
The jeeber's view of a request. Nearest patterns: R16 jeeber home's feed card and R17 offer composer. Tile refs: ${TILES}/16-r16-jeeber-home.png, ${TILES}/17-r17-offer-composer.png.` },
  { item: 'M3-07', label: 'customer profile', dirs: 'lib/features/customer_profile', extra: `YOUR ITEM: M3-07 \`lib/features/customer_profile/presentation/customer_profile_screen.dart\` (257 LOC).
NOTE: this screen owns one of the 2 known-red catalog captures — \`customer-profile__…__0-client-verified-rated\` throws MissingPluginException(getTemporaryDirectory) from flutter_cache_manager behind a network avatar fixture, AFTER the render (the PNG still lands). If you can make the fixture not reach the network, that red closes; if not, leave it and say why. Do not fake it green.
Nearest patterns: R15 mutual rating's identity block, R22 settings' identity card.` },
  { item: 'M3-08', label: 'notifications list', dirs: 'lib/features/notifications', extra: `YOUR ITEM: M3-08 \`lib/features/notifications/presentation/notifications_list_screen.dart\` (362 LOC).
A list surface. Nearest tile: R21 order history (rows, status chips, the expired/read dimming question). NOTE Q-006 is still open on R21's dimming — do NOT invent a read/unread dim value; use the shipped R21 treatment and flag it as inheriting that open question. Empty state: pick the nearest JeebEmptyState variant and justify.` },
  { item: 'M3-09', label: 'rating screen', dirs: 'lib/features/rating', extra: `YOUR ITEM: M3-09 \`lib/features/rating/presentation/rating_screen.dart\` (340 LOC). This is the SINGLE-SIDED rating screen, distinct from \`mutual_rating_screen.dart\` which is already Midnight (M2-11) and which you must NOT re-open.
Read mutual_rating_screen.dart first and carry its shipped treatment across: amber stars with the radial-gradient halo (a BoxShadow halo paints nothing on the golden canvas), \`JeebAvatarFill.glass\`, chip rhythm. Stars do NOT twinkle — board-absent, explicitly banned.` },
  { item: 'M3-10', label: 'delivery man profile', dirs: 'lib/features/delivery_man_profile', extra: `YOUR ITEM: M3-10 \`lib/features/delivery_man_profile/presentation/delivery_man_profile_screen.dart\` (149 LOC) — the smallest row this wave.
Nearest patterns: R15's identity block and R16's rating pill. If this screen duplicates something \`customer_profile_screen.dart\` also draws, say so — a shared kit-level treatment may be the right M4/M6 follow-up.` },
]

const L10N = `You are the l10n merge lane for MIDNIGHT M3 Tier 1 in ${REPO}, branch feat/redesign-midnight (NEVER run git mutations). GOLDEN RULE: comments max 2 lines, only when super necessary.
YOU OWN lib/l10n/*.arb. Work:
1. Process EXACTLY these five queue files and NO others: docs/redesign-midnight/l10n-queue/M2-19-r22.md, M2-20-r23.md, M2-21-r5-w123.md, M2-22-23-r6-r7.md, M2-24-r8.md. (Ten screen lanes are running concurrently and WILL create new files in that directory — those are next-wave work. NEVER glob the directory.)
2. This repo has NO \`flutter gen-l10n\` (no l10n.yaml, no generate: true) — the ARBs are pubspec assets parsed at runtime by the hand-authored lib/l10n/app_localizations.dart. Hand-add getters into the existing numbered sections, as the last three merge lanes did.
3. Swap every "TODO(midnight): l10n-queued" call site in the wave-D feature dirs: lib/features/{settings,kyc,onboarding,registration,transcription} and lib/features/auth/social. Do NOT touch any M3 Tier-1 dir (deep_link_targets, escalate, no_offer_timeout, cancellation, order_summary, jeeber_request_detail, customer_profile, notifications, rating, delivery_man_profile) — lanes are working there. If a queue row points at one, apply the KEY but leave the call site and report it.
4. If a queue file records that a feature-local l10n stopgap can now close (as otp_handover and live_tracking did), verify every key landed byte-identical, then delete it. Any mismatch → keep it and say why.
5. Delete ONLY the five queue files you processed.
STANDING RULINGS: value changes are in scope (change the value, keep the key id). For a key marked "replaced": after swapping, grep for remaining references — zero → delete from both ARBs; any left → KEEP and report where. Never leave a dangling reference. If a queue file names a test that pins a literal via find.text, YOU own that test file — update the finder in the same pass.
**Sentence case is the DS rule** — a previous merge correctly changed "At Door" to "At door" and two tests pinned the old literal. Expect that class and fix the pins.
VERIFY: flutter analyze --no-pub lib/l10n lib/features/{settings,kyc,onboarding,registration,transcription} → 0 errors · flutter test test/l10n + the targeted suites for those dirs → green (report before/after).
RETURN: keys applied per file · keys deleted with grep evidence · call sites swapped · stopgaps closed · test finders updated · AR strings flagged · before/after counts · questions.`

phase('Screens')
const results = await parallel([
  ...SCREENS.map((s) => () => agent(
    `${s.extra}\nYour dirs: ${s.dirs} (+ its tests).\n${COMMON}\nYour capture/report item id: ${s.item}.`,
    { label: s.label, phase: 'Screens', model: 'opus' },
  )),
  () => agent(L10N, { label: 'l10n-merge', phase: 'Screens', model: 'opus' }),
])

return Object.fromEntries([...SCREENS.map((s, i) => [s.item, results[i]]), ['l10n-merge', results[10]]])
