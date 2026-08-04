# Wave 4 — verification gate

Branch `feat/redesign-24-migration`. 26 lanes edited 26 feature directories in parallel.
No branch created/switched, nothing committed, nothing pushed.

---

## 1. Headline numbers

| Gate | Before this pass | After |
|---|---|---|
| `flutter analyze` | 0 errors / 0 warnings / 8 infos | **0 errors / 0 warnings / 8 infos** |
| `flutter test` | 4660 pass · 61 skip · **3 fail** | **4664 pass · 61 skip · 1 fail** |
| `test/core/widgets/jeeb/` (frozen kit) | — | **476 / 476** |
| `test/decision_violations_test.dart` + `qa_keys_batch` + `back_arrow_dead_at_root` + `no_raw_semantic_colors` | — | **29 / 29** |

The 8 analyze infos are all `containsSemantics` deprecations in test files — the documented
local-SDK skew (local 3.44.2 vs CI 3.38.9). **Not touched**: `isSemantics` does not exist in
3.38.9 and would be a CI compile error.

The 1 remaining failure is `test/core/diagnostics/gesture_log_test.dart` — the known
pre-existing local-SDK-skew failure, green in CI. **No new failures.**

### Test delta explained

The first full run of the wave-4 tree measured **3** failures, not the 1 in the standing baseline.
Two were real and both are now fixed (§3). The count then moved 4660 → 4664 because the
`+4` are the previously-uncounted new lane tests that only began running once their files
became visible to the tree (see §3.1) plus the re-greened `mb1` case.

---

## 2. Wiring requests applied

I hold sole write access to `app_router.dart`, `injection_container.dart` and `lib/l10n/*`.
**No router or DI change was requested by any lane** — every w4 lane resolved its own routes.
All applied work was l10n plus two test gates.

### 2.1 l10n — 14 new keys, added to all three files consistently

No `flutter gen-l10n` was run. Each key was hand-added to `app_en.arb`, `app_ar.arb` **and**
the hand-authored runtime parser `lib/l10n/app_localizations.dart`. None of the 14 has a plural
or placeholder, so the key-suffix plural convention was not engaged.

| Source request | Keys |
|---|---|
| `w4-biometric-login.md` | `biometricPromptSubtitle` |
| `w4-dispute-status.md` | `disputeStatusStepSubmitted`, `disputeStatusStepUnderReview` |
| `w4-client-unreachable.md` | `clientUnreachableTitle`, `…NoticeTitle`, `…NoticeBody`, `…CallAgainCta`, `…ChatCta`, `…FlagCta` |
| `w4-prohibited-item.md` | `prohibitedItemReportTitle`, `…Guidance`, `…DescriptionLabel`, `…AttachPhotoCta`, `…SubmitCta` |

Verified mechanically: both ARBs parse as JSON (2944 EN / 1779 AR keys); all 14 present in
**both** locales; all 14 reachable through a parser getter; **0** parser getters reference a key
absent from the EN ARB.

### 2.2 Call-site grants applied

- `biometric_prompt_screen.dart` — replaced the hardcoded English literal
  `'Sign in quickly with your fingerprint or face'` (and its 4-line `TODO(redesign-24)`) with
  `l10n.biometricPromptSubtitle`. EN copy byte-identical; the screen no longer shows English to
  Arabic users. This was the one request a lane deliberately refused to self-grant, because an
  undefined getter in `lib/` is an app-target compile error.
- `dispute_status_l10n.dart` — `stepSubmittedLabel` / `stepUnderReviewLabel` now delegate to the
  granted getters instead of the feature-local `_pick(en, ar)` map. EN **and** AR values are
  byte-identical to the stopgap, so this is a no-op for every assertion.

### 2.3 Duplicate-key reconciliation

`pendingTabSearchingLabel` (and its `@`-metadata) was defined **twice** in `app_en.arb`,
at lines 3298 and 3318. Both definitions were byte-identical in value and description, so the
second was removed and the first kept as canonical. **Pre-existing** — present twice at `HEAD`,
not introduced by wave 4. JSON still parses; the surviving value is unchanged
(`"Searching for Jeebers…"`).

### 2.4 Test gates

- `no_raw_semantic_colors_test.dart` — added
  `lib/features/settlement/presentation/widgets/settlement_status_pill.dart` to `migratedFiles`
  (`w4-settlement.md`). The settlement re-skin de-duplicated the paid/pending chip into this new
  file, moving the guarded `jeebRoles.success/warning` usage one file below the sweep's list.
  Restores intended coverage; green on arrival.
