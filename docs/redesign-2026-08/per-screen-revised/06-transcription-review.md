# 06 · Transcription review — REVISED instruction set (authoritative)

Screen id: `06-transcription-review` · Verdict: **rebuild** (confirmed against the render + source).
Lane owns: `lib/features/transcription/**` + `test/transcription_screen_test.dart` + new tests under
`test/features/transcription/`. Everything else is a wiring request.

## Review outcome — what changed vs the Opus proposal

**Verified correct** (checked against source): the per-word-confidence field does NOT exist
(`voice_recording_repository.dart` ~:65 documents `TranscribeResponse: { audioId, status,
transcription, language, reason }`; `TranscriptionResult` at :12–20 carries only `id` +
`transcript`) — the orange underline is unbuildable and must not be faked. `language` IS in that
documented contract and is dropped before reaching this screen. All 7 Semantics identifiers, the
cited HTML tpl values, the Wave-0 theme symbols (`jeebText.h1` 24/w700, `.h2` 20/w700, `.caption`
11.5/w600, `.button` 17/w600, `JeebShadows.raised`/`.ctaNavy`, `jeebRoles.accent` #D73B00), the
router facts (route :1140, `backFallbacks['transcription']='/'` ~:485, `VoiceClip` constructions at
:1079 and :1192) and the periwinkle AA failure (`color_role_contrast_test.dart:129–140`) all check out.

**CORRECTED — the proposal's biggest factual error:** `find.text` does NOT break on `Text.rich`.
Verified in `flutter_test/lib/src/finders.dart` (`_MatchTextFinder._matchesNonRichText`): a `Text`
with a `textSpan` is matched via `textSpan.toPlainText()`. So the 3 claimed test breaks
(`transcription_screen_test.dart:85`, `:195`, `integration_wiring_test.dart` ~:196) do not happen,
**provided** the transcript renders as `Text.rich` (never raw `RichText`), uses only `TextSpan`s
(no `WidgetSpan` — it injects U+FFFC into `toPlainText`), and span concatenation is byte-identical
to `state.text`. **Zero existing test edits. Wiring request W7 is cancelled.**

**CUT (scope creep / unnecessary cross-lane cost):**
1. All edits to `transcription_status_banner.dart` and the JeebInfoNote conversion (old W2). The
   board shows no banner; the plan's `JeebInfoNote` consumer list (§5 #22) is `08 11 12 17 23` —
   06 is not on it. The banner's role pairs are already compliant, the file is on the
   `no_raw_semantic_colors_test.dart` list (touching it is pure risk), and Wave 0's errorContainer
   re-tint restyles the failed state through the theme with zero edits. **File stays untouched.**
2. The `JeebCtaFooter` "fourth form" ask (old W1, first half). The footer is 10 lines of local
   composition (padding + `JeebCtaButton` + centered text link). Only the `isEnabled` ask survives.
3. The `lowConfidenceRanges` state field + dormant underline paint path. An always-empty field with
   an unreachable paint branch is dead code. A `TODO(redesign-24)` comment at the span builder is
   the policy-compliant artifact (§7.6).
4. In-screen go_router back guard (`if (context.canPop()) context.pop()`). The repo's documented
   guard idiom is `Navigator.maybePop` (see `test/core/router/back_button_blank_surface_test.dart`
   header: the OMDS fix), which also keeps this screen router-agnostic — its tests pump a plain
   `MaterialApp` with no GoRouter, where a go_router extension call would throw if ever exercised.
   The guarded default belongs in `JeebTopBar` (kit) — wiring request W5.

**Prerequisites (blocked-by):** Wave 0 is landed (verified: `jeeb_text_styles.dart`,
`jeeb_shadows.dart` exist). The kit (`lib/core/widgets/jeeb/`) does **not** exist yet. Do not start
tasks 6–9 until `JeebTopBar`, `JeebCtaButton`, `JeebOutlinedCard`, `JeebSelectChip`, `JeebMeter`
exist. Degrade rules are stated per task; never hand-roll a parallel copy of a kit widget.

---

## Semantics identifiers — FROZEN inventory (all on `TranscriptionKeys`, `transcription_screen.dart:17–27`)

These 7 must be emitted after the rebuild, spelled identically, via explicit `Semantics` wrappers:

| Value | Today | After |
|---|---|---|
| `voice_transcript_audio_toggle` | `audio_card.dart:46` | the navy play/pause disc |
| `voice_transcript_edit_button` | `text_panel.dart:73` | the `Edit all` action in the card hint row |
| `voice_transcript_text_field` | `text_panel.dart:149` | unchanged |
| `voice_transcript_save_edit_button` | `text_panel.dart:177` | unchanged |
| `voice_transcript_confirm_button` | `screen.dart:227` | the primary pill |
| `voice_transcript_re_record_button` | `screen.dart:253` | the centered text link |
| `voice_transcript_retry_button` | `status_banner.dart:152` | unchanged (file untouched) |

New identifiers (add as consts on `TranscriptionKeys`, `<screen>_<element>` convention):
`voice_transcript_root` (container + explicitChildNodes — §7.5), `voice_transcript_back`,
`voice_transcript_transcript_text`, `voice_transcript_scrubber`,
`voice_transcript_language_chip`, `voice_transcript_quick_add_quantity` / `_brand` / `_budget`.

---

## Task list (dependency-ordered — execute top to bottom)

### 1. Append the wiring file
Create `docs/redesign-2026-08/wiring/06-transcription-review.md` with the exact content in the
"Wiring requests" section below. Then write all screen code as if granted.

### 2. Domain: `VoiceClip.language` + `seek` on the player port
- `domain/voice_clip.dart`: add `final String? language;` + optional ctor param. Short *why*
  comment: carries the documented `TranscribeResponse.language`; null until the voice_request
  lane forwards it (wiring W2/W3).
- `domain/transcript_audio_player.dart`: add `Future<void> seek(Duration position);` to the
  abstract class; no-op impl in `NoopTranscriptAudioPlayer`; in `FakeTranscriptAudioPlayer` add
  `int seekCalls = 0; Duration? lastSeek;` and record. **Do NOT delete or rename Noop/Fake**
  (§7.4 — tests construct them).
- `domain/audioplayers_transcript_audio_player.dart`: implement as
  `await _player?.seek(position);` — deliberately `_player?`, not `_resolved`: seeking before any
  `play` must not construct a source-less platform player. One-line why comment.

### 3. Cubit/state additions (`application/transcription_cubit.dart`) — all additive
- `TranscriptionState`: `+ String? language`, `+ TextRange? editRange`,
  `+ Set<String> appliedQuickAdds` (default `const {}`). Update `copyWith` and `props`.
  **Pitfall:** the `?? this.x` idiom cannot null out `editRange` — add a
  `bool clearEditRange = false` param to `copyWith` (or equivalent explicit reset) and use it from
  `confirmEdit`.
- `seedFromClip`: also seed `language: clip.language`.
- `+ void startEditingWord(TextRange range)`: emit `isEditing: true, editRange: range`.
- `+ void applyQuickAdd(String id, String fragment)`: no-op if `appliedQuickAdds.contains(id)`;
  append fragment (`text` empty → fragment; else `'$text\n$fragment'`); emit with
  `isEditing: true`, `editRange: TextRange.collapsed(newText.length)`, id added to the set,
  status recomputed like `confirmEdit` does.
- `+ Future<void> seekTo(Duration position)`: no-op when `playbackPath` is null/empty (mirror the
  guard at `togglePlayback` :161–162); clamp to `[Duration.zero, audioDuration]`; emit
  `playbackPosition`; call `_player.seek` inside `try { … } on Object {}` (mirror the play degrade).
- `confirmEdit`: also clear `editRange` (via the reset flag).
- `startEditing` (Edit all): unchanged behavior, no `editRange`.

### 4. Audio card rebuild (`presentation/widgets/transcription_audio_card.dart`)
- Container: keep `surfaceContainerHigh` + `OmdsBorderRadius.medium` (already design-exact);
  padding → `EdgeInsets.symmetric(horizontal: Spacing.medium, vertical: Spacing.small)` (16/12 vs
  design 16/14 — R3, don't chase).
- Toggle: replace `IconButton.filled` with a Ø48 (`Sizes.fourXLarge`; design 46) circle —
  `colorScheme.primary` fill, `shape: BoxShape.circle`, `boxShadow: JeebShadows.raised` — holding a
  `Sizes.large` (20) white `Icons.play_arrow` / `Icons.pause`. Keep the existing
  `Semantics(identifier: TranscriptionKeys.audioToggle, button: true, label: play/pause l10n)`
  wrapper and the `cubit.togglePlayback()` tap. Use an ink-capable tappable (e.g. `Material` +
  `InkWell(customBorder: CircleBorder())`); Ø48 already satisfies the tap-target minimum.
- Progress: replace `ClipRRect + LinearProgressIndicator` with `JeebMeter.scrubber` (kit §5 #20;
  06 is a listed consumer): track h5 r9 `surfaceContainerHighest`, accent fill, Ø14 accent knob.
  Wrap it in `Semantics(identifier: TranscriptionKeys.scrubber, slider: true, value: '<pos> /
  <total>')`. Wire `onSeek` → `cubit.seekTo`. **If the kit ships without `onSeek`: render it
  display-only, drop `slider: true`, add `// TODO(redesign-24): wire onSeek when JeebMeter grows
  it` — never hand-roll a second meter.**
- Times: replace the single combined label with two `Text`s in
  `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween)`, style `context.jeebText.caption` in
  `colorScheme.onSurfaceVariant` (NOT periwinkle — AA), keep `FontFeature.tabularFigures()`, each
  wrapped in `Directionality(textDirection: TextDirection.ltr, child: …)` so `0:04` never renders
  as `04:0` under ar.
- `_format`: drop the leading zero on minutes (`0:04`, not `00:04`). No test pins the old string
  (verified — only cubit positions are asserted).

### 5. Text panel rebuild (`presentation/widgets/transcription_text_panel.dart`)
- Delete `_TranscriptionLabelRow` and `_EditAction`'s current placement (tpl: no section label, no
  icon button). `transcriptionFieldLabel` stays in use by the editor's `labelText`.
- Display card → `JeebOutlinedCard` (kit §5 #3): white fill, 1.5px `colorScheme.outline`, radius
  16, padding 20 param. NO shadow (R7).
- Transcript text: `Text.rich` — one `TextSpan` per word (`RegExp(r'\S+')` matches) with a
  `TapGestureRecognizer` calling `cubit.startEditingWord(TextRange(start: m.start, end: m.end))`,
  plus plain spans for the exact inter-word gaps. **Invariant: concatenated span text ==
  `state.text` byte-identical; `TextSpan`s only, no `WidgetSpan`** — this is what keeps the three
  existing `find.text` assertions green. Style: `context.jeebText.h2.copyWith(height: 1.6)` in
  `colorScheme.onSurface` (design 22/w700 — R3). Wrap in `Semantics(identifier:
  TranscriptionKeys.transcriptText, container: true)`. Recognizers live in a StatefulWidget:
  create per build of spans, dispose in `dispose()`/on text change (`didUpdateWidget`).
  At the span builder add:
  `// TODO(redesign-24): needs gateway word-confidence offsets on TranscribeResponse — underline omitted, not faked.`
- No underline renders. Ever. (Refusal upheld: no confidence data exists.)
- Placeholder branch (empty text): keep a plain `Text(l10n.transcriptionFieldHint)` in
  `onSurfaceVariant` — the queued-state test asserts this exact string.
- Hint row inside the card (only when text non-empty, mirroring today's `showEdit` gate), tpl
  326–331: `Row[ Icon(Icons.info_rounded, size: Sizes.medium, color: context.jeebRoles.accent),
  gap 8, Text(l10n.transcriptionTapHint, style: jeebText.bodySmall, color: onSurfaceVariant),
  Spacer(), EditAll ]`. `Edit all` = a `TextButton` (min tap target ≥44 via `styleFrom`) whose
  label is `l10n.transcriptionEdit` styled `jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700,
  color: context.jeebRoles.accent)`, wrapped in
  `Semantics(identifier: TranscriptionKeys.editButton, button: true)` → `cubit.startEditing()`.
  Hint copy is "Tap any word to fix it" — reworded because no underline renders.
- Content-derived direction: wrap the transcript `Text.rich` (and only it) in
  `Directionality(textDirection: Bidi.detectRtlDirectionality(state.text) ? TextDirection.rtl :
  TextDirection.ltr)` (`package:intl/intl.dart`, already a direct dep at pubspec :121 — no new
  dependency). The screen's ambient direction is untouched, so the existing
  `Directionality.of == rtl` assertion still passes.
- Editor: `_TranscriptionEditor` gains an optional `TextRange? editRange`; in `initState`, after
  building the controller, clamp the range to `text.length` and apply
  `_controller.selection = TextSelection(baseOffset: r.start, extentOffset: r.end)` when valid.
  `TranscriptionTextPanel` passes `state.editRange`. Identifiers `voice_transcript_text_field`
  and `voice_transcript_save_edit_button` unchanged.

### 6. Language chip (new widget file `presentation/widgets/transcription_language_chip.dart`)
- Renders **only** when `state.language` maps to a known code: `ar-LB` →
  `l10n.transcriptionLanguageArabicLebanese`, `ar` → `…Arabic`, `en` → `…English`; anything else
  (incl. null) → `SizedBox.shrink()`. Never echo an unknown code raw; never derive from
  `Localizations.localeOf` (that would fabricate a detection result). Label via
  `l10n.transcriptionLanguageDetected(displayName)`.
- Meta-role pill: use `JeebSelectChip` with the `meta` role if the kit shipped it (plan line 235
  bakes the meta scale into the chip enum); otherwise a local pill —
  `surfaceContainerHigh` fill, `OmdsBorderRadius.pill`, padding
  `EdgeInsets.symmetric(horizontal: Spacing.small, vertical: Spacing.twoXSmall)` (12/4 vs design
  12/5), `jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700)` in `colorScheme.onSurface`,
  plus `// TODO(redesign-24): swap to JeebSelectChip(role: meta) when the kit ships it`.
- `Semantics(identifier: TranscriptionKeys.languageChip, container: true)`.
- Until wiring W2/W3 land, `language` is always null and the chip never renders — a stated,
  deliberate divergence from the render, not an oversight.

### 7. Quick-add row (new widget file `presentation/widgets/transcription_quick_add_row.dart`)
- `Wrap(spacing: Spacing.xSmall, runSpacing: Spacing.xSmall)` of up to three
  `JeebSelectChip(role: inlineAction)` (kit §5 #6) — unselected form: white + 1.5px outline,
  13/w600. A chip is omitted once its id is in `state.appliedQuickAdds`.
- Labels: `l10n.transcriptionQuickAddQuantity` / `…Brand` / `…Budget` (no `+` in the ARB values).
  The `+` prefix: a leading `Icons.add` glyph if the chip has a leading slot; otherwise compose
  `'+ ${label}'` in code — under an RTL base direction the leading `+` mirrors correctly; baking
  it into the ARB would not.
- Tap → `cubit.applyQuickAdd(id, l10n.transcriptionQuickAddFragmentQuantity /* etc. */)`. Each chip
  gets its `voice_transcript_quick_add_*` Semantics identifier, `button: true`.

### 8. Screen rebuild (`presentation/transcription_screen.dart`)
- `Scaffold(appBar: null)`. Body: `SafeArea` → `Semantics(identifier: TranscriptionKeys.root,
  container: true, explicitChildNodes: true)` → `Column`:
  1. `JeebTopBar(leading: back, title: l10n.transcriptionTitle, identifier:
     TranscriptionKeys.back)` (kit §5 #1; 06 is a listed consumer; title copy already matches tpl
     306 — no l10n change). Back behavior: rely on the kit's guarded default; if it requires a
     callback, pass `() => Navigator.of(context).maybePop()`. **Never an unguarded pop** (see
     `back_button_blank_surface_test.dart`). Do NOT import go_router here.
  2. `Expanded(child: SingleChildScrollView(child: Column(crossAxisAlignment:
     CrossAxisAlignment.start, children: […])))` with horizontal padding
     `EdgeInsets.symmetric(horizontal: Spacing.xLarge)` (24 gutters — every HTML padding is 24):
     header → audio card (`if state.hasAudio`) → language chip → status banner
     (`if status != ready`, widget untouched) → text panel → quick-add row (only when
     `status == ready` and not editing). Vertical gaps via existing `Spacing` tokens
     (header top ~`Spacing.large`, card gaps `Spacing.medium`/`Spacing.small` — R3).
     **The lower ~45% of the render is real emptiness (R1): top-aligned content, no filler, no
     vertical centering, nothing stretches.**
  3. Footer (outside the scroll area), gated on `!state.isEditing` as today: padding
     `EdgeInsets.fromLTRB(Spacing.xLarge, 0, Spacing.xLarge, Spacing.twoXLarge)` (24/0/24/32,
     tpl 337) → `Column(mainAxisSize: min)`:
     - `JeebCtaButton(variant: primary)` — h56 navy pill, `jeebText.button` white,
       `JeebShadows.ctaNavy`, `isEnabled: state.canConfirm`, `onTap: () =>
       onConfirm?.call(state.text.trim(), state.audioPath ?? '')`, wrapped in the existing
       `Semantics(identifier: TranscriptionKeys.confirmButton, container: true)`. The disabled
       state must swallow the tap — `transcription_screen_test.dart:148–164` pins it (wiring W4).
     - gap `Spacing.small` (design 14 — R3).
     - Re-record: centered `TextButton` (min tap target ≥44), label `l10n.transcriptionReRecord`
       styled `jeebText.cardTitle.copyWith(fontWeight: FontWeight.w600, color:
       colorScheme.onSurfaceVariant)` (design 15/w600 brown-subtitle; cardTitle 15.5 is the
       nearest ramp step), inside the existing `Semantics(identifier:
       TranscriptionKeys.reRecordButton, container: true)`. **Delete the 4-line OMDSOutlinedButton
       contrast comment** — it documents a workaround for a fill that no longer exists.
- Header (`_TranscriptionHeader`): title `context.jeebText.h1` in `colorScheme.onSurface`
  (tpl 308 = 24/w700 exactly); subtitle `context.jeebText.body` in `colorScheme.onSurfaceVariant`
  — deliberately NOT periwinkle: `color_role_contrast_test.dart:129–140` documents
  periwinkle-on-white as a genuine AA failure. Keep `Spacing.xSmall` between (design 6 — R3).
- Add the 8 new consts to `TranscriptionKeys`. Delete `_ConfirmButton`/`_ReRecordButton` classes
  (replaced by the footer composition) — keep their `Semantics` wrappers in the new code.

### 9. Tests
**Keep green with ZERO edits** (this is a hard gate): all 15 tests in
`test/transcription_screen_test.dart` and the transcription case in
`test/core/router/integration_wiring_test.dart` (~:165–203). The `find.text` assertions at :85,
:111, :113, :195, :285–289 and the banner `find.byType(TranscriptionStatusBanner)` at :110/:224
all survive because (a) the transcript is a `Text.rich` with byte-identical plain text, (b) the
placeholder and banner strings/classes are untouched, (c) all identifiers are preserved.

**Add** (new file `test/features/transcription/transcription_redesign_test.dart`, reuse the
existing `_SyncDelegate` harness pattern):
1. Tapping a word enters edit mode with that word pre-selected (controller.selection matches).
2. `find.text(<full transcript>)` still resolves on the `Text.rich` display (plain-text identity
   guard).
3. A quick-add chip appends its fragment exactly once and then disappears; double-tap cannot
   duplicate.
4. Language chip: renders for `ar-LB`, absent for null and for an unknown code.
5. Cubit `seekTo`: clamps below zero / above duration, calls the player (`FakeTranscriptAudioPlayer
   .seekCalls/lastSeek`), no-ops with no playback path.
6. An Arabic transcript under the `en` locale renders the transcript subtree RTL (content-derived
   direction) while the screen stays LTR.
7. A 200% `textScaleFactor` pump does not overflow-crash the footer (DoD).

### 10. Verify
`flutter analyze` — no NEW errors/warnings beyond the 6 pre-existing baseline errors (2×
`Semantics identifier` + 4× `DioExceptionType.transformTimeout`). Run
`flutter test test/transcription_screen_test.dart test/features/transcription/
test/core/router/integration_wiring_test.dart`. Grep the feature dir: no new hex, no `fontSize:`,
no `BorderRadius.circular(` (`tool/check_design_tokens.sh` bans all three under `lib/features`).

---

## Code quality requirements
- Lints in force: `prefer_const_constructors` (const the static spans/paddings/icons),
  `prefer_final_locals`, `sort_constructors_first` (constructor above fields in every new class),
  `use_build_context_synchronously` (no context use after `await` — cubit calls are fire-and-forget
  from tap handlers), `avoid_print`.
- Comments: short, *why*-only (the tree was swept by a comment-size-cap chore). The two mandated
  TODOs use the exact `// TODO(redesign-24): needs gateway <field> — omitted, not faked.` shape.
- New widgets go in `presentation/widgets/` files, not inline in the 263-line screen file:
  `transcription_language_chip.dart`, `transcription_quick_add_row.dart`; the footer/header stay
  private classes in the screen file (small).
- Consume kit widgets; the only sanctioned bespoke pieces are the language-chip fallback pill and
  the two footer text links.

## Stop conditions — "done" means
1. All 15 existing tests + the integration-wiring test pass **unmodified**.
2. All 7 frozen identifiers emitted verbatim; 8 new ones present; screen renders under `ar` and
   `en`, mirrored correctly, at 200% text scale without overflow.
3. No new analyze findings; no token-script violations; no new dependency.
4. No underline, no language chip for unknown/null codes, no invented data, empty lower half
   preserved.
5. Wiring file appended exactly as below.

**Do NOT touch:** `transcription_status_banner.dart` (yes, really — leave it byte-identical),
`lib/core/router/*`, `lib/core/di/*`, `lib/core/theme/*`, `lib/core/widgets/*` (kit is another
lane), `lib/l10n/*` (arb AND `app_localizations.dart`), `pubspec.yaml`, `lib/features/voice_request/**`,
`../omds-flutter`, any test gate, `test/core/**` (the integration-wiring test needs no edit).
Do not rename `TranscriptionStatusBanner` or any public class a test finds by type. Do not delete
`NoopTranscriptAudioPlayer` / `FakeTranscriptAudioPlayer` or any constructor seam.

---

## Wiring requests — exact content for `docs/redesign-2026-08/wiring/06-transcription-review.md`

```markdown
### l10n
file: lib/l10n/app_en.arb, lib/l10n/app_ar.arb, lib/l10n/app_localizations.dart
need: 4 changed values (keys unchanged, no getter changes) + 12 new keys with getters for the transcription-review redesign.
exact change:
Changed EN values (descriptions already exist):
  "transcriptionHeader": "Here's what we heard",
  "transcriptionSubtitle": "Fix anything before we broadcast it.",
  "transcriptionSubmit": "Looks right — continue",
  "transcriptionEdit": "Edit all",
Changed AR values (MSA register, matching the file's existing voice — integrator may retune):
  "transcriptionHeader": "هذا ما سمعناه",
  "transcriptionSubtitle": "عدّل أي شيء قبل بثّ طلبك.",
  "transcriptionSubmit": "تمام — تابع",
  "transcriptionEdit": "تعديل الكل",
New EN keys:
  "transcriptionTapHint": "Tap any word to fix it",
  "@transcriptionTapHint": { "description": "Hint inside the transcript card; every word is tappable to edit just that word" },
  "transcriptionLanguageDetected": "{language} · auto-detected",
  "@transcriptionLanguageDetected": { "description": "Detected-language chip label", "placeholders": { "language": {} } },
  "transcriptionLanguageArabicLebanese": "Lebanese Arabic",
  "@transcriptionLanguageArabicLebanese": { "description": "Display name for detected language code ar-LB" },
  "transcriptionLanguageArabic": "Arabic",
  "@transcriptionLanguageArabic": { "description": "Display name for detected language code ar" },
  "transcriptionLanguageEnglish": "English",
  "@transcriptionLanguageEnglish": { "description": "Display name for detected language code en" },
  "transcriptionQuickAddQuantity": "Quantity",
  "@transcriptionQuickAddQuantity": { "description": "Quick-add chip label (the + glyph is composed in code)" },
  "transcriptionQuickAddBrand": "Brand",
  "@transcriptionQuickAddBrand": { "description": "Quick-add chip label (the + glyph is composed in code)" },
  "transcriptionQuickAddBudget": "Budget",
  "@transcriptionQuickAddBudget": { "description": "Quick-add chip label (the + glyph is composed in code)" },
  "transcriptionQuickAddFragmentQuantity": "Quantity: ",
  "@transcriptionQuickAddFragmentQuantity": { "description": "Text scaffold appended to the request when the Quantity chip is tapped; trailing space intended" },
  "transcriptionQuickAddFragmentBrand": "Brand: ",
  "@transcriptionQuickAddFragmentBrand": { "description": "Text scaffold appended when the Brand chip is tapped; trailing space intended" },
  "transcriptionQuickAddFragmentBudget": "Budget: ",
  "@transcriptionQuickAddFragmentBudget": { "description": "Text scaffold appended when the Budget chip is tapped; trailing space intended" },
  "transcriptionScrubberLabel": "Playback position",
  "@transcriptionScrubberLabel": { "description": "A11y label for the audio replay scrubber" },
New AR values:
  "transcriptionTapHint": "اضغط على أي كلمة لتصحيحها",
  "transcriptionLanguageDetected": "{language} · مكتشفة تلقائيًا",
  "transcriptionLanguageArabicLebanese": "عربي لبناني",
  "transcriptionLanguageArabic": "العربية",
  "transcriptionLanguageEnglish": "الإنجليزية",
  "transcriptionQuickAddQuantity": "الكمية",
  "transcriptionQuickAddBrand": "الماركة",
  "transcriptionQuickAddBudget": "الميزانية",
  "transcriptionQuickAddFragmentQuantity": "الكمية: ",
  "transcriptionQuickAddFragmentBrand": "الماركة: ",
  "transcriptionQuickAddFragmentBudget": "الميزانية: ",
  "transcriptionScrubberLabel": "موضع التشغيل",
Getters for app_localizations.dart (parameterized one follows the replaceFirst idiom at :100–107):
  String get transcriptionTapHint => _get('transcriptionTapHint');
  String transcriptionLanguageDetected(String language) =>
      _get('transcriptionLanguageDetected').replaceFirst('{language}', language);
  String get transcriptionLanguageArabicLebanese => _get('transcriptionLanguageArabicLebanese');
  String get transcriptionLanguageArabic => _get('transcriptionLanguageArabic');
  String get transcriptionLanguageEnglish => _get('transcriptionLanguageEnglish');
  String get transcriptionQuickAddQuantity => _get('transcriptionQuickAddQuantity');
  String get transcriptionQuickAddBrand => _get('transcriptionQuickAddBrand');
  String get transcriptionQuickAddBudget => _get('transcriptionQuickAddBudget');
  String get transcriptionQuickAddFragmentQuantity => _get('transcriptionQuickAddFragmentQuantity');
  String get transcriptionQuickAddFragmentBrand => _get('transcriptionQuickAddFragmentBrand');
  String get transcriptionQuickAddFragmentBudget => _get('transcriptionQuickAddFragmentBudget');
  String get transcriptionScrubberLabel => _get('transcriptionScrubberLabel');
why: The redesign's hint row, language chip and quick-add chips are all user-visible copy; the parity gate fails a key without its getter and both locales.

### cross-feature
file: lib/features/voice_request/data/voice_recording_repository.dart, lib/features/voice_request/presentation/voice_recording_screen.dart (+ that lane's state)
need: Parse and forward the EXISTING documented `language` field of TranscribeResponse ({ audioId, status, transcription, language, reason }).
exact change: TranscriptionResult gains `final String? language;` parsed as `language: body['language'] as String?` next to the existing `transcription` parse (~:70); carry it on VoiceRecordingState.result; widen `typedef VoiceSentCallback` (voice_recording_screen.dart:43–49) with `String? language` — the same additive pattern JEBV4-13 used for localAudioPath/duration.
why: 06's detected-language chip renders only from this field; until it lands the chip deliberately does not render. This reads a documented field — it invents nothing.

### route
file: lib/core/router/app_router.dart
need: Thread `language` into both VoiceClip constructions once the voice_request lane widens VoiceSentCallback.
exact change: at the two `extra: VoiceClip(` sites (~:1079 and ~:1192) add `language: language,` to the named-arg list, and add `String? language` to the enclosing onSent closure parameters to match the widened VoiceSentCallback.
why: transcription/domain/voice_clip.dart already carries `language`; without this 1-line thread per site the chip can never render.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_cta_button.dart (kit lane, plan §5 #2)
need: `JeebCtaButton` needs an `isEnabled` flag whose disabled state does NOT invoke `onTap`.
exact change: `final bool isEnabled;` (default true); when false render the disabled treatment and pass a null tap handler.
why: transcription_screen_test.dart:148–164 pins that a disabled confirm swallows the tap (`confirmCalls == 0`); 06's confirm is gated on `state.canConfirm`.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_top_bar.dart (kit lane, plan §5 #1)
need: The default back action must be pop-GUARDED and directional.
exact change: default back = `Navigator.of(context).maybePop()` (never a bare `Navigator.pop`); glyph via `DirectionalIcons.back(context)`; optional `VoidCallback? onBack` override; `identifier` param emits an explicit `Semantics(identifier: …, button: true)`.
why: test/core/router/back_button_blank_surface_test.dart documents the outage an unguarded pop caused on a `go()`-replaced stack; 06 (and 15 other consumers) inherit whatever default the kit ships.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_meter.dart (kit lane, plan §5 #20)
need: `JeebMeter.scrubber` must be RTL-correct and optionally seekable.
exact change: fill + knob positioned with AlignmentDirectional/PositionedDirectional (a hard `left:` inverts the playhead under ar); optional `ValueChanged<double>? onSeek` reporting a 0–1 fraction on tap/drag; the widget must tolerate an external Semantics wrapper (no internal identifier required).
why: 06 renders the replay scrubber from this variant (design tpl 315–317 draws a Ø14 drag knob); without onSeek the knob is a false affordance and 06 degrades to display-only + TODO.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_select_chip.dart (kit lane, plan §5 #6)
need: Confirm the `meta` chip role ships (plan line 235's scale table bakes "meta chip 12/w700" into the role enum, but §5 #6's role list omits it).
exact change: role `meta`: pill, `surfaceContainerHigh` fill, no border, pad ~5/12, 12/w700 `onSurface`, non-interactive.
why: 06's detected-language chip (and 08's SLA chip per its proposal) need it; 06 ships a local fallback pill with a swap TODO if the role is absent.
```

---

## Deliberate divergences from the render (owner-visible, do not "fix")
1. **No orange underline** on `الفرماشية` — no confidence data exists (verified in the parsed
   contract). Tap-any-word ships instead; hint copy reworded to match.
2. **Periwinkle body copy → `onSurfaceVariant`** (subtitle, timestamps, hint) — periwinkle on white
   is a test-documented AA failure; reverting needs an explicit a11y waiver.
3. **Language chip absent until W2/W3 land** — never guessed from the UI locale.
4. **Token-step deltas** (48 vs 46 disc, 12 vs 14 pads, 20 vs 22 transcript, 15.5 vs 15 link) — R3:
   weight carries hierarchy; do not chase pixels off the ramp.
