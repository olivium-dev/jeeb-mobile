# Screens wave 05 (registration, request_summary, settlement, voice_request)

7/7 delivered. Two agents (VoiceRecordingScreen, SettlementDetailScreen) hit
`API Error: Connection closed mid-response` AFTER writing their files, so the
workflow recorded them as errors while their work was complete on disk and
passing. Verified individually before this was committed.

## F01

OtpVerificationScreen: A network failure is reported to the user as a WRONG CODE. `_otpErrorCopy` maps `RegistrationOtpError.networkError` onto `l10n.registrationOtpInvalid` ("Wrong code. Try again."), and `_OtpEntry` takes `hasError` from `otpError != null`, so the cells get the same red border. A user whose verify never left the device is told the digits they just read off an SMS are wrong. There is no `registrationOtpNetwork` key in either ARB, and no connectivity copy anywhere on the screen. The only tell is the ABSENCE of the attempts counter, because the network branch costs no attempt.

## F02

OtpVerificationScreen: The screen renders its title TWICE. `OMDSAppBar(title: l10n.registrationOtpTitle)` and a `headlineSmall` at the top of the body are the same string, so "Enter the code" / "أدخل الرمز" is drawn once in the bar and again ~16 pt below it. Visible on every state, in both locales (the test pins `findsNWidgets(2)`).

## F03

OtpVerificationScreen: `registrationOtpAttemptsRemaining` has no plural form in either ARB, so the most consequential moment on the screen — the last attempt before lockout — reads "1 attempts remaining" in EN. The Arabic is the same single form ("1 محاولات متبقية"), which is wrong for both 1 and 2 in a language with a dual.

## F04

OtpVerificationScreen: The verify CTA can NEVER be enabled from cubit state. `isEnabled` is `!state.isVerifying && _enteredCode.length == 4`, and `_enteredCode` is `State`-local starting at `''`, so no state restored from the cubit can satisfy the second half — including `Verifying…`, which by definition has a code in flight and still draws a DISABLED button. Nothing breaks for a user typing on a live screen, but any rebuild that re-runs `initState` (locale change, hot reload) drops the typed code from the CTA's gate while the four cells keep displaying it, stranding the user on a disabled button over a full-looking input.

## F05

OtpVerificationScreen: Lockout is a one-way door whose only exit is mislabelled. The whole `if (state.step != RegistrationStep.lockedOut)` block — entry cells, attempts counter, verify CTA, resend row AND "Change phone number" — is unmounted, leaving the banner and the app-bar back arrow. That arrow's only semantics id is `phone_otp_back_cta`, but `onPressed` calls `changePhone()`, i.e. it navigates OUT of the lockout to phone entry — the opposite of what a back arrow above a countdown implies, and the only affordance a locked-out user has.

## F06

OtpVerificationScreen: The two lockouts are the same picture from completely different causes. `verifyCode` routes `OtpVerifyOutcome.rateLimited` (gateway HTTP 429) into `RegistrationStep.lockedOut` instead of burning an attempt, so `failedAttempts` stays 0 — yet the user is shown the identical "Too many attempts" banner as someone who burned all three. On screen the two differ only in the mm:ss the countdown happens to hold. A user who typed nothing wrong is blamed for too many attempts.

## F07

OtpVerificationScreen: Five doc comments on this screen still describe a 6-digit OTP, but `_OtpEntry._kOtpLength = kCustomerOtpLength` and `kCustomerOtpLength = 4` (lib/features/registration/domain/otp_service.dart:6). Lines 23, 34, 273, 275, 279 and 289 say "6-digit OTP", "the mock dev code is the 6-digit `123456`", and — load-bearing, because it is a driver contract — "per-cell ids `phone_otp_input_0..5`". Only `phone_otp_input_0..3` exist. A Maestro/integration driver written against these comments would type 6 digits into 4 cells and submit `123456` against a service whose valid code is 4 digits. The rendered subtitle already says "We sent a 4-digit code to …", so the code and the copy agree and only the docs are stale.

## F08

