# Wave 04 (core + app) — defects surfaced by the previews

7 written, 1 skipped (CaptureLocationRoute — a route host that renders a Screen
verbatim; Screens are Screen-Catalog scope). Recorded, not fixed.

## F01

MinTapTarget: The 48 dp floor is not a floor. MinTapTarget's ConstrainedBox applies its minimum via BoxConstraints.enforce, which CLAMPS that minimum into the parent's constraints rather than winning over them, so any parent with a tighter maximum silently produces an undersized target. Measured in test/previews/core/min_tap_target_preview_test.dart: a 32 dp slot yields a 32x32 tap target - 16 dp under AC T-mobile-036, which the widget's own file cites - with no assert, no overflow stripe and no other signal. One SizedBox away from any of the four production call sites.

## F02

MinTapTarget: Same property, opposite direction, and the likelier one to already be in the app: under Column(crossAxisAlignment: CrossAxisAlignment.stretch) - a tight width is also a minimum, so enforce keeps it - the target expands to the full parent width. Measured 358 dp on a 390 dp phone for a 16 dp glyph. Because the GestureDetector is HitTestBehavior.opaque across the whole box, all 358 dp are live: a tap 24 dp from the trailing edge fires the target's onTap (pinned by the 'every pixel of the stretched strip is live' test). Any sibling control placed on that line is unreachable, and nothing in the rendering hints at it.

## F03

MinTapTarget: The IgnorePointer silently swallows the child's own onTap. It is deliberate and documented ('the outer gesture owns the complete target'), but OmdsChip - the child at all four production call sites - advertises an onTap, so MinTapTarget(onTap: f, child: OmdsChip(onTap: f)) reads correct and is half dead. Pinned: tapping the target moves the outer counter to 1 and leaves the child's at 0.

## F04

MinTapTarget: A bare MinTapTarget exposes a tap action and the child's label on one semantics node, but WITHOUT the isButton flag, so a screen reader announces 'Lowest price' with nothing to say it can be activated. This is why all four production call sites wrap it in Semantics(button: true, label: ...) -> ExcludeSemantics(MinTapTarget(...)): the helper named by AC T-mobile-036 does not satisfy the 'semantic labels on all interactive elements' half of that AC on its own.

## F05

MinTapTarget: A squeezed target squeezes its child and clips nothing - MinTapTarget passes the clamped maximum straight down through Align. Observed while building the previews: an OmdsChip constrained to 86.8 dp paints a RenderFlex overflow from its internal Row on top of an already-undersized target. So the narrow-parent failure is either invisible (Icon child, absorbs the squeeze quietly) or noisy in the wrong widget (chip child, stripe attributed to OmdsChip).

## F06

PushBannerHost: DOUBLE-RESERVED STATUS-BAR INSET (layout, live in production). push_banner_host.dart:86 positions the card at `top: MediaQuery.of(context).padding.top + 8` and then wraps it at :89 in `SafeArea(bottom: false)`, which pads by `MediaQuery.padding.top` AGAIN. app.dart:634-661 mounts the host as the `MaterialApp.router` builder — above the Navigator and above any SafeArea — so nothing upstream has consumed that padding on a device. Measured in the render test: with a 47pt inset the card lands at 102pt from the top instead of 55pt. Fix is to drop one of the two (either the `+ padding.top` term or the inner SafeArea).

## F07

PushBannerHost: HARDCODED ENGLISH FALLBACK TITLE (l10n). push_banner_host.dart:145 renders the Dart literal `'Notification'` when `message.title` is empty — no ARB key, so the AR RTL rendering of that state shows an English word inside an otherwise Arabic banner. Reachable: a data-only push with no `notification` block parses to an empty title. Pinned by the test `the empty-title fallback is hardcoded English, even in Arabic`.

## F08

PushBannerHost: DISMISS BUTTON HAS NO ACCESSIBLE NAME (a11y). The `IconButton(icon: Icon(Icons.close))` at push_banner_host.dart:162-165 has no `tooltip:`, no `semanticLabel:` on the Icon and no Semantics wrapper — measured semantics label is the empty string, so TalkBack/VoiceOver announce an unnamed button as the only way to dismiss a banner covering the top of the screen. Note the obvious fix is barred: `test/core/notifications/push_banner_host_overlay_test.dart` pins that the host sits ABOVE the Navigator's Overlay, and a Tooltip mounts an OverlayPortal (the BUG-P1a crash). A `semanticLabel` on the Icon is the fix that survives that constraint.

