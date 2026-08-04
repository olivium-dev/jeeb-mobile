# 05 · Voice recording — change proposal

Target file: `lib/features/voice_request/presentation/voice_recording_screen.dart` (693 LOC)
Host: `lib/features/voice_request/presentation/voice_request_screen.dart` → routes `/voice-request`
**and** `/compose-dictation` (the same screen serves both — every change lands on both flows).
Design: `screens/05-voice-recording.{png,html,note.md}`. Plan: `00-MIGRATION-PLAN.md` §5 (#1, #10,
#14, #15, #22), `02-PLAN-ENHANCED.md` R1/R3/R4/R5/R10.

**Verdict: rebuild.** The design does not restyle the current screen — it re-anchors it. Today the
mic is vertically centred between two `Spacer`s at the middle of the viewport; the design docks a
three-part thumb cluster to the bottom and leaves the top ~60% empty. Two interactions are net new
(slide-to-cancel, the max-duration arc) and one is data-blocked (live transcript).

---

## 0. Semantics inventory — FROZEN, all 10 must still be emitted after the rebuild

Grepped from `lib/features/voice_request/`:

| Identifier | Emitted in phase | Where it moves to |
|---|---|---|
| `voice_request_mic_button` | idle | `JeebMicHero` inside the new bottom cluster |
| `voice_request_blocked_state` | idle + blocking error | unchanged (`OmdsErrorState`) |
| `voice_request_recording_waveform` | recording | the new `JeebWaveform.live` block (was `OmdsRecordingInput`) |
| `voice_request_cancel_button` | recording | the Ø46 `×` satellite at the cluster **start** |
| `voice_request_playback_toggle` | recorded / playing | unchanged (review surface) |
| `voice_request_playback_progress` | recorded / playing | unchanged (review surface) |
| `voice_request_discard_button` | recorded / playing | unchanged (footer, outline pill) |
| `voice_request_send_button` | recorded / playing | unchanged (footer, navy pill) |
| `voice_request_retry_upload_button` | upload failure | unchanged |
| `voice_request_record_another_button` | sent | unchanged |

Plus 11 `VoiceRecordingKeys` (`micButton`, `blockedState`, `recordingWaveform`, `cancelButton`,
`playbackToggle`, `playbackProgress`, `discardButton`, `sendButton`, `uploadErrorState`,
`retryUploadButton`, `recordAnotherButton`) — **all keep their exact `Key('…')` values**;
`voice_recording_keys_test.dart` passes unchanged.

New identifiers (additive only):

| New identifier | Widget |
|---|---|
| `voice_request_root` | the screen `Column` (`container: true` + `explicitChildNodes: true`, §7.5 — otherwise it swallows the 10 above) |
| `voice_request_back` | `JeebTopBar` back circle |
| `voice_request_type_button` | the Ø46 keyboard satellite at the cluster **end** |
| `voice_request_transcript_card` | the live-transcript card (only mounted when a transcript exists) |
| `voice_request_timer` | the `00:07 / 1:00` readout (`value:` = the formatted elapsed) |

---

## 1. Layout & structure

### 1.1 Delete the double `Spacer` — this is the change (R1)

`voice_recording_screen.dart:157-180` is `[subtitle, timer, Spacer, PrimarySurface, Spacer,
ActionRow]`. Two spacers vertically centre the mic. **The design has exactly one spacer and a
bottom-docked cluster.** Replace the whole `builder:` body with:

```
Semantics(identifier: 'voice_request_root', container: true, explicitChildNodes: true,
  child: Column(
    JeebTopBar(...)                       // in-body, pad 14/24/0
    SizedBox(height: Spacing.large)       // 20
    _LiveTranscriptCard(...)              // conditional — see §4.1
    const Spacer()                        // ONE spacer. Real emptiness. Never fill it.
    _RecordingReadout(state)              // waveform + timer + status  (recording only)
    _MicCluster(state)                    // × ← mic → keyboard, Row-based
    SizedBox(height: Spacing.medium)      // 16
    Text(l10n.voiceRecordingHoldToRecord) // 13/w600 mutedText, centered
  ))
```

Gutters: `EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge)` (24) — currently
`Spacing.medium` (16) at line 158. The design gutter is 24 everywhere (§4.3).

### 1.2 Top bar: `OMDSAppBar` → in-body `JeebTopBar`

`voice_recording_screen.dart:124` — delete `appBar:` entirely; the design has no Material app bar,
it has an in-body row: Ø40 `surfaceContainerHigh` circle + 20px navy `DirectionalIcons.back` +
title 20/w700 (`context.jeebText.h2`), gap 14, padding `14/24/0`.

```dart
JeebTopBar(
  leading: JeebTopBarLeading.back,
  identifier: 'voice_request_back',
  onLeading: () => Navigator.of(context).maybePop(),
  title: l10n.voiceRecordingNewRequestTitle,
)
```

Copy: the board says **`New request`**, not today's "Record your request". `voiceRecordingTitle` is
**shared with `escalate_screen.dart:457`** — do NOT repurpose it. Add a new key
`voiceRecordingNewRequestTitle` (EN `New request` / AR `طلب جديد`).

`backFallbacks['voice-request'] = '/'` already exists (`app_router.dart:481`), so `maybePop()` keeps
working under `RootAwareBackScope`. No router change needed for back.

### 1.3 The bottom cluster is a `Row`, not a `Stack`

The HTML positions the satellites absolutely (`left:26` / `right:26`, `bottom:106`) inside a 220px
stack. **Do not port that.** `PositionedDirectional` + magic offsets is the RTL trap on this screen,
and `SizedBox(height: 220)` is a `check_design_tokens.sh` violation in `lib/features`. Build it as:

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    _Satellite(cancel)                     // start — recording only
    Expanded(child: Center(child: JeebMicHero(...))),
    _Satellite(type)                       // end
  ],
)
```

Measured centres agree: mic centre sits 126px off the bottom, satellite centres 129/147px — a
centre-aligned `Row` reproduces the render within a few px and mirrors for free.

### 1.4 Per-phase surfaces

| Phase | Renders |
|---|---|
| `idle` | top bar · (no transcript) · Spacer · timer `00:00 / 1:00` in `mutedText` · mic (no arc, no `×`) · `Type` satellite · `Hold to record` |
| `idle` + blocking error | top bar · Spacer · `_BlockedSurface` (`OmdsErrorState`, unchanged) — replaces the cluster |
| `recording` | + `JeebWaveform.live` · timer in navy · `Recording — release to stop` (accent) · arc on the mic · `×` satellite live · `Type` satellite inert |
| `recorded` / `playing` | review surface (see §1.5) |
| `sending` | review surface + `OmdsLoadingButton` footer (unchanged) |
| `sent` | `JeebInfoNote(tone: success)` + `JeebCtaFooter.single(recordAnother)` |

### 1.5 The review phase has no design — restyle, do not delete

The board covers the recording state only; screen 06 is the *post-upload* transcription review, not
this screen's local playback. Keep `_PlaybackPreview` + `_ActionRow` and restyle:
`_PlaybackPreview` → wrapped in a `JeebOutlinedCard` (white, 1.5px `colorScheme.outline`, r16, **no
shadow** — R7); `_ActionRow` recorded case → `JeebCtaFooter.split` (outline `Record again` +
expanded navy `Submit` pill). Same keys, same identifiers, same order.

### 1.6 Deleted

- `voice_recording_screen.dart:162-171` — the top subtitle `Text` (`voiceRecordingSubtitle` /
  `voiceRecordingReviewTitle` block). The board has no subtitle line above the fold; `Hold to
  record` under the mic carries that job. **Keep `voiceRecordingReviewTitle` on the review phase**
  (it is asserted at `voice_recording_screen_test.dart:99`); only the idle subtitle goes.
- `OmdsRecordingInput` (`:291`) — the WhatsApp-style bar with its own send/cancel icons contradicts
  the design (waveform mark + held mic + satellites). Replaced by `JeebWaveform.live`. Its `Key` and
  `Semantics(identifier:)` migrate verbatim.
- `_TimerLabel` (`:188-232`) — replaced by `_RecordingReadout`.
- `_BroadcastingBanner` (`:491-527`) — folded into `JeebInfoNote(tone: success)`.
- `AnimatedMicButton` (`presentation/widgets/animated_mic_button.dart`) stops being used by the
  screen. **Do not delete the file** — `.claude/worktrees/widget-previews-pilot` renders it and
  nothing in the main tree breaks by leaving it. Add one line to its doc comment noting the live
  screen now uses `JeebMicHero`.

---

## 2. Tokens

The file is already hex-free; what it hardcodes is *semantics* — stock `TextTheme` roles and navy
where the design says orange.

| Current | Line | Becomes |
|---|---|---|
| `OMDSAppBar(title: …)` | 124 | `JeebTopBar` + `context.jeebText.h2` |
| `EdgeInsets.symmetric(horizontal: Spacing.medium)` | 158 | `EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge)` (24 gutter, §4.3) |
| `textTheme.bodyMedium` (subtitle) | 168 | deleted (§1.6) |
| `textTheme.displaySmall` (timer) | 209, 219 | `context.jeebText.statHero` + `FontFeature.tabularFigures()`, ink `colorScheme.primary` (navy) — `mutedText` when idle |
| `colorScheme.outline` (idle timer ink) | 211 | `Theme.of(context).extension<JeebSemanticColors>()!.mutedText` |
| `textTheme.labelMedium` (`{duration} recorded`) | 227 | no longer visible — becomes the `Semantics(label:)` of `voice_request_timer` (keeps the a11y string and the l10n key alive) |
| `textTheme.bodyMedium` (`Hold to record`) | 328 | `context.jeebText.body.copyWith(fontWeight: FontWeight.w600, color: semantic.mutedText)` (13.5/w600 periwinkle; board says 13/w600) |
| `AnimatedMicButton` base `colorScheme.primary` | `animated_mic_button.dart:83` | **`context.jeebRoles.accent` (#D73B00)** — the mic is orange in the redesign, navy today. This is the single most visible token change on the screen (R5: the mic is one of the five sanctioned orange fills) |
| mic glow `base.withValues(alpha: .35)` | `animated_mic_button.dart:128` | `JeebMicHero`'s internal stack: `0 0 0 9 rgba(215,59,0,.15)` + `0 16 34 rgba(215,59,0,.45)` + the Ø184 radial halo (kit-owned, exact px allowed in `lib/core/widgets/jeeb/`) |
| arc track | — | `colorScheme.surfaceContainerHighest` (#E5E1E5), stroke 5; arc `context.jeebRoles.accent`, `StrokeCap.round` |
| transcript card `background` | — | `colorScheme.surfaceContainerHigh` (#EAE7EB), `OmdsBorderRadius.medium` (16) |
| `LIVE TRANSCRIPT` label | — | `JeebSectionLabel(small: true)` — **screen 05 is the only sanctioned consumer of the 11px `small` flag** (§5 #10 / R14) |
| transcript body | — | `context.jeebText.h2` (20/w700) navy |
| status line | — | `context.jeebText.body.copyWith(fontWeight: FontWeight.w600, color: context.jeebRoles.accent)` (13.5/w600 orange) |
| `/ 1:00` limit | — | `context.jeebText.cardTitle.copyWith(fontWeight: FontWeight.w600, color: semantic.mutedText)` (15.5/w600 periwinkle; board 15/w600) |
| satellite captions | — | `context.jeebText.bodySmall` (12/w600) + `mutedText` |
| `colorScheme.primary.withValues(alpha: 0.12)` + `Icons.check_circle` | 477-484 | `JeebInfoNote(tone: success)` — `jeebRoles.successContainer` + Ø30 check |
| `colorScheme.secondaryContainer` + `OmdsBorderRadius.small` | 505-506 | folded into the same `JeebInfoNote` as its sub-line |
| `Sizes.tenXLarge` / `Sizes.fiveXLarge` | 473-483 | owned by `JeebInfoNote` |

**Leave alone:** the `OmdsSeekBar` colors at `:414-419`. `voice_recording_screen_test.dart:111-151`
pins active/inactive contrast ≥3:1 and `thumbColor == activeColor`; navy passes and the board draws
no seek bar. Changing it buys nothing and risks the gate.

Gap tokens (design → nearest `Spacing`, all gate-clean): 20→`large`, 16→`medium`, 14→`small`(12),
10→`small`(12), 8→`xSmall`, 6→`xSmall`(8), 4→`twoXSmall`.

---

## 3. Shared components consumed

| Kit widget (§5) | Replaces | Notes |
|---|---|---|
| **#1 `JeebTopBar`** (`leading: back`) | `OMDSAppBar` | identifier `voice_request_back` |
| **#10 `JeebSectionLabel`** (`small: true`) | — | `LIVE TRANSCRIPT`; the *only* 11px consumer |
| **#14 `JeebWaveform`** mode `live` (~11 bars, accent with an alpha tail, container h40) | `OmdsRecordingInput` | carries `VoiceRecordingKeys.recordingWaveform` + `voice_request_recording_waveform` |
| **#15 `JeebMicHero`** (`size: 128`, `progress:`, `onPressStart/End`, `onSlideCancel`) | `AnimatedMicButton` | carries `VoiceRecordingKeys.micButton` + `voice_request_mic_button` |
| **#22 `JeebInfoNote`** (`tone: success`) | `_SentConfirmation` + `_BroadcastingBanner` | title `voiceRecordingSentTitle`, sub `voiceRecordingSentBody`, trailing none |
| **#3 `JeebOutlinedCard`** | `_PlaybackPreview`'s bare `Column` | white + 1.5px outline + r16, **no shadow** |
| **#2 `JeebCtaButton` / `JeebCtaFooter`** (`split` + `single`) | `_ActionRow`'s raw `Row` of OMDS buttons | keeps every key/identifier |

**Not in the kit and needed here — wiring request:** a Ø46 circular icon action. R10 names it
("circle icon buttons are Ø40 in a top bar and Ø46 in content, filled `surfaceContainerHigh`, glyph
17–20px navy") and it has ≥5 consumers (05 ×2, 12, 16, 21). `Sizes` has no 46 and
`check_design_tokens.sh` bans `SizedBox(width: 46)` in `lib/features`, so it cannot be hand-rolled
in the feature. Ask the Wave-1 kit lane for **`JeebCircleAction`** (`size: 40 | 46`, `icon`,
`onTap`, `identifier`, `enabled`), extracted from `JeebTopBar`'s back circle. Fallback if refused:
`Sizes.fourXLarge` (48) — a 2px divergence, invisible, gate-clean.

---

## 4. New functionality

### 4.1 Live transcript — REFUSED as drawn (no data)

The board's top card streams `جيب لي دوا من الفرماشية` with a caret while the user speaks. **The app
has no streaming speech recognition and cannot get one**: there is no on-device recognizer
(constraint 3 forbids adding `speech_to_text`), and the only transcription contract is
`HttpVoiceRecordingRepository.upload()` → `POST /transcribe`, a one-shot call that happens *after*
the clip is uploaded (`voice_recording_repository.dart:48-73`). Worse, on the happy path the
transcript arrives in `VoiceRecordingPhase.sent`, and the `sent` listener (`:129-145`) immediately
navigates to `/voice-request/transcription` — so even the non-live transcript is never on screen
here.

**Build:** `_LiveTranscriptCard` as a real widget, mounted only when
`state.result?.transcript` is non-empty (identifier `voice_request_transcript_card`). In practice
that is never in the current flow, so the top of the screen is empty — which *matches* the render's
deliberate emptiness better than a fabricated ticker would.

```dart
// TODO(redesign-24): live transcript needs streaming STT. No on-device
// recognizer (no new deps) and /transcribe is post-upload only — omitted,
// not faked.
```

Escalate to the owner: if the live transcript is load-bearing for the product, it is a gateway +
dependency workstream, not a redesign lane.

### 4.2 Max-duration progress arc — BUILDABLE TODAY

`JeebMicHero(progress: …)`, an accent arc on an `#E5E1E5` track, r74 stroke 5, `StrokeCap.round`,
starting at 12 o'clock (the HTML rotates the SVG −90°). Value:

