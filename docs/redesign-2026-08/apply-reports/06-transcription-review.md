# 06 · Transcription review — apply report

**Status: applied.** Tasks 1–10 of `per-screen-revised/06-transcription-review.md` are done. The
one thing not green is the lane's declared l10n dependency (12 undefined getters — see "Blocking
dependency" below), which is the designed hand-off to the serialized integrator, not damage.

---

## ⚠️ READ FIRST — a concurrent-lane hazard I created (screen 05 / voice_recording)

To run the instruction set's hard gate ("all 15 existing tests pass **unmodified**") I had to make
the feature dir compile, which needs the l10n batch. I applied the batch **temporarily**, ran the
suites, and restored `lib/l10n/app_en.arb`, `app_ar.arb`, `app_localizations.dart` from a byte-exact
backup (sha256 verified, `shasum -c` OK). **The three files are exactly as I found them.**

The hazard: the backup snapshot was taken *after* another lane had already started writing those
files, and it captured this state, which is what I restored:

| file | state at backup == state now |
|---|---|
| `lib/l10n/app_en.arb` | clean vs HEAD |
| `lib/l10n/app_ar.arb` | +4 keys: `voiceRecordingNewRequestTitle`, `voiceRecordingStatusRecording`, `voiceRecordingSlideToCancel`, `voiceRecordingTypeInstead` |
| `lib/l10n/app_localizations.dart` | +4 matching getters |

**Those 4 keys have AR values and getters but NO EN values.** I cannot tell whether that is the 05
lane's genuine mid-batch state or whether an `app_en.arb` write of theirs landed inside my ~4-minute
window and was overwritten by my restore. **Integrator: assume the EN side of those 4 keys may be
missing and re-request them from the 05 lane before running the parity gate.** I did not add them —
guessing another screen's EN copy would be worse than flagging it.

Re-checked after other lanes landed further l10n edits (`app_en.arb` is now modified by them): the
4 keys **still** have AR + getter and no EN. So the gap is real right now regardless of its cause.

I should not have touched shared files even temporarily. Recording it here rather than hoping.

---

## Blocking dependency (expected, per the lane workflow)

`dart analyze lib/features/transcription` → **12 issues, all `undefined_getter`/`undefined_method`
on `AppLocalizations`**, and nothing else. They are exactly the 12 new keys in
`docs/redesign-2026-08/wiring/06-transcription-review.md`:

```
transcriptionTapHint · transcriptionLanguageDetected · transcriptionLanguageArabicLebanese
transcriptionLanguageArabic · transcriptionLanguageEnglish · transcriptionQuickAddQuantity
transcriptionQuickAddBrand · transcriptionQuickAddBudget · transcriptionQuickAddFragmentQuantity
transcriptionQuickAddFragmentBrand · transcriptionQuickAddFragmentBudget
transcriptionScrubberLabel
```

With the batch applied (verified locally, then reverted): `dart analyze lib/features/transcription`
→ **No issues found!** and `flutter test test/transcription_screen_test.dart
test/features/transcription/` → **26/26 pass**. Other lanes are in the same state
(`request_summary`, `home_client`, `registration` already have pending getters on main).

---

## What changed

**Modified**
- `lib/features/transcription/domain/voice_clip.dart` — `+ String? language`.
- `lib/features/transcription/domain/transcript_audio_player.dart` — `+ seek()` on the port; no-op
  on `NoopTranscriptAudioPlayer`; `seekCalls`/`lastSeek` on `FakeTranscriptAudioPlayer`. Neither
  class renamed or removed.
- `lib/features/transcription/domain/audioplayers_transcript_audio_player.dart` — `seek` via
  `_player?.seek` (deliberately not `_resolved`: a knob drag before any play must not construct a
  source-less platform player).
- `lib/features/transcription/application/transcription_cubit.dart` — state `+ language`,
  `+ editRange`, `+ appliedQuickAdds`; `copyWith` gains an explicit `clearEditRange` (the `?? this.x`
  idiom cannot null a field out); `seedFromClip` seeds `language`; `+ startEditingWord`,
  `+ applyQuickAdd`, `+ seekTo`; `confirmEdit` clears the range.
- `lib/features/transcription/presentation/widgets/transcription_audio_card.dart` — rebuilt: Ø48
  navy `InkWell` disc with `JeebShadows.raised`, `JeebMeter.scrubber` wired to `cubit.seekTo`, times
  split to the row edges, each forced LTR (`0:04`, never `04:0` under `ar`), leading zero dropped.
