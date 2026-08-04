# Screens wave 09 (pending offers, feed, kyc, language, live tracking)

7/7 written, 56 previews, 0 agent errors. Measured with real fonts.

## F01

JeeberPendingOffersScreen: Empty, error and loading bodies are top-aligned, not centred. `OmdsEmptyState`/`OmdsErrorState`/`OmdsLoadingState` are each a `mainAxisSize.min` Column handed straight to `Scaffold.body`, and Scaffold lays its body out under LOOSE constraints at the content origin. Measured on a 390x600 frame: the empty state occupies y 56..304 (centring would be 204..452), and the cold-load spinner is an 88x88 box in the TOP-LEFT corner. omds ships `OmdsEmptyStatePage`/`OmdsErrorStatePage`, which wrap in `Center`; this screen uses the un-paged variants. lib/features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart:139-155

## F02

JeeberPendingOffersScreen: The cold-load failure renders the wrong sentence: `l10n.offerSubmissionErrorGeneric` = "Something went wrong sending your offer. Please try again." Nothing is being sent — the read of `GET /v1/offers?jeeberId=` failed — so a jeeber whose list will not load is told the bid they placed a minute ago failed to submit. jeeber_pending_offers_screen.dart:145

## F03

JeeberPendingOffersScreen: `SubmittedOffer.note` is carried on the model, populated by the offer-submission flow and by the catalog fixture ('Can drop off at the lobby'), and rendered by nothing. `PendingOfferRow` draws price, ETA, status and Withdraw and never reads it, so the note a jeeber typed is not shown back to them on this surface. Pinned by the test 'an offer note reaches no pixel of the list'.

## F04

JeeberPendingOffersScreen: At 200% text the price is the only element that yields, and the app-bar title goes with it. `_PriceEtaRow` gives the price an `Expanded` and the ETA a bare `Text` with no `Flexible`, so the ETA takes its full intrinsic width first. Measured through the real Inter/Noto faces on the 320 pt frame: the price wants 199.9 dp and is given 166.8 (EN), wants 208.3 and is given 159.3 (AR) — ellipsized in both — and 'Pending offers' in the OMDSAppBar is clipped from 230.3 to 216.0. At 1x the same price wants 100.8 of the 219.4 it gets, so nothing is visible until text is scaled.

## F05

JeeberPendingOffersScreen: A list that mixes open and terminal offers has two row heights 52 dp apart with no grouping or separator to explain the change in rhythm (measured at 390 pt: terminal 89 dp, open 141 dp; 129 vs 181 at 200% text). Terminal rows lose both the awaiting label and the 48 dp Withdraw pill.

## F06

JeeberPendingOffersScreen: The list body is a bare `ListView.builder` under an app bar: no count, no section header, no summary of the wallet reserve these open offers hold (D1), and no bottom affordance. With six pending offers the only way to learn how many are outstanding is to scroll to the end.

## F07

JeeberPendingOffersScreen: `pending_offers_back` is the screen's only navigation affordance and it resolves a GoRouter (`context.canPop()`), so it throws in any host that has no Router above it — including both dev surfaces (preview canvas and Screen Catalog). Combined with the ORPHAN note at the top of the file (no in-app nav callsite, reachable only via a degenerate push-notification fallback), the back edge is the least-exercised path on the screen.

## F08

JeeberPendingOffersScreen: Two placeholder ARB strings are user-visible on this surface, both flagged as deliberate in `PendingOfferRow`'s own comments but shipping: the awaiting label renders `jeeberFeedStatusPending` -> "Pending" rather than "Awaiting customer decision", and a lost offer renders `requestFeedActionDeclinedSnack` -> "Request declined" (AR "تم رفض الطلب"), a snackbar string about a jeeber declining a *request*, shown to a jeeber whose *offer* the customer did not pick.

## F09

RequestFeedScreen: `_FeedListRow` never reads `DeliveryRequest.feedStatus` or `nextDeliveryAction`, so the three lifecycle buckets the Screen Catalog names as separate designed states (`Incoming — Ignore / Offer card`, `Pending response — awaiting client reply`, `Accepted — delivery-action cards`, after Figma screens 24/25/26) render as the SAME Decline/Accept card. A jeeber cannot tell an auction they can bid on from one they have already bid on from one they have already won, and the accepted row still offers two live Accept/Decline buttons for a request whose auction is over. Pinned by `test/previews/jeeber_request_feed/request_feed_screen_preview_test.dart` → 'incoming, pending and accepted rows are the SAME card'.

