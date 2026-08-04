# W5 — kyc-submitting

**Status: `done`. One file changed.**

| File | Verdict |
| --- | --- |
| `lib/features/kyc/presentation/widgets/kyc_submitting_view.dart` | re-skinned (presentation only) |

No render exists for this step. It is the wizard frame between screen 22 (`identity`) and the
status view, so the reference used was **its own already-migrated siblings in this directory** —
`kyc_status_view.dart` first, `kyc_identity_step.dart` and `kyc_wizard_screen.dart` second — with
`22-become-a-jeeber.png` for the band rhythm. A single wizard must not contain two visual
languages, and until this change it contained three.

## What was wrong (concrete, not stylistic)

**1. The largest colour block on the screen was orange.** The Ø88 head disc was filled with
`colorScheme.primaryContainer`. After Wave 0 that role is **`#FFDBD1`** — the brand orange's
tone-90 container (`app_theme.dart:88-90,135-136`) — so this screen carried a 6,000px² peach fill
while §4 rations orange and R5 permits it only on what is live or decaying. Its own neighbour in
this directory already says so out loud: `kyc_liveness_prompt_card.dart:38` — *"`primaryContainer`
is the brand orange (#FFDBD1) after the redesign; orange marks decay, not coaching."*

**2. Type came from two ad-hoc `copyWith`s, not the ramp.** `textTheme.headlineSmall.copyWith(w700)`
and `textTheme.bodyMedium` — exactly the pattern §4.2 exists to end, and neither matched the title
its sibling status view renders one frame later.

**3. Content was vertically centred (R1).** `MainAxisAlignment.center` in a fixed `Column`: the
redesign's defining move is a top-aligned block over real emptiness, and this was the opposite. The
fixed column also had no escape at 200% text scale with the long Arabic body.

**4. The gutter was 20 and non-directional.** `EdgeInsets.all(Spacing.large)` — the board's gutter
is 24 everywhere (R12), and `EdgeInsets` does not mirror in Arabic (constraint 5).

## What changed

| Before | After | Why |
| --- | --- | --- |
| `EdgeInsets.all(Spacing.large)` (20, non-directional) | `EdgeInsetsDirectional.fromSTEB(24,24,24,20)` | byte-identical to `_kStatusBodyPadding` in `kyc_status_view.dart`; RTL-safe |
| `Column(mainAxisAlignment: center)` | `ListView` | R1 — top-aligned block, real white emptiness below, and the Arabic body now scrolls instead of overflowing |
| disc `primaryContainer` / glyph `onPrimaryContainer` @48 | disc `surfaceContainerHigh` / glyph `primary` (navy) @40 | de-orange; identical recipe and size to `_GlyphMark` in `kyc_status_view.dart` (Ø88 + `Sizes.threeXLarge`) |
| `headlineSmall.copyWith(w700)` | `context.jeebText.h1` + `colorScheme.primary` | ramp instead of ad-hoc; metric-neutral (h1 is 24/w700, the same pair) but now navy-inked like every sibling title |
| `bodyMedium` + `onSurfaceVariant` | `context.jeebText.body` + `onSurfaceVariant` | the ramp's 13.5/w500/lh19; identical to the status bodies |
| 3 private single-use widget classes (`_SubmittingIcon`, `_SubmittingTitle`, `_SubmittingBodyText`, each taking a `ThemeData` param) | 2 `Text`s inline + one `_SubmittingMark` | the wrappers existed only to pass `theme` down; the mark is the only piece with geometry worth naming |

Vertical rhythm (`large` → `small` → `xLarge` between mark/title/body/spinner) was **already**
identical to `_StatusScaffold` and was left untouched.

## What was deliberately NOT changed

**No `JeebInfoNote`.** The lane note suggests one, but the only existing localized copy that fits —
`kycReviewTimeTitle` / `kycReviewPrivacyNote` — is already rendered as `kyc_review_note` on the
*previous* screen (`kyc_identity_step.dart:482-487`), so repeating it here duplicates the screen the
user just left. Any *new* reassurance line is a new string → `app_en.arb` + `app_ar.arb` + the
hand-authored parser (constraint 4), i.e. a wiring request, and adding copy is not a re-skin. Left
out on purpose; no wiring request filed because the change is not wanted, not merely blocked.

**No `KycReviewMark` (the kyc-review Lottie).** Two reasons, either sufficient:
(a) the scan-line loop means *"a reviewer is reading your document"* — that is the PENDING state one
frame later, and `_PendingBody` already wears it; two consecutive frames sharing a mark erases the
difference between "uploading" and "under review".
(b) `test/kyc_submitting_view_test.dart:163` asserts `find.byIcon(Icons.cloud_upload_outlined)`, and
`test/` is outside this lane.

**No `loading-dots` Lottie.** `OmdsLoadingState` is the wait idiom used by *both* other waits in
this feature (`kyc_status_view.dart:184`, `kyc_wizard_screen.dart:266`). Swapping one of three is
how a feature ends up with two idioms — the exact defect this wave exists to remove. A feature-wide
adoption is a separate, coherent change.

**No chrome change.** The submitting step still gets the Material `OMDSAppBar` because
`_ownsItsChrome` (`kyc_wizard_screen.dart:159-160`) lists only `identity` and `status`. See gaps.

## Constraints check

- **Semantics:** this file contains **no `Semantics(identifier:)`** — the root node uses
  `label:`/`hint:` with `liveRegion: true`, and it is byte-identical (only its `child:` moved). All
  three public `Key`s (`rootKey`, `titleKey`, `spinnerKey`) still resolve to one widget each. No new
  interactive widget was added, so no new identifier was owed.
- **Behaviour:** the whole `_KycSubmittingViewState` polling safety net (JEBV4-259/271 — grace
  timer, 5 scheduled + 3 resume probes, `_inFlight` single-flight, lifecycle seam, dispose) is
  **untouched, byte-for-byte**. No flow, navigation or copy change.
- **No pubspec edit, no new file, no new string, no invented endpoint.**
- **RTL:** `EdgeInsetsDirectional`; `cloud_upload_outlined` is non-directional so it must not mirror.
- **D52/D20:** nothing rejection- or vehicle-related is rendered here.

## Verification

| Check | Result |
| --- | --- |
| `flutter analyze <file>` | **No issues found** |
| `flutter test test/kyc_submitting_view_test.dart test/kyc_wizard_screen_test.dart` | **33/33 pass** |
| `flutter test` kyc suite (liveness, poll schedule, poll controller, status view, wizard cubit) | **69/69 pass** |
| `flutter test test/decision_violations_test.dart` | **4/4 pass** (D56 · D52 · D20 · fee-only) |
| `flutter test test/core/theme/no_raw_semantic_colors_test.dart test/semantics_identifier_surfacing_test.dart` | **31/31 pass** |
| `tool/check_design_tokens.sh` | 1 violation, **pre-existing and in another lane** (`location/…/client_location_screen.dart:1023` raw `TextField`) |

## Remaining gaps vs the neighbour render

1. **Chrome discontinuity (the real one).** Screen 22 opens with a Ø40 back circle + in-body title
   (`JeebTopBar`); so does the status step. The submitting step between them still shows the
   Material `OMDSAppBar`, so the wizard swaps header language twice in three frames. The fix is one
   line in `kyc_wizard_screen.dart:159-160`, which is in this feature but **not the assigned file**,
   and it is not purely cosmetic: `JeebTopBar` draws a back affordance during an in-flight,
   non-cancellable submit. Flagged for an owner decision, not changed.
2. **No progress band.** Screen 22's top band is `Step 1 of 2` over `JeebMeter.segmented`. Carrying
   a settled 2-of-2 meter into the submitting frame would keep that band alive across the whole
   wizard, but it is rendered by `_CaptureProgress` in `kyc_wizard_screen.dart` (same reason as
   above) and it is an addition, not a re-skin.
3. **The head is a static glyph where the board's language is a mark.** Pinned by an out-of-lane
   test assertion; see above. If that assertion is ever relaxed, the honest replacement is a
   *new* upload composition, not `kyc-review`.
4. **A Material circular spinner appears nowhere on the board.** `OmdsLoadingState` is retained for
   intra-feature consistency; `loading-dots` is the brand's own wait and the right end state once
   the feature adopts it in one move.
5. **The bottom ~55% is now plain white with no dock.** That is R1 working as designed here (there
   is no CTA during an in-flight submit), but it is worth stating explicitly since every other
   migrated screen ends in a `JeebCtaFooter`.
