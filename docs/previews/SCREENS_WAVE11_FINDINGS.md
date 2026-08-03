# Screens wave 11 — findings

`OtpHandoverScreen`, `PasswordSecurityScreen`, `DisplayNameSetupScreen`,
`ProhibitedItemReportScreen`, `RequestTypeScreen`, `ReviewsListScreen`,
`ShellScreen`. 7/7 written, 59 previews, 0 agent failures.

53 findings. Nothing here was fixed — this is a record, per the campaign
rule that previews observe production and never edit it.

Pixel figures were measured with the real Inter/Noto faces loaded, not
`flutter_test`'s 1-em square face. See FINDINGS_TRIAGE.md §6.

## DisplayNameSetupScreen

1. No seam for the NAME, so the enabled-CTA state is unreachable from every dev
   surface. `_DisplayNameSetupScreenState` owns its `TextEditingController`
   privately and constructs it empty; the widget takes
   `repository`/`refreshSignals`/`cubit` and nothing else. `_SubmitButton`
   gates on `controller.text.trim().isNotEmpty` rather than on cubit state, so
   the one frame every real user passes through — a name typed, Continue live —
   can only be produced by a widget test that types into the field. Both the
   Screen Catalog and the new preview canvas show a permanently dead CTA.
   Closing it needs an `initialName` seam or moving the draft into
   `DisplayNameCubit`; that is a production edit and was NOT made.

2. A missing repository reports success and silently drops the name.
   `_resolveRepository()` returns null when the `repository:` seam is null and
   `Dio` is not registered (`display_name_setup_screen.dart:53-57`), and
   `DisplayNameCubit.submit` then emits `DisplayNameStatus.saved` with no
   transport at all (`display_name_cubit.dart:36-39`). On any build where the
   DI graph has not registered `Dio` by the time this step mounts, the user
   types their name, the step resolves, and nothing was ever PUT. The field doc
   calls this "fixture mode"; nothing on screen does. Pinned by
   `displayNameSetupScreenSavedWithoutRepository` and by the
   `savedWithoutRepository reaches `saved` with NO transport` test.

3. `DisplayNameStatus.saved` has no rendering whatsoever. `isSaving` is false
   and nothing else consults the status, so the terminal state of the step
   paints exactly the idle form — no confirmation, no name echoed back, no
   disabled form. The only feedback is the HOST navigating away. The `Saved`
   preview card is pixel-identical to the `Idle` card and the step is already
   resolved in it.

4. `DisplayNameStatus.failure` also has no rendering: no inline error, no field
   highlight, nothing. The only failure feedback is a 4-second SnackBar raised
   from `BlocConsumer.listener`, so the error is bound to a state TRANSITION,
   not to a state. A cubit that is already on `failure` when the screen mounts
   renders a clean, error-free form — which is exactly what happened when the
   extracted catalog fixture seeded the state eagerly: the Screen Catalog got
   away with it because a `CatalogState` builder runs inside a synchronous
   `build()`, but under `WidgetTester.pumpWidget` the rejected future's
   microtask lands BEFORE the mount and the snackbar never appeared. Fixed in
   the dev surfaces only, by firing the submit from a post-frame callback
   (`DisplayNameSetupScreenPreviewDriver`); the screen itself is unchanged.
   Once the snackbar times out the screen cannot distinguish a user who never
   submitted from one whose name was just lost.

5. A hung PUT is an unexitable screen. `_NameStepBody` passes `enabled:
   !state.isSaving` to the field AND to `_SkipButton`, so `saving` disables the
   only exit a step whose whole contract is "optional, never blocks
   registration" has — and `DioDisplayNameRepository` sets no
   send/receive/connect timeout of its own (it issues `GET /v1/users/me` then
   `PUT /api/User/profile` on the shared Dio). There is no cancel, no back and
   no skip for as long as the request hangs. Pinned by
   `displayNameSetupScreenSaving` and the `Saving · the field, the CTA and SKIP
   are all disabled at once` test.

6. At 200% text on a 320x568 frame, "Skip for now" — the only live control on
   the step — starts entirely below the fold. Measured with the real Inter/Noto
   faces, not the 1-em test face. It is not a defect (the body is a
   `SingleChildScrollView`, and `ensureVisible` brings it back), but nothing on
   the screen indicates there is anything below, and the visible CTA above it
   is dead until a name is typed — so the accessibility-ceiling reading is a
   screen with no apparently-usable control. Pinned by the `at 200% Skip goes
   BELOW the fold` test; nothing overflows at 100% or 200% in either locale.