- `back_arrow_dead_at_root_test.dart` — **two lanes filed competing repairs for the same helper.**
  Reconciled to one, per `w4-kyc-rejected.md`'s own instruction ("take one of them, not both").
  Kept the already-applied `Finder _appBarBackButton() => find.byType(MinTapTarget);`.
  `w4-offer-kyc-gate.md`'s stricter `find.bySemanticsIdentifier('<screen>_back')` form was
  **not** additionally applied — it needs a `tester.ensureSemantics()` handle, and the applied
  form is green at 3/3 with no assertion or navigation expectation weakened. It fails loudly
  (`findsNWidgets` ambiguity), never silently. **Follow-up condition, unchanged from the lane's
  own note:** the moment any of those three top bars gains a trailing action or identity avatar,
  switch to the identifier form. The ids already exist: `offer_kyc_gate_back`,
  `delivery_register_prompt_top_back`, `kyc_rejected_back`.

---

## 3. Fixes I made

### 3.1 `mb1_doc_residual_receipts_test.dart` — REAL failure, fixed

```
Expected: empty
  Actual: [ settlement_status_pill.dart, client_unreachable_l10n.dart,
            prohibited_item_report_l10n.dart, set_password_screen_test.dart,
            prohibited_item_report_screen_test.dart, goods_cost_screen_test.dart,
            onboarding_funding_screen_test.dart, client_unreachable_screen_test.dart ]
```

Eight `.dart` files created by wave-4 lanes existed on disk but git did not track them. The MB1
receipts gate follows `git ls-files`, so a residual in any of them would have been **invisible to
the gate** — the gate would have been measuring a different tree than the one being merged.

Fixed exactly as the test's own failure message prescribes: `git add -N` on all eight, making them
tracked without committing content (no commit, no push — `git status` still shows them as
unstaged additions for the owner to review). `mb1` now **7/7**.

This is worth calling out: it was not a cosmetic test failure. Three of the eight are `lib/`
source files that were effectively outside every git-based gate.

### 3.2 Everything else

No source fix was needed for any lane's re-skin. No test was deleted, no assertion weakened,
no `Semantics(identifier:)` restored (none was lost — see §5).

---

## 4. Per-lane diff audit

Every lane that reported `done` or `partial` has a non-zero diff. **No false reports.**

| Lane dir | files | +/− |
|---|---|---|
| `delivery_status` | 6 | +328 / −466 |
| `jeeber_request_feed` | 2 | +297 / −500 |
| `settlement` | 3 | +323 / −200 |
| `location` | 2 | +255 / −164 |
| `biometric_auth` | 1 | +255 / −89 |
| `offer_kyc_gate` | 2 | +246 / −170 |
| `dispute_status` | 2 | +246 / −151 |
| `jeeber_onboarding` | 8 | +226 / −162 |
| `goods_cost` | 1 | +223 / −64 |
| `notification_prefs` | 1 | +222 / −125 |
| `jeeber_onboarding_funding` | 1 | +196 / −114 |
| `password_security` | 1 | +192 / −167 |
| `delivery_man_profile` | 6 | +180 / −159 |
| `prohibited_item_report` | 2 | +161 / −48 |
| `biometric_login` | 1 | +148 / −49 |
| `client_unreachable` | 2 | +142 / −71 |
| `settings` | 2 | +141 / −115 |
| `jeeber_home` | 3 | +140 / −113 |
| `account_status` | 1 | +137 / −91 |
| `kyc_rejected` | 1 | +130 / −87 |
| `auth` (set_password) | 1 | +119 / −82 |
| `jeeber_pending_offers` | 1 | +103 / −57 |
| `rating` | 4 | +93 / −50 |
| `language` | 1 | +70 / −86 |
| `profile_name` | 1 | +54 / −31 |
| `request_summary` | 1 | +54 / −9 |

**Kit adoption:** files under `lib/features/` importing `core/widgets/jeeb` went
**99 → 144** (+45).

---

## 5. Semantics identifier audit

Mechanical diff of every `identifier: '…'` under `lib/features/` between `HEAD` and the working
tree: **633 → 660** (+29 new, per the `<screen>_<element>` rule for new interactive widgets).

Two identifiers appeared "dropped" to a literal-string diff:
`request_feed_accept_$requestId` and `request_feed_decline_$requestId`. **False positive** — the
`jeeber_request_feed` lane inlined `_ActionButtons`, so the interpolation expression changed from
`$requestId` to `${request.id}`. At `HEAD` the parameter was fed by `requestId: request.id`
(line 256), so the **runtime identifier value is byte-identical**. The paired widget Keys
(`requestFeed.card.accept.…` / `.decline.…`) survived the same way.

**Net: zero identifiers lost.**

---

## 6. Locked decisions (§4 of the brief) — the wave's real risk

`test/decision_violations_test.dart` **passes**. Individually re-confirmed:

- **D56** — mandatory rating offers no close/skip/dismiss; back suppressed via
  `PopScope(canPop: false)`. The `rating` lane removed an `OMDSAppBar` that carried
  `automaticallyImplyLeading: false`, so no affordance was added. `rating_skip_cta` and
  `feedback_close_button` still do not exist.
