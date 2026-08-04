# Wave 3 — verification gate

Branch `feat/redesign-24-migration`, verified 2026-08-03 against baseline `03c6c74` + 8 redesign
commits. Nothing was committed, pushed or branched.

## Verdict

**PASS.** Analyze is exactly at baseline. Tests are +46 with zero new failures. The frozen kit,
theme and pubspec are byte-unchanged. All 12 Tier-1 lanes have real diffs — no false `done`.

| Gate | Baseline | Now | Delta |
|---|---|---|---|
| `flutter analyze` | 8 issues / 0 errors / 0 warnings | **8 issues / 0 errors / 0 warnings** | 0 |
| `flutter test` | 4617 pass / 61 skip / 1 fail | **4663 pass / 61 skip / 1 fail** | **+46 pass, 0 new failures** |
| `test/core/widgets/jeeb/` (frozen kit) | 476 | **476 / 476 pass** | 0 |
| `test/decision_violations_test.dart` | pass | **pass** | — |
| `test/qa_keys_batch_test.dart` | pass | **pass** | — |
| `tool/check_design_tokens.sh` | — | **1 violation, pre-existing** | 0 new |

The 8 analyze issues are the same 8 `containsSemantics` deprecation infos in test files
(local Flutter 3.44.2 vs CI 3.38.9). Not fixed, per the baseline note — `isSemantics` does not exist
in 3.38.9 and would be a CI compile error.

The 1 test failure is `test/core/diagnostics/gesture_log_test.dart` — the known pre-existing
local-SDK skew, green in CI. **It is the only failure, and it is the same one.**

## Frozen-surface audit

`git diff --stat -- pubspec.yaml lib/core/theme lib/core/widgets/jeeb` → **empty**.

- `lottie: 3.3.1` still pinned exactly (pubspec line 71). Nobody loosened it to `^3.3.1`.
- No lane edited the frozen kit; the 476 kit tests pass unchanged.
- Dead/orphan files confirmed untouched (`git status` reports nothing for any of them):
  `tier_selection_screen.dart`, `live_settings_screen.dart`, both `location_picker_screen.dart`.

Integrator-owned shared files:

| File | Change |
|---|---|
| `lib/core/router/app_router.dart` | **unchanged** — no lane needed a route |
| `lib/injection_container.dart` | **unchanged** — no lane needed DI |
| `lib/l10n/app_en.arb` | +7 (one key, mine) |
| `lib/l10n/app_ar.arb` | +1 (one key, mine) |
| `lib/l10n/app_localizations.dart` | +2 (one accessor, mine) |

ARB parity gate: **1736 EN keys / 1736 AR keys, zero one-sided keys**, both files valid JSON.

## Semantics identifier audit (hard constraint 1)

Machine-diffed every `identifier:` literal in `lib/` at HEAD vs the working tree:
**628 → 673**. Zero identifiers lost.

Two looked lost and are **false positives**, verified by reading both revisions:
`request_feed_accept_$requestId` → `request_feed_accept_${request.id}` and the decline twin, in
`jeeber_request_feed/presentation/request_card.dart`. HEAD passed `requestId: request.id` into the
child; the redesign passes the whole `DeliveryRequest`. The interpolated **runtime string is
identical**, and the matching `Key('requestFeed.card.accept.…')` changed the same way. Maestro is
unaffected.

The 47 new identifiers all follow the required `<screen>_<element>` shape. 24 of them are the
in-body `JeebTopBar` back circles that replaced `OMDSAppBar` (which exposed no identifier at all) —
that is a net accessibility gain, not drift.

## Per-lane diff sizes — no false `done` reports

Tier-1 re-skins, `git diff --shortstat HEAD -- <dir>`:

| Lane | Directory | Diff |
|---|---|---|
| w3-delivery-detail | `lib/features/deep_link_targets` | 1 file, +141 / −131 |
| w3-escalate | `lib/features/escalate` | 1 file, +274 / −246 |
| w3-no-offer-timeout | `lib/features/no_offer_timeout` | 1 file, +232 / −114 |
| w3-cancellation | `lib/features/cancellation` | 3 files, +196 / −84 |
| w3-customer-profile | `lib/features/customer_profile` | 8 files, +191 / −295 (+1 new) |
| w3-notifications | `lib/features/notifications` | 2 files, +211 / −166 |
| w3-order-summary | `lib/features/order_summary` | 2 files, +357 / −263 |
| w3-jeeber-request-detail | `lib/features/jeeber_request_detail` | 3 files, +134 / −171 |
| w3-kyc-status | `lib/features/kyc` | 2 files, +224 / −255 (+1 new) |
| w3-support-ticket | `lib/features/support` | 1 file, +185 / −122 |
| w3-reviews-list | `lib/features/reviews` | 2 files, +306 / −252 |
| w3-wallet-activity | `lib/features/wallet` | 4 files, +607 / −420 (+1 new) |

