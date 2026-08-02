# Screens wave 04 (jeeber_request_detail, location, offer_kyc_gate, rating) — defects

7/7 written, 53 previews.

## F01

JeeberRequestDetailScreen: Empty pickup label renders as a labelled row with a blank value. `_RequestSummaryRows` trim-guards `description` (the whole row disappears when blank) but renders `request.shortLabel` unguarded. An empty shortLabel is not malformed data: `DioRequestFeedRepository._parseRequest` deliberately degrades a feed item with an unusable `pickup` into `RequestLocation(label: '')` rather than dropping it ('a second cause of the empty feed'), and `_parseFeedLocation` defaults the label to '' whenever an item has coordinates but no address — that string reaches `FeedRequest.shortLabel` via app_router.dart:1830 unchanged. Result: an icon badge and the word 'Pickup' over an empty line, which reads as a rendering fault rather than as missing data. Pinned by 'the description row is trim-guarded; the pickup row is not'.

## F02

JeeberRequestDetailScreen: `reportService` is required, resolved from GetIt (app_router.dart:1312), threaded through the loader into this screen — and never read. Neither `build` nor `_openOfferForm` touches it, and there is no prohibited-item affordance anywhere on the surface (exactly two CTAs, no icon buttons in the body). Every preview and catalog state has to construct one purely to compile.

## F03

JeeberRequestDetailScreen: The two CTAs use two different navigation idioms and only one is a declared seam. `Decline request` calls the injected `onDeclined`, but the PRIMARY action hardcodes `context.pushNamed('jeeber-offer-submission')`, which the screen's constructor never mentions — so no host (preview canvas, widget test, future embedding) can exercise the offer path without also mounting a GoRouter that owns that route name. In the preview canvas the primary CTA of this screen throws when clicked; the destructive one works first time. Pinned by 'the offer CTA is not a declared seam — it needs a GoRouter'.

## F04

JeeberRequestDetailScreen: Decline is destructive, immediate and unconfirmed: one tap fires `onDeclined(request.id)` (which the route wires to `back()`), with no confirmation sheet, no undo and no server round-trip. Pinned by 'Decline fires on the first tap, with nothing in between' (no Dialog, no BottomSheet in the tree).

## F05

JeeberRequestDetailScreen: On the 320 × 568 floor the ORDINARY request already overflows the summary viewport at default text. Fixed chrome takes 212 dp of 568 (56 dp app bar + a 156 dp action bar that is fixed by construction) leaving a 356 dp viewport for a 394 dp three-row card, so the request reference — the last row — starts below the fold with nothing on screen indicating there is more. Measured under flutter_test's square test font, so treat the dp as an upper bound; the structural point (a fixed 156 dp bar against a 568 dp display, 27% of it) is font-independent. On the 390 × 844 phone the same chrome is 293 dp of 844 (the bar sits above the 34 dp home indicator its SafeArea clears).

## F06

JeeberRequestDetailScreen: At 200% text nothing in the action bar scales: `OmdsPrimaryButton` pins `height: Sizes.fourXLarge`, so both touch targets and both label boxes stay at 48 dp for a user who asked for double-size text, while every row above them doubles. This is simultaneously what saves the layout (the `Expanded` summary absorbs the whole increase and scrolls — no overflow on either device, in either locale) and what caps the accessibility story. At the ceiling the description alone measures 2208 dp against a 551 dp viewport, i.e. the one thing the jeeber is being asked to price is four screenfuls of scrolling above two unscaled buttons.

## F07

JeeberRequestDetailScreen: The reference row shows two different KINDS of reference depending on the id it is given. `friendlyReference` shortens a gateway UUID to `#775EAE`, but passes `req-101` through verbatim (it matches the `REQ-` human-reference prefix, and not even case-normalised), so what a jeeber reads as 'the request reference' is not one format. The formatting rule lives in core, but this screen is where the inconsistency is visible. Pinned by 'a UUID is shortened but a `req-` id is passed through'.

## F08

