# Wave 18 (jeeber_request_detail, order_history, app, misc) — defects

8/8 written, 45 previews. First wave written directly into the co-located layout.

## F01

JeeberRequestDetailLoader: JeeberRequestUnavailableScreen (lib/features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart:46) interpolates the RAW route UUID into its subtitle — the jeeber reads 'Request e30b7f2e-7914-402d-8dd3-e699e6775eae is no longer available.' The resolved branch of the SAME loader, for the SAME id, renders '#775EAE' via friendlyReference. sprint-009 audit §T5 is applied on one branch of this router and not the other; putting the two previews side by side is what makes it obvious.

## F02

JeeberRequestDetailLoader: At 200% text in the 390x700 box the previews declare, the unavailable dead end overflows by 240 dp (EN) / 72 dp (AR) and lays 'Browse other requests' — the ONLY thing on that screen a jeeber can act on — at y 872 / y 704, entirely below the viewport. It is a bare centred Column with no scroll view (find.byType(Scrollable) findsNothing), so there is nothing to scroll it back. The resolved branch survives the identical box (0 overflow, 'Send your offer' at y 568–616) because its summary is in a SingleChildScrollView and its action bar is pinned — so this is a defect, not a house style. Part of the extra height is finding #1: the 36-char UUID is several lines at 200% where '#775EAE' would be one.

## F03

JeeberRequestDetailLoader: A dead request and a dead network are the same screen. _recover swallows every fetch error (loader lines 102-106) and falls through to the same terminal state, so 'expired / matched to another jeeber' and 'the jeeber is offline' render identical copy with no offline notice and no retry — and the only affordance re-issues the same failing read. The two previews differ only in the id they happen to print.

## F04

JeeberRequestDetailLoader: JeeberRequestDetailLoadingView takes a requestId and never renders it (build() uses only l10n.jeeberRequestDetailTitle + a spinner). Consequence: the `loading` and `redirecting` resolutions are pixel-identical — asserted in the render test by comparing every Text rect — so 'still fetching' and 'about to jump to a delivery you already own' are indistinguishable, and there is no reference on screen to tell a user or a support agent which request is being fetched.

## F05