## OtpHandoverScreen

1. Attempts hint counts into the NEGATIVE. `_AttemptHint` renders
   `OtpHandoverState.maxAttempts - state.wrongAttempts` with no floor and
   nothing caps `wrongAttempts`; `dismissEscalate()` clears the `escalate` flag
   that gates `submitOtp`, so a 4th wrong code gets through and the hint reads
   '-1 attempt(s) remaining' — in EN and AR alike, since the ARB is a plain
   `{count}` substitution. Pinned by `otpHandoverScreenPastTheCap` and by the
   test 'a fourth wrong code prints a NEGATIVE attempts hint'.

2. Cancelling the escalate dialog clears the ERROR but not the COUNT.
   `OtpHandoverCubit.dismissEscalate` passes `clearError: true`, so
   `_OtpInstruction` reverts to the neutral 'Enter the OTP from the Client'
   while the red hint below it still reports a spent (or negative) budget. The
   screen reads as if nothing went wrong.

3. The customer's code body overflows the 320 pt phone at 200% text, with the
   SHIPPING 4-digit code — no gateway change needed. Measured through the real
   Inter/Noto faces on the pinned 320x568 frame: RenderFlex overflow of 96 pt
   (EN) / 66 pt (AR); with a 6-digit code, 224 pt / 194 pt. `_ClientOtpDisplay`
   is a `Center` over a bare `Column` and NOTHING on this screen scrolls, so
   what runs off the bottom is the 'Rate your Jeeber' CTA and no gesture brings
   it back.

4. The handover code wraps MID-NUMBER when the panel is narrower than the
   digits. On the 320 pt floor `481902` wants 283.6 pt of the 208 pt available
   and re-flows onto two stacked fragments that read as two numbers (no
   `FittedBox`, no `maxLines`, no `overflow` anywhere on the path). Nothing on
   the customer's side enforces the 4-digit contract — only the jeeber's submit
   button does (`code.length == 4`) — so a widened gateway code would leave the
   customer showing digits the jeeber's grid cannot even accept.

5. `_ClientSmsFallback`'s resend button has an UNREACHABLE loading state:
   `isLoading: state.mode == OtpHandoverViewMode.loading`, but `_OtpBody`
   switches the whole body to the full-screen spinner in that same mode. The
   in-place spinner can never paint, and a customer who taps resend loses the
   sentence that explained the wait.

6. The customer's cold-read state carries no copy at all. Asserted in the
   render test: the entire tree contains exactly ONE `Text` (the app bar title)
   while `GET /otp` is triggering an SMS on the customer's behalf — no 'sending
   your code' line, and no timeout behind the call, so a slow gateway leaves a
   bare spinner up indefinitely.

7. The OTP grid stays live while the verify POST is in flight. `OmdsOtpInput`
   is never disabled, so its cells keep focus and keep accepting digits — the
   jeeber can rewrite the code under a request already sent. Both
   `_onCompleted` and `OtpHandoverCubit.submitOtp` guard on `mode ==
   submitting`, so nothing is re-submitted: the input responds and means
   nothing. The button is the only control that visibly stops.

8. `OtpHandoverScreen._shouldListen` carries a dead clause: it returns true on
   the `ready → success` transition, but `_onStateChange` only acts when
   `state.escalate` is set. The listener is woken for success and does nothing.

9. Adjacent (cubit, not the screen): `OtpHandoverCubit.submitOtp` emits after
   its `await` with NO `isClosed` guard, unlike `_fetchFromGateway` beside it
   which has one. A jeeber who leaves the screen while the verify is in flight
   makes the cubit emit after close — a `StateError` on an unawaited future.

## PasswordSecurityScreen