## F09

NotificationPermissionPrompt: ACTION ROW CANNOT SHRINK — `_PromptActions` (lib/core/notifications/presentation/notification_permission_prompt.dart:160-187) is a bare `Row(mainAxisAlignment: end)` holding two `OmdsPrimaryButton`s, neither wrapped in Flexible/Expanded, and OmdsPrimaryButton sizes itself to its label (`width` defaults to null). Measured: the primary button is the SAME width on an 800pt surface and on a 390pt phone, so a narrower card is paid for entirely in overflow — 'A RenderFlex overflowed by N pixels' in debug, silently clipped in release. Reproduced at the 200% accessibility ceiling with the SHIPPED labels on a 390pt phone, and at 1.0 with ordinary product copy ('Enable notifications now' / 'Maybe later') on a 320pt device. No maxLines, no Wrap, no stacked fallback absorbs it.

## F10

NotificationPermissionPrompt: HARDCODED ENGLISH, NO ARB KEYS — all four strings default to English literals (`_defaultTitle`/`_defaultBody`/`_defaultEnable`/`_defaultDismiss`, lines 50-55) instead of AppLocalizations. The box itself mirrors correctly in RTL (no hardcoded EdgeInsets.only anywhere), so the AR RTL dark rendering of the default preview is a perfectly mirrored, entirely English card. The class doc calls this deliberate ('not in the integrator-owned ARB yet'), but it means an Arabic user sees English unless every call site passes translations by hand — and today there are no call sites at all (see next finding).

## F11

NotificationPermissionPrompt: NO PRODUCTION CALL SITE — the class doc says the card is 'surfaced by PushBannerHost ... via PushBannerHost.showPermissionPrompt'. That member does not exist: `grep -rn showPermissionPrompt lib test` hits only that doc comment, and PushBannerHost (lib/core/notifications/presentation/push_banner_host.dart) never constructs the prompt. The only references to NotificationPermissionPrompt in the repo are its own file and its unit test, so the priming card is unreachable in the app today.

## F12

NotificationPermissionPrompt: HEADER ICON DOES NOT FOLLOW THE TEXT SCALER — `_PromptHeader`'s leading `Icon` is a fixed 24pt while the title beside it is an Expanded Text that scales. In the 'Long copy' preview's EN 200% text rendering the title wraps to four lines with the icon pinned beside the first, and the row stops reading as one unit.

## F13

JeebVerifiedBadge: Dark-mode contrast failure: the glyph is inked with `Theme.of(context).colorScheme.secondaryContainer` — an M3 *container* role, i.e. a fill meant to sit BEHIND ink. Measured against `colorScheme.surface`: 17.13:1 in light (the light scheme hard-codes that role to brand navy, so painting with it accidentally works) but 1.98:1 in dark, where `ColorScheme.fromSeed(_jeebNavy, dark)` gives the role its real M3 value on an almost equally dark surface. WCAG 1.4.11 asks 3:1 of a graphical object. `lib/core/theme/app_theme.dart` states the rule this violates in as many words: 'Anything that wants to PAINT ... must use `tertiary`, never a `*Container` role.' Same defect already recorded for DeliveryConfirmIllustration in test/previews/chat/delivery_confirm_illustration_preview_test.dart, so it is a palette-usage pattern, not a one-off.

## F14

JeebVerifiedBadge: The badge does not respond to text scaling. `size` is a raw logical-pixel double and `Icon.applyTextScaling` is left at its `false` default — nothing in `AppTheme` or OMDS sets `IconThemeData.applyTextScaling` anywhere in the repo. At the 200% accessibility ceiling the profile name goes from 24pt to 48pt and the seal stays exactly 20x20, so the verification mark ends up under half the height of the capital letter beside it. Pinned by the test 'the seal does NOT grow with text scale'.

## F15

