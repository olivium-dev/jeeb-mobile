# 22 · Become a Jeeber (KYC wizard) — REVISED instruction set (authoritative)

Reviewed against: `screens/22-become-a-jeeber.{png,html,note.md}`, the live source of all five
lane files, `kyc_wizard_state.dart`, `kyc_wizard_cubit.dart`, `kyc_submission.dart`,
`photo_attachment.dart`, `kyc_wizard_screen_test.dart` (17 tests, every cited line re-read),
`kyc_liveness_prompt_card_test.dart`, `kyc_id_alignment_guide_test.dart`,
`test/decision_violations_test.dart`, `test/core/theme/no_raw_semantic_colors_test.dart`,
`tool/check_design_tokens.sh`, `.maestro/flows/jm-040-kyc-identity.yaml`, `03-WAVE1-KIT.md`, and
the shipped kit source in `lib/core/widgets/jeeb/`. Every `file:line` below was re-checked on
2026-08-03. Where this document contradicts the original proposal, **this document wins**.

Verdict: **rebuild** of the identity-step presentation tree in place. Cubit, gateway, routes, DI
untouched. Two additive derived getters on `KycWizardState` (lane-owned file). The only wiring is
one l10n batch (§8) — no route, DI, theme, or kit request.

**Locked decisions in force:** D52 — a FINAL KYC rejection offers NO resubmit CTA; the rejection
branch lives in `kyc_status_view.dart`, which this lane must not touch (`kyc_status_resubmit_cta`
stays reachable only on the `resubmitRequested` branch — `kyc_wizard_screen_test.dart:728-755`
pins both polarities). D20 — nothing vehicle-shaped; the D20 ARB scan
(`decision_violations_test.dart:155-174`) bans the key names `kycWizardStepVehicleLabel`,
`kycVehicleStepTitle`, `kycVehicleRegistrationLabel`, `kycStatusResubmitCta` — none of §8's new
keys collide. Fee framing — the terms line interpolates `kJeebCommissionPercent`
(`lib/core/jeeb_commission.dart:78`), never a literal `10`, and never the word "Commission".

---

## 1. What changed vs the original proposal

### CUT

- **The entire "Blocked on Wave-1 kit steps 1,2,3,4,7 / `lib/core/widgets/jeeb/` does not exist"
  framing.** The kit SHIPPED (31 files, 476 tests green). Consume it; never build a stand-in or a
  private copy of a kit widget.
- **Both §11 kit-lane wiring requests — already satisfied by the shipped kit.** (1) The disabled
  primary CTA is already navy at 45% opacity: `JeebCtaButton.disabledFillOpacity = 0.45`
  (`03-WAVE1-KIT.md` §2.2), shadow dropped when disabled. (2) `JeebOutlinedCard` already takes
  `radius:` and an `EdgeInsetsGeometry padding:` (§2.1). Nothing to request.
