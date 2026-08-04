# 10 · Request summary — REVISED instruction set (authoritative)

**Screen id:** `10-request-summary` · **Verdict:** `rebuild` (confirmed)
**Lane owns:** `lib/features/request_summary/**` + `test/features/request_summary/**` + the finder
updates in `test/core/router/request_summary_route_test.dart` (this screen's only widget test).
**Reviewed:** every `file:line` claim in the Opus proposal was checked against source. The three
load-bearing facts are all TRUE (verified 2026-08-03):

1. `/request-type`'s `onTierSelected`/`onContinue` closures are declared LEGACY and never invoked
   (`request_type_screen.dart:51-63`; `_onContinue` pushes `client-location` itself). The only live
   producer is transcription → summary, carrying `description == transcription` + `audioUrl` only.
2. The router builds the draft with `description: text, transcription: text` (`app_router.dart`,
   `/voice-request/transcription` builder) — **the dedupe in task 6 is mandatory** or the sentence
   renders twice and `request_summary_route_test.dart` (`find.text('JEB-4 happy-path draft')`,
   `findsOneWidget`) goes red.
3. `RequestDraft.audioUrl` carries the gateway `audioId`; `VoiceClip.localAudioPath` (the playable
   file, doc: "NOT locally playable" refers to audioPath) and `durationMs` are dropped by the
   router today. The replay bar is blocked on wiring request **W1**.

Also verified: Wave-0 theme exists (`jeebText`, `JeebShadows.ctaNavy`, `jeebRoles.accent`,
`JeebSemanticColors.mutedText`); `lib/core/widgets/jeeb/` does **not** exist yet (precondition
below); `decision_violations_test.dart` has **no** pin touching this screen, "cancel", or
"Broadcast"; AR `requestSummaryTitle` is already «مراجعة وإرسال» so only the EN value diverges from
the board's "Review & send".

## Corrections to the proposal (differences are intentional — follow THIS document)

- **Waveform:** the proposal specced `JeebWaveform.cardMark` (4 bars, gap 2, h≤15) while the board
  (`dc-tpl 581-588`) draws **7 bars, w3, gap 3, h 10/18/12/22/14/20/9, solid ×3 then .45/.45/.35/.35**.
  Neither `cardMark` nor `live` matches exactly and the plan assigns screen 10 no mode. Resolution:
  consume `JeebWaveform.cardMark` expanded (accepted divergence), and file wiring request **W4**
  asking the kit owner whether 10 gets the 7-bar preset. **Never fork a bespoke waveform in this
  feature.**
- **Ramp reality:** `bodySmall` is **12/w600** (not 12.5/w500) and `badge` is **10.5/w800**. Use
  ramp entries as-is; the only `copyWith(fontWeight:)` allowed is **w700** on links and the
  duration read-out. Do not chase 0.5px/one-weight deltas.
- **Extraction is mandatory**, not optional: the rebuilt ticket would push the screen file past
  ~400 LOC. New widgets live in `lib/features/request_summary/presentation/widgets/`.
- **Dropped:** `request_summary_photos` Semantics identifier (row is non-interactive; the
  convention covers interactive widgets only). Dropped the optional devtool-catalog second entry
  (`lib/devtool/**` is outside this lane). Use `EdgeInsets.symmetric` (not
  `EdgeInsetsDirectional.symmetric`) for symmetric padding — direction-agnostic anyway.
- **Promoted:** the EN `requestSummaryTitle` value fix ("Review & submit" → "Review & send") is a
  required part of W2 — the render is the spec, and AR already says "send".
- **Split `isVoice` into two conditions** (the proposal conflated them):
  - badge says VOICE vs TYPED: `draft.audioUrl != null || draft.audioLocalPath != null`;
  - replay band renders: `draft.audioLocalPath != null` **and** the file exists on disk.

## Preconditions — do not start without

1. Wave-1 kit landed in `lib/core/widgets/jeeb/`: `JeebTopBar`, `JeebCtaButton` + `JeebCtaFooter`,
   `JeebOutlinedCard`, `JeebTierChip`, `JeebWaveform`. (Verified absent as of this review.)
2. Wiring requests appended (task 1) — code is then written as if granted; the tree compiles fully
   only after the integrator lands W1/W2 (and W3 if the kit lacks `isLoading`).

---

## Ordered tasks (execute top to bottom)

**1. File the wiring requests.** Append the four blocks in §Wiring below, verbatim, to
`docs/redesign-2026-08/wiring/10-request-summary.md`. Everything after this task assumes they are
granted.

**2. Extend `RequestDraft`** (`lib/features/request_summary/domain/request_draft.dart` — this
lane's file). Add two optional ctor params + finals, keeping the ctor first
(`sort_constructors_first` — the file already complies):

```dart
/// LOCAL-ONLY (never sent): on-device file the recorder wrote, so the summary
/// can replay the clip. `audioUrl` is the gateway audioId — not playable.
final String? audioLocalPath;
/// LOCAL-ONLY: recorded clip length for the replay read-out.
final int? audioDurationMs;
```

Do **not** touch `DioRequestSubmissionService._buildBody` (verified `:63-77`) — the wire body is
unchanged; this is not a contract change. All existing `RequestDraft(...)` call sites keep
compiling (params optional).

**3. Create `presentation/widgets/request_ticket.dart`** — `class RequestTicket` (public
in-feature) plus private `_ModeBadge`, `_VoiceReplayBand`, `_TierRow`, `_RouteTimeline`,
`_PhotosRow`. Structure:

```
Stack(clipBehavior: Clip.none)
├ JeebOutlinedCard(radius 20, 1.5px outline, NO shadow, 1px outlineVariant dividers inset 16)
│  ├ _VoiceReplayBand   — only if audioLocalPath != null (task 4)
│  ├ transcript block   — always (task 6 dedupe)
│  ├ _TierRow           — only if draft.tierName != null (task 7)
│  ├ _RouteTimeline     — only if either address != null
│  └ _PhotosRow         — only if draft.photoUrls.isNotEmpty
└ PositionedDirectional(start: Spacing.medium, top: -9, child: _ModeBadge)
```

- `_ModeBadge`: navy pill (`cs.primary`, `OmdsBorderRadius.pill`), pad
  `EdgeInsets.symmetric(horizontal: Spacing.xSmall, vertical: Spacing.twoXSmall)`, text
  `(isVoiceBadge ? l10n.requestSummaryBadgeVoice : l10n.requestSummaryBadgeTyped).toUpperCase()`
  in `context.jeebText.badge.copyWith(color: cs.onPrimary)`. `toUpperCase()` is EN-effective only;
  AR passes through.
- Route timeline (`dc-tpl 602-613`): `Row` + `EdgeInsetsDirectional`; rail = `Column` (Ø10 ring
  with 3px `cs.primary` border · 2px `cs.surfaceContainerHighest` connector `minHeight 22` · 14px
  `Icons.location_on` in `cs.error`). Labels `l10n.requestSummarySectionPickup`/`...Dropoff` in
  `jeebText.bodySmall` + `mutedText`; values in `jeebText.cardTitle` navy, `maxLines: 1`,
  `TextOverflow.ellipsis` (the route test's `find.text('12 Hamra St, Beirut')` needs each value as
  its own `Text`). Rail metrics (10/3/2/22/14) have no tokens — private consts, one short why.
  The `#E02020` pin literal is REFUSED → `cs.error` (accepted ~2pt divergence).
- Photos (`dc-tpl 615-620`): up to two 40×40 (`Sizes.threeXLarge`) `cs.surfaceContainerHigh`
  tiles radius `OmdsBorderRadius.small` — first `Icons.image_outlined` in `mutedText`, second
  `+N` (LTR-isolated) — then `l10n.requestSummaryPhotosAttached(count)`. Glyph placeholders only;
  **no `Image.network`** (test stubs + no cache dep).

**4. `_VoiceReplayBand`** (private `StatefulWidget` inside `request_ticket.dart`) — first ticket
child, `ClipRRect(borderRadius: BorderRadius.vertical(top: OmdsBorderRadius.large.topLeft))` over
`cs.surfaceContainerHigh`, pad `Spacing.medium`:
- Ø42 navy disc (size from kit/local const) + white play/pause, wrapped
  `Semantics(identifier: 'request_summary_voice_play', button: true, label: isPlaying ?
  l10n.transcriptionPauseAudio : l10n.transcriptionPlayAudio)`;
- `Expanded(child: JeebWaveform.cardMark())` (const if the kit allows — `prefer_const_constructors`);
- duration `mm:ss` from `audioDurationMs` in `jeebText.bodySmall.copyWith(fontWeight:
  FontWeight.w700)` + `mutedText`, wrapped `Directionality(textDirection: TextDirection.ltr)`;
  **omit the read-out when `audioDurationMs == null`** — never fake.
- Playback: reuse the transcription idiom verbatim (verified `transcription_screen.dart:84`):
  screen takes `const RequestSummaryScreen({super.key, this.audioPlayer});` +
  `final TranscriptAudioPlayer? audioPlayer;`, band resolves
  `widget.audioPlayer ?? AudioPlayersTranscriptAudioPlayer()` **lazily in State (late final, not in
  build)**. Imports: `features/transcription/domain/transcript_audio_player.dart` and
  `.../audioplayers_transcript_audio_player.dart` — read-only cross-feature imports (precedent:
  chat imports request_summary domain). Production plays with NO DI/router edit because the
  default is constructed in-widget. `isPlaying` lives in the State — **do not widen
  `RequestSummaryState`** (plain submit-state class, no `copyWith`).
- Guards: `File(draft.audioLocalPath!).existsSync()` gates the disc (disabled disc + no onTap when
  the temp file is gone — never crash); `if (!mounted) return;` after every await
  (`use_build_context_synchronously`); `player.dispose()` in `dispose()`; `onCompleted` resets
  `isPlaying`.

**5. Create `presentation/widgets/broadcast_footer.dart`** — `class BroadcastFooter` docked below
the scroll area (`dc-tpl 622-626`): `JeebCtaFooter.single` (pad `0/24/32` via
`EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, 0, Spacing.xLarge, Spacing.twoXLarge)`), then:
- `JeebCtaButton.primary`: h58 navy pill, `JeebShadows.ctaNavy`, leading 20px
  `Icons.wifi_tethering` white, label `l10n.requestSummaryBroadcastCta`, `isLoading:
  state.isSubmitting` (W3), `onTap: () => context.read<RequestSummaryCubit>().submit()`.
  **Re-home both contracts verbatim:** explicit `Semantics(identifier: 'request_summary_submit',
  button: true, ...)` wrapper (plan §7.5 — never the OMDS `identifier:` param) AND
  `key: const Key('request_summary.submit')`.
- 12px gap (`Spacing.small`), centered `l10n.requestSummaryCancelNote` in `jeebText.bodySmall` +
  `mutedText`. C1 cleared: no decision pin exists on cancel copy; the line describes the user's
  own action and this screen adds no Cancel affordance.

**6. Rewrite `request_summary_screen.dart`** (keep `:19-30` listeners byte-identical; keep the
`draft == null → OmdsLoadingState` guard):

```
Scaffold (NO appBar)
└ SafeArea
  └ Semantics(identifier: 'request_summary_root', container: true, explicitChildNodes: true)
    └ Column
      ├ JeebTopBar.back(title: l10n.requestSummaryTitle, identifier: 'request_summary_back',
      │                 onBack: () { if (context.canPop()) { context.pop(); } else { context.go('/'); } })
      ├ Expanded(child: SingleChildScrollView(
      │     padding: EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.large, Spacing.xLarge, 0),
      │     child: RequestTicket(draft: draft, audioPlayer: audioPlayer)))
      └ BroadcastFooter(isSubmitting: state.isSubmitting)
```

`Expanded` + `SingleChildScrollView` (never a bare `Spacer`) reproduces the board's flex-1 spacer
(`dc-tpl 621`) and survives 200% text scale. The lower ~45% of the render is deliberately white —
do not fill it (plan risk-13). The onBack fallback mirrors `backFallbacks['request-summary'] = '/'`
(`app_router.dart:492`); do NOT add `RootAwareBackScope` — the route is already wrapped. Delete
`_SectionCard`, `_SectionCardContent`, `_SubmitButton`, `_RequestSummaryBody`.

Dedupe (transcript block, mandatory — see fact 2):

```dart
final headline = (draft.transcription?.trim().isNotEmpty ?? false)
    ? draft.transcription!.trim()
    : draft.description.trim();
final sub = draft.description.trim();
final showSub = sub.isNotEmpty && sub != headline;
```

Headline `jeebText.titleProminent` navy (17/w700 ≈ board 18/w700), with per-string direction —
the one place the board's explicit `direction: rtl` (`dc-tpl 591`) is load-bearing:

```dart
Directionality(
  textDirection: Bidi.detectRtlDirectionality(headline)
      ? TextDirection.rtl : TextDirection.ltr,
  child: Text(headline, textAlign: TextAlign.start),
)
```

`Bidi` is from `package:intl/intl.dart` — already a direct dep (`pubspec.yaml:121`), no new
dependency. Sub-line `jeebText.bodySmall` + `mutedText`; trailing `Edit` link.

**7. Tier row + localized tier copy** (fixes the live i18n leak — `:73` renders the raw slug
today). Import `features/tier_selection/domain/tier.dart` (enum only). Match
`draft.tierName` case-insensitively against `TierId.values[*].name`; on match render
`JeebTierChip` with the existing `tier<X>Title` key + SLA text from `tier<X>Speed`
(`app_en.arb:1248+`, AR mirrored — reuse, no new keys); on no match render the raw string
verbatim (keeps unknown labels visible). Verified: fixture `tierName: 'Express'` →
`TierId.express` → `tierExpressTitle` EN = "Express" → route-test `find.text('Express')` stays
green — provided the chip keeps the title in its own `Text` (never concatenate a glyph/emoji into
the title string; the glyph is the kit's job).

**8. Edit / Change links** (`dc-tpl 594/600/613`): text in
`jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700)` + `context.jeebRoles.accent` (never
`.tertiary`), labels `l10n.requestSummaryEdit` / `l10n.requestSummaryChange`. All three do
`if (context.canPop()) context.pop();` and each renders **only when `context.canPop()`** — on both
producers the previous route IS the editor. One short why comment. **REFUSED:** pushing
`/request-type` or `/client-location` — JM-024 moved the create to the location leg
(`compose_request_controller.submitFromLocation` calls the submission service itself, verified);
a push from here starts a second divergent create flow. Identifiers:
`request_summary_edit_description`, `request_summary_change_tier`, `request_summary_change_route`.

**9. RTL sweep.** `PositionedDirectional` for the badge; `DirectionalIcons.back` comes free with
`JeebTopBar`; `EdgeInsetsDirectional` everywhere non-symmetric; `Spacer()` in rows (never
`Align(Alignment.centerRight)`); LTR `Directionality` isolates on `0:07` and `+N`; task-6 Bidi
detection on the headline.

**10. Update `test/core/router/request_summary_route_test.dart` — three finder sites ONLY:**
- happy path (`:162-166`): `find.widgetWithText(OmdsLoadingButton, 'Send request')` →
  `find.bySemanticsIdentifier('request_summary_submit')`, `findsOneWidget`, + assert the new
  button's idle/enabled state. Do NOT relax to `findsWidgets`.
- fallback paths (`:199-206`, `:230-236`): same finder swap with `findsNothing` — otherwise both
  assertions go vacuous (the old string stops existing anywhere).
- `:153-156` and `:170` need NO change — they are the proof the dedupe, tier resolution, and
  loading guard survived. A break there is a real defect, not collateral.

**11. New tests** in `test/features/request_summary/` (route-test harness idiom +
`SyncAppLocalizationsDelegate`): (a) badge VOICE vs TYPED; (b) dedupe — same string renders once,
distinct strings render twice; (c) live-path shape — tier/route/photos rows absent when fields
null; (d) replay — `FakeTranscriptAudioPlayer` play/pause toggles the semantics label, and a
missing file yields a disabled disc; (e) AR locale smoke test (screen builds, no overflow).

**12. Lint/quality pass.** `const` constructors wherever possible; `final` locals; ctor first in
every new class; comments = short whys only; no prints. Verify no banned literals:
`bash tool/check_design_tokens.sh` (bans `Color(0x…)`, `Colors.*`, `fontSize:`, first-arg-literal
`EdgeInsets`, `BorderRadius.circular(N)`, literal `SizedBox` — all verified in the script).

**13. Self-check before handoff.**
`grep -rn "identifier:" lib/features/request_summary/` must list `request_summary_submit` spelled
identically plus only the new ids in §Semantics; `grep -rn "Key('request" lib/features/request_summary/`
must still show `request_summary.submit` and the untouched `request-summary-unavailable-state`.
Run `flutter analyze` (bar: no NEW issues over the 11-issue/6-error baseline) and the feature +
route tests. Note which failures are wiring-pending (missing l10n getters until W2 lands) and say
so in the handoff — do not "fix" them locally.

---

## Semantics contract

Survive verbatim (full inventory, verified by grep — this screen has exactly one):

| Identifier | Today | After |
|---|---|---|
| `request_summary_submit` | `request_summary_screen.dart:101` | explicit `Semantics` wrapper on the new CTA |

Also survive: `Key('request_summary.submit')` (`:104`) and the untouched
`RequestSummaryUnavailableScreen` `Key('request-summary-unavailable-state')`.

New: `request_summary_root` (container: true, explicitChildNodes: true — the
`active_request_card.dart` idiom, or nested ids get swallowed), `request_summary_back`,
`request_summary_voice_play`, `request_summary_edit_description`, `request_summary_change_tier`,
`request_summary_change_route`. Nothing else.

## Token map (corrected against the actual Wave-0 ramp)

| Board value | Token |
|---|---|
| navy fills/ink `#0B1351` | `cs.primary` (fills), `cs.onSurface` (ink) |
| orange links + waveform `#D73B00` | `context.jeebRoles.accent` |
| periwinkle `#777FC0` | `JeebSemanticColors.mutedText` |
| card border `#916F66` 1.5px | `cs.outline` via `JeebOutlinedCard` |
| band/back-circle/chip/tiles `#EAE7EB` | `cs.surfaceContainerHigh` |
| dividers/connector `#E5E1E5` | `cs.outlineVariant` (dividers) / `cs.surfaceContainerHighest` (connector) |
| drop-off pin `#E02020` | `cs.error` (literal REFUSED) |
| CTA shadow | `JeebShadows.ctaNavy` |
| radii 20 / 18-top / 10 / 999 | `OmdsBorderRadius.large` / `.large.topLeft` via `BorderRadius.vertical` / `.small` / `.pill` |
| 20/w700 title · 18/w700 transcript · 17/w600 CTA · 14/w700 route values · 12.5 & 12 small text · 13/w700 links · 12.5/w700 duration · 10/w800 badge | `jeebText.h2` · `.titleProminent` · `.button` · `.cardTitle` · `.bodySmall` (12/w600 — as-is) · `.bodySmall` w700 · `.bodySmall` w700 · `.badge` (10.5/w800 — as-is) |
| pads/gaps 24/22/16/14/12/10/6 | `Spacing.xLarge/.large/.medium/.small/.xSmall/.twoXSmall` — snap per plan §4.3 |
| 40px circles/tiles | `Sizes.threeXLarge` |

Never on this screen: `readTick`, `accentTint`, `JeebInfoNote` (the cancel line is a plain
centered caption, `dc-tpl 626`).

## Stop conditions

**Done means:** the six-card ListView is gone; one outlined ticket + overhanging badge + docked
footer match the board; every conditional row collapses on the live voice path (short ticket vs
the PNG is CORRECT — fact 1); dedupe holds; `request_summary_submit` + both Keys survive; tasks
10–11 tests written; analyze/token-gate clean modulo the pre-existing baseline and
wiring-pending getters; wiring file appended.

**Do NOT touch:** `app_router.dart`, `injection_container.dart`, `lib/core/theme/*`,
`lib/l10n/*.arb`, `pubspec.yaml`, `lib/core/widgets/jeeb/*` (consume only),
`request_summary_cubit.dart` / `RequestSummaryState`, `dio_request_submission_service.dart`,
`request_summary_unavailable_screen.dart`, anything under `features/transcription/`,
`features/request_type/`, `features/tier_selection/` (imports fine, edits forbidden),
`lib/devtool/**`, Maestro flows, `test/decision_violations_test.dart`. Never play `audioUrl`
(gateway id — `audioplayers` will just fail). Never fabricate duration, reach counts, or photo
content.

## Wiring — append verbatim to `docs/redesign-2026-08/wiring/10-request-summary.md`

```
### route
file: lib/core/router/app_router.dart
need: The `/voice-request/transcription` builder must thread the recorder's local file path and clip duration onto the RequestDraft it forwards, so the summary's replay bar is real.
exact change: In the `onConfirm` closure of the `/voice-request/transcription` GoRoute (the `RequestDraft(...)` construction, currently `description: text, transcription: text, audioUrl: ...`), add:
  audioLocalPath: clip.localAudioPath,
  audioDurationMs: clip.durationMs,
(`clip` is already in scope in that builder. Fields exist on RequestDraft after this lane's domain change; both are LOCAL-ONLY and never serialized.)
why: Without it the voice band ships with no play disc and no duration (rendered omitted, not faked, per the data-gap policy). TranscriptionScreen is NOT modified.

### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb (+ regenerated AppLocalizations getters)
need: Six new keys for the redesigned summary, plus one EN value fix; five keys orphaned but KEPT for parity.
exact change: app_en.arb —
  "requestSummaryBroadcastCta": "Broadcast to nearby Jeebers",
  "@requestSummaryBroadcastCta": {"description": "Request summary primary CTA"},
  "requestSummaryCancelNote": "Free to cancel any time before you accept an offer.",
  "@requestSummaryCancelNote": {"description": "Reassurance caption under the broadcast CTA; describes the user's own action only"},
  "requestSummaryBadgeVoice": "Voice request",
  "@requestSummaryBadgeVoice": {"description": "Ticket mode badge; uppercased at call site"},
  "requestSummaryBadgeTyped": "Typed request",
  "@requestSummaryBadgeTyped": {"description": "Ticket mode badge; uppercased at call site"},
  "requestSummaryEdit": "Edit",
  "@requestSummaryEdit": {"description": "Transcript row inline edit link"},
  "requestSummaryChange": "Change",
  "@requestSummaryChange": {"description": "Tier / route row change link"},
  and change the VALUE of existing "requestSummaryTitle" from "Review & submit" to "Review & send" (board copy; AR already reads «مراجعة وإرسال»).
  app_ar.arb —
  "requestSummaryBroadcastCta": "أرسل الطلب إلى الجيبرز القريبين",
  "requestSummaryCancelNote": "يمكنك الإلغاء مجاناً في أي وقت قبل قبول أي عرض.",
  "requestSummaryBadgeVoice": "طلب صوتي",
  "requestSummaryBadgeTyped": "طلب مكتوب",
  "requestSummaryEdit": "تعديل",
  "requestSummaryChange": "تغيير",
  (matching @-metadata per house style).
  KEEP (orphaned by the rebuild, both locales, so the parity gate stays green): requestSummarySectionDescription, requestSummarySectionTranscription, requestSummarySectionPhotos, requestSummarySectionTier, requestSummarySubmit.
why: All new user-visible strings on the rebuilt screen. AR cancel copy deliberately describes only the user's action (sprint-009: pre-accept cancel is locally authoritative; no server-confirmation phrasing).

### cross-feature
file: lib/core/widgets/jeeb/jeeb_cta_button.dart (Wave-1 kit)
need: `JeebCtaButton.primary` needs an `isLoading` flag (spinner replaces label, taps ignored while true) — plan §5 #2 specs none, and this screen's CTA must render `state.isSubmitting`.
exact change: add `final bool isLoading;` (default false) to JeebCtaButton and render the OMDS loading affordance when true, preserving height/pill/shadow.
why: The submit cubit's re-entrancy guard is state-level only; the button must show it. Affects other CTA lanes too. Fallback if refused: this lane keeps OmdsLoadingButton inside a JeebShadows.ctaNavy container styled to spec (h58, cs.primary, pill, jeebText.button).

### cross-feature
file: lib/core/widgets/jeeb/jeeb_waveform.dart (Wave-1 kit)
need: Screen 10's board mark is 7 bars, w3, gap 3, h 10/18/12/22/14/20/9, first three solid accent then .45/.45/.35/.35 (dc-tpl 581-588) — none of the four planned modes match. Decide: extend `cardMark` (bar-count/heights param) or bless the 4-bar `cardMark` as-is for 10.
exact change: kit owner's choice; no API demanded.
why: Screen 10 consumes `JeebWaveform.cardMark()` today. If refused, the 4-bar cardMark stands as an accepted divergence — this lane will not fork a bespoke waveform.
```

## Task count: 13
