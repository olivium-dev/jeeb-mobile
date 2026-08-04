export const meta = {
  name: 'midnight-m4-states',
  description: 'M4 — app-wide empty/loading/error sweep: inventory first, then restyle every state the inventory finds',
  phases: [
    { title: 'Inventory+Kit', detail: 'app-wide state inventory · _skeleton() per-variant · sqflite harness gap' },
    { title: 'Sweep', detail: 'restyle lanes fanned out over the inventory' },
  ],
}

const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const TILES = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/export-rich-ui/screens'

const INVENTORY = `You are the M4 STATE INVENTORY lane for the Jeeb MIDNIGHT redesign in ${REPO}, branch feat/redesign-midnight.
**You write NO production code this run.** Your entire deliverable is an accurate, evidence-backed inventory. NEVER run git commit/checkout/stash/branch.

M2 and M3 are complete — all 70 mapped + remainder screens carry the Midnight design language. M4's job (master plan §4) is: *"Enumerate EVERY empty/loading/error surface app-wide … each gets the §2.7 pattern (E1-sample variants for variety); kill any remaining light-theme state,"* **including states the catalog harness cannot reach.**

METHOD — use several independent search angles, because one grep will not find them all:
1. Widget-name angle: \`OmdsEmptyState\`, \`OmdsEmptyStatePage\`, \`OmdsErrorState\`, \`OmdsLoadingState\`, \`OmdsListItemShimmer\`, \`EmptyView\`, \`ErrorView\`, \`CircularProgressIndicator\`, \`LinearProgressIndicator\`, \`Shimmer\`, \`Placeholder\`.
2. Branch angle: \`when(\` / \`switch\` on a state enum with loading/empty/error/failure arms; \`if (state.isLoading)\`; \`AsyncSnapshot\` branches; \`FutureBuilder\`/\`StreamBuilder\` \`hasError\`.
3. Light-theme-residue angle: \`Colors.grey\`, \`Colors.white\`, \`Colors.black\`, \`shade[0-9]00\`, \`Theme.of(context).textTheme\`, \`colorScheme.background\` — any of these inside a state branch is a surviving light-theme state.
4. Kit angle: which states already route through \`JeebEmptyState\` and are therefore DONE — list them so the sweep does not redo them.
5. Coverage angle: for each state found, does a catalog entry render it? A state with no catalog state is invisible to every capture — flag those, they are the ones §4 says get missed.

For EVERY state you find, record: file:line · owning feature dir · which of {loading, empty, error} it is · what it renders TODAY (kit widget? OMDS? bare Material? light-theme colours?) · whether a catalog state reaches it · and a one-line verdict: **DONE** (already JeebEmptyState) / **RESTYLE** / **DELETE** (dead branch) / **QUESTION**.

Then GROUP the RESTYLE items by top-level feature directory and output that grouping explicitly, with a count per dir — the next phase fans out one lane per group, so the grouping IS the work-plan. Call out any group that is unusually large or that spans \`lib/core\` (frozen).

Be honest about limits: if a search angle returned nothing, say so rather than implying coverage. If you suspect states exist that none of your angles would find (e.g. built inside a package, or behind a feature flag), say that too.
RETURN: the full inventory table · the per-dir grouping with counts · DONE/DELETE/QUESTION lists · which angles found what · what you could not see.`

const KIT_SKELETON = `You are the kit lane for MIDNIGHT M4 in ${REPO}, branch feat/redesign-midnight. NEVER run git commit/checkout/stash/branch. GOLDEN RULE: comments max 2 lines, only when super necessary.
YOU OWN lib/core/widgets/jeeb/jeeb_empty_state.dart and test/core/widgets/jeeb/jeeb_empty_state_test.dart. Nothing else.

**Close the deferred \`_skeleton()\` gap.** \`_Illustration.build\` hard-codes \`skeleton ? _e1ViewBox : _viewBoxFor(variant)\`, and \`_skeleton()\` paints E1's 300×280 dotted ring with a Ø94 core and **four** glass discs — **for every variant**. Consequences already observed and reported by lanes: E2's radar loads a 4-disc E1 skeleton that then morphs into a 3-disc radar; the wallet's e1-composed empty loads the wrong shape; the support screen's submitting state draws E1's rings.

Make the loading skeleton follow its variant's own geometry — viewBox, disc/medallion count and centre size — for all seven variants (e1, radar, street, parcel, pocket, balcony, beacon). The skeleton must stay a *skeleton*: it breathes (\`jBreathe\`) and carries no colour identity beyond the glass rungs; it is not the lit illustration. Where a variant has no medallions (radar has 3 letter discs, street and parcel have none), the skeleton must not invent four.

**KNOWN KIT FACT you may also fix if it is in this file and cheap:** \`_pocketLayers()\` IGNORES the \`center\` slot and hard-draws a solid orange mic — a lane shipped a bright orange mic on a read-only wallet before catching it in its own capture. Only \`_e1Layers()\` honours \`center\`. If honouring \`center\` in the other variants is a safe additive change, do it and say so; if it would change shipped screens' appearance, do NOT and report which screens would move.

Additive only — existing callers must not move. PROVE each new assertion discriminates: revert the value, confirm red, restore.
VERIFY: flutter analyze --no-pub lib/core → 0 errors · flutter test test/core/widgets/jeeb test/core/theme → all green · then run the CONSUMERS rather than reasoning about them: flutter test test/features/client_offers test/features/jeeber_home test/features/wallet test/features/support test/features/order_history.
RETURN: what changed · exact behaviour per variant before/after · whether center is now honoured and for which variants · before/after counts · discrimination proof · anything you could not close.`

