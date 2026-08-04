# 22 · Become a Jeeber (KYC wizard) — apply report

**Status: applied.** All nine tasks of `per-screen-revised/22-become-a-jeeber.md` executed.
The lane compiles and its full test set is green **once the §8 l10n batch lands** (verified — see
"Verification" below). Against the tree as it stands today it shows exactly 11 analyzer errors,
all of them `undefined_getter/undefined_method` on the 10 new `AppLocalizations` keys the wiring
request asks for. Nothing else.

---

## Files changed

| File | What |
|---|---|
| `lib/features/kyc/application/kyc_wizard_state.dart` | +2 derived getters (`currentCaptureStep`, `isSelfieUnlocked`). Not in `props`, no cubit change. |
| `lib/features/kyc/presentation/kyc_wizard_screen.dart` | `BlocBuilder` hoisted above the `Scaffold` so `appBar:` can read the step; identity step drops `OMDSAppBar` for `JeebTopBar`; `_ProgressHeader` → `_CaptureProgress`; schema-error view restyled + `JeebCtaButton.outline`. |
| `lib/features/kyc/presentation/widgets/kyc_capture_tile.dart` | Rebuilt: 140px square → outlined r18 row (thumb · title+sub-line · passive trailing), three states. |
| `lib/features/kyc/presentation/widgets/kyc_identity_step.dart` | Body column rebuilt per §5; `_TosAgreementRow` + terms sheet; scroll-hint recolor; footer → `JeebCtaFooter.single`. |
| `lib/features/kyc/presentation/widgets/kyc_liveness_prompt_card.dart` | Recolored off the (now orange) `primaryContainer`; conditional mount moved to the call site. |
| `test/kyc_wizard_screen_test.dart` | Viewport pin on the scroll test + 4 additive tests. No assertion weakened. |

**Deleted** (Task 7, owner-visible): `lib/features/kyc/presentation/widgets/kyc_id_alignment_guide.dart`
and `test/kyc_id_alignment_guide_test.dart`. This is the only coverage reduction in the change.

**Untouched, as required:** `kyc_status_view.dart` (D52 lives there), `kyc_submitting_view.dart`,
`kyc_wizard_cubit.dart`, `lib/core/**` (router, DI, theme, kit), `lib/l10n/*`, `pubspec.yaml`,
`lib/devtool/**`, `.maestro/**`.

---

## Kit widgets consumed (no private copies)

`JeebTopBar` · `JeebMeter.segmented` · `JeebOutlinedCard` · `JeebSelectChip` (+ `JeebChipRole`) ·
`JeebSectionLabel` · `JeebInfoNote.muted` · `JeebCtaButton` (`.primary` / `.outline` / `.text`) ·
`JeebCtaFooter.single`.

---

## Semantics

Every identifier in §3.1 still greps, spelled identically, in the same wrapper idiom
(`kyc_wizard_root`, `kyc_wizard_retry_cta`, `kyc_id_front_upload`, `kyc_id_back_upload`,
`kyc_id_type_picker`, `kyc_id_type_${type.wire}`, `kyc_id_number_input`, `kyc_selfie_upload`,
`kyc_submit_cta`, `kyc_scroll_hint`, `kyc_tos_accept`). Every listed `Key` survives.

