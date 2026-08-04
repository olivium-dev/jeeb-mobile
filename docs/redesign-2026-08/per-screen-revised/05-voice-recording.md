# 05 · Voice recording — REVISED instruction set (authoritative)

Reviewed against: the render + HTML (`screens/05-voice-recording.{png,html,note.md}`), the current
source, `00-MIGRATION-PLAN.md` (incl. the STOP block), `02-PLAN-ENHANCED.md` R1/R5/R7/R10/R14 + §3.3.
Every file:line below was re-verified on 2026-08-03. The Opus proposal was largely accurate; the
deltas that matter are in §0.

**Verdict: rebuild** (confirmed). The design re-anchors the screen: today the mic is vertically
centred between two `Spacer`s; the board docks a three-part thumb cluster (× ← Ø128 orange mic →
keyboard) at the bottom with a max-duration arc, a waveform + `00:07 / 1:00` readout above it, and
~60% deliberate emptiness above that. The board draws ONLY the recording state — every other phase
(review, sending, sent, blocked, upload-failure) is undesigned and gets minimum churn.

**Both routes get every change**: `/voice-request` AND `/compose-dictation` mount this same screen
(`app_router.dart:1059`, `:1181`).

---

## 0. Review deltas vs the Opus proposal

**CUT (not evidenced by the render / dead code / not ours to edit):**

1. **`_LiveTranscriptCard` as a real widget — CUT.** Verified data-blocked: the only transcription
   contract is one-shot `POST /transcribe` *after* upload
   (`voice_recording_repository.dart:48-80`), and `state.result?.transcript` is only ever non-null
   in the `sent` phase — where the `sent` listener immediately navigates away on both routes. The
   widget could never render in a real flow; the proposal's own mount condition made it dead code.
   Ship a `TODO(redesign-24)` comment only (task 5). This also cuts the `voice_request_transcript_card`
   identifier, the transcript-absence test, and — note for the kit lane — 05 was the *only*
   consumer of `JeebSectionLabel(small: true)`; that flag now has no consumer.
2. **`onCancelIntentChanged` on `JeebMicHero` — CUT.** The render shows a static `‹ Slide` caption;
   caption-swapping on drag is invented UX. The kit request is `onSlideCancel` only.
3. **Any edit to `animated_mic_button.dart` — CUT.** The proposal contradicted itself (edit `:83`
   and `:128` for orange, but also "stops being used"). Resolution: the widget stops being used by
   this screen and the file is left **completely untouched** (the widget-previews worktree renders
   it). The orange fill, glow stack, halo and arc all live inside kit `JeebMicHero`.
4. **Direct edit of the Maestro flow — CUT as a direct edit.** `.maestro/...` is a shared surface,
   not this lane's feature dir. The coordinate-rot finding is real and verified
   (`longPressOn point: "41.7%,54.9%"` at `voice-request.yaml:10-11`); it becomes a cross-feature
   wiring request (§9).
5. **Sent-phase `JeebInfoNote` fold and review-phase `JeebOutlinedCard` wrap — DEMOTED to
   optional.** The board does not draw these phases; both surfaces keep their current widgets by
   default (see task 10). Skipping the optional polish does NOT fail DoD for this screen.

**CORRECTED:**

- **Baseline:** the prompt's "11 issues / 6 errors" is SUPERSEDED (plan STOP-2). Current baseline:
  `flutter analyze` = **5 issues, 0 errors** (local-SDK deprecation infos). Your bar: no new issues
  of any severity.
- **Waveform bar count:** the HTML has exactly **10 bars** (tpl 258-267), not ~11. Bars w4, r9,
  gap 4, heights 12–38, container h40, orange with alpha tails .30–.50 — the kit `live` mode owns
  the exact values; you just mount it.
- **The mic-orange change** is delivered by consuming `JeebMicHero`, not by editing any file.

**CONFIRMED as written (spot-checked, all correct):** the frozen identifier/key inventory; every
screen-file line cite; `backFallbacks['voice-request'] = '/'` at `app_router.dart:481`;
`cancelRecording()` at `voice_recording_cubit.dart:117-136` documented for exactly this gesture and
never wired; tick + auto-stop at cap at `:291-305`; `maxDuration = 60s` / `elapsed` in
`voice_recording_state.dart`; the `/voice-request/transcription` empty-clip fallback at
`app_router.dart:1153-1156`; `voiceRecordingTitle` shared with `escalate_screen.dart:457`
(and `voiceRecordingHoldToRecord` shared at `:450` — reuse both, never re-word either);
`decision_violations_test.dart` pins nothing about this screen; `intl` is a direct dep
(`pubspec.yaml:121`); `Sizes.fourXLarge == 48`; the C-05.1 copy refusal (§7 below).

