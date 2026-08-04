# Screens wave 07 (client_offers, profiles, receipt, delivery_status)

7/7 written, 53 previews, 0 agent errors.

## F01

ClientOffersScreen: ClientOffersCubit.refresh() can emit after close. lib/features/client_offers/application/client_offers_cubit.dart:167 guards the SUCCESS path with `if (isClosed) return;`, but the two failure paths (emit at :175 and :179) have no guard. Pull-to-refresh, then pop the screen before the read resolves and the failure lands: `Cannot emit new states after calling close`. Every other async path in this cubit (load :116/:124/:137, _scheduleColdRetry :154, _refreshFromPush :343/:348) guards it. Found while building the refresh-failure fixture, which drives exactly that call sequence.

## F02

ClientOffersScreen: The empty state gives the customer no way out. The Cancel-request CTA is gated on `state.hasOffers && state.requestIsOpen` (client_offers_screen.dart:301), so the person most likely to want free pre-accept cancel (D69) — nobody has bid, the window is counting down — is the one person the screen offers no cancel to, while a customer who already has bids gets one. Visible side by side in `Empty · no bids yet` vs `Fresh window · three bids`.

## F03

ClientOffersScreen: A locally elapsed display window renders a frozen 'Window: 0:00 left' band in the urgent amber, indefinitely, with no copy saying bidding is over. `OfferWindowTimer(remaining: state.windowRemaining, expired: state.requestIsExpired)` (client_offers_screen.dart:239) takes its two inputs from two different authorities — the local clock and a server-only lifecycle flag — and only the server may say 'expired'. Keeping Accept armed is deliberate and correct; having no DISPLAY state for 'the deadline you were shown has passed and we are still waiting on the server' is not. Note the Screen Catalog state named 'Offer window expired' has never rendered those words: it is this 0:00 band.

## F04

ClientOffersScreen: The accept-phase half of the inline error banner is unreachable dead code. `_LoadedBody` picks `OffersErrorPhase.accept` when `state.errorSource == OffersErrorSource.accept` (client_offers_screen.dart:257-259), but `errorSource.accept` is set ONLY by `ClientOffersCubit.acceptOffer`, and nothing in lib/ calls it — B-01 moved the accept into OfferAcceptSheet/OfferAcceptCubit and left the list with beginAccept/endAccept. So `offersErrorGeneric` and the accept-phase reading of `offersErrorJeeberAtCapacity` can never render on this screen, and no fixture can reach them.

## F05

ClientOffersScreen: The loading body replaces the entire surface and is indistinguishable from a rate-limit back-off. `OffersScreenStatus.initial`/`loading` render a bare `OmdsLoadingState` (client_offers_screen.dart:161-163): no window, no sort bar, no cards, no copy, nothing to tap but the back arrow. `_scheduleColdRetry` deliberately KEEPS the screen in `loading` for the whole Retry-After window on a 429 (FIX-A), so a customer under back-pressure watches an unexplained spinner for as long as the gateway asks — a state with no copy for the only thing it could say.

## F06

ClientOffersScreen: [harness, not this screen — but it will bite every remaining screen] The preview render harness lays Arabic out in the 1-em FlutterTest face, so any preview with a tight slot reports a phantom AR overflow. `previewCanvas` builds `AppTheme.light()` unmodified and the theme carries no `fontFamilyFallback`; `loadInterTestFont` registers the Noto Arabic subset under its own family, which only `withGoldenTestFonts` wires in. Measured through the golden fonts, OfferSortBar is 238 dp (EN) / 223.6 dp (AR) against slots of 358 dp (390 pt) and 288 dp (320 pt) — fits everywhere; under the test face it is 389 dp (EN) / 303 dp (AR) and overflows both. Without `loadInterTestFont` EVERY loaded state here fails with `RenderFlex overflowed by 31 pixels`; with it, only the 320 pt AR pass still trips, on a defect that exists on no device.

## F07

ClientUnreachableScreen: NOT LOCALIZED AT ALL — client_unreachable_screen.dart contains zero `AppLocalizations` lookups. All six visible strings ('Client Unreachable', 'Cannot reach the Client', the 15-minute paragraph, 'Try Calling Again', 'Send Chat Message', 'Flag as Unreachable') are English literals, so the AR locale renders identical English on a mirrored surface. The live flow this screen belongs to (live_tracking) carries its own live_tracking_l10n.dart, so this is the odd one out, not a house style. Pinned by 'FINDING — the screen is not localized, at all'.

## F08

