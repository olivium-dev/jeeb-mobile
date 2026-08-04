# 07 · Gap-closer verification gate

Measured 2026-08-03 on `feat/redesign-24-migration`, working tree, after integrating the four
gap-closer lanes and applying the outstanding wiring requests.

**Verdict: all four lanes are real. No lane reported `done` with a zero diff. The tree is greener
than the baseline it was cut from — one of the two pre-existing failures is now fixed.**

---

## 1 · Gate summary

| Gate | Baseline | Now | Delta |
|---|---|---|---|
| `flutter analyze --no-pub` | 5 issues / **0 errors** | 8 issues / **0 errors / 0 warnings** | +3 infos, all pre-existing class, all from the *committed* redesign, not the gap lanes |
| `flutter test` | 4601 pass / 61 skip / **2 fail** | **4617 pass / 61 skip / 1 fail** | **+16 tests, −1 failure** |
| `flutter test test/core/widgets/jeeb/` | 476 / 476 | **476 / 476** | unchanged — kit not touched |
| `test/decision_violations_test.dart` | pass | **pass** | — |
| `test/qa_keys_batch_test.dart` | pass | **pass** | — |
| `test/semantics_identifier_surfacing_test.dart` | pass | **pass** | — |
| `test/mb1/` | pass | **pass** (after a staging fix, §4.2) | — |
| `tool/check_design_tokens.sh` | 6 violations | **6 violations** | unchanged — all 6 verified pre-existing on `main` |

### 1.1 The analyze delta is not a regression