JeeberRequestUnavailableScreen: At 200% text the CTA is laid out BELOW the display and nothing scrolls. `Scaffold > SafeArea > Center > Column` has no scroll view anywhere in the chain, so the surplus is off-screen rather than reachable by any gesture. Measured on the REFERENCE phone (390x844, EN): 96 px of RenderFlex overflow, 'Browse other requests' at y 904-952 against an edge at y 876. On 320x568: 684 px (EN) / 412 px (AR) overflow, CTA at y 1216 / y 944 against an edge at y 600. The sibling screen the same loader routes to survives the identical box because its summary scrolls and its action bar is pinned. Contributing cost: the title is rendered twice (OMDSAppBar + OmdsEmptyState.title, a contract the existing widget test pins) and the restatement alone measures 320 pt of the 788 pt body at 200%.

## F09

JeeberRequestUnavailableScreen: A cold push tap onto a dead request has NO back arrow to fall back on. `OMDSAppBar` is constructed without `showBackButton` — which defaults to FALSE (omds_app_bar.dart:12) — and passes `automaticallyImplyLeading: true` to Material's AppBar, so an arrow exists only when the enclosing route can be popped. A feed-row tap leaves a page underneath; a `context.go`-style / notification arrival on `/jeeber/requests/:id` does not. Measured: arrow present in the feed-tap states, absent in the stack-root states. Combined with the finding above, `Compact · 200% text` is a screen with ZERO reachable affordances — no arrow, and the only CTA 616 pt below the viewport, in both EN and AR.

## F10

JeeberRequestUnavailableScreen: At 200% text the CTA's own label is clipped inside its pill, independent of the overflow — it bites even where the button IS on screen (AR at 390x844, CTA at y 772-820). `OmdsPrimaryButton` hard-pins its height to `Sizes.fourXLarge` (48) and centres an unconstrained `Text`, so the label does not grow with the text scale. Measured via RenderParagraph: 'Browse other requests' needs 120 pt of intrinsic height at its laid-out width of 318 and is given exactly 48 — under half the label is visible. At 100% it needs 20 pt in the same 48, which is why this is invisible until someone raises the text size.

## F11

JeeberRequestUnavailableScreen: The router's blank-id fallback renders a malformed sentence. `app_router.dart:1284` is `state.pathParameters['id'] ?? ''` and the id is interpolated into `requestNoLongerAvailable` with no guard, so an absent id does not shorten the copy — it produces 'Request  is no longer available.' with a double space where the reference should be. There is no `{requestId}`-less ARB variant to fall back to. go_router will not match an empty path segment, so this is a defensive branch rather than one a jeeber can walk into today, but the `?? ''` is shipped code and the failure is invisible from every other state.

## F12

JeeberRequestUnavailableScreen: The raw 36-character UUID is printed in full: the screen hands its route id straight to the ARB while the resolved detail screen the same loader routes to shortens it to `#775EAE` (sprint-009 audit §T5, `friendlyReference`). Corroborates what `jeeber_request_detail_loader_preview_test.dart` already records from the loader side; recorded here because the interpolation is this screen's own copy, and in AR it is an LTR run dropped into an RTL sentence.

## F13

LocationPickerScreen: The production button Row does not fit a phone. With `mapPickerLauncher` supplied (the documented production wiring), the `Row` of two `Expanded` OmdsPrimaryButtons at location_picker_screen.dart:178 overflows horizontally at every phone width: 390x844 by 100pt and 29pt in EN, by 154pt and 168pt in AR; 320x568 by 135/64 (EN) and 189/203 (AR). Each button is icon + unclamped label + 16pt internal padding, and neither label has a TextOverflow. It is clean only because `flutter test` renders on an 800pt-wide surface, so no existing test can see it. Hiding the map button (launcher null) is clean at 390 but still overflows by 39pt at 320 in Arabic.

## F14

LocationPickerScreen: An error has NO persistent surface, and an error present at mount is invisible. `state.error` is consumed only by the BlocConsumer listener (a 4-second snackbar, then `acknowledgeError()`); nothing in `builder` renders it. Because `listenWhen` compares `prev.error != next.error`, a `LocationPickerCubit` handed to the screen with an error already set never fires the listener at all — and the `cubit:` seam is explicitly documented for hosts that already own the cubit lifecycle. Both error previews have to fire their failing call from a post-frame callback; built the obvious way they render a completely healthy screen.

