# Apply report — 10 · Request summary

**Lane:** `10-request-summary` · **Date:** 2026-08-03 · **Status:** applied (blocked only on wiring W2)
**Instruction set:** `docs/redesign-2026-08/per-screen-revised/10-request-summary.md` (13 tasks)

---

## What shipped

| Task | Done | Note |
|---|---|---|
| 1 · file wiring | ✅ | The four blocks were already present verbatim. Appended **Addendum 2**, which VOIDS the stale "stand-ins" Addendum 1 (written pre-kit) and re-states W1/W2 as still required, W3 as already granted, W4 as open. |
| 2 · extend `RequestDraft` | ✅ | `audioLocalPath` + `audioDurationMs`, both optional, ctor kept first. `dio_request_submission_service.dart` untouched — no wire-contract change. |
| 3 · `RequestTicket` | ✅ | New `presentation/widgets/request_ticket.dart`. `Stack(clipBehavior: Clip.none)` over `JeebOutlinedCard.grouped(radius: 20, dividers: true)` + `PositionedDirectional` badge at `start: 16, top: -9`. |
| 4 · `_VoiceReplayBand` | ✅ | Private `StatefulWidget`. Ø42 navy disc, `const JeebWaveform.cardMark()` in an `Expanded`, `mm:ss` read-out in an LTR isolate — **omitted entirely when `audioDurationMs == null`**. Player resolved lazily in State (`late final`); `File(...).existsSync()` gates the disc; `dispose()` disposes the player; `onCompleted` resets. |
| 5 · `BroadcastFooter` | ✅ | New `presentation/widgets/broadcast_footer.dart`. `JeebCtaFooter.single(spacing: 12, below: cancel note)` + `JeebCtaButton.primary(height: primaryHeightTall /* 58 */, leadingIcon: Icons.wifi_tethering, iconSize: 20, isLoading: state.isSubmitting)`. |
| 6 · rewrite screen | ✅ | Six-card `ListView` + `_SectionCard` + `_SectionCardContent` + `_SubmitButton` + `_RequestSummaryBody` all deleted. `OMDSAppBar` → `JeebTopBar.back`. Listener block byte-identical; `draft == null → OmdsLoadingState` guard kept. Dedupe implemented exactly as specced. |
| 7 · tier row + l10n copy | ✅ | Case-insensitive match of `tierId` then `tierName` against `TierId.values`; on hit → `JeebTierChip` + `tier<X>Title` and the SLA from `tier<X>Speed`; on miss → `JeebTierChip.meta` with the raw label (unknown tiers stay visible). Fixes the live raw-slug i18n leak. |
| 8 · Edit / Change links | ✅ | `bodySmall` w700 in `context.jeebRoles.accent`; each renders **only when `context.canPop()`** and each pops. No push to `/request-type` or `/client-location`. |
| 9 · RTL sweep | ✅ | `PositionedDirectional`, `EdgeInsetsDirectional` for every non-symmetric inset, `Spacer()` (never `Align`), LTR isolates on `0:07` and `+N`, `Bidi.detectRtlDirectionality` on the headline. Back glyph mirrors via `JeebTopBar`. AR smoke test green, no overflow. |
| 10 · route-test finders | ✅ | Three sites swapped to `find.bySemanticsIdentifier('request_summary_submit')` (`findsOneWidget` / `findsNothing` / `findsNothing`) plus a `JeebCtaButton` idle+enabled assertion via `Key('request_summary.submit')`. `:153-156` and `:170` untouched. |
| 11 · new tests | ✅ | `test/features/request_summary/request_summary_screen_test.dart` — 14 tests: badge VOICE/TYPED, dedupe both directions, live-path row collapse, populated draft, unknown tier, play/pause/complete semantics-label toggle, missing-file inert disc, no-duration → no read-out, no-local-path → no band, AR locale, frozen contracts. |
| 12 · lint / token gate | ✅ | `dart analyze` on the feature: **7 issues, all the wiring-pending l10n getters, 0 anything else.** All 12 `check_design_tokens.sh` patterns hand-run over `lib/features/request_summary/`: **0 hits.** |
| 13 · self-check | ✅ | See below. |

## Kit consumed (nothing hand-rolled)

