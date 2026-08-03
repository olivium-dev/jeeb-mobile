# 12 — Final Verification: the whole redesign migration

**Branch** `feat/redesign-24-migration` · 10 commits ahead of `main` (HEAD `d44c0945`) plus the
uncommitted Wave 5 working tree · verified **2026-08-03**.

This is the closing gate for Waves 0–5. Everything below is measured, not asserted; every count is
reproducible from the command printed beside it. Where the honest answer is "not done", it says so.

---

## 0. Wave 5 wiring inbox — empty

```
$ ls docs/redesign-2026-08/wiring/w5-*.md
zsh: no matches found
```

No Wave 5 lane raised a shared-file request. `app_router.dart`, `injection_container.dart` and
`lib/l10n/*` therefore needed **no integrator edit** in this gate, and none was made. The six W5
lanes landed 4 `done` + 2 `no-change-needed`, and both `no-change-needed` verdicts are corroborated
in §2 below (they are ORPHAN-tagged, gate-protected placeholders — declining was correct).

---

## 1. Gate results

| Gate | Required | Measured | Verdict |
|---|---|---|---|
| `flutter analyze` | 0 errors | **8 issues, 0 errors, 0 warnings** | PASS — baseline |
| `flutter test` | 4664 / 61 skip / 1 fail | **`+4664 ~61 -1`** | PASS — baseline |
| `flutter test test/core/widgets/jeeb/` | 476/476 | **`+476: All tests passed!`** | PASS |
| `decision_violations_test` + `qa_keys_batch_test` | pass | **`+8: All tests passed!`** | PASS |
| `git diff --stat -- pubspec.yaml lib/core/widgets/jeeb lib/core/theme` | empty | **empty** | PASS |
| `lottie` exact pin | `3.3.1` | `pubspec.yaml:71: lottie: 3.3.1` · `pubspec.lock: version: "3.3.1"` | PASS |
| Untracked `.dart` files | none hidden | **none** (`git ls-files --others` → ∅) | PASS |
| ARB key parity EN/AR | matched | **1750 / 1750, zero drift both directions** | PASS |

The 8 analyzer issues are all the expected `containsSemantics` deprecation infos in **test** files
(`chat_dm_header_parity`, `chat_dm_states`, `chat_screen` ×2, `client_home_screen` ×2,
`order_chat_strip_redesign`, `shell_dual_role_landing`) — local Flutter 3.44.2 vs CI 3.38.9. Not
touched, per the brief.

The single test failure is the documented one, reproduced in isolation to prove it is not a
regression:

```
$ flutter test test/core/diagnostics/gesture_log_test.dart
00:01 +9 -1: Some tests failed.
  GestureLogListener button-merged nested Semantics records the OUTER exposed id, not inner
```

Pre-existing local-SDK skew, green in CI. **No second failure anywhere in the suite.**

Overall footprint: `278 files changed, 36604 insertions(+), 15084 deletions(-)` in `lib/`
(234 under `lib/features`, 40 under `lib/core`, 3 under `lib/l10n`).

---

## 2. Screen coverage census

Population = `lib/features/**/*_screen.dart | *_page.dart | *_view.dart`.
"Migrated" = non-empty `git diff main -- <file>` **against the working tree**, so the uncommitted
Wave 5 edits count.

```
$ find lib/features -type f \( -name '*_screen.dart' -o -name '*_page.dart' -o -name '*_view.dart' \) | wc -l
```

| Metric | Count |
|---|---|
| Total screen/page/view files | **88** |
| Migrated (non-empty diff vs `main`) | **78** (88.6%) |
| — of those, importing `core/widgets/jeeb` | **71** (91.0% of migrated) |
| — migrated via tokens/delegation only, no direct kit import | **7** |
| Untouched | **10** (11.4%) |

> A methodology note worth recording: computing this with `git diff main..HEAD` instead of
> `git diff main` reports 75/13 and silently hides all five uncommitted Wave 5 files. The
> commit-range form is the wrong tool for a working-tree audit.

### 2.1 The 10 untouched files — one line each