```dart
final progress = (state.elapsed.inMilliseconds /
        VoiceRecordingState.maxDuration.inMilliseconds).clamp(0.0, 1.0);
```

Both fields exist (`voice_recording_state.dart:37`, `:45`) and the cubit already ticks `elapsed`
every 100ms and auto-stops at the cap (`voice_recording_cubit.dart:291-305`). **No cubit or state
change.** The board's dasharray (`54.5 / 410.4` ≈ 11.7%) is consistent with `00:07 / 1:00`.

### 4.3 Slide-to-cancel — new gesture, kit-owned

The `‹ Slide` caption under the `×` is a gesture affordance, not a label. Add to `JeebMicHero`:

- `onSlideCancel` (required when `onPressStart` is set),
- `onCancelIntentChanged(bool)` (optional) so the screen can swap the caption.

Implementation inside the kit widget (the existing `GestureDetector` at
`animated_mic_button.dart:92-98` already has the long-press hooks; add `onLongPressMoveUpdate`):

```dart
final sign = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
final travel = details.offsetFromOrigin.dx * sign;      // negative = toward start
final willCancel = travel <= -_cancelThreshold;          // ~64 logical px
```

On release: `willCancel ? onSlideCancel() : onPressEnd()`. Wire `onSlideCancel` to
`cubit.cancelRecording()` — which already exists (`voice_recording_cubit.dart:120-136`) and is
documented as "the explicit cancel gesture (swipe-to-cancel on the mic button)". **The cubit was
built for this gesture and never got one.** No state change.