1. Both error branches paint the SAME hardcoded string.
   `password_strength_error` and `password_mismatch_error` are two different
   Semantics nodes but both render `l10n.setpwValidationError` — "Passwords
   must match and meet the strength requirements." `ChangePasswordValidation`
   distinguishes `empty` / `weak` / `sameAsCurrent` / `mismatch` and
   `PasswordSecurityState` carries the value, but `hasStrengthError` folds
   three of them into one node and both nodes print the same sentence. For two
   of the four the sentence is factually WRONG: a user who typed their current
   password into all three boxes (`sameAsCurrent`) is told it fails the
   strength requirements when it is strong AND matching; a user who typed
   nothing (`empty`) is told the same. The ARB has no per-cause key in either
   locale to fix it with (lib/features/password_security/presentation/password_
   security_screen.dart:193-218).

2. `PasswordSecurityStatus.submitting` is UNREACHABLE.
   `PasswordSecurityCubit.submit` is synchronous end to end — it validates and
   emits `failed` or `unavailable` in the same turn — and nothing else emits
   `submitting`. So the three `enabled: !submitting` flags on the fields, the
   `isEnabled: !submitting` on the CTA, and the `if (state.status ==
   submitting) return;` re-entrancy guard in the cubit are all dead wiring. It
   took a dev-only seeded cubit to draw the state at all
   (password_security_screen.dart:107, password_security_cubit.dart:37).

3. The submit CTA is therefore ALWAYS enabled, including on a completely blank
   form. `isEnabled: !submitting` is the only gate and `submitting` cannot
   happen, so the first action available on a freshly opened screen is to
   submit nothing — which lands on `ChangePasswordValidation.empty` and the
   match/strength sentence about three fields the user never touched
   (password_security_screen.dart:225).

4. B-33's "not available yet" notice leaves NO persistent trace.
   `passwordChangeUnavailable` is fired only from `listenWhen` as a transient
   snackbar, and the `unavailable` branch of `submit` also CLEARS `validation`
   — so the state a valid submit leaves behind renders as a pristine idle form.
   Rotate the device, rebuild, or let the snackbar time out and nothing on the
   surface says the password was not changed. The preview for this state is
   pixel-identical to the idle preview (password_security_screen.dart:99-103,
   password_security_cubit.dart:52-55).

5. The current-password field can never be unmasked. The screen honours
   `state.currentObscured`, and `PasswordSecurityCubit.toggleCurrentObscured()`
   exists — but it has ZERO callers anywhere under `lib/`, and
   `password_current_field` is the only one of the three fields built without a
   `suffixIcon`. Two eye buttons are drawn for three maskable fields
   (password_security_screen.dart:127-137 vs 151-162/179-190,
   password_security_cubit.dart:14-15).

6. A user who already HAS a password is offered "Set a password". `hasPassword:
   true` renders the change form and `password_set_entry` together; the source
   comment calls it a "re-link affordance", but the copy is
   `passwordSetEntryCta` = "Set a password" / "تعيين كلمة مرور", sitting
   directly under a form for changing the password they already have. It is the
   same button the social-only variant shows, differing only in
   `OmdsButtonVariant` (password_security_screen.dart:232-249).

7. The strength floor is never stated, before or after it is failed.
   `ChangePasswordPolicy` requires 8 characters with at least one letter and
   one digit; no helper text under any field says so, and the error copy only
   says "meet the strength requirements". The render test asserts that no text
   on the screen contains "8".

8. The current-password field is the least specific of the three. It borrows
   `loginPasswordLabel` / `loginPasswordHint` ("Password" / "Your password")
   from the login screen, placed immediately above "New password" and "Confirm
   password" — so the field asking for the OLD password is labelled with the
   most generic word on the surface (password_security_screen.dart:129-130).

## ProhibitedItemReportScreen

1. Body overflows the moment the keyboard is up. The Scaffold body is a non-
   scrolling Column with a Spacer() and no SingleChildScrollView; with
   resizeToAvoidBottomInset (default true) a 216 pt iOS keyboard on a 320x568
   phone leaves the column 84 px short — 'A RenderFlex overflowed by 84 pixels
   on the bottom', measured with the real Inter/Noto faces, in BOTH locales.
   This is the state the jeeber is in for the entire time the screen matters,
   since typing the description is its only purpose.
   prohibitedItemReportScreenKeyboardOpen is deliberately excluded from the
   shared render suite and asserted in its own group.

2. The same column overflows by 104 px at 200% text on 320x568 with no keyboard
   at all (measured with real fonts). Visible as the 200% card of the `Longest
   · compact 320` matrix preview. The 390x844 phone survives 200%; the
   accessibility ceiling is only breached on the small phone.