- `lib/features/transcription/presentation/widgets/transcription_text_panel.dart` — rebuilt:
  `JeebOutlinedCard` (white, 1.5 outline, r16, pad 20, no shadow); transcript as a `Text.rich` of
  one tappable `TextSpan` per word; hint row moved **inside** the card with `Edit all` at the end
  edge; content-derived `Directionality` over the transcript only; editor gained `editRange`
  pre-selection. `_TranscriptionLabelRow` and the old `_EditAction` deleted.
- `lib/features/transcription/presentation/transcription_screen.dart` — rebuilt: `appBar: null` +
  `JeebTopBar.back`; scroll column on 24px gutters, top-aligned (the lower ~45% is real emptiness);
  footer outside the scroll with `JeebCtaButton.primary` (`isEnabled: state.canConfirm`) and
  `JeebCtaButton.text` for Re-record. `_ConfirmButton`/`_ReRecordButton` deleted, their `Semantics`
  wrappers re-homed. The 4-line `OMDSOutlinedButton` contrast comment deleted (the fill is gone).

**Created**
- `lib/features/transcription/presentation/widgets/transcription_language_chip.dart`
- `lib/features/transcription/presentation/widgets/transcription_quick_add_row.dart`
- `test/features/transcription/transcription_redesign_test.dart` (11 tests)
- `docs/redesign-2026-08/wiring/06-transcription-review.md`

**Untouched, deliberately:** `transcription_status_banner.dart` (byte-identical — confirmed by
`git status`), `lib/core/**`, `lib/l10n/**` (restored), `pubspec.yaml`, `lib/features/voice_request/**`,
`test/transcription_screen_test.dart`, `test/core/**`.

## Kit widgets consumed

`JeebTopBar.back` · `JeebCtaButton.primary` / `.text` / `.accentText` · `JeebOutlinedCard` ·
`JeebMeter.scrubber` · `JeebSelectChip(role: inlineAction)`. No private copy of any kit widget.

Three instruction-set wiring requests were **already satisfied by the shipped kit** and are recorded
as such in the wiring file rather than re-asked: `JeebCtaButton.isEnabled`, `JeebTopBar`'s guarded
`Navigator.maybePop` default + `identifier`, and `JeebMeter.scrubber`'s `onSeek` +
`AlignmentDirectional` mirroring. The **only** kit gap is `JeebChipRole.meta`, so the language chip
ships the sanctioned local pill with a swap TODO.

## Semantics identifiers

All 7 frozen values emitted verbatim (`audio_toggle` on the disc, `edit_button` on `Edit all`,
`text_field`, `save_edit_button`, `confirm_button`, `re_record_button`, `retry_button` in the
untouched banner). 8 new: `root` (container + explicitChildNodes), `back`, `transcript_text`,
`scrubber`, `language_chip`, `quick_add_quantity` / `_brand` / `_budget`. A test in the new file
asserts the inventory so it cannot rot silently.

## Verification

| check | result |
|---|---|
| `dart analyze lib/features/transcription` | 12 issues, **all** pending-l10n; 0 otherwise |
| `dart analyze lib/features/transcription` *with l10n batch* | No issues found! |
| `dart analyze test/features/transcription` | No issues found! |
| `flutter test test/transcription_screen_test.dart` (15 tests, **unmodified**) | pass |
| `flutter test test/features/transcription/` (11 new) | pass |
| `test/core/router/integration_wiring_test.dart` | **cannot load** — other lanes' pending getters (`request_summary`, `home_client`, `registration`); nothing transcription-related |
| token gate patterns over `lib/features/transcription` | 0 violations (no hex, no `Colors.*`, no `fontSize:`, no raw `BorderRadius.circular(N)`, no banned widgets) |
| rendered goldens at 440×956, `en` and `ar` | band structure, gutters and mirroring match the board; temp files deleted |
| 200% text scale | no overflow exception |

## Deliberate divergences from the render (do not "fix")

1. **No orange underline** on `الفرماشية` — `TranscribeResponse` carries no word-confidence offsets.
   Tap-**any**-word ships instead and the hint copy says so. `TODO(redesign-24)` sits at the span
   builder.
2. **Periwinkle body copy → `onSurfaceVariant`** (subtitle, timestamps, hint) — periwinkle-on-white
   is a test-documented AA failure.
3. **Language chip does not render in production yet** — `state.language` is null until the
   voice_request + router wiring lands. Never guessed from the UI locale.
4. **Token-step deltas** (Ø48 vs 46 disc, 12 vs 14 pads, 20 vs 22 transcript, 15.5 vs 15 link).