ClientUnreachableScreen: `deliveryId` is a REQUIRED constructor parameter that `build` never reads. The screen cannot show which delivery is about to be flagged, and its only output is a bare `pop(true)` — never the id. The 'Cold arrival' preview is handed a real 36-char id and is pixel-identical to 'Phone', which is handed 'delivery-demo-1'. Pinned by 'FINDING — the required deliveryId is never drawn'.

## F09

ClientUnreachableScreen: Two of the three CTAs are dead in shipped source: 'Try Calling Again' and 'Send Chat Message' are `onTap: () {}` literals (lines ~35 and ~47), not injected callbacks a preview forgot to wire. They are visually indistinguishable from the one button that works. Pinned by 'FINDING — two of the three buttons do nothing'.

## F10

ClientUnreachableScreen: The body is `Scaffold > Padding > Column` with a `Spacer` and NO scroll view anywhere in the chain, so overflow is laid out off the display and no gesture reaches it. Measured: 390x844 @200% overflows 236 px with the flag CTA at y1048 vs an edge at y876 (172 pt past it); 320x568 @200% overflows 800 px with the CTA at y1336 vs y600. What gets cut is always 'Flag as Unreachable' — the only working button — leaving only the two empty handlers on screen. AR is identical because the copy never translates.

## F11

ClientUnreachableScreen: At 320x568 with DEFAULT text (no accessibility setting) the body already overflows 36 px and the flag CTA straddles the bottom edge at y572-620 against y600, i.e. its lower half is off the display. Flagged as the BOUNDARY rather than a certain break: this is the one measurement the flutter_test square-glyph font plausibly inflates. The reference 390 pt phone has only 16 pt of slack at 100%, and this window is 276 pt shorter.

## F12

ClientUnreachableScreen: `Navigator.of(context).pop(true)` in the flag CTA assumes a caller underneath. On a stack-replacing arrival it removes the only route and leaves a BLANK surface, and the `true` it reports has no receiver. Compounding it, OMDSAppBar is built with no `showBackButton` (defaults FALSE) while passing `automaticallyImplyLeading: true`, so that same arrival has no back arrow either. Pinned by 'FINDING — on a cold arrival the flag CTA empties the navigator' and 'FINDING — a cold arrival has no back arrow at all'.

## F13

ClientUnreachableScreen: OmdsPrimaryButton (omds_library) centres a `Row(mainAxisSize: min)` of icon + UNCONSTRAINED `Text` inside a pill whose height is hard-pinned to `Sizes.fourXLarge` (48), so a label wider than the button neither wraps nor ellipsizes — it is painted outside the pill. Measured on 390x844 @200%: the 'Try Calling Again' paragraph is 478 pt wide inside a 358 pt button, still on ONE line, and the row reports 187 px of horizontal overflow. It bites on exactly the two buttons that survive the vertical cut. This is an OMDS-level defect that this screen exposes, not one it introduces.

## F14

CustomerProfileScreen: Seed is read exactly once per element: `CustomerProfileScreen` (a StatelessWidget) hands `data` to `CustomerProfileCubit(seed: …)` inside `BlocProvider.create`, which provider runs once per element and never re-runs. Rebuilding the screen at the same position with a DIFFERENT `CustomerProfileViewData` silently keeps the old profile on screen forever — there is no `didUpdateWidget` and no seed re-sync. Latent today (the shell always passes the same const empty seed; the route and the Screen Catalog each build a fresh element), but it cost two red render tests that looked like preview bugs and were not. Every preview card now carries its own key to work around it.

## F15

CustomerProfileScreen: A failed getMe is invisible: `CustomerProfileCubit` records the typed failure on `state.error`, and NOTHING reads it — `_Body` takes `state.data` and nothing else. No banner, no inline message, no error icon anywhere on the surface.

## F16

CustomerProfileScreen: …and unrecoverable in place: `CustomerProfileCubit.refresh()` — the method its own doc offers 'for an optional inline retry' — has no caller anywhere in `lib/`; the body is a plain `ListView` with no `RefreshIndicator`; and `load()` refuses to re-enter (`if (state.status != initial) return;`). Once the read fails, the mounted screen can never try again.

## F17

CustomerProfileScreen: On the shell path the failure is byte-identical to the cold start. `shell_screen.dart` seeds the Profile tab with an empty `CustomerProfileViewData()` on purpose, so a failed getMe leaves exactly the frame the tab opened with ('?' avatar, blank name line, 'No reviews yet'). The render test asserts the two states render the identical Text set and can only be told apart by the cubit's status/error — pinned as a DEFECT test to be deleted when an error affordance lands.