RegistrationScreen: `_phoneErrorCopy` (registration_screen.dart:595) maps RegistrationPhoneError.networkError AND .rateLimited onto l10n.registrationPhoneInvalid — 'Enter a valid Lebanese phone number.' Two of the screen's three error states therefore tell a user whose number parses cleanly that the number is wrong. The only remedy the copy suggests is 'fix your number', which for those two causes cannot clear the error no matter how correct the digits are, and nothing on the screen mentions the connection or a rate limit. There is no registrationPhoneNetwork / registrationPhoneRateLimited key in either ARB (the code comment defers this to JEEB-56). Pinned by the render test: 76001122 and 81445566 both satisfy LebanonPhone.tryParse yet both render the invalid copy.

## F09

RegistrationScreen: Nothing throttles a retry after a 429. On RegistrationPhoneError.rateLimited the field stays `enabled: true` and `registration.sendCode` stays `isEnabled: true` — RegistrationCubit.sendCode has no client-side cooldown on the send leg at all — so the single action the screen offers after a rate-limit is an immediate re-tap of the endpoint that just refused it, while the inline copy blames the phone number. The sibling OtpVerificationScreen routes its own 429 into a lockout step with a visible countdown; the send leg has no equivalent.

## F10

RegistrationScreen: A pasted international number is drawn NEXT TO the permanent, non-editable '+961' prefix, so the field reads '+961  +961 71 123 456'. `_PhoneField`'s own doc comment asserts the opposite — 'The TextField only ever receives the 8 national digits; the prefix is decorative' — but nothing enforces it any more: `inputFormatters` deliberately allows '+' so a pasted block is not truncated at the wrong end, and PR #45 removed the per-keystroke mirror-back of the normalised value (it corrupted live editing, Maestro P0). Only sendCode normalises, and it never writes back — `_syncControllerText` runs on step transitions only. The outbound request is still correct (+96171123456), so this is a display defect rather than a delivery one, but it is the first thing a user sees after pasting and it is RTL-sensitive because prefixIcon is directional.

## F11

RequestSummaryScreen: Tier-card entry produces an unfillable empty description. lib/core/router/app_router.dart:1105-1111 pushes `RequestDraft(description: '', tierId: tier.id.name, tierName: tier.id.name)` with the comment "the user fills it on the summary screen", but request_summary_screen.dart renders every value as a bare read-only `Text` — there is no `EditableText`/`TextField` anywhere on the screen — so the Description card is a title over a blank line and `Send request` stays enabled and submits the empty string. The ARB has carried the placeholder for this all along: `requestSummaryDescriptionEmpty` ("No description provided") and `requestSummaryPhotosEmpty` are translated in EN+AR and referenced by NO Dart file.

## F12

RequestSummaryScreen: The Speed card shows the raw enum id. The same router call passes `tierName: tier.id.name`, so the card reads `express` — lowercase, untranslated — where the localized tier label belongs; in AR that is latin text under a localized title (`السرعة`) in an RTL paragraph.

## F13

RequestSummaryScreen: The submit failure surface is hardcoded ENGLISH in both locales. `RequestSummaryCubit._messageFor` returns literals ('No connection. Check your network and try again.'), so an AR user gets English on a red bar while `requestSummaryErrorNetwork` IS translated in both ARBs and is rendered by three other screens (tier_selection, request_type, client_location). Pinned in the render test as a defect: the AR run finds the English string and not the AR one.

## F14

RequestSummaryScreen: A failed submit leaves no trace after ~4 s. `state.error` is set but never rendered in the body — the card list returns to exactly its idle rendering with the CTA live again — and `requestSummaryRetry` ("Try again") is unused on this screen. The only surface is a floating snackbar which, because the nearest `ScaffoldMessenger` is the host `MaterialApp`'s rather than this screen's `Scaffold`, draws at the bottom of the page and then disappears.

## F15

RequestSummaryScreen: `recipientPhone` is on the draft and off the screen. It is the number the at-door handover OTP is dispatched to (T-BE-019 / JEB-55) and the one field a client would most want to check before committing; `_RequestSummaryBody` renders six cards and no card for it.

## F16