| File | LOC | Reason | Genuinely missed? |
|---|---|---|---|
| `location/presentation/location_picker_screen.dart` | 461 | Constraint 10 NEVER-TOUCH; `ORPHAN (JEBV4-227)` — real cubit picker, unwired; `/location` mounts the placeholder instead | No — forbidden |
| `settings/presentation/screens/live_settings_screen.dart` | 228 | Constraint 10 NEVER-TOUCH | No — forbidden |
| `tier_selection/presentation/tier_selection_screen.dart` | 369 | Constraint 10 NEVER-TOUCH | No — forbidden |
| `location/presentation/screens/location_picker_screen.dart` | 36 | Constraint 10 NEVER-TOUCH; `ORPHAN (JEBV4-227)` placeholder, zero callsites | No — forbidden |
| `deep_link_targets/kyc_status_screen.dart` | 36 | Type-A `placeholder-discipline.sh` gate + `ORPHAN`; route builds `KycWizardScreen`. Body is one `OmdsEmptyStatePage` — no colour, style or `EdgeInsets` to migrate | No — dead + gate-locked |
| `deep_link_targets/rating_prompt_screen.dart` | 46 | Same gate; `/orders/:id/rate` unconditionally redirects to the redesigned `MutualRatingScreen`, asserted by `integration_wiring_test.dart:134-160` | No — dead + gate-locked |
| `settings/presentation/screens/saved_addresses_screen.dart` | 36 | Same gate + `ORPHAN`; route `settings-addresses` was reassigned to `SavedLocationsScreen`, which **is** migrated (6 kit imports) | No — superseded |
| `chat/presentation/dev_chat_preview_screen.dart` | 148 | Dev-only harness behind the `JEEB_DEV_CHAT` seam; both `build`s return `ChatScreen(...)`, which is migrated. Zero colours/styles/layout of its own | No — delegates |
| `onboarding/onboarding_screen.dart` | 8 | Pure `export` shim. Its target `onboarding/presentation/onboarding_screen.dart` is migrated (**+714/−174**) | No — export shim |
| `settings/presentation/screens/notification_preferences_screen.dart` | 31 | Cubit/DI wrapper. Its delegate `notification_prefs/presentation/notification_prefs_screen.dart` is migrated (**+222/−125**) | No — cubit wrapper |

**Genuinely missed screens: 0.** Four are explicitly forbidden by Constraint 10, three are
CI-gate-locked dead placeholders, three are shims/wrappers whose real surface is migrated.

### 2.2 The 7 migrated files with no direct kit import — all justified

| File | Why no kit import |
|---|---|
| `voice_request/presentation/voice_request_screen.dart` (36) | 100% delegation — `build` returns `VoiceRecordingScreen(...)` and nothing else |
| `customer_profile/presentation/customer_profile_screen.dart` (203) | Composition root (`BlocProvider` → `Semantics` → `ListView`); the visuals live in `customer_profile_header.dart` and `customer_profile_rows.dart`, both migrated with **3 kit imports each** |
| `home_client/.../client_home_empty_view.dart` (76) | Delegates its mark to `client_home_motion.dart` (`empty-say-it.json` Lottie); the rest is OMDS + l10n |
| `jeeber_home/.../jeeber_no_requests_view.dart` (142) | Token-level migration — 2 × `context.jeebText`, 2 × `JeebSemanticColors` |
| `kyc/presentation/widgets/kyc_submitting_view.dart` (316) | Token-level migration — 3 × `context.jeebText` + the `_GlyphMark` recipe, deliberately mirroring its migrated sibling `kyc_status_view.dart` rather than inventing a third language mid-wizard |
| `location/.../google_map_capture_view.dart` (164) | Raster map capture surface — a `GoogleMap` + canvas, no chrome for the kit to supply |
| `shell/shell_screen.dart` (550) | Navigation scaffold (tabs, header-action overlay); 1 × `context.jeebText`, no card/CTA surface of its own |

---

## 3. Consistency sweep

### 3.1 Raw hex colours — held flat, and every survivor is sanctioned

```
$ grep -rn "Color(0x" lib/features/ | wc -l        →  5
$ git grep -c "Color(0x" main -- lib/features      →  6
```

All 5 remaining are in a single file, `features/auth/social/social_sign_in_button.dart`:
`_googleBrandBlue #4285F4`, `_googleGlyphForeground`, `_facebookBrandBlue #1877F2`,
`_facebookGlyphForeground`, `_appleBrandBlack`. These are **third-party brand marks** whose values
are dictated by Google/Meta/Apple sign-in brand guidelines — they must not be tokenised. `main`
carried a sixth (`_appleBrandWhite`) which is now gone.

**Zero un-sanctioned raw hex anywhere in `lib/features`.**

### 3.2 Raw `TextStyle(` — count rose 2 → 6, and that is fine

This is the one metric that moved the "wrong" way, so each site was read rather than counted:

