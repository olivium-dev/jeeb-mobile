# 10 · Request summary — change proposal

**Screen id:** `10-request-summary`
**Verdict:** `rebuild` (structural collapse: six `Card`s → one outlined ticket; new voice-replay affordance; new footer)
**Target file:** `lib/features/request_summary/presentation/request_summary_screen.dart` (151 LOC — the whole file is rewritten)
**Confirmed reachable from `lib/main.dart`:** yes — `app_router.dart:1318-1338` `GoRoute('/request-summary')` → `RequestSummaryScreen`. `screen-repo-map.md` agrees with the prompt; no path correction needed.

---

## 0. What I read

- Render `screens/10-request-summary.png`, HTML `screens/10-request-summary.html`, note `screens/10-request-summary.note.md`.
- `lib/features/request_summary/**` (screen, unavailable screen, cubit, `RequestDraft`, `ComposeRequestController`, `DioRequestSubmissionService`).
- Producers: `app_router.dart:1094-1122` (`/request-type`), `:1139-1172` (`/voice-request/transcription`), `:480-495` (`backFallbacks`), `lib/features/request_type/presentation/request_type_screen.dart:50-64, 150-172, 340-352`.
- Wave-0 theme: `jeeb_text_styles.dart`, `jeeb_shadows.dart`, `jeeb_color_roles.dart`, `jeeb_semantic_colors.dart`. **`lib/core/widgets/jeeb/` does not exist yet** — this proposal depends on Wave 1.
- Tests: `test/core/router/request_summary_route_test.dart` (the ONLY widget test that renders this screen), `test/features/request_summary/*` (cubit/service/resolver only), `lib/devtool/catalog/entries/batch_10_entries.dart:47-97`.
- Gates: `tool/check_design_tokens.sh`, `test/decision_violations_test.dart` (no pin touches this screen).

### Three facts that shape everything below

1. **`/request-summary` has exactly one live producer.** `request_type_screen.dart:50-64` documents that JM-024 superseded the summary edge: the tier card only *selects* and the Continue CTA self-navigates to `client-location`. The router still passes `onTierSelected` / `onContinue` closures, but the screen **never invokes them**. The single live path is `/voice-request` → `/voice-request/transcription` → `/request-summary`, and that draft carries only `description`, `transcription`, `audioUrl`. **`tierName`, `pickupAddress`, `dropoffAddress` and `photoUrls` are all null/empty on the live path.** The designed ticket must collapse gracefully; four of its six rows will normally not render at all. Do not fabricate them.
2. **The router sets `description == transcription`** (`app_router.dart:1161-1165`: `description: text, transcription: text`). The designed ticket has a headline (transcript) *and* a sub-line (description). Rendering both unconditionally duplicates the same sentence on screen **and** breaks `request_summary_route_test.dart:153` (`findsOneWidget` → `findsNWidgets(2)`). Dedupe is mandatory, not cosmetic.
3. **`draft.audioUrl` is the gateway `audioId`, not a playable path.** `VoiceClip.localAudioPath` is the playable file and the router **drops it** when it builds the `RequestDraft`. `RequestDraft` has no duration field either. So the design's `▶ / waveform / 0:07` bar is **not buildable from today's draft** — see §4.1 for the two-line fix and the honest fallback.

---

## 1. Layout & structure

### Deleted

| What | Where | Why |
|---|---|---|
| `Scaffold.appBar: OMDSAppBar` | `request_summary_screen.dart:36` | Design has no Material app bar — an in-body 40px circle back + `h2` title (HTML `dc-tpl 570-574`, padding `14/24/0`). |
| `ListView` + `EdgeInsets.all(Spacing.medium)` | `:54-55` | Design is a top-aligned column, 24px gutter, with a **real `flex:1` spacer** (`dc-tpl 621`) and a docked footer. A `ListView` lets content grow into the emptiness that R1/risk-13 says must stay white. |
| `_SectionCard` (`:113-131`) and `_SectionCardContent` (`:133-150`) | whole classes | Six `Card`s (M3 12px radius + elevation) become one outlined ticket with `1px outlineVariant` inner dividers. A white card with a shadow does not exist on this board (plan §3). |
| Six independent `_SectionCard(title:…, child: Text(...))` calls | `:57-85` | Collapsed into the ticket's five rows. |
| `SizedBox(height: Spacing.xLarge)` before the button | `:86` | Replaced by the `Expanded` spacer. |