JeeberRequestDetailLoader: _JeeberRequestDetailLoaderState reads widget.initial / widget.requestId only in initState and implements no didUpdateWidget, so a rebuild IN PLACE with a new requestId keeps the previously resolved request on screen. app_router.dart:1299 builds JeeberRequestDetailLoader(requestId: id, ...) with no key, so a same-route navigation to a different id (e.g. a push tap for request B while sitting on request A's detail) would reuse the State and show A. This is not hypothetical — it bit the render test: two previews pumped back-to-back reused the State and the second silently rendered the first one's request, which is why the test carries a _pumpFresh helper. Not fixed here (production change, out of scope), and not asserted as a contract.

## F06

JeeberRequestDetailLoadingView: `requestId` is a required constructor parameter that `build()` never reads — the loading scaffold cannot say WHICH request it is recovering. Nothing on screen identifies it: not the raw UUID, not the `friendlyReference` short form (`#75EAE`) the resolved detail screen shows. Pinned by `the requestId never reaches the screen`.

## F07

JeeberRequestDetailLoadingView: `_Resolution.loading` and `_Resolution.redirecting` render the identical frame, so a jeeber cannot tell 'still fetching your request' from 'about to be moved to a delivery you already own'. With no elapsed hint, retry or cancel — the only control is the app-bar Back button (`Navigator.maybePop()`) — a stalled run-22 redirect is indistinguishable from a slow network. Pinned by measuring both frames with different ids.

## F08

JeeberRequestDetailLoadingView: The spinner is centred in the BODY, not the screen: 47 dp status bar + 56 dp toolbar come off the top and only the 34 dp home indicator off the bottom, so on a 390 × 844 phone the one moving element sits 34.5 dp BELOW the optical centre of the glass. Invisible without a pinned device frame; now asserted.

## F09

JeeberRequestDetailLoadingView: The app-bar title is the DESTINATION's title ('Request details') shown before any details exist, and it is the only text on the screen. The surface reads as an empty details screen rather than a loading one — there is no 'finding your request' copy anywhere in the ARB for this state.

## F10

JeeberRequestDetailLoadingView: Text-scale risk worth a look in the canvas: the toolbar reserves the title only 216 dp on a 320 dp phone (286 dp on a 390 dp one) while Material scales the title by 1.34 at a 2.0 scaler. Whether the shipped font still fits 'Request details' in 216 dp cannot be settled by a widget test — flutter_test lays text out in the square test font, where it is truncated at both widths — so `Compact 320 × 568 · EN 200%` exists to be READ in the canvas. The test pins the band arithmetic, the 1.34 clamp ratio and containment, deliberately not the truncation.

## F11

OrderHistoryCard: order_history_card.dart:170 `_Footer` — the amount `Text` is not wrapped in `Flexible`/`Expanded`, so the Row lays it out at its natural width FIRST and the `Expanded` tier label gets whatever is left, possibly zero. A non-USD MoneyFormat token blows the Row: `LBP 1,335,000.00` (a $15 delivery at the 2026 peg, not a synthetic number) throws `A RenderFlex overflowed by 20 pixels on the right` at 150% text and by 132 px at 200%, at 390 pt width. `$1,234.00` survives 200% comfortably — the defect is currency-shaped, not just scale-shaped, and LBP is a shipping currency. In AR the same overflow runs off the leading edge. Thresholds measured under the flutter_test font (wider than Roboto), so the real-device trigger point is higher, but the failure mode and its ordering across currencies are font-independent. Same class of bug OfferCard already documents for its fee pill.

## F12

OrderHistoryCard: order_history_card.dart:175 `_Footer` — the tier label `Text` has no `maxLines`/`overflow`, unlike the two `_AddressLine` texts (which correctly use `maxLines: 2` + ellipsis). Once a wide amount squeezes its `Expanded` slot the label WRAPS instead of ellipsizing and the card silently grows: 156 pt → 188 pt at 100% text with `LBP 1,234,567,890.99`. That is a reflow inside a scrolling list, and it happens before any overflow warning fires, so no existing test can see it.

## F13

OrderStatusChip: Light-mode `errorContainer` is a saturated FILL, not a container tone: the Cancelled/Disputed pill paints #B00020 under white ink while its two neighbours are pale tints (#FFDBD1 active, #DCFCE7 completed). Cause is in AppTheme, not the chip — `AppTheme.light()` builds `ColorScheme.light(...)` and passes no `errorContainer`/`onErrorContainer`, so Flutter's getters fall back to `error`/`onError`. `AppTheme.dark()` uses `ColorScheme.fromSeed` and DOES get the real tonal pair (#93000A/#FFDAD6), so the same chip is a different kind of surface in the two themes. Contrast passes either way (7.33:1 light, 7.24:1 dark); the weight/hierarchy is what is wrong. This is the exact tone-pair mistake AppTheme's own `_jeebOrangeContainer` comment documents fixing for the brand orange, still live on the error role.

## F14

OrderStatusChip: `disputed` and `cancelled` are pixel-identical pills. `_paletteFor` switches on `status.tab`, and both statuses bucket to `OrderHistoryTab.cancelled`, so an OPEN dispute (needs the customer to act) is indistinguishable from a closed cancellation except by reading the word. The app already ships an unused `warning` role (`JeebColorRoles.warning`) intended for exactly this. Pinned by a test in the new preview suite so the collision is known to be the current contract rather than a canvas artefact.

## F15

OrderStatusChip: Colour carries no information inside the Active bucket: pending / matched / pickedUp / enRoute AND `unknown` all render the same `primaryContainer` pill. An unrecognised backend status is therefore visually identical to a confirmed "En route" — the label is the chip's entire signal, which raises the cost of any label that fails to localize or fit.

## F16

OrderStatusChip: At the 200% text ceiling the card header nearly quadruples in height — 24pt to 80pt, measured with Inter at the real 358pt row width. The chip is the non-flexible child of `_Header`'s Row, so it is measured against unbounded width and grows first (81pt to 133pt); the `Expanded` date takes the remainder and WRAPS to two lines. Nothing clips and nothing overflows, but the existing comment at lib/features/shell/tabs/orders_tab.dart:368 asserts the date "must ellipsize rather than push the chip off the trailing edge" — neither `_Header`'s `Text` nor the chip's sets `maxLines` or `overflow`, so it wraps instead. That comment describes behaviour the code does not have.

## F17

OrderStatusChip: Arabic squeezes the header harder than English, the reverse of the usual direction in this app: the AR date string is 23 characters against 19, and the AR "Picked up" chip measures wider than the EN one. The repo's 200%-text goldens are EN-only, so the worst case for this row (AR at 200%) is not covered anywhere but the AR RTL rendering of this preview.

## F18

JeebApp: Bottom nav bar cannot adapt and overflows at large text. `_JeebBottomBar` (lib/features/shell/shell_screen.dart:374) lays five tabs out in a bare `Row(mainAxisAlignment: spaceAround)` whose children are `InkWell > Column` with an unconstrained `Text(tab.label)` — no Expanded/Flexible, no maxLines, no TextOverflow.ellipsis, no FittedBox. At the 390x844 preview box the EN shell overflows the bar horizontally by 58 px at 100% text and ~498 px at 200%, and each tab Column overflows 2 px vertically at 200%. flutter_test draws every glyph as a full-em box so the 100% number is pessimistic, but the 200% figure exceeds the entire 390 dp frame — no real font metric closes that. Nothing throws (clipped text is a layout error, not an exception), which is why the existing shell tests are all green. Pinned by 'at 200% text the shell overflows its own phone frame' in the render test, with the account-status screen as a clean control at both scales.

## F19

JeebApp: First-run carousel clips with no way to scroll. The `Column` inside `OmdsWalkthroughStep` (OnboardingScreen -> OmdsWalkthroughSwitcher -> AnimatedSwitcher -> fixed-height SizedBox) overflows the 844 dp frame by 134 px at 100% text and 446 px at 200%, and there is no Scrollable anywhere in that subtree. At 200% roughly half the first thing a new user reads is unreachable.

## F20

JeebApp: The preview canvas locale and brightness do not reach JeebApp. It builds its own `MaterialApp.router` with `locale:` from LocaleCubit (prefs -> device -> English) and `themeMode: ThemeMode.system`, so the standard `AR RTL dark` cell of the matrix renders English in the light theme. A reviewer scanning the app-level previews would wrongly conclude RTL is fine. The only way in is to seed `app.locale.languageCode`, which is what `jeebAppArabicLanguage` does; asserted both ways by 'the CANVAS locale does not reach JeebApp' / 'the persisted language DOES reach it'. Same trap the JeebBootstrap splash preview already documents for the splash host.

## F21

JeebApp: `RegistrationScreen` has no DI-free path: it resolves `sl<OtpService>()` eagerly inside its `BlocProvider.create` (lib/features/registration/presentation/registration_screen.dart), so `/register` throws before it paints whenever GetIt is unconfigured (verified — the preview renders a red error box). That makes the whole `session.isUnauthenticated` branch of `AppRouter._firstRunRedirect`, and with it the RC-9 'biometric-enrolled but logged out must not be captured onto /lock' guard, unreachable from any preview or bare widget test of the root widget. Every other screen the root routes to (shell, onboarding, lock, account-status) falls back to an inert stub.

## F22

JeebApp: `app.locale.languageCode` is a private literal in LocaleCubit while every sibling preference key is deliberately public for exactly this reason — `OnboardingCubit.completedKey`, `BiometricPreferenceRepositoryImpl.kEnabledKey`, `SessionSeamBootstrap.kAccountBlockedKey`, `RoleCubit.rolePrefKey` all carry a 'single source of truth, no parallel store' comment. The preview had to duplicate the string, which is precisely the drift those comments exist to prevent.

## F23

MarkDeliveredPanel: `ProofPhotoStatus.failed` renders the IDENTICAL picture to `none`: same `add_a_photo_outlined` glyph, same label, same live tap target, no error text and no retry wording. A proof-of-delivery upload that died on the gateway is indistinguishable from 'I haven't taken the photo yet', and the delivery can still be completed with no evidence attached. Pinned by comparing the full rendered-Text list of the two states.

## F24

MarkDeliveredPanel: The photo slot's visible copy is `escalatePhotoLabel` — 'Photos (optional, up to 5)' — borrowed from the escalation flow for a slot that accepts exactly ONE photo (the evidence stamped on the final status patch). The screen-reader name is the correct `receiptProofPhotoLabel` ('Proof of delivery photo'), so only sighted users get the wrong copy.

## F25

MarkDeliveredPanel: Hardcoded English: `otpError` is not an ARB key. `ActiveDeliveryCubit._mapOtpError` returns English literals ('Incorrect code — ask the recipient and try again', 'Too many attempts — contact support', 'No internet connection', …) and `_DoorOtpEntry` prints them verbatim, so the Arabic rendering shows an Arabic title + instruction over an English error line. Pinned in the AR pump.

## F26

MarkDeliveredPanel: `_CashNote` degrades badly on a delivery with no `amount` / no `clientName` (both nullable, and `_amountText` returns null for any shape it cannot parse): it renders `receiptCashToJeeber('', activeDeliveryDropOffLabel)` = 'Pay  cash to Drop-off address' — double space, no amount, and a UI heading standing in for the recipient's name, on the screen where cash changes hands.

## F27

MarkDeliveredPanel: a11y: the `mark_delivered_otp_submit` wrapper is a bare `Semantics(container: true)` with no `button: true`, and the `OmdsLoadingButton` inside it gets no `identifier`, so the node carries a label and NO isButton flag — TalkBack announces 'Complete Delivery' as plain text at the one control that completes the delivery. `mark_delivered_cta` (the CTA it replaces) does set `button: true`; the test asserts both as a control pair.

## F28

MarkDeliveredPanel: RTL: `OmdsOtpInput` spaces its cells with a physical `EdgeInsets.only(left: isFirst ? 0 : spacing/2, right: isLast ? 0 : spacing/2)` instead of a directional inset, so the gaps redistribute when the Row reverses — measured 56/56/56 dp centre-to-centre in EN and 52/56/52 in AR, i.e. the two outer door-OTP boxes crowd their neighbours in Arabic.

## F29

MarkDeliveredPanel: 200% text: `_MarkDeliveredCta` uses `OmdsLoadingButton`, which hard-codes `height: Sizes.fourXLarge` (48) around a plain `Text`. At the 200% rendering 'Complete Delivery' wraps to two lines inside a box that does not grow and the second line is clipped — no ellipsis, no overflow stripe, no exception. (Same defect the DeliveryStatusStepper previews already pin for its advance CTA.)

## F30

MarkDeliveredPanel: Copy: the panel's own header is `l10n.activeDeliveryStatusDone` — the literal status word 'Done' — used as the section title above a form that has not been submitted yet. It reads as a claim that the delivery is finished rather than as 'mark as delivered'.

## F31

MarkDeliveredPanel: The door-OTP entry mounts `OmdsOtpInput` with its default `autoFocus: true` and `_DoorOtpEntry` does not override it, so the instant `otpRequired` flips the keyboard opens unasked and the delivering-phase `ListView` scroll-jumps to the cell row — under the jeeber's thumb, at the customer's door. (This also has a preview-side consequence: the scroll-to-reveal starts a driven scroll animation, and `Scrollable`'s `IgnorePointer` then strips the tap action off every semantics node in the panel until it finishes; the OTP preview box is sized so nothing has to scroll.)

## F32

SocialCollisionSheet: At 200% text the sheet lays out 840dp tall at 390dp width — 60dp MORE than the 780dp a 390x844 phone can give a full-height modal sheet — and there is no scroll fallback: SocialCollisionSheet is a Column(mainAxisSize: min) and `isScrollControlled: true` in showSocialCollisionSheet only raises the route's height ceiling, it does not make the content scroll. The `registration.socialCollisionDismiss` CTA is laid out below the bottom edge of the screen, so a user at 200% text has NO visible way to dismiss the block prompt except dragging the sheet down. Pinned by the render test ('at 200% the CTA falls below the bottom of a phone screen'); it is worse on a 320dp phone and worse again once the 34dp home-indicator inset is subtracted.

## F33

SocialCollisionSheet: l10n.registrationSocialCollisionTitle ('You already have an account') is a bare titleLarge with no maxLines/overflow and already wraps to TWO lines (56dp) at 390dp, three lines (84dp) at 320dp, and four lines (224dp) at 200%. It is the single largest contributor to the 200% overflow above — shortening it is the cheapest fix.

## F34

SocialCollisionSheet: Total content height grows 332dp -> 380dp between a 390dp and a 320dp phone, i.e. the smallest supported screen loses 48dp before any accessibility scaling; combined with the 34dp home-indicator inset the sheet's slack on a 320x568 device is already thin at default text size.

## F35

CancelRequestSheet: No scroll fallback under the sheet's Column: at 200% text the content exceeds the screen and RenderFlex overflows, clipping BOTH CTAs. Measured with the real theme+ARBs — 390x844 phone, network-failure state: 'A RenderFlex overflowed by 4.0 pixels on the bottom' (848 pt of content). 320x568 phone: the IDLE sheet already overflows by 184 px and the network failure by 424 px. showModalBottomSheet(isScrollControlled: true) grants height, it does not add scrolling, so cancel_request_confirm_cta and cancel_request_keep_cta are simply off screen — a user at the accessibility ceiling is shown a failed cancel with neither button.

## F36

CancelRequestSheet: The Keep pill clips its own label at 200% text. OmdsPrimaryButton is a fixed 48 pt (Sizes.fourXLarge) at every text scale and its label is a bare Text in a Center with no maxLines and no ellipsis, so a grown label is painted over the pill rather than growing it. 'Keep delivery' measures 307x45 inside the 342x48 pill at 390 pt and 237x45 inside a 272x48 pill at 320 pt — two lines with ~3 logical px of horizontal and 3 px of vertical slack. AR ('إبقاء التوصيلة') lands in the same place. One more word in either language clips it.

## F37

CancelRequestSheet: Copy contradicts the sheet's own premise: the heading borrows cancellationTitle ('Cancel Delivery') and the dismiss CTA borrows deliveryCancelDialogDismiss ('Keep delivery'), while the sentence between them (cancelRequestFreeNote) exists precisely to say there is no delivery yet and nothing is charged. This is pre-accept — there is no Jeeber and no delivery. The widget's own doc comment files cancelRequestTitle / cancelRequestKeepCta as intended replacements; every preview shows the mismatch still shipping.

## F38

CancelRequestSheet: The Confirm CTA never changes label or role across states. After a network failure it is the retry affordance but still reads 'Cancel' (actionCancel), so the retryable case is never named. After a 409 it sits live and red directly under 'This request can no longer be cancelled.' — a terminal statement — where tapping it can only produce the same 409.

## F39

CancelRequestSheet: The in-flight state is neither readable nor announceable. OmdsLoadingButton replaces `text` with a 20 pt spinner whenever isLoading, so no word on screen says a cancel is running; the surrounding Semantics keeps label: l10n.actionCancel unconditionally with ExcludeSemantics on the child, so a screen reader announces only a disabled 'Cancel' button. Relatedly, the cancel_request_error node carries no liveRegion, so a failure that appears after the tap is never announced and focus stays on the unchanged Confirm button.