The `×` satellite stays independently tappable (same `cancelButton` key + `voice_request_cancel_button`
identifier) — a slide-only cancel is unreachable by switch control and by
`voice_recording_semantics_identifier_test.dart:76`.

### 4.4 Switch-to-typing — new affordance, existing destination

The Ø46 keyboard satellite. **No new route needed.** `/voice-request/transcription` already renders
a typeable field when handed an empty clip — `app_router.dart:1152-1155` falls back to
`const VoiceClip(audioPath: '', durationMs: 0)` precisely so "a `queued` upload (no text yet) drops
the user straight into a typeable field" (`transcription_screen.dart:42-44`, backed by
`transcription_text_panel.dart:151` `OmdsTextField`).

Screen-side seam (the screen must stay router-agnostic — it already is):

```dart
class VoiceRecordingScreen extends StatelessWidget {
  const VoiceRecordingScreen({super.key, this.cubit, this.onSent, this.onSwitchToTyping});
  final VoidCallback? onSwitchToTyping;   // null → the Type satellite is not rendered
```

Mirror the param on `VoiceRequestScreen`. **Wiring request to the integrator** (`app_router.dart` is
integrator-owned):

- `/voice-request` (`app_router.dart:1070`): `onSwitchToTyping: () => context.push('/voice-request/transcription', extra: const VoiceClip(audioPath: '', durationMs: 0))`
- `/compose-dictation` (`app_router.dart:1184`): `onSwitchToTyping: () => context.pop()` — the
  compose field the user came from is one pop away; pushing the transcription review there would
  bypass the dictation return contract.