JeebVerifiedBadge: An empty `semanticsLabel` is accepted silently, and for this widget that is total failure. `required` only means present — there is no assert, no non-empty floor and no fallback. A caller passing `''` (or an untranslated ARB key, which resolves to an empty string rather than to the English fallback) still gets a semantics node flagged `image: true` and announced as nothing, so a screen reader stops on content that says nothing. The badge renders no visible text, so the label IS the widget for the users it exists for, and it is pixel-identical to a correct badge — no amount of looking at the canvas finds it.

## F16

JeebVerifiedBadge: The two shipping callers already disagree about what the badge says. `CustomerProfileHeader._NameBadge` passes `customerProfileVerifiedBadgeLabel` = 'Verified account'; `DeliveryManProfileHeader._NameBadge` passes `deliveryManProfileVerifiedBadgeLabel` = 'Verified'. A sighted user sees one badge across the app; a screen-reader user hears two different ones. The widget was extracted specifically so the two profile screens share one implementation (RAIL 4), but it delegates the entire announced meaning to the caller with no shared default.

## F17

JeebVerifiedBadge: Host-side (both profile headers, not the badge class): with a wrapped name the `_NameRow`'s `CrossAxisAlignment.center` parks the seal against the vertical middle of the multi-line text block, so the verification mark floats in whitespace with the name it verifies one or more lines above it. Measured in the test as `badge.center.dy - name.top > one line height`. Note the failure I went looking for and did NOT find: the badge is never pushed off the trailing edge — `Flexible` reserves the 20dp seal plus its 8pt gap in every state, including the longest name at the real 250pt identity-column width.

## F18

JeeberKycGateBuilder: Pre-fetch window is indistinguishable from 'never onboarded' (preview `live · fetch in flight`). `JeeberKycStatus` has no `unknown`/loading member, so `LiveJeeberKycStatusGate.status` returns `_cached ?? JeeberKycStatus.none` until the first `GET /v1/kyc/status` lands, and `JeeberKycGateBuilder` resolves that to `registerPrompt`. In release the DELIVERY tab therefore shows an already-approved jeeber a fully actionable 'Register as a delivery man' prompt whose CTA pushes the onboarding wizard (JM-039). The conservative default is right; being pixel-identical to the never-onboarded state, with a live CTA and no loading affordance, is the defect.

## F19

JeeberKycGateBuilder: That window is permanent if the one read fails, and nothing can retry it. `LiveJeeberKycStatusGate.refresh()` is called exactly once, from its own constructor (lib/core/session/jeeber_kyc_status_gate.dart:177); `catch (_)` swallows the failure and leaves `_cached` null. `refresh()` is not a member of the `JeeberKycStatusGate` interface, and DI registers the abstract type (`sl.registerLazySingleton<JeeberKycStatusGate>(() => LiveJeeberKycStatusGate(sl<KycGateway>()))`, injection_container.dart:754) — so no consumer can even reach it without a downcast, and grep finds zero `refresh()` call sites in lib/. One failed status read pins an approved jeeber to the register prompt for the entire session; only a cold restart clears it. The gate is reactive but has no second trigger for the thing it reacts to.

## F20

JeeberKycGateBuilder: `JeeberDeliveryTabDestination.kycRejected` is a destination with no body. The gate resolves it, but `_JeeberHomeHost` (dashboard_tab.dart:155) collapses it via `destination != feed` into the register prompt, so a terminally-rejected jeeber (D52/D87 — final, appeal-only) is shown 'Register as a delivery man' with a CTA into onboarding for the frame before `_GateScoped`'s post-frame redirect fires — and indefinitely in any host where `GoRouter.maybeOf(context)` is null, which is the guard that path early-returns on.

## F21

CaptureLocationRoute: 200% text breaks the primary CTA on the capture-location surface, and the label paints OUTSIDE its own pill. Measured at 390x780 with textScaler 2.0: the pill (capture_location_pin_cta) is Rect.fromLTRB(20, 716, 370, 764) — 48pt tall, because OmdsPrimaryButton pins `height ?? Sizes.fourXLarge` (omds-flutter/omds_library/lib/src/buttons/omds_primary_button.dart:122) and ignores the text scaler. The label's paragraph gets 318pt of width (pill minus Spacing.medium x2) but needs maxIntrinsicWidth 337.2 (EN 'Pin Location') / 336.0 (AR 'تثبيت الموقع'), so it wraps to two lines needing getMaxIntrinsicHeight(318) == 80pt inside a box constrained to 48pt. Container clipBehavior defaults to Clip.none, so the second line paints from y=764 to y=796: 32pt below the pill on the page background, and the last 16pt off the bottom of a 780pt viewport entirely. Silent — didExceedMaxLines is false (no maxLines set at capture_location_screen.dart:101-106) and tester.takeException() is null, so no golden or overflow assertion catches it. Fires in BOTH locales and it is the only control on the screen, i.e. at the accessibility ceiling the user cannot read what the confirm button says. Fix belongs at the call site (lib/features/location/presentation/capture_location_screen.dart:101 — let the button grow, or set maxLines+ellipsis), matching the ObsOverlayExportButton F14 verdict from wave 03 that OmdsLoadingButton/OmdsPrimaryButton ignore textScaler by design.