3. The destructive CTA's gate does not trim: `isEnabled:
   _descriptionController.text.isNotEmpty`. A description of three spaces arms
   'Report Item' at full error-red, on a card that is otherwise pixel-for-pixel
   the empty state. prohibitedItemReportScreenWhitespaceOnly renders exactly
   that and the test pins it.

4. Not one string on the screen is localized. 'Report Prohibited Item',
   'Describe the prohibited item', 'Attach Photo', 'Report Item' and the
   warning sentence are Dart literals; the file does not import
   AppLocalizations at all. The AR rendering mirrors the layout correctly and
   translates nothing — asserted in the test by pumping the Arabic preview and
   finding all five English strings present under TextDirection.rtl.

5. The typed description is thrown away. 'Report Item' calls
   `Navigator.of(context).pop(true)` — a bool, not the text — and `requestId`
   is never read anywhere in `build`. Nothing on this screen touches
   ProhibitedItemReportService.report (whose body is empty `async` anyway), so
   the form collects a prohibited-item report and discards it.

6. The screen is unreachable in the shipping app. `ProhibitedItemReportScreen(`
   is constructed in exactly two places in lib/: the Screen Catalog entry and
   this new preview section. No GoRoute in app_router.dart builds it, and
   JeeberRequestDetailScreen — which is handed the ProhibitedItemReportService
   — has no affordance that navigates here.

7. 'Attach Photo' is wired to `onTap: () {}`. It is fully styled, always
   enabled, and does nothing; every preview card shows it as a live affordance.

8. No SafeArea around the body, so the destructive CTA is painted into the
   home-indicator strip. On the 393x852 notched window the Report Item button
   occupies y 788..836 while the 34 pt indicator owns y >= 818. Scaffold drops
   the TOP padding for a body under an appBar but not the bottom one, and the
   Spacer() pushes the button to the last 48 pt of the window.

9. OmdsTextField(maxLines: 4) caps the box at a fixed 120 pt and scrolls
   internally with no scrollbar and no 'there is more' affordance. The
   343-character fixture is reviewable four lines at a time — the jeeber who
   wrote the most detail is the one who can least re-read it before tapping an
   irreversible red button.

## RequestTypeScreen

1. `onTierSelected` and `onContinue` are DEAD constructor parameters. Both are
   declared on `RequestTypeScreen` but `build` forwards only `cubit`,
   `repository` and `onChangeLocation` to `_Scaffold`, so neither can ever
   fire. `app_router.dart:1105` still passes both, wired to
   `context.push('/request-summary', extra: RequestDraft(...))` — a route the
   screen has not used since JM-024 re-pointed the flow — while
   `_ContinueFooter._onContinue` self-navigates to `client-location`. A caller
   reading the constructor would reasonably believe they own the Continue edge.
   Pinned: the preview host passes both callbacks and the render test taps a
   tier, presses Continue, watches the navigation happen, and asserts
   `requestTypeScreenSeamCalls` is still empty.

2. Everything the gateway says about a tier except its `id` is discarded at the
   card. `_RequestTierCopy.of(l10n, tier.id)` keys the title, speed and value
   lines on the id alone, so `priceLow`, `priceHigh`, `currency`, `slaMinutes`,
   `vehicleClass`, `recommended` and `serverId` are parsed by
   `DioTierRepository`, carried through `TierSelectionCubit`, and dropped. The
   'value' line a customer reads as a price cue ('Highest price • Priority
   pickup') is static ARB copy. `requestTypeScreenRepricedCatalogue` prices
   Flash at 99–125 USD with a 5-minute SLA on a van and renders byte-identical
   cards to the 120–160k LBP catalogue; the test asserts the two copy lists are
   equal and that none of the fixture's numbers reach a card.

3. `_Body` never reads `state.failure`: both `TierLoadFailure.network` and
   `TierLoadFailure.server` render `l10n.requestSummaryErrorNetwork` —
   "Couldn't reach Jeeb. Check your connection and try again." So a 5xx, or a
   response body `DioTierRepository._parseResponse` cannot recognise, tells the
   customer to check a connection that is working and to press a retry that
   will fail the same way. The string is also borrowed from the request_summary
   feature, so it names a submit problem on a screen that has not submitted
   anything. Pinned: `requestTypeScreenErrorNetwork` and
   `requestTypeScreenErrorServer` render an identical set of strings.

4. An empty tier catalogue is a silent dead end. A `200 OK` with no tiers is
   `TierSelectionStatus.loaded`, so the screen renders 'Choose your request'
   over nothing, the Location row under the hole, and a Continue button that
   can never enable — no message, no retry, no way forward, and nothing on the
   error path fires. It is reachable through the SUCCESS path without any
   outage: `DioTierRepository._tierIdFromLabel` silently drops every tier whose
   `name` this client cannot map, so a server-side rename empties the screen
   one tier at a time. Pinned by `requestTypeScreenEmptyCatalogue`.

5. The `bottomNavigationBar` is ABSENT rather than disabled on every non-loaded
   status: `_ContinueFooter` returns `SizedBox.shrink()` unless `status ==
   loaded`. The page therefore has no footer at all during the first read and
   on failure, then grows one when the read lands — and on the error state the
   in-body retry is the only control on the screen.

6. The `cubit:` seam does not drive itself. `build` mounts a provided cubit
   through `BlocProvider.value` and never calls `load()` on it, while
   `TierSelectionCubit.selectTier` returns early unless `status == loaded`. A
   caller who hands over a freshly constructed cubit gets a screen pinned on
   the spinner forever with no way to select anything; the Screen Catalog
   fixture only works because it chains `selectTier` onto its own `load()`.

## ReviewsListScreen

1. A null `averageScore` renders the D59 cold-start header regardless of review
   count. `_AggregateHeader` branches on `state.coldStart || state.averageScore
   == null`, and the two fields are independent on the wire
   (`ReviewsPage.coldStart` and `ReviewsPage.averageScore`; `ReviewsCubit.load`
   copies both through verbatim). A jeeber with 42 completed ratings whose
   score is missing from the response is told he is New and that his score
   'appears after a few completed deliveries'. Previewed as
   `reviewsListScreenScoreWithheld`; pinned by the test 'a NULL score renders
   "New Jeeber" over 42 ratings'.

2. The session-resolving surface has no app bar and therefore no back button.
   Opened with no `jeeberId`, `build` returns `const Scaffold(body:
   Center(child: OmdsLoadingState()))` while `AuthTokenStore.userId` is in
   flight — no title, no chrome, no way off the screen but the system gesture.
   The read is FlutterSecureStorage (a keychain unlock on a cold start after
   reboot), so it is not a single-frame flash, and `ReviewsStatus.loading` one
   frame later is a completely different surface (app bar + six skeletons).
   Previewed as `reviewsListScreenResolvingSession`.

3. An unresolved session id degrades to an EMPTY id rather than an error. The
   same branch ends in `_buildFor((snapshot.data ?? '').trim())`, so a signed-
   out or token-less user builds a `ReviewsCubit` on `jeeberId: ''` and issues
   a real read for nobody; what the user sees is whatever the gateway answers
   for an empty path segment, funnelled into the generic 'Could not load
   reviews.'. The screen never distinguishes 'you are not signed in' from 'the
   server is down'. Not previewable as a still frame (it depends on the live
   response), which is why it is written into the section prose.

4. The error state's Retry is silent. `_ErrorBody.onRetry` calls
   `ReviewsCubit.refresh()`, which — unlike `load()` — never emits an
   intermediate loading state; it only emits on completion. The error surface
   stays unchanged for the whole round trip, so a slow retry is
   indistinguishable from a dead button and a user who taps twice has fired two
   reads.

5. The error branch is the only body outside the `RefreshIndicator`.
   `RefreshIndicator` wraps only the `ReviewsStatus.loaded` case, so the empty
   state can be pulled to retry and the failure state cannot — its only
   recovery affordance is the silent button above. Pinned by the test 'the
   failure body is an error with a retry — and NO pull gesture behind it'.

6. `_LoadingSkeletons` takes a `ReviewsL10n copy` it never reads — the
   parameter is dead — and draws a hardcoded SIX rows regardless of the 20-item
   `pageSize` the cubit requests. The placeholder is also structurally unlike
   what replaces it (a one-line `OmdsListItemShimmer` vs a 194 dp name + card +
   CTA row), so the list jumps on first paint.

7. Nothing on a review row clamps, and on the compact frame the list pays for
   it. Neither the attribution nor the comment sets `maxLines`, so a long
   review grows instead of ellipsizing: measured through the real Inter/Noto
   faces at 320x568, the ceiling review is 341 dp of the 464 dp of list area,
   and the next review starts at 446 and is cut by the fold at 568 — its stars,
   comment and Report button all below it. Nothing errors (the list scrolls);
   one angry review is simply the entire first screen of a jeeber's reviews.

8. The aggregate score line cannot shrink. It is a bare `Text` in a `Row` after
   a fixed-size star, with no `Flexible` and no `maxLines`. Measured at 200%
   text on 320 pt with real fonts: '3.9 · 128 reviews' wants 228.1 dp of the
   264.0 the padded Row can give it, Arabic '3.9 · 128 تقييمات' wants 214.1 —
   it clears today by virtue of the copy, not of the layout, and a five-digit
   review count or a longer localization would overflow rather than ellipsize.

9. `_EmptyBody` offsets the empty state by `MediaQuery.of(context).size.height
   * 0.18` — a fraction of the WINDOW, not of the body it sits in. It reads as
   centred on a phone and drifts on anything with different chrome (split
   screen, a taller app bar, a future banner above the list).

## ShellScreen

1. Bottom bar cannot ellipsize: _JeebBottomBar lays its five _BarItems out in a
   bare Row (spaceAround, no Expanded/Flexible) and _BarItem's label is a Text
   with no maxLines and no overflow, so the row demands the labels' intrinsic
   width and can only overflow. Measured with real fonts: 238.9 dp (EN) / 171.1
   dp (AR) at 100%, scaling linearly. First break in ENGLISH at 150% on a 320
   dp device (354.3 dp, 34 dp over) and at 175% on a 390 dp phone (412.0 dp, 22
   dp over); at 200% EN it is 469.7 dp — 149.7 dp over a 320 dp device. 150% is
   reachable from Android 'Largest' / iOS accessibility sizes, so this is a
   shipping configuration, not a ceiling.

2. Bottom bar height is a constant: _JeebBottomBar pins its row to
   SizedBox(height: Sizes.fiveXLarge) = 56 dp whatever the text scale, while
   _BarItem's Column is a 24 dp icon + gap + a label that does scale. At 200%
   text EVERY one of the five destinations reports 'RenderFlex overflowed by
   2.0 pixels on the bottom' (3.0 for one Arabic label) — five identical errors
   per frame, in BOTH locales and on BOTH devices.

3. The tighter locale in this bar is ENGLISH, not Arabic — inverting the
   assumption most Jeeb layout work is written against. All five Arabic labels
   total 171.1 dp against English's 238.9 (لوحة التحكم is 48.3 dp where
   Dashboard is 59.2), so Arabic still fits a 390 dp phone at 200% while
   English does not.

4. ShellScreen has no initialIndex seam: _selectedIndex is private state and
   every entry point opens on whatever _landingIndex returns. The IndexedStack
   BUILDS all five tab bodies, but the Delivery, Earnings and Profile surfaces
   are only reachable by tapping — so neither a preview nor a Screen Catalog
   state can open on them, and the ordersRepository seam the catalog added can
   never be seen in its own designed state without a scripted tap.

5. _CustomerProfileTabBody hardcodes `CustomerProfileScreen(data:
   CustomerProfileViewData())` with no data and no repository seam. With no Dio
   in the graph the cubit's load() is a no-op, so the Profile destination is
   permanently the empty default — blank name, '?' avatar, 'No reviews yet' —
   and, because showRegister is `!data.isJeeber` on that empty seed, it offers
   'Register as a delivery' to the very user the shell has just routed to the
   jeeber Dashboard beside it. Two adjacent destinations disagree about whether
   the user is a jeeber.

6. The jeeber branch is not previewable through a constructor: DashboardTab
   resolves sl<AvailabilityGateway>() and sl<RequestFeedRepository>()
   unconditionally with no override seam (which is why batch_11_entries.dart
   skipped it in the catalog). The preview reaches it only by registering the
   in-memory implementations this repo already ships for its own widget tests.
   A `repository:`/`cubit:` seam on DashboardTab, matching the one OrdersTab
   and HomeTab already have, would remove the DI dance from both dev surfaces.
