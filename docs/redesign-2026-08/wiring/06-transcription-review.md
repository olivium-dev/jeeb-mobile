# Wiring requests — 06 · Transcription review

Lane: feature dir `lib/features/transcription/` · screen id `06-transcription-review`.
Written per task 1 of `docs/redesign-2026-08/per-screen-revised/06-transcription-review.md`.
Screen code in `lib/features/transcription/**` is already written **as if every request below is
granted** — the l10n batch is the one that must land for the feature dir to analyze clean.

Re-verified against the tree on 2026-08-03 (`feat/redesign-24-migration`, main `03c6c74`):

- `JeebCtaButton.isEnabled` **already ships** (`jeeb_cta_button.dart:80` and the general ctor) —
  the instruction set's W4 is **satisfied, no request needed**.
- `JeebTopBar`'s default back is **already** `Navigator.maybeOf(context)?.maybePop()` and it already
  takes an `identifier` — W5 is **satisfied, no request needed**.
- `JeebMeter.scrubber` **already** takes `onSeek` and positions fill/knob with
  `AlignmentDirectional` — W6 is **satisfied, no request needed**. 06 wires the real seek.
- `JeebSelectChip` ships **five** roles (`filter sort choice quickReply inlineAction`) and **no
  `meta` role**. 06 therefore ships the sanctioned local fallback pill for the detected-language
  chip, with the swap TODO in place. Request kept below as informational for the kit lane.

---

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
why: The redesign's hint row, language chip and quick-add chips are all user-visible copy; the parity gate fails a key without its getter and both locales. **Until this lands, `lib/features/transcription/` does not compile** — the 12 getters are the lane's only blocking dependency.

---

### cross-feature
file: lib/features/voice_request/data/voice_recording_repository.dart, lib/features/voice_request/presentation/voice_recording_screen.dart (+ that lane's state)
need: Parse and forward the EXISTING documented `language` field of TranscribeResponse ({ audioId, status, transcription, language, reason }).
exact change: TranscriptionResult gains `final String? language;` parsed as `language: body['language'] as String?` next to the existing `transcription` parse (~:70); carry it on VoiceRecordingState.result; widen `typedef VoiceSentCallback` (voice_recording_screen.dart:43–49) with `String? language` — the same additive pattern JEBV4-13 used for localAudioPath/duration.
why: 06's detected-language chip renders only from this field; until it lands the chip deliberately does not render. This reads a documented field — it invents nothing.

---

### route
file: lib/core/router/app_router.dart
need: Thread `language` into both VoiceClip constructions once the voice_request lane widens VoiceSentCallback.
exact change: at the two `extra: VoiceClip(` sites (~:1079 and ~:1192) add `language: language,` to the named-arg list, and add `String? language` to the enclosing onSent closure parameters to match the widened VoiceSentCallback.
why: `transcription/domain/voice_clip.dart` now carries `language` (this lane added the field and `seedFromClip` already seeds it); without this 1-line thread per site the chip can never render.

---

### kit
file: lib/core/widgets/jeeb/jeeb_select_chip.dart (kit lane, plan §5 #6)
need: A `meta` chip role — a static, non-interactive pill (plan line 235's scale table bakes "meta chip 12/w700" into the role enum, but the shipped `JeebChipRole` has only filter/sort/choice/quickReply/inlineAction).
exact change: role `meta`: pill, `surfaceContainerHigh` fill, **no border**, pad ~5/12, 12/w700 `onSurface`, non-interactive (no selected state).
why: 06's detected-language chip (`Lebanese Arabic · auto-detected`, tpl 322) and 08's SLA chip need it. 06 ships `transcription_language_chip.dart`'s local fallback pill with a `// TODO(redesign-24)` swap marker until it exists — that file is the only bespoke pill this lane owns and it should be deleted when the role lands.