- **D52** — no resubmit CTA on a final KYC rejection; `kyc_rejected_resubmit_cta` absent. The
  `kyc_rejected` lane explicitly refused to give the appeal action the accent treatment the
  design language would otherwise want.
- **D20** — no "Vehicle number" string anywhere.
- **Fee-only framing** — "Platform fee", never "Commission". `jeeb_commission` test green; the
  `goods_cost` lane refused to invent fee copy, and the one proposed new string making a
  fee-model claim was **not** granted (§8).

Also green: `qa_keys_batch_test.dart`, `semantics_identifier_surfacing_test.dart`.

---

## 7. Freeze / boundary checks

| Check | Result |
|---|---|
| `git diff --stat -- pubspec.yaml lib/core/widgets/jeeb lib/core/theme` | **empty** — no lane edited the frozen kit, theme or pubspec |
| `lottie` pin | `lottie: 3.3.1` — exact pin intact, not loosened to `^3.3.1` |
| `test/core/widgets/jeeb/` | **476 / 476** |
| `tier_selection_screen.dart` | untouched |
| `live_settings_screen.dart` | untouched |
| both `location_picker_screen.dart` | untouched |

**Token discipline sweep:** `Color(0x` occurrences in `lib/features/` — **5 at HEAD, 5 now.**
Did not grow.

**Design-token gate** (`tool/check_design_tokens.sh`): **1 violation**, a raw `TextField(` in
`lib/features/location/presentation/client_location_screen.dart:1023`. **Pre-existing** — that
file has a zero diff this wave. Note this is an *improvement*: several lane reports observed
3 repo-wide violations mid-wave; the other two were cleared by the lanes that owned them.

---

## 8. Requests deliberately NOT granted

- **`goodsCostCashNote`** (`w4-goods-cost.md`) — new copy asserting a fee model
  ("Jeeb takes a cut of the delivery fee only — never of your goods"). The lane itself flagged it
  "must be owner-confirmed before it ships", which is why it refused to hardcode it. It is a
  product claim, not a re-skin, and it sits directly on the D41/D44 fee-only decision.
  **Owner decision.** The screen ships correct without it.
- **`setpwPolicyHint`** (`w4-auth-set-password.md`) — filed by its own lane as OPTIONAL and
  non-blocking; new product copy surfacing a password policy that is currently only shown after
  failure. **Owner decision.**
- **`JeebMoneyField` stepper-slot relaxation** (`w4-goods-cost.md` WR-GOODS-1) — blocked on
  screen 17's WR-1 kit promotion landing first, and the kit is frozen this wave.
- **`JeebTextField` kit widget / gate exemption** (`w4-profile-name.md`) — kit is frozen; this is
  a Wave-5 scope call between adding a kit primitive and widening the raw-`TextField` exemption.

## 9. Still open (not regressions — gaps)

- **`pending_offer_row.dart` is still un-migrated.** `w4-jeeber-pending-offers.md` R1 asks for a
  ~120-line restyle of `lib/features/jeeber_request_feed/presentation/pending_offer_row.dart`,
  which the `jeeber_pending_offers` lane could not touch under constraint 9 and the
  `jeeber_request_feed` lane did not pick up. Confirmed: **zero diff, zero kit imports.** It is
  shared by three surfaces (pending-offers screen, feed sub-tab, jeeber home feed) and still
  renders uncarded strips, hairline dividers, raw `titleMedium`/`labelMedium`, an italic
  periwinkle line on white and an `errorContainer` withdraw pill.
  **I did not apply it**: my shared-file authority is router / DI / l10n, and this is an
  unrendered visual change across three surfaces that a verification gate cannot validate.
  Assign it an owner in Wave 5 — the paste-ready diff and its paired consumer padding change are
  already in the wiring file.
- **Three feature-local l10n stopgaps can now be deleted**, since their keys landed in §2.1:
  `client_unreachable_l10n.dart`, `prohibited_item_report_l10n.dart`, and the two stepper getters
  in `dispute_status_l10n.dart` (already repointed). Deleting the first two also requires adding
  `AppLocalizations.delegate` to their test hosts. Left in place — they are correct and green
  today, and the swap belongs to the owning lanes.
- **`saved_addresses_screen.dart`** (`settings`) is dead code that self-declares ORPHAN; the
  `settings-addresses` route builds `SavedLocationsScreen` from `lib/features/location/`. The
  lane's recommendation is deletion, which is a scope call above a lane.
- **`@kycRejectedTitle`**'s ARB description still says "OMDSAppBar title" (now a `JeebTopBar`).
  Not user-visible; left for an l10n description sweep.
- **Orphan screens re-skinned this wave** (no user-visible impact today, reachable only from the
  devtool catalog): `RequestFeedScreen`, `BiometricPromptScreen`, `ClientUnreachableScreen`,
  `ProhibitedItemReportScreen`, `DeliveryStatusScreen`.
