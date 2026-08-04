# 22 · Become a Jeeber (KYC wizard) — change proposal

**Screen id:** `22-become-a-jeeber` · **Wave:** 2 (self-contained) · **Verdict: rebuild**

**Files owned by this lane**

| File | LOC | Fate |
|---|---|---|
| `lib/features/kyc/presentation/kyc_wizard_screen.dart` | 303 | restructure (`_ProgressHeader`, app-bar hoist) |
| `lib/features/kyc/presentation/widgets/kyc_identity_step.dart` | 548 | **rebuild** the body column |
| `lib/features/kyc/presentation/widgets/kyc_capture_tile.dart` | 157 | **rebuild** — 140px square tile → 72px horizontal row |
| `lib/features/kyc/presentation/widgets/kyc_id_alignment_guide.dart` | 188 | **delete** (design replaces it with per-row hints) |
| `lib/features/kyc/presentation/widgets/kyc_liveness_prompt_card.dart` | 95 | keep — becomes the *unlocked* selfie row's expansion |
| `lib/features/kyc/presentation/kyc_status_view.dart` | 950+ | **untouched** — not one of the 24 designed surfaces |
| `lib/features/kyc/presentation/widgets/kyc_submitting_view.dart` | — | untouched |

Blocked on Wave-1 kit steps **1, 2, 3, 4, 7** (`lib/core/widgets/jeeb/` does not exist yet on this branch).

---

## 0. The one thing to read first

The board draws a **four-block** screen (progress → 3 capture rows → info note → terms → docked CTA) and **omits
the two fields the KYC contract requires**: `id_type` and `id_number`. Those are not decoration — E3/JEBV4-197
makes `id_number` required for *every* `KycIdType`, the BFF answers a missing/short value with a field-scoped
RFC-7807 400, and the app has a whole error surface built for it (`KycSubmitFieldError.idNumber` /
`.idType`, `kyc_wizard_cubit.dart:274-281`, `kyc_wizard_cubit.dart:328-348`). **Building the board literally
makes every submit 400.** The proposal below keeps both fields and puts them inside the Step-1 group, which is
also where they belong semantically ("Step 1 of 2 — Your ID").

Everything else on the board is adoptable, and three of its four claims in the note are real improvements.

---

## 1. Layout & structure

### 1.1 Before → after (the whole body column)

| Today (`kyc_identity_step.dart`) | Board | Action |
|---|---|---|
| `Scaffold(appBar: OMDSAppBar(title: kycWizardTitle))` — `kyc_wizard_screen.dart:93-96` | in-body row: Ø40 `surfaceContainerHigh` circle + 20px navy back glyph, gap 14, title 20/w700 navy, pad `14/24/0` | **replace** with `JeebTopBar(leading: back)` on the `identity` step only (§1.3) |
| `_ProgressHeader` — `labelMedium` "Step 1 of 2" + `OMDSLabeledStepperProgress` (`:258-302`) | label row `Step 1 of 2 — Your ID` (12/w700 navy) ↔ `then Selfie` (12/w600 periwinkle); two `flex:1` segments h6 r9, gap 8, first `--jeeb-orange`, second `--jeeb-surface-highest` | **rebuild** (§1.4) |
| `Padding(EdgeInsets.all(Spacing.large))` = 20px gutter (`:201-202`) | `24` gutter everywhere | `EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge)` |
| `kycIdStepTitle` headline + `kycIdStepSubtitle` (`:213-223`) | absent — the progress row *is* the section header | **delete** both `Text`s |
| `KycIdAlignmentGuide` — 240px-wide ID-1 framing rectangle + caption (`:225-228`) | absent; replaced by the per-row hint "Lay it flat, avoid glare" | **delete** the widget + its call site (§9-R2) |
| `KycCaptureTile` front, 140px square, dashed placeholder (`:230-245`) | row: 64×44 r8 thumb + title 14.5/w700 + status sub 12/w600 + trailing `Retake` 12.5/w700 orange, inside r18 / 1.5px brown outline / pad `14/16` | **rebuild** `KycCaptureTile` as a row (§1.5) |
| `KycCaptureTile` back (`:247-262`) | same row, dashed `surface-high` thumb + 18px periwinkle camera glyph + trailing navy `Capture` pill pad `8/15` r999, 12.5/w600 white | same |
| `kycIdTypeLabel` `titleSmall.copyWith(w600)` + 3 `OmdsRadioTile` (`:266-306`) | **absent from the board** | **KEEP** — group into one `JeebOutlinedCard` under a `JeebSectionLabel` (§10-C1) |
| `OmdsTextField` ID number (`:310-341`) | **absent from the board** | **KEEP** in the same card (§10-C1) |
| `_ScrollForSelfieHint` pill (`:352-360`) | absent | **KEEP** — identifier `kyc_scroll_hint` is frozen (§6, §8) |
| `kycSelfieStepTitle` headline + `kycSelfieStepSubtitle` (`:363-373`) | absent | **delete** the headline/subtitle pair; `kycSelfieStepTitle` survives as the selfie row's title |
| `KycLivenessPromptCard` always shown (`:375-388`) | absent while step 2 is locked | render **only** when the selfie step is unlocked and not yet captured (§1.6) |
| `KycCaptureTile` selfie, 140px square (`:390-405`) | row at `opacity .55`: Ø44 `surface-high` circle + 20px periwinkle person glyph, title `Selfie`, sub `Step 2 — unlocks after your ID`, **no trailing action** | **rebuild** + add a `locked` state (§1.6) |
| `_TosAcceptanceCard` = `OMDSSectionCard` + document body + `OmdsCheckboxTile` (`:409-414`, `:506-547`) | 22×22 r7 navy checkbox + 2-line 12.5/w500 brown paragraph, pad `16/24/0`, gap 10, align start | **rebuild** as a flat row; move the document body behind a sheet (§1.7, §10-C5) |
| CTA is the last child of a `Column` after `Expanded(SingleChildScrollView)` (`:419-444`) | `flex:1` spacer, then h56 navy pill r999 + `0 10 24 rgba(11,19,81,.28)`, pad `0/24/32`; disabled = **opacity .45**, not a grey fill | **replace** `OmdsPrimaryButton` with `JeebCtaFooter.single(JeebCtaButton.primary)` (§1.8) |