## F10

RequestFeedScreen: A refresh that fails while rows are already on screen is completely silent. `RequestFeedCubit._refresh` catches, keeps `status: ready` (the feed is non-empty) and records `errorMessageKey: 'requestFeedErrorLoad'` — a field NOTHING in `request_feed_screen.dart` reads. The result is byte-identical to a healthy feed: no banner, no snackbar, no stale-data mark, no retry. Stale rows are presented as current, and tapping Accept is the only way to find out. Pinned by 'a refresh failure over rows shows NO error surface'.

## F11

RequestFeedScreen: `RequestFeedState.errorMessageKey` is dead on this screen in the other direction too: `_FeedBody` hardcodes `l10n.requestFeedErrorLoad` for the full-screen error body instead of resolving the key the cubit emitted, so a second failure mode added to the cubit would silently render as a connectivity error.

## F12

RequestFeedScreen: The countdown badge renders raw seconds — `requestFeedExpiresIn` is `"Expires in {seconds}s"` with no mm:ss formatting. Production's ~5-minute offer window reads "Expires in 287s"; the catalog's own dev fixture (`DevJeeberFeedFixtures`, `expiresAt = now + 365 days`) makes it an eight-digit number on the designer-facing surface.

## F13

RequestFeedScreen: The loading body is `Center(child: OmdsLoadingState())` with no message — the only state on this screen with zero text of its own in either locale. On a slow connection it is a blank area under an app bar reading 'Incoming requests', indistinguishable from a hang, and it is unreachable from the Screen Catalog (every catalog state drives a real `start()` over a synchronous fixture repository, so the loading frame is over before first paint).

## F14

RequestFeedScreen: `_RequestFeedViewState` arms `Timer.periodic(const Duration(seconds: 1))` unconditionally in `initState` and calls `setState` on every tick, even when no request in the feed carries an `expiresAt` (a documented gateway shape — `null` means 'no countdown applies'). That is a full rebuild of the feed once a second for a screen with nothing to count down.

## F15

RequestFeedScreen: `RequestFeedState.expiredIds` / `isExpired` are never consulted by the screen. The expired look comes only from `_FeedListRow._secondsLeft()` clamping to 0 against the device clock, so the cubit's G3 expired-linger mark and the card's disabled state are two independent derivations of the same fact.

## F16

RequestFeedScreen: `RequestCard` drops most of what the feed model carries: `senderName`, `senderAvatarUrl`, `senderRating`, `itemsSummary`, `distanceFromYouKm` and `receivedAt` are all supplied by the catalog fixture (they are the Figma screen-24 content) and none of them reach the screen — it renders pickup, dropoff, distance and earnings only.

## F17

KycWizardScreen: /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile/.claude/worktrees/widget-previews-pilot/lib/features/kyc/presentation/kyc_wizard_screen.dart — the schema-load ERROR view is unreachable in the running app. `_SchemaErrorView` (the localized failure line plus `kyc_wizard_retry_cta`, the ONLY retry affordance in the feature) renders while `state.error == KycWizardError.schemaLoadFailed`, but `_WizardScaffold` also mounts a `BlocListener` on `error` whose `_surfaceError` raises a snackbar and then calls `cubit.acknowledgeError()` UNCONDITIONALLY, clearing the flag in the same turn. `_SchemaLoadingView` then falls back to `Center(child: OmdsLoadingState())`, so a jeeber whose `GET /v1/kyc/jeeb/form-schema` fails gets a transient toast and then an indefinite spinner with nothing to tap. Held as an assertion in the render test ('a schema load that fails IN-APP never renders the retry'). Same root cause makes EVERY error on this screen toast-only, including `submitValidationFailed`.

## F18

KycWizardScreen: /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile/.claude/worktrees/widget-previews-pilot/lib/features/kyc/presentation/kyc_wizard_screen.dart — the four bodies of one route disagree about scrolling. `_buildBody` returns a `SingleChildScrollView`-backed identity step but an unscrollable `KycStatusView` (`_StatusScaffold` is a bare `Column` + `Spacer`). Measured with the real font faces on a 320x568 phone at 200% text, the SHORTEST status body (approved) overflows by 144 dp in EN and lays `kyc_status_topup_cta` out at y=692 — off a 568 dp screen with nothing to scroll it back — while the identity route survives the same box and scale cleanly. Every other `_StatusScaffold` variant (pending, rejected, resubmit-requested) is taller than the one measured.

