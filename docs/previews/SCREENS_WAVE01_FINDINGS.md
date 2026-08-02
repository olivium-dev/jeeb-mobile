# Screens wave 01 (location, chat, home_client) — defects

6 written / 1 refused (LiveSettingsScreen — no injectable seam).
43 previews. Catalog fixtures extracted, not copied; catalog unchanged at
270 states / 67 screens.

## F01

CaptureLocationScreen: `isConfirming` promises a busy state and delivers a disabled one. `_PinCta` forwards the flag to `OmdsPrimaryButton.isEnabled` and stops there, so the screen renders the ordinary disabled treatment (brand fill at 45% alpha, identical 'Pin Location' label at 90%) with no spinner, no progress copy and no change to the CTA's semantics — while the class doc calls it 'a busy state (reverse-geocode / save in flight)'. Pinned by `and shows no sign that anything is in flight` (no CircularProgressIndicator / LinearProgressIndicator anywhere).

## F02

CaptureLocationScreen: Nothing but the CTA is gated while confirming. With `isConfirming: true` the map still pans, the pin still tracks it and the app bar's back arrow still pops, so the surface tells the user they are still choosing a point while the host is already committing the point it read at tap time. Pinned by `and gates nothing else — the map still pans` (readout moves from 33.89380 to 33.89300 during the confirm).

## F03

CaptureLocationScreen: `isConfirming` is unreachable in the app: neither `CaptureLocationRoute` (app_router.dart:147) nor `GoogleMapPickerLauncher.pickOnMap` passes it, and no other caller exists — grep for `isConfirming` outside `lib/features/chat/`. Only a preview can put that state on screen today, which is also why nobody has noticed it has no busy affordance.

## F04

CaptureLocationScreen: The shipping state offers a live primary CTA with nothing to pin. `/capture-location` builds the screen with no `mapBuilder`, so the map is the neutral `CaptureMapViewport` placeholder, which cannot pan, and JEBV4-176 deliberately made the route pop WITHOUT a coordinate. Enablement is `!isConfirming` and nothing else, so 'Pin Location' is full-width, brand-coloured and fires — the user confirms, the sheet closes, and location-select's Confirm stays disabled with nothing on screen explaining why. Pinned by `offers a live CTA over a map that cannot pan`.

## F05

CaptureLocationScreen: The screen has no permission-denied / map-failed / outside-service-area state. `GpsDeniedState` was written for it (T-MOB-012 AC4) and `captureLocationOutsideServiceArea` ships in both ARBs, but nothing on this screen renders either; the only seam is `mapBuilder`, which puts any such surface UNDER the fixed centre pin and ABOVE a live CTA. The previews show a red map pin floating in the middle of 'Location access required' with 'Pin Location' confirmable underneath — a pin confirmed on a screen that has just said it cannot locate the user. Pinned by `permission denied arrives under the pin, over a live CTA`.

## F06

CaptureLocationScreen: The CTA's semantics node cannot express the disabled state. `_PinCta` wraps the button in `Semantics(identifier: 'capture_location_pin_cta', button: true)` and never passes `enabled:`, so `flagsCollection.isEnabled` is `Tristate.none` in BOTH the idle and confirming renderings — a screen reader announces 'Pin Location, button' identically while the screen is busy, and taps simply stop landing. Maestro likewise sees the same node in both states. Pinned by `and the CTA announces itself identically either way`.

## F07

CaptureLocationScreen: `onPinned` is a bare `VoidCallback`, so the screen cannot report WHAT was pinned. Every host has to carry the coordinate on a side channel (`GoogleMapPickerLauncher` reads `MapCaptureController.center` at tap time), and the host that has no such channel — the `/capture-location` route — pops nothing at all. The preview had to invent its own tally because there is no coordinate on the screen's own contract to display.

## F08