## F22

BrandedSplash: BrandedSplash: the tagline is unreadable in dark mode — 1.40 : 1. `_SplashTagline` (branded_splash.dart:104-106) inks with `colorScheme.onSecondary` while `BrandedSplash.build` (branded_splash.dart:34) fills with `colorScheme.secondaryContainer`. Those are not an M3 pair, so nothing derives them together; the light scheme survives only because `AppTheme` hardcodes `onSecondary: Colors.white` and `secondaryContainer: _jeebNavy` (17.13 : 1). Dark is `ColorScheme.fromSeed(_jeebNavy, dark)`, which lands both at neighbouring dark tones. Measured `_contrast(dark.onSecondary, dark.secondaryContainer) == 1.4035674124369568` against WCAG AA 4.5. Not hypothetical: `lib/app/jeeb_bootstrap.dart:190-192` hosts the splash with `theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: ThemeMode.system`, so this IS the first frame every dark-mode user sees. The M3-correct partner for the same fill measures 7.23 : 1, so the fix is a one-word role change (`onSecondary` -> `onSecondaryContainer`), not a palette change. Pinned by the `the tagline colour pair only survives in the light scheme` test.

## F23

BrandedSplash: BrandedSplash: the wordmark width is an absolute token, not a fraction of the frame, so its share of the screen swings by 2.3x across the supported device range. `_SplashLogo` uses `width: Sizes.twoHundredLarge` (200.0) with no LayoutBuilder or FractionallySizedBox. Measured `SvgPicture` width == 200.0 at every frame: 45.5 % of the 440 pt Figma frame, 55.6 % of a 360 pt phone, 24.0 % of an 834 pt tablet. The dartdoc at branded_splash.dart:76-79 claims '~45% of a 440dp frame — the brand-sized analogue of Figma's 182px (≈41%)', which is only true at exactly 440 pt. Nothing clips (`BoxFit.contain` holds the 182 : 73.2418 ratio), so this is a brand-proportion defect rather than a layout one. Pinned by the `the wordmark is a fixed 200 pt at every frame width` test.

## F24

BrandedSplash: BrandedSplash: `_SplashTagline` is a bare `Text` with no `Padding` and no width constraint, sitting directly in `_SplashBody`'s Column, so its line box is the FULL safe width of the device with a zero side gutter. Measured on the 360 pt frame at 200 % text: tagline rect 360 x 96 at left == 0.0, i.e. flush to both edges of the frame, on a device with no side insets for `SafeArea` to contribute. Latent rather than live — both shipped taglines ('Delivery App' / 'تطبيق التوصيل') are short enough not to wrap at the real Inter metrics, and the two-line wrap I measured is partly a flutter_test font artifact (square glyphs make 'Delivery App' 384 pt wide at 32 px where Inter needs roughly half). The missing gutter is structural and font-independent: any longer string — a new locale, a reworded tagline — wraps against the glass. Pinned by the `the tagline has no side gutter` test.

## F25

BrandedSplash: BrandedSplash: bottom spacing is not visually constant across devices. The `SizedBox(height: Spacing.fourXLarge)` at branded_splash.dart:55 is inside the `SafeArea`, so the 48 pt is measured from the top of the home indicator rather than from the display edge. Measured gap from the tagline baseline box to the bottom of the frame: 48.0 pt with no insets, 82.0 pt on a 393 x 852 phone with a 34 pt home indicator. Arguably intended (that is what SafeArea is for), but it means the splash the designer signed off at 48 pt renders at 82 pt on most modern iPhones. Pinned by the `the 48 pt tagline margin stacks on top of the home indicator` test.