## F19

KycWizardScreen: /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile/.claude/worktrees/widget-previews-pilot/lib/features/kyc/presentation/kyc_wizard_screen.dart — `_ProgressHeader` reports progress that does not exist, in both directions. `displayStep` floors at 1, so a wholly empty form (nothing captured, nothing typed, ToS unticked) already reads 'Step 1 of 2'; and `KycWizardState.completedCaptureSteps` counts PHOTOS only, so a form with both ID sides and the selfie captured reads 'Step 2 of 2' while `kyc_submit_cta` is still dead because `id_number` is blank or invalid (the JEBV4-295/E3 hard gate). Three captures also collapse into two ticks, and the `OMDSLabeledStepperProgress` labels ('ID', 'Selfie') are static with no tap target.

## F20

KycWizardScreen: /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile/.claude/worktrees/widget-previews-pilot/lib/features/kyc/presentation/kyc_wizard_screen.dart — `_WizardScaffold._buildBody` builds `const KycStatusView()` and forwards no `pollSchedule`, even though `KycStatusView` takes one as an injectable constructor parameter (`KycPollSchedule.standard` is only its default). The route therefore has no way to reach any schedule but the production 3 s / 15-minute one, which means a pending decision holds a live `Timer` at essentially all times and the only settled frames are 'a probe is in flight' or 'the 15-minute budget is spent'. The preview has to run a frame clock past the 3 s grace to reach a still frame at all; forwarding the parameter (as `KycStatusView` already anticipates) would remove that.

## F21

KycRejectedScreen: Every structured rejection reason instructs an action this screen deliberately does not offer. The body says "This decision is final" (D52/D87, no resubmit CTA) while the notice under it says "Please review your details and resubmit." (other), "Retake the selfie in better lighting." (selfieMismatch) or "Submit a current document." (expired) — the copy is lifted verbatim from KycStatusView's rejected branch where resubmit WAS reachable. Worse, test/decision_violations_test.dart enforces D52 with expect(find.textContaining('resubmit'), findsNothing) and passes only by fixture accident: it builds a bare FakeKycGateway() whose stored submission is notSubmitted, so no reason ever renders. The Screen Catalog's own 'Reason — other/generic' state renders text containing 'resubmit' — pinned as a KNOWN test.

## F22