| Site | Verdict |
|---|---|
| `settings/.../settings_notifications_card.dart:157` | Inline `TextSpan` **child** carrying only `fontWeight` + `muted`; the parent span is `context.jeebText.body`. Delta on an inherited style |
| `chat/.../chat_message_bubble.dart:358` | `const TextStyle(fontStyle: FontStyle.italic)` — the bubble's `DefaultTextStyle` already carries the side's ink; italics is the only override, and the code comment says so |
| `delivery_receipt/.../delivery_receipt_screen.dart:507` | `const TextStyle(fontWeight: FontWeight.w800)` on one `TextSpan` inside a `Text.rich` whose root span carries the resolved `style` |
| `live_tracking/.../tracking_google_map.dart:123` | `TextPainter` painting an icon glyph into a `Canvas` for a map `BitmapDescriptor`. No `BuildContext`, no text theme — raster, not typography |
| `offline_mode/presentation/offline_banner.dart:41` | Pre-existing, already on `roles.onWarningContainer` |
| `location/.../saved_locations_screen.dart:608` | Pre-existing (moved 538 → 608), `TextStyle(color: scheme.error)` |

**Zero typography bypasses.** All four new sites are inline-span deltas or canvas painting, i.e.
exactly the cases where `context.jeebText` is not applicable. Adoption on the other side of the
ledger: **349 `jeebText` references across `lib/features`.**

### 3.3 Kit duplication — 3 real divergences, all outside the screen census

Method: parenthesis-matched scan for a `BoxDecoration` containing both `Border.all` and
`borderRadius` — the shape `JeebOutlinedCard` exists to own. 9 files hit; 6 are legitimate.

Legitimate (not cards):
- `registration_screen.dart:611`, `offers/.../jeeb_money_field.dart:121`, `goods_cost_screen.dart:298`
  — **text-field** borders (focus ring / error state). The kit has no field widget; these already use
  `colorScheme` + `JeebShadows.focusRing`.
- `onboarding_screen.dart:361,805` — pill toggle track and glass tail **on the navy hero**, not cards.
- `wallet_hub_screen.dart:544` — pill promo chip on `semantic.accentTint` / `accentRing`, tokenised
  with an explicit rationale comment.
- `address_detail_form_screen.dart:449` — map-preview frame at the board's 1.5px `scheme.outline`,
  commented against §4.1.

**Genuine divergences — hand-rolled outlined cards, zero kit imports:**

| File | Note |
|---|---|
| `location/presentation/widgets/client_location_option_card.dart:72` | Selectable option card; `OmdsBorderRadius.medium` + `scheme.outline`/`scheme.primary`. **Tokenised but not `JeebOutlinedCard`.** Reachable (← `current_location_status_card` ← `client_location_screen`) |
| `location/presentation/widgets/current_location_status_card.dart:237` | Same shape, `surfaceContainerHighest` + `scheme.outline`. Reachable via `client_location_screen` |
| `tier_selection/presentation/tier_card.dart:85` | Unchanged vs `main`. Consumed by `tier_selection_screen.dart` (Constraint 10 NEVER-TOUCH) **and** by `core/widgets/jeeb/jeeb_tier_row.dart:403` |

Both location cards are colour-correct — they use theme roles, not hex — so no token test fails.
The divergence is **structural**: three surfaces re-implement the card geometry the kit owns, so a
future radius/stroke change to `JeebOutlinedCard` will not reach them. This is the punch-list item,
not a defect today.

Beyond these, 60+ private `_Foo` widget classes exist in `lib/features`. They were sampled and are
composition helpers (`_ToggleRow`, `_PartyRow`, `_OfferCardBody`, `_StageRow`…), not kit clones —
they compose kit widgets rather than replacing them.

### 3.4 Kit adoption spread

All 32 kit widgets are reachable in product code. Distribution across `lib/features`:

```
JeebCtaButton 60 · JeebTopBar 57 · JeebOutlinedCard 49 · JeebCtaFooter 42 · JeebInfoNote 39
JeebSectionLabel 28 · JeebListRow 17 · JeebAvatar 17 · JeebSelectChip 16 · JeebNavySurfaceCard 12
JeebTierChip 8 · JeebSystemChip 7 · JeebChipRow 7 · JeebAccentFrameCard 7 · JeebWaveform 6
JeebSurfaceTone 5 · JeebProfileHeader 5 · JeebCodeCells 5 · JeebStepper 4 · JeebMicHero 4
JeebMeter 4 · JeebSegmentedToggle 3 · JeebMoneyBreakdown 3 · JeebTierRow 2 · JeebStepperPill 2
JeebChatBubble 2 · JeebQuickReplyRow 1 · JeebPageDots 1 · JeebNumericKeypad 1 · JeebChatComposer 1
JeebAvatarStack 1 · JeebPriceMeter 0*
```

