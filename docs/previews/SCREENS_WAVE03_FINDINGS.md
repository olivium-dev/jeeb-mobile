# Screens wave 03 (settings, core, deep_link_targets) — defects

7/7 written, 41 previews.

## F01

NotificationPreferencesScreen: The typed load failure is computed and then discarded. `NotificationPrefsCubit._view` maps `NotificationPrefsFailure` onto `NotificationPrefsFailureView` and `NotificationPrefsError` carries it, but `_ErrorView` in `lib/features/notification_prefs/presentation/notification_prefs_screen.dart` never reads `state.failure` — `network` and `unknown` both render `l10n.notificationPrefsLoadError`. An offline user is told "Couldn't load your notification preferences." with no connection hint and offered a Retry that will fail identically until the network returns. Pinned by a render test: two fixtures failing for different reasons are byte-identical on screen.

## F02

NotificationPreferencesScreen: `NotificationPrefsLoaded.isSaving` is emitted and never rendered. The cubit sets it before every debounced PATCH; the identifier `isSaving` does not appear anywhere in `notification_prefs_screen.dart`. The row stays enabled and unmarked for the 500 ms debounce plus the round trip, so a SUCCESSFUL save is completely silent and indistinguishable from not having saved — the only feedback the screen ever gives about a write is the snackbar that appears when it fails. Verified by tapping the save-fails preview: switch flips on, no `CircularProgressIndicator`, `enabled` still true, then it flips back ~500 ms later.

## F03

NotificationPreferencesScreen: The app-bar back arrow has two contradictory contracts and takes neither of the documented ones. `_onBack` falls through to `context.goNamed('customer-profile')` and the screen's dartdoc states "Back → `customer-profile`", but `settings-notifications` is declared as a CHILD of `/settings` in `app_router.dart` and go_router materializes a page for every matched ancestor with a builder — so `canPop()` is true on every route into the screen and back always pops to `LiveSettingsScreen`. The `customer-profile` branch is unreachable, and were it reachable it would disagree with the router's own registered fallback, `AppRouter.backFallbacks['settings-notifications'] == '/settings'`, which is what the SYSTEM back gesture uses via `RootAwareBackScope`. Both destinations are pinned by tests.

## F04

NotificationPreferencesScreen: `_PrefsBody`'s `if (prefs.transactionalLocked)` guard is dead code with a sharp edge. `DioNotificationPrefsRepository._parse` hardcodes `transactionalLocked: true` on BOTH its parse paths (real gateway shape and legacy mock shape), so nothing in production can make it false. If it ever does, the entire Security section disappears with no replacement — taking `notif_prefs_transactional_lock_icon` with it, an id JM-058 AC2 and the on-device jm-058 flow both assert. Test: `transactionalLocked:false` renders four rows and no `Security` header.

## F05

NotificationPreferencesScreen: At 320 x 568 with 200% text only FOUR of the five switch rows are built. The body carries 1618 pt of scroll (under `flutter_test` glyph metrics) and the `ListView` stops building past its viewport plus cache extent; the row that falls off is the last one, the locked transactional row, so `notif_prefs_transactional_lock_icon` is absent from the widget tree AND from the semantics tree on arrival. A driver or a screen reader querying the id the AC publishes finds nothing until the user scrolls. Pinned by a render test that also proves it reappears after `scrollUntilVisible`.

## F06

NotificationPreferencesScreen: Retry gives no feedback that it was pressed. `_ErrorView`'s CTA is `cubit.load`, which emits `NotificationPrefsLoading` — so the error copy the user was reading is replaced by a bare centered 48 pt spinner with no message, no app-bar progress and no disabled CTA. On a slow connection the screen simply goes blank-with-a-spinner for the duration and then returns to the same generic error.

## F07

NotificationPreferencesScreen: `NotificationPreferencesScreen` builds its cubit inside `BlocProvider.create`, which runs once per `State`, so a changed `repository:` on an already-mounted element is silently ignored. Surfaced when two previews reconciled onto the same element tree and the second state rendered the FIRST fixture's data; the render test now unmounts between pumps. Harmless in production (the route mounts it once) but it makes the `repository:` seam a construction-time-only seam, which is worth knowing for hot reload and for any future caller that swaps it.