ClientLocationScreen: Two different blockers render the SAME dead Confirm CTA, and the screen names neither. In the fully-healthy preview (GPS resolved, saved addresses loaded) `OmdsLoadingButton.isEnabled` is false — pixel-identical to the GPS-permission-denied preview. `_ConfirmFooterState.build` gates on `state.canConfirm && value.text.trim().isNotEmpty`; `canConfirm` is true there, so the blocker is the empty description — but `_DescriptionSectionState._touched` is false until the customer edits the field, so `composeDescriptionRequired` ('Please describe what you need.') is never shown either. The customer sees a disabled create button with zero explanation. Pinned by `the healthy state disables Confirm for the same-looking reason` in the render test.

## F09

ClientLocationScreen: Cold load withholds the compose block for a network call it does not depend on. While the saved-locations read is in flight, `_Body` returns `Center(child: OmdsLoadingState())` and `_ConfirmFooter` returns `SizedBox.shrink()`, so the whole create step — including the required 'What do you need?' field, which needs nothing from `GET /users/:id/saved-locations` — is replaced by a bare contextless spinner with no app-bar-adjacent copy and no skeleton. On a slow connection the customer cannot even start typing the request content. Pinned by `cold load is a bare spinner with no create affordances`.

## F10

ClientLocationScreen: The screen's GPS-resolver fallback made the designer-facing Screen Catalog non-deterministic and plugin-live. `ClientLocationScreen._resolveGpsResolver()` falls through to `GeolocatorCurrentLocationResolver()` when `currentLocationResolver` is null and nothing is DI-registered, and the catalog entry passed null — so opening 'Location Select (create flow)' on a device raised a REAL location-permission prompt and then rendered whichever GPS state that device happened to be in. `CatalogNetworkGuard` only guards Dio, so it never saw this. Fixed here by threading `ClientLocationScreenFixtures.gpsResolved` through the catalog entry as well as the previews; the screen's fallback itself is unchanged (no production edit).

## F11

