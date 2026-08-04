# Wiring requests — 10 · Request summary

Filed by the `10-request-summary` lane. Screen code is written as if every block below is granted.

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

---

## Addendum filed at apply time (precondition unmet)

### cross-feature
file: lib/core/widgets/jeeb/{jeeb_top_bar,jeeb_cta_button,jeeb_outlined_card,jeeb_tier_chip,jeeb_waveform}.dart (Wave-1 kit)
need: `lib/core/widgets/jeeb/` did NOT exist when this lane ran (verified 2026-08-03: `lib/core/widgets/` holds only `directional_icons.dart` + `jeeb_verified_badge.dart`), so the five kit widgets this screen was specced to consume have no home to import from. The screen ships with feature-local stand-ins built to the kit's published spec; they must be deleted and replaced by the kit components once Wave 1 lands.
exact change: after the kit lands, in `lib/features/request_summary/presentation/`:
  - `widgets/summary_top_bar.dart` -> `JeebTopBar.back(title:, identifier: 'request_summary_back', onBack:)`; delete the file.
  - `widgets/broadcast_footer.dart` `_BroadcastCta` -> `JeebCtaFooter.single` + `JeebCtaButton.primary(isLoading: isSubmitting, leading: Icons.wifi_tethering, ...)`; keep the `Semantics(identifier: 'request_summary_submit')` wrapper and `Key('request_summary.submit')` on the result.
  - `widgets/request_ticket.dart` `_TicketCard` -> `JeebOutlinedCard(radius: 20, dividers: true)`; `_TierChip` -> `JeebTierChip`.
  - `widgets/voice_replay_band.dart` `_CardMarkWaveform` -> `JeebWaveform.cardMark()` (see the waveform block above; the stand-in already implements the plan's 4-bar cardMark spec verbatim, so the swap is a one-line import change).
why: This lane may not create files under `lib/core/widgets/jeeb/` (not its ownership), and importing a non-existent library would have made every file in the feature unanalyzable. The stand-ins are private to the feature, carry a `// Wave-1 kit stand-in` marker comment naming their replacement, and hold no state the kit widgets do not.

---

## Addendum 2 — filed 2026-08-03 by the second (kit-era) apply pass. SUPERSEDES Addendum 1.

**Addendum 1 above is VOID.** It was written when `lib/core/widgets/jeeb/` did not exist and
describes feature-local stand-ins (`widgets/summary_top_bar.dart`, `_TicketCard`, `_TierChip`,
`_CardMarkWaveform`, …). None of those files exist in this tree and none were created. Wave 1 has
since shipped, and this screen now imports the real kit: `JeebTopBar.back`, `JeebOutlinedCard.grouped`,
`JeebTierChip` / `JeebTierChip.meta`, `JeebWaveform.cardMark`, `JeebCtaFooter.single`,
`JeebCtaButton.primary`. **There is nothing to swap out — do not apply Addendum 1.**

Status of the four original blocks:

- **route (W1) — STILL REQUIRED.** Unchanged; apply verbatim. `RequestDraft.audioLocalPath` and
  `RequestDraft.audioDurationMs` now exist (added by this lane, both optional, both LOCAL-ONLY, and
  `DioRequestSubmissionService._buildBody` was NOT touched). Until it lands, the replay band never
  renders on the live voice path — by design, not a bug: the band is gated on `audioLocalPath`.
- **l10n (W2) — STILL REQUIRED and BLOCKING.** Apply verbatim. Until it lands,
  `lib/features/request_summary/` reports exactly **7 `undefined_getter` errors** over 6 keys
  (`requestSummaryBroadcastCta`, `requestSummaryCancelNote`, `requestSummaryBadgeVoice`,
  `requestSummaryBadgeTyped`, `requestSummaryEdit`, `requestSummaryChange` ×2) and the feature's
  widget tests cannot compile. Verified locally against a temporary copy of exactly the W2 patch:
  with it applied, `test/features/request_summary/request_summary_screen_test.dart` is **14/14
  green**. The temporary patch was reverted byte-for-byte (checksums re-verified); `lib/l10n/` is
  untouched in the diff.
- **cross-feature `JeebCtaButton.isLoading` (W3) — ALREADY GRANTED, no action.** The shipped kit has
  `final bool isLoading` plus `bool get isInteractive`. The fallback clause is moot.
- **cross-feature `JeebWaveform` 7-bar preset (W4) — STILL OPEN, non-blocking.** The screen consumes
  `const JeebWaveform.cardMark()` (4 bars) as the accepted divergence from the board's 7. No fork
  was made. Kit owner's call.

### test
file: test/core/router/request_summary_route_test.dart
need: Nothing to apply — this lane already updated the three finder sites (`request_summary_submit`
via `find.bySemanticsIdentifier`, plus the `Key('request_summary.submit')` / `JeebCtaButton`
idle+enabled assertions). Recorded here only so the integrator does not re-edit it.
exact change: none.
why: The suite currently cannot be RUN: `app_router.dart`'s import closure pulls in other lanes'
in-flight screens (registration, onboarding, client_offers, location, transcription, home_client),
which have their own wiring-pending getters and two missing symbols (`DirectionalIcons.forward`,
`TranscriptionKeys.scrubber`/`.transcriptText`). Zero of those errors come from `request_summary`.
Re-run this suite after the l10n integration pass.