## F08

NotificationPreferencesScreen: Data-layer, but it decides what this screen shows on first paint: `DioNotificationPrefsRepository._parse` reads `marketing: read('promotions', true)` on the real-gateway path, defaulting marketing ON when the key is absent — while `NotificationCategoryPrefs`'s own default (and the legacy `topics` path) is marketing OFF, documented as "the conservative, consent-friendly choice". The two paths disagree about consent, and the screen renders whichever one answered.

## F09

ProfileEditScreen: Save silently DELETES the user's avatar. `_onSave` calls `saveProfile(name: value)` and omits `photoUrl`, so `SettingsCubit.saveProfile` passes an explicit `null` into `UserProfile.copyWith`, which distinguishes "omitted" (a sentinel default) from `null` (clear the field). A user who edits only their name loses their photo on the success path, with a "Profile saved." snackbar and no other feedback. `removePhoto()` and `_onChangePhoto` both thread the other field through explicitly; the name-only path is the one that does not. Pinned in test/previews/settings/profile_edit_screen_preview_test.dart (group 'Save deletes the avatar') — that test FAILS once the bug is fixed, by design.

## F10

ProfileEditScreen: The name field is empty for every real user. `_ProfileEditScreenState.initState` seeds its `TextEditingController` from `context.read<SettingsCubit>().state.profile.name` and nothing ever re-syncs it, while `app_router.dart:1005` builds `SettingsCubit(...)..load()` in the route builder with `ProfileEditScreen` as its direct child — so `initState` runs while the profile is still `UserProfile.empty()`. When the read lands a frame later the avatar and the phone row update (they read `state` in `build`) and the field does not. A user with a name on file opens "Edit profile", sees a blank Name, and tapping Save answers "Please enter your name." Both halves pinned (group 'the name field never syncs'). NOTE: the Screen Catalog's `_ProfileEditPreview` awaited `load()` before first build with the comment "mirrors real usage" — that comment predates the 2026-07-24 crash fix that gave the route its own fresh cubit, so the catalog has been showing a state no user reaches.

## F11

ProfileEditScreen: The screen has no loading state. `SettingsState.isLoading` is never read; while the profile read is in flight it renders a complete, interactive, SAVABLE form — `?` avatar, empty name, `—` where the phone belongs, and a live Save button that would write that empty profile back. Tapping Save in that window is a real race: `saveProfile` builds from `state.profile` (phoneE164 `''`) and the still-pending `load()` then emits over the result.

## F12

ProfileEditScreen: The screen has no error state either, and `SettingsCubit.load()` has no failure branch at all — it awaits `_profileRepository.load()` with no try/catch and no emit on error. A repository throw leaves the screen on that same blank-form frame permanently, with the exception escaping as an unhandled async error: nothing the user can see, and nothing to retry. There is no third picture to preview for it — that IS the finding.

## F13

ProfileEditScreen: Two required-field errors, only one of them localized. `OmdsTextField(isRequired: true)` switches on the design system's own auto-validation, which emits a hardcoded English "This field is required" (omds_library/lib/src/inputs/omds_text_field.dart) when the field is cleared, next to the screen's localized `profileNameRequired`. On the Arabic rendering the field says "This field is required" and the Save button says "يُرجى إدخال اسمك." Pinned in both locales.

## F14

ProfileEditScreen: A long name cannot be seen whole on the one screen that exists to edit it. Measured off the render tree at the declared 390x844 box: the 36-character Arabic fixture name lays out at 576 dp against 318 dp of editable width, and `maxLines: 1` (the OMDS default, not overridden here) makes the field scroll rather than wrap — with no ellipsis or any other mark that the name continues. Nothing overflows at 100% or 200% text in either locale, so this is a legibility ceiling, not a clipping one.

## F15