## F18

CustomerProfileScreen: A 401 is indistinguishable from success. `CustomerProfileFailure.unauthorized` takes the same graceful-degradation path as a flaky network: the seeded read model (name, email, verified badge, rating) stays rendered in full with nothing marking it stale, so a dead session goes on displaying the previous user's PII indefinitely.

## F19

CustomerProfileScreen: The loading status has no affordance and gates nothing. `state.status` is read by no widget: during the in-flight getMe all eight navigation rows are fully painted and fully tappable, so a user can push `password-security` / `settings-addresses` before the screen knows who they are.

## F20

CustomerProfileScreen: `_resolveReviewLauncher()` falls back to `sl<AppReviewLauncher>()`. The Dev Tool shares the app's real GetIt graph, so the day the integrator registers the `in_app_review`-backed adapter, tapping the Rate-app row inside the designer-facing Screen Catalog would raise the real OS store-review sheet against the signed-in account. Both dev surfaces now pass an explicit inert launcher instead of relying on that registration staying absent.

## F21

RatingPromptScreen: `deliveryId` is accepted and never rendered. The route `/orders/:id/rate` hands the constructor the id of the delivery being rated, and nothing on the surface names a delivery, jeeber or order reference. Pinned by the `Deep-link id · never rendered` preview: two different ids ('ORD-4821' vs 'DLV-2026-08-02-000914') produce the identical string set ['Rate your Jeeber', 'Rating Prompt coming soon', 'This screen is not yet available.'].

## F22

RatingPromptScreen: The composition clips at the accessibility ceiling and nothing can absorb it. On 320x568 at 200% text the centred Column wants 732 pt and is given 464 — 'RenderFlex overflowed by 268 pixels on the bottom', in EN and AR alike. There is no Scrollable anywhere inside the screen and the empty-state icon is a fixed 100 pt that does not follow the text scaler, so the clipped copy is unreachable, not merely below a fold.

## F23

RatingPromptScreen: The app bar makes the clip 56 pt deeper than its sibling placeholder. `OMDSAppBar` takes kToolbarHeight off the body before the column is measured (body 512 pt vs `KycStatusScreen`'s 568, 464 vs 520 after the page's own padding). It is not the cause — 732 pt overruns either figure — but this screen fails the small-screen/large-text window by a wider margin than the otherwise identical sibling.

## F24