## F15

LocationPickerScreen: `_searchController` is never seeded from the cubit's current state. `_LocationPickerViewState` syncs it only from the listener (line 117); there is no initial sync in `initState` or `build`. Mounting the view over a cubit that already holds a `searchQuery` — again, exactly what the `cubit:` seam is for — draws an EMPTY search field above a populated suggestion dropdown. Pinned by the 'a populated dropdown sits over an EMPTY search field' test.

## F16

LocationPickerScreen: `canConfirm` only requires a non-null draft, so a leg can be committed before its address resolves. `onPinDragged` sets `draftSelection` with `address: null` and reverse-geocodes in the background writing back to `draftSelection` only; `confirmAndContinue` commits whatever the draft holds at that instant. The committed `pickup`/`dropoff` then keeps `address: null` forever and `_PairRow` renders raw `lat, lng` via `locationCoordinatesFallback` — with no `textDirection`, so bidi reorders the two numbers under Arabic. Shown by `locationPickerScreenResolvingAddress`.

## F17

LocationPickerScreen: The suggestion dropdown is an inline Column child with only a `Spacer` to absorb it. `_ResultsList` is `shrinkWrap: true` + `NeverScrollableScrollPhysics`, so it takes the height its rows want and cannot give any back, and the screen's Column (line 155) has no other flexible child. Measured: five suggestions overflow the Column by 44pt on the 800x600 render surface and by 116pt on a 320x568 device; the longest-addresses state overflows 320x568 by 40pt.

## F18

LocationPickerScreen: Confirming the pickup pre-seeds the dropoff draft with the pickup pin AND leaves the CTA enabled, so a user who taps straight through saves a delivery whose two legs are the same address. Pinned by the 'the dropoff draft is pre-seeded with the pickup pin' test.

## F19

LocationPickerScreen: On the `done` step the CTA becomes a full-width, enabled primary button that does nothing. `_confirmCta` has no copy for `done`, so it repeats the app-bar title ('Locations confirmed' rendered twice), and `confirmAndContinue()` returns immediately on that step. Pinned by 'the terminal state repeats its own title on the CTA'.

## F20

LocationPickerScreen: The search bar has no `isSaving` input, so it stays fully live while a save is in flight. The CTA and the GPS button both go inert on `state.isSaving`, but tapping a suggestion mid-save runs `selectSearchResult` and moves `draftSelection` under a request already sent with the old pair — the user sees the new address in the draft card and the old pair gets persisted.

## F21

LocationPickerScreen: Tapping a suggestion leaves 'No matching addresses' directly under the address just chosen. `selectSearchResult` copies the address into `searchQuery` and empties `searchResults`, which is byte-for-byte the 'nothing matched' triple. Already documented at widget level in the `LocationSearchBar` preview section; this confirms it reaches the real screen, where the false empty-state card also occupies layout space above the draft card.

## F22

LocationPickerScreen: An in-flight GPS lookup has no spinner anywhere on the screen — the entire loading affordance is one line of body copy swapped into the draft card ('Detecting your location…'), while the GPS button merely greys out. On a slow fix this reads as 'nothing happened' rather than 'working'. Asserted (deliberately) by 'an in-flight GPS lookup shows copy, never a spinner'.

## F23

DeliveryRegisterPromptScreen: Copy mismatch: every string on the register-as-a-delivery-person prompt is offer-KYC-gate copy — `offerKycGateTitle` ("Verification required"), `offerKycGateHeadline` ("Get approved to start sending offers"), `offerKycGateBody` ("Finish your identity verification…") and `gateStartKycCta` ("Start verification"). The screen's own dartdoc calls the CTA "Register now"; nothing rendered mentions registering or delivering, and the button labelled "Start verification" navigates to `jeeber-onboarding` (the photo → address → service-area wizard), not to KYC. `customer_profile_screen.dart:159` sends a plain customer here from "register as a delivery person". Same mismatch in AR ("التوثيق مطلوب" / "بدء التوثيق").