KycRejectedScreen: Four different upstream outcomes collapse to one picture. _RejectionReasonSection returns SizedBox.shrink() whenever state.rejectionReason == null, and no widget reads state.status at all, so a failed GET /v1/kyc/status, a fetch still in flight, and a rejection with no structured cause paint byte-identical surfaces — no spinner, no error banner, no retry, no diagnostic. Asserted by comparing the full painted-Text list across the three states (with a with-reason control to prove the comparison isn't vacuous).

## F23

KycRejectedScreen: KycRejectedState.submittedAt is fetched off the status response and stored on state on every load, and no widget in the screen file reads it. The user is never told WHEN the decision landed — the one fact that would tell them whether an appeal is still worth filing.

## F24

KycRejectedScreen: A KycStatus.resubmitRequested submission is rendered as FINAL. KycRejectedCubit.load() passes clearRejectionReason: submission.status != KycStatus.rejected, so the tri-state third path (E19/Q-040/SM-6 — actionable, fix-and-resend, mandatory reason, resubmitSteps attached) loses its cause and its per-slot instructions and shows the appeal-only dead end. The route is only supposed to be reached on a rejected decision, so this is defence-in-depth rather than a live bug, but the degrade turns an actionable state into a terminal one.

## F25

KycRejectedScreen: On a 320x568 device at 150% text or above (measured with real Inter/Noto fonts, EN and AR), kyc_rejected_appeal_cta and kyc_rejected_back_cta are absent from the element tree until the user scrolls — the ListView body does not build past the fold. Nothing is lost for a user, but docs/build-out/65_W2_TEST_PLAN.md §2 JM-043 asserts those two ids alongside the kyc_rejected_resubmit_cta assertNotVisible check, so that scenario is device- and text-scale-dependent: green on a 390 pt phone, red on a compact one, with no change to the screen.

## F26

LanguageSettingsScreen: Unselected language row renders a DISCLOSURE CHEVRON. `_LanguageRow` passes `trailing: selected ? const Icon(Icons.check) : null`, and `OmdsSettingsRow` falls back to its default `icon: Icons.chevron_right` when `trailing` is null. So the unselected member of a group the code itself declares `inMutuallyExclusiveGroup: true` carries the same 'tap to navigate somewhere' affordance as every ordinary settings row. It mirrors correctly in AR (chevron_right is matchTextDirection: true), which only makes it a more convincing disclosure arrow. `SettingsScreen._LanguageRow` is the same code with the same rendering. Pinned by the 'renders a DISCLOSURE CHEVRON, not an empty slot' test.

## F27

LanguageSettingsScreen: No 'follow system language' affordance, and picking a language is ONE-WAY. `LocaleCubit.resetToDeviceLocale()` clears the persisted key and returns to the device locale; nothing on this screen — or on `SettingsScreen`, the other host of these rows — calls it. Before the first tap the app follows the device; after it, the choice is persisted and a user cannot get back to device-follow from the UI at all. Pinned as `findsNWidgets(2)` rows.

## F28

LanguageSettingsScreen: Cold start is INDISTINGUISHABLE from an explicit English choice. A first launch on an unsupported device locale (nothing persisted, `de` reported) falls through `_resolveInitial` to the hard `en` default, and the screen tells that user English is 'selected' when they have selected nothing. `languageSettingsScreenColdStart` and `languageSettingsScreenEnglishSaved` are pixel-identical below the dev caption.

## F29

LanguageSettingsScreen: Selecting a language is fire-and-forget: no in-flight, no success, no failure state anywhere. `setLocale` emits, awaits `prefs.setString`, then mirrors the choice to the remote user-preferences store via `_pushRemote`, which swallows every failure by design (offline-first). The screen renders nothing for any of it, so a user whose language never reached the server sees exactly what a user whose language did sees. This is why the preview set has no loading and no error card — those states exist in the cubit and have no rendering.

## F30

LanguageSettingsScreen: 'Language' is painted TWICE, 24 pt apart. The `OMDSAppBar` title and the only `OmdsSettingsSection` header are both `l10n.settingsLanguage`, so on a two-row screen a third of the visible copy is the same word repeated. `SettingsScreen` hosts the same section under an app bar reading 'Settings', so the duplication is specific to the standalone `/settings/language` route. Pinned as `findsNWidgets(2)` in both locales.

## F31

LanguageSettingsScreen: At 200% text the section header becomes LARGER than the screen's own app-bar title. `AppBar` wraps its title in `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.34)`, so `OMDSAppBar`'s 24 pt headlineSmall stops growing at ~1.34x (measured 32.0 pt -> 43.0 pt) while the `OmdsSettingsSection` header directly below it — the same word — scales the whole way to 2x. Measured on 320x568 with the real Inter/Noto faces: the bar title is the taller of the two at 100% and the shorter at 200%. Nothing overflows and nothing wraps; the type hierarchy simply inverts.

## F32

LanguageSettingsScreen: The back control is duplicated and both halves are live. `Semantics(identifier: 'language_back', button: true, onTap: <guarded pop>)` wraps an `ExcludeSemantics(IconButton(onPressed: <the same guarded pop, written out a second time>))`. Two independent copies of the `context.canPop() ? context.pop() : context.go('/')` decision that have to be kept in sync by hand.

## F33

LiveTrackingScreen: `LiveTrackingCubit._detectEvent` reads `prev = state.trackingInfo?.currentStage`, which is null on the FIRST read of every screen entry — so an already-in-transit delivery satisfies `prev != next` and returns `jeeberOnTheWay`. The customer gets the "Jeeber is on the way!" snackbar on EVERY open of tracking, not on the transition. The `delivered` arm one line above carries the `prev != TrackingStage.delivered` guard this arm is missing (live_tracking_cubit.dart:558-573).

## F34

LiveTrackingScreen: The error body is hard-coded ENGLISH. `LiveTrackingCubit._mapError` / `_mapErrorTitle` return string literals ('Delivery not found', 'Unable to connect. Check your internet.', "We can't find this delivery yet…") which `_TrackingErrorBody` renders verbatim, while everything around them (retry label, app-bar title, icon) IS localized. Pinned by a render test in `ar`.

## F35

LiveTrackingScreen: The DELIVERED state cannot be rendered on this screen at all: `_onEvent` answers `deliveredAutoAdvance` with `context.goNamed('delivered-receipt')`, so the 4-step stepper this screen advertises (D70) has a fourth step no customer ever sees lit here — and no preview of it can be written (with no GoRouter the listener throws instead of rendering).

## F36

LiveTrackingScreen: All three terminal/side bodies take NO arguments and drop `info` on the floor: `_TrackingCancelledBody`, `_TrackingExpiredBody`, `_TrackingUnderReviewBody`. The moment a row goes cancelled/expired/under-review the customer is told 'this delivery was cancelled' with nothing on screen naming the order, the item, the price or the Jeeber — while the row carrying all of it is sitting in `state.trackingInfo` two frames up.

## F37

LiveTrackingScreen: The ordinary active layout does NOT fit the narrowest supported viewport. `_TrackingBody` is a `Column` with exactly one `Expanded` (the map) and there is no scroll view anywhere on the screen, so at 320x568 the six fixed blocks overflow rather than scroll: measured through the real Inter/Noto faces, 152 pt in English and 145 pt in Arabic, on the everyday picked-up row (not a longest-content one). The same fixture at 390x844 is clean, so this is a viewport ceiling.

## F38

LiveTrackingScreen: Same cause at the accessibility ceiling: at `TextScaler.linear(2)` on a full 390x844 phone the body reports 262 pt of vertical overflow plus a 1 pt horizontal one. Nothing scrolls, so there is no degradation path.

## F39

LiveTrackingScreen: `hasSummary` (pinned header) and `info.jeeber` (courier card) are independent, and the shipped in-transit row diverges: `DemoLiveTrackingRepository`/the catalog's `In transit` state sets `jeeberName: 'Kamal Hajj'` with `jeeber: null`, so the header names a courier on the same frame that has no courier card under the map.

## F40

LocationPickerScreen: /location serves a dead end. `app_router.dart:76` imports THIS 36-line placeholder and mounts it at `/location` (`name: 'location-picker'`, app_router.dart:968-970), while the 461-line working picker in `lib/features/location/presentation/location_picker_screen.dart` is imported by exactly one file in the repo — the Screen Catalog. The designer-facing surface renders a working Location Picker; the app renders 'coming soon'.

## F41

LocationPickerScreen: The dead end has no exit affordance, and it is live. `appBar: null` means no app bar and therefore no back arrow, and `OmdsEmptyStatePage` is given no `buttonText`/`onButtonTap`, so there is no action either. `locationPickerScreenPlaceholderDeadEnd` pushes it onto a poppable route and the render test asserts `NavigatorState.canPop() == true` with `find.byType(BackButton)` finding nothing — the only exit is a system gesture. The byte-identical placeholder on `SavedAddressesScreen` gets away with this because no route serves it; this one is routed.

## F42

LocationPickerScreen: The copy is hardcoded English. `title`, `subtitle` and the `Semantics.label` are string literals, though `app_en.arb`/`app_ar.arb` ship 30+ `location*` keys (`locationPickerTitle` = 'Choose location') and the 461-line sibling uses them throughout. Pumped under `Locale('ar')` the frame is `TextDirection.rtl` and the words are still English — pinned in the render test so the AR half of `testPreviewsRender` cannot pass for the weaker reason that an unlocalized screen always builds.

## F43

LocationPickerScreen: A screen reader hears the copy twice. `Semantics(container: true, label: 'Location Picker coming soon. This screen is not yet available.')` wraps a subtree that already publishes both sentences and nothing excludes it, so the merged node's label is `'<label>\n<title>\n<subtitle>'` — one node, each sentence announced twice, no children, no `SemanticsAction.tap`, nothing to move focus to next. `find.bySemanticsLabel` on the literal finds NOTHING, which reads as 'no label' when the truth is three labels glued together.

## F44

LocationPickerScreen: The narrow device — not the short one — is the layout ceiling, and the margin is 36 pt. Measured with the real Inter face: the unclamped headline (`OmdsEmptyState` passes it no `maxLines`, no `overflow`) wants 331 pt, so it stays on one line at 390 pt and wraps to two at 320 pt; at 200% text it wants 662 pt and wraps to FOUR lines, taking the centred non-scrolling Column to 532 pt of a 568 pt viewport. There is no `SingleChildScrollView` anywhere in `OmdsEmptyStatePage`, so a word added to either string clips with nothing to scroll to. The intuitive candidate, the 844x390 landscape box, has 90 pt to spare at 200%.