ClientLocationScreen: At the length ceiling, two saved addresses become indistinguishable. `_SavedAddressCard` renders both `address.label` and `address.address` with `overflow: TextOverflow.ellipsis` and NO `maxLines`, so each caps at one truncated line; the only other content on the card is a three-value category icon. Two entries sharing a long prefix ('Teta Salma's apartment — third building after…') therefore truncate to the same visible string in a mutually-exclusive selection group. Pinned by `the longest saved address truncates on one line` (intrinsic width > laid-out width for both lines).

## F12

ClientLocationScreen: The most important field on the create step can only ever be reviewed empty. The 'What do you need?' text is seeded in `_ScaffoldState.initState` from `sl<ComposeRequestController>().description` — a global GetIt read with no constructor seam — so neither a preview nor a catalog state can show the screen with content typed in without mutating the app's DI graph. Everything downstream of a non-empty description (enabled Confirm CTA, the 280-char counter near its cap, the multi-line field at 6 lines) is unreachable for visual review. Reported, not fixed: adding the seam would be a production edit.

## F13

SavedLocationsScreen: AR + 200% text overflows the saved-address tile by 42 pt. The title line is `Flexible(label) + _DefaultBadge` (saved_locations_screen.dart:261-275) and _DefaultBadge/OmdsChip is NOT flexible, so it claims its natural width first and the Flexible label shrinks to zero. In Arabic the badge reads `الافتراضي` (wider than `Default`); at TextScaler 2.0 it alone exceeds the 206 pt the title line gets — `A RenderFlex overflowed by 42 pixels on the right`, creator `Row ← Column ← Expanded ← Row ← Padding`, reproduced in BOTH list previews. EN@200% is clean and AR@100% is clean; only the combination breaks — and the standard JeebPreview matrix renders AR at 100% and 200% in EN, so it renders the two halves and never the failure.

## F14

SavedLocationsScreen: The Add CTA has no disabled rendering. `_AddAddressFab` (saved_locations_screen.dart:172-194) resolves `enabled:false` to `onPressed:null` on a `FloatingActionButton.extended`, and neither the M3 defaults nor `AppTheme`'s `floatingActionButtonTheme` (app_theme.dart:203, backgroundColor/foregroundColor only, no disabledElevation) change anything when onPressed is null. During the initial load the CTA keeps the primary fill, the full-opacity label and the same elevation — it is pixel-identical to the working one and silently swallows taps. Pinned in the render test ('the Add CTA is inert during the load but looks identical').

## F15

SavedLocationsScreen: The Add CTA stays ENABLED on a failed load. `enabled: !_isMutating(state) && state is! SavedLocationsLoading` (saved_locations_screen.dart:104) does not exclude `SavedLocationsError`, so on the error surface a user can add an address while the manager is unable to show what is already saved — i.e. can create a duplicate of an address they cannot see. Pinned in the render test ('the error preview offers retry — and still offers Add').

## F16

SavedLocationsScreen: The screen cannot build without a `Router` ancestor, which is invisible until something hosts it outside the app. `_SavedLocationsView` wraps its Scaffold in `RootAwareBackScope` → `BackButtonListener`, whose `didChangeDependencies` calls `Router.of(context)`; under a plain `MaterialApp` (the preview canvas host AND `test/previews/preview_test_harness.dart`) that throws 'Router operation requested with a context that does not include a Router' before first paint — verified directly. The preview section therefore has to supply `Router.withConfig` over a local GoRouter. Any future widget test that pumps this screen under a non-router MaterialApp hits the same wall.

## F17

SavedLocationsScreen: Two of the cubit's five states are unreachable from any static host. `SavedLocationsScreen` builds its own `SavedLocationsCubit` internally and exposes only a `repository:` seam — no `cubit:` seam — so `SavedLocationsMutating` (the delete-in-flight `OmdsLoadingState` overlay that also disables every row) and `SavedLocationsMutationError` (the cap-reached / save-failed / delete-failed snackbar, including the `isCapError` branch) can only be produced by a real tap sequence. They are previewable by hand in the canvas ("…" → Delete against a hanging/throwing fake) but cannot be pinned by a preview or a render test.

## F18

AddressDetailFormScreen: No seam to seed the save lifecycle: `AddressDetailFormScreen` builds its `AddressFormCubit` inside `build()`, so `AddressFormStatus.saving`, `.saved` and `.failed` cannot be rendered by any host — only by a human tapping Save. The two states carrying real risk (the CTA spinner and the failure copy) are therefore invisible to the catalog, the preview canvas and any golden test. Missing seam, exactly: an optional `AddressFormCubit? cubit` (or `AddressFormState? initialState`) constructor parameter handed to a `BlocProvider.value` when non-null — the same shape the existing `repository` seam already has. Not added; nothing above the banner was touched.

## F19

AddressDetailFormScreen: A failed save leaves NOTHING on the screen. `_onStateChange` shows a 4-second snackbar and immediately calls `acknowledgeError()`, so after it fades there is no inline error, no retry, and no record that the address was not saved — the form looks exactly as it did before the tap.

## F20

AddressDetailFormScreen: The add path and the edit path are the same picture. Both use `l10n.addressFormTitle` ("Address details") and `l10n.addressFormSaveCta` ("Save address"), and nothing else drawn names the intent, so a user cannot tell creating from editing (pinned in `documented defects`).

## F21

AddressDetailFormScreen: Nothing drawn says why Save is disabled. The JEBV4-176 gate dims the CTA until a real pin is dropped, but the explanation (`AddressFormL10n.pinMissing`, "Pick a location on the map") exists only as the `Semantics(label:)` on `address_form_map_pin` — it is never rendered, and the map band looks identical with and without a pin apart from the centre marker. `find.bySemanticsLabel` finds it; `find.text` does not.

## F22

AddressDetailFormScreen: Two persisted fields have no control anywhere on the form. `_onSave` writes `category: _category` and `isDefault: widget.existing?.isDefault ?? false`, but `_FormBody` renders only five `OmdsTextField`s and the map band — no category picker, no default toggle. Every address created on the add path is silently saved as `SavedLocationCategory.home`.

## F23

AddressDetailFormScreen: The empty add form is covered in what look like answers. `AddressFormL10n` writes its hints as finished values ("4th floor, Apt 12", "Ring twice; blue door.", "Home, Office, etc.") and `InputDecorator` keeps them drawn, so only ink colour separates a field the user filled from one they did not. This surfaced concretely: a fixture using the natural value `4th floor, Apt 12` matched twice in the render test.

## F24

AddressDetailFormScreen: The cold-mount branch is a dead end. `FutureBuilder` on `AuthTokenStore.userId` returns its own bare `Scaffold(body: Center(OmdsLoadingState()))` — no app bar, no back affordance — so a slow or wedged keychain read strands the user on a blank screen. Worse, `snapshot.data ?? ''` swallows an ERROR into an empty user id: a keychain that throws lands on the same form as one that answers, with `userId: ''` behind the cubit.

## F25

AddressDetailFormScreen: `_PinPreview` hardcodes its band to `Sizes.eightXLarge * 2` (160 pt) and never reads the text scaler, while the app bar is clamped to 1.34 and the CTA box is fixed at 48 dp. At 200% text the one purely decorative element keeps its full share of the screen and everything carrying meaning is pushed into the scroll — visible in `addressDetailFormScreenTextCeiling`.

## F26

LiveSettingsScreen: No seam at all, and it is a testability defect in the screen, not just a preview inconvenience: `const LiveSettingsScreen({super.key})` resolves `sl<Dio>()` from a private method behind a `late` field initializer (live_settings_screen.dart:34-40) and hard-constructs `DioAccountService(sl<Dio>(), AuthTokenStore())` + `DioDisplayNameRepository(sl<Dio>())` in a private State (lines 78-90). There is no way to render ANY of its three states deterministically — not from a preview, not from a widget test, not from the Screen Catalog, which is why batch_10_entries.dart:751 skipped it.

## F27

LiveSettingsScreen: Dead parsing left behind by the role-switch removal: `_SettingsAccountSnapshot.availableRoles` and `.activeRole` are computed by `fromJson` (lines 183-200) and carried on the class (lines 174-180), but the only field ever read is `snapshot.profile` at line 79. The whole `_roles`/`_role` alias table (lines 205-220 — client/customer/user, jeeber/driver/delivery/deliveryman/delivery_man) is unreachable output. The class doc comment already says JEBV4-204/E9 removed the role toggle; the parsing was not removed with it.

## F28

LiveSettingsScreen: Every branch of this screen owns a Scaffold — `Scaffold(appBar: OMDSAppBar(...))` for loading (line 58), `_LiveSettingsError` (line 113), and the loaded branch delegates to `SettingsScreen`, which returns its own Scaffold (settings_screen.dart:110) — while `jeebPreviewHost` already wraps its child in `Scaffold(body: SafeArea(...))`. Any screen-level preview of this file nests two Scaffolds; the pilot needs a host variant that skips the wrapper Scaffold for screens, or every screen preview will carry a doubled surface and a duplicated app-bar/inset budget.

## F29

LiveSettingsScreen: `CatalogNetworkGuard` gives this screen no protection: it rejects only mutating verbs, and this screen's sole network call is a GET. The Dev Tool shares the app's real GetIt graph (Bootstrap.minimal), so hosting `LiveSettingsScreen` in the catalog or in a preview canvas with DI configured would fire a real `GET /v1/users/me` at the live gateway. For this screen the guard is not even a net.

## F30

LiveSettingsScreen: The error branch is undiscriminated: a 401 from an expired token, a 500, and a malformed-JSON parse failure all render `l10n.settingsNetworkError` ("network") with a retry that repeats the identical call (lines 43-45, 56-57). An expired-session user gets an infinite retry loop against an error message that names the wrong cause.

## F31

LiveSettingsScreen: Contradiction worth resolving before anyone pays for the seam: the class is annotated ORPHAN (JEBV4-227, verified 2026-07-12, "no forward-nav entry point — customer-profile is the live surface"), yet app_router.dart:975 still builds it as the `/settings` route, so a deep link or any surviving `context.goNamed('settings')` reaches it. Either the route goes and the screen is deleted, or the orphan annotation is stale — deciding that is cheaper than seaming a screen nobody navigates to.

## F32

ChatScreen: lib/features/chat/presentation/widgets/offer_card_bubble.dart:89 — the 'Client · broadcasting offers' state cannot render exception-free at any width the app ships. Inside ChatScreen the offer bubble is capped at 250 pt, and _OfferActions is a Row(mainAxisSize: min) of two intrinsically sized pills with no Wrap/Flexible, so the footer overflows by 97 px in EN at 390 pt — one RenderFlex exception per offer card, two per pump. The defect is documented at WIDGET level in offer_card_bubble.dart's own preview library, but its own render tests pump the 800x600 surface where the row has ~450 px to spare, so nothing in CI saw it until a screen preview pinned a real phone frame. The preview keeps the 390 pt frame and its test tolerates only errors whose text contains 'overflowed' (never widened the canvas to make it green).

## F33

ChatScreen: lib/features/chat/presentation/chat_screen.dart:_ChatBody.build — the cold-load branch (`if (state.isLoadingHistory) return const _ChatHistoryShimmer();`) returns BEFORE the Column is built, so the shimmer replaces the ENTIRE surface, composer and header chrome included. For as long as the history read takes, the user cannot start typing and any fee banner / pinned summary is absent; a slow read renders as a chat with no input. Pinned in the loading group's test (`find.byType(TextField)` findsNothing) so the consequence is visible rather than inferred.

## F34

ClientHomeScreen: `_LoadingLayout` hard-codes `ClientHomeGreeting(name: null)` (client_home_screen.dart:277) while `_FailedLayout` and `_ReadyLayout` both pass `state.greetingName`. `ClientHomeCubit.load()` emits `greetingName` in the SAME frame it sets `loading`, so the name is already in state when this body paints — the header greets 'Welcome back' for the whole cold read and then re-greets 'Hello, Layla' when the snapshot lands. Pinned by `DEFECT: the loading header forgets a name it already has`.

## F35

ClientHomeScreen: `initialTab: ClientHomeTab.inProgress` is still reachable (the dev seam and the Screen Catalog both pin it) but JEBV4-298 removed the In-Progress chip from `_ClientHomeTabBar`, and `_resolveInitialTab` returns early for any non-default `initialTab`. The result on screen: three active-order cards under a tab bar in which BOTH visible chips report `isSelected: false`, so the only affordance that names the visible list says nothing. Pinned by `DEFECT: the In-Progress body renders with no chip selected`.

## F36

ClientHomeScreen: A cold failure removes the chip row, not just the list. `_ClientHomeBody` swaps the entire layout on `ClientHomeStatus.failed`, so `_FailedLayout` leaves the user a greeting + Retry and no way to switch tabs. `PendingRequestsTab` and `RepliesTab` each carry their own error branch that KEEPS the chrome — those branches are unreachable from this screen because the screen-level failed branch preempts them. Pinned by `the failed body replaces the chip row, not just the list`.

## F37

ClientHomeScreen: The 'land where the content is' affordance in `_resolveInitialTab` moves the selection from a POST-FRAME `addPostFrameCallback` + `setState`, so with Pending empty and Replies populated the first painted frame is the Pending empty state and the second is the Replies list — a visible jump on open. No widget test can observe it because `pumpAndSettle` collapses both frames; the canvas shows it.

## F38

ClientHomeScreen: Two rows on this screen are a bare `Row` with no `Wrap`, no `Flexible` and no scrollable around their children — the Pending/Replies chip row in `_ClientHomeTabBar` (client_home_screen.dart:436) and the trailing CTA row on each In-Progress card (`_ActiveOrderActions`, active_request_card.dart:397). Neither is ever laid out at device width by CI: every widget test, including the preview render harness, pumps an 800 pt surface where both have ~2x the room they ship with. Under the SDK test font both overflow at 320 AND at 390 pt, which is why the preview boxes pin the frame in `size:` (canvas only) rather than in the widget tree.

## F39

ClientHomeScreen: The loading body renders no text of any kind in either locale — no chip row, no skeleton, no 'loading your requests'. For the whole cold read a screen-reader user is told nothing about what the surface is doing, and the same spinner is what a stalled read shows indefinitely.