`JeebTopBar.back` · `JeebOutlinedCard.grouped` · `JeebTierChip` + `JeebTierChip.meta` ·
`JeebWaveform.cardMark` · `JeebCtaFooter.single` · `JeebCtaButton.primary`.
No private copy of any kit widget exists in this feature.

## Semantics / Key contracts

```
request_summary_submit            broadcast_footer.dart:42   (explicit Semantics wrapper, button: true)
Key('request_summary.submit')     broadcast_footer.dart:45   (on the JeebCtaButton)
request_summary_root              request_summary_screen.dart:48  (container + explicitChildNodes)
request_summary_back              request_summary_screen.dart:56  (JeebTopBar leading circle)
request_summary_voice_play        request_ticket.dart:284
request_summary_edit_description  request_ticket.dart:403
request_summary_change_tier       request_ticket.dart:472
request_summary_change_route      request_ticket.dart:581
```

`Key('request-summary-unavailable-state')` untouched (that screen was not edited). Nothing else.

## Verification

**`dart analyze lib/features/request_summary test/features/request_summary` → 7 issues, 0 non-l10n.**
All seven are `undefined_getter` over the six W2 keys. Nothing else — no warnings, no infos.

**Tests could not compile against the unmodified tree** (same six getters). To avoid shipping an
unverified layout, W2 was applied to a **temporary local copy** of `lib/l10n/`, the suite was run,
and the three files were restored byte-for-byte (`shasum` re-verified; `git status lib/l10n/` clean).
Under that temporary patch:

```
flutter test test/features/request_summary/request_summary_screen_test.dart  →  +14  All tests passed!
```

That run earned its keep: it caught a **real layout crash**. `_RouteTimeline`'s
`Row(crossAxisAlignment: stretch)` — needed so the rail's connector flexes to the address block —
hands children the incoming max height, which is *infinite* inside the `SingleChildScrollView`.
Fixed with an `IntrinsicHeight` wrapper; both affected tests then passed.

**`test/core/router/request_summary_route_test.dart` still cannot be RUN**, and not because of this
lane: `app_router.dart`'s import closure pulls in other lanes' in-flight screens (registration,
onboarding, client_offers, location, transcription, home_client) with their own wiring-pending
getters plus two missing symbols (`DirectionalIcons.forward`, `TranscriptionKeys.scrubber` /
`.transcriptText`). Zero of those errors originate in `request_summary`. Re-run after the
integration pass.

## Accepted divergences from the board

1. **Waveform:** `JeebWaveform.cardMark()` is 4 bars; the board draws 7 (`dc-tpl 581-588`). Per the
   instruction set: consume the kit, never fork. W4 is filed and open.
2. **Tier SLA copy:** the board reads "Under 1 hour"; the reused `tierFlashSpeed` key reads
   "Delivered in less than 1 hour." No new key was invented, so the line ellipsizes on narrow
   phones. If shorter SLA copy is wanted it is an l10n decision, not a layout one.
3. **Drop-off pin** is `cs.error` (~#B3261E), not the board's `#E02020` — the literal was refused.
4. **Radii snapped to tokens:** photo tiles 12 (`OmdsBorderRadius.small`) vs the board's 10; band
   top 20 (`OmdsBorderRadius.large.topLeft`) vs the board's 18.
5. **Ramp used as-is:** `bodySmall` is 12/w600 where the board says 12.5/w500 or 12/w600; `badge` is
   10.5/w800 vs 10/w800. No 0.5px chasing, per the instruction set.

## Files

Changed: `lib/features/request_summary/domain/request_draft.dart` ·
`lib/features/request_summary/presentation/request_summary_screen.dart` ·
`test/core/router/request_summary_route_test.dart` ·
`docs/redesign-2026-08/wiring/10-request-summary.md`
Created: `lib/features/request_summary/presentation/widgets/request_ticket.dart` ·
`lib/features/request_summary/presentation/widgets/broadcast_footer.dart` ·
`test/features/request_summary/request_summary_screen_test.dart`

Not touched: `app_router.dart`, `injection_container.dart`, `lib/core/theme/*`,
`lib/core/widgets/jeeb/*`, `lib/l10n/*`, `pubspec.yaml`, `request_summary_cubit.dart`,
`dio_request_submission_service.dart`, `request_summary_unavailable_screen.dart`, anything under
`features/transcription|request_type|tier_selection` (read-only imports only), `lib/devtool/**`,
Maestro flows, `test/decision_violations_test.dart`.