---

## 1. Semantics inventory — FROZEN. All 10 must still be emitted, spelled identically.

| Identifier | Phase | New home |
|---|---|---|
| `voice_request_mic_button` | idle + recording | `Semantics(container: true)` wrapping `JeebMicHero` in the cluster |
| `voice_request_blocked_state` | blocking error | unchanged (`OmdsErrorState`) |
| `voice_request_recording_waveform` | recording | the `JeebWaveform.live` block |
| `voice_request_cancel_button` | recording | the Ø46 `×` satellite (cluster start) |
| `voice_request_playback_toggle` | recorded/playing | unchanged |
| `voice_request_playback_progress` | recorded/playing | unchanged |
| `voice_request_discard_button` | recorded/playing | unchanged |
| `voice_request_send_button` | recorded/playing | unchanged |
| `voice_request_retry_upload_button` | upload failure | unchanged |
| `voice_request_record_another_button` | sent | unchanged |

All 11 `VoiceRecordingKeys` constants keep their exact `Key('…')` values —
`test/voice_recording_keys_test.dart` must pass unchanged.

New identifiers (additive only): `voice_request_root` (screen column; `container: true` +
`explicitChildNodes: true`, else it swallows the 10 above), `voice_request_back` (top-bar circle),
`voice_request_type_button` (keyboard satellite), `voice_request_timer` (the readout;
`label:` = `l10n.voiceRecordingTimerLabel(formatted)` — this keeps the existing a11y string and its
l10n key alive after its visible line is deleted).

`test/voice_recording_semantics_identifier_test.dart` asserts the recording phase emits BOTH
`voice_request_recording_waveform` and `voice_request_cancel_button` (`:73-79`) — the × satellite
must exist whenever the waveform does.

---

## 2. Dependencies — check before starting

`lib/core/widgets/jeeb/` does not exist yet (verified). This lane is **blocked until Wave 1
ships**: `JeebTopBar` (leading mode `back`), `JeebWaveform` (mode `live`), `JeebMicHero` (with the
`progress` param the plan already specs in §5 #15, **plus the `onSlideCancel` request in §9**).
`JeebCtaButton`/`JeebCtaFooter` are optional-polish only here. If `JeebMicHero` ships without
`onSlideCancel`, build everything else and leave the gesture as a
`// TODO(redesign-24): blocked on JeebMicHero.onSlideCancel` — do NOT hand-roll a competing
gesture layer around the kit widget.

If `JeebCircleAction` (§9) is refused: build the satellite in-feature as
`SizedBox(width: Sizes.fourXLarge, height: Sizes.fourXLarge)` (48 — a 2px divergence from Ø46,
gate-clean) + circular `DecoratedBox` in `surfaceContainerHigh` + `InkWell`. Never a literal `46`
(`tool/check_design_tokens.sh` bans literal-number `SizedBox` in `lib/features`).

---

## 3. Task list — execute top to bottom

**T1. Write the wiring file.** Create `docs/redesign-2026-08/wiring/05-voice-recording.md` with the
seven requests in §9, verbatim. Then write all screen code as if they are granted.

**T2. Add the `onSwitchToTyping` seam (feature-owned).**
`VoiceRecordingScreen` and `VoiceRequestScreen` (`voice_request_screen.dart`) each gain
`final VoidCallback? onSwitchToTyping;` (constructor param, `sort_constructors_first` order —
fields after constructor per file convention). `null` → the Type satellite is not rendered.
The screen stays router-agnostic; destinations are the router's job (§9 route requests — both
destinations already exist, no new route).

**T3. Rebuild the `builder:` skeleton** (`voice_recording_screen.dart:156-180`). Delete the double
`Spacer` and the idle subtitle block (`:162-171`). New shape:

```
Semantics(identifier: 'voice_request_root', container: true, explicitChildNodes: true,
  child: Column(
    JeebTopBar(...)                        // T4
    // TODO(redesign-24) transcript       // T5
    const Spacer(),                        // ONE spacer. Real emptiness (R1). Never fill it.
    <phase surface>                        // T6–T10, see the phase table §4
    SizedBox(height: Spacing.medium),
    <footer caption / actions per phase>
  ))
```