While `state.isRecording` the Type satellite is drawn (the render shows it) but wrapped in
`IgnorePointer` — the user's thumb is on the mic, and a tap that silently discarded the in-flight
clip would be a destructive surprise. One-line why-comment, no invented "disabled" styling.

### 4.5 Amplitude-driven waveform — explicitly OUT of scope

`record` 6.x exposes `AudioRecorder.onAmplitudeChanged`, so a real level meter is reachable without a
new dependency, but it requires widening the `VoiceRecorder` port and adding a levels field to
`VoiceRecordingState`. The plan specs `JeebWaveform.live` as a decorative animated mark (§5 #14) and
the board's bars are static. Keep it decorative; note the seam for a follow-up.

---

## 5. New routes

**None.** `/voice-request` and `/compose-dictation` both exist; `/voice-request/transcription`
already serves the typed path (§4.4). Two `builder:` argument additions in `app_router.dart` are the
only router work, and they are integrator-owned.

---

## 6. RTL

| Hazard | Fix |
|---|---|
| Satellites positioned `left:26` / `right:26` in the HTML | `Row` with `crossAxisAlignment: center` (§1.3) — start/end, never left/right |
| `‹ Slide` chevron is a literal glyph in the design | Do **not** put `‹` in the l10n string. Render `Row[Icon(DirectionalIcons.back(context), size: Sizes.small), Text(l10n.voiceRecordingSlideToCancel)]` — the chevron flips, the word doesn't need to |
| Slide direction | `Directionality.of(context)`-signed threshold (§4.3). In AR the cancel target is on the **right**, so the cancel gesture travels right |
| `00:07 / 1:00` | mirrors to `1:00 / 00:07` under `ar` unless isolated. Wrap the readout in `Directionality(textDirection: TextDirection.ltr, …)` and keep `FontFeature.tabularFigures()` (§7.1.5: LTR isolates for digits) |
| Transcript body direction | The clip's language is not the UI's. Do not hardcode `direction: rtl` (the HTML does, because its sample is Arabic). Use `Bidi.detectRtlDirectionality(text)` from `package:intl/intl.dart` (already a direct dep, `pubspec.yaml:121`) to wrap the card body, with `TextAlign.start` |
| Caret after the transcript | Ends the *text*, not the line. Render as an inline `WidgetSpan` in the same `Text.rich` so bidi places it, never as a `PositionedDirectional` bar |
| Top bar back glyph | `DirectionalIcons.back(context)` — `JeebTopBar` already does this |
| All paddings | `EdgeInsetsDirectional` throughout (the file already uses it at `:500`) |

Text-scale: at 200% the `statHero` timer + status line + `Hold to record` stack can eat the single
`Spacer`. Give the readout column `mainAxisSize: MainAxisSize.min` and let the `Spacer` collapse to
zero; no `SingleChildScrollView` (it would fight the docked cluster). Verify no overflow-crash at
200% — that is a DoD item.

---

## 7. Test impact

Four test files touch this screen. **Two need edits, both legitimate; two pass untouched.**

**`test/voice_recording_keys_test.dart` — untouched.** Every `VoiceRecordingKeys` value survives on
the new widgets.

**`test/voice_recording_semantics_identifier_test.dart` — untouched.** All four groups
(`mic_button`, `recording_waveform` + `cancel_button`, `playback_toggle` + `playback_progress` +
`send_button`, `record_another_button`) still resolve. This is the file that would catch a mistake:
if it goes red, the proposal is wrong, not the test.

**`test/voice_recording_screen_test.dart` — 3 lines.** All three assert the *concrete OMDS type*,
not behaviour:

| Line | Now | Becomes | Why legitimate |
|---|---|---|---|
| 60 | `expect(find.byType(OmdsRecordingInput), findsNothing)` | `expect(find.byKey(VoiceRecordingKeys.recordingWaveform), findsNothing)` | the recording bar is replaced by `JeebWaveform.live`; the key is the stable contract |
| 77 | `expect(find.byType(OmdsRecordingInput), findsOneWidget)` | `expect(find.byKey(VoiceRecordingKeys.recordingWaveform), findsOneWidget)` | same |
| 101 | `expect(find.text('Press and hold the mic. Release to stop.'), findsNothing)` | unchanged — still passes | the subtitle is deleted everywhere (§1.6) |

Lines 99 (`'Review your recording'`), 104-107, 111-151 (seek-rail contrast), 173, 219 all still pass
because the review phase and the seek bar are preserved deliberately.

**`test/voice_recording_blocked_state_test.dart` — 1 line.** `:102`
`expect(find.byType(OmdsRecordingInput), findsOneWidget)` → `find.byKey(VoiceRecordingKeys.recordingWaveform)`.
Same reason.

**New tests to add** (`test/voice_recording_*`):
1. arc — `JeebMicHero.progress` equals `elapsed / maxDuration` at 7s and clamps at 60s.
2. slide-to-cancel calls `cancelRecording()` in **both** `ltr` and `rtl` (direction-signed threshold).
3. `Type` satellite: absent when `onSwitchToTyping == null`; emits `voice_request_type_button` and
   fires when provided; inert while recording.
4. RTL smoke at `ar` + `textScaleFactor: 2.0` — no overflow.
5. transcript card is absent when `state.result?.transcript` is null (the honest-omission guard, so
   nobody later fakes it).

**Goldens:** none for this screen (only 18 and the 24-sheet). No golden regeneration.

**Maestro — silent-rot risk, flag to the integrator.**
`.maestro/jeeb/devices/R5CT71TVVAJ/flows/pages/voice-request.yaml` drives this screen by
**coordinates**, not identifiers: `longPressOn point: "41.7%,54.9%"` is the mic at its *current*
vertically-centred position. The redesign moves the mic to ≈`50%,78%`, so the flow will long-press
empty space and still "pass" (it only takes screenshots). Recommended fix, in the same PR:
`longPressOn: { id: "voice_request_mic_button" }` — the identifier already exists and is frozen, and
this removes the coordinate dependency permanently. Maestro is not in CI, so nothing catches this.

**l10n:** `voiceRecordingSubtitle` becomes unused. Leave it in both `.arb` files — the parity gate
checks EN↔AR coverage, not call-site usage, and deleting it churns two integrator-owned files for
nothing.

---

## 8. Conflicts and refusals

**C-05.1 — "Recording — release to send" is a lie in this app. REFUSED as written.**
The board's status line promises that releasing the mic uploads the clip. It does not:
`stopRecording()` → `VoiceRecordingPhase.recorded` → a local review with playback, `Record again`
and an explicit `Submit` (`voice_recording_cubit.dart:93-115`, screen `:556-585`). Shipping
"release to send" would mis-describe an irreversible network action.

*Ship instead:* a new key `voiceRecordingStatusRecording` = `Recording — release to stop` /
`جارٍ التسجيل — أفلت للإيقاف`, styled exactly as the board (13.5/w600 accent).

*Owner decision, not an engineering one:* if the intent really is release-to-send (record 05 →
transcription review 06, dropping the local playback step), that deletes five frozen identifiers
(`voice_request_playback_toggle`, `_playback_progress`, `_discard_button`, `_send_button`,
`_record_another_button`) and their tests. Constraint 2 makes that a product change with an
identifier-retirement plan, not something this lane may do silently. **Do not do it in this PR.**

**C-05.2 — Live transcript is data-blocked, not merely missing.** §4.1. No streaming STT exists and
none can be added under constraint 3. Omitted with a `TODO(redesign-24)`; not faked (JEBV4-176).

**C-05.3 — `voiceRecordingTitle` must not be repurposed.** It is shared with
`escalate_screen.dart:457`. New key instead (§1.2).

**No locked-decision conflicts.** `test/decision_violations_test.dart` pins nothing about voice
recording; B04 (no mic in the composer) is chat-only and is *not* engaged here — this screen's mic
is the product.

---

## 9. Risks

1. **The mic turns orange.** The most visible single change; if the owner expected a token-only
   restyle, flag it early. It is R5-sanctioned and non-negotiable for board fidelity.
2. **Emptiness reads as "unfinished"** with the transcript card omitted (§4.1) — the top 100% of the
   screen is white. That is R1 plus a real data gap compounding. Worth showing the owner a build
   screenshot next to the PNG before Wave 5.
3. **`JeebMicHero` gains three params this lane needs** (`progress`, `onSlideCancel`,
   `onCancelIntentChanged`). If the kit lane ships without them, 05 is blocked — raise it at Wave-1
   kickoff, not at integration.
4. **`JeebCircleAction` does not exist in the plan's list** (§3). Without it the Ø46 satellites
   cannot be built gate-clean in `lib/features`.
5. **Maestro coordinate rot** (§7) — invisible in CI by construction.
6. **Both routes get every change.** `/compose-dictation` reuses this screen; the `New request`
   title is slightly wrong there (you are dictating into an existing compose field). Accepted
   divergence; the alternative is a title override param on both screen classes.
