# w3 · lane `motion-voice` — Lottie wiring for 05 + 06

Animations: `mic-listening.json`, `voice-waveform.json`.
Screens: 05 voice recording (`lib/features/voice_request`), 06 transcription review
(`lib/features/transcription`).

Branch `feat/redesign-24-migration`. No branch/commit/push performed. No pubspec, l10n, theme,
router or kit file touched.

---

## 1. What was wired

| Screen | Film | Where | Plays when |
|---|---|---|---|
| 05 | `voice-waveform.json` | the live mark above the `00:07 / 1:00` readout, replacing the static `JeebWaveform.live` **for the recording phase only** | audio is being captured |
| 05 | `mic-listening.json` | a sonar layer *behind* the whole mic cluster, concentric with the Ø128 `JeebMicHero` | the mic is held |
| 06 | `voice-waveform.json` | inline voice mark in the replay card, between the play disc and the scrubber | the clip is actually playing |

### 05 · `voice-waveform.json`
New `lib/features/voice_request/presentation/widgets/recording_waveform.dart`. The kit documents
`JeebWaveform.live` as **static by design** ("no amplitude source"), and motion spec §2.2 names this
film as its moving counterpart — so this is not replacing kit motion, it is supplying motion the kit
deliberately declined to fake. The mark renders at exactly `JeebWaveform.liveHeight` (40dp), so the
docked cluster's vertical rhythm is byte-identical to before; width follows the composition's 320:96
canvas.

The film never appears on an idle composer. `RecordingReadout` already gated the mark on
`state.isRecording`, and that gate is untouched: a pulsing waveform on an idle screen would claim the
mic is listening when nothing is being captured.

### 05 · `mic-listening.json`
Private `_MicListeningPulse` in `mic_cluster.dart`, displayed at **288dp** (1.2× the 240 canvas).
That scale is chosen arithmetically, not by eye:

- the film's own static Ø88 disc lands at Ø105.6 — entirely behind the hero's Ø128 disc, so the
  duplicate mic never shows;
- its rings run Ø115 → Ø240, so a ring emerges from the disc edge at ~49% opacity and has fully
  dissolved at Ø240, well inside the 288 box (no clipped ring);
- 288 < 312, the content width inside the 24dp gutters on a 360dp screen.

The pulse is laid out inside a `SizedBox.square(MicCluster.micExtent)` + `OverflowBox`, so it
overflows the mic square **without** widening the Row or displacing the two satellites.

Nothing here duplicates or fights kit motion: `JeebMicHero`'s glow and halo are static gradients (no
controller), and its max-duration arc is bound to real elapsed time. The film contributes only the
organic listening pulse, exactly the division of labour spec §2.1 asks for.

### 06 · `voice-waveform.json`
Private `_PlaybackWaveform` in `transcription_audio_card.dart`, 24×80dp. It occupies the same box
whether or not the clip is running (frozen on frame 0 when paused), so starting playback never
resizes the scrubber beside it.

06 is not drawn with a waveform on the board render; spec §2.2 nevertheless lists 06 as a consumer
("previewing a voice clip"). Treated as a sanctioned addition, flagged here as a board deviation for
the owner.

---

## 2. Two real bugs the wiring surfaced

**1. Re-parenting the mic cluster kills the live press.** The first cut wrapped the cluster in a
`Stack` only while recording. That re-parents `JeebMicHero` the instant recording starts, disposing
the `State` that is tracking the in-flight pointer — on a real device **release-to-stop and
slide-to-cancel would both silently stop working**, and the clip would be dropped. Caught by
`voice_recording_redesign_test.dart` ("This widget has been unmounted"). Fixed by making the `Stack`
unconditional and letting `_MicListeningPulse` own its own on/off, so the cluster keeps its element
identity across the phase change.

**2. `pumpAndSettle` can no longer be used on the recording phase.** Two looping films now live in
that phase, so the tree never settles while the mic is held — this is inherent to any looping
animation and the kit lane called it out in advance. One helper in
`test/voice_recording_redesign_test.dart` (`_pressAndSlide`) used `pumpAndSettle`; it is now two
`pump()`s with a comment naming the cause. All assertions in that file are unchanged.

**Anyone adding a widget test that drives 05's recording phase must use `pump()`, not
`pumpAndSettle()`.**

---

## 3. Rules honoured

- **Reduce-motion.** 05's waveform falls back to the kit's measured static `JeebWaveform.live` (same
  height, same accent ink, no asset decode). The mic pulse and 06's mark hold frame 0 via
  `animate: false`. Verified by rendering the recording phase under
  `MediaQueryData(disableAnimations: true)`: both marks are still, the pulse shows one static ring.
- **RTL.** Both films are `RTL: none` in 09-MOTION-VALIDATION §8 (radially symmetric / symmetric
  about the centre bar). Neither is wrapped in a flip — deliberately. No `left:`/`right:` introduced;
  the cluster still centres via equal-flex flanks and `AlignmentDirectional`.
- **Surface.** Both films are measured **BOTH** (mic-listening 12.4–16.7% ink, voice-waveform
  5.4–7.6%). Both are placed on white/tonal surfaces here, their strongest case.
- **Semantics.** `voice_request_recording_waveform` is preserved byte-identically, with the same
  `container: true` + `explicitChildNodes: true` pair and the same
  `VoiceRecordingKeys.recordingWaveform` key. The two new decorative layers emit no semantics
  (`ExcludeSemantics`) and are `IgnorePointer`ed — no animation is ever in the way of a tap, and no
  user action waits on a frame.
- **No new strings**, no endpoint/field invented, no pubspec edit, no kit edit.

## 4. Verification

- `dart analyze lib/features/voice_request lib/features/transcription` → **No issues found.**
- 05 + 06 suites (`voice_recording_*` ×8, `transcription_screen_test`,
  `features/transcription/transcription_redesign_test`, plus `integration_wiring_test` and
  `home_tab_create_request_fab_test`) → all pass.
- Pixels: the recording phase and the replay card were rendered to PNG at 390×844 @3x and viewed
  directly, at two points in the loop, plus once under reduce-motion. The waveform bars change
  height between frames, the sonar ring advances, the reduce-motion capture is still.

## 5. Remaining gaps

1. **The 05 mark is ~2× the board's width.** The board draws a 66×40 mark; the film's canvas is
   320:96, so holding the board's 40dp height yields 133dp of width. Height (the layout-critical
   axis) matches exactly; width does not. Fixing it properly means re-authoring `voice-waveform.json`
   on a tighter canvas — a spec amendment, not an implementer's call.
2. **Bar weight.** At 40dp the film's 6px bars render ~2.5dp wide against the board's 4dp; at 06's
   24dp they are ~1.5dp hairlines. The reduce-motion fallback (the kit's static mark) is visibly
   closer to the board than the film is. The film wants ~48dp of height, which 06's row cannot give
   without halving the functional scrubber.
3. **No live transcript.** 05's top card in the render is a streaming-STT surface the app has no
   source for; the existing `TODO(redesign-24)` stands. No film substitutes for it.
4. **`success-check.json` on 05's `sent` phase** is not wired — it belongs to whichever lane owns
   screens 14/15/22/23, and 05's sent confirmation is an interim surface. Listed as deferred.