**All 12 reported `done` and all 12 have substantial diffs. No false reports.**

Motion lanes:

| Directory | Diff | Note |
|---|---|---|
| `lib/features/voice_request` | 2 files, +73 / −3 (+1 new) | — |
| `lib/features/transcription` | 1 file, +44 | — |
| `lib/features/home_client` | 5 files, +43 / −24 (+1 new) | — |
| `lib/features/delivery_receipt` | 1 file, +96 / −48 (+1 new) | — |
| `lib/features/client_offers` | 1 file, +25 / −1 | — |
| `lib/core/widgets/motion` | new file | new shared player |
| `lib/features/onboarding` | **ZERO** | expected — lane refused `onboarding-say-it`, documented |
| `lib/features/live_tracking` | **ZERO** | expected — lane deferred `courier-in-transit`, documented |

Both zero-diff motion directories are **consistent with their lanes' own `partial` reports**, which
refused those two files with written reasoning. They are not false `done` claims.

## Animation reference audit

`grep -rn "Lottie.asset" lib/ | wc -l` → **12** call sites (3 of the 12 lines are doc comments in
`jeeb_lottie_mark.dart`; 9 are real `Lottie.asset(` invocations).

**8 of 10 compositions are wired. 2 are orphaned.**

| Composition | Wired? | Where |
|---|---|---|
| `success-check.json` | ✅ | `delivery_receipt/widgets/receipt_confirmed_overlay.dart`, `kyc/widgets/kyc_status_marks.dart`, `wallet/widgets/wallet_topup_confirmed_mark.dart` |
| `voice-waveform.json` | ✅ | `voice_request/widgets/recording_waveform.dart`, `transcription/widgets/transcription_audio_card.dart` |
| `broadcasting.json` | ✅ | `client_offers_screen.dart:376`, `no_offer_timeout_screen.dart:504` |
| `empty-say-it.json` | ✅ | `home_client/widgets/client_home_motion.dart` |
| `loading-dots.json` | ✅ | `home_client/widgets/client_home_motion.dart` |
| `kyc-review.json` | ✅ | `kyc/widgets/kyc_status_marks.dart:40` |
| `mic-listening.json` | ✅ | `voice_request/widgets/mic_cluster.dart:166` |
| `nearby-scan.json` | ✅ | `no_offer_timeout_screen.dart:665` |
| **`courier-in-transit.json`** | ❌ **ORPHAN** | zero references in `lib/` |
| **`onboarding-say-it.json`** | ❌ **ORPHAN** | zero references in `lib/` |

Both orphans are **deliberate refusals with written justification**, not oversights:

- `courier-in-transit.json` — `w3-motion-tracking` refused it because the motion spec §3 explicitly
  forbids a canned live-tracking marker ("a lie about where the courier is"), and its three
  sanctioned homes (04 card, 18 strip, 24 row) are other lanes' directories.
- `onboarding-say-it.json` — `w3-motion-home-onboarding` refused it because the file composes screen
  01 panel 1's whole tableau, which already ships in Dart with **real localized Arabic copy**; the
  Lottie contract is shape-layers-only with no fonts, so adopting it would replace the Arabic
  transcript with a grey placeholder bar and break `onboarding_screen_test.dart:218/410/415`. The
  lane filed a request for a cards-free variant.

**These two JSON files are currently dead weight in the bundle.** Either the two filed follow-ups
land (a cards-free `onboarding-say-it` variant; a sanctioned home for `courier-in-transit`), or the
files should be removed from `assets/animations/` so the app does not ship ~29KB it never plays.

Related orphan flagged by a lane and confirmed here: `assets/illustrations/empty_orders.png` now has
**zero references in `lib/`** (replaced on screen 04 by `empty-say-it.json`), but is still registered
at `pubspec.yaml:273`. Left alone — removing it is a pubspec edit, which this gate is not authorised
to make.

## Wiring requests applied

Five `wiring/w3-*.md` files were filed. **Four requested no code change** (all explicitly
"non-blocking", "no shared-file change requested", or proposals for a later owner): `w3-motion-confirm`,
`w3-motion-home-onboarding`, `w3-motion-tracking`, and both items of `w3-customer-profile`.