const HARNESS = `You are the capture-harness lane for MIDNIGHT M4 in ${REPO}, branch feat/redesign-midnight. NEVER run git commit/checkout/stash/branch. GOLDEN RULE: comments max 2 lines, only when super necessary.
YOU OWN test/tools/catalog_capture_test.dart, test/support/**, and pubspec.yaml dev_dependencies ONLY.

**Close the last capture red: 329/330.** \`delivery-receipt__deliveryreceiptscreen__0-loaded-proof-photo-cash-on-delivery-amount\` seeds a network proof photo (its whole purpose — nulling it would gut the state). The harness already stubs \`plugins.flutter.io/path_provider\`, which fixed the avatar states. Past that, \`flutter_cache_manager\` hits **sqflite** and throws \`Bad state: databaseFactory not initialized\`. A MethodChannel mock CANNOT satisfy this — \`sqflite_common\` checks the factory before any channel call. I verified that dead end myself; do not repeat it.

The likely fix is \`sqflite_common_ffi\` as a **dev_dependency** with \`databaseFactory = databaseFactoryFfi\` in the harness setUp. Evaluate it properly before adding a dependency:
- Does it work under \`flutter test\` on this Flutter version without a native build step? Try it.
- Is there a lighter option — e.g. injecting a no-op/in-memory cache manager into \`OmdsCachedImage\` for tests, or a test-only image provider override? A dependency-free fix is better than a new dev_dependency if it is not more invasive.
- **lottie must stay pinned EXACTLY 3.3.1** (a caret resolves to 3.5.1 and breaks CI at Flutter 3.38.9). If your change perturbs the lockfile beyond your own package, STOP and report.
If no fix is safe, say so plainly and leave the red documented — that is an acceptable outcome. Do NOT make the capture pass by weakening the state or deleting the entry.

Also, while you are in the harness: several lanes hit the same friction — a harness mounting an ∞-looping Midnight surface needs \`MediaQuery(disableAnimations: true)\`, and any tree mounting Home also needs a \`pump()\` past a fake-latency timer. If a shared \`test/support/\` helper would make that one import instead of a copied 6-line block, propose it (and build it if it is clearly safe), so the next wave does not rediscover it.
VERIFY: flutter test test/tools/catalog_capture_test.dart --tags capture → report exact pass/fail before and after · flutter analyze --no-pub test → 0 errors · confirm \`grep -A1 "  lottie:" pubspec.lock\` still resolves 3.3.1.
RETURN: what you tried · what worked and what did not (including dead ends, so they are not retried) · dependency added or avoided and why · before/after capture counts · lottie pin confirmation.`

phase('Inventory+Kit')
const p1 = await parallel([
  () => agent(INVENTORY, { label: 'inventory', phase: 'Inventory+Kit', model: 'opus' }),
  () => agent(KIT_SKELETON, { label: 'kit:skeleton', phase: 'Inventory+Kit', model: 'opus' }),
  () => agent(HARNESS, { label: 'harness:sqflite', phase: 'Inventory+Kit', model: 'opus' }),
])

const inventory = p1[0] || '(inventory lane returned nothing)'
const kitReport = p1[1] || '(kit lane returned nothing)'

log('Inventory complete — fanning out the sweep over its grouping.')