SavedAddressesScreen: Hardcoded English copy: the title ('Saved Addresses coming soon'), subtitle ('This screen is not yet available.') and the Semantics label are string literals, not l10n lookups — even though `savedAddressesTitle`, `savedAddressesEmptyTitle` and `savedAddressesEmptyBody` already ship in BOTH `lib/l10n/app_en.arb` and `app_ar.arb`, and `lib/features/settings/presentation/screens/settings_screen.dart:201` already uses `l10n.savedAddressesTitle` for the row that names this screen. An `ar` build mirrors the frame and keeps the English words. Pinned by the test `an Arabic build still renders the English copy` so the AR half of the harness cannot pass for the wrong reason (an unlocalized screen always builds under any locale).

## F16

SavedAddressesScreen: Content cannot scroll and clips at the accessibility ceiling: `OmdsEmptyStatePage` renders `Center(child: OmdsEmptyState(...))`, and `OmdsEmptyState` is a bare `Column` (100pt icon + 32pt gap + headline + 16pt gap + body, inside `EdgeInsets.all(24)`) with no `SingleChildScrollView` anywhere above it. At 200% text in an 844x390 landscape / split-screen viewport this throws a real `RenderFlex overflowed by ...` and the clipped copy is unreachable — `find.byType(Scrollable)` is empty. Confirmed both ways: the SAME box at 100% text does not overflow, and the SAME 200% text on a 390x844 phone does not overflow, so it is specifically the short-viewport x large-text corner.

## F17

SavedAddressesScreen: No app bar and therefore no back affordance: the screen passes `appBar: null` to `OmdsEmptyStatePage`, so the rendered tree has no `AppBar`, no `BackButton`, and no button of any kind — a pushed route would leave the user with only the OS back gesture. Survivable today only because nothing routes to this class (grep finds the class definition and the catalog entry, nothing else); `/settings/addresses` and the `saved-addresses` route resolve to `SavedLocationsScreen`.

## F18

SavedAddressesScreen: The headline is given no `maxLines` and no `overflow` by `OmdsEmptyState`, so on the 320x568 compact phone it wraps to two lines rather than truncating (measured: max intrinsic width > laid-out width, laid-out height > single-line height). Not wrong on its own, but it is what consumes the vertical margin before the overflow above bites.

## F19

SavedAddressesScreen: `SavedAddressesScreen` is a live entry in the designer-facing Screen Catalog (`batch_10_entries.dart`, feature 'settings') while its own source comment marks it ORPHAN (JEBV4-227, verified 2026-07-12) — superseded by `SavedLocationsScreen`. Designers can sign off on a placeholder the app has no route to. Flagged, not changed: removing a catalog entry is a product call, not a preview one.

## F20

SettingsScreen: Dead destructive state machine: nothing in lib/ calls SettingsCubit.requestAccountDeletion() or signOut(). Both Account rows open LogoutDeleteConfirmSheet, which clears the session through its own AccountSessionTerminator (dio_account_session_terminator.dart) and never touches the cubit. So `deletionPending`, `isDeletingAccount` and `isSigningOut` are set by no production path, and the E20/JEBV4-215 copy 'Scheduled for deletion. Sign in again to cancel.' can only be produced by a fixture or by test/settings_screen_test.dart — never by a user.

## F21

SettingsScreen: The whole BlocConsumer banner path in _SettingsView (listener + _bannerMessage) is unreachable. Four of the five SettingsBanner values are only emitted by the cubit methods above; the fifth (profileSaved) is emitted by saveProfile, which only ProfileEditScreen calls — and app_router.dart gives the `settings-profile` route its OWN BlocProvider<SettingsCubit> (documented crash fix, 2026-07-24), so that emission lands on a different cubit instance than the one this screen listens to. Additionally listenWhen fires only on a CHANGE, so a cubit that arrives already holding SettingsBanner.networkError renders no error at all.

## F22

SettingsScreen: No loading affordance: state.isLoading is read by nothing in _SettingsView. During the cold read the list is fully painted and fully tappable, and the profile row shows the same 'Add your name' placeholder a user with no name saved gets — the only difference is the subtitle, and only because the phone has not loaded yet (asserted in the render test 'cold read differs from "no name saved" by ONE subtitle'). The Profile row still pushes `settings-profile` mid-read, and that route seeds its name field from initState, so a tap during the window opens an editor primed with an empty name.