RequestSummaryScreen: The photo card counts files it never shows, in copy that never pluralizes. `requestSummaryPhotosAttached` is a plain `{count}` placeholder (not an ICU plural), so one photo reads '1 photo(s) attached' and twelve read '12 photo(s) attached' with the AR singular 'صورة'; no thumbnail is rendered, so the client cannot check WHICH photos are attached.

## F17

RequestSummaryScreen: Success is the state with no design. `context.go('/')` fires on the `isSubmitted` edge and the screen is gone; `RequestSummaryState.requestId` — the id the gateway just minted — is read by no widget in the app, so the client lands back on the Requests tab with no confirmation that anything was created.

## F18

RequestSummaryScreen: The `draft == null` branch returns a bare `OmdsLoadingState` from ABOVE the `Scaffold`: no app bar, no title, no back affordance — a spinner on an empty surface with no way off it. Unreachable through the shipped route (which substitutes `RequestSummaryUnavailableScreen` and seeds the draft inside the provider) but it is the cubit's INITIAL state, so any future caller that forgets `setDraft` strands the user.

## F19

RequestSummaryScreen: At 200% text the submit CTA is not on the screen at all. Measured on the declared 390x844 box: at 100% the CTA occupies y 748–796, i.e. 48 pt of slack; at 200% only three of the six cards lay out and `OmdsLoadingButton` is not even built. It is the last child of a scrolling `ListView`, not a pinned footer, so the button that commits the request has to be scrolled to with nothing on the surface indicating there is more below — and one extra card or one extra wrapped line costs that 48 pt at the default text size too.

## F20

RequestSummaryUnavailableScreen: EN-only title collision: `requestSummaryUnavailableTitle` (app_en.arb:1912) and `requestSummaryTitle` (:1784) are both exactly "Review & submit", so the empty-state fallback wears the populated review screen's header — a user whose draft was lost gets the review step's own title over an empty box with no signal that anything went wrong. Arabic does NOT collide ("المراجعة والإرسال" vs "مراجعة وإرسال", app_ar.arb:660 / :626), so the two locales disagree about whether these are the same screen. Both halves pinned in the render test.

## F21

RequestSummaryUnavailableScreen: The back arrow is dead in the exact arrival the screen exists for. `OMDSAppBar(showBackButton: true)` is passed no `onBackPressed`, so it defaults to `Navigator.of(context).maybePop()`, which no-ops on a lone page — and a cold deep link to `/request-summary` (the case app_router.dart:1329 was written for, pinned by request_summary_route_test.dart Test 2) is exactly one page. `RootAwareBackScope` rescues the Android system BACK gesture via `AppRouter.backFallbacks['request-summary'] = '/'`; nothing rescues the arrow, and iOS has no such gesture. This is the same defect JEBV4-13 P1-6 fixed on offer_kyc_gate_screen, delivery_register_prompt_screen and kyc_rejected_screen (test/back_arrow_dead_at_root_test.dart) — this screen was not in that sweep.

## F22

RequestSummaryUnavailableScreen: The body copy promises an action the screen cannot perform: "No request draft available. Start a new request to continue." while `OmdsErrorState` is given no `onRetry`, so there is no CTA anywhere. Combined with the dead arrow above, the deep-link state has zero working exits and zero ways to do what it asks. Pinned: no `ButtonStyleButton` inside the screen, exactly one `IconButton`.

## F23

RequestSummaryUnavailableScreen: At 200% text on a 320 pt display the composition fits by 16 pt — 480 pt of content in the 512 pt the app bar leaves, 94% of the body box. There is no `SingleChildScrollView` anywhere in the chain (pinned by a test), so anything that does not fit is clipped off the bottom, where the only instruction is. The sibling ProfileUnavailableScreen is the same `Center` + non-scrolling `Column` with one more line of text and it overflows the identical window by 164 px. A heading, a second sentence, a longer translation, or the CTA the copy already promises each cost more than the 16 pt left.

## F24

SettlementScreen: Every error string on this surface is hardcoded ENGLISH. `SettlementCubit._mapError` returns 'No internet connection' / 'Server error. Please try again.' / 'Statement not found' / 'Unable to save PDF file', and `_buildBody` uses `state.errorMessage ?? l10n.settlementLoadError` — so the localized key wins only when the message is null, which the cubit never emits. `settlementLoadError` exists in both app_en.arb and app_ar.arb and is DEAD copy; an Arabic build shows English on every failure, under an `OmdsErrorState` whose 'Retry' label is also an English default. Visible side by side in the `Error · offline` matrix card.