const SWEEP_COMMON = `
You are a sweep lane for MIDNIGHT **M4 — the empty/loading/error state pass** in ${REPO}, branch feat/redesign-midnight (verify with \`git status -sb\`; NEVER run git commit/checkout/stash/branch).
GOLDEN RULE (user mandate): code comments max 2 lines, only when super necessary.

An inventory lane just swept the app for every loading/empty/error surface. **Its report is below — the items in YOUR directories are your work list.** Work only from items it marked RESTYLE in dirs you own; ignore DONE items, and report rather than act on DELETE/QUESTION items.

--- M4 STATE INVENTORY ---
${inventory}
--- END INVENTORY ---

--- KIT LANE REPORT (the loading skeleton now follows its variant) ---
${kitReport}
--- END ---

WHAT "RESTYLED" MEANS HERE (master plan §2.7): every state uses the JeebEmptyState family — **loading = the illustration skeleton breathing, error = the danger-tinted variant, empty = the lit illustration**. Pick the variant whose SUBJECT matches the screen (e1, radar, street, parcel, pocket, balcony, beacon) and say why. A waiting-on-someone-else state is \`radar\`; an order/parcel domain is \`parcel\`; a jeeber-side quiet state is \`street\`. Do not default everything to e1.
**Do not invent copy.** If a state has no string, queue an l10n key and use the nearest existing one with TODO(midnight): l10n-queued. Missing wire data → designed slot + TODO(midnight): omitted, not faked.

CONSTRAINTS:
- Tokens/kit only; ZERO raw hex, ZERO Colors.* (transparent ok). Do NOT modify lib/core/** — FROZEN (the kit lane owns jeeb_empty_state.dart this wave).
- Preserve frozen test identifiers by re-homing onto the kit's own \`identifier:\` slot, then delete the Padding/Column chrome that existed only to host them.
- **KNOWN DEFECT SIGNATURE — grep your dirs:** any pass-1 code or comment treating \`colorScheme.primary\` as cool/navy is FALSE; under Midnight \`primary\` IS \`#D73B00\`. Found on 8+ screens, one ledger drew three orange elements per row. Report every instance you fix.
- **Also grep for \`Theme.of(context).extension<…>()!\`** — a bang on that lookup throws under any theme lacking the extension and cost us 9 latent crashes. Use \`?? JeebSemanticColors.midnight()\`.
- RTL-safe. Respect MediaQuery.disableAnimations; a harness mounting ShellScreen must set it (a guard test enforces this).

**STANDING RULE — goldens are evidence, NOT gates** (5% tolerance; a real ink swap moved 0.097% and three goldens stayed green carrying the wrong colour). Land per-element assertions read off the widget and PROVE each discriminates by reverting.

**A state with no catalog entry is invisible to every capture.** If the inventory flags one of yours as uncaptured, ADD the catalog state — that is part of the row, not extra credit.

Analyze baseline: 0 errors / 30 known infos. KNOWN-RED and NOT yours: chat_header_contrast (5) · dio_tier_repository (2) · gesture_log (1) · 14 files under test/previews/ · 1 in catalog_capture_test.
VERIFY: flutter analyze --no-pub <your dirs> → 0 errors · targeted tests (before/after) · re-capture your states into docs/redesign-midnight/captures/M4/<dir>/.
RETURN: items handled from the inventory (file:line each) · variant chosen per state + why · what changed · primary-leaks and extension-bangs fixed · catalog states added · before/after counts · discrimination proof · l10n queued · anything left.`

phase('Sweep')
const GROUPS = [
  { label: 'sweep: client surfaces', dirs: 'lib/features/home_client, lib/features/client_offers, lib/features/request_type, lib/features/request_summary, lib/features/voice_request, lib/features/transcription' },
  { label: 'sweep: delivery + tracking', dirs: 'lib/features/live_tracking, lib/features/otp_handover, lib/features/delivery_receipt, lib/features/active_delivery_jeeber, lib/features/cancellation, lib/features/escalate, lib/features/dispute_status' },
  { label: 'sweep: jeeber surfaces', dirs: 'lib/features/jeeber_home, lib/features/jeeber_request_feed, lib/features/jeeber_request_detail, lib/features/jeeber_pending_offers, lib/features/offers, lib/features/jeeber_active_deliveries, lib/features/no_offer_timeout' },
  { label: 'sweep: money surfaces', dirs: 'lib/features/wallet, lib/features/earnings, lib/features/order_history, lib/features/order_summary' },
  { label: 'sweep: account + chrome', dirs: 'lib/features/settings, lib/features/notification_prefs, lib/features/notifications, lib/features/language, lib/features/password_security, lib/features/profile_name, lib/features/customer_profile, lib/features/delivery_man_profile, lib/features/reviews, lib/features/support, lib/features/shell' },
  { label: 'sweep: onboarding + kyc', dirs: 'lib/features/onboarding, lib/features/registration, lib/features/kyc, lib/features/kyc_rejected, lib/features/account_status, lib/features/jeeber_onboarding, lib/features/jeeber_onboarding_funding, lib/features/offer_kyc_gate, lib/features/biometric_auth, lib/features/auth, lib/features/location, lib/features/chat, lib/features/deep_link_targets, lib/features/rating' },
]

const p2 = await parallel(GROUPS.map((g) => () => agent(
  `YOUR DIRECTORIES: ${g.dirs}.\nHandle every RESTYLE item the inventory lists in those dirs. If the inventory found none in one of your dirs, say so explicitly rather than inventing work.\n${SWEEP_COMMON}`,
  { label: g.label, phase: 'Sweep', model: 'opus' },
)))

return { inventory: p1[0], kitSkeleton: p1[1], harness: p1[2], sweep: Object.fromEntries(GROUPS.map((g, i) => [g.label, p2[i]])) }
