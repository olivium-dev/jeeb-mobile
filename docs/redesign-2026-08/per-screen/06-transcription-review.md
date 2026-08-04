# 06 · Transcription review — change proposal

Screen id: `06-transcription-review`
Design: `screens/06-transcription-review.{png,html,note.md}`
Repo target (confirmed against `screen-repo-map.md`, reachable from `main.dart` via
`app_router.dart:1140` `/voice-request/transcription` **and** `/compose-dictation/review`):

- `lib/features/transcription/presentation/transcription_screen.dart` (263 LOC)
- `lib/features/transcription/presentation/widgets/transcription_audio_card.dart`
- `lib/features/transcription/presentation/widgets/transcription_text_panel.dart`
- `lib/features/transcription/presentation/widgets/transcription_status_banner.dart`
- `lib/features/transcription/application/transcription_cubit.dart`
- `lib/features/transcription/domain/{voice_clip,transcript_audio_player,audioplayers_transcript_audio_player}.dart`

**Verdict: `rebuild`.** The route, the cubit's public surface and all 7 Semantics identifiers
survive, but the chrome (M3 `AppBar` → in-body top bar), the transcript surface (grey slab + a
label row → outlined card with an in-card hint row), the footer (two stacked pills → one pill +
a demoted text link) and three genuinely new interactions (per-word tap-to-fix, quick-add chips,
a seekable scrubber) all change. That is past a restyle.

**Two data findings up front** (§7.6 flagged this screen as "per-word confidence needs a field check"):

1. **Per-word confidence does NOT exist.** The gateway contract is documented verbatim at
   `lib/features/voice_request/data/voice_recording_repository.dart:65` as
   `TranscribeResponse: { audioId, status, transcription, language, reason }`. There is no word
   array, no confidence score, no offsets. `TranscriptionResult` (`:12-20`) carries only
   `id` + `transcript`. **The orange underline is therefore unbuildable and must not be faked.**
   See §4.1 for the honest substitution.
2. **`language` DOES exist in that same documented contract** — but it is dropped at three layers
   (repository parse → `VoiceRecordingState.result` → `VoiceSentCallback` → router → `VoiceClip`).
   Plumbing it is reading an existing documented field, not inventing one, but two of those layers
   are outside this lane. See §4.2 + the wiring requests.

---

## 1. Layout & structure

### 1.1 Target structure (from the HTML, top → bottom)

```
Scaffold(appBar: null)                       // OMDSAppBar deleted
└ SafeArea
  └ Semantics(identifier: 'voice_transcript_root', container, explicitChildNodes)
    └ Column
      ├ JeebTopBar(leading: back, title: l10n.transcriptionTitle)   // pad 14/24/0, tpl 302-306
      ├ Expanded
      │ └ SingleChildScrollView                                     // top-aligned, never stretched
      │   └ Column(crossAxisAlignment: start)                       // 24px gutters
      │     ├ _TranscriptionHeader        h1 + subtitle             // pad 22/24/0, tpl 307-309
      │     ├ TranscriptionAudioCard      r16 grey replay card      // margin 20/24/0, tpl 310-320
      │     ├ _LanguageChip               (only when language != null) // pad 16/24/0, tpl 321-322
      │     ├ TranscriptionStatusBanner   (only when status != ready)
      │     ├ TranscriptionTextPanel      JeebOutlinedCard          // margin 14/24/0, tpl 323-331
      │     └ _QuickAddRow                3 outline pills, wrap     // pad 16/24/0, tpl 332-335
      └ _TranscriptionActions            docked footer              // pad 0/24/32, tpl 337-339
```

### 1.2 What moves

| Change | Where | Why |
|---|---|---|
| `OMDSAppBar` → in-body `JeebTopBar` | `transcription_screen.dart:101` | HTML tpl 302-306: the bar is a *body row* (`padding:14px 24px 0`), a Ø40 `surfaceContainerHigh` circle with a 20px navy arrow, gap 14, title 20/w700. There is no Material elevation, no surface tint, no centered title. Plan §5 #1 lists 06 as a `JeebTopBar` consumer. |
| `ListView` → `SingleChildScrollView` + `Column` | `:131-146` | R1/risk 13: the spacer must be *real emptiness*. A `ListView` with `shrinkWrap:false` inside `Expanded` is fine today only by accident; making the column explicit stops any future lane from letting content expand into the empty lower ~45% the render shows. |
| Gutter 16 → 24 | `:132` `EdgeInsets.all(Spacing.medium)` | Every horizontal padding in the HTML is `24px` (§4.3 `--screen-gutter`). Must become `EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge)`. |
| Language chip **added** between the replay card and the transcript | new `_LanguageChip` | tpl 321-322 + the note ("detected language surfaced as a chip"). |
| Quick-add chip row **added** below the transcript card | new `_QuickAddRow` | tpl 332-335 + the note ("quick-add chips for quantity/brand/budget"). |
| `_TranscriptionLabelRow` ("Transcription" + `Edit text` button) **deleted** | `transcription_text_panel.dart:46-63` | The render has no section label above the card and no icon button; `Edit all` lives *inside* the card's hint row (tpl 326-331). |
| Hint row **added inside** the transcript card | new, in `TranscriptionTextPanel` | tpl 326-331: 15px orange info glyph + hint text + `Spacer` + `Edit all`, `margin-top:14`. |
| `Re-record` demoted from a filled pill to a centered text link | `transcription_screen.dart:238-262` | tpl 339: `margin-top:14; text-align:center; font-size:15; font-weight:600; color: --jeeb-brown-subtitle`. It is not a button surface at all. |
| Status banner keeps its slot but moves above the transcript card | `:140-143` | Unchanged position in practice; stated so the lane does not "helpfully" drop it. The board has no queued/failed state — that degradation path is ours and must survive. |