## F23

SettingsScreen: A failed profile read is indistinguishable from the cold read and cannot recover. SettingsCubit.load() (settings_cubit.dart:53) does not catch: a throwing ProfileRepository escapes as an unhandled Future error from the `..load()` cascade at settings_screen.dart:74 and leaves isLoading latched true, which load()'s own `if (state.isLoading) return;` guard then treats as 'already loading' forever. The screen shows the placeholder profile row with no error and no retry, permanently.

## F24

SettingsScreen: The only in-flight feedback for a destructive action is two rows dropping to 38% opacity with their taps nulled — no spinner, no banner, nothing that says a request is going (preview 'Destructive actions in flight'). Moot today because of the first finding, but it is what the screen would show if that cubit path were ever wired back up.

## F25

DiagnosticsScreen: A FAILED listing is byte-for-byte the EMPTY state. `_enabledBody` (lib/core/diagnostics/diagnostics_screen.dart:176) reads `snapshot.data ?? const <DiagSessionFileInfo>[]` and never inspects `snapshot.hasError`, so a loader that throws paints the same 'No session files yet' / 'No session directory yet' / 'Appears once a session file exists' surface a genuinely empty directory paints — no error, no retry, no mention of the cause. The render test proves the equality by comparing the full set of painted strings. Production masks it one layer earlier: `defaultSessionsLoader` wraps the whole listing in `catch (_) { return const <DiagSessionFileInfo>[]; }`, so an EACCES, a missing dir, or a failing `stat` lands on the same empty state. A tester whose session files do not show up has nothing to go on.

## F26

DiagnosticsScreen: The Export section is unbounded and pushes the sessions list off-screen. `OmdsSettingsRow` gives neither its title nor its subtitle a `maxLines` or an overflow policy, and both export subtitles are unbroken machine strings — the on-device folder path, and the `adb pull "<path>" <name>` fallback built from it. With an iOS-container-length path (which is exactly what `defaultSessionsLoader` produces on iOS via `getApplicationSupportDirectory()`), the Export section alone is taller than a 600 pt viewport: `diag-session-row-0` — the reason the screen exists — is not merely below the fold, it is not built until you scroll. Pinned in the test ('the longest session title survives — once you scroll past the export section').

## F27

DiagnosticsScreen: The refresh action stays live in the release-like body. The `Scaffold.appBar` is built outside the `!Diag.enabled` branch (diagnostics_screen.dart:152-166), so when diagnostics is disabled the app bar still shows `diag-refresh`, and tapping it runs `_refresh()` → `Diag.flushPersistent()` + a full directory listing whose result no body will ever render. A dead control plus pointless IO on the one build where this screen is meant to do nothing.

## F28

DiagnosticsScreen: The loading body blanks the entire surface behind an unlabeled spinner. `_enabledBody` returns a bare `Center(child: CircularProgressIndicator())` for any non-`done` connection state, and `_load()` awaits `Diag.flushPersistent()` BEFORE it lists — so on a large buffered session the user sees a spinner with no app-bar hint and nothing naming what is being awaited, and a hung flush looks identical to a slow directory read. Lower severity than the three above, but it is what the 'Loading · listing files' card shows.

## F29

ProfileUnavailableScreen: The body cannot scroll, so at 200% text on a 320 pt phone the only instruction on the screen is clipped off the display. `Scaffold > Center > OmdsErrorState > Column(mainAxisSize: min)` has no `SingleChildScrollView` anywhere in the chain (asserted: zero `Scrollable` descendants of `ProfileUnavailableScreen`). Measured on the 320x568 window at textScale 2.0: `RenderFlex overflowed by 164 pixels` in EN and 124 px in AR, with the message laid out from y=424 to y=744 against a display edge at y=600 — 144 of its 320 pt are off-screen and unreachable by any gesture. This is the screen a user lands on when something has ALREADY gone wrong, and the half that gets cut is 'We couldn't load this profile. Please go back and try again.' Fix is a scroll view around the body, which every other error surface in the app already has.

## F30