### Added / moved

```
RequestSummaryScreen                       (listeners at :19-30 UNCHANGED)
└ Scaffold
  └ SafeArea
    └ Semantics(identifier:'request_summary_root', container:true, explicitChildNodes:true)
      └ Column
        ├ JeebTopBar.back(title: l10n.requestSummaryTitle,
        │                 identifier:'request_summary_back', onBack: _rootAwareBack)
        ├ Expanded
        │  └ SingleChildScrollView(padding: EdgeInsetsDirectional 24/22/24/0)
        │     └ _RequestTicket(draft)            ← the whole design card
        └ _BroadcastFooter(isSubmitting: state.isSubmitting)
```

`Expanded(child: SingleChildScrollView(...))` reproduces the render exactly (content top-aligned, lower ~45% plain white) **and** survives 200% text scale, which a bare `Column` would not.

`_RequestTicket` = `JeebOutlinedCard` (kit #3, `radius: 20`, `1.5px colorScheme.outline`, **no shadow**, inner `1px outlineVariant` dividers inset 16), wrapped in a `Stack(clipBehavior: Clip.none)` so the mode badge can overhang:

| # | Row | Design source | Renders when |
|---|---|---|---|
| 0 | Mode badge `VOICE REQUEST` / `TYPED REQUEST` — navy pill, white `jeebText.badge`, pad `3/9`, `PositionedDirectional(start: 16, top: -9)` | `dc-tpl 577`; note: typed variant swaps the word | always |
| 1 | Voice band — `surfaceContainerHigh`, top corners clipped `OmdsBorderRadius.large`, pad 16, gap 12: Ø42 navy circle + white 18px play/pause · `JeebWaveform.cardMark` (expanded) · duration `12.5/w700` periwinkle | `dc-tpl 576-589` | audio present (§4.1) |
| 2 | Transcript block, pad 16: headline `jeebText.titleProminent` navy (HTML 18/w700 — 17/w700 is the nearest ramp entry); sub-line `jeebText.bodySmall` `mutedText` + trailing `Edit` accent link | `dc-tpl 590-594` | always |
| 3 | Tier row, pad `14/16`, gap 10: `JeebTierChip` · SLA text `bodySmall` `mutedText` · `Spacer` · `Change` | `dc-tpl 596-600` | `draft.tierName != null` |
| 4 | Route timeline, pad 16, gap 12: rail column (Ø10 ring `3px primary` · 2px `surfaceContainerHighest` connector, `minHeight 22` · 14px pin) + `Pickup`/value, `Drop-off`/value + centered `Change` | `dc-tpl 602-613` | either address non-null |
| 5 | Photos row, pad `14/16`, gap 10: up to two 40×40 `surfaceContainerHigh` tiles (glyph, then `+N`) + count text | `dc-tpl 615-620` | `draft.photoUrls.isNotEmpty` |

`_BroadcastFooter` = `JeebCtaFooter.single` (kit #2), `EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, 0, Spacing.xLarge, Spacing.twoXLarge)` (= `0/24/32`, `dc-tpl 622`):
- `JeebCtaButton.primary`, h58, navy pill, `JeebShadows.ctaNavy`, leading 20px broadcast glyph (`Icons.wifi_tethering`), label `jeebText.button` white (`dc-tpl 623`);
- 12px gap, then the centered cancel note in `bodySmall` `mutedText` (`dc-tpl 626`).

**Never build:** the 440×956 frame, the 40px frame radius, `scale(0.55)`, or the `9:41` status row (`dc-tpl 566-569`).

---

## 2. Tokens — every hardcoded value that must become a token

The current file has **zero** color/px literals (it is token-clean), so this is a *token-upgrade* table, not a cleanup: everything the design adds must arrive already tokenised, because `tool/check_design_tokens.sh` bans `Color(0x…)`, `Colors.*`, `fontSize:`, `BorderRadius.circular(N)`, `EdgeInsets.*(<number>)` and `SizedBox(width|height: <number>)` inside `lib/features`.

| Design value (HTML) | Dart token |
|---|---|
| `--jeeb-navy #0B1351` (badge fill, play disc, CTA, rail dot, ink) | `Theme.of(context).colorScheme.primary` / `onSurface` for body ink |
| `--jeeb-orange #D73B00` (Edit / Change links, waveform bars) | `context.jeebRoles.accent` — never `.tertiary` |
| `rgba(215,59,0,.45)` / `.35` waveform tail | `JeebWaveform.cardMark`'s own internal opacity ladder (kit #14) — the screen passes no colors |
| `--jeeb-periwinkle #777FC0` (sub-line, `0:07`, `Pickup`/`Drop-off` labels, photo count, cancel note) | `Theme.of(context).extension<JeebSemanticColors>()!.mutedText` |
| `--jeeb-brown-outline #916F66` 1.5px card border | `colorScheme.outline` — supplied by `JeebOutlinedCard` |
| `--jeeb-surface-high #EAE7EB` (voice band, back circle, tier chip, photo tiles) | `colorScheme.surfaceContainerHigh` |
| `--jeeb-surface-highest #E5E1E5` (1px dividers, route connector) | `colorScheme.outlineVariant` for dividers, `surfaceContainerHighest` for the connector fill |
| `#E02020` drop-off pin | `colorScheme.error` (`#B00020` after Wave 0). **The literal is banned in `lib/features`; the ~2-point hue shift is an accepted divergence.** |
| `#FFFFFF` CTA / badge ink | `colorScheme.onPrimary` |
| `box-shadow rgba(11,19,81,.28) 0 10 24` on the CTA | `JeebShadows.ctaNavy` |
| card radius 20 · band top radius 18 · photo tile 10 · pills 999 | `OmdsBorderRadius.large` (20) · `.large` (20, for the band clip — 18 vs 20 is invisible) · `.small` (12) · `OmdsBorderRadius.pill` |
| pad `18/24/0`, `22/24/0`, 16, `14/16`, `0/24/32`; gaps 14/12/10/6 | `Spacing.medium` (16) · `Spacing.xLarge` (24) · `Spacing.small` (12) · `Spacing.xSmall` (8) · `Spacing.twoXLarge` (32); the odd 14/22/10/6 snap to the nearest token per §4.3 |
| 20/w700 title · 18/w700 transcript · 12.5/w500 sub · 13/w700 links · 12.5/w700 duration · 10/w800 badge · 17/w600 CTA · 12/w600 route labels · 14/w700 route values | `context.jeebText.h2` · `.titleProminent` · `.bodySmall` · `.bodySmall` (w700 via `copyWith(fontWeight)` — the ramp has no 13/w700) · `.bodySmall` · `.badge` · `.button` · `.bodySmall` · `.cardTitle` (15.5/w700 ≈ 14/w700) |
| Ø42 play disc, Ø40 back circle, 40×40 photo tiles, h58 CTA | `Sizes.*` tokens (`Sizes.threeXLarge` = 40; the 42/58 come from the kit widgets' own internals) |

**Do not use** `JeebSemanticColors.readTick` (zero board occurrences) or `accentTint` (07 only) on this screen.

---

## 3. Shared components consumed

| Kit widget (plan §5) | Replaces | Notes |
|---|---|---|
| **#1 `JeebTopBar`** (`.back` mode) | `OMDSAppBar` at `:36` | `identifier: 'request_summary_back'`. `onBack` must reproduce `RootAwareBackScope`: `context.canPop() ? context.pop() : context.go('/')` — `backFallbacks['request-summary'] = '/'` (`app_router.dart:492`). |
| **#2 `JeebCtaButton` + `JeebCtaFooter.single`** | `_SubmitButton` (`:93-111`) + `OmdsLoadingButton` | **Blocker:** §5 #2 specs no loading state and this screen needs one. See §10-R2. |
| **#3 `JeebOutlinedCard`** (radius 20, inner dividers) | `_SectionCard` ×6 (`:113-131`) | One card for the whole ticket. |
| **#7 `JeebTierChip`** | `_SectionCard(title: Speed, child: Text(tierName))` (`:71-75`) | Emoji + localized title. **Render the emoji as a separate leading child, not concatenated into the title string** — otherwise `find.text('Express')` (route test `:155`) breaks. |
| **#14 `JeebWaveform.cardMark`** | — (net new) | 4 bars w3 r9 gap 2, h 8/14/10/15, accent with the last at `.4`, container h16. |
| **#22 `JeebInfoNote`** | — | **Not used here.** The cancel note is a centered caption under the CTA (`dc-tpl 626`), not an info panel. Do not reach for `JeebInfoNote` because it is "the most repeated pattern" — it is wrong for this row. |

Screen-local (not kit, because they appear nowhere else on the board): the mode badge, the voice band, the pickup→drop-off rail, the photo-tile row. Keep them as private widgets in `request_summary_screen.dart` or a new `presentation/widgets/` folder inside the lane's own tree.

---

## 4. New functionality

### 4.1 Voice replay — the one real blocker

The design's band needs (a) a locally playable file and (b) a duration. Today:

- `RequestDraft.audioUrl` = `VoiceClip.audioPath` = the **gateway `audioId`**, explicitly documented as "NOT locally playable" (`transcription/domain/voice_clip.dart`).
- `VoiceClip.localAudioPath` (the real file) and `VoiceClip.durationMs` exist on the clip but the router **discards both** when it constructs the draft (`app_router.dart:1159-1166`).

**Recommended fix — two local fields, zero backend change:**

1. *This lane:* add to `RequestDraft` (`domain/request_draft.dart`)
   ```dart
   /// LOCAL-ONLY (never sent): the on-device file the recorder wrote, so the
   /// summary can replay the clip. `audioUrl` carries the gateway audioId,
   /// which is not playable.
   final String? audioLocalPath;
   /// LOCAL-ONLY: recorded clip length, for the replay bar's read-out.
   final int? audioDurationMs;
   ```
   `DioRequestSubmissionService._buildBody` (`:61-74`) is **not** touched — the wire body is unchanged, so this is not a contract change.
2. *Integrator (`app_router.dart:1159-1166`):* the transcription route's builder already has `clip` in scope; add
   `audioLocalPath: clip.localAudioPath, audioDurationMs: clip.durationMs`.
   `TranscriptionScreen` is **not** modified — no cross-lane edit into screen 06.

**Playback itself** reuses the existing port, no new dependency and no DI edit:
`TranscriptAudioPlayer` (`transcription/domain/transcript_audio_player.dart`) with `AudioPlayersTranscriptAudioPlayer` in production and `NoopTranscriptAudioPlayer`/`FakeTranscriptAudioPlayer` in tests. Add an optional constructor seam mirroring `TranscriptionScreen`'s idiom:
```dart
const RequestSummaryScreen({super.key, this.audioPlayer});
final TranscriptAudioPlayer? audioPlayer;   // sort_constructors_first: ctor stays first
```
All three existing call sites (`app_router.dart:1335`, `batch_10_entries.dart:95`, tests) keep compiling. Playback state (`isPlaying`, `position`) lives in a private `StatefulWidget` inside the ticket — **do not extend `RequestSummaryState`**, which is a plain submit-state class with no `copyWith`; widening it would touch `request_summary_cubit_test.dart` for a purely presentational concern.

**Honest fallback if the router edit is refused:** render the `VOICE REQUEST` badge and the static `JeebWaveform.cardMark`, **omit the play disc and the duration**, and leave
`// TODO(redesign-24): needs the recorder's local path + duration on RequestDraft — omitted, not faked.`
Never invent a duration and never wire play to the gateway `audioId`.

### 4.2 Typed vs voice variant (from the note)

`final isVoice = draft.audioLocalPath != null` (fallback mode: `draft.audioUrl != null`). Voice → badge reads `VOICE REQUEST` and row 1 renders. Typed → badge reads `TYPED REQUEST` and row 1 is simply absent; everything else identical. No new state.

### 4.3 Transcript / description dedupe (mandatory — see §0.2)

```dart
final headline = (draft.transcription?.trim().isNotEmpty ?? false)
    ? draft.transcription!.trim()
    : draft.description.trim();
final sub = draft.description.trim();
final showSub = sub.isNotEmpty && sub != headline;
```

### 4.4 Localized tier name (fixes a live i18n defect)

`draft.tierName` is the **enum slug** (`tier.id.name` → `flash`, `express`, `onTheWay`) at both producers, and `:73` renders it raw today — an untranslated slug leaking into the AR build. Resolve it client-side (no new endpoint, no new keys):

`tierName` → match against `TierId.values` by name (case-insensitive) → existing `tierFlashTitle` / `tierFlashSpeed` … keys (`app_en.arb:1248-1269`, mirrored in AR). **Fallback: if no enum matches, render the raw string verbatim** — that keeps unknown gateway labels visible and keeps `find.text('Express')` green. Import `features/tier_selection/domain/tier.dart` for the enum only; that read-only cross-feature import already has precedent (`chat/application/order_compose_coordinator.dart` imports `request_summary/domain/*`).

### 4.5 Edit / Change actions

All three are "go back to the step that owns this value" → `if (context.canPop()) context.pop();`, and each link renders **only when `context.canPop()`**. Rationale in a one-line WHY comment: on both producers the previous route *is* the editor (transcription review for the transcript, request-type for the tier). See §9-C2 for why pushing a route instead is refused.

### 4.6 Photos

`draft.photoUrls` is a `List<String>` of remote URLs and **nothing in the create flow populates it** today. Render the design's tiles as **glyph placeholders** (`Icons.image_outlined`, `mutedText`) plus a `+N` tile and the existing `l10n.requestSummaryPhotosAttached(count)` string — exactly what the render draws (`dc-tpl 616-620` is a glyph on a grey square, not a photo). Do **not** add `Image.network`: it needs a network stub in every widget test and there is no image-cache dependency available under constraint 3.

---

## 5. New routes

**None.** No surface in this design lacks a route. `/request-summary` already exists (`app_router.dart:1318`) with `backFallbacks['request-summary'] = '/'` (`:492`). Do not add `RootAwareBackScope` — the route is already inside `_wrapRootAware([...])`.

---

## 6. Semantics identifiers

### Existing — MUST survive (full inventory; `grep -rn "identifier:" lib/features/request_summary/`)

| Identifier | Today | After |
|---|---|---|
| `request_summary_submit` | `request_summary_screen.dart:101`, wrapping `OmdsLoadingButton` | re-homed verbatim onto the `JeebCtaButton` in `_BroadcastFooter`. **Explicit `Semantics(identifier:)` wrapper — never the OMDS `identifier:` param** (§7.5, stale local clone). |

Also preserve the widget key `const Key('request_summary.submit')` (`:104`) — it is a separate contract from the semantics id.
`RequestSummaryUnavailableScreen` (`Key('request-summary-unavailable-state')`) is untouched.

### New

| Identifier | Element |
|---|---|
| `request_summary_root` | the screen's `Semantics` container (`container: true, explicitChildNodes: true`, per the `active_request_card.dart` idiom, so nested ids are not swallowed) |
| `request_summary_back` | `JeebTopBar.back` circle |
| `request_summary_voice_play` | play/pause disc (label toggles via the existing `l10n.transcriptionPlayAudio` / `transcriptionPauseAudio` — reuse, no new keys) |
| `request_summary_edit_description` | transcript-row `Edit` |
| `request_summary_change_tier` | tier-row `Change` |
| `request_summary_change_route` | route-row `Change` |
| `request_summary_photos` | photo-tile row (non-interactive but worth addressing) |

---

## 7. RTL

| Design detail | Mirrored risk | Build rule |
|---|---|---|
| Badge at `left:16; top:−9` | pins to the physical left in AR | `PositionedDirectional(start: Spacing.medium, top: -9)` inside `Stack(clipBehavior: Clip.none)` |
| Back arrow glyph | wrong-facing in AR | `DirectionalIcons.back(context)` (`lib/core/widgets/directional_icons.dart`) — the kit's `JeebTopBar` already does this |
| Pickup→drop-off rail on the leading edge | flips wrongly if built with `Row` + fixed `left` padding | plain `Row` + `EdgeInsetsDirectional`; the rail is a `Column` child so it auto-mirrors |
| `Change` links trailing | — | `Spacer()` inside a `Row` mirrors correctly; never `Align(Alignment.centerRight)` |
| `0:07` duration read-out | AR-Indic digits + RTL reordering can render `07:0` | wrap in `Directionality(textDirection: TextDirection.ltr, …)` (the money/digits LTR-isolate rule, §7.1-5) |
| `+1` photo tile | same | same LTR isolate |
| **Arabic transcript inside an EN app** (`dc-tpl 591` sets `direction: rtl` explicitly) | an AR sentence in an LTR paragraph gets LTR base direction: trailing punctuation jumps to the wrong end and the line left-aligns | detect per string: `Directionality(textDirection: Bidi.detectRtlDirectionality(headline) ? TextDirection.rtl : TextDirection.ltr, child: Text(headline, textAlign: TextAlign.start))`. `intl ^0.20.2` is already a direct dependency (`pubspec.yaml:121`) — **no new dep**. This is the one place the design's explicit `direction: rtl` is load-bearing, and it is also correct in reverse (an EN description inside the AR build). |
| 200% text scale | the `flex:1` spacer collapses and the ticket overflows | `Expanded(child: SingleChildScrollView(...))` (§1) — this is why the spacer is not a bare `Spacer()` |

---

## 8. Test impact

Only **one** test renders this screen: `test/core/router/request_summary_route_test.dart`. It loads the real ARB via `SyncAppLocalizationsDelegate`, so l10n value changes reach it.

| Assertion | Verdict | Action |
|---|---|---|
| `:162` `find.widgetWithText(OmdsLoadingButton, 'Send request')` + `:164-166` `isLoading`/`isEnabled` | **Legitimate break** — the CTA copy changes to "Broadcast to nearby Jeebers" and, if `JeebCtaButton` replaces `OmdsLoadingButton`, so does the type | rewrite as `find.bySemanticsIdentifier('request_summary_submit')` `findsOneWidget` + assert the enabled/idle state on the new widget. Do **not** relax it to a bare `findsWidgets`. |
| `:199`, `:232` same finder, `findsNothing` on the fallback paths | would silently become **vacuous** (the string no longer exists anywhere) | update to the same identifier-based finder so the fallback assertions keep meaning |
| `:153` `find.text('JEB-4 happy-path draft')` `findsOneWidget` | **survives only with §4.3 dedupe.** The fixture has `transcription: null`, so headline = description and the sub-line is suppressed | no test change; this is the assertion that proves the dedupe |
| `:154` `find.text('Express')` | **survives only if `JeebTierChip` keeps the title in its own `Text`** and `_tierCopy` falls back to the raw slug on no match | no test change; treat a break here as a signal the chip concatenated the emoji |
| `:155-156` `find.text('12 Hamra St, Beirut')` / `'88 Verdun Ave, Beirut'` | survive — the timeline renders each address as its own `Text` | none |
| `:170` `find.byType(OmdsLoadingState)` `findsNothing` | unaffected (`:34` is untouched) | none |
| `:207`, `:236` `find.byType(Scaffold)` `findsWidgets` | unaffected — the `Scaffold` stays, only its `appBar` goes | none |
| `test/features/request_summary/*` (cubit, dio service, phone resolvers, compose controller, inflight guard) | unaffected — no cubit/service/`_buildBody` change | none |
| `test/core/di/injection_container_new_repos_test.dart` | unaffected — no DI edit | none |

**No goldens exist for this screen.** New tests to add in `test/features/request_summary/`: voice-vs-typed badge variant; description/transcription dedupe; each optional row absent when its field is null (the live-path shape); an AR/RTL smoke test; a `FakeTranscriptAudioPlayer` play/pause test.

---

## 9. Conflicts and refusals

**C1 — "Free to cancel any time before you accept an offer." vs "no pre-accept cancel endpoint".**
`decision_violations_test.dart` carries no pin on cancel copy (grepped), and sprint-009 records that pre-accept cancel is **locally authoritative only** — the capability is real, only server confirmation is not. **Ship the line**, and constrain both locales to describe the user's own action. Forbidden phrasings for the AR value: anything meaning "we will cancel it with the Jeebers" / "Jeeb will confirm the cancellation". This screen adds **no** Cancel affordance (the design has none), so nothing here implies a server round-trip.

**C2 — REFUSED: route-row and tier-row `Change` as a *push*.**
The obvious wiring (`context.push('/request-type')` or `'/client-location'`) is wrong. JM-024 deliberately deleted the summary edge: `/request-type`'s Continue now writes into the singleton `ComposeRequestController` and navigates to `/client-location`, which calls `POST /requests` **itself** (`compose_request_controller.dart:131-140`) and hands off to order-chat. Pushing it from here would start a second, divergent create flow that abandons this draft and can double-create. Implemented as pop-to-previous-step instead (§4.5), rendered only when `context.canPop()`.

**C3 — `#E02020` drop-off pin.** Refused as a literal (`tool/check_design_tokens.sh` bans `Color(0x…)` in `lib/features`, and the plan's "not a token" note points at *marker assets*, which this row is not). Ships as `colorScheme.error`. Divergence documented in §2.

**C4 — the design shows a fully-populated ticket that the live flow cannot produce.** Not a product conflict, but the largest honesty risk on this screen: tier, route and photos are null on the only live path (§0.1). Every row is conditional; nothing is placeholdered. Anyone reviewing the built screen against the PNG will see a much shorter ticket — that is correct.

**Checked and clear:** D41/D44 (no money on this surface), D52, D56, D20, B04, the accept-sheet tense pin, the pinned-chat-summary pin, the deleted-features rule (nothing here resurrects role switch / search / email-password), the deep-link guard (route builder untouched). The word "Broadcast" collides with no pinned vocabulary.

---

## 10. Dependencies, wiring requests and risks

**Wiring requests (integrator-owned files — this lane must not edit them):**

- **W1 · `lib/core/router/app_router.dart:1159-1166`** — add `audioLocalPath: clip.localAudioPath, audioDurationMs: clip.durationMs` to the `RequestDraft` the transcription route forwards. Two lines; `clip` is already in scope; unblocks §4.1.
- **W2 · l10n batch (`app_en.arb` + `app_ar.arb` + `app_localizations.dart` getter, 4-edit recipe)** — new keys:
  `requestSummaryBroadcastCta` "Broadcast to nearby Jeebers" / «أرسل الطلب إلى الجيبرز القريبين»;
  `requestSummaryCancelNote` "Free to cancel any time before you accept an offer." / «يمكنك الإلغاء مجاناً في أي وقت قبل قبول أي عرض.»;
  `requestSummaryBadgeVoice` "Voice request" / «طلب صوتي»;
  `requestSummaryBadgeTyped` "Typed request" / «طلب مكتوب»;
  `requestSummaryEdit` "Edit" / «تعديل»;
  `requestSummaryChange` "Change" / «تغيير».
  Badges are uppercased at the call site (`toUpperCase()`), EN-only effect, AR passes through.
  **Reused, no new key:** `requestSummaryTitle`, `requestSummarySectionPickup` ("Pickup"), `requestSummarySectionDropoff` ("Drop-off"), `requestSummaryPhotosAttached(count)`, `tier*Title`/`tier*Speed`, `transcriptionPlayAudio`/`transcriptionPauseAudio`.
  **Orphaned by this change** (keep the keys, both locales, so parity stays green): `requestSummarySectionDescription`, `requestSummarySectionTranscription`, `requestSummarySectionPhotos`, `requestSummarySectionTier`, `requestSummarySubmit`.
  **Optional copy fix:** EN `requestSummaryTitle` is "Review & submit" while AR is already «مراجعة وإرسال» (= *Review & send*) and the design says "Review & send" — aligning EN removes a real EN/AR divergence. Owner's call; value edit only, no new key.
- **W3 · Wave-1 kit** — `JeebCtaButton.primary` needs an `isLoading` flag (see R2).

**Risks**

1. **R1 — the voice bar is blocked on W1.** Without it the screen ships with a static waveform and no play/duration. Do not work around it by playing `audioUrl`; it is a gateway id and `audioplayers` will simply fail.
2. **R2 — `JeebCtaButton` has no loading state in §5 #2**, and this screen's CTA must show `state.isSubmitting` (the cubit's re-entrancy guard at `request_summary_cubit.dart:35` is state-level, not visual). Either the kit gains `isLoading`, or this lane keeps `OmdsLoadingButton` styled to spec (`backgroundColor: colorScheme.primary`, `textStyle: context.jeebText.button`, `height: 58`, `borderRadius: OmdsBorderRadius.pill`) inside a `JeebShadows.ctaNavy` container. Flag early — it affects other CTA lanes too.
3. **R3 — `lib/core/widgets/jeeb/` does not exist yet.** This proposal consumes five kit widgets; it cannot start before Wave-1 steps 1–5 land (`JeebOutlinedCard`, `JeebTopBar`, `JeebCtaButton`/`Footer`, `JeebTierChip`, `JeebWaveform`).
4. **R4 — the dedupe is the single highest-value line in this diff.** Miss it and the live screen shows the user's sentence twice and a green test turns red for the right reason.
5. **R5 — density.** The ticket ends at ~52% of the viewport in the render. Do not stretch it, do not centre it, do not backfill the white space with the reassurance copy (which belongs under the CTA).
6. **R6 — stale local audio file.** The recorder's temp file can be gone by the time the summary mounts. Guard with `File(path).existsSync()` before enabling play and degrade to a disabled disc; never crash.
7. **R7 — effort vs reach.** This screen sits on a near-dead edge of the create flow (§0.1). Build the ticket exactly as specced, but do not invest in speculative rows or a photo picker that no producer feeds.
8. **R8 — devtool catalog.** `batch_10_entries.dart:73-82` seeds a fully-populated draft (tier + addresses + one photo). It will keep compiling and now previews the *rich* variant only; consider (optionally, outside this lane) a second entry with the voice-path shape so the collapsed ticket is reviewable in the catalog.