- **The hand-rolled two-`JeebMeter` progress `Row`** (proposal §1.4's `for`-loop of
  `JeebMeter(value:)` + `SizedBox` glue). The kit ships **`JeebMeter.segmented(steps:, filled:)`**
  built and measured from THIS screen ("22's two-step KYC progress: n `flex:1` segments, h6,
  gap 8" — `jeeb_meter.dart` header, `03-WAVE1-KIT.md` §2.7). Hand-rolling the row is exactly the
  private-copy defect. Task 3 uses the segmented form.
- **The raw-`Checkbox` rebuild of the ToS row** (proposal §1.7). Keep **`OmdsCheckboxTile`** —
  `tosCheckboxKey` and the `kyc_tos_accept` wrapper survive with zero re-verification, and the
  theme already paints the checked box navy + white check. Only its container and title string
  change (Task 6). Less new code, same render.
- **Interactive trailing controls inside the capture rows** (proposal §1.5's tappable
  `JeebCtaButton.accentText` "Retake" and tappable `JeebSelectChip` "Capture"). The row's single
  `onTap` is today's contract and the frozen `Semantics(identifier: …, button: true)` wrappers
  describe ONE tap target; nesting live buttons inside them creates double targets and TalkBack
  noise, and JM-040 taps ids, not inner pills. The trailing affordances ship as **passive
  visuals**: the Capture pill is `JeebSelectChip(role: JeebChipRole.inlineAction, selected: true,
  onTap: null)` with **no identifier** — per `03-WAVE1-KIT.md` §2.3 a chip emits no semantics node
  unless given `identifier`/`semanticLabel`, so this is a kit-consuming, semantics-silent pill.
  "Retake" is a plain `Text` in `jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700, color:
  context.jeebRoles.accent)`.
- **New "Capture" copy.** Reuse `kycIdCaptureCta` ("Take photo") / `kycSelfieCaptureCta`
  ("Capture selfie") as the pill labels and `kycIdRetake` / `kycSelfieRetake` for the retake text
  — they are already the `captureCtaSemantic` strings. Do not mint a near-duplicate "Capture" key
  (house rule, cf. 11 §2). Divergence from the board's bare "Capture" noted in §4.
- **The "compressed from 3.1 MB" offered-not-recommended line.** Dropped entirely.

### CORRECTED

1. **`Theme.of(context).extension<JeebSemanticColors>()!` null-crashes every wizard test.** The
   screen's own harness pumps a bare `MaterialApp` with default `ThemeData`
   (`kyc_wizard_screen_test.dart:53-63`, `:75-89`) — no `AppTheme`, so the extension is absent
   and the bang throws in all 17 tests. Use the kit's own idiom everywhere in this lane:
   ```dart
   final semantic = Theme.of(context).extension<JeebSemanticColors>() ??
       JeebSemanticColors.light();
   ```
   (precedent: `jeeb_avatar.dart:382-384`, `jeeb_navy_surface_card.dart:289-291`).
   `context.jeebText` and `context.jeebRoles` are already fallback-safe
   (`jeeb_text_styles.dart:211-212`, `jeeb_color_roles.dart:258-272`) — use them freely.
2. **Six wizard tests (not five) drive `cubit.captureSelfie()` directly** — lines 209, 244, 280,
   328, 381, 463 — plus the hint-visibility test at `:486` captures the selfie with BOTH ID slots
   empty. This triples the proposal's point: the selfie lock is **UI-only**; any cubit-level
   guard breaks seven tests and the JM-040 rationale.
3. **Maestro JM-040 never taps `kyc_selfie_upload`** (verified: the flow taps only
   `kyc_submit_cta` after asserting visibility — `jm-040-kyc-identity.yaml:151-168`). The locked
   row cannot break the flow. It remains documented-RED for unrelated seam reasons; neither fix
   nor worsen.
4. **`kycTosStepSubtitle` is already unconsumed today** (grep: zero call sites) — it is not
   "orphaned by this change"; leave it alone.
5. **Verified true, kept:** the proposal's line citations were accurate to ±1 line throughout;
   the C1 contract analysis (submit 400s without `id_number`) is real
   (`kyc_wizard_cubit.dart:273-280` client gate, `:406-415` field mapping,
   `kyc_submission.dart:174-179` per-type validity); `jeebRoles.success` IS `#1B7A3D` light
   (`jeeb_color_roles.dart:57`); `primaryContainer` IS the orange `#FFDBD1`
   (`app_theme.dart:89`, wired at `:135`) so the scroll-hint and liveness-card recolors are
   mandatory, not taste.

### HARDENED

- **Existing identifiers keep their existing explicit `Semantics` wrappers in the feature files,
  byte-identical** — kit `identifier:` params are used only for the NEW ids (§3.2). Never pass an
  existing id into a kit widget while also keeping the outer wrapper (double nodes).
- **Capture-row state precedence is `captured > locked > pending`.** The
  "submit reachable without ID photos" test (`:357-393`) puts a captured selfie behind a locked
  gate (`hasSelfie == true`, `isSelfieUnlocked == false`) — the row must render **captured**, not
  locked, or that state combination paints a lie.
- The scroll-hint scroll test's viewport pin (§6 Task 8) gets an exact recipe including the
  `addTearDown` resets.
- `JeebCtaButton.primary` already carries h56, pill r999, `JeebShadows.ctaNavy`, and the .45
  disabled paint — do **not** re-apply any of them at the call site.

---

## 2. File fates (all lane-owned)

| File | Fate |
|---|---|
| `lib/features/kyc/presentation/kyc_wizard_screen.dart` | restructure: step-dependent app bar, `JeebTopBar`, `_CaptureProgress` (Task 2–3) |
| `lib/features/kyc/presentation/widgets/kyc_identity_step.dart` | rebuild the body column (Task 5–6) |
| `lib/features/kyc/presentation/widgets/kyc_capture_tile.dart` | rebuild: 140px square tile → outlined horizontal row (Task 4) |
| `lib/features/kyc/presentation/widgets/kyc_id_alignment_guide.dart` | **delete** (Task 7; owner-visible, §4) |
| `lib/features/kyc/presentation/widgets/kyc_liveness_prompt_card.dart` | keep; recolor + conditional mount (Task 5, 6) |
| `lib/features/kyc/application/kyc_wizard_state.dart` | +2 derived getters, nothing else (Task 1) |
| `lib/features/kyc/presentation/kyc_status_view.dart` | **UNTOUCHED** (D52 lives here) |
| `lib/features/kyc/presentation/widgets/kyc_submitting_view.dart` | untouched |
| `test/kyc_wizard_screen_test.dart` | one surgical edit + additive tests (Task 8) |
| `test/kyc_id_alignment_guide_test.dart` | **delete** with its widget (Task 7) |

Not yours: `kyc_wizard_cubit.dart` behaviour (no signature/logic change), `lib/l10n/*` (wiring),
`lib/core/**`, `lib/devtool/**` (batch_05 mounts `KycWizardScreen(cubit:)` — constructor is
frozen), any other feature.

---

## 3. Semantics inventory

### 3.1 Existing — every one must still be emitted, spelled identically, same wrapper idiom

| Identifier | Source today | After |
|---|---|---|
| `kyc_wizard_root` | `kyc_wizard_screen.dart:99-101` (`container: true`, wraps the whole body) | unchanged, wraps the body on **every** step |
| `kyc_wizard_retry_cta` | `:243-251` (`container: true, button: true`) | same wrapper, child becomes `JeebCtaButton.outline` |
| `kyc_id_front_upload` | `kyc_identity_step.dart:230-233` (`button: true, container: true`) | wraps the front capture row |
| `kyc_id_back_upload` | `:247-250` | wraps the back row |
| `kyc_id_type_picker` | `:273-275` | moves inside the new `JeebOutlinedCard` |
| `kyc_id_type_${type.wire}` (×3) | `:280-281` | unchanged — keep the `OmdsRadioTile`s and their keys |
| `kyc_id_number_input` | `:310-312` (`textField: true`) | unchanged `OmdsTextField`, now inside the card |
| `kyc_selfie_upload` | `:390-393` | wraps the selfie row in **all three** states |
| `kyc_submit_cta` | `:420-423` | same wrapper, child becomes `JeebCtaButton.primary` |
| `kyc_scroll_hint` | `:466-469` | kept, recolored (Task 6) |
| `kyc_tos_accept` | `:532-534` | same wrapper, `OmdsCheckboxTile` kept |

Widget `Key`s that must survive: `KycWizardScreen.rootKey` / `.progressKey` / `.backLeadingKey`;
`KycIdentityStep.frontTileKey` / `.backTileKey` / `.idNumberFieldKey` / `.idTypeNationalIdKey` /
`.idTypePassportKey` / `.idTypeResidencyKey` / `.selfieTileKey` / `.livenessPromptKey` /
`.tosCheckboxKey` / `.submitButtonKey` / `.scrollHintKey`. The tile keys stay on the row widget's
own `Semantics(key: tileKey, button: true, enabled: …)` node exactly as `kyc_capture_tile.dart:42-46`
places them today. `KycIdAlignmentGuide.rootKey` / `.frameKey` die with the widget.

### 3.2 New (convention `<screen>_<element>`)

| New id | Element | How |
|---|---|---|
| `kyc_wizard_back` | top-bar back circle | `JeebTopBar(identifier: 'kyc_wizard_back')` — the kit lands it on the leading circle (frozen `<screen>_back` contract). Put `KycWizardScreen.backLeadingKey` on the `JeebTopBar` itself (`key:`) — the kit exposes no leading-key slot and no test targets the key today |
| `kyc_review_note` | the review-time info note | `JeebInfoNote.muted(identifier: 'kyc_review_note', …)` |
| `kyc_tos_read_cta` | "Read the full terms" | `JeebCtaButton.text(identifier: 'kyc_tos_read_cta', …)` |
| `kyc_tos_document_sheet` | modal sheet root | explicit `Semantics(identifier: …, container: true, explicitChildNodes: true)` in the sheet builder |

---

## 4. Deliberate divergences from the board (each a one-line reversal; list them in the PR)

| Board | Ship | Why |
|---|---|---|
| four blocks only — no ID type, no ID number | both controls kept, grouped in one `JeebOutlinedCard` inside the Step-1 group | **C1 refusal.** E3/JEBV4-197: `id_number` is contract-required for every `KycIdType`; the client hard-gates on it (`kyc_identity_step.dart:439-441`, `kyc_wizard_cubit.dart:273-280`) and the BFF 400s without it (`:406-415`). Building the board literally makes every submit fail |
| `Captured · looks sharp ✓` | `Captured ✓` (text + `Icons.check_rounded`, both `jeebRoles.success`) | **C2 refusal (verdict half).** `PhotoAttachment` (`photo_attachment.dart:15-40`) carries no sharpness/glare/face signal; computing one needs a banned new dependency. TODO comment, never fake |
| captured thumb = navy slab + ID glyph | real `Image.memory(photo.bytes)` in the same 64×44 r8 box; navy + `Icons.badge_rounded` as `errorBuilder` fallback | **C3.** Dropping the only visual proof of what was captured is a regression the note never asked for; stub/test payloads hit the fallback and render the board's exact slab |
| "…are encrypted and never shown to customers" | "Your documents are never shown to customers." | **C4 hold.** The app can verify the read-audience claim, not storage-at-rest encryption; an unverified security promise in a signed-terms context is a legal risk. One-key edit if legal ratifies it later |
| terms = one line, no document | one line + `kyc_tos_read_cta` → modal sheet with `kycTosStepTitle` + `kycTosDocumentBody` | **C5.** Submit signs a contract (`kyc_wizard_cubit.dart:289-295`); the document must stay reachable |
| trailing `Capture` pill copy | `Take photo` / `Capture selfie` (existing keys) | no near-duplicate l10n keys (§1 CUT) |
| sub-12px type (12 / 12.5) | `jeebText.bodySmall` (12) / `caption` (11.5) nearest-ramp | no `fontSize:` in `lib/features` (token gate) |
| `#2E7D32` captured-green | `context.jeebRoles.success` (`#1B7A3D`) | WCAG-corrected role green (`jeeb_color_roles.dart:57`); never the CSS literal |
| single-paragraph note with inline bold | `JeebInfoNote.muted` **stacked** form: `title:` = review-time line (navy w700), `text:` = privacy line | inline-bold spans don't survive l10n/RTL cleanly; the stacked form is the kit-native equivalent (`03-WAVE1-KIT.md` §2.10: `title` switches the form) |
| empty lower half (content ends ~62%) | column still scrolls on a 360×800 with C1's fields restored | **C9.** ~340pt of chrome is genuinely removed (guide + 2 headlines + 3×140px tiles → 3 rows ≈75px); do not buy the white space by deleting required inputs |

---

## 5. Target structure

```
Scaffold(key: rootKey,
  appBar: state.step == KycWizardStep.identity ? null
          : OMDSAppBar(title: l10n.kycWizardTitle, centerTitle: false),   // schema/submitting/status keep OMDS chrome
  body: Semantics(identifier: 'kyc_wizard_root', container: true,        // unchanged, every step
    child: SafeArea(child: <step body>)))

identity step body (Column):
  JeebTopBar(title: kycWizardTitle, identifier: 'kyc_wizard_back', …)     kit default pad 14/24/0
  _CaptureProgress                                                        pad 24/20/24/0, key: progressKey
    Row[ Text(kycWizardProgressStepLabel)  ·  Spacer  ·  Text(kycWizardNextStepHint)? ]
    JeebMeter.segmented(steps: 2, filled: state.currentCaptureStep)       h6 gap 8 r9, kit-owned
  Expanded(KycIdentityStep())

KycIdentityStep column (scroll gutter EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge)):
  KycCaptureTile(front)      — row, r18 outlined                          gap Spacing.small (12)
  KycCaptureTile(back)       — row
  JeebSectionLabel(kycIdTypeLabel) + JeebOutlinedCard(radius: 18): 3 OmdsRadioTile + OmdsTextField
  _ScrollForSelfieHint       — centred pill, while !hasSelfie             (fold boundary preserved)
  KycCaptureTile(selfie)     — row: locked | pending | captured
  KycLivenessPromptCard      — ONLY when isSelfieUnlocked && !hasSelfie
  JeebInfoNote.muted(title: kycReviewTimeTitle, text: kycReviewPrivacyNote, icon: Icons.access_time_filled)
  _TosAgreementRow           — OmdsCheckboxTile(kycTosAgreeLine) + JeebCtaButton.text(kycTosReadFullCta)
JeebCtaFooter.single(…)      — outside the scroll view, kit docked pad 24/0/24/32
```

The Step-1 card sits **between the ID rows and the selfie row** — it keeps `id_type`/`id_number`
inside "Step 1 — Your ID" and preserves the fold boundary that `kyc_scroll_hint` and its two
tests depend on.

---

## 6. Task list — execute top to bottom

**Task 1 — `kyc_wizard_state.dart`: two derived getters.** Additive, pure derivations, **not** in
`props`, no cubit change:

```dart
/// The 1-based step the user is ON — header label + segment fill. Unifies the
/// off-by-one between today's label (`:268-270`) and bar (`completedCaptureSteps`).
/// `completedCaptureSteps` itself is unchanged (KycStatusView reads it).
int get currentCaptureStep =>
    (completedCaptureSteps + 1).clamp(1, totalCaptureSteps);

/// UI-only gate for the selfie row. NEVER enforced in the cubit — six wizard
/// tests drive captureSelfie() directly (JEBV4-295 / JM-040 rationale).
bool get isSelfieUnlocked => submission.hasIdFront && submission.hasIdBack;
```

**Task 2 — `kyc_wizard_screen.dart`: step-dependent chrome.** Restructure `_WizardScaffold.build`
(`:89-140`): move the `BlocBuilder` above the `Scaffold` so `appBar:` can read the step —
`MultiBlocListener(listeners: <unchanged :103-132>, child: BlocBuilder(builder: (context, state)
=> Scaffold(…)))`. `appBar: null` on `identity` only; `kyc_wizard_root` + `SafeArea` keep wrapping
the whole body on every step. The identity branch of `_buildBody` (`:167-173`) becomes
`Column[JeebTopBar, _CaptureProgress(state), Expanded(KycIdentityStep())]`.
- `JeebTopBar(key: KycWizardScreen.backLeadingKey, title: l10n.kycWizardTitle, identifier:
  'kyc_wizard_back', leadingTooltip: <MaterialLocalizations.of(context).backButtonTooltip>,
  onLeadingPressed: () => context.canPop() ? context.pop() : context.go('/'))` — mirrors
  `AppRouter.backFallbacks['kyc-status'] == '/'` (`app_router.dart:473`); do not rely on the kit's
  `Navigator.maybePop` default (the dead-at-root defect class). Only evaluated on tap, so the
  GoRouter-less test harness is safe.
- Schema error view (`:230-256`): `Text` at `:241` gets `context.jeebText.body` +
  `colorScheme.onSurfaceVariant`; `OMDSOutlinedButton` at `:247-250` becomes
  `JeebCtaButton.outline(label: l10n.kycRetry, onTap: …)` **inside the untouched
  `kyc_wizard_retry_cta` wrapper**.

**Task 3 — `_ProgressHeader` → `_CaptureProgress`** (replaces `:258-302`; keep
`KycWizardScreen.progressKey` on the outer `Padding`, padding
`EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.large, Spacing.xLarge, 0)`):

```dart
Row(children: [
  Text(l10n.kycWizardProgressStepLabel(current: state.currentCaptureStep,
      total: KycWizardState.totalCaptureSteps, stepName: l10n.kycWizardStepIdTitle),
    style: context.jeebText.bodySmall.copyWith(
        fontWeight: FontWeight.w700, color: colorScheme.primary)),
  const Spacer(),
  if (state.currentCaptureStep < KycWizardState.totalCaptureSteps)
    Text(l10n.kycWizardNextStepHint(stepName: l10n.kycWizardStepSelfieLabel),
      style: context.jeebText.bodySmall.copyWith(color: semantic.mutedText)),
]),
const SizedBox(height: Spacing.xSmall),
JeebMeter.segmented(
  steps: KycWizardState.totalCaptureSteps,
  filled: state.currentCaptureStep,          // segment N filled while ON step N
),
```

Step-1 name stays `kycWizardStepIdTitle` ("Your ID"); the "then" hint reuses the existing
`kycWizardStepSelfieLabel`. `OMDSLabeledStepperProgress` and the `displayStep` clamp (`:268-270`)
are deleted — `currentCaptureStep` is the single source for label AND bar.

**Task 4 — rebuild `KycCaptureTile` as the outlined row.** Same class name; keep the existing
params (`label`, `photo`, `onTap`, `isProcessing`, `tileKey`, `captureCtaSemantic`) so call-site
churn is minimal; `tileHeight` const is deleted (content-driven height — 200% text must grow the
row). New params: `String? hint`, `bool isLocked = false`, `bool isSelfie = false` (drives the
circle thumb), `String? trailingLabel` (the passive Retake/Capture text). State precedence:
**captured (photo != null) > locked > pending.**

- Shell: `JeebOutlinedCard(radius: 18, onTap: isLocked || isProcessing ? null : onTap, child: …)`
  — kit default padding (13/16 — nearest kit value to the HTML's 14/16, accepted), 1.5px
  `colorScheme.outline`, no shadow. Keep the widget's own semantics node exactly as today
  (`kyc_capture_tile.dart:42-46`): `Semantics(key: tileKey, button: true, enabled: !isProcessing
  && !isLocked, label: captureCtaSemantic ?? label, child: <card>)`. The frozen
  `kyc_id_*_upload` / `kyc_selfie_upload` wrappers stay in `kyc_identity_step.dart`, outside.
- Locked treatment: wrap the card's child in `Opacity(0.55)` (direction-agnostic), no trailing,
  sub-line = `hint` (`kycSelfieLockedHint`).
- Thumb slot (feature-local named consts, e.g. `static const double _thumbWidth = 64;` — the
  token gate bans `SizedBox(width: N)` single-arg literals and `EdgeInsets.<x>(N)`, not named
  consts):
  - captured: 64×44, `ClipRRect(borderRadius: OmdsBorderRadius.xSmall)` over
    `Image.memory(photo.bytes, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: navy fill
    + white Icons.badge_rounded @ Sizes.large)` — carry over the stub-payload comment from
    `:120-124`.
  - pending: 64×44 r8 fill `colorScheme.surfaceContainerHigh`, **1.5px dashed
    `colorScheme.outline`** via a small feature-local `CustomPainter` (no kit dashed border
    exists — this is sanctioned bespoke, keep the painter `const`-able), glyph
    `Icons.photo_camera_rounded` @ `Sizes.large` in `semantic.mutedText`.
  - selfie (locked or pending): Ø44 circle (`BoxShape.circle`), same fill, `Icons.person_rounded`
    @ `Sizes.large` in `semantic.mutedText`.
- Text column (`Expanded`): title = `label` in `context.jeebText.cardTitle` +
  `colorScheme.primary`; sub-line per state — captured: `Row[Text(l10n.kycCaptureCaptured),
  Icon(Icons.check_rounded, size: Sizes.medium)]` both `jeebRoles.success`,
  `jeebText.bodySmall` (text before icon in the same Row — reading-order RTL rule, never
  `Positioned`); pending: `hint` in `jeebText.bodySmall` + `semantic.mutedText`; locked: the
  locked hint, same style; no sub-line when `hint == null`.
- Trailing per state — captured: `Text(trailingLabel /* kycIdRetake | kycSelfieRetake */,
  style: jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700, color: jeebRoles.accent))`;
  pending: `JeebSelectChip(role: JeebChipRole.inlineAction, label: trailingLabel /* kycIdCaptureCta
  | kycSelfieCaptureCta */, selected: true, onTap: null)` — no identifier ⇒ no semantics node ⇒
  passive; locked: none; `isProcessing`: keep `OmdsLoadingState` in the trailing slot.
- Delete `_PlaceholderBody` / `_PreviewBody` / the overlay label chip (`:75-156`) — the row has a
  real title column. Update the class doc comment (it describes the square tile).
- Add a short `// TODO(redesign-24): the board's "looks sharp ✓" verdict needs a capture-quality
  signal the app does not have — omitted, not faked.` above the captured sub-line.

**Task 5 — rebuild the `KycIdentityStep` body column** (order per §5):

- Scroll padding `EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge)` replaces
  `EdgeInsets.all(Spacing.large)` (`:201-202`).
- DELETE: both headline/subtitle pairs (`:213-223`, `:363-373`) and the `KycIdAlignmentGuide`
  call site + import (`:225-228`, `:12`).
- Front/back rows: keep the `:230-262` wrappers byte-identical; call the rebuilt tile with
  `hint: l10n.kycIdCaptureHint`, `trailingLabel: hasPhoto ? l10n.kycIdRetake :
  l10n.kycIdCaptureCta`.
- ID group: `JeebSectionLabel(l10n.kycIdTypeLabel)` (positional label — the kit uppercases
  internally, locale-gated; never `.toUpperCase()` yourself) replacing the `titleSmall` header
  (`:266-271`); then one `JeebOutlinedCard(radius: 18)` containing the untouched
  `kyc_id_type_picker` block (`:273-296`), the idType inline error (`:297-306` — restyle to
  `jeebText.caption` + `colorScheme.error`), and the untouched `kyc_id_number_input` block
  (`:310-341` — keep `ArabicIndicDigitsFormatter` BEFORE `digitsOnly`).
- Scroll hint block (`:352-360`): visibility rule unchanged (`!hasSelfie`).
- Selfie row: keep the `:390-405` wrapper; `isSelfie: true`, `isLocked: !state.isSelfieUnlocked
  && !state.submission.hasSelfie`, `hint:` locked ? `l10n.kycSelfieLockedHint` : null,
  `trailingLabel:` captured ? `kycSelfieRetake` : unlocked ? `kycSelfieCaptureCta` : null,
  `label: l10n.kycSelfieStepTitle`.
- `KycLivenessPromptCard` (`:375-388`): move BELOW the selfie row and mount only when
  `state.isSelfieUnlocked && !state.submission.hasSelfie` — coaching at the moment step 2 opens.
  `livenessPromptKey` preserved. (Its test mounts the card directly and asserts text/icons only —
  verified safe.)
- Info note: `JeebInfoNote.muted(identifier: 'kyc_review_note', icon: Icons.access_time_filled,
  title: l10n.kycReviewTimeTitle, text: l10n.kycReviewPrivacyNote)` — stacked form; note the C4
  hold in a one-line comment.
- Footer: replace `:419-444` with `JeebCtaFooter.single` OUTSIDE the scroll view, child = the
  untouched `kyc_submit_cta` `Semantics` wrapper around
  ```dart
  JeebCtaButton.primary(
    key: KycIdentityStep.submitButtonKey,
    label: state.step == KycWizardStep.submitting
        ? l10n.kycWizardSubmitting : l10n.kycWizardSubmit,
    isEnabled: state.step != KycWizardStep.submitting &&
        state.submission.hasSelfie && state.submission.hasValidIdNumber,
    onTap: () => cubit.submit(),
  )
  ```
  The predicate is verbatim `:439-441` (JEBV4-295, three tests pin it) — **do not** add
  `tosAccepted` to it. Keep the explanatory comment block. Board copy "Submit for review" already
  equals `kycWizardSubmit` — no change.

**Task 6 — ToS row + sheet + recolors.**
- Delete `_TosAcceptanceCard` (`:506-547`). New `_TosAgreementRow`: the untouched
  `kyc_tos_accept` wrapper around `OmdsCheckboxTile(key: tosCheckboxKey, title:
  l10n.kycTosAgreeLine(percent: kJeebCommissionPercent), value: accepted, onChanged:,
  contentPadding: EdgeInsets.zero, dense: true)`, then `JeebCtaButton.text(label:
  l10n.kycTosReadFullCta, identifier: 'kyc_tos_read_cta', expand: false, onTap: _openTosSheet)`.
  `{percent}` MUST come from `kJeebCommissionPercent` (`jeeb_commission.dart:78`) — a literal
  `10%` in Dart or ARB is the second-copy class `jeeb_commission_test.dart` exists to prevent.
- `_openTosSheet`: `showModalBottomSheet` rendering `Semantics(identifier:
  'kyc_tos_document_sheet', container: true, explicitChildNodes: true, child: …)` with
  `l10n.kycTosStepTitle` (`jeebText.h2`) + `l10n.kycTosDocumentBody` (`jeebText.body`) in a
  `SingleChildScrollView`, gutter `Spacing.xLarge`. No new route, no fetch.
  `// TODO(redesign-24): render contractTemplate.documentUrl once the template is fetched
  eagerly — today it loads lazily at submit (kyc_wizard_cubit.dart:288-289).`
- `_ScrollForSelfieHint` (`:456-504`): `colorScheme.primaryContainer` → `surfaceContainerHigh`,
  `onPrimaryContainer` → `colorScheme.primary`; `labelMedium` → `jeebText.bodySmall.copyWith(
  fontWeight: FontWeight.w600)`. Identifier, key, tap behaviour unchanged. (Why: R5 —
  `primaryContainer` is now orange `#FFDBD1`; orange marks decay, not navigation.)
- `KycLivenessPromptCard`: fill `:39` → `colorScheme.surfaceContainerHigh` (it currently paints
  60% orange); radius `:40` → `OmdsBorderRadius.medium`; title `:45-50` →
  `jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700)`; prompt ink `onPrimaryContainer` →
  `colorScheme.onSurface` / icons `semantic.mutedText`.

**Task 7 — delete `kyc_id_alignment_guide.dart` AND `test/kyc_id_alignment_guide_test.dart`.**
Owner-visible removal (§4/R2): the ID-1 framing rectangle is replaced by the per-row
`kycIdCaptureHint`; it was the largest density offender. The only coverage reduction in this
change — call it out in the PR.

**Task 8 — test updates (`test/kyc_wizard_screen_test.dart`).**
- `tapping kyc_scroll_hint scrolls …` (`:495-524`): the redesign shortens the column ~340pt, so
  the precondition `find.byKey(selfieTileKey).hitTestable() → findsNothing` becomes
  viewport-luck in the 800×600 harness. Pin a phone viewport at the top of the test — do NOT
  weaken the assertions:
  ```dart
  tester.view.physicalSize = const Size(1080, 1920);   // 360×640 @3x
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  ```
- Add (additive, same `_host` harness):
  1. selfie row locked until both ID sides: fresh cubit → the selfie row reports
     `Semantics(enabled: false)` / tapping `selfieTileKey` starts no capture
     (`cubit.state.capturing == null`); after `captureIdFront()` + `captureIdBack()` it unlocks.
  2. `kyc_tos_read_cta` opens the sheet: tap → `kyc_tos_document_sheet` + the
     `kycTosDocumentBody` text found.
  3. `kyc_review_note` present on the identity step.
  4. captured state renders `kycCaptureCaptured` after `cubit.captureIdFront()`.
- Everything else in the suite passes unchanged — re-verified per test: the 8-identifier render
  test `:150`, progress `:184`, AC4 `:196`, JEBV4-271 trio `:229/:267/:310`, no-ID submit `:357`
  (the reason the lock is UI-only), CTA gates `:395/:431`, hint visibility `:474`, inline errors
  `:559/:579`, passport swap `:598` (radio keys kept), resubmit-clear `:625`, re-entry quartet
  `:650/:686/:728/:757` (KycStatusView untouched). `kyc_liveness_prompt_card_test.dart` asserts
  text + icons only — recolor-safe. `kyc_wizard_cubit_test.dart` — cubit untouched.

**Task 9 — gates.**
```
flutter analyze                       # bar: 5 pre-existing infos, 0 errors, nothing new
flutter test test/kyc_wizard_screen_test.dart test/kyc_wizard_cubit_test.dart \
  test/kyc_liveness_prompt_card_test.dart test/kyc_status_view_test.dart \
  test/kyc_submitting_view_test.dart test/decision_violations_test.dart \
  test/core/jeeb_commission_test.dart test/core/theme/no_raw_semantic_colors_test.dart
bash tool/check_design_tokens.sh      # clean — no fontSize:, EdgeInsets.<x>(N), BorderRadius.circular(N), Colors.*, Color(0x…)
grep -rn "identifier:" lib/features/kyc/presentation/ | diff against §3
```
`no_raw_semantic_colors_test.dart` lists `offer_kyc_gate_screen.dart`, not any `features/kyc/`
file — no impact, verified. Report which steps were blocked on the l10n wiring batch (the lane
won't compile clean until the integrator lands §8 — expected; say so).

---

## 7. RTL & text-scale rules (build-time checklist)

| Element | Rule |
|---|---|
| Segment bar | `JeebMeter.segmented` mirrors itself (kit-tested) — never wrap in `Directionality` |
| Header label ↔ "then Selfie" | `Row` + `Spacer()`, never side-specific alignment |
| Capture row | `Row` + `EdgeInsetsDirectional`; trailing lands visual-left under `ar` automatically |
| `Captured ✓` | `Text` then `Icon` in one `Row` — reading order, no `Positioned` |
| ToS row | `OmdsCheckboxTile` handles it; the read-terms button below aligns `start` |
| `{percent}` / step counters | ICU-style placeholders via the house `replaceFirst` getters — never concatenation; counters keep Arabic-Indic digits (no LTR isolate — not money) |
| ID number field | keep `ArabicIndicDigitsFormatter` ahead of `digitsOnly` (`:330-332`) |
| 200% text | no fixed row height (that is why `tileHeight = 140` dies); thumb fixed, text `Expanded`, trailing `Flexible` |

---

## 8. Wiring request — the ONLY one (final text, already at `docs/redesign-2026-08/wiring/22-become-a-jeeber.md`)

l10n batch: 4 value changes + 10 new keys + hand-rolled getters (this repo's `AppLocalizations`
is `_get` + `replaceFirst` — `app_localizations.dart:761-764` is the house pattern; no ICU plural
engine). Keys already consumed by the code written in Tasks 2–6. None of the new names collide
with the D20 banned list. Orphans after this change (integrator may retire, both locales):
`kycWizardProgressLabel`, `kycIdStepTitle`, `kycIdStepSubtitle`, `kycSelfieStepSubtitle`,
`kycIdAlignmentGuideTitle`, `kycIdAlignmentGuideCaption`, `kycTosSignAndSubmit`
(`kycTosStepSubtitle` was already orphaned before this change). **Keep**: `kycTosDocumentBody`,
`kycTosStepTitle`, `kycIdRetake`, `kycIdCaptureCta`, `kycSelfieRetake`, `kycSelfieCaptureCta`,
`kycScrollForSelfieHint`, `kycWizardStepIdLabel`, `kycWizardStepSelfieLabel`.

See the wiring file for the paste-ready JSON/Dart.

---

## 9. Stop conditions

**Done means:** the five lane files match §5/§6; every §3.1 identifier and every listed `Key`
greps identically; the Task-9 suites are green (modulo the l10n-wiring compile dependency,
reported); `flutter analyze` shows only the 5 baseline infos; the token script is clean; the PR
notes list the §4 divergences, the R2 deletion, and the `kycWizardTitle` retitle ("Verify your
identity" → "Become a Jeeber" — no test pins it; it also retitles the OMDS bar on the
status/submitting/schema steps, which is coherent).

**Do NOT touch:** `kyc_status_view.dart` (D52 lives here), `kyc_submitting_view.dart`,
`kyc_wizard_cubit.dart` (no logic/signature change — the selfie lock is presentation-only),
`lib/core/**` (router, DI, theme, kit — the kit is frozen; consume it),
`lib/l10n/*` (wiring request only), `pubspec.yaml`, `lib/devtool/**`, `.maestro/**`, any other
feature, the four pre-existing `_BASELINE.md` test failures. Do not add a resubmit affordance
anywhere (D52). Do not mint `kyc_vehicle_*` anything (D20). Do not fabricate a sharpness verdict,
an encryption promise, or an eager contract fetch.