## F26

BrandedSplash: BrandedSplash: the 'optical centering' is a by-product of spare height, not a fixed offset. `_SplashBody`'s dartdoc (branded_splash.dart:45-46) says the wordmark is 'optically centered (slightly above true centre via asymmetric Spacer weights)', but the 10 : 9 `Spacer` weights are applied to the SAFE box, so the lift scales with both frame height and inset asymmetry. Measured lift above true frame centre: 14.85 pt on the 440 x 956 Figma frame, 7.54 pt on a 393 x 852 notched phone — the same widget, half the intended optical correction. A device whose bottom inset exceeded its top inset would land the wordmark BELOW true centre while still reading as 'optically centered' in the code. Pinned by the `the wordmark sits above true centre, and the notch moves it` test.

## F27

JeebBootstrap: `_BootstrapErrorApp` clips its message SILENTLY at large text: in the matrix's `EN 200% text` rendering at the preview's own 390x844 box, the verbose PlatformException paragraph needs 1520 dp inside a 796 dp box — the details and the whole stack trace are cut mid-word. There is no `SingleChildScrollView`, no `maxLines`, no `overflow`, and clipped text throws nothing, so `takeException()` stays null and no golden or render test could ever have caught it. Measured and pinned in `test/previews/app/jeeb_bootstrap_preview_test.dart` ('at 200% text the verbose payload is SILENTLY truncated').

## F28

JeebBootstrap: The error host is a bare `MaterialApp` with no `theme:`/`darkTheme:` (lib/app/jeeb_bootstrap.dart:212), so the one screen a user sees when the app is broken renders stock Material — not AppTheme, and not dark. In the `AR RTL dark` rendering of every error preview it is a white screen with black text while the rest of the canvas is dark.

## F29

JeebBootstrap: The error host never mirrors and is hardcoded English. It passes no `locale`, no `localizationsDelegates` and no `Directionality`, so it resolves to en/LTR whatever the ambient locale, and `'App failed to start: $error'` is a raw English literal in an app that otherwise ships 1534 ARB keys in both locales. The `Boot failed · Arabic payload` preview shows the consequence: the English label and an Arabic message end up in one LTR bidi run, centre-aligned as if they read the same way.

## F30

JeebBootstrap: The error host dumps the raw error object at the user (pigeon channel names, `java.lang.IllegalStateException` frames) and offers no retry, no restart and no support path — `find.byType(ButtonStyleButton)` finds nothing. With `Exception()` as the payload it degrades to 'App failed to start: Exception', a dead end with zero actionable content.

## F31

JeebBootstrap: `_SplashApp` resolves its locale from `PlatformDispatcher.instance.locale` and its brightness from `ThemeMode.system` (lib/app/jeeb_bootstrap.dart:176-197), so the canvas locale/brightness never reach it: the `AR RTL dark` rendering of the cold-start preview is neither Arabic nor dark. The splash's RTL mirroring is not reviewable from the preview canvas at all — only from a device or desktop whose system locale is Arabic. Pinned as `host.locale == Locale('en')` under an `ar` canvas.

## F32

JeebBootstrap: The branded splash is withheld behind an asynchronous asset load. `_SplashApp` uses the real `AppLocalizations.delegate`, which parses `lib/l10n/app_en.arb` out of the asset bundle, and `Localizations` renders an empty `Container` until that resolves — so the splash host is mounted while `BrandedSplash` is not. The first frame(s) after `runApp` are blank rather than brand navy, which is exactly the window the branded splash exists to fill.

## F33

JeebBootstrap: The ready state has no preview seam and cannot be exercised without side effects: `_scheduleDeferred` unconditionally fires `Bootstrap.deferred` (`Firebase.initializeApp()`) from a post-frame callback the moment the bootstrap future resolves, and `BootstrapResult.preferences` requires a live `SharedPreferences` no fake can stand in for. Separately, `_JeebBootstrapState` caches its future in a `late final` with no `didUpdateWidget`, so rebuilding the element with a different `bootstrapFuture` keeps the FIRST one — a loop over four preview states silently asserts the same state four times unless the tree is unmounted between pumps (this bit during authoring; the test now unmounts explicitly).