## F24

DeliveryRegisterPromptScreen: "Back to requests" (`gateBackCta`) does not go to requests. Both back exits are `canPop() ? pop() : go('/')`, and both shipped callers (`offer_kyc_gate_screen.dart:159`, `customer_profile_screen.dart:159`) arrive with a stack-REPLACING `goNamed`, so `canPop()` is false and the tap lands on the shell root. Pinned by the render test: the tap resolves to the shell stand-in, not to any requests surface.

## F25

DeliveryRegisterPromptScreen: The CTA `go`es where the onboarding wizard expects to have been `push`ed. `dm_onboarding_screen.dart:216` documents step-1 Back as returning "to the `delivery-register-prompt` the wizard was pushed from" and implements it as `canPop() ? pop() : go('/')`; this screen's `context.goNamed('jeeber-onboarding')` replaces the stack, so after the CTA the router holds one page and `canPop()` is false — the documented round trip never fires and the wizard's Back drops the user on the shell. The test taps the CTA and asserts `GoRouter.of(...).canPop()` is false.

## F26

DeliveryRegisterPromptScreen: No bottom SafeArea: the screen is a bare top-level `GoRoute` (no ShellRoute), `Scaffold` does not SafeArea its body, and the `ListView`'s bottom padding is `Spacing.xLarge` = 24 pt against a 34 pt home indicator. Measured on the notched window scrolled to the end: viewport bottom == display bottom, and the last 10 pt of the `delivery_register_prompt_back` button sits under the system gesture bar. Font-independent (24 < 34).

## F27

DeliveryRegisterPromptScreen: At 200% text both actions leave the screen on an ORDINARY phone, not just a small one: on 390 × 844 the body scrolls 180 pt in EN and 220 pt in AR behind a 788 pt viewport, and neither `delivery_register_prompt_cta` nor `delivery_register_prompt_back` is in the widget tree or the semantics tree on arrival (compact 320 × 568 is 1303 pt EN / 1159 pt AR — 2.5 screenfuls). The root `delivery_register_prompt` id survives, so JM-044 AC3 and the Maestro flows that assert only the root stay green while both of the screen's actions are off the display.

## F28

DeliveryRegisterPromptScreen: Arabic is the LONGER rendering at the accessibility ceiling (220 pt of scroll vs 180 on the same phone), so a reviewer who checks only the English card is reading the better case — the reason the reference preview is matrixed.

## F29

OfferKycGateScreen: OfferKycGatePhase.error is emitted by OfferKycGateCubit and rendered by NOTHING. `_GateStatusLine` returns SizedBox.shrink() for any phase != ready, so a jeeber whose `GET /v1/kyc/status` read FAILED is shown the byte-identical screen of a jeeber who never started KYC — no retry, no stale-data notice, no way for the user or for QA to tell the two apart. Pinned by the render test 'loading, error, notSubmitted and approved are the SAME surface'.

## F30

OfferKycGateScreen: `_GateStatusLine`'s `_ => (null, null, null)` arm swallows KycStatus.approved, and OfferKycGateState.isApproved is defined and read nowhere. The screen's dartdoc claims 'an APPROVED jeeber NEVER reaches this screen', but that guarantee lives entirely at the JM-048 feed call site — nothing in the screen, the cubit or the router enforces it. A stale feed payload or an approval landing mid-session renders 'Get approved to start sending offers' to an already-approved jeeber, with no exit to the offer composer they were trying to reach.

## F31

OfferKycGateScreen: The `rejected` branch is a dead end that contradicts its own copy. It renders 'This decision is final — you can appeal through support' (kycStatusRejectedBody) while the only primary CTA on the screen is 'Start verification' -> goNamed('kyc-status'), i.e. restart the wizard. There is no edge from the gate to `kyc-rejected`, the appeal-via-support route the router registers for D52/D87.

## F32