All 8 issues are the same `containsSemantics` deprecation **info** in test files (local Flutter
3.44.2 vs CI's 3.38.9 — CI never sees them; `_BASELINE.md` forbids "fixing" them). Attribution,
by counting `containsSemantics` occurrences on `main` versus now:

| File | on `main` | now |
|---|---|---|
| `test/chat_dm_header_parity_test.dart` | 1 | 1 |
| `test/chat_dm_states_test.dart` | 1 | 1 |
| `test/client_home_screen_test.dart` | 2 | 2 |
| `test/features/shell/shell_dual_role_landing_test.dart` | 1 | 1 |
| **`test/chat_screen_test.dart`** | **0** | **2** |
| **`test/features/chat/order_chat_strip_redesign_test.dart`** | **absent** | **1** |
| total | **5** = the baseline | **8** |

The +3 come from two files changed by the **committed** redesign (`51967d89`), both of which sit
outside the four gap lanes' working-tree diff. Zero errors, zero warnings, nothing new to fix.

### 1.2 The test delta

`4617 +/61 ~/1 −`. The single failure is
`test/core/diagnostics/gesture_log_test.dart` — *"button-merged nested Semantics records the OUTER
exposed id, not inner"* — which `_BASELINE.md` records as a local-SDK-skew failure that **passes in
CI**. It is one of the two named pre-existing failures and is untouched by this work.

The other named pre-existing failure, **`test/jeeber_feed_card_test.dart`, is now GREEN**
(194/194 in that suite). The jeeber-feed lane's two-row card layout genuinely fixed the pill
alignment defect that was red on `main` in CI; the l10n wiring applied here (§3) finished it.

No new failure was introduced. No test was deleted and no assertion weakened — see §5.

---

## 2 · The gaps actually closed (per-lane diff sizes)

The four lanes could not commit, so their work is the **working tree**. The prompt's
`main..HEAD` check is therefore split in two below: the committed 24-screen redesign, and the
uncommitted gap-closer work. The three directories named as "must not be zero" were **exactly
zero in the redesign commit** — which is precisely the gap the owner spotted on the device — and
are non-zero now.

| Directory | committed `main..HEAD` (the 24-screen redesign) | gap-lane working tree | closed? |
|---|---|---|---|
| `lib/features/deep_link_targets` | **0 files, 0 lines** | 1 file, **+197 / −10** | ✅ |
| `lib/features/shell` | **0 files, 0 lines** | 1 file, **+144 / −68** | ✅ |
| `lib/features/jeeber_request_feed` | **0 files, 0 lines** | 1 file, **+403 / −365** | ✅ |
| `lib/features/jeeber_active_deliveries` | **0 files, 0 lines** | 1 file, **+200 / −229** | ✅ (the feed lane's W-3) |
| `lib/features/request_type` | 5 files, +428 / −334 | 1 file, +7 / −1 | ✅ (already redesigned; lane fixed a 360dp defect) |
| `lib/features/jeeber_home` | 6 files, +629 / −449 | 1 file, +7 / −0 | ✅ (call-site wiring for the new card) |

Per-lane totals including tests and flows:

| Lane | files | lines |
|---|---|---|
| `gap-chat-container` | 1 lib + 3 test + 4 maestro | +233 / −49 |
| `gap-shell-tabbar` | 1 lib + 1 new test (225 lines) | +369 / −68 |
| `gap-jeeber-feed` | 3 lib + 3 test | +920 / −786 |
| `07/08 request-type` | 1 lib + 1 new test (117 lines) | +124 / −1 |
| **integration (this pass)** | 3 l10n + 1 lib + 1 test | +81 / −7 |

Whole integration diff vs `HEAD`: **21 files, +1727 / −904**.

---

## 3 · Wiring requests applied

Two `wiring/gap-*.md` files were open. Neither needed `app_router.dart` or
`injection_container.dart`.

### 3.1 `gap-jeeber-feed.md` — l10n batch · **APPLIED**

Four missing keys from the W-1 batch. **The request's ICU syntax was not applicable**: this repo has
no `flutter gen-l10n` (no `l10n.yaml`, no `generate: true`). `lib/l10n/app_localizations.dart` is a
hand-authored loader that parses the ARBs at runtime, and plurals use the repo's **key-suffix
convention** (`…Zero/One/Two/Few/Many/Other`, six Arabic CLDR branches per set,
`qa/t-mob-fix-002/ar_plurals_check.sh`). The four keys were expanded accordingly:

- `lib/l10n/app_en.arb` (+34): `jeeberFeedMakeOfferAction` + 18 branch keys with `@`-metadata.
- `lib/l10n/app_ar.arb` (+19): the same 19 keys, all genuinely translated.
- `lib/l10n/app_localizations.dart` (+28): `jeeberFeedMakeOfferAction` getter, three
  `jeeberFeedMinutesAgo/HoursAgo/DaysAgo(int)` methods over one private `_jeeberFeedAge` dispatcher
  modelled on the existing `pendingCardCreated*` / `offersWindowStrip` code.

Both call sites in `jeeber_feed_card.dart` were then switched and their `TODO(redesign-24)` comments
deleted:

1. `_OfferPill` renders **`Make offer`**, not `Offer`.
2. `_Timestamp` renders a **relative age** (`2 h ago`, `Just now`) instead of `DateFormat.Hm`; the
   now-unused `DateFormat` import was dropped from the `show` clause (`NumberFormat` stays).

`jeeberFeedOfferAction` was **kept** in both ARBs as the request specifies, so the runtime-parity
gate still sees a matched key set. It now has no call site in `lib/`.

Test follow-through in `test/jeeber_feed_card_test.dart`: four `find.text('Offer')` → `'Make offer'`,
and the `SW-03 device-local timestamp` group was **retargeted, not weakened** — it now feeds a UTC
instant two hours old and asserts the timestamp `Text` reads exactly `2 h ago` *and*
`isNot(contains(':'))`, which preserves the original SW-03 intent (no raw-UTC wall clock can
survive) against the new formatter. A second case was **added** for the `Just now` branch.

### 3.2 Requests deliberately NOT applied

| Request | File | Why not |
|---|---|---|
| accent `JeebCtaVariant` | `lib/core/widgets/jeeb/jeeb_cta_button.dart` | **kit is FROZEN.** The lane's `Theme`-override workaround is correct and forks nothing. Owner/kit-lane call. |
| `Flexible` chip label | `lib/core/widgets/jeeb/jeeb_select_chip.dart` | kit is FROZEN. |
| `Flexible` tier badge (200 %-text overflow) | `lib/core/widgets/jeeb/jeeb_tier_row.dart` | kit is FROZEN. Note the request-type lane **corrected** the earlier repro: with the shipped Inter there is zero overflow at 1.0/1.3/1.5; the defect is real only at 2.0 text scale on the badged row. |
| badge moves Flash → Standard; `Most picked` → `Recommended` | `lib/features/tier_selection/data/tier_repository.dart` + ARB value | **product claim, not a wiring gap.** Changing which tier is "recommended" and asserting popularity is an owner decision, explicitly flagged as such in the request. |
| delete `selectable_radio_glyph.dart` | `lib/features/request_type/presentation/` | dead but harmless; the 09 lane is editing option cards concurrently. Deleting now is a merge landmine for zero user-visible gain. |

---

## 4 · Fixes made during integration

### 4.1 `jeeber_feed_card.dart` + its test — §3.1 above.

### 4.2 `test/mb1/mb1_doc_residual_receipts_test.dart` — a **new** failure, fixed

> `Expected: empty` / `Actual: ['test/features/shell/shell_tab_bar_redesign_test.dart',
> 'test/features/request_type/request_type_layout_test.dart']`
> *"these .dart files exist on disk but git does not track them, so V-1 CANNOT see a residual in
> them. Stage them, or the receipts are measuring a different tree than the gate."*

Two lanes created new test files and — correctly, per their instructions — never committed them.
The MB1 lens asks **git** what exists, so an untracked `.dart` file is invisible to the residual
gate. Fixed exactly as the test prescribes: `git add -N` on both files (intent-to-add — they are
now in `git ls-files`, **nothing was committed**). `test/mb1/` is green.

This is a standing trap for any future parallel-lane wave: **a new `.dart` file under `lib/` or
`test/` must be staged or `test/mb1/` reds.**

---

## 5 · Claims audited (not taken on trust)

**Frozen surfaces.** `git status` on `lib/core/widgets/jeeb`, `lib/core/theme` and `pubspec.yaml` is
**empty** — no lane touched the kit, the theme or the dependencies. Kit suite is 476/476.

**`Semantics(identifier:)` preservation.** Every identifier literal in each lane's files was diffed
against `main`. Result — **no identifier was dropped or renamed**:

| File | delta |
|---|---|
| `shell_screen.dart` | **none** (all `shell_tab_*` / `shell_tab_*_badge` byte-identical) |
| `jeeber_feed_card.dart` | **none** |
| `chat_detail_screen.dart` | +`chat_detail_resolution_retry` (new; the old retry button carried none). `chat_resolution_error` survives. |
| `request_type_screen.dart` | +`request_type_back` (new) |
| `jeeber_feed_tab_view.dart` | +`jeeber_feed_search_toggle` (new, from the committed redesign) |
| `active_deliveries_banner.dart` | `…open_chat_$deliveryId` → `…open_chat_${delivery.id}` — **same runtime string**, the widget was re-parameterised from a loose `deliveryId` to the `delivery` object. Not a rename. |

**No test deleted, no assertion weakened.** Case counts per touched suite, `main` → now:
`jeeber_feed_card_test` 16 → **22**; `jeeber_active_card_push_render_test` 1 → 1;
`jeeber_active_deliveries_cap_test` 5 → 5; the three `chat_resolution_*` suites 7/3/4 → 7/3/4
(their edits are `find.byType(OmdsErrorStatePage)` → `find.byType(ChatResolutionErrorView)`, a type
retarget onto the replacement widget with every `reason:` string intact). Two new suites add 342
lines of assertions.

**The four Maestro edits are legitimate.** The deleted `chat_detail_voice_button` assertions target
an id that provably cannot exist — decision B-04 refused a composer mic, and
`test/features/chat/chat_composer_no_mic_b04_test.dart` asserts its **absence**. Each flow now
carries a comment explaining why the id is gone so it is never re-added. Net −4 assertions, +12
comment lines.

**Two failures the shell lane reported as "not mine" are resolved.** `test/widget_test.dart` (it saw
a compile error from the chat lane's in-flight `chat_detail_screen.dart`) and the three
`test/features/shell/jeeber_*` overflows (in-flight `jeeber_feed_card.dart`) all pass in the final
run. They were mid-edit artifacts of concurrent lanes, not defects.

**Design tokens.** `tool/check_design_tokens.sh` reports 6 violations — `settlement_screen` (2),
`settlement_detail_screen` (1), `client_location_screen` (1), `wallet_activity_list_screen` (1),
`reviews_list_screen` (1). Four of those files are byte-identical to `main`; `client_location_screen`
changed but its raw-`TextField` count is 2 on `main` and 2 now. **All 6 pre-date this migration.**

---

## 6 · Still open (nothing blocking)

1. **`test/core/diagnostics/gesture_log_test.dart`** — the one red test. Pre-existing, local-SDK
   skew, green in CI. Not this migration's.
2. **Three frozen-kit requests** (§3.2) are unapplied by design and need the kit lane or the owner.
   The 200 %-text tier-badge overflow is the only one with a user-visible symptom.
3. **The tier-badge product decision** (Flash vs Standard, `Most picked` vs `Recommended`) is
   waiting on the owner.
4. **`assets/animations/` is untracked and unreferenced** — 10 Lottie JSONs alongside an untracked
   `08-MOTION-SPEC.md`. Nothing in `lib/`, `test/` or `pubspec.yaml` mentions the path, and playing
   them would need a dependency this wave is not allowed to add. Inert, but it is dead weight
   somebody should either wire up or delete.
5. **`jeeberFeedOfferAction`** now has no call site in `lib/`. Kept deliberately (§3.1); delete it
   only together with its AR twin, or the parity gate reds.