ProfileUnavailableScreen: The screen's only affordance is an app-bar arrow that silently does nothing when the screen is the stack root — and stack-root is how shipped code reaches it. `OMDSAppBar._buildBackButton` defaults to `Navigator.of(context).maybePop()`, a no-op on a lone page; `ProfileUnavailableScreen` passes no `onBackPressed` and gives `OmdsErrorState` no `onRetry`, so there is exactly one tappable control (asserted: one `IconButton`, zero `ButtonStyleButton`). `password_security_screen.dart:132` calls the stack-REPLACING `context.goNamed('customer-profile')` with no `extra`, and `app_router.dart:945` falls through to this screen in release whenever the typed `extra` is absent — leaving one page in the Navigator. `RootAwareBackScope` (backFallbacks['customer-profile'] = '/') rescues only the Android system BACK gesture, because it intercepts at `BackButtonListener`; it does not touch the arrow, and iOS has no such gesture. Proven in the test: tapping the arrow at stack root leaves the screen mounted, no exception, no navigation.

## F31

ProfileUnavailableScreen: The title string is rendered twice — `OMDSAppBar(title: l10n.profileUnavailableTitle)` and `OmdsErrorState(title: l10n.profileUnavailableTitle)` — so every window shows 'Profile unavailable' stacked directly under 'Profile unavailable' (asserted: `findsNWidgets(2)`, and 2x the Arabic string in AR). Cosmetic at 100% on a phone; in the compact 200% window the restatement alone occupies 224 pt of the 512 pt the body has, i.e. 44% of the space is spent repeating the app bar in the one window that has already run out of room.

## F32

KycStatusScreen: Clipped at the accessibility ceiling with no way to recover: `OmdsEmptyStatePage` is `Scaffold(body: Center(child: OmdsEmptyState(...)))` and `OmdsEmptyState` is a bare `Column(mainAxisSize: min)` — there is no Scrollable anywhere inside `KycStatusScreen` (asserted). On a 320x568 display at 200% text the column asks for 668 pt of the 520 pt the padded window offers: 'RenderFlex overflowed by 148 pixels on the bottom', in EN and AR alike. Nothing can absorb the shortfall, so the ends of the composition are cut off and unreachable — no scroll gesture brings them back. (The 148 pt figure is inflated by the wider `FlutterTest` font; the structural claim — no scrollable, nothing that gives way — is font-independent.)

## F33

KycStatusScreen: The 100 pt icon does not follow the text scaler: `OmdsEmptyStatePage.iconSize` defaults to a fixed 100 and the screen does not override it, so at 200% the text doubles around an illustration that stays exactly as tall. Measured identical (100x100) at 100% and at 200%. This is why the column can only grow and never rebalance, and it is what tips the compact window into the overflow above.

## F34

KycStatusScreen: The copy is hardcoded English, not localized. `'KYC Status coming soon'`, `'This screen is not yet available.'` and the `Semantics.label` are string literals in `build`, not `AppLocalizations` lookups, so the AR RTL card renders English inside a right-to-left layout (asserted under `Locale('ar')`). Every comparable placeholder in this family goes through the ARB.

## F35

KycStatusScreen: The `Semantics` wrapper double-announces. `Semantics(container: true, label: 'KYC Status coming soon. This screen is not yet available.')` wraps a subtree that already publishes both sentences as `Text`, and does not set `explicitChildNodes`, so the wrapper label and the two Texts MERGE into a single node whose label reads 'KYC Status coming soon. This screen is not yet available.\nKYC Status coming soon\nThis screen is not yet available.' A screen reader reads the pair, then reads it again. Asserted (2 occurrences of each sentence in one merged node).

## F36

KycStatusScreen: No in-app way out. The screen passes `appBar: null` and supplies no `buttonText`/`onButtonTap`, so the rendered Scaffold has no app bar, no back affordance and no action of any kind — a user who lands here can only leave via the OS back gesture. Related: because `appBar: null` consumes no top inset and `Scaffold` does not `SafeArea` its body, the only thing keeping content clear of a 59 pt notch is that the column is centred and short (asserted at 393x852/200%: 164 pt of top clearance). One more line of copy and text starts sliding under the status bar.