### 1.2 Resulting order (top → bottom)

```
JeebTopBar(back, "Become a Jeeber")            pad 14/24/0
_CaptureProgress                               pad 20/24/0   ← label row + 2 segments
── Step 1 group ─────────────────────────────  pad 20/24/0, gap 12
  KycCaptureRow(front)                         r18 outlined
  KycCaptureRow(back)                          r18 outlined
  JeebOutlinedCard  ← ID type radios + ID number field   [refusal C1]
  _ScrollForSelfieHint (while selfie missing)  centred pill
── Step 2 group ────────────────────────────────────────────
  KycCaptureRow(selfie, locked | active)       r18 outlined
  KycLivenessPromptCard (only when unlocked & uncaptured)
JeebInfoNote(muted)                            margin 16/24/0
_TosAgreementRow                               pad 16/24/0
Spacer()                                       ← the flex:1
JeebCtaFooter.single(Submit for review)        pad 0/24/32
```

The Step-1 card is deliberately placed **between the ID rows and the selfie row**, not after all three. That
(a) keeps `id_type`/`id_number` inside "Step 1 — Your ID" where they belong, and (b) preserves the fold
boundary that `kyc_scroll_hint` and its two tests depend on (§8).

### 1.3 Top bar

`_WizardScaffold.build` (`kyc_wizard_screen.dart:89-140`) currently builds `Scaffold(appBar: …, body: BlocBuilder…)`.
Hoist the `BlocBuilder` **above** the `Scaffold` so the app bar can be step-dependent:

```dart
appBar: state.step == KycWizardStep.identity ? null : OMDSAppBar(title: l10n.kycWizardTitle, centerTitle: false),
```

The `identity` step then renders `JeebTopBar` as the first child of the body column. `status` / `submitting` /
`schema` keep the OMDS bar untouched — those are JM-042/043 surfaces, not one of the 24, and they carry their
own `kyc_status_back` CTA.

