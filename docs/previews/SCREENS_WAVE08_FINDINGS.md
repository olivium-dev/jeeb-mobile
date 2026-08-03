# Screens wave 08 (dispute, earnings, escalate, goods_cost, jeeber home/onboarding)

7/7 written, 60 previews, 0 agent errors. FIRST wave written under the corrected
font guidance — agents load the real Inter/Noto faces, so overflow numbers here
are device-plausible in a way earlier waves' are not (see FINDINGS_TRIAGE §6).

## F01

DisputeStatusScreen: `_EvidenceCard` emits its "Evidence summary" heading unconditionally but builds its rows conditionally, so a dispute with nothing attached renders a section header over blank space — no "nothing attached yet" line, no affordance, no signal that the section is finished rather than still loading. `DisputeEvidenceSummary.hasAny` exists in the domain for exactly this decision and nothing on the screen reads it. Pinned by `disputeStatusScreenOpenNoEvidence`.

## F02

DisputeStatusScreen: `_StateCard` branches on `dispute.isResolved` (i.e. `state == DisputeState.resolved`) only, so `DisputeState.unknown` takes the else branch and is presented as "Open — under review" with the warning hourglass and the reassuring "We're reviewing your dispute" body. `DioDisputeStatusRepository._state()` returns `unknown` for ANY status outside open/pending/in_review/resolved/closed — `escalated`, `withdrawn`, or a missing field — so this is the screen asserting a state it was never told. Pinned by `disputeStatusScreenUnknownWireState`.

## F03

DisputeStatusScreen: `DisputeStatusCubit.refresh()` opens with `if (disputeId.trim().isEmpty) return;` — the same guard `load()` uses — so the Retry button, the only affordance the D30 error page offers, cannot ever issue a read on the blank-id path. `disputeStatusScreenBlankIdRetryInert` puts a resolved dispute behind a recording repository and the render test asserts `fetchedIds` is still empty after the tap.

## F04

DisputeStatusScreen: `_ErrorBody._message` folds `DisputeStatusFailure.unauthorized` in with `unknown` and `null`, so an expired session reads "Could not load this dispute." — identical to an unclassified failure — over a Retry that will 401 again forever. Nothing on the page routes to a re-authentication, and the support CTA is not rendered in the failed state either.

## F05