New (§3.2): `kyc_wizard_back` (on `JeebTopBar`'s leading circle), `kyc_review_note`,
`kyc_tos_read_cta`, `kyc_tos_document_sheet`.

---

## Divergences from the board — the §4 list, all shipped as specified

C1 ID type + ID number kept (contract-required) · C2 `Captured ✓` without the fabricated sharpness
verdict · C3 real `Image.memory` thumb with the navy slab as `errorBuilder` · C4 the
"encrypted at rest" clause held · C5 `kyc_tos_read_cta` → document sheet · trailing pill reuses
`kycIdCaptureCta` / `kycSelfieCaptureCta` · nearest-ramp type · role green.

### Additional deviations I made, and why (each is a one-line reversal)

1. **Progress step name is derived, not hard-coded to `kycWizardStepIdTitle`.** §6 Task 3's snippet
   pins `stepName: l10n.kycWizardStepIdTitle`, which would render "Step 2 of 2 — Your ID" once the
   ID sides are captured. The label now uses `kycWizardStepSelfieLabel` on the last step. No new
   key, no board impact (the board only draws step 1).
2. **`_scrollToSelfie` uses `Scrollable.ensureVisible` on the selfie row, not `maxScrollExtent`.**
   The redesign moved the review note and the terms BELOW the selfie row, so scrolling to the very
   bottom pushed the row the hint advertises almost off the top of the viewport (measured: only
   51 of its 87px left on a 360×640). It now lands the row 12% down the viewport, and falls back
   to the old `maxScrollExtent` animation if the anchor is not mounted. This is also what made the
   pinned-viewport scroll test pass honestly rather than by luck.
3. **The trailing affordance is width-capped at 42% of the row, inside a
   `FittedBox(scaleDown)`.** Uncapped, a long label (200% text, Arabic, or the test block font)
   starved the title column to ~18px and produced a 550px-tall row — measured. A hard
   `ConstrainedBox` alone makes the kit chip's shrink-wrapped `Row` overflow, so the cap wraps a
   `scaleDown` box: below the cap it renders at scale 1.0, pixel-identical to the board.
4. **The locked row absorbs its own taps** (`GestureDetector(behavior: opaque)` inside the card).
   Without it a locked row is a hole — taps fall through to the scroll view and the row is not a
   hit target for a11y focus or for `hitTestable()`.
5. **The locked fade wraps the whole card, not just its child.** `22 tpl 1324` puts `opacity: .55`
   on the row div, outline included; §6 said "wrap the card's child", which would have left the
   border at full strength.
6. **Pending/locked sub-line is `bodySmall` at w500** (`tpl 1322` draws `font-weight: 500`);
   the captured line stays w600. Weight-only `copyWith`, no `fontSize:`.

---

## Verification

| Gate | Result |
|---|---|
| `dart analyze lib/features/kyc` | **11 issues, all `undefined_getter/undefined_method` on the 10 §8 keys.** Zero other errors, zero warnings, zero infos. |
| `bash tool/check_design_tokens.sh` | **0 violations in `lib/features/kyc`.** (The script fails overall on 6 pre-existing violations in `settlement`, `location`, `wallet`, `reviews` — none mine.) |
| `flutter test` — `kyc_wizard_screen_test` (21 tests incl. 4 new), `kyc_wizard_cubit_test`, `kyc_liveness_prompt_card_test`, `kyc_status_view_test`, `kyc_submitting_view_test`, `core/jeeb_commission_test`, `core/theme/no_raw_semantic_colors_test` | **All green.** |
| `flutter analyze` repo-wide / `decision_violations_test` | **Not run.** Both need the whole tree to compile; other lanes are mid-flight and the tree currently does not (e.g. `mutual_rating_screen.dart` references its own un-landed l10n keys). |

**How the test run was done, and one caveat.** `AppLocalizations` is a concrete class, so the lane
cannot be executed at all until §8 lands. To verify rather than assume, I applied the §8 batch to
`lib/l10n/{app_en.arb,app_ar.arb,app_localizations.dart}` **temporarily**, ran the suites, and then
reverted with a precise reverse patch. The three files are now **byte-identical (sha256 verified)
to their pre-patch state**, and `git diff --stat lib/l10n/` shows no change of mine.

⚠️ **Caveat for the orchestrator:** during that window four `voiceRecording*` keys/getters
(`voiceRecordingNewRequestTitle`, `voiceRecordingStatusRecording`, `voiceRecordingSlideToCancel`,
`voiceRecordingTypeInstead`) that another lane had written directly into `lib/l10n` disappeared
from the tree. I cannot rule out that my read-modify-write raced them. They are **fully recoverable**:
`docs/redesign-2026-08/wiring/05-voice-recording.md` already carries all four, and
`lib/features/voice_request/**` still references them, so the integrator's normal l10n pass restores
them. Flagging it rather than re-adding, since `lib/l10n` is not mine to edit.

---

## Test changes

- `tapping kyc_scroll_hint scrolls …` — pinned to a 360×640 @3x viewport with `addTearDown` resets.
  **Assertions unchanged.**
- Added, in a new `redesign-2026-08 (screen 22)` group:
  1. the selfie row is locked until both ID sides exist, the lock is presentation-only, and
     tapping it opens no camera;
  2. a captured row renders `kycCaptureCaptured`;
  3. `kyc_review_note` renders on the identity step;
  4. `kyc_tos_read_cta` opens `kyc_tos_document_sheet` with `kycTosDocumentBody`.

---

## Wiring

`docs/redesign-2026-08/wiring/22-become-a-jeeber.md` is unchanged and remains the **only** request:
one l10n batch (4 value changes + 10 new keys + hand-rolled getters). No route, DI, theme, kit or
cross-feature change is needed. The code was written against exactly those key names.

---

## Locked decisions

D52 — `kyc_status_view.dart` untouched; no resubmit affordance added anywhere; `kyc_status_resubmit_cta`
still reaches only the `resubmitRequested` branch (both polarities pinned by the existing tests, still
green). D20 — nothing vehicle-shaped; none of the new key names collide with the banned set.
Fee framing — `kycTosAgreeLine` interpolates `kJeebCommissionPercent`; no literal `10`, no
"Commission".