OfferKycGateScreen: The `resubmitRequested` branch tells the jeeber to 'Fix the items below, then resubmit' and there are no items below. KycSubmission.resubmitSteps carries the per-document-slot list the back-office filled in and nothing on this screen reads it — the copy is borrowed verbatim from the KYC status screen, where the list does render.

## F33

OfferKycGateScreen: At 320x568 with 200% text the body carries 2287 pt of scroll behind a ~512 pt viewport, and the ListView stops building past its viewport plus cache extent: `gate_topup_note`, `gate_start_kyc_cta`, `gate_register_link` and `gate_back_cta` are ALL absent from the widget tree and from the semantics tree on arrival. Those are four of the five semantics ids 65_W2_TEST_PLAN §2 JM-044 publishes as QA targets, so a driver or a screen reader querying them finds nothing until the user scrolls. The D67 top-up note is the worst of the four — its whole purpose is to be read before the jeeber decides what to do. Pinned by the render test.

## F34

OfferKycGateScreen: The loading phase has no affordance whatsoever — no spinner, no skeleton, no disabled CTA. Keeping the exits up is deliberate (R-F: the D38 invariant must not be gated behind the network), but the silence is total: there is no frame in which the screen admits a status read is in flight, which is what makes loading, error and notSubmitted mutually indistinguishable.

## F35

OfferKycGateScreen: The Screen Catalog entry could never reach three of the six states the screen can actually be in. It drove the gate with `FakeKycGateway(initial: ...)`, whose fetchStatus always resolves and never throws, so LOADING, ERROR and the `resubmitRequested` branch of `_GateStatusLine` had no mocked state on any dev surface until this wave — the resubmit branch in particular had never been rendered anywhere outside production.

## F36

MutualRatingScreen: Quick-tag Wrap never wraps: measured at 390x844, every OmdsChip takes the full 350 pt content width, so the five tags render as five full-width bars one per run — in EN and AR, at 100% text as much as at 200%. The Wrap sets `spacing` but no `runSpacing`, so the pitch equals the chip height exactly (48 pt bars on a 48 pt pitch) and the bars touch. The compact pill row that `Wrap(spacing:)` implies does not exist at any width the app ships on. Pinned in the render test (`the quick-tag Wrap never wraps: five full-width bars, no gap`).

## F37

MutualRatingScreen: AR + 200% text overflows a tag chip on a stock phone: `mutualRatingTagPunctuality` ("دقيق بالمواعيد") measures 336 pt inside the 350 pt chip and the chip's internal Row overflows by 12 pt (10 pt in the selected/filled state). EN survives only because its widest label ("Communication") measures 319 pt. Nothing wraps or ellipsizes. Locale-specific and invisible at 800x600, so no existing test saw it; pinned in the render test.

## F38

MutualRatingScreen: `_ErrorView` is a dead end. It replaces the WHOLE body (stars, comment, tags and `rating_submit_cta` all go), and no phase leads back to `_InputView` — from `error` MutualRatingCubit can only reach `submitting`, then `error` or `submitted`. Combined with `PopScope(canPop: false)` plus a `BackButtonListener` that consumes BACK unconditionally, a permanent rejection (403 'not a party to this delivery') leaves the user on a mandatory screen with one button that fails again and no exit from the app.

## F39

MutualRatingScreen: `OmdsErrorState.retryLabel` defaults to the hardcoded English literal 'Retry' and `_ErrorView` never passes a localized one. Verified by rendering the error state under `ar`: the screen shows [Arabic error copy, 'Retry', Arabic title]. Same defect class as JEBV4-296 (the tag-chip EN leak), still live one branch away.

## F40

MutualRatingScreen: `_CommentField` takes `comment` and never reads it — the OmdsTextField has no `controller` and no `initialValue`. A 254-character comment seeded into `MutualRatingState.comment` renders as an empty field with the hint showing, so any draft restore, or showing what was typed after a failed submit, is silently a no-op.

## F41

MutualRatingScreen: The blind-reveal phases (`awaitingOther`/`polling`/`revealed`/`autoRevealed`) fall through to `_InputView`, so a state restored into `awaitingOther` shows an already-submitted rating as a blank, fully re-submittable form with an ENABLED submit button. Six ARB keys written for those phases (mutualRatingAwaitingTitle / RevealedTitle / AutoRevealedTitle / NoCounterRating / TheirStars / Done) ship in both EN and AR and are never rendered by this screen.