DisputeStatusScreen: The loaded body identifies nothing: no dispute id, no `orderRef`, no `createdAt`, no `resolvedAt`. `DisputeStatus` carries all four and `_LoadedBody` renders none of them (`orderRef` is read only to seed the support form's `extra`). Two disputes on the same order with different outcomes are the same picture, and a resolved dispute never says when it was resolved.

## F06

DisputeStatusScreen: `_OutcomeCard._formattedAmount` returns the bare figure when `currency` is null, and `DioDisputeStatusRepository` reads `refundAmount` and `currency` independently — so a payload that omits the unit renders "A refund of 1234.50 was issued to you." with no currency anywhere on the card. Pinned by `disputeStatusScreenLongestContent`.

## F07

DisputeStatusScreen: The back CTA label is the constant `disputeStatusBackCta` ("Back to chat") while `_DisputeStatusView._back` falls back to `context.pop()` and then `context.go('/')` when the dispute carries no `conversationRef` or `orderRef`. The fallback is the honest behaviour (AP-9); the promise printed above it is not conditional on it, so the button lands the user on the home shell while still saying "Back to chat".

## F08

DisputeStatusScreen: `_LoadingBody` is `Center(child: OmdsLoadingState())` with no `message:`, so the cold read paints zero copy — no text, no skeleton, no timeout — and because `dispute_status_support` lives inside `_LoadedBody`, there is also no route to support for as long as the fetch takes. A repository that never answers leaves that bare spinner on screen forever.

## F09

DisputeStatusScreen: The `DisputeStatusScreen` class doc lists the semantics identifiers as EXACT and names `dispute_status_outcome` and `dispute_status_evidence`, but the widgets emit `dispute_status_outcome_note` (line 319) and `dispute_status_evidence_summary` (line 406). The existing widget test asserts the emitted spellings, so the doc — which is what a Maestro flow author would read — is the thing that is wrong.

## F10

DisputeStatusScreen: `DioDisputeStatusRepository` maps the wire `note` onto BOTH `DisputeStatus.note` (via `_parse`) and `DisputeEvidenceSummary.comment` (via `_evidence`'s `comment ?? note`), so any dispute whose payload carries `note` and no `comment` renders the same paragraph twice on this screen — once under the outcome heading and again as "Your note: …" in the evidence summary. Pinned by the render test as `findsNWidgets(2)`.

## F11

EarningsDashboardScreen: _DeliveryBreakdownList renders `const OmdsEmptyState()` when a summary carries a delivery COUNT but an empty `deliveries` list — OmdsEmptyState with no icon/title/subtitle/button builds an empty Column inside 24 dp of padding, so the jeeber gets a blank gap. The `Recent deliveries` heading is not rendered on that branch either, and `earningsBreakdownEmpty` ("Completed deliveries for this period will appear here.") already ships translated in BOTH ARBs and is not wired to it. Reachable from the live wire: EarningsSummary.fromJson reads `deliveryCount`/`rowCount` independently of the `items` array. Pinned by the ROLLUP PAYLOAD test.

## F12

EarningsDashboardScreen: _MemberSinceRow._formatDate's `DateTime.tryParse(iso) ?? iso` guard does not do what it reads as. `DateTime.tryParse('1730592000')` does NOT return null — ten digits match the basic-ISO `yyyyyy-mm-dd` shape as `173059-20-00`, the out-of-range month normalizes, and the result is `173060-07-31`. An epoch-seconds join date (a string EarningsSummary.fromJson accepts, since it only casts `memberSince`/`createdAt` to `String?`) therefore renders as a confident, formatted, fictional "Member since Jul 173060" rather than hitting the raw-echo fallback. Pinned by the EPOCH JOIN DATE test.

## F13

EarningsDashboardScreen: _MemberSinceRow._formatDate calls a bare `DateFormat.yMMM()`, which resolves through `Intl.getCurrentLocale()`; nothing in the app sets `Intl.defaultLocale`, so the month is en_US in every locale. The label beside it DOES translate, so the Arabic rendering reads "عضو منذ Nov 2025" — the only Latin-script token in the whole AR screen, and the app ships date formats for ar. (Also noted by the EarningsTab preview section; re-confirmed here through the real font faces.)

## F14

EarningsDashboardScreen: _PeriodFilterRow is a bare `Row` of three OmdsChips — no Wrap, no horizontal scroll, no Flexible. Measured through the shipping Inter + Noto Arabic faces it FITS a 390 dp phone at 100%, and overflows by 70.0 dp at 200% text (EN and AR alike). Because the row cannot scroll there is no gesture that brings the clipped "This month" pill back, so a large-text jeeber cannot switch period at all. Worst on the empty state, where the pills are the only control besides pull-to-refresh.

## F15

EarningsDashboardScreen: _FeesPaidCard is `Icon + Expanded(label column) + Text(amount)` and the amount has no flex, so it is measured against an unbounded main axis and the Expanded divides the remainder. Measured with real fonts: 104 dp tall with a 123 dp label at 390 dp for `$24.50`, against 292 dp tall with a 39 dp label at 320 dp for `LBP 12,845,000.00` — "Platform fees paid" wraps into a tall ribbon and the card nearly triples in height, pushing the stats row, the member-since row and the whole breakdown below the fold. Nothing throws; it is a silently-wrong layout. The amount needs a Flexible, or the row needs to wrap.

## F16

EarningsDashboardScreen: _buildBody's error branch renders the localized `copy.loadError` and never reads `state.errorMessage`, so the three classified messages EarningsCubit._mapError builds (network / server / parse) are dead code on this screen — every failure shows the identical generic line. Those three strings are also hardcoded ENGLISH, and the one path that does surface them (the export-failure `showOmdsSnackbar` in _onStateChange) therefore shows English copy inside an Arabic app.

## F17

EarningsDashboardScreen: Both the loading and the error bodies replace the ENTIRE body, including _PeriodFilterRow. A jeeber whose "This month" read failed (or is hanging on a slow gateway) has no way to drop back to "Today" without a successful read first, and the loading body carries no copy at all — a screen reader is told nothing while the read is in flight. Pinned for the loading state by the `Loading · cold read renders its own state` test.

## F18

EscalateScreen: `escalateSubtitle` is rendered THREE times by one form — as the subtitle (escalate_screen.dart:204), as the body of the `dispute_auto_attach_note` beside a paperclip icon (:226), and as the evidence panel's own header (:523). Two of the three are captions for something else entirely and no separate ARB key exists for either; the render test now pins `findsNWidgets(3)`.

## F19

EscalateScreen: The evidence panel's not-loaded branch renders `escalateSubmitting` — "Submitting…" — while `loadEvidence` is merely fetching the D53 chat snapshot (escalate_screen.dart:530-537). Every cold entry passes through it, so the screen claims to be sending a report over an untouched form whose Submit button is still on screen. The `Evidence pending` preview holds that state still and the test asserts both strings coexist.

## F20

EscalateScreen: Reaching the ≤5 photo cap silently REMOVES the only add-photo control: `_PhotoSection` guards the CTA with `if (photos.length < 5)` (escalate_screen.dart:366), so at the cap there is no disabled button, no "5 of 5" line and no explanation. The remaining count (`escalatePhotoCountRemaining`) exists only as a `Semantics` label, so it reaches a screen reader and no sighted user.

## F21

EscalateScreen: `EscalateErrorKind.alreadyOpen` is rendered with `onRetry: null` (escalate_screen.dart:722), producing a full-screen error with nothing on it to tap: no retry, no link to the dispute that already exists, and no route back to the form the customer had filled in. The only exit is the app-bar arrow, which leaves the flow. Previewed beside the network error, which is one enum value away and keeps its retry.

## F22

EscalateScreen: The network-error copy promises "Your report will be retried automatically" (`escalateErrorNetwork`), but nothing in this feature retries anything. `EscalateCubit.submit` emits the error and stops; the only retry is the button under the sentence.

## F23

EscalateScreen: A degraded evidence fetch is indistinguishable from "this delivery has no evidence". `EscalateCubit.loadEvidence` swallows every failure into `EscalateEvidence.empty`, so the panel drops its `(n)` counter and collapses the timeline to one generic "Live tracking" line — while the auto-attach note at the top still tells the customer the chat and GPS timeline ARE attached. Nothing on the screen says the read failed.

## F24

EscalateScreen: `_EvidenceSection._stepLabel` maps BOTH `AtDoor` and `Done` to `trackingStepCompleted` (escalate_screen.dart:603-605), so a timeline carrying both renders the identical "Delivered" row twice with nothing to tell them apart. The ceiling fixture had to omit `AtDoor` to keep the panel readable.

## F25

EscalateScreen: The voice row's visible label and its accessibility label disagree once a clip is captured: the button text is `voiceRequestRecorded` ("Recording ready") while the `Semantics` label on the same node is `voiceRecordingDiscard` ("Re-record"), which is what tapping actually does (escalate_screen.dart:443-469). The section heading is also `voiceRecordingTitle` — "Record your request" — copy borrowed from the voice-request feature and wrong on a dispute screen.

## F26

EscalateScreen: The submitting phase replaces the ENTIRE form, including the `dispute_back` button, with a bare spinner, and `EscalateCubit.submit` has no timeout. A POST that never answers leaves the customer on an uncancellable spinner with their assembled evidence off screen — which is exactly what the `Submitting` preview's never-completing fixture holds.

## F27

GoodsCostScreen: goods_cost_screen.dart:131 — `_submit` drops any input `double.tryParse` rejects on the floor: `final amount = double.tryParse(...); if (amount == null) return;`. The CTA's `isEnabled` only asks whether the field is non-empty (line 192), so `12,5` (comma decimal), `12.5.6`, `abc` and `١٢` (Arabic-Indic digits — what `TextInputType.number` gives an Arabic keyboard) all arm the button and produce a completely silent press: no spinner, no error, no state change. There is no `inputFormatters` and no validator on the field, so nothing stops any of them being typed. Pinned by 4 tests in `test/previews/goods_cost/goods_cost_screen_preview_test.dart` ('"<input>" arms the CTA and the press does NOTHING').

## F28

GoodsCostScreen: goods_cost_screen.dart:170 — `prefixIcon: const Icon(Icons.attach_money)` hardcodes a dollar sign into the same slot as a label the code goes out of its way to source from the gateway (the comment above `_label` cites 40_GUARDRAILS_ARCH §5, 'no hardcoded currency'). An LBP delivery renders `Goods cost (LBP)` next to a `$`; in AR the mirrored layout puts the `$` on the right of an Arabic label. The guardrail was applied to the string and missed the icon.

## F29

GoodsCostScreen: goods_cost_screen.dart:82/190 — nothing on this screen scrolls. `_GoodsCostView` is a fixed Column ending in `Expanded`, and the body inside it is field + optional error + `Spacer` + CTA, so the `Spacer` is the only give the layout has. Measured in EN with the real Inter face: 532 pt of slack on a 390x844 phone, 256 pt on the narrowest supported 320x568 one, dropping to 356 pt and ~40 pt at 200% text. This is a text-entry screen, so the software keyboard (~290 pt) is subtracted from exactly that slack by the screen's own `resizeToAvoidBottomInset` — on the compact frame the form overflows at 100% text, never mind 200%. Reproduced in the test ('take a keyboard off the compact frame and the form overflows'); the fix is a scroll view, not a bigger box.

## F30

GoodsCostScreen: goods_cost_screen.dart:174 — the submit-failure message is destroyed by the act of acting on it. `onChanged` calls `cubit.acknowledgeError()`, so the first keystroke after 'Enter a valid amount and try again.' clears the message, and nothing marks the field itself as invalid (`OmdsTextField.errorText` is never set — the error is a separate `Text` at line 178). The Jeeber corrects the amount and immediately loses the only statement of what was wrong.

## F31

GoodsCostScreen: goods_cost_cubit.dart:34 / goods_cost_screen.dart:167 — 'currency read in flight' and 'currency read failed' are pixel-identical: both render the neutral `Goods cost` label with a live field and a live CTA, and there is no spinner, skeleton or disabled state anywhere to say a read is happening. Two consequences: the label can change under the Jeeber's finger the moment `loadCurrency` lands, and after a failure the person typing cannot tell whether they are being asked for dollars or for pounds (~90,000x apart). The failure swallow itself is deliberate and documented; the total absence of an affordance is not.

## F32

GoodsCostScreen: goods_cost_screen.dart:158 — the success listener calls an unguarded `Navigator.of(context).pop(recorded)` on a screen whose app bar leaves `showBackButton` at its `false` default, so the only leading affordance is whatever `automaticallyImplyLeading` finds. Reached by a stack-REPLACING navigation, that pop empties the Navigator and leaves a contentless surface — the exact failure `OMDSAppBar._buildBackButton` guards against with `maybePop`, documented in its own source. GoodsCostScreen is an orphan today (JEBV4-227), so this is a trap for whoever routes it rather than a live defect.

## F33

GoodsCostScreen: goods_cost_screen.dart:131 — no client-side validation of the amount at all: `-5` and `0` parse and are submitted to the gateway to be rejected there, costing a round trip and surfacing as the same generic 422 copy. Pinned in the test ('the client never validates the amount').

## F34

JeeberHomeScreen: No loading surface at all. `_RegisteredViewSwitch` branches on `AvailabilityLoadPhase.loadError` and nothing else, so while the cold `GET /v1/availability` is still outstanding the screen renders `AvailabilityStatus.initial` as a SETTLED offline dashboard — same full availability card, same "You're offline" title, no spinner, no skeleton, no disabled state. `jeeberHomeScreenColdRead` is byte-identical to `jeeberHomeScreenOffline` apart from the greeting name (pinned by the 'an in-flight cold read is drawn as a settled OFFLINE dashboard' test, which asserts no Circular/LinearProgressIndicator exists anywhere). A jeeber on a slow link is told they are offline before the server has answered, and a toggle tapped in that window races the fetch that is about to overwrite it.

## F35

JeeberHomeScreen: "Pull down to refresh" is a promise only ONE of the two online-empty branches can keep. `JeeberNoRequestsView`'s empty copy is `requestFeedEmptySubtitle` ("Pull down to refresh, or stay online…"), but the `OmdsPullToRefresh` wrapper added by JEBV4-13 P2-6 sits only on the `hasFeedCubit && online && requests.isEmpty` branch in `_AvailableBody`. Reaching `_NoRequestsScope` any other way — no feed cubit, or offline/auto-offline — renders the identical copy inside a bare `SingleChildScrollView(AlwaysScrollableScrollPhysics)`: it drags and springs back and refreshes nothing. Pinned by the `jeeberHomeScreenOnlineNoRequests` / `jeeberHomeScreenEmptyFeed` pair (`OmdsPullToRefresh` findsNothing vs findsOneWidget over the same body and the same string).

## F36

JeeberHomeScreen: `_AvailableBody` never reads `RequestFeedState.status`. Its only test is `feedState.requests.isEmpty`, so a feed cubit in `RequestFeedStatus.loading` and one in `.error` (whose `errorMessageKey` the cubit sets and this screen ignores) both fall through to the no-requests body and tell the jeeber "No requests right now" — a claim about server data that a failed `GET /v1/jeebers/me/feed` is no evidence for, with no error, no retry and no way to tell the two apart.

## F37

JeeberHomeScreen: The availability load-error body is a dead end that takes unrelated, still-valid state down with it. `_LoadErrorView` replaces the ENTIRE dashboard — greeting, availability control, feed, and the injected active-deliveries banner — so a jeeber who has an ACCEPTED delivery in progress loses their in-app re-entry into that order's chat (the whole point of S007-P1B) because a different endpoint, `/v1/availability`, failed. Asserted by 'a failed availability read replaces the WHOLE dashboard'. The JEBV4-271/279 self-heal only papers over the 403 sub-case, and only when a `RoleCubit`, a `RoleAvailabilityCubit` and a DI-registered `RoleSwitchRepository` are all present — otherwise `_autoActivateJeeber` silently returns and the jeeber is left with the manual Retry.

## F38

JeeberHomeScreen: The screen's DEFAULT collaborators are live-network ones resolved from the global service locator during build, not injected ones. `_resolveSubmittedOffersCubit` falls back to `sl.isRegistered<Dio>()` → `DioSubmittedOffersRepository`, and `_NoRequestsScope` falls back to `const JeeberActiveDeliveriesBanner()`, which itself resolves `sl<Dio>()` and issues `GET /requests?role=jeeber` from `initState`. Both the previews and the catalog entry have to pass explicit fakes for those two params purely to stay off the wire; an un-injected host gets two real reads it never asked for. This is the one thing that made the screen awkward to preview — it is previewable (both are optional ctor params), but the safe path is opt-in rather than default.

## F39

DmOnboardingScreen: The failure toast covers the only control that can retry. `showOmdsErrorSnackbar` raises a FLOATING SnackBar bottom-anchored to the wizard's Scaffold, and `DmOnboardingStepLayout` pins Continue to the bottom of that same Scaffold. Measured in test/previews/jeeber_onboarding/dm_onboarding_screen_preview_test.dart ('the toast escapes the phone frame in the preview host, and lands on the CTA on a device'): the toast band, translated onto the phone frame, overlaps the CTA rect. For the toast's 4 s, "Couldn't check coverage for this area. Please try again." sits on top of the only way to try again.

## F40

DmOnboardingScreen: A failed coverage probe leaves NO durable trace. `_onError` calls `acknowledgeError()` immediately and the SnackBar times out after 4 s, after which the wizard is identical to a step that was never submitted — same live Continue, same pinned base, no inline error, no retry affordance. Pinned by 'the error is one-shot: the wizard keeps no trace of it'. The JEBV4-13 P1-5 fix moved the failure from invisible to 4-seconds-visible, not to recoverable.

## F41

DmOnboardingScreen: `coverageReady` is a one-shot edge with no reset, so a hand-off that fails once is dead for the visit. `_onCoverageReady`'s listenWhen is `!prev.coverageReady && curr.coverageReady`, nothing ever clears the flag, and `DmOnboardingCubit._confirmCoverage` re-emits `coverageReady: true` on every later Continue. If the FIRST hand-off does not navigate — no GoRouter above the screen and a null `onCompleted`, i.e. exactly the Screen Catalog / preview canvas / cold-deep-link case — every subsequent Continue re-runs the probe and the listener never fires again. There is no `clearCoverageReady` on the state.

## F42

DmOnboardingScreen: `DmOnboardingError.photoPickFailed` blames the photo for a denied OS permission. A `PhotoPickFailure.permissionDenied` is collapsed by the cubit into the same single error value as `unavailable`, so `_onError` can only say "Couldn't use that photo. Please try again." — copy that describes a bad picture, offers no route to Settings (asserted: no 'Settings' string anywhere in that state), and leaves step 1's Continue gated on the photo the user cannot take. The screen has no finer value to switch on; the discrimination is lost in `DmOnboardingCubit._surfacePickFailure`.

## F43

DmOnboardingScreen: The wizard's only error surface is owned by whatever Scaffold is the ROOT of the nested set, not by the wizard. `ScaffoldMessengerState._isRoot` presents a SnackBar in the outermost registered Scaffold only, so hosting `DmOnboardingScreen` under another Scaffold — the Screen Catalog does this, `jeebPreviewHost` does this, any future sheet/host would — silently relocates the coverage/photo failure message outside the wizard entirely. Verified: `find.descendant(of: DmOnboardingScreen.rootKey, matching: find.byType(SnackBar))` finds nothing under the preview host.

## F44

DmOnboardingScreen: The screen cannot be hosted without a GoRouter. `_OnboardingBackButton._onBack` calls `context.canPop()` on the first step, which asserts when no GoRouter is in the tree — so Back on step 1 throws in the Screen Catalog and in the preview canvas, while Back on steps 2/3 (a plain cubit call) works. Pinned by 'Back steps the wizard on step 2, and needs a router on step 1'. `_onCoverageReady` already has a router-less fallback (`onCompleted`); the back path has none.

## F45

OnboardingFundingScreen: Both OMDSSectionCards AND the app bar pass `l10n.fundingTitle`, so "Your starter credit" is painted THREE times on a two-section screen and the D1 reserve-10%-per-offer card is labelled with the starter-credit heading. The .arb has no second title key (only `fundingTitle`/`fundingReserveBody`), so this is a copy gap, not a typo. Pinned at findsNWidgets(3) in the render test.

## F46

OnboardingFundingScreen: A read still in flight is INDISTINGUISHABLE from a failed one. `initState` fires `fetchBalance()` and the first frame is painted long before it can return, and the screen has no spinner, skeleton, placeholder or error strip — so the state 100% of users see first renders byte-identical strings to a permanently failed read. The render test asserts that equality directly (full list of painted strings), because no single string could discriminate them.

## F47

OnboardingFundingScreen: The two enrichment gates (`balance != null && balance.giftCredit > 0` / `.reservedNow > 0`) conflate a legitimate zero with no data. A jeeber who has not sent an offer yet (`reservedNow == 0` — the FIRST state after KYC submit) gets exactly the reserve card a network failure produces; symmetrically `giftCredit == 0` blanks the card the screen is named after. The fail-safe itself is correct per 40_GUARDRAILS_ARCH §3, but it is silent: no retry, no "amounts unavailable" hint.

## F48

OnboardingFundingScreen: At 200% text on a 390x844 phone with a long amount, NEITHER `funding_topup_cta` nor `funding_continue_cta` is even built — both are past the ListView's cache extent. In Arabic at 200% (ordinary amounts, measured through the real Noto face) the top-up CTA survives but `Continue` lays out at y 839–879 against an 844 pt viewport, i.e. clipped to a 5 pt sliver with 63 pt of scroll behind it. The only affordance that advances onboarding is reachable solely by scrolling a page whose layout gives no hint that it scrolls.

## F49

OnboardingFundingScreen: `_formatMoney` neither groups digits nor drops the two decimals, so `1234567.89 LBP` measures 375.8 pt unwrapped in headlineSmall at 200% text. Its only break opportunity is the single space: on a 320 pt phone (240 pt card) the paragraph breaks INSIDE the digit run and the starter credit renders as two stacked numbers; on a 390 pt phone (310 pt card) the currency code is orphaned alone on line two. `Text` wraps rather than throwing, so nothing in CI notices. LBP is a live currency for this app, so this is a realistic snapshot rather than a stress test.

## F50

OnboardingFundingScreen: The `context.pop()` half of `onBackPressed` is dead code today. The KYC wizard chains here with `context.goNamed('onboarding-funding')`, which REPLACES the stack, and the dev-seam landing (`jeeberKycSubmitted`) starts on `/jeeber/onboarding/funding` cold — so `context.canPop()` is always false and the arrow always takes `context.go('/')`. The screen's own comment ("Normally pushed after KYC submission, but also reachable via deep link with an empty Navigator stack") states it exactly backwards.