RatingPromptScreen: All three visible strings and the `Semantics` label are hardcoded English literals, not ARB lookups, so the AR rendering shows English inside a right-to-left layout (asserted in the render test). Explicitly out of scope for the Type-A gate (UX rule #7 belongs to T-MOB-FIX-002), so recorded rather than filed as a defect — but it is what a reviewer sees on the AR card of the matrix.

## F25

RatingPromptScreen: The `Semantics(container: true, label: ...)` wrapper double-announces. It labels a subtree that already publishes both sentences as Text and does not set `explicitChildNodes`, so the merged node contains 'Rating Prompt coming soon' twice and 'This screen is not yet available.' twice (asserted). Same defect as `KycStatusScreen`, so it is a template-level bug across the Type-A placeholders rather than a one-off.

## F26

RatingPromptScreen: The a11y label and the app bar disagree with each other. The toolbar says 'Rate your Jeeber' while the body — and the only text the Semantics wrapper contributes — says the screen does not exist, so a screen-reader user is told 'coming soon' about a screen whose title promises a rating flow.

## F27

RatingPromptScreen: The toolbar title does not honour the user's text size. `AppBar` clamps its own scaler to 1.34 while the body scales to 2.0 (both measured in the same window), so at the accessibility ceiling the two halves of the surface scale at visibly different rates.

## F28

RatingPromptScreen: The bottom safe-area inset is nobody's job. With no bottom bar and `Scaffold` not SafeArea-ing its body, the content clears a 34 pt home indicator only because it is centred and short — it stops being true the moment this placeholder grows a third line or a CTA. (The top inset IS consumed here: the app bar measures 56+59 = 115 pt on the notched window, which is the one structural improvement over the appBar-less sibling.)

## F29

DeliveryManProfileScreen: The ONLY in-app route into this screen renders a self-contradicting surface. lib/features/client_offers/presentation/client_offers_screen.dart:362 `_openJeeberProfile` is the single push to `delivery-man-profile`, and it hardcodes `reviews: const <DeliveryReviewData>[]` and `location: ''`, never setting `isVerified`. Every real visit therefore shows an identity header claiming e.g. "4.7 . 113 Reviews", a section header repeating "113 Reviews", and an empty state underneath saying "No reviews yet". The populated state the catalog and Figma sign off is debug-only — it is reachable only through the `kDebugMode` fixture branch at lib/core/router/app_router.dart:957.

## F30

DeliveryManProfileScreen: The screen has no loading state and no error state. It is a pure value over `DeliveryManProfileViewData`, so "reviews still loading", "the reviews read failed" and "this jeeber has no reviews" are all the same picture — the `OmdsEmptyState` reading "No reviews yet" — with no retry, no spinner and no copy that admits the difference. Pinned in the render test (no CircularProgressIndicator, no 'Try again').

## F31

DeliveryManProfileScreen: D59 cold start renders the review-count string TWICE, one line under the other. `_RatingRow` substitutes `deliveryManProfileReviewsCount` for the hidden aggregate score in the identity header (delivery_man_profile_header.dart), and `DeliveryReviewsHeader` renders the same key immediately below it — "2 Reviews" over "2 Reviews". Only visible with the whole screen composed; asserted as findsNWidgets(2).

## F32

DeliveryManProfileScreen: `deliveryManProfileReviewsCount` is `"{count} Reviews"` with a plain int placeholder and no ICU plural (resolved by literal substitution), so a jeeber's first review reads "1 Reviews" — and because of the duplication above, this screen prints it twice. Arabic `"{count} تقييم"` is one fixed form for every count, so the 3–10 band is wrong there too.

## F33

DeliveryManProfileScreen: The only exit from this modal screen is inked with a container role. `_CloseButton` (delivery_man_profile_screen.dart:~120) passes `Theme.of(context).colorScheme.secondaryContainer` as the icon colour, and the X sits on an app bar whose background is `colorScheme.surface`. In the light scheme that role is hard-coded to brand navy and clears 3:1 comfortably; in dark (`ColorScheme.fromSeed(_jeebNavy, dark)`) it resolves to a dark container tone on an almost equally dark surface — measured under the 3:1 WCAG floor for a UI component, pinned in the render test. `app_theme.dart` says in its own words that `*Container` roles are fills, not ink.

## F34

DeliveryManProfileScreen: `reviewCount` and `reviews.length` are independent inputs the screen never reconciles. The shipped fixture shows 2 review cards under a header that says 113, with no "showing 2 of 113", no pagination and no count of what is on the page — "View all" is the only way to the rest and it leaves the screen.

## F35

DeliveryManProfileScreen: The location/availability line truncates at 1x on a 390 pt phone and at the 320 pt floor, and what gets cut is the availability state. `DeliveryManMetaRow._MetaText` sets `overflow: ellipsis` with `maxLines: null` (single-line truncation) and `deliveryManProfileLocationAvailability` joins location + availability into ONE string with availability LAST, so `Text` cuts " . Available"/" . Unavailable" — the answer to "can this jeeber take my delivery?". Both cases asserted via `didExceedMaxLines`.

## F36

DeliveryManProfileScreen: `rating.toStringAsFixed(1)` rounds a trust signal UP: the 4.96 fixture renders as "5.0 . 1284 Reviews". A jeeber who is not perfect is presented as perfect, and the count beside it is interpolated as `'$count'` — ungrouped, in Western digits even inside the Arabic string.

## F37

DeliveryManProfileScreen: `DeliveryManProfileViewData.isVerified` defaults to true and the offer-card call site never passes it, so an account with zero reviews and no name of its own is still shown the verified badge — the strongest trust mark on the screen, granted by a default.

## F38

DeliveryReceiptScreen: receipt_proof_photo announces itself as an IMAGE labelled "Proof of delivery photo" even when the jeeber uploaded none. The Semantics(identifier: 'receipt_proof_photo', image: true, label: l10n.receiptProofPhotoLabel) node wraps the whole ClipRRect, so the neutral image_not_supported placeholder branch inherits the flag and the label — a screen-reader user is told proof of delivery exists on every receipt. lib/features/delivery_receipt/presentation/delivery_receipt_screen.dart, _LoadedBody proof-photo block. Pinned by the 'the proof-photo slot' group in the render test.

## F39

DeliveryReceiptScreen: At 200% text on the 390x844 device the previews declare, NEITHER receipt_confirm_cta NOR receipt_not_yet_cta is built — the entire confirm/dispute fork is off the first screenful, under a heading still asking "Did you receive your order?". Cause: the proof-photo slot is a hardcoded `height: 200` in BOTH branches (photo and placeholder), so it does not shrink while the copy and buttons grow. At 100% text both CTAs fit. Pinned by 'measured at 390 x 844'.

## F40

DeliveryReceiptScreen: The 404 load failure is a dead end. DeliveryReceiptStatus.failed replaces the WHOLE body, so receipt_not_yet_cta — the dispute escape hatch and the only non-confirm way off this screen — goes with it; what is left is a Retry that re-runs the same 404 against the same id, under OMDSAppBar(showBackButton: false). Reached as the deep link the screen documents itself as, go_router has nothing to pop either. Pinned by 'the failed-load dead end'.

## F41

DeliveryReceiptScreen: DeliveryReceiptCubit.acknowledgeConfirmError() is dead code: nothing in lib/ (screen included) calls it, so the receipt_confirm_error banner has no dismiss — it clears only by starting another confirm. lib/features/delivery_receipt/application/delivery_receipt_cubit.dart:105.

## F42

DeliveryReceiptScreen: LATENT (not reachable from today's UI): DeliveryReceiptCubit.refresh() on an already-loaded receipt writes a failure into state.error while leaving status == loaded, and the builder switches on status only — so a failed refresh of a loaded receipt is silently swallowed. Harmless today because Retry only exists in the failed branch, which takes the other path; it becomes a live bug the moment a pull-to-refresh is added.

## F43

DeliveryStatusScreen: A mid-delivery stream drop throws away a complete delivery. `_Scaffold`'s BlocConsumer switches on `state.mode` alone and the `error` branch never reads `state.snapshot`, which the cubit still holds fully populated. One transport blip (tunnel, backgrounded app) replaces stepper, addresses, courier, ETA and both CTAs with a full-page 'Connection lost' that is byte-identical to the never-connected case. Pinned by `deliveryStatusScreenStreamDropped` + the render test asserting the in-transit data is gone.

## F44

DeliveryStatusScreen: The error page contradicts itself. The body reads 'We can't reach the status service right now. Tap retry to reconnect' while a snackbar over it simultaneously says 'Live status reconnecting…' (`deliveryErrorStreamLost`). Nothing reconnects: `_subscribe()` is reachable only from `retry()`, which only the button calls.

## F45

DeliveryStatusScreen: A DELIVERED delivery still says it is looking for a courier. `_ReadyView` passes `snapshot.jeeber` to `DeliveryJeeberCard` with no regard for lifecycle, so a terminal snapshot with a null jeeber renders the pre-match spinner + 'Looking for a Jeeber…' under the green 'Delivered successfully' banner — and the spinner never resolves. This is exactly the `Delivered` card the Screen Catalog has shipped since DT-04.

## F46

DeliveryStatusScreen: A cancelled delivery is contradicted by its own stepper. `DeliveryLifecycle.cancelled` zeroes `completedSteps` while the milestone rows keep their timestamps, so one card says 'this never started' and 'Matched at 10:00' at once. The ARB has `deliveryStageCancelled`; nothing on this screen reads it, so the red banner is the only element that names the state.

## F47

DeliveryStatusScreen: `isCancelling` has no seam and almost no treatment. `DeliveryStatusCubit` takes a gateway and nothing else (no `initialState`/seed), so neither the catalog, a preview nor a test can preset the in-flight cancel; reaching it needs a real tap plus a gateway whose `cancel()` future stays open. What the user gets for a write in the air is one button label changing to 'Cancelling…' and greying out — no overlay, no progress, Contact Jeeber still live, stepper still claiming the parcel is on its way.

## F48

DeliveryStatusScreen: A four-hour ETA renders as 'ETA 240 min'. `deliveryEtaMinutes` is the only ETA form in the ARB and the screen clamps nothing on the way in (`isEtaVisible` only requires a non-null value in the in-transit stage), so any long ETA is shown in minutes.

## F49

DeliveryStatusScreen: Cold load has no timeout and no skeleton. `mode` starts at `loading` and only leaves it when a snapshot lands, so a gateway that never answers leaves the bare spinner + 'Loading delivery…' on screen indefinitely, with no subtitle, no retry and no failure path.

## F50

DeliveryStatusScreen: Read while wiring the preview seam, not asserted by a test: with neither `cubit:` nor `gateway:` supplied, `DeliveryStatusScreen.build` silently mounts `InMemoryDeliveryStatusGateway(seed: demoDeliverySnapshot(id: deliveryId))` — i.e. any route that mounts this screen with just a `deliveryId` renders fabricated data (Karim H., Hamra → Verdun, scooter) as if it were the real delivery. Mitigated only by the file's ORPHAN marker (JEBV4-227: zero external refs).