Gutter: `EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge)` (24, plan §4.3) replaces
`EdgeInsets.symmetric(horizontal: Spacing.medium)` at `:158`.

**T4. Top bar.** Delete `appBar: OMDSAppBar(...)` (`:124`). Mount
`JeebTopBar(leading: back, identifier: 'voice_request_back', onLeading: () =>
Navigator.of(context).maybePop(), title: l10n.voiceRecordingNewRequestTitle)` as the first column
child. Title style is the kit's (`jeebText.h2`). `maybePop()` is safe:
`backFallbacks['voice-request'] = '/'` exists (`app_router.dart:481`). Do NOT repurpose
`voiceRecordingTitle` (shared with `escalate_screen.dart:457`) — new key per §9.

**T5. Live transcript = honest omission.** At the top-of-column slot, one comment only:

```dart
// TODO(redesign-24): live transcript needs streaming STT. No on-device
// recognizer (no new deps) and /transcribe is post-upload only — omitted,
// not faked.
```

No widget, no identifier, no test. The resulting emptiness matches R1.

**T6. `_RecordingReadout`** (new; replaces `_TimerLabel` `:188-232`). Recording phase renders,
top-to-bottom, centred: `JeebWaveform.live` wrapped in
`Semantics(identifier: 'voice_request_recording_waveform', container: true,
label: l10n.voiceRecordingReleaseToStop, child: JeebWaveform.live(key:
VoiceRecordingKeys.recordingWaveform))` — this deletes `OmdsRecordingInput` (`:282-299`); its
send/cancel affordances move to release-to-stop and the × satellite. Then the timer:
elapsed in `context.jeebText.statHero` + `FontFeature.tabularFigures()`, ink `colorScheme.primary`;
`' / ' + _formatDuration(maxDuration)` in `context.jeebText.cardTitle.copyWith(fontWeight:
FontWeight.w600, color: semantic.mutedText)`. Wrap the whole readout row in
`Directionality(textDirection: TextDirection.ltr, ...)` (digit isolate) and in
`Semantics(identifier: 'voice_request_timer', label: l10n.voiceRecordingTimerLabel(...))`.
Then the status line `l10n.voiceRecordingStatusRecording` in
`context.jeebText.body.copyWith(fontWeight: FontWeight.w600, color: context.jeebRoles.accent)`.
Idle phase: timer only, `00:00 / 1:00`, ink `mutedText` (replaces the `colorScheme.outline` idle
ink at `:211`), no waveform, no status line. Read `JeebSemanticColors` via
`Theme.of(context).extension<JeebSemanticColors>()!` — no context shorthand exists.

**T7. `_MicCluster`** (new file `presentation/widgets/mic_cluster.dart` — the screen file is 693
LOC and growing; extract). A `Row`, never the HTML's absolute `Stack`
(`left:26/right:26` + `SizedBox(height: 220)` is both the RTL trap and a token-gate violation):

```dart
Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
  <× satellite>            // recording only; otherwise a same-size placeholder to keep the mic centred
  Expanded(child: Center(child: <mic>)),
  <Type satellite>         // only when onSwitchToTyping != null
])
```

- Mic: `Semantics(identifier: 'voice_request_mic_button', container: true, child:
  JeebMicHero(size: 128, key: VoiceRecordingKeys.micButton, isRecording: state.isRecording,
  progress: <T8>, onPressStart: cubit.startRecording, onPressEnd: cubit.stopRecording,
  onSlideCancel: cubit.cancelRecording, semanticLabel: l10n.voiceRecordingMicSemantic))`.
  Keep the existing why-comment about `Semantics(identifier:)` surfacing as the Android
  resource-id (`:310-312`).
- × satellite: circle action + `Key(VoiceRecordingKeys.cancelButton)` +
  `Semantics(identifier: 'voice_request_cancel_button', container: true, label:
  l10n.voiceRecordingCancel)`, `onTap: cubit.cancelRecording`. Caption beneath:
  `Icon(DirectionalIcons.back(context))` at a small token size + `Text(l10n.voiceRecordingSlideToCancel)`,
  both `jeebText.bodySmall` + `mutedText`. The chevron is a widget, never a `‹` in the l10n string.
- Type satellite: keyboard glyph, `Semantics(identifier: 'voice_request_type_button')`,
  `onTap: onSwitchToTyping`. While recording, wrap in `IgnorePointer` with a one-line why-comment
  (thumb is on the mic; a tap that discarded the in-flight clip would be destructive).