\* `JeebPriceMeter` shows 0 **direct** feature references by design: it is deliberately split out of
`JeebTierRow` (used in 2 feature files) because its on-navy inversion reads `JeebSurfaceTone`
structurally rather than by parameter. It is composed at `jeeb_tier_row.dart:403` and covered by
`jeeb_price_meter_test.dart` + `jeeb_tier_row_test.dart`. **Not orphaned.**

### 3.5 RTL — clean

Across all 276 changed `.dart` files:

| Hazard | Hits |
|---|---|
| `EdgeInsets.only(left:` / `(right:` | **0** |
| `Alignment.centerLeft` / `centerRight` / `topLeft` / `bottomLeft` | **0** |
| `TextAlign.left` / `.right` | **0** |
| `BorderRadius.horizontal` | **0** |
| `EdgeInsets.fromLTRB` | 3 |

All 3 `fromLTRB` are RTL-safe: `offer_submission_screen.dart:786` and `wallet_hub_screen.dart:622`
are horizontally symmetric (`Spacing.medium` on both sides); `jeeb_top_bar.dart:361` reconstructs
from an already-`resolve`d directional `EdgeInsets` in order to subtract tap overhang, which is
direction-correct by construction. One further hit is a doc comment in `review_row.dart:16`
describing the `EdgeInsets.only(right:)` the migration *removed*.

### 3.6 Hardcoded user-visible strings — 1 hit, sanctioned

`settings/presentation/widgets/settings_more_card.dart:58` — `'Diagnostics'` /
`'Session logs · dev builds only'`. Guarded by `if (Diag.enabled)` (`kDebugMode ||
JEEB_DIAG` dart-define), so it never renders in release, with an in-file comment stating the
literals are deliberately kept out of the ARB catalogs. Correct call — a dev tool in the
translator's queue is worse than a literal.

No other hardcoded string in any changed feature file. `lib/l10n` grew by `+1101/−44` across
`app_en.arb`, `app_ar.arb` and the hand-authored parser, and the catalogs are **exactly in sync at
1750 keys with zero drift in either direction**. `flutter gen-l10n` was never run.

### 3.7 `tool/check_design_tokens.sh` — 1 violation, pre-existing

```
FAIL: Raw TextField -> use OmdsTextField or OmdsValidatedTextField
lib/features/location/presentation/client_location_screen.dart:1023
```

Pre-existing: the same raw `TextField` sits at `client_location_screen.dart:1088` on `main`. The
migration did not introduce it and did not fix it — it is outside every Wave 5 lane's file
allowlist. Punch-list item.

---

## 4. Semantics identifier audit

Method: parenthesis-tolerant, **multiline** regex `[A-Za-z]*[Ii]dentifier:\s*'([^']*)'` over every
`.dart` file in `lib`, run against `main` (via `git ls-tree` + `git show`) and against the working
tree, then set-differenced.

```
main: 569 distinct literals    working tree: 687 distinct literals
LOST: 7        ADDED: 125
```

Every one of the 7 was traced to source. **All 7 are artifacts of literal extraction — the runtime
string is unchanged in each case. Zero identifiers were actually lost.**

| Reported "lost" | What actually happened | Runtime string |
|---|---|---|
| `order_history_active_tab` | `order_history_screen.dart:116` now emits `'order_history_${tab.name}_tab'` over `enum OrderHistoryTab { active, completed, cancelled }`, with a `// FROZEN:` comment naming all three | identical |
| `order_history_completed_tab` | same loop | identical |
| `order_history_cancelled_tab` | same loop | identical |
| `order_history_card_${order.id}` | hoisted to a local at `order_history_card.dart:112` (`final String identifier = 'order_history_card_${order.id}'`) then passed as `identifier: identifier` | identical |
| `request_feed_accept_$requestId` | `request_card.dart:431` → `'request_feed_accept_${request.id}'`; on `main` the field was bound `requestId: request.id` (line 256) | identical |
| `request_feed_decline_$requestId` | `request_card.dart:417`, same substitution | identical |
| `jeeber_active_delivery_open_chat_$deliveryId` | `active_deliveries_banner.dart:235` → `'..._${delivery.id}'`; on `main` bound `deliveryId: delivery.id` (line 257) | identical |

An earlier single-line-only regex additionally mis-flagged `password_confirm_visibility_toggle`
(now line-wrapped across `password_security_screen.dart:243-244`); the multiline pass resolves it.
This is why the brief demands verification before reporting a loss — a naïve extraction reports 8
regressions where there are none.

