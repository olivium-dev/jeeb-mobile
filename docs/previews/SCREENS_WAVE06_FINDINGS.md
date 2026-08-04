# Screens wave 06 (account_status, active_delivery, auth, biometric, cancellation)

7/7 written, 57 previews, 0 agent errors.

## F01

AccountStatusScreen: The `failed` branch has no way off the screen. `AccountStatusGate` forces this route and blocks ALL tab access, and both exits (`account_status_support_cta`, `account_status_signout_cta`) are built inside the `loaded` case of `_AccountStatusView`. A failed status read leaves an icon, one sentence and a Retry. With `AccountStatusFailure.unauthorized` the token is rejected deterministically, so Retry is a button that cannot succeed and there is no sign-out anywhere on the surface to escape with.

## F02

AccountStatusScreen: `AccountStatusL10n.loadError` is a single getter for all three typed failures, so a dead session (401) and a 5xx are both reported as "Couldn't load your account status. Check your connection and try again." Pinned by a test that renders the `unauthorized` twin and finds the identical string — which is also why the section ships one error preview instead of two.

## F03

AccountStatusScreen: `_BlockedBody` is a `SafeArea` → `Padding` → `Column(mainAxisAlignment: center)` with no scroll fallback, and it breaks on the app's OWN copy: the suspended state with NO server text overflows a 320x568 device by 62 pt at 150% text and 344 pt (EN) / 120 pt (AR) at 200%. A one-line server reason overflows the same device by 176/80 pt at 200%.

## F04

AccountStatusScreen: A paragraph-length `statusReason` — free text a human agent types, rendered verbatim — needs no large text scale at all: 212 pt of bottom overflow on a 320x568 device at 100%, 320 pt on a 390x844 phone at 150%, 1052 pt at 200%. What goes past the fold is the support CTA and the sign-out CTA, i.e. both exits from a screen the gate will not let the user leave.

## F05

AccountStatusScreen: The overflow is invisible to every existing assertion: the semantics nodes survive, so `find.bySemanticsIdentifier('account_status_support_cta')` still returns one widget while the button is painted off the bottom of the device. Only the RenderFlex error reports it.

## F06

AccountStatusScreen: `OmdsErrorState`, which the failed branch renders, centres a `Column(mainAxisSize: min)` with no scroll fallback either — 36 pt of bottom overflow on a 320x568 device at 200% text, where the thing past the fold is the Retry, the only control on that surface.

## F07

AccountStatusScreen: The server `reason` is dropped verbatim into a `Text` with no `Directionality` of its own, and `statusReason` is not localized. In an Arabic build the English sentence is laid out with an RTL base direction, so the neutral characters at its edges resolve to RTL and the trailing period is painted at the LEFT end of the last line, directly under a genuinely Arabic banner.

## F08