Back action (the board's Ø40 circle): `context.canPop() ? context.pop() : context.go('/')` — the same resolution
`RootAwareBackScope` already gives system BACK for this route (`app_router.dart:472`, `'kyc-status': '/'`).
Do **not** rely on `Navigator.maybePop()` alone; that is the dead-arrow defect
`test/back_arrow_dead_at_root_test.dart` was written for.

### 1.4 Progress block

Replaces `_ProgressHeader` (`kyc_wizard_screen.dart:258-302`), keeping `KycWizardScreen.progressKey` on the
outer `Padding` (a test finds it by key).

```dart
Row(children: [
  Text(l10n.kycWizardProgressStepLabel(current: s.currentCaptureStep,
       total: KycWizardState.totalCaptureSteps, stepName: …),
       style: context.jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700, color: cs.primary)),
  const Spacer(),
  if (s.currentCaptureStep < KycWizardState.totalCaptureSteps)
    Text(l10n.kycWizardNextStepHint(stepName: l10n.kycWizardStepSelfieLabel),
         style: context.jeebText.bodySmall.copyWith(color: semantic.mutedText)),
]),
const SizedBox(height: Spacing.xSmall),          // 9px in the HTML → 8
Row(children: [
  for (var i = 0; i < KycWizardState.totalCaptureSteps; i++) ...[
    if (i > 0) const SizedBox(width: Spacing.xSmall),
    Expanded(child: JeebMeter(value: i < s.currentCaptureStep ? 1 : 0)),   // kit #20: h6 r9
  ],
]),
```

`OMDSLabeledStepperProgress` is dropped: it renders per-step text labels under a single animated bar; the board
wants two discrete segments and moves the labels into the header row.

**Semantics of the bar changed and that is deliberate.** Today the label uses
`completedCaptureSteps < 1 ? 1 : completedCaptureSteps` while the bar uses `completedCaptureSteps` — the two
disagree by one. The board unifies them on the *current* step: segment 1 is filled while you are on step 1.
Add one derived getter (§4.1); do not change `completedCaptureSteps` itself (`KycStatusView` reads it).

### 1.5 The capture row (`KycCaptureTile` rebuilt)

Same class name and same public API (`tileKey`, `label`, `photo`, `onTap`, `isProcessing`, `captureCtaSemantic`)
so nothing above it moves. New params: `hint`, `state` (`pending | captured | locked`), `thumbShape`
(`rect64x44 | circle44`).

Container: `JeebOutlinedCard(radius: 18, padding: EdgeInsetsDirectional.fromSTEB(16,14,16,14))` — kit #3,
white fill, `1.5px colorScheme.outline`, **no shadow** (R7).

| Slot | Spec (HTML) | Dart |
|---|---|---|
| thumb, captured | 64×44 r8 `--jeeb-navy` + white 20px ID glyph | `ClipRRect(OmdsBorderRadius.xSmall)` over `Image.memory(photo.bytes)`; navy + `Icons.badge_rounded` as the `errorBuilder` fallback (§10-C3) |
| thumb, pending | 64×44 r8 `--jeeb-surface-high`, **1.5px dashed** `--jeeb-brown-outline`, 18px periwinkle camera glyph | `CustomPainter` dashed border inside the kit-free feature widget; fill `cs.surfaceContainerHigh`, glyph `Icons.photo_camera_rounded` in `mutedText` |
| thumb, locked (selfie) | Ø44 circle `--jeeb-surface-high`, 20px periwinkle person glyph | `Container(shape: BoxShape.circle)` |
| title | 14.5/w700 navy | `context.jeebText.cardTitle` (15.5/w700) — 1px over, nearest ramp entry, no `fontSize:` allowed in `lib/features` |
| sub, captured | 12/w600 `rgb(46,125,50)` + `✓` | `jeebText.bodySmall`, colour `context.jeebRoles.success` (`#1B7A3D`) per the §4.1 token-bridge row "KYC quality green (22)" — **never** the CSS `#43A047`, which fails the WCAG gate |
| sub, pending / locked | 12/w500 periwinkle | `jeebText.bodySmall` + `JeebSemanticColors.mutedText` |
| trailing, captured | `Retake` 12.5/w700 orange, text-only | `JeebCtaButton.accentText` (kit #2) — orange via `context.jeebRoles.accent` |
| trailing, pending | `Capture` pill pad `8/15` r999 navy, white 12.5/w600 | `JeebSelectChip(role: inlineAction, selected: true)` (kit #6) or `JeebCtaButton.primary(dense)` |
| trailing, locked | **none** | omit |
| processing | — | keep today's `OmdsLoadingState` in the trailing slot (row height unchanged) |

Row height ≈ 44 + 28 + 3 = **75px** vs today's **140px**. Three rows + gaps go from 452px to 249px — that is
most of the density win (R1/R12).

### 1.6 The locked selfie step (new behaviour)

`state: locked` when `!(hasIdFront && hasIdBack)`: whole row at `Opacity(0.55)`, `onTap: null`,
`Semantics(enabled: false)`, sub = `kycSelfieLockedHint` ("Step 2 — unlocks after your ID"), no trailing action.

**The lock is UI-only.** Do NOT add a guard to `KycWizardCubit.captureSelfie()` — five tests in
`kyc_wizard_screen_test.dart` call `cubit.captureSelfie()` directly to reach the submit path
(`:209`, `:243`, `:281`, `:328`, `:381`, `:463`); a cubit guard breaks all of them and would also break the
JM-040 Maestro rationale (ID photos are not camera-drivable).

`KycLivenessPromptCard` (`livenessPromptKey` preserved) renders only when `unlocked && !hasSelfie` — the board
has no room for it while step 2 is locked, and it is exactly the coaching you want at the moment step 2 opens.

### 1.7 Terms row

Delete `_TosAcceptanceCard` (`:506-547`). New feature-local `_TosAgreementRow`:

```dart
Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Semantics(identifier: 'kyc_tos_accept', child: Checkbox(
    key: KycIdentityStep.tosCheckboxKey, value: accepted, onChanged: onChanged,
    shape: const RoundedRectangleBorder(borderRadius: OmdsBorderRadius.xSmall), // r8 ≈ board r7
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
  const SizedBox(width: Spacing.small),
  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l10n.kycTosAgreeLine(percent: kJeebCommissionPercent),
         style: context.jeebText.body.copyWith(color: cs.onSurfaceVariant)),
    JeebCtaButton.text(label: l10n.kycTosReadFullCta, identifier: 'kyc_tos_read_cta', onTap: _openTosSheet),
  ])),
]);
```

Checked state comes free: Material `Checkbox` fills with `colorScheme.primary` (navy) + white check, which is
exactly the board's 22×22 navy square. `10%` **must** be the `{percent}` placeholder fed by
`kJeebCommissionPercent` (`lib/core/jeeb_commission.dart:78`) — never a literal in the ARB (§10-C8).

### 1.8 Footer

```dart
JeebCtaFooter.single(child: JeebCtaButton.primary(
  identifier: 'kyc_submit_cta', key: KycIdentityStep.submitButtonKey,
  label: state.step == KycWizardStep.submitting ? l10n.kycWizardSubmitting : l10n.kycWizardSubmit,
  isEnabled: state.step != KycWizardStep.submitting && state.submission.hasSelfie
             && state.submission.hasValidIdNumber,
  onTap: () => cubit.submit()));
```

The enable predicate is copied verbatim from `kyc_identity_step.dart:439-441` — JEBV4-295 pinned it, three
tests assert it, and it does **not** change. The board's disabled treatment is `opacity: .45` on the navy pill:
`JeebCtaButton.primary` must render disabled as a 45%-opacity navy pill, not a grey `surfaceContainerHighest`
fill — flag this to the kit lane (§11).

The board's copy `Submit for review` already matches `kycWizardSubmit` byte-for-byte. No change.

---

## 2. Tokens — every literal / stock-theme reach in the current files

The two files are already hex-free; the debt is stock-`TextTheme` reaches, geometry, and OMDS-default surfaces.

| Where | Today | Becomes |
|---|---|---|
| `kyc_wizard_screen.dart:287` | `textTheme.labelMedium` | `context.jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700)` + `cs.primary` |
| `kyc_wizard_screen.dart:273-278` | `EdgeInsets.fromLTRB(Spacing.large, …)` (20 gutter) | `EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.large, Spacing.xLarge, 0)` |
| `kyc_wizard_screen.dart:290-297` | `OMDSLabeledStepperProgress` | 2 × `JeebMeter` in a `Row` (kit #20) |
| `kyc_wizard_screen.dart:241` | `Text(l10n.kycErrorSchemaLoadFailed)` (unstyled) | `context.jeebText.body` + `cs.onSurfaceVariant` |
| `kyc_wizard_screen.dart:247-250` | `OMDSOutlinedButton` | `JeebCtaButton.outline` (keeps `kyc_wizard_retry_cta`) |
| `kyc_identity_step.dart:202` | `EdgeInsets.all(Spacing.large)` | `EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge)` |
| `kyc_identity_step.dart:215-217` | `headlineSmall.copyWith(w700)` ×2 | deleted (headline blocks removed) |
| `kyc_identity_step.dart:222`, `:372` | `bodyMedium` ×2 | deleted |
| `kyc_identity_step.dart:268-270` | `titleSmall.copyWith(w600)` | `JeebSectionLabel(l10n.kycIdTypeLabel)` (kit #10, 12.5/w700/ls1.2/uppercase/`mutedText`) |
| `kyc_identity_step.dart:302-304` | `bodySmall.copyWith(color: cs.error)` | `context.jeebText.caption` + `cs.error` |
| `kyc_identity_step.dart:471` | `colorScheme.primaryContainer` on the scroll hint | `cs.surfaceContainerHigh` + navy ink — `primaryContainer` is now the **orange** container `#FFDBD1` (`app_theme.dart:135`); an orange pill here breaks R5 (orange marks what decays) |
| `kyc_identity_step.dart:487-489` | `labelMedium.copyWith(w600)` | `context.jeebText.bodySmall` |
| `kyc_liveness_prompt_card.dart:39` | `primaryContainer.withValues(alpha: 0.6)` | `cs.surfaceContainerHigh` (same reason — it currently paints a 60% orange panel) |
| `kyc_liveness_prompt_card.dart:41` | `OmdsBorderRadius.small` (12) | `OmdsBorderRadius.medium` (16) — the board's note radius |
| `kyc_liveness_prompt_card.dart:47-50` | `titleSmall.copyWith(w700)` | `context.jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700)` |
| `kyc_capture_tile.dart:24` | `tileHeight = 140` | gone (row height is content-driven) |
| `kyc_capture_tile.dart:49,56,116` | `OmdsBorderRadius.small` (12) | thumb `OmdsBorderRadius.xSmall` (8); card radius 18 lives inside `JeebOutlinedCard` |
| `kyc_capture_tile.dart:53-62` | `surfaceContainerHighest` / `surfaceContainerLow` fills, `outlineVariant` border, `width: hasPhoto ? 1 : 1.5` | card is always `1.5px cs.outline` (brown); thumb fill `cs.surfaceContainerHigh` |
| `kyc_capture_tile.dart:90` | `Sizes.twoXLarge` (32) camera glyph | 18px glyph → `Sizes.large` (20) is the nearest token; 20px is the R10 content size |
| `kyc_capture_tile.dart:95` | `labelLarge.copyWith(cs.primary)` | gone (label moves to the row title) |
| `kyc_capture_tile.dart:135-151` | `PositionedDirectional` label chip over the preview | gone (the row has a real title column) |
| new — CTA shadow | none | `JeebShadows.ctaNavy` (`0 10 24 rgba(11,19,81,.28)`) |
| new — greens | none | `context.jeebRoles.success` for the `Captured ✓` line |
| new — orange | none | `context.jeebRoles.accent` for `Retake` and the filled progress segment |
| new — periwinkle | none | `Theme.of(context).extension<JeebSemanticColors>()!.mutedText` for every sub-line and `then Selfie` |

**Not tokenised:** the exact 64×44 thumb, the 18px card radius, the 6px meter height, the dashed stroke. All
of those live inside `lib/core/widgets/jeeb/` kit widgets, or inside a `CustomPainter` constant in the feature
file (`tool/check_design_tokens.sh` only bans `SizedBox(width:/height: N)`, `EdgeInsets.<x>(N)`,
`BorderRadius.circular(N)`, `fontSize: N`, `Color(0x…)`, `Colors.*` — a `static const double _thumbW = 64;`
consumed by `Container(width: _thumbW)` is clean, but prefer the kit).

---

## 3. Shared components consumed

| Kit widget | Use here | Replaces |
|---|---|---|
| **#1 `JeebTopBar`** (`leading: back`) | screen header, identity step only | `OMDSAppBar` (`kyc_wizard_screen.dart:93`) |
| **#2 `JeebCtaButton` + `JeebCtaFooter.single`** | Submit pill; `accentText` for `Retake`; `outline` for retry; `text` for `Read the full terms` | `OmdsPrimaryButton` (`:424`), `OMDSOutlinedButton` (`:247`) |
| **#3 `JeebOutlinedCard`** (radius 18) | all three capture rows **and** the ID-type/number card | `KycCaptureTile`'s `Container` (`:50-63`), `OMDSSectionCard` (`:522`) |
| **#6 `JeebSelectChip`** (`role: inlineAction`, selected) | the `Capture` pill | — |
| **#10 `JeebSectionLabel`** | `ID TYPE` above the identity card | `titleSmall.copyWith(w600)` (`:268`) |
| **#20 `JeebMeter`** (h6 r9) ×2 in a `Row` | the two progress segments | `OMDSLabeledStepperProgress` (`:290`) |
| **#22 `JeebInfoNote`** (`tone: muted`, leading 19px clock, `title` + `body`) | the review-time / privacy note | net-new on this screen |
| `JeebShadows.ctaNavy` | submit pill | net-new |

**Not** consumed: `JeebStepper` (#11) — that is the 26-node done/active/pending stepper for screens 12 and 18;
this screen's progress is a two-segment bar, and #11 carries the frozen `tracking_step_*` identifiers.
**Not** consumed: `JeebNavySurfaceCard` (#4) — nothing on this board screen is a navy surface except the CTA.

---

## 4. New functionality, and what it needs from the state layer

### 4.1 Two derived getters — additive, no new data (`kyc_wizard_state.dart`)

```dart
/// The step the user is ON (1-based), for the header + the segment bar.
/// `completedCaptureSteps` stays as-is — KycStatusView reads it.
int get currentCaptureStep =>
    (completedCaptureSteps + 1).clamp(1, totalCaptureSteps);

/// UI-only gate for the selfie row. Never enforced in the cubit — five
/// wizard tests drive `captureSelfie()` directly (JEBV4-295 / JM-040).
bool get isSelfieUnlocked => submission.hasIdFront && submission.hasIdBack;
```

Both are pure derivations of fields already in `KycSubmission`. Do **not** add them to `props` (derived).
No cubit change, no gateway change, no DI change.

### 4.2 The "Read the full terms" sheet — new, and required by §10-C5

`showModalBottomSheet` from the identity step, rendering `l10n.kycTosStepTitle` + `l10n.kycTosDocumentBody`
(the strings that exist today at `:412`, `:523`). Root `Semantics(identifier: 'kyc_tos_document_sheet')`.
No new route, no new endpoint. `KycContractTemplate.documentUrl` exists on the fetched template but the
template is only fetched lazily at submit time (`kyc_wizard_cubit.dart:288-289`) — **do not** wire the URL:
that would need an eager fetch and a web view neither of which is in scope. Leave:
`// TODO(redesign-24): render contractTemplate.documentUrl once the template is fetched eagerly.`

### 4.3 Live capture-quality feedback — **REFUSED, half of it** (§10-C2)

The note promises "live quality feedback ('looks sharp ✓' / glare hint)".

* The **glare hint** is static coaching copy — buildable now, shipped as the row `hint`.
* The **verdict** ("looks sharp") is not. `PhotoAttachment` carries `id`, `bytes`, `originalSizeBytes`,
  `source` (`photo_attachment.dart:14-40`) — no sharpness, blur, glare or face-detect signal. `KycSubmission`
  carries none either. Computing one needs an image-processing dependency, and **constraint 3 forbids adding
  a package**. Ship the honest half:

  ```dart
  // TODO(redesign-24): the board's "looks sharp ✓" verdict needs a capture-quality
  // signal the app does not have — omitted, not faked.
  ```

  Rendered: `Captured` + `Icons.check_rounded`, both in `context.jeebRoles.success`.
  (`originalSizeBytes`/`sizeBytes` *would* support a "compressed from 3.1 MB" line — honest but noise; offered,
  not recommended.)

### 4.4 Everything else the note claims is buildable today

| Note claim | Source | Verdict |
|---|---|---|
| "shows what's next (`then Selfie`)" | `KycWizardState.currentCaptureStep` (§4.1) | build |
| "selfie step visibly locked until the ID is done" | `hasIdFront && hasIdBack` | build (UI-only) |
| "review-time expectation up front" | already product copy — `kycStatusPendingBody` ships "up to 24 hours" | build; reword to the board's "under 24 hours" |
| "encryption promise up front" | **not verifiable by this repo** | **hold** — §10-C4 |
| "terms line spells out the 10% deal" | `kJeebCommissionPercent` | build via ICU placeholder |

---

## 5. New routes

**None.** `/profile/kyc` (name `kyc-status`, `app_router.dart:899-906`) is unchanged and stays in
`AppRouter.backFallbacks` (`:472`). The full-terms surface is a modal sheet, not a route — adding a `/terms`
route would need a document source this screen does not have.

---

## 6. Semantics identifiers

### 6.1 Existing — every one must still be emitted

| Identifier | Today | After |
|---|---|---|
| `kyc_wizard_root` | `kyc_wizard_screen.dart:100` | unchanged, still wraps the whole body |
| `kyc_wizard_retry_cta` | `:244` | moves onto `JeebCtaButton.outline` |
| `kyc_id_front_upload` | `kyc_identity_step.dart:231` | wraps the front `KycCaptureTile` row |
| `kyc_id_back_upload` | `:248` | wraps the back row |
| `kyc_id_type_picker` | `:274` | moves inside the new `JeebOutlinedCard` |
| `kyc_id_type_national_id` / `_passport` / `_residency` | `:281` (templated on `type.wire`) | unchanged — keep `OmdsRadioTile`s |
| `kyc_id_number_input` | `:311` | unchanged `OmdsTextField`, now inside the card |
| `kyc_selfie_upload` | `:391` | wraps the selfie row (also in the `locked` state) |
| `kyc_submit_cta` | `:421` | moves onto `JeebCtaButton.primary` |
| `kyc_scroll_hint` | `:467` | kept, restyled to `surfaceContainerHigh` |
| `kyc_tos_accept` | `:533` | moves onto the flat `Checkbox` |

Widget `Key`s that must also survive (devtool + widget tests): `KycWizardScreen.rootKey`, `.progressKey`,
`.backLeadingKey`; `KycIdentityStep.frontTileKey`, `.backTileKey`, `.idNumberFieldKey`,
`.idTypeNationalIdKey`, `.idTypePassportKey`, `.idTypeResidencyKey`, `.selfieTileKey`, `.livenessPromptKey`,
`.tosCheckboxKey`, `.submitButtonKey`, `.scrollHintKey`.
`KycIdAlignmentGuide.rootKey` / `.frameKey` die with the widget (§9-R2).

### 6.2 New

| Identifier | Element | Notes |
|---|---|---|
| `kyc_wizard_back` | `JeebTopBar` back circle | also wire the already-declared-but-unused `KycWizardScreen.backLeadingKey` onto it |
| `kyc_review_note` | `JeebInfoNote` root | `container: true`, non-interactive; gives Maestro a hook for the review-time promise |
| `kyc_tos_read_cta` | "Read the full terms" text button | `button: true` |
| `kyc_tos_document_sheet` | modal sheet root | `container: true, explicitChildNodes: true` |

Every wrapper stays an **explicit** `Semantics(identifier: …)` — never OMDS's `identifier:` param (§7.5,
stale local clone). Parent wrappers around children need `container: true` + `explicitChildNodes: true`.

---

## 7. RTL

| Element | Risk | Build rule |
|---|---|---|
| Two-segment progress bar | the *first* segment must be the leading one | plain `Row` of `Expanded` — auto-mirrors. Never `Stack`/`Positioned(left:)` |
| Header label ↔ `then Selfie` | — | `Row` + `Spacer()`, not `MainAxisAlignment` on hardcoded sides |
| Capture row (thumb → text → action) | — | `Row` + `EdgeInsetsDirectional`; the trailing `Retake`/`Capture` lands at the visual left under `ar` automatically |
| `Captured ✓` | check must follow the text in *reading* order | put `Text` then `Icon` in the same `Row` — do not `Positioned` it |
| Info-note leading clock glyph | — | `Row` with the glyph first + `EdgeInsetsDirectional` |
| ToS checkbox | — | `Row`, checkbox first; `crossAxisAlignment: start` so a 2-line AR paragraph aligns to its top |
| `10%` in the terms line | AR places `٪`/`%` differently and may reorder the clause | ICU placeholder `{percent}`, never string concatenation |
| `Step {current} of {total}` | AR renders Arabic-Indic numerals | keep them as ICU `int` placeholders (today's behaviour); **no** LTR isolate — these are counters, not money |
| ID-number field | already handled | keep `ArabicIndicDigitsFormatter` (`:330`) ahead of `digitsOnly` (`:331-332`) |
| `Opacity(0.55)` locked row | direction-agnostic | fine |
| 200% text scale | the row must grow, not clip | thumb fixed 64×44, text column `Expanded`, trailing action in a `Flexible`; do not set a fixed row height (this is why `KycCaptureTile.tileHeight = 140` is deleted rather than re-valued) |

---

## 8. Test impact

`grep -rl` over `test/` for this screen: `kyc_wizard_screen_test.dart` (17 tests), `kyc_wizard_cubit_test.dart`,
`kyc_id_alignment_guide_test.dart`, `kyc_liveness_prompt_card_test.dart`, `kyc_status_view_test.dart`,
`kyc_submitting_view_test.dart`. No goldens exist for KYC (`find test -name '*.png'` → only 18 and 24).

| Test | Verdict |
|---|---|
| `identity screen renders all three uploads … and no vehicle step` (`:150`) | **passes** — all 8 identifiers preserved, `kyc_vehicle_step` still absent |
| `progress header reflects 2 capture steps` (`:184`) | **passes** — `progressKey` stays on the new block |
| `AC4: tapping kyc_submit_cta chains to onboarding-funding` (`:196`) | **passes** |
| `JEBV4-271 auto-approved submit …` (`:229`) | **passes** — status branch untouched |
| `JEBV4-259/271 hung submit auto-recovers` (`:267`) | **passes** |
| `JEBV4-271 round 3 role-arrived signal` (`:310`) | **passes** |
| `submit is reachable without driving the ID front/back camera` (`:357`) | **passes — and it is the reason the selfie lock is UI-only.** It captures the selfie through the cubit with both ID slots empty; a cubit-level lock would fail it |
| `blank/invalid ID number disables the CTA` (`:395`) | **passes** — the field and the enable predicate are untouched |
| `submit-disabled-without-selfie` (`:431`) | **passes** |
| `kyc_scroll_hint visible before / hidden once captured` (`:474`) | **passes** — same visibility rule, same identifier |
| `tapping kyc_scroll_hint scrolls towards the selfie tile` (`:495`) | **AT RISK — legitimate, needs a test edit.** Its precondition is `find.byKey(selfieTileKey).hitTestable()` → `findsNothing`, i.e. "the selfie tile starts below the fold". The redesign shortens the column by ~340px; in the default 800×600 harness the selfie row lands near the fold and the assertion becomes viewport-luck. **Fix by pinning the viewport** (`tester.view.physicalSize = Size(360*dpr, 640*dpr)`), not by deleting the assertion — the affordance and its identifier both survive |
| `typing a too-short national ID surfaces the inline error` (`:559`) | **passes** |
| `Eastern Arabic-Indic digits normalize` (`:579`) | **passes** |
| `switching the ID type to passport …` (`:598`) | **passes** — `OmdsRadioTile`s and their keys are kept; only their container changes |
| `resubmit() clears the visible ID-number text` (`:625`) | **passes** |
| `re-entry on approved / rejected / resubmit-requested` (`:650`, `:686`, `:728`, `:757`) | **passes** — `KycStatusView` untouched |
| `kyc_wizard_cubit_test.dart` | **passes** — cubit unchanged; the two new state getters are derived and not in `props` |
| `kyc_liveness_prompt_card_test.dart` | **passes** — widget kept, only its container colour/radius change; the test asserts text + icons |
| `kyc_id_alignment_guide_test.dart` | **DELETE with the widget** (§9-R2). This is the one coverage reduction in the proposal and it is owner-visible |
| `decision_violations_test.dart` D20 ARB scan (`:154-174`) | **passes** — none of the new keys collide with `kycWizardStepVehicleLabel` / `kycVehicleStepTitle` / `kycVehicleRegistrationLabel` / `kycStatusResubmitCta` |
| `core/jeeb_commission_test.dart` negative scan | **passes** — the terms line uses `kJeebCommissionPercent`, not a second literal |
| `core/theme/no_raw_semantic_colors_test.dart` | **no impact** — the 18-file list contains `offer_kyc_gate_screen.dart`, not any `features/kyc/` file, and nothing listed is moved |
| `core/router/back_nav_all_routes_test.dart`, `back_arrow_dead_at_root_test.dart` | **passes** — no route or fallback changes; the in-body back uses `canPop ? pop : go('/')` |
| `tool/check_design_tokens.sh` | must stay clean — all design-exact px live in `lib/core/widgets/jeeb/` or as named `static const double` in the feature widget |

Maestro: `.maestro/flows/jm-040-kyc-identity.yaml` asserts `kyc_wizard_root`, `kyc_id_front_upload`,
`kyc_submit_cta`, and `assertNotVisible: kyc_vehicle_step` (`:138`, `:151`, `:154`, `:145`). All preserved.
The flow is already documented RED for unrelated seam reasons; this change neither fixes nor worsens it.

---

## 9. Owner-visible removals

* **R1 — `kycIdStepTitle` / `kycIdStepSubtitle` / `kycSelfieStepSubtitle` headline blocks disappear.**
  The board replaces them with the progress row and the per-row hints. Straight adoption.
* **R2 — `KycIdAlignmentGuide` is deleted** (widget + `test/kyc_id_alignment_guide_test.dart`). It is a 240px
  ID-1 framing rectangle with corner ticks; the board replaces it with a 12px hint on the row itself. It is
  also the single largest density offender on the screen (R1). Its coaching value survives as the ID rows'
  `hint` (the shorter `kycIdCaptureHint`). If the owner wants the framing visual kept, the honest home is the
  camera surface, not this list — and that is not a screen this board covers.

---

## 10. Conflicts and refusals

**C1 — the board omits `id_type` and `id_number`. REFUSED.**
E3/Q-042/JEBV4-197 ratified `national_id | passport | residency` and made `id_number` contract-required for
every one of them (`kyc_identity_step.dart:68-82`, `kyc_submission.dart:66-80`). The client already hard-gates
on it (`hasValidIdNumber`, `kyc_wizard_cubit.dart:274-281`) and the BFF returns a field-scoped 400 without it
(`KycSubmitFieldException` → `_mapFieldError`, `:406-415`). Shipping the board's four blocks alone makes every
submit fail. Keep both controls, grouped in one `JeebOutlinedCard` inside the Step-1 block.

**C2 — "Captured · looks sharp ✓". REFUSED (the verdict half).**
No sharpness/blur/glare signal exists anywhere in the app, and constraint 3 forbids the dependency that would
produce one. §7.6 already lists "capture-quality verdicts (22)" as genuinely suspect. Ship `Captured` + `✓`.

**C3 — the captured thumbnail is drawn as a navy icon slab. DIVERGE (deliberately).**
The board's row-1 thumb is a navy rectangle with an ID glyph — i.e. it drops the photo preview the app shows
today (`kyc_capture_tile.dart:112-134`). Removing the only visual confirmation of *what you captured* is a
regression the note does not ask for. Render the real bytes inside the same 64×44 r8 box, with the navy+glyph
as the `errorBuilder` fallback (which stub/test payloads already hit). Visually identical shape; strictly more
information.

**C4 — "Your documents are encrypted and never shown to customers". HOLD the first clause.**
"Never shown to customers" is verifiable: KYC assets go to the CDN gateway and are read back only by the
back-office. "Encrypted" is a claim about storage-at-rest that this repo cannot substantiate — the app knows
only that it POSTs over TLS. Shipping an unverified security promise in a signed-terms context is a legal risk,
not a copy preference. **Ship `kycReviewPrivacyNote` = "Your documents are never shown to customers."** and
raise the encryption clause for owner/legal ratification; adding it later is a one-key edit.

**C5 — the board deletes the ToS document body. PARTIAL REFUSAL.**
Tapping submit signs a contract (`signContract(templateId, tosVersion, signatureBlob)`,
`kyc_wizard_cubit.dart:290-295`) and stamps `tos_accepted_version` onto the submission. A one-line summary with
no way to read the document is a legal regression, not a design simplification. Adopt the one-line agreement
row **and** keep `kycTosDocumentBody` reachable behind `kyc_tos_read_cta` → a modal sheet. No new route.

**C6 — D52 (final rejection ⇒ no resubmit). NO CONFLICT.** The board has no resubmit affordance; the rejection
branch lives on `KycStatusView`, which this lane does not touch. `kyc_status_resubmit_cta` must remain
reachable **only** on the `resubmitRequested` branch (`kyc_wizard_screen_test.dart:728-755`).

**C7 — D20 (no vehicle contract). NO CONFLICT.** Nothing vehicle-shaped on the board. `kyc_vehicle_step` must
stay absent, and none of the new l10n keys may resemble the four banned names.

**C8 — the single 10% literal.** The board writes `10% fee per won offer` as prose. Render it as
`kycTosAgreeLine(percent: kJeebCommissionPercent)`. A hardcoded `10%` in the ARB would slip past
`jeeb_commission_test.dart`'s numeric scan (it looks for `0.10` in `lib/**.dart`) while still violating the
plan's locked decision — this is exactly the class of second copy that test exists to prevent.

**C9 — density (R1) cannot be fully honoured here, and must not be faked.**
The board's content ends at ~62% of a 956pt canvas. With the two mandatory fields restored (C1) the column is
~920pt and still scrolls on a 360×800 S22. The `flex:1` spacer + docked footer structure is preserved and the
screen loses ~340pt of chrome (the alignment guide + two headline blocks + three 140px tiles → three 75px
rows), which is the real win. **Do not buy the empty lower half by deleting required inputs.**

---

## 11. Wiring requests (integrator-owned / other lanes)

**l10n batch** — `lib/l10n/app_en.arb` + `app_ar.arb` + getters (4-edit recipe; the parity gate fails both
directions and rejects `value == key`):

| Key | EN | AR (proposed) | Action |
|---|---|---|---|
| `kycWizardTitle` | `Become a Jeeber` | `كن جيبر` | **value change** (was "Verify your identity"); single consumer, no test pins it |
| `kycWizardProgressStepLabel` | `Step {current} of {total} — {stepName}` | `الخطوة {current} من {total} — {stepName}` | new (supersedes `kycWizardProgressLabel`) |
| `kycWizardNextStepHint` | `then {stepName}` | `ثم {stepName}` | new |
| `kycWizardStepIdTitle` | `Your ID` | `هويتك` | new |
| `kycIdFrontLabel` | `ID — front` | `الهوية — الوجه الأمامي` | value change (was "Front side") |
| `kycIdBackLabel` | `ID — back` | `الهوية — الوجه الخلفي` | value change (was "Back side") |
| `kycSelfieStepTitle` | `Selfie` | `صورة شخصية` | value change (was "Take a selfie"); still the selfie row title |
| `kycIdCaptureHint` | `Lay it flat, avoid glare` | `ضعها مسطّحة وتجنّب الانعكاسات` | new |
| `kycCaptureCaptured` | `Captured` | `تم التقاطها` | new |
| `kycSelfieLockedHint` | `Step 2 — unlocks after your ID` | `الخطوة ٢ — تُفتح بعد إتمام هويتك` | new |
| `kycReviewTimeTitle` | `Review usually takes under 24 hours` | `تستغرق المراجعة عادةً أقل من ٢٤ ساعة` | new |
| `kycReviewPrivacyNote` | `Your documents are never shown to customers.` | `لا تُعرض مستنداتك على العملاء أبدًا.` | new — encryption clause held (C4) |
| `kycTosAgreeLine` | `I agree to the Jeeber terms — deliver what's asked, collect cash honestly, {percent}% fee per won offer.` | `أوافق على شروط جيبر — التوصيل كما هو مطلوب، وتحصيل النقد بأمانة، ورسوم {percent}٪ عن كل عرض تفوز به.` | new, `{percent}` = `int` |
| `kycTosReadFullCta` | `Read the full terms` | `اقرأ الشروط كاملة` | new |

Orphaned after this change (warn-level in `l10n_parity_check.sh`; integrator may delete both locales):
`kycWizardProgressLabel`, `kycIdStepTitle`, `kycIdStepSubtitle`, `kycSelfieStepSubtitle`,
`kycIdAlignmentGuideTitle`, `kycIdAlignmentGuideCaption`, `kycTosStepSubtitle`.
**Keep** `kycTosDocumentBody`, `kycTosStepTitle`, `kycTosSignAndSubmit`, `kycIdRetake`, `kycIdCaptureCta`,
`kycSelfieRetake`, `kycSelfieCaptureCta`, `kycScrollForSelfieHint`.

**Kit lane (Wave 1)** — two spec details this screen needs and the plan does not state:
1. `JeebCtaButton.primary` disabled state = **navy at 45% opacity**, not a grey fill (HTML `opacity: 0.45`).
2. `JeebOutlinedCard` must accept a `radius: 18` and an `EdgeInsetsDirectional` content padding of `14/16`.

**Router / DI:** no change. **pubspec:** no change (and note this screen is a live argument against adding an
image-quality package — see C2).

---

## 12. Risks

1. `tapping kyc_scroll_hint scrolls …` becomes viewport-sensitive after the ~340pt shortening (§8). Pin the
   viewport in the test rather than relaxing the assertion.
2. Deleting `KycIdAlignmentGuide` + its test is the only coverage reduction here; it is owner-visible (§9-R2).
3. `kycWizardTitle` changes from "Verify your identity" to "Become a Jeeber". No test pins it, but it is the
   screen's name in the profile/dashboard entry flow — one-line revert if the owner disagrees.
4. The encryption clause (C4) is held pending ratification; the board's info note ships one sentence shorter.
5. This lane cannot start until Wave-1 steps 1–4 and 7 land (`lib/core/widgets/jeeb/` is absent today).
6. `KycStatusView` keeps the OMDS app bar while the identity step gets the in-body bar — a deliberate seam.
   If the owner wants uniform chrome across the wizard, that is a follow-up on the status view, not this screen.