- Below the cluster: `Text(l10n.voiceRecordingHoldToRecord)` centred,
  `jeebText.body.copyWith(fontWeight: FontWeight.w600, color: mutedText)` (replaces `:326-329`).

**T8. Progress arc.** Pure consumption:
`final progress = (state.elapsed.inMilliseconds / VoiceRecordingState.maxDuration.inMilliseconds)
.clamp(0.0, 1.0);` — pass to `JeebMicHero.progress` while recording, `null`/0 when idle. Both
fields exist; the cubit already ticks at 100ms and auto-stops at the cap
(`voice_recording_cubit.dart:291-305`). **No cubit or state change.** Arc geometry (r74, stroke 5,
12-o'clock start, `surfaceContainerHighest` track) is kit-owned — do not re-draw it in-feature.

**T9. Slide-to-cancel.** Already wired in T7 (`onSlideCancel: cubit.cancelRecording` — the cubit
method built for this gesture, `voice_recording_cubit.dart:117-136`). The gesture itself
(direction-signed ~64px travel toward the cluster start) lives in the kit widget (§9 request).
The × satellite stays independently tappable — a slide-only cancel is unreachable by switch
control and fails `voice_recording_semantics_identifier_test.dart`.

**T10. Undesigned phases — relocate, don't redesign.** Under the new skeleton:
- *Blocked* (idle + blocking error): `_BlockedSurface` unchanged, replaces the cluster.
- *Recorded/playing/sending*: render `Text(l10n.voiceRecordingReviewTitle)` above `_PlaybackPreview`
  (`test/voice_recording_screen_test.dart:99` pins the literal text — today it comes from the
  deleted subtitle block, so it MUST be re-homed here), then `_PlaybackPreview` and the existing
  `_ActionRow` recorded/sending cases, all keys/identifiers/strings intact. Leave the `OmdsSeekBar`
  colors at `:414-419` alone — `voice_recording_screen_test.dart` pins the contrast and
  `thumbColor == activeColor`.
- *Upload failure* and *sent*: unchanged (`_UploadFailureSurface`, `_SentConfirmation`,
  `_BroadcastingBanner`, `_UploadFailureActions`).
- OPTIONAL polish, only if the kit widgets exist and every pinned string/key/identifier survives
  verbatim: wrap `_PlaybackPreview` in `JeebOutlinedCard` (no shadow — R7); swap the recorded
  footer to `JeebCtaFooter.split`; fold sent into `JeebInfoNote(tone: success)` +
  `JeebCtaFooter.single`. Pinned strings that must survive any polish: `Review your recording`,
  `Record again`, `Submit`, `Retry upload & submit`, `Record another`.

**T11. Test edits (this lane's own files — edit directly, 3 lines total):**
- `test/voice_recording_screen_test.dart:60`
  `find.byType(OmdsRecordingInput)` → `find.byKey(VoiceRecordingKeys.recordingWaveform)` (findsNothing).
- `test/voice_recording_screen_test.dart:77` same swap (findsOneWidget).
- `test/voice_recording_blocked_state_test.dart:102` same swap (findsOneWidget).
- `:101` (`'Press and hold the mic. Release to stop.'` findsNothing) passes unchanged — the idle
  subtitle is deleted everywhere. `voice_recording_keys_test.dart` and
  `voice_recording_semantics_identifier_test.dart` must pass **untouched** — if either goes red,
  your change is wrong, not the test.

**T12. New tests** (in this lane's `test/voice_recording_*` files):
1. Arc: the `JeebMicHero` in the tree has `progress == elapsed/maxDuration` at 7s; clamps to 1.0 at cap.
2. Slide-to-cancel reaches `cancelRecording()` (idle phase after slide) in `ltr` AND `rtl`.
3. Type satellite: absent when `onSwitchToTyping == null`; emits `voice_request_type_button` and
   fires when provided; inert while recording.
4. RTL + text-scale smoke: `ar` at `textScaleFactor: 2.0`, recording phase, no overflow (give the
   readout `mainAxisSize: MainAxisSize.min` so the single `Spacer` absorbs growth; no scroll view —
   it would fight the docked cluster).
No goldens exist for this screen; regenerate nothing.

**T13. Self-check before handing off:** `flutter analyze` shows only the 5 baseline infos;
`flutter test test/voice_recording_*` green; `grep -rn "identifier:" lib/features/voice_request/`
still lists all 10 §1 values verbatim; no `fontSize:`, hex, literal-number `SizedBox`, or
`BorderRadius.circular(N)` added in `lib/features`; every new padding is `EdgeInsetsDirectional`.

---

## 4. Phase table (what renders under the T3 skeleton)

| Phase | Surface |
|---|---|
| idle | top bar · TODO slot · Spacer · timer `00:00 / 1:00` (mutedText) · cluster (mic navy→**orange via kit**, no arc, no ×, Type present) · `Hold to record` |
| idle + blocking error | top bar · Spacer · `_BlockedSurface` (replaces cluster) |
| recording | + waveform · timer navy · status accent · arc on mic · × live · Type inert |
| recorded / playing | top bar · Spacer · review title + `_PlaybackPreview` · `_ActionRow` (recorded case) |
| sending | as recorded, `OmdsLoadingButton` footer |
| upload failure | `_UploadFailureSurface` + `_UploadFailureActions` |
| sent | `_SentConfirmation` + record-another (unchanged) |

## 5. Code quality

- Lints in force: `prefer_const_constructors`, `prefer_final_locals`, `sort_constructors_first`,
  `use_build_context_synchronously`, `avoid_print`. New widget classes: constructor first, fields
  after, `const` constructors where possible.
- Comments: short, why-only (the repo swept comment size). The two sanctioned comments are the T5
  TODO and the T7 IgnorePointer why-line, plus preserved existing ones.
- Extraction: `mic_cluster.dart` (T7) into `presentation/widgets/`; `_RecordingReadout` may stay
  in-file if <80 lines. Do not grow the screen file past its current 693 LOC.
- Consume kit widgets; never re-derive their px/colors in-feature (`lib/core/widgets/jeeb/` owns
  design-exact values).

## 6. Locked decisions & refusals (carry into PR notes)

- **C-05.1 — the board's "Recording — release to send" is REFUSED as copy.** Release goes to a
  local review with an explicit Submit (`stopRecording()` → `recorded`; and <1s → `tooShort`, not
  send). Ship `voiceRecordingStatusRecording` = "Recording — release to stop". If the owner wants
  true release-to-send, that deletes five frozen identifiers — a product change, NOT this PR.
- **C-05.2 — live transcript is data-blocked** (§0 cut 1). Omitted, not faked (JEBV4-176).
- **C-05.3 — `voiceRecordingTitle` and `voiceRecordingHoldToRecord` are shared with
  `escalate_screen.dart` (`:457`, `:450`)** — reuse, never re-word; new title key instead.
- No `decision_violations_test.dart` conflicts (verified — zero voice pins). B04 is chat-only;
  this screen's mic is the product.

## 7. Stop conditions

**Done means:** T1–T13 complete; recording/idle phases match the PNG (mock chrome excluded);
all 10 identifiers + 11 keys byte-identical; the 3 test-line edits and ≥4 new tests green; analyze
= 5 baseline infos, zero new; RTL + 200% smoke passes; wiring file written.

**Do NOT touch:** `animated_mic_button.dart` (any line) · the cubit, state, repository, domain
files (zero logic changes needed — verified) · `OmdsSeekBar` colors `:414-419` ·
`voice_recording_keys_test.dart` · `voice_recording_semantics_identifier_test.dart` · any file
outside `lib/features/voice_request/` + this lane's `test/voice_recording_*` files · `.maestro/**` ·
`lib/l10n/*`, `lib/core/router/*`, `lib/core/theme/*`, `lib/core/widgets/**`, `pubspec.yaml` (all
wiring/kit-owned) · the `voiceRecordingSubtitle` arb entries (unused after this change — leave; the
parity gate checks coverage, not usage).

---

## 8. Wiring requests — paste into `docs/redesign-2026-08/wiring/05-voice-recording.md` (T1)

### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart
need: four new keys for the redesigned recording surface (title, status line, satellite captions).
exact change:
```
app_en.arb:
  "voiceRecordingNewRequestTitle": "New request",
  "@voiceRecordingNewRequestTitle": {"description": "Top-bar title on the voice recording screen (redesign 05)."},
  "voiceRecordingStatusRecording": "Recording — release to stop",
  "@voiceRecordingStatusRecording": {"description": "Live status line while recording. Deliberately 'stop', not the board's 'send' (C-05.1): release opens a local review."},
  "voiceRecordingSlideToCancel": "Slide",
  "@voiceRecordingSlideToCancel": {"description": "Caption under the cancel satellite; the directional chevron is a widget, not part of the string."},
  "voiceRecordingTypeInstead": "Type",
  "@voiceRecordingTypeInstead": {"description": "Caption under the keyboard satellite that switches to typed input."},
app_ar.arb:
  "voiceRecordingNewRequestTitle": "طلب جديد",
  "voiceRecordingStatusRecording": "جارٍ التسجيل — أفلت للإيقاف",
  "voiceRecordingSlideToCancel": "اسحب",
  "voiceRecordingTypeInstead": "اكتب",
app_localizations.dart (with the other voiceRecording getters):
  String get voiceRecordingNewRequestTitle => _get('voiceRecordingNewRequestTitle');
  String get voiceRecordingStatusRecording => _get('voiceRecordingStatusRecording');
  String get voiceRecordingSlideToCancel => _get('voiceRecordingSlideToCancel');
  String get voiceRecordingTypeInstead => _get('voiceRecordingTypeInstead');
```
why: the board's title/status/captions are new user-visible strings; `voiceRecordingTitle` cannot be repurposed (shared with escalate_screen.dart:457).

### route
file: lib/core/router/app_router.dart
need: the `/voice-request` builder passes the new switch-to-typing callback.
exact change: inside the existing `GoRoute` at path `/voice-request` (`:1059`), add to the `VoiceRequestScreen(...)` arguments:
```dart
onSwitchToTyping: () => context.push(
  '/voice-request/transcription',
  extra: const VoiceClip(audioPath: '', durationMs: 0),
),
```
why: the Type satellite; the transcription route already renders a typeable field for an empty clip (app_router.dart:1153-1156).

### route
file: lib/core/router/app_router.dart
need: the `/compose-dictation` builder passes the callback as a pop.
exact change: inside the `GoRoute` at path `/compose-dictation` (`:1181`), add to the `VoiceRequestScreen(...)` arguments:
```dart
onSwitchToTyping: () => context.pop(),
```
why: the compose field the user dictates into is one pop away; pushing the transcription review there would bypass the dictation return contract.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_mic_hero.dart (Wave-1 kit lane)
need: `JeebMicHero` gains a required-when-recording `VoidCallback onSlideCancel`, fired instead of `onPressEnd` when the long-press drag travels ≥ ~64 logical px toward the cluster start (direction-signed: `Directionality.of(context) == TextDirection.rtl ? -1 : 1` × `offsetFromOrigin.dx`).
exact change: add `onLongPressMoveUpdate` tracking to the existing long-press gesture; on release, `willCancel ? onSlideCancel() : onPressEnd()`. Also confirm the `progress` param (already in plan §5 #15) ships with an idle (null/0) state.
why: screen 05's `‹ Slide` affordance, wired to `VoiceRecordingCubit.cancelRecording()` which was built for this gesture (voice_recording_cubit.dart:117-136). Without the param, 05 ships the cluster with a TODO.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_circle_action.dart (Wave-1 kit lane, NEW widget)
need: a circular icon action per R10 — `size: 40 | 46`, `icon`, `onTap`, `identifier`, `enabled`, fill `surfaceContainerHigh`, glyph 17–20px navy — extracted from `JeebTopBar`'s back circle.
exact change: new kit widget + widget test + RTL smoke, per §5 conventions.
why: 05's two Ø46 satellites (plus consumers on 12, 16, 21). `Sizes` has no 46 and literal-number `SizedBox` is banned in `lib/features`. Fallback if refused: 05 hand-rolls at `Sizes.fourXLarge` (48) — accepted 2px divergence.

### cross-feature
file: .maestro/jeeb/devices/R5CT71TVVAJ/flows/pages/voice-request.yaml (integrator)
need: the flow long-presses the mic by coordinates (`point: "41.7%,54.9%"`, line 10-11) tuned to the OLD vertically-centred layout; the redesign moves the mic to ≈50%,78%, so the flow will press empty space and still "pass" (screenshot-only, not in CI).
exact change: replace the `longPressOn: point:` step with `longPressOn: { id: "voice_request_mic_button" }` (identifier frozen and preserved).
why: silent Maestro rot; the identifier form removes the coordinate dependency permanently.

### cross-feature
file: (informational — Wave-1 kit lane, no code change requested)
need: FYI: `JeebSectionLabel(small: true)`'s only planned consumer was 05's LIVE TRANSCRIPT label; that card is omitted as data-blocked, so the 11px flag currently has zero consumers.
exact change: none.
why: prevents the kit lane building/keeping a flag on a stale consumer claim.