## F42

MutualRatingScreen: `_StarSection`'s Semantics label is a hardcoded, unpluralized English `'$stars stars selected'`. An Arabic screen-reader user hears English on the one control this mandatory screen requires, and one star reads '1 stars selected'.

## F43

MutualRatingScreen: `isClient` changes nothing on screen. `Fresh · jeeber rates client` is pixel-identical to `Fresh · client rates jeeber`: `mode=jeeber` flips the audience on the wire only — no ratee name, no avatar, no 'rate your customer' copy. A jeeber closing out a delivery and a customer receiving one are shown the same screen.

## F44

MutualRatingScreen: `submitting` and `submitted` both render a bare centred `OmdsLoadingState` with no copy, so the last thing a user sees of a rating they were REQUIRED to give is an unlabelled spinner before `context.go('/')` fires.

## F45

MutualRatingScreen: PRE-EXISTING RED (not caused by this work): `test/features/rating/mutual_rating_tag_chips_l10n_test.dart` — 'ar locale: tapping the localized chip toggles the CANONICAL gateway taxonomy wire value' fails with a hit-test miss (tap at Offset(400,524) lands on a RenderIgnorePointer from the un-settled route transition; the test pumps once instead of pumpAndSettle). Confirmed failing with `git show HEAD:` of the screen file swapped in, so it is independent of this change.

## F46

RatingScreen: Submit CTA is live and fully inked at zero stars, and the tap is a silent no-op. `_FeedbackFooter` builds `OmdsLoadingButton` with `isEnabled` at its `true` default while `_onSubmit` opens with `if (_stars == 0 || _submitting) return;` — no toast, no inline error, no scroll-to-the-stars. Because the screen is `PopScope(canPop: false)` with `automaticallyImplyLeading: false` and no close X (D56), picking a star is the ONLY exit and nothing on screen says so. Asserted in `the CTA is live at zero stars and silently does nothing`.

## F47

RatingScreen: The shipped route can render "Rate " with nobody in it. `RatingScreen.rateeName` defaults to `''` and the only builder for it (`lib/core/router/app_router.dart:1441`) reads `state.uri.queryParameters['name'] ?? ''`. Nothing under `lib/` navigates to `/orders/:id/feedback` — it is deep-link-only — so a link without `?name=` produces the bare verb plus a dangling space over `FeedbackAvatar`'s '?' placeholder, on an un-dismissable screen.

## F48

RatingScreen: A rejected submit is indistinguishable from a successful one. `_onSubmit` catches everything, drops the stars AND the typed comment, and runs `context.go('/')` anyway (deliberate per its comment, so a failure cannot strand the user). The consequence is that this screen has no error surface at all and the user is never told the rating was lost — and cannot return to re-enter it, since the route is gone from the stack and unreachable from the app.

## F49

RatingScreen: Nothing is disabled while the submit is in flight. `_submitting` gates a second submit and nothing else: with the CTA spinner up, the star row still accepts a change (the test drives 4 -> 5 stars mid-flight) and `OmdsTextField` stays `enabled`, so the rating on screen can diverge from the one already sent. `_submitting` is also never reset — the screen relies on always navigating away.

## F50

RatingScreen: `MixedDirectionText` is a no-op at this call site. `_FeedbackRateName` hands it the whole localized sentence and `detectDirection` keys off the FIRST character, which is always the localized verb ("Rate" / "قيّم") and never the interpolated name. The widget's stated purpose — giving a name its own direction inside a differently-directed line — cannot fire here; it only ever echoes the locale.

## F51

RatingScreen: Secondary, in a dependency rather than the screen: `lib/features/mixed_direction/presentation/mixed_direction_text.dart` still carries `// ORPHAN (JEBV4-227, verified 2026-07-12): zero refs`, which `_FeedbackRateName` disproves. An orphan sweep acting on that marker would delete a widget this screen builds.