### 1.3 What is deliberately NOT built

- The 440×956 device frame, the 40px frame radius, `scale(0.55)` and the `9:41` status row (§3, mock chrome).
- The **orange underline** on `الفرماشية` — data-blocked, see §4.1.
- Any additional content in the lower half. The render is ~45% empty below the chip row; that is the design (R1).

---

## 2. Tokens — every hardcoded value that changes

Wave 0 has landed (`lib/core/theme/jeeb_text_styles.dart`, `jeeb_shadows.dart`, the accent quartet,
the 4 semantic colors). Use those symbols verbatim; do not create parallel constants (§4.6).

| Current | file:line | Becomes | HTML evidence |
|---|---|---|---|
| `OMDSAppBar(title:, centerTitle:false)` | `transcription_screen.dart:101` | `JeebTopBar(leading: JeebTopBarLeading.back, title: …, identifier: 'voice_transcript_back')`; `Scaffold(appBar: null)` | tpl 302-306 |
| `EdgeInsets.all(Spacing.medium)` (16) | `:132` | `EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge)` (24) | every `padding: … 24px` |
| `textTheme.titleLarge` | `:168` | `context.jeebText.h1` (24/w700) + `colorScheme.onSurface` | tpl 308 `24px/700/ls -0.5` |
| `SizedBox(height: Spacing.xSmall)` (8) | `:169` | `SizedBox(height: Spacing.twoXSmall + …)` → keep `Spacing.xSmall`; design is 6px, invisible delta | tpl 309 `margin-top:6` |
| `textTheme.bodyMedium` + `onSurfaceVariant` | `:170-175` | `context.jeebText.body` + **`colorScheme.onSurfaceVariant`** (NOT periwinkle — see §7.3) | tpl 309 `14.5/500` |
| `EdgeInsets.all(Spacing.medium)` footer | `:195-196` | `EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, 0, Spacing.xLarge, Spacing.twoXLarge)` (24/0/24/32) | tpl 337 `padding: 0 24px 32px` |
| `OmdsPrimaryButton(text:, isEnabled:, onTap:)` | `:229-233` | `JeebCtaButton(variant: primary, height: 56, isEnabled:, …)` — navy `colorScheme.primary`, `OmdsBorderRadius.pill`, `context.jeebText.button` in `colorScheme.onPrimary`, `boxShadow: JeebShadows.ctaNavy` | tpl 338 `h56 r999 navy 17/600 shadow 0 10 24 rgba(11,19,81,.28)` |
| `SizedBox(height: Spacing.small)` (12) | `:205` | keep (design is 14) | tpl 339 `margin-top:14` |
| `OMDSOutlinedButton(textColor: onPrimary)` + the 4-line contrast comment | `:246-260` | `JeebCtaButton(variant: text)`, label `context.jeebText.titleProminent.copyWith(fontWeight: w600)` in `colorScheme.onSurfaceVariant`, centered. **Delete the comment** — it documents a workaround for a fill that no longer exists. | tpl 339 |
| audio card `EdgeInsets.all(Spacing.medium)` | `audio_card.dart:21` | `EdgeInsetsDirectional.symmetric(horizontal: Spacing.medium, vertical: Spacing.small)` (16/12 vs design 16/14) | tpl 310 `padding: 14px 16px` |
| `surfaceContainerHigh` + `OmdsBorderRadius.medium` | `:23-24` | unchanged — already exact (`#EAE7EB`, r16) | tpl 310 |
| `IconButton.filled(iconSize: Sizes.fourXLarge)` | `:49-55` | Ø48 (`Sizes.fourXLarge`; design 46) navy disc: `Container(decoration: BoxDecoration(color: colorScheme.primary, shape: circle, boxShadow: JeebShadows.raised))` + a 20px white `Icons.play_arrow` / `Icons.pause` | tpl 311-313 `46px r999 navy, shadow 0 8 16 rgba(11,19,81,.25), 20px white ▶` |
| `LinearProgressIndicator` + `outline.withValues(alpha:0.2)` + `OmdsBorderRadius.twoXSmall` | `:76-83` | `JeebMeter.scrubber(...)` from the kit (§5 #20 already names 06 as a consumer) — track h5 r9 `colorScheme.surfaceContainerHighest`, fill `context.jeebRoles.accent`, Ø14 accent knob with `0 2 6 rgba(215,59,0,.4)` | tpl 315-317 |
| `'${_format(pos)} / ${_format(total)}'` in one `labelSmall` | `:85-90`, `:96-101` | Two `Text`s in a `Row(mainAxisAlignment: spaceBetween)`, style `context.jeebText.caption` (11.5/w600) in `colorScheme.onSurfaceVariant`, each wrapped in an LTR isolate; `_format` drops the leading zero on minutes (`0:04`, not `00:04`) | tpl 318-320 `0:04` … `0:07`, `11.5/600` |
| text panel `_TranscriptionTextCard` `surfaceContainerHigh` fill + r16 | `text_panel.dart:96-102` | `JeebOutlinedCard(radius: 16, padding: 20)` — **white fill, 1.5px `colorScheme.outline` (#916F66), NO shadow** | tpl 323 `border: 1.5px --jeeb-brown-outline`; R7 "a white card with a shadow does not exist anywhere on this board" |
| `textTheme.bodyLarge` for the transcript | `:105-109` | `context.jeebText.h2` (20/w700; design 22 — R3: do not chase size) in `colorScheme.onSurface`, `height: 1.6` | tpl 324 `22px/700/navy/line-height 1.6` |
| `TextButton.icon(Icons.edit_outlined, size: Sizes.large)` | `:75-79` | plain tappable `Text` — `context.jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700, color: context.jeebRoles.accent)` (design 13/w700 orange) | tpl 331 |
| banner `EdgeInsets.all(Spacing.medium)` + `OmdsBorderRadius.medium` | `status_banner.dart:83-86` | `JeebInfoNote` geometry — r14–16, pad `12/16`, gap 10, leading glyph `Sizes.medium` (16) | §5 #22 |
| banner `Icon(size: Sizes.large)` | `:121` | `Sizes.medium` (16) | R10 (icons are 14/17/18-20/22/24) |
| `OMDSOutlinedButton` retry | `:154` | `JeebCtaButton(variant: outline)` | §5 #2 |

**No new hex, no new `fontSize:`, no new `BorderRadius.circular(N)` lands in `lib/features`** —
`tool/check_design_tokens.sh` bans all three there, and design-exact px (r9, Ø14 knob, 1.5px stroke)
live inside the kit widgets under `lib/core/widgets/jeeb/`, which the script does not scan.

`transcription_status_banner.dart` is on the `no_raw_semantic_colors_test.dart` list (line 40):
its orange, if any, may come **only** from `context.jeebRoles.accent`. Its current
`jeebRoles.infoContainer` / `colorScheme.errorContainer` pairs are compliant and survive. Wave 0's
error re-tint changes the failed banner from the `#B00020` slab to `#FFDAD6`/`#410002` — intended,
and no test pins the old color.

---

## 3. Shared components consumed

| Kit widget (§5) | Replaces | Notes |
|---|---|---|
| **#1 `JeebTopBar`** (`leading: back`) | `OMDSAppBar` at `:101` | Back must replicate OMDSAppBar's **guarded** pop (`back_button_blank_surface_test.dart:9-19` documents the outage caused by an unguarded `Navigator.pop`): `if (context.canPop()) context.pop();`. `RootAwareBackScope` (`backFallbacks['transcription'] = '/'`, `app_router.dart:485`) covers only *system* back, so the in-body circle needs its own guard. |
| **#2 `JeebCtaButton` + `JeebCtaFooter`** | `_ConfirmButton` `:213-236`, `_ReRecordButton` `:238-262`, `_RetryButton` `status_banner.dart:143` | Footer form is **pill + centered text link**, which is a *fourth* realized form — see wiring request W1. |
| **#3 `JeebOutlinedCard`** | `_TranscriptionTextCard` `text_panel.dart:84-113` | `default` state only; no `selected`, no `dormant`. |
| **#6 `JeebSelectChip`** (`role: inlineAction`) | new `_QuickAddRow` | R2 inline-action pill = pad `9/16–18`, 13/w600, navy ink, unselected = white + 1.5px outline. HTML is `9/15` — same role. |
| **#20 `JeebMeter.scrubber`** | `_PlaybackProgress` `audio_card.dart:60-94` | §5 #20 already lists 06. Needs a directional fill + knob (wiring request W3). |
| **#22 `JeebInfoNote`** | `_BannerSurface` `status_banner.dart:54-98` | Needs two extra tones — wiring request W2. **Keep the public class name `TranscriptionStatusBanner`**; a test asserts `find.byType(TranscriptionStatusBanner)` twice. |
| **meta chip** | new `_LanguageChip` | R2's "meta chip" (pad `4/10`–`5/12`, 12/w700, navy on `surfaceContainerHigh`) is not one of `JeebSelectChip`'s five roles today — wiring request W4. |

Not consumed: `JeebProfileHeader` (this is a top-bar screen), `JeebNavySurfaceCard`,
`JeebAccentFrameCard`, `JeebSectionLabel` (the design shows none), `JeebWaveform` /
`JeebMicHero` (06 shows a scrubber, not a waveform — that is 05's mark).

---

## 4. New functionality

### 4.1 Per-word tap-to-fix — **buildable as an interaction, NOT as a confidence signal**

The note's headline feature is "low-confidence words get a tappable orange underline (fix one word,
not the whole text)". Split it in two:

- **The underline is data-blocked.** No confidence data exists anywhere in the app or the documented
  gateway contract (see the finding at the top). Rendering an orange underline on a word we did not
  measure would assert to the user that the machine flagged it — a fabricated claim, exactly the
  JEBV4-176 failure mode. **Do not render it.**
  Add the field so the day it arrives the paint path is already there:
  ```dart
  /// Char ranges the recognizer flagged as low-confidence. Always empty today.
  // TODO(redesign-24): needs gateway word-confidence offsets on TranscribeResponse
  // — omitted, not faked.
  final List<TextRange> lowConfidenceRanges;
  ```
  and style a span with `decoration: TextDecoration.underline, decorationColor: jeebRoles.accent,
  decorationThickness: 2.5` **only** when its range is in that list.
- **The per-word tap ships.** Every word becomes tappable. That is a client-side editing affordance,
  not a claim about the recognizer, so it is honest and it delivers the actual user value.

**Implementation (chosen over a bottom sheet):** tapping a word calls
`cubit.startEditingWord(range)`, which is `startEditing()` plus a `TextRange? editRange` on state.
`_TranscriptionEditor` (`text_panel.dart:124-141`) applies it once in `initState`:
`_controller.selection = TextSelection(baseOffset: r.start, extentOffset: r.end)`.
The word arrives pre-selected in the existing editor; typing replaces it.
This adds **zero new surfaces, zero new routes and zero new identifiers**, reuses
`voice_transcript_text_field` and `voice_transcript_save_edit_button`, and keeps the surrounding
sentence visible while you fix the word — which a single-word modal does not.

Copy consequence: the hint must read **"Tap any word to fix it"**, not "Tap the underlined word to
fix it", because no underline will render. Otherwise the screen points at something that is not there.

Cubit/state delta: `+ List<TextRange> lowConfidenceRanges` (const empty), `+ TextRange? editRange`,
`+ void startEditingWord(TextRange)`. `confirmEdit` clears `editRange`.

### 4.2 Language chip — needs a field the app currently drops

`Lebanese Arabic · auto-detected` (tpl 322). The `language` field is in the documented
`TranscribeResponse` (`voice_recording_repository.dart:65`) but never parsed. Plumbing it crosses
lane boundaries (see W5/W6). This lane's half:

- `+ String? language` on `features/transcription/domain/voice_clip.dart` (this file **is** mine —
  it is the DTO the router constructs, distinct from `voice_request/domain/voice_clip.dart`).
- `+ String? language` on `TranscriptionState`, seeded in `seedFromClip`.
- `_LanguageChip` renders **only** when `language` maps to a known display name.

Honest rules, because the gateway returns a code (`ar` / `ar-LB` / `en`), not a display string:

```dart
// Only codes we have a localized display name for surface a chip; an unknown
// code is never echoed raw at the user, and never guessed from the UI locale.
```
`ar-LB` → "Lebanese Arabic", `ar` → "Arabic", `en` → "English", anything else → **no chip**.
Never derive the language from `Localizations.localeOf(context)` — that would be a fabricated
detection result. **Until W5/W6 land, the chip simply does not render.** That is a stated,
deliberate divergence from the render, not an oversight.

### 4.3 Quick-add chips (`+ Quantity` / `+ Brand` / `+ Budget`)

Purely client-side text composition — no backend involvement, so no data gap.

Tapping a chip calls `cubit.applyQuickAdd(id, l10n.<fragment>)`, which appends a **localized**
fragment to the text (`"Quantity: "` / `"الكمية: "` — so an Arabic request gets Arabic scaffolding),
enters edit mode, and places the caret at the end via `editRange`. `Set<String> appliedQuickAdds` on
state hides a chip once used so a double tap cannot duplicate the fragment. The user can delete the
fragment; nothing is submitted that the user did not see and approve.

Cubit delta: `+ Set<String> appliedQuickAdds`, `+ void applyQuickAdd(String id, String fragment)`.

### 4.4 Seekable scrubber

The render draws a Ø14 knob (tpl 317) — a knob that does not seek is a false affordance.
`audioplayers` 6.7.1 (`pubspec.yaml:80`) exposes `AudioPlayer.seek(Duration)`, so this is buildable
with **no new dependency** and no backend involvement:

- `+ Future<void> seek(Duration)` on `TranscriptAudioPlayer` (`domain/transcript_audio_player.dart:18-32`)
- implemented in `AudioPlayersTranscriptAudioPlayer` (`await _resolved.seek(position)`),
  `NoopTranscriptAudioPlayer` (no-op) and `FakeTranscriptAudioPlayer` (`seekCalls` + `lastSeek`).
  **Do not delete the Noop/Fake classes** (§7.4) — 4 tests construct them.
- `+ Future<void> seekTo(Duration)` on the cubit: clamps to `[0, audioDuration]`, emits
  `playbackPosition`, calls `_player.seek`, and is a no-op when `playbackPath` is empty (mirrors
  `togglePlayback`'s guard at `:161-162`).

If the kit lane ships `JeebMeter.scrubber` without an `onSeek`, degrade to a display-only meter and
`// TODO(redesign-24)` the drag — do **not** hand-roll a second meter.

### 4.5 Content-derived text direction (a real bug the redesign exposes)

The transcript panel today "inherits RTL from the ambient `Directionality`"
(`text_panel.dart:9-11`). That is wrong for the actual product: a Lebanese-Arabic transcript viewed
in the English UI gets an LTR base direction, so trailing punctuation and any mixed Latin token
(a brand name, a price) order incorrectly. The HTML sets `direction: rtl` on the transcript div
specifically (tpl 324) — the *content's* direction, not the app's.

Fix: wrap the transcript (and only the transcript) in
`Directionality(textDirection: Bidi.detectRtlDirectionality(text) ? TextDirection.rtl : TextDirection.ltr)`
using `package:intl` (`pubspec.yaml:121`, already a direct dep). The screen's own direction is
untouched, so the existing `Directionality.of(...) == rtl` assertion still passes.

---

## 5. New routes

**None.** `newRoutes: []`.

The one candidate was a word-fix surface; §4.1 deliberately realizes it as a pre-selected range in
the existing inline editor instead. That avoids an `app_router.dart` edit (integrator-serialized,
§7.4), avoids touching `backFallbacks`, and avoids adding a route to the w0–w4 route-resolve suites
and `back_nav_all_routes_test.dart`. `/voice-request/transcription` (`app_router.dart:1140`) and
`/compose-dictation/review` both keep their current builders and closures unchanged.

---

## 6. Semantics identifiers

### 6.1 Inventory — must all still be emitted (`grep -rn 'identifier:' lib/features/transcription/`)

| Value (`TranscriptionKeys`) | Today | After |
|---|---|---|
| `voice_transcript_audio_toggle` | `audio_card.dart:46` on `IconButton.filled` | the Ø48 navy play disc |
| `voice_transcript_edit_button` | `text_panel.dart:73` on `TextButton.icon` | the `Edit all` text in the card's hint row |
| `voice_transcript_text_field` | `text_panel.dart:149` | unchanged (`OmdsTextField`) |
| `voice_transcript_save_edit_button` | `text_panel.dart:177` | unchanged |
| `voice_transcript_confirm_button` | `screen.dart:227` | the `Looks right — continue` pill |
| `voice_transcript_re_record_button` | `screen.dart:253` | the demoted centered text link |
| `voice_transcript_retry_button` | `status_banner.dart:152` | the outline retry inside the info note |

All 7 stay as literals on `TranscriptionKeys` (`screen.dart:17-27`) — **never renamed**, since 625
`find.bySemanticsIdentifier` assertions and 83 Maestro flows key off this namespace and Maestro is
not in CI.

### 6.2 New (convention `<screen>_<element>`; the established prefix here is `voice_transcript_`)

| New value | On |
|---|---|
| `voice_transcript_root` | the screen's outermost `Semantics(container: true, explicitChildNodes: true)` — §7.5 requires exactly one `_root` per surface and this screen has none today |
| `voice_transcript_back` | `JeebTopBar`'s Ø40 back circle |
| `voice_transcript_transcript_text` | the tappable `Text.rich` transcript (container) |
| `voice_transcript_scrubber` | `JeebMeter.scrubber` (slider role, `value` = `mm:ss`) |
| `voice_transcript_language_chip` | the detected-language chip (container; non-interactive but QA-addressable) |
| `voice_transcript_quick_add_quantity` | `+ Quantity` |
| `voice_transcript_quick_add_brand` | `+ Brand` |
| `voice_transcript_quick_add_budget` | `+ Budget` |

`voice_transcript_root` must carry `container: true` + `explicitChildNodes: true` or it swallows the
7 nested ids (§7.5; canonical idiom in `active_request_card.dart`).

---

## 7. RTL

The screen is bilingual by definition — an Arabic transcript is the *default* case here, so this is
the highest-RTL-risk screen in Wave 3 after 21.

| Risk in the design | How to build it |
|---|---|
| Top bar `back-circle → title`, gap 14 | plain `Row` + `EdgeInsetsDirectional` — mirrors automatically. Icon must be `DirectionalIcons.back` (`lib/core/widgets/directional_icons.dart:9`), never `Icons.arrow_back`. |
| Scrubber fills from `left:0` and the knob sits at `left:55%` (tpl 316-317) | The fill and the knob must be positioned with `AlignmentDirectional`/`PositionedDirectional` so both grow from the **start** edge. A hard `left` reverses the meaning of the playhead under `ar`. Kit-side (W3). |
| `0:04` … `0:07` at opposite ends (tpl 318) | `Row(mainAxisAlignment: spaceBetween)` mirrors correctly (position lands on the right under `ar` — correct). Each timestamp must be in an **LTR isolate** (`Directionality(textDirection: ltr)` or `⁦…⁩`) so `0:04` never renders as `04:0`. |
| Transcript base direction | §4.5 — derived from content via `Bidi.detectRtlDirectionality`, not from the app locale. |
| Hint row `glyph · text · [flex] · Edit all` (tpl 326-331) | `Row` + `Spacer()`. Never `Positioned(right:)`, never `MainAxisAlignment` chosen by locale. |
| `+ Quantity` — a literal `+` prefix inside the label (tpl 333) | Build as `Row(children: [Icon(Icons.add, size: Sizes.medium), SizedBox(width:…), Text(label)])` so the glyph leads in the reading direction. Do **not** bake `"+ "` into the ARB value — it would trail the word under `ar`. |
| Quick-add chip row wraps (tpl 332 `flex-wrap`) | `Wrap(spacing:, runSpacing:)` — direction-aware by default. |
| CTA and `Re-record` | centered text, direction-neutral. |
| 200% text scale | the CTA label `Looks right — continue` is long; the pill must allow 2 lines or ellipsize rather than overflow-crash (DoD). |

---

## 8. Test impact

Existing coverage: `test/transcription_screen_test.dart` (9 tests) and
`test/core/router/integration_wiring_test.dart:165-203` (1 test).

| Test | Effect | Legitimate? |
|---|---|---|
| `renders the Arabic machine transcription (RTL)` → `find.text('كيلو بندورة من السوق')` `:85` | **BREAKS.** `find.text` matches `Text.data` / `EditableText`, not `Text.rich` — splitting the transcript into per-word `TextSpan`s makes `data` null. Fix: `find.textContaining(...)`, which *does* resolve `Text.textSpan.toPlainText()`. | Yes — the change is required by the per-word tap (§4.1) and `textContaining` asserts the same thing without weakening it. |
| same test → the 4 `_byIdentifier` assertions `:92-95` | pass — all 4 ids survive on their new widgets. | — |
| same test → `Directionality.of(TranscriptionScreen) == rtl` `:87-90` | passes — §4.5 changes only the transcript subtree's direction. | — |
| `shows the queued/empty state` → `find.byType(TranscriptionStatusBanner)` `:110` | passes **only if the class name is kept**. Keep `TranscriptionStatusBanner` as the public name even though it becomes a `JeebInfoNote` internally. | — |
| same → `find.text('Transcription is queued')` `:111` | passes — that copy is unchanged. | — |
| same → `find.text('Type your request here')` `:113` | passes — keep the placeholder branch in `JeebOutlinedCard` (`text_panel.dart:38-39`). | — |
| `confirm fires onConfirm` `:120-146` | passes if `JeebCtaButton` forwards `onTap`. | — |
| `confirm is a no-op while transcript is empty` `:148-164` | passes **only if `JeebCtaButton` has an `isEnabled` flag that swallows the tap**. Wiring request W1. | — |
| `edit → type → save` `:168-197` — `find.byType(TextField)` | passes (`OmdsTextField` wraps a `TextField`). `find.text('edited text')` at `:195` **BREAKS** for the same `Text.rich` reason → `find.textContaining`. | Yes, same cause. |
| `editing to empty drops back to queued` `:199-228` | passes. | — |
| `re-record fires onReRecord` `:232-252` | passes — the `Semantics` wrapper survives the widget swap and the text link is still hit-testable. | — |
| `failed status shows retry banner` `:256-294` | passes — copy and `retryButton` unchanged; the banner's *color* changes (Wave 0's errorContainer re-tint), and nothing pins the color. | — |
| 5 `TranscriptionCubit` tests `:297-369` | pass — `seedFromClip`, `togglePlayback`, `hasAudio`, `canConfirm`, `playbackPath` are all untouched. New fields are additive with defaults. | — |
| `integration_wiring_test.dart:194-201` → `find.text(transcript)` | **BREAKS** — same `Text.rich` cause. This file is `test/core/router/`, **outside this lane's ownership** (§7.4) → wiring request W7. | Yes — one-line `text` → `textContaining`. |

**New tests this lane adds** (all under `test/features/transcription/` or alongside the existing file):
tap-a-word pre-selects that word in the editor; a quick-add chip appends its fragment once and then
hides; the language chip renders for `ar-LB` and does **not** render for `null` or an unknown code;
`lowConfidenceRanges` empty ⇒ no underline is painted; `seekTo` clamps and calls the player;
an AR transcript under the `en` locale renders RTL (§4.5); a 200%-textScale smoke.

**Net: 3 assertion edits (2 mine, 1 an integrator ask), 0 identifier renames, 0 gates weakened.**

---

## 9. Conflicts & refusals

| Item | Verdict |
|---|---|
| **Orange underline on `الفرماشية`** (tpl 325, and the note's headline claim) | **REFUSED — no data.** `TranscribeResponse` is `{ audioId, status, transcription, language, reason }`; there is no word-confidence array and `TranscriptionResult` (`voice_recording_repository.dart:12-20`) keeps only `id` + `transcript`. Painting an underline would fabricate a recognizer verdict. Ship the tap affordance, keep the render path behind `lowConfidenceRanges`, TODO the field (§7.6 policy). |
| **"Tap the underlined word to fix it"** (tpl 329) | **Reworded to "Tap any word to fix it".** Direct consequence of the refusal above — the original copy points at an underline that will not render. |
| **`Lebanese Arabic · auto-detected`** (tpl 322) | **Conditional.** `language` is in the documented contract but unplumbed; renders only when a known code arrives (W5/W6). Never guessed from the UI locale. |
| **Periwinkle body copy** (tpl 309 subtitle, 318 timestamps, 329 hint) | **Divergence, deliberate.** `#777FC0` on white is ~3.2:1 and `color_role_contrast_test.dart:129-140` documents it as a genuine AA failure; §4.1 says "NEVER body text on white" and §4.6 says `JeebSemanticColors` is "decorative only, never body-text ink". These three are sentences, not decoration → render in `colorScheme.onSurfaceVariant` (`#5C4038`, AA, and one of the board's own three inks, R4). Flagged as risk R3 below — reverting to literal periwinkle would need an explicit a11y waiver. |
| **`decision_violations_test.dart`** (D56 / D52 / D20 / D41-D44) | **No conflict.** None of the four touches this screen; the ARB additions carry no "Commission", no vehicle-contract key, no skip affordance. |
| **B04 / pinned-summary / tracking-privacy** (§7.2) | **Not applicable** to 06. |
| **`transcriptionSubmit` = "Send to Jeeb" → "Looks right — continue"** (tpl 338) | **Accept, and it fixes a live copy bug.** Confirming here goes to `/request-summary` (`app_router.dart:1157`) or pops back to the compose field (`/compose-dictation/review`) — nothing is sent to anyone. "Send to Jeeb" is currently misleading on both routes. |
| **`transcriptionSubtitle` → "Fix anything before we broadcast it."** (tpl 309) | Accept, with a caveat: on `/compose-dictation/review` the immediate next step is the compose field, not a broadcast. Both routes do end in a broadcast, so the copy stays true — noted as risk R4. |

---

## 10. l10n (integrator batch — EN key + `@key` description + real AR value + `_get` getter)

**Changed values, keys unchanged** (cheapest path; no new getters, parity-safe):

| Key | EN now | EN target | AR target |
|---|---|---|---|
| `transcriptionHeader` | We turned your voice into text | Here's what we heard | هيدا اللي سمعناه |
| `transcriptionSubtitle` | Edit the text below if anything's off… | Fix anything before we broadcast it. | صلّح أي شي قبل ما نبثّ الطلب. |
| `transcriptionSubmit` | Send to Jeeb | Looks right — continue | تمام — كمّل |
| `transcriptionEdit` | Edit text | Edit all | عدّل الكل |

`transcriptionTitle` ("Review your request" / "راجع طلبك") already matches tpl 306 **exactly** —
no change. `transcriptionReRecord`, the queued/failed banner strings and `transcriptionFieldHint`
are unchanged (three tests assert them verbatim).

**New keys:** `transcriptionTapHint`, `transcriptionBack`, `transcriptionScrubberLabel`,
`transcriptionLanguageDetected` (`"{language} · auto-detected"`, with a placeholders block),
`transcriptionLanguageArabicLb` / `…Arabic` / `…English`,
`transcriptionQuickAddQuantity` / `…Brand` / `…Budget` (chip labels, no `+`),
`transcriptionQuickAddFragmentQuantity` / `…Brand` / `…Budget` (the appended text, e.g.
`"Quantity: "` / `"الكمية: "`).

---

## 11. Wiring requests

| # | To | Ask |
|---|---|---|
| **W1** | Kit lane, §5 #2 | `JeebCtaFooter` needs a **fourth form**: `single` + an optional centered `secondary` text action at `margin-top: 14` (06's `Re-record`; the three specced forms are single / split / textStack). And `JeebCtaButton` needs `isEnabled`, whose disabled state does **not** invoke `onTap` — `transcription_screen_test.dart:148-164` pins that. |
| **W2** | Kit lane, §5 #22 | `JeebInfoNote` needs `info` and `error` tones (role pairs `jeebRoles.info*` / `colorScheme.error*`) alongside `muted`/`success`/`accent`, plus an optional trailing **action** slot for the retry button. Without them 06's queued/failed banner has to stay bespoke. |
| **W3** | Kit lane, §5 #20 | `JeebMeter.scrubber` needs (a) a directional fill + knob (`AlignmentDirectional`/`PositionedDirectional`) so the playhead does not invert under `ar`, and (b) an optional `onSeek(double fraction)` + `identifier`. |
| **W4** | Kit lane, §5 #6/#7 | A `meta` chip role — pill, `surfaceContainerHigh` fill, no border, pad `5/12`, 12/w700 navy, non-interactive. 06's language chip and 08's SLA chip both need it; `JeebTierChip` is emoji-shaped and `JeebSelectChip`'s five roles do not include it. |
| **W5** | Lane 05 (`voice_request`) | Parse and forward the **existing documented** `language` field: `TranscriptionResult { id, transcript, language }` (`voice_recording_repository.dart:64-73`), carry it on `VoiceRecordingState.result`, and widen `VoiceSentCallback` (`voice_recording_screen.dart:43-49`) with `String? language` — the same additive pattern used for `localAudioPath`/`duration` in JEBV4-13. |
| **W6** | Integrator (`app_router.dart`) | Thread that `language` into the two `VoiceClip` constructions at `:1077-1083` and `:1195-1201`. Both are 1-line additions to an existing named-arg list. |
| **W7** | Integrator (core tests) | `test/core/router/integration_wiring_test.dart:196` `find.text(transcript)` → `find.textContaining(transcript)`. Required by the `Text.rich` transcript; asserts the same thing. |

---

## 12. Risks

- **R1 — `Text.rich` breaks `find.text` in 3 places, one of them core-owned.** Cheap to fix and
  semantically identical, but it is a cross-lane edit (W7) and easy to miss until CI.
- **R2 — the seekable scrubber is the only part of this screen that touches a platform plugin.**
  `audioplayers.seek` is well-supported, but if `JeebMeter.scrubber` ships without `onSeek` the knob
  becomes a false affordance. Degrade to display-only + TODO rather than hand-rolling a meter.
- **R3 — the periwinkle → `onSurfaceVariant` substitution is visible.** `#777FC0` and `#5C4038` are
  different hues, not different lightnesses, so the screen will read warmer than the render. Defensible
  (AA + the plan's own §4.1/§4.6 rules) but an owner may want the literal render; that requires an
  explicit a11y waiver, not a silent change.
- **R4 — the screen serves two flows with one copy set.** `/voice-request/transcription` leads to
  `/request-summary`; `/compose-dictation/review` pops back to the compose field. "before we broadcast
  it" is true of both eventually, but the immediacy differs.
- **R5 — the quick-add fragments inject text into the user's request.** Localized and user-visible
  before submit, and deletable — but it is the one place this screen puts words in a user's mouth.
  If the owner objects, degrade the chips to "enter edit mode with the caret at the end" and drop the
  fragment entirely; the chips then differ only by their `Semantics` label, which is weak.
- **R6 — the language chip may never render.** If W5/W6 do not land, 06 ships without the chip that
  the designer's note calls out by name. Visible gap; the alternative is fabricating a detection result.
- **R7 — density (plan risk 13).** After the chip row the render is ~45% white. The natural instinct
  when the status banner and the editor are both absent is to fill it. Do not.
- **R8 — `JeebTopBar` back must be guarded.** `back_button_blank_surface_test.dart` exists because an
  unguarded `Navigator.pop` on a `go()`-replaced screen emptied the Navigator and blanked the app.
  The in-body circle is a fresh chance to reintroduce exactly that bug.