**+125 new identifiers**, all following the `<screen>_<element>` convention.

---

## 5. Animation audit

10 compositions in `assets/animations/`, all individually registered in `pubspec.yaml` (deliberately
not as a directory glob). 132 KB total.

| Asset | refs in `lib/` | Consumers |
|---|---|---|
| `success-check.json` | 4 | `kyc_status_marks`, `receipt_confirmed_overlay`, `delivery_receipt_screen`, `wallet_topup_confirmed_mark` |
| `broadcasting.json` | 3 | `jeeb_lottie_mark`, `client_offers_screen`, `no_offer_timeout_screen` |
| `empty-say-it.json` | 2 | `client_home_empty_view`, `client_home_motion` |
| `voice-waveform.json` | 2 | `recording_waveform`, `transcription_audio_card` |
| `kyc-review.json` | 1 | `kyc_status_marks` |
| `loading-dots.json` | 1 | `client_home_motion` |
| `mic-listening.json` | 1 | `mic_cluster` |
| `nearby-scan.json` | 1 | `no_offer_timeout_screen` |
| **`courier-in-transit.json`** | **0** | **ORPHAN — 7,904 bytes** |
| **`onboarding-say-it.json`** | **0** | **ORPHAN — 21,384 bytes** |

**2 orphaned animations, 29,288 bytes (~29 KB, 22% of the animation payload) shipped in the bundle
with no code path that can play them.** They are registered in `pubspec.yaml`, so they are real
download weight in every install. Either wire them (`courier-in-transit` clearly belongs on the
live-tracking surface, `onboarding-say-it` on onboarding) or drop both asset lines. Removing them
requires a `pubspec.yaml` edit, which this gate is forbidden to make.

---

## 6. Honest punch list

Nothing below blocks the migration. All are real, none were fixed here, and each names why.

1. **2 orphaned Lottie assets — ~29 KB of dead bundle weight.** `courier-in-transit.json`,
   `onboarding-say-it.json`. Fix needs a `pubspec.yaml` edit (forbidden to this gate) or a wiring
   lane. *Highest-value item on this list.*
2. **3 hand-rolled outlined cards bypass `JeebOutlinedCard`.**
   `client_location_option_card.dart:72`, `current_location_status_card.dart:237` (both live and
   reachable), `tier_card.dart:85` (behind a NEVER-TOUCH screen). Colour-correct today; the risk is
   that a future change to the kit's radius or stroke will not reach them.
3. **`client_location_screen.dart:1023` raw `TextField`** fails `tool/check_design_tokens.sh`.
   Pre-existing on `main` (line 1088), outside every W5 allowlist.
4. **`location_picker_screen.dart` (461 LOC, real cubit-backed picker) is written but unrouted** —
   `/location` mounts a 36-LOC placeholder instead. Both NEVER-TOUCH. Unmigrated *and* unreachable;
   whichever ticket wires it up inherits a Wave-0-era screen.
5. **4 gate-locked placeholder screens** (`deep_link_targets/kyc_status`, `rating_prompt`,
   `settings/saved_addresses`, `location/screens/location_picker`) stay pre-redesign by CI contract
   (`qa/t-mob-fix-001/placeholder-discipline.sh`). They unblock only when `T-MOB-RATING-001` and
   siblings lift the gate.
6. **8 `containsSemantics` analyzer infos** clear themselves when CI moves past Flutter 3.40.
7. **`gesture_log_test`** fails on local 3.44.2, green on CI 3.38.9. Local-SDK skew, not code.

---

## 7. Verdict

The 24-screen redesign is **complete across every screen it was allowed to touch, with zero
identifier regressions and zero test regressions.**

- 78 of 88 screen/page/view files migrated; **0 genuinely missed**. The 10 untouched decompose into
  4 forbidden by Constraint 10, 3 CI-gate-locked dead placeholders, and 3 shims/wrappers whose real
  surface *is* migrated.
- 71 migrated files import the kit directly; the other 7 are delegation roots, token-level
  migrations, or non-chrome surfaces — each individually justified in §2.2.
- Design-system discipline holds under measurement: 0 un-sanctioned raw hex, 0 typography bypasses,
  0 RTL hazards, 1 sanctioned dev-only literal, ARB catalogs exact at 1750/1750.
- Every gate is at baseline. Nothing was weakened, no test deleted, no assertion relaxed.

The honest residue is small and named: ~29 KB of unreferenced animation, 3 hand-rolled cards the kit
should own, and one pre-existing raw `TextField`. None is a design-system failure; all three are
follow-up tickets.