## F25

SettlementScreen: `SettlementCubit.loadStatements` is `try { … } on SettlementException catch (e)`, so anything else out of the data layer (a TypeError from `SettlementStatement.fromJson` on a changed payload, a DioException that escaped, a FormatException) is not caught: no error state is emitted, the discarded future completes with an uncaught async error, and the screen sits on its spinner forever with no message and no retry. Pinned by `settlementScreenUnmappedFailure` — the render test needs `runZonedGuarded` to pump it at all, which is itself the evidence.

## F26

SettlementScreen: `SettlementState.isExporting` is list-wide, not per statement, so downloading ONE week's PDF replaces the download button on EVERY row (`_StatementList` passes the same `isExporting` to all rows). Worse, `downloadPdf` early-returns while `state.isExporting`, so the other rows are not merely busy — they are unreachable until the export finishes. Pinned: 2 cards, 0 download icons.

## F27

SettlementScreen: The per-row export indicator is invisible. `_StatementRow` renders `SizedBox(width: 20, height: 20, child: OmdsLoadingState())`, but `OmdsLoadingState` is a 48 pt CircularProgressIndicator inside `EdgeInsets.all(Spacing.large)` (20) — 88 pt of intrinsic width forced into 20. Measured layout: `Size(0.0, 48.0)`. Zero pixels wide, so nothing is drawn, and 48 pt tall against a 20 pt budget. During an export the trailing column of every row is simply blank.

## F28

SettlementScreen: Each row announces its amount and status TWICE. `_StatementRow` puts `l10n.settlementRowSemantics(amount, status)` ('USD 184.50 — Paid') on a Semantics around the `Card`, then wraps the `InkWell` in `Semantics(container: true, button: true)`, which starts its own node and merges the three Texts into it ('Jun 22 – Jun 28 / USD 184.50 / Paid'). The crafted summary label therefore duplicates the row content on a separate non-interactive node instead of replacing it.

## F29

SettlementScreen: `settlement_download_<id>` — the identifier an automation harness or a11y audit would target — resolves to a `button: true` node with an EMPTY label, an EMPTY tooltip, and NO `SemanticsAction.tap`. The node that actually acts is its unnamed single child, whose only name is the 'Download PDF' tooltip. Two button nodes per row, the outer one inert and unlabelled.

## F30

SettlementScreen: `_Unavailable` (what `SettlementScreen()` renders when neither seam is supplied) builds `OMDSAppBar(title: …)` without `showBackButton`, unlike the loaded surface which passes it, and `automaticallyImplyLeading` finds nothing to pop. Measured: zero back arrows on this state versus one on the loaded state. The route is an ORPHAN (JEBV4-227: registered, zero inbound nav), so deep-link entry is the only way in — and this state has no way out.

## F31

SettlementScreen: A failed PDF export's only feedback is a 4-second snackbar: `_onStateChange` calls `showOmdsSnackbar` and immediately `acknowledgeExport()`, so the rows are already back to their download buttons while the snackbar is still up, and once it times out nothing on the screen records that anything failed. There is no retry affordance for a failed export anywhere.

## F32

SettlementScreen: A statement whose `weekLabel` the gateway omitted renders a card with a BLANK title line. `SettlementStatement.fromJson` defaults `weekLabel` (and its `periodLabel` alias) to `''` and `_StatementRow` prints it unguarded, so the amount is the only thing identifying the row. Two such rows are in the longest-content preview; the render test finds two empty Text widgets.

## F33

SettlementScreen: Seam hazard, not a production bug today: `_Body` handles export results in a `BlocConsumer.listener`, which only sees transitions occurring AFTER it subscribes. A cubit passed through the `cubit:` seam that has already finished exporting arrives in `error`/`done` silently — no snackbar, no `onOpenPdf` call. The route uses `repository:` so it is unaffected, but the preview host has to drive the export from a post-frame callback to observe it at all.