**Applied — `w3-escalate` R1 (`escalatePhotoChipLabel`).** This was the only filed item that was a
genuine breach of hard constraint 4: `escalate_screen.dart` rendered `label: 'Photo ${index + 1}'`,
a raw English literal shown to the user, with a `TODO(wiring w3-escalate)` pointing at the request.
Applied the full hand-authored trio plus the call site:

- `lib/l10n/app_en.arb` — `"escalatePhotoChipLabel": "Photo {index}"` + `@`-metadata with the
  `index` int placeholder, following the neighbouring `escalatePhotoAttached` shape.
- `lib/l10n/app_ar.arb` — `"escalatePhotoChipLabel": "صورة {index}"`.
- `lib/l10n/app_localizations.dart` — `String escalatePhotoChipLabel(int index) =>
  _get('escalatePhotoChipLabel').replaceFirst('{index}', index.toString());`, matching the
  single-placeholder helper used by `escalatePhotoAttached`.
- `escalate_screen.dart` — call site swapped, TODO removed.

`flutter gen-l10n` was **not** run (this repo has no gen-l10n; the parser is hand-authored).
Verified: `dart analyze lib/l10n lib/features/escalate` clean, escalate suites 20/20, ARB parity
1736/1736.

**Not applied, deliberately:**

- **`w3-escalate` R2** (`escalateAutoAttachNote` / `escalateEvidenceTitle`) — the request itself says
  this "should be reviewed by whoever owns dispute copy (D53/D76) rather than pattern-matched from
  this file". It is a product copy decision, not an integration gap. Left for the copy owner.
- **`w3-customer-profile` 1 & 2** (`DirectionalIcons.signOut`; tone-aware `JeebVerifiedBadge`) —
  both touch `lib/core/widgets/*`, outside this gate's grant (`app_router.dart`,
  `injection_container.dart`, `lib/l10n/*`). Both are explicitly non-blocking dedupe cleanups with
  shipped, green workarounds. Deferred to the `lib/core/widgets` owner.

## Fixes made by this gate

**1. `test/mb1/mb1_doc_residual_receipts_test.dart` — the one new failure. Fixed.**

Not a design regression: the gate cross-checks two lenses and asserts that every `.dart` file on
disk is also git-tracked, because its residual scan runs over `git ls-files`. Twenty new lane files
(the Lottie players, the new l10n helpers, the new widgets and their tests) were untracked, so the
scan was measuring a different tree than the gate. Its own failure message says "Stage them, or the
receipts are measuring a different tree than the gate."

Staged the 19 legitimate new `.dart` files plus the `docs/redesign-2026-08` reports. **Staged only —
nothing committed, nothing pushed, no branch touched.** `.claude/worktrees/` was left untracked.
The test now passes.

**2. Deleted `test/features/jeeber_onboarding_funding/scratch_render_test.dart` — leftover debris.**

Its own header reads *"TEMPORARY visual-check harness (deleted before reporting)"* — the
`w4-jeeber-onboarding-funding` lane forgot to remove it. It is a `matchesGoldenFile(
'scratch_funding_render.png')` assertion against a golden that **does not exist on disk**, i.e. a
latent CI failure and a file that writes a PNG into the repo on every run.

This is **not** deleting a test to get green: the file was *passing*, and removing it lowers no real
coverage — the lane's actual suite, `onboarding_funding_screen_test.dart`, is untouched and staged.
Swept for other debris: the only other `throwaway` hit is an unrelated doc comment in
`back_nav_all_routes_test.dart`, and the three `active_delivery_jeeber/goldens/*.png` are a properly
tracked golden suite.

## Still failing / still open

- **`test/core/diagnostics/gesture_log_test.dart`** — 1 failure, pre-existing, local-SDK skew, green
  in CI. Unchanged from baseline. Not touched.
- **8 `containsSemantics` analyze infos** — pre-existing, deliberately not fixed (fixing them breaks
  CI at Flutter 3.38.9).
- **1 design-token violation** — `lib/features/location/presentation/client_location_screen.dart:1023`
  uses a raw `TextField`. Verified pre-existing: the line is present at `HEAD` and the file has a
  **zero-byte diff** on this branch. Not this wave's to fix.
- **2 orphaned Lottie compositions** (above) — need either the filed follow-ups or removal from
  `assets/animations/`.
- **`assets/illustrations/empty_orders.png`** — zero `lib/` references, still registered in pubspec.