AccountStatusScreen: The loading surface carries no copy at all — `OmdsLoadingState` is constructed with `message` left null, so the whole screen holds exactly ONE `Text` (the app bar's "Account unavailable"). Combined with `AccountStatusCubit.load()`'s re-entry guard (`status != initial` returns early), a hung `GET /v1/users/me` parks a blocked user on a bare spinner with no copy, no retry and no exit.

## F09

AccountStatusScreen: `account_status_signout_cta` calls `LogoutDeleteConfirmSheet.show(context, mode: both)` with no terminator argument, and the sheet self-provides a `DioAccountSessionTerminator(resolveGatewayDio(), AuthTokenStore())` when DI has nothing registered. There is no seam on the screen to inject an inert one, so confirming inside the canvas or the Screen Catalog is a real logout attempt and `CatalogNetworkGuard`'s POST rejection is the only thing between it and the gateway. (Opening the sheet is safe — `_terminator` is `late` — which the render test pins.)

## F10

ActiveDeliveryJeeberScreen: Dead-end unavailable shell: with both `cubit:` and `repository:` null, `build` returns `_Unavailable` — an app bar plus the single sentence "Delivery details unavailable.", no retry, no reload, no route out — yet it still carries the `mark_delivered_root` semantics identifier, so the seam route pin and any Maestro flow that asserts only that id passes on a surface where the jeeber cannot complete the delivery they are standing at the door of (active_delivery_jeeber_screen.dart:138-154).

## F11

ActiveDeliveryJeeberScreen: The load-error message is never localized. `_buildBody` falls back to `l10n.activeDeliveryLoadError` only when `state.errorMessage` is null, but `ActiveDeliveryCubit._mapLoadError` always returns an English literal ('Unable to load delivery' / 'No internet connection' / 'Delivery not found'), so the localized string is dead code and an Arabic user gets an English error under an Arabic app bar (screen line 245-249 vs active_delivery_cubit.dart:850-858).

## F12

ActiveDeliveryJeeberScreen: The loading state renders zero text: `Center(child: OmdsLoadingState())` with no message, no title and nothing for a screen reader to announce — and no timeout or cancel, so a stalled `GET /v1/deliveries/{id}` holds a blank spinner indefinitely. It is also the first frame of every cold deep-link from a `type=delivery` push (screen line 243-244).

## F13

ActiveDeliveryJeeberScreen: The mark-delivered panel is titled with the STAGE label `l10n.activeDeliveryStatusDone` = "Done", so while the delivery is In Transit the panel heading reads "Done" directly under a stepper whose fifth (upcoming) stage is also labelled "Done" — the word appears twice on the same screen with two different meanings (mark_delivered_panel.dart:83-86).

## F14

ActiveDeliveryJeeberScreen: `_QuickActions`' single-row branch is unreachable on every supported handset: it stacks below `_kInlineQuickActionsMinWidth` (448) and a 390 pt phone leaves the padded `ListView` 358 pt, so "Open in Maps"/"Open Chat" always stack in production and only a tablet/landscape canvas ever renders the Row (screen lines 20, 625-648; pinned by the 'quick actions STACK at phone width' test).

## F15

ActiveDeliveryJeeberScreen: A `disputed` (FailedNeedsEscalation) delivery loses every affordance. `_ReadyContent` short-circuits to `_UnsuccessfulTerminalContent` for all three unsuccessful terminals, so the jeeber gets an empty state with no Open Chat, no maps and no support entry — on the ONE status that is not really final (SM edges 12/13 let an admin resolve it, which is why the cubit deliberately keeps watching the row, P6/A2). Cancelled and expired are correct here; disputed is the same dead end for an open case (screen lines 331-333, 421-476).

## F16

ActiveDeliveryJeeberScreen: The GPS-permission banner is only reachable from the ready/transitioning branch. `state.isGpsBlocked` is mirrored into the state regardless of mode, but `_buildBody` returns the spinner or the error state for `loading`/`error`, so a jeeber whose uploader is parked sees nothing at all while the delivery read is slow or failing — the customer's map is empty and the one recovery CTA is not on screen (screen lines 242-249 vs 360-367).

## F17

ActiveDeliveryJeeberScreen: `ActiveDeliveryMode.ready` with a null delivery renders `SizedBox.shrink()` — a silently blank body under the app bar, with no message and no retry. Defensive today (no cubit path emits it), but it is the one branch that fails invisibly rather than loudly (screen line 252-253).

## F18

SetPasswordScreen: One sentence is rendered for six different causes. `_SetPasswordViewState.build` reads only `state.hasError` and paints the hardcoded `l10n.setpwValidationError` ("Passwords must match and meet the strength requirements."). That is what `SetPasswordValidation.mismatch`, `.weak` and `.empty` all show, AND what every server `AuthFailure` shows (`network`, `invalidToken`, `badRequest`, `unknown`). A user whose request never left the phone is told their passwords do not match. The discriminator exists on the state — `validation` and `failure` are separate fields and `SetPasswordCubit.submit` is careful to clear one when it sets the other — and the screen throws it away. There is no `setpwNetworkError` / `setpwWeak` / `setpwMismatch` key in either ARB to fix it with. Pinned by the `one sentence for four causes` test.

## F19

SetPasswordScreen: The in-flight submit has no progress affordance at all. `SetPasswordStatus.submitting` only sets `isEnabled: !submitting` on the CTA (which `OmdsPrimaryButton` paints as a 45%-alpha fill) and `enabled: !submitting` on the two fields. The label still reads "Save password" and there is no `CircularProgressIndicator` / `LinearProgressIndicator` anywhere on the surface — `OmdsPrimaryButton` has no loading state and the screen adds none. On a slow gateway the screen is indistinguishable from a disabled/broken form.

## F20

SetPasswordScreen: The strength floor is never stated, before OR after it is failed. `SetPasswordPolicy` requires 8 characters with at least one letter and one digit; no helper text sits under either field, neither field is marked required, and the error copy only says "meet the strength requirements" without naming them. There is nothing on the surface for the user to aim at.

## F21

SetPasswordScreen: The submit CTA is live on an empty form. `isEnabled: !submitting` is the entire gate, so the first action available on the idle screen is to submit nothing — which `SetPasswordPolicy.validate` (emptiness is checked first) turns into `SetPasswordValidation.empty`, i.e. the mismatch/strength sentence about two fields the user never typed in. This is likely the most common failure on the screen.

## F22

SetPasswordScreen: `mode` is dead plumbing. `SetPasswordMode` has exactly one value, `SetPasswordMode.fromQuery` ignores its argument entirely, `SetPasswordScreen` threads `mode` into `_SetPasswordView`, and `_SetPasswordView.build` never reads `widget.mode`. Three layers of a field that changes no pixel and no behaviour; the analyzer does not flag an unread widget field.

## F23

SetPasswordScreen: The typed password is not part of the state. Both `TextEditingController`s live in `_SetPasswordViewState` while the two `obscured` flags live in `SetPasswordCubit`, so the form is split across two owners. Consequences: no fixture, catalog entry or restored screen can put characters in the fields (the `Both fields revealed` preview can only show flipped eye icons over empty boxes), and a cubit rebuild resets the eyes to masked while the typed text stays.

## F24

BiometricLockScreen: No scroll view anywhere in the body chain (SafeArea → BlocBuilder → Center → Padding → Column), so at 320×568 / 200% text the gate overflows on the FIRST FRAME of the idle arrival state — measured 124 pt EN. That leaves 4 pt of the 48 pt biometric_unlock_authenticate_cta above the display edge and puts biometric_unlock_use_password_link 56 pt below it. In the failed state the same window overflows by 328 pt EN / 216 pt AR, putting the CTA 200 pt and the link 260 pt off-screen. Nothing scrolls and this is a router-held gate with no other exit, so the failure mode is 'cannot enter the app', not 'looks cramped'. 390×844 @200% is fine in both locales, which is why it went unnoticed.

## F25

BiometricLockScreen: biometricLockFailure reads 'Biometric check failed. Try again or use your PIN.' and there is no PIN entry on this screen, in lib/features/biometric_auth/, or on the /lock route — asserted: zero TextField/EditableText in the failed state. Worse, BiometricLockCubit.evaluate() counts hasPin() as a reason to LOCK (canChallenge = available || hasPin), so a PIN-enrolled user on a device whose platform biometric is unavailable is held here BY their PIN and then given no way to enter it. On the shipped UnavailableBiometricGateway (hard-returns false) that user's CTA can never succeed — verified with biometricLockScreenPinOnlyCubit: tap → gateway called once → still on /lock with the retry label.

## F26

BiometricLockScreen: 'Use password instead' (biometricUnlockUsePasswordLink) leads to no password. _usePasswordFallback routes to /register, the phone-OTP entry, because the email/password funnel was deleted in JEBV4-199 — while the ARB metadata for the key still documents the destination as '→ /login'. Same mismatch in AR ('استخدم كلمة المرور بدلاً من ذلك'). Pinned by a render test that follows the tap to a labelled /register stand-in. (The AC3 release-then-goNamed ORDERING itself is sound — proved against a fixture gate that would bounce a premature move.)

## F27

BiometricLockScreen: BiometricLockCubit._osPromptReason is the hardcoded English literal "Confirm it's you to open Jeeb", handed straight to the gateway. An Arabic user gets a fully localized screen and then an English system biometric sheet. It is the only user-visible string on this flow that never passes through a Text widget, so no preview, golden or screenshot can surface it — the fixture's fake gateway records it and the test asserts the AR run still receives the English string.

## F28

BiometricLockScreen: The prompting state gives no in-app feedback at all: same title, same body, same CTA label, only the fill dims. There is no spinner and no copy saying the OS is being asked. On Android the system sheet normally covers this, but on a device where the sheet fails to appear this frame is the entire feedback the user gets. (The tap IS genuinely blocked, not merely discouraged — asserted zero gateway calls — so this is a feedback gap, not a double-submit hazard.)

## F29

BiometricPromptScreen: Half the screen's copy is hardcoded English with no ARB key. `_PromptHeader`'s subtitle ('Sign in quickly with your fingerprint or face', biometric_prompt_screen.dart:92) and `_PromptAction`'s CTA label ('Authenticate', :113) are string literals, while the heading directly above them is `l10n.useBiometrics`. The AR preview renders an Arabic heading over two English lines; neither string exists in lib/l10n/app_en.arb or app_ar.arb. Asserted in the test's `Arabic` group.

## F30

BiometricPromptScreen: `BiometricState.failed` renders NOTHING. `_PromptAction` has no branch for it, so it falls through to `SizedBox.shrink()` (:125): a user rejected by the OS prompt sees the same invitation to authenticate with the button removed — no error, no retry, no password fallback, and no app bar or back affordance. Nothing can emit `available` again, so one wrong finger is a permanent dead end.

## F31

BiometricPromptScreen: `BiometricState.authenticated` also renders nothing, and the screen has no `BlocListener`, no `onAuthenticated` callback and no navigation — so a SUCCESSFUL sign-in is pixel-identical to a failed one. Both terminal outcomes of `authenticate()` are invisible.

## F32

BiometricPromptScreen: Three of `BiometricState`'s six values (`initial`, `failed`, `authenticated`) produce the identical surface, which is why the previews need a caption to be told apart at all. `_PromptAction` branches on only three values and has no default/exhaustive handling, so any state added to the enum silently renders a headless prompt.

## F33

BiometricPromptScreen: At the accessibility ceiling on the smallest supported display (320x568, 200% text) the screen OVERFLOWS by 260 px: `_PromptColumn` (:61) is a bare centred `Column` inside `Center` inside `SafeArea` with no scroll view above it, and the localized `biometricNotAvailable` sentence is laid out past the bottom edge and clipped with no way to reach it. Measured and asserted in the `compact at 200% text` group.

## F34

BiometricPromptScreen: The `checking` loading state is unreachable in production. `BiometricCubit.checkAvailability()` is `emit(checking); emit(available);` with nothing awaited between them (biometric_cubit.dart:8-12), so no frame is ever built on the spinner; the same is true of `authenticate()`. Additionally `OmdsLoadingState` is built with no `message`, so when a real `local_auth` round-trip does land there is no copy — localized or otherwise — labelling what is being checked.

## F35

BiometricPromptScreen: The screen's error state is a bare unstyled `Text` (:123) with no icon, no error styling and no route onward — and it sits directly under the hardcoded 'Sign in quickly with your fingerprint or face', so the screen invites the user to do the thing it simultaneously says is impossible.

## F36

CancellationScreen: A failed cancellation has NO rendering. `CancellationSuccess`/`CancellationTooLate`/`CancellationError` are consumed only by a `BlocListener`, which never fires for the state a cubit is constructed in — so the DT-04 `initialState:` seam that can preset 'submitting' cannot preset 'failed', and there is no inline error surface to preset either. The entire feedback for a rejected cancel is a 4-second floating snackbar, and it uses `showOmdsSnackbar` (neutral) rather than `showOmdsErrorSnackbar`, so the failure is not even coloured as one. Pinned in the render test: after the snackbar expires the form is indistinguishable from one nobody submitted.

## F37

CancellationScreen: The Jeeber reason list is unreachable in the shipped app. `isJeeber` comes from `?role=jeeber` (app_router.dart:860), but the only in-app entry point — `_CancelButton` in lib/features/deep_link_targets/delivery_detail_screen.dart:697 — pushes `/orders/$deliveryId/cancel` with no query, while sibling actions in that same file read `RoleCubit` and append `?mode=jeeber` (lines 445-454). A Jeeber cancelling a delivery is offered the client reasons; `cannot_complete`, `vehicle_issue`, `emergency`, `prohibited_item` are dead in production.

## F38

CancellationScreen: Selecting 'Other' enables Confirm with the free-text box EMPTY: nothing validates `cancellation_other_field`, so the submit sends `otherDetails: ''` and the reason the field exists to capture is never given. Proven by tap-through in the render test (empty box -> Confirm -> success sheet).

## F39

CancellationScreen: A 409 leaves the delivery re-submittable indefinitely. `CancellationTooLate` disables nothing and marks nothing: after the snackbar expires the same Confirm produces the same snackbar, forever. Pinned in the render test.

## F40

CancellationScreen: The in-flight state is signalled ONLY by the button (label swaps to 'Cancelling…', greyed). No overlay, no progress indicator, no dimming — and the reason rows stay live, so a tap moves the radio underneath a POST that has already gone out with a different reason.

## F41

CancellationScreen: At the 200% accessibility ceiling on the 320x568 device, ONE of five reasons is on screen. The prompt grows to 144pt and the 48pt CTA holds its size, both OUTSIDE the scroll view, leaving the reason list 208pt for ~784pt of rows: reason 1 ends at 480, the fold is 488, reason 2 starts at 496. There is no scrollbar, fade or shadow, so a five-option radio group reads as a one-option list. Arabic at 200% on 390x844 still cuts the fifth row (736->784 against a viewport ending at 764). Nothing overflows, so none of this is visible without previewing at a real device size.

## F42

CancellationScreen: The pinned Confirm CTA clips its own label at 200% text: `OmdsPrimaryButton` is a fixed 48pt while 'Confirm Cancellation' needs 120pt at that scale (measured via RenderParagraph.getMaxIntrinsicHeight and pinned in the test). The control that commits the cancellation is laid out into a third of the height its text asks for, silently — no overflow stripe.

## F43

CancellationScreen: `_CancellationViewState._reasons(AppLocalizations l10n)` never reads its parameter — the reason CODES are hardcoded and localization happens later in `_label`. Harmless but misleading: the role split is a bare `if (widget.isJeeber)` that no l10n layer can see.

## F44

DevChatPreviewScreen: SILENT SELECTOR FALLBACK — both dispatch arms in lib/features/chat/presentation/dev_chat_preview_screen.dart accept anything. `_isDeliveryMan` is `selector.startsWith('dm')` and `_clientPreview()`'s switch closes with `_ => accepted`, so no selector is ever rejected. `accepted-thread` renders the client accepted thread and `dm-order-picke` renders the plain jeeber thread — both pixel-identical to a correct capture, neither logged nor thrown. On a screen whose entire purpose is capturing named Figma frames deterministically, a typo in the `jeeb.state` dev-seam knob yields the WRONG frame filed under the RIGHT label. Previewed deliberately as `Unrecognised selector · silent fallback`; the `dm`-prefixed half is worse and cannot be previewed at all, because it is indistinguishable from `Jeeber · accepted thread`.

## F45

DevChatPreviewScreen: THE AUTO-OPENED CONFIRM SHEET ESCAPES ANY NON-FULLSCREEN HOST. `_DeliveryManPreviewState.initState` post-frame-calls `ConfirmDeliveryActionSheet.show(context, ...)`, which is `showModalBottomSheet` with the default `useRootNavigator: false` — it resolves to the nearest ancestor Navigator, not to this screen. In the Screen Catalog, which already ships both sheet states (`_chatScreenEntry` in lib/devtool/catalog/entries/batch_02_entries.dart), that navigator is the CATALOG's: the sheet and its navy scrim cover the whole designer-facing tool rather than the chat behind them, and dismissing it drops the designer back into the catalog. This is why lib/features/chat/presentation/chat_screen.dart's own preview section explicitly refuses to preview these two selectors. The previews here only work because `_devChatPreviewScreenSheetHosted` wraps the screen in a local `Navigator`; the screen itself has no way to confine its one side effect.

## F46

DevChatPreviewScreen: `_bannerTrailing` gives the two confirm-sheet states a DISMISS × that the frame they are built on does not have. `dm` returns `ChatFeeBannerTrailing.none` and `dm-order-picked` returns `orderPicked`, but `dm-confirm-picking` / `dm-confirm-heading-off` fall through to `dismiss`. So the captured sheet frames are not "the jeeber thread plus a sheet" — the fee banner underneath has gained an affordance, purely as a consequence of the fallthrough arm rather than a decision. Worth checking against Figma 56618:2751 / 56618:2852 before those captures are signed off.

## F47

DevChatPreviewScreen: Every rebuild allocates a `DevChatFixtureGateway` that is never disposed. Both `_clientPreview()` and `_DeliveryManPreviewState.build()` construct the gateway INSIDE `build`, and `DevChatFixtureGateway` opens a broadcast `StreamController` in a field initializer with a `dispose()` that nothing in this screen ever calls. `ChatScreen`'s `BlocProvider.create` runs once, so every rebuild after the first constructs a controller that is immediately abandoned. Harmless on the emulator-capture path it was written for; in the preview canvas, whose whole loop is hot reload, it is an unbounded stream of never-closed controllers.

