# Wave 07 (jeeber_home) — defects surfaced by the previews

8/8 written, 45 previews, no failures. Recorded, not fixed.

## F01

JeeberActiveDeliveriesBanner: Large-text/RTL row overflow (same class as JEBV4-286, never fixed on THIS banner): `_OpenChatButton` is a non-flexible child of the row and its OMDSOutlinedButton label is a plain Text with no maxLines/overflow, so it claims full intrinsic width and the Expanded title absorbs the shortfall. Measured on the long-name fixture at 390 logical px — EN 100%: CTA 127px / title 151px (fine); EN 200%: CTA 253px / title 25px (name effectively gone, no exception); AR 200%: CTA 336px / title 0px + 'A RenderFlex overflowed by 58 pixels on the right'. EN 200% on a 320px-wide phone overflows by 45px. The sibling banner fixed this by making the label Flexible + ellipsizing (`_ButtonLabel` in features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart); jeeber_active_deliveries_banner.dart still has the pre-fix shape.

## F02

JeeberActiveDeliveriesBanner: CTA label is vertically clamped at large text: `_OpenChatButton` pins the button to `SizedBox(height: Sizes.twoXLarge)` (32px). At 200% text the label needs ~32px of line box but is measured into a 16px-high slot (rendered Text height stays 16.0 at both 100% and 200% while its width doubles), so the glyphs paint outside the button's rounded background instead of the pill growing with them.

## F03

JeeberActiveDeliveriesBanner: Hardcoded English in a localized widget: `_ActiveDeliveryRow._title(AppLocalizations l10n)` takes an l10n and never uses it — the last fallback is the literal `'Order ${conversation.routeId}'`. A row that arrives with no counterpartName/title/displayId (a shape the live `GET /requests?role=jeeber` envelope does produce) renders 'Order f2244baa-ff25-4316-b723-c08a80cd3da9' in English even in the Arabic UI. Pinned by the AR test in the preview test file.

## F04

JeeberActiveDeliveriesBanner: No error path exists to preview: `_JeeberActiveDeliveriesBannerState._load()` awaits `repository.fetchAccepted()` with no try/catch, relying entirely on the swallow-all contract documented on AcceptedConversationsRepository. Any implementation that throws produces an unhandled async error and leaves the banner permanently in its not-loaded (invisible) state — which is why the preview set has an empty state and a stalled state but no error state.

## F05

JeeberActiveDeliveriesBanner: No loading affordance: the in-flight read renders the same `SizedBox.shrink` as the empty state — no skeleton, no spinner, no reserved height. Flipping between the 'Loading · self-hidden' and 'One accepted order' previews shows the banner popping in at full height and shoving the availability card down the dashboard rather than fading into reserved space.

## F06

JeeberHomeGreeting: Header silently loses its avatar: `_GreetingRow` (lib/features/jeeber_home/presentation/widgets/jeeber_home_greeting.dart:77) returns the bare text line whenever no avatarUrl resolves, instead of the initials/'?' avatar ClientHomeGreeting always shows. Measured in the preview box: the title paints at x=16.0 with no avatar and x=56.0 with one, so the greeting jumps 40dp sideways the moment `GET /users/me` lands, and a jeeber with no picture on file never gets an initials avatar at all (`_GreetingAvatar`'s initial branch is then reachable only as a network-image placeholder). Call sites split on this too: jeeber_unregistered_view.dart:65 and jeeber_no_requests_view.dart:84 pass name only, jeeber_feed_tab_view.dart:198 and jeeber_feed_empty_view.dart:79 pass both.

## F07

JeeberHomeGreeting: Name-suppression discards a perfectly good threaded name (latent). jeeber_home_greeting.dart:37-42 picks `profile.name` whenever it is non-empty and only THEN runs `displayNameOrNull`; there is no fall-through to the threaded `name`. Ambient 'jeeb-e1a35ea8a520' + threaded 'Rami' renders 'Welcome back', losing 'Rami'. It cannot bite today only because DashboardTab threads a name solely on the unregistered path, which mounts no GreetingProfileCubit — one wiring change from greeting a named jeeber generically. Pinned by the 'Synthetic handle suppressed' preview and its test.

## F08

JeeberHomeGreeting: At 200% text the personalization is the first thing to disappear. In the 390x110 preview box the greeting gets 318dp of width with an avatar (358 without) and is capped at maxLines:1 + ellipsis, so 'Hello, Abdulrahman' truncates mid-first-name while the shorter 'Welcome back' fallback never does. No overflow exception is thrown — it degrades silently, which is why only the visual preview surfaces it.

## F09

JeeberHomeGreeting: The avatar does not participate in text scaling: JeeberHomeGreeting pins OmdsProfileAvatar to `Sizes.twoXLarge` (32dp) while the initial inside it uses `size / 2.5` (12.8) and IS scaled by the ambient textScaler. At 200% the initial's line box measures 32.0dp inside the 32dp circle (zero margin, measured), and OmdsProfileAvatar's placeholder Container does not clip, so any larger scale paints the letter across the circle edge. The 32dp avatar beside 56dp-tall text also reads as unbalanced at the accessibility ceiling.

## F10

JeeberHomeGreeting: Avatar accessibility node is weaker than the client header's: jeeber_home_greeting.dart:98-99 wraps it in `Semantics(identifier: 'jeeber_home_avatar')` with no label and no `image: true`, whereas ClientHomeGreeting passes `image: true` (client_home_greeting.dart:172). When the picture fails or is absent the node surfaces as a bare 'A'/'?' text node next to the greeting.

## F11

JeeberFeedEmptyView: Dark-mode contrast, empty-state headline: `_EmptyTitle` paints "No Requests yet" with `theme.colorScheme.secondaryContainer` — a container/background role used as a foreground. Measured against AppTheme.dark() (scaffoldBackgroundColor falls through to colorScheme.surface #131318) that is a 1.98:1 contrast ratio, below the WCAG AA 3:1 floor for large text; the headline is very nearly invisible in dark mode. Light mode happens to land at 17.13:1, so a light-only review never sees it.

## F12

JeeberFeedEmptyView: Light-mode contrast, empty-state subtitle: `_EmptySubtitle` uses `colorScheme.onSecondaryContainer` as body text on the surface — 3.76:1 in AppTheme.light(), below the AA 4.5:1 floor for body text (14.29:1 in dark). The two strings fail in opposite themes, which is why neither has been caught.

## F13

JeeberFeedEmptyView: 200% text pushes both empty strings below the fold: `_EmptyHero` is `AspectRatio(aspectRatio: 1)` on the full content width, so it stays 358x358 at every text scale while everything around it doubles. Measured at 390x720: the copy block moves from y=522 to y=594 and the subtitle's bottom runs to y=914 — off a 720 pt phone. There is no overflow exception because the SingleChildScrollView absorbs it, so at 200% the screen silently opens as an illustration with no explanatory copy visible.

## F14

JeeberFeedEmptyView: Unwired availability toggle reads as live: `_AcceptOrdersRow` forwards `onAcceptOrdersChanged` straight into `OmdsSwitchTile.onChanged` but never sets `enabled: false`. With a null callback the InkWell and the Switch go dead while the tile title keeps full-strength `colorScheme.onSurface` (verified: #0B0E53 in light), so it looks tappable and silently ignores taps. This is not hypothetical — the only current host, `_DevFeedBody` in lib/features/shell/tabs/dashboard_tab.dart:490, constructs the widget with `profileName`/`profileAvatarUrl` only.

## F15

JeeberFeedEmptyView: The switch-OFF state says the wrong thing: with `acceptOrders: false` the view still renders "No Requests yet" / "All requests will show up here", implying the market is quiet when the jeeber has actually taken themselves offline. `jeeberFeedOfflineBannerTitle` ("You are offline") and `jeeberFeedOfflineBannerSubtitle` ("Go online to see available requests.") already exist in both ARBs for exactly this case and this surface never reaches for them.

## F16

AvailabilityStatusBlock: Auto-offline silently drops the deliveries still assigned. `build` gates BOTH sub-lines on `view.status.isOnline`, but `AvailabilityCubit._onIdleTick` emits `status.copyWith(state: AvailabilityState.autoOffline)`, which PRESERVES `activeDeliveryCount`. So a Jeeber kicked off the matching engine after 8 h idle while holding 2 pickups is told only 'Automatically taken offline' — the count line and its `activeDeliveriesKey` are not rendered at all, at exactly the moment the outstanding work matters most. Confirmed by test (`find.textContaining('active deliver')` findsNothing at autoOffline+count:2, findsOneWidget at online+count:2), not inferred. lib/features/jeeber_home/presentation/widgets/availability_status_block.dart:32.

## F17

AvailabilityStatusBlock: While a toggle is in flight the block asserts the STALE pre-toggle truth under a contradictory headline. `_StatusHeadline` short-circuits to 'Updating…' on `isToggleInFlight`, but the `if (view.status.isOnline)` guard three lines below reads the OLD snapshot (`toggle()` emits `copyWith(isToggleInFlight: true)` without touching `status`). Result: a Jeeber tapping the switch OFF sees 'Updating…' / '3 active deliveries' / 'Auto-offline after 8 h idle' — the app advertising the auto-offline idle policy to someone mid-way through going offline by hand. The mirror case (going online from offline) renders the headline alone, so the widget's two only-in-production frames are structurally different shapes. Confirmed by test.

## F18

AvailabilityStatusBlock: At the 200% ceiling the block grows ~5x with nothing to absorb it, and the app renders one string two contradictory ways. Measured on a 390pt phone at the block's real 290pt slot width: 76pt at 1x, 240pt at 200% for the in-flight stack, and 360pt at 200% for the settled online stack once "You're online — receiving requests" wraps to three lines. Nothing truncates (no `maxLines`, no clip, unbounded parent), so this is growth rather than overflow — but `AvailabilityCard._CompactOnlineAvailability` wraps the SAME `availabilityStatusOnline` string in `DefaultTextStyle.merge(maxLines: 2, overflow: ellipsis)`. At 200% the dashboard therefore ellipsizes that sentence in the compact row and lets it run to three full lines here.

## F19

InactivityWarningBanner: CTA alignment is dead code: `_BannerCta` wraps the button in `Align(alignment: AlignmentDirectional.centerEnd)`, but `OmdsPrimaryButton.width` "defaults to full width" (its inner `Center` expands into the loose constraints), so the pill fills the card's content box. Measured offset of the CTA centre from the card centre is exactly 0.0 dp in BOTH en and ar — the trailing-edge intent never takes effect, and the CTA's RTL mirroring is consequently unobservable.

## F20

InactivityWarningBanner: CTA label is clipped at 200% text: on a 390x844 phone at textScaleFactor 2.0 the label "I'm still here" has a one-line width of 393.4 dp against 292 dp available inside the pill, so it wraps to two lines needing 80 dp of height — but `OmdsPrimaryButton` pins the pill to `Sizes.fourXLarge` (48 dp). The paragraph is clamped to 48 dp and the second line is painted nowhere. No Flutter overflow error is raised (a clamped RenderParagraph does not report overflow), so nothing in CI catches it today.

## F21

InactivityWarningBanner: Title-row icon floats against wrapped text: `_BannerHeader` is `Row(Icon, gap, Expanded(Text))` with the default `crossAxisAlignment: center`. Measured at 200% text on 390 dp, the title block spans y 17-113 while the clock icon sits at y 53-77 — vertically centred against a three-line heading instead of aligned to its first line. Same pattern the JeeberRemovedBanner preview already flags for its own icon row.

## F22

InactivityWarningBanner: In a 260 dp tall slot (landscape / split view / enlarged system font) the whole CTA falls below the fold at ORDINARY text scale — measured pill at y 313-361 against a 260 dp viewport. The column scrolls rather than clipping, which is the correct degradation, but nothing above the fold indicates there is a button to scroll to, and ignoring this banner is what takes the Jeeber offline.

## F23

JeeberUnregisteredView: EN 200% text overflows by 136pt on an ordinary phone body. At 390x680 the English headline goes from 2 lines to 4 (64pt -> 256pt) while the hero illustration is a hard-coded 200x200 box that yields nothing; the view needs ~816pt of body height to survive the harness's standard `EN 200% text` rendering. The Galaxy S22 the team tests on is 360x780 logical (~676pt of body after chrome) and narrower, so the real device clips harder than the canvas. The AR RTL rendering does NOT reproduce it — 'سجّل كموصِّل' still fits on one line — so this is an English-only accessibility break an Arabic-first spot check would miss.

## F24

JeeberUnregisteredView: Silent clipping below ~496pt of body height (390pt wide), ~528pt at 320pt wide. Measured: greeting 48pt + CTA 48pt + trailing gap 20pt are taken first, so the Expanded hero is handed `height - 116` against a hard minimum of `296 + title + subtitle` (380pt at 390pt wide). At a 420pt body the hero overflows by 76pt in EN and 44pt in AR. There is no SingleChildScrollView anywhere in the subtree, so in release this is clipped with no indication — the fix belongs to the view (scroll view, or drop the illustration under a height threshold), not to its hosts.

## F25

JeeberUnregisteredView: The register CTA has no vertical headroom at large text. OmdsPrimaryButton pins `height: height ?? Sizes.fourXLarge` (48pt) regardless of textScaler, and at 200% the 'Register now' label measures exactly 48pt tall inside that 48pt box (20pt at 100%). It does not clip today, but the margin is zero — a longer localized CTA string, or a locale with taller line metrics, clips inside the pill with no overflow stripe to warn anyone.

## F26

JeeberUnregisteredView: The upsell headline has no `maxLines`, so width squeezes turn into height. 'Register as a delivery man' takes 2 lines at 390pt (64pt) and 3 lines at 320pt (96pt), and because the 200pt illustration above it is fixed, a narrow device consumes the height budget rather than the width budget — which is why the 320pt phone hits the overflow floor 32pt earlier than the 390pt one.

## F27

JeeberNoRequestsView: Horizontal overflow at 200% text: the active-work band this view hosts renders `avatar + Expanded(name) + "Open chat"` where the CTA is NOT flexible (lib/features/jeeber_home/presentation/widgets/jeeber_active_deliveries_banner.dart:164). At 200% text the AR rendering throws `A RenderFlex overflowed by 58 pixels on the right` — twice, once per row — while EN clears by only ~33px. (Measured under the flutter_test font, whose advance width equals the font size, so the exact pixel counts are indicative; the structural cause — an unbounded button in a fixed-width row — is not font-dependent.)

## F28

JeeberNoRequestsView: The same row's CTA cannot scale: `_OpenChatButton` pins it inside `SizedBox(height: Sizes.twoXLarge /* 32 */)`. Measured, the button box is exactly 32.0px tall at BOTH 1x and 2x text scale, and its label box stays 16.0px tall while its width doubles (126.9 → 252.9). The label is clipped rather than the row growing, so this one control opts out of the 200% accessibility ceiling the rest of the surface honours.

## F29

JeeberNoRequestsView: Hardcoded English + a leaked internal id: an accepted order carrying no counterpartName/title/displayId falls through to `'Order ${conversation.routeId}'` (jeeber_active_deliveries_banner.dart:191). The AR rendering of the 'Active work' preview shows the literal `Order req-23471` — untranslated, with a raw request id as user-facing copy. The ARB already has `jeeberActiveDeliveriesFallbackTitle` ('Delivery' / 'توصيلة'), and the sibling banner at lib/features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart:194 uses it correctly.

## F30

JeeberNoRequestsView: No finding against JeeberNoRequestsView's own composition: at 200% text in EN and AR, at each preview's canvas box, none of its own bands (greeting, availability card, inactivity banner, empty state) overflowed — vertical growth is absorbed by its SingleChildScrollView. Every problem above is in the injected active-deliveries band.

## F31

AvailabilityCard: EN-only truncation at the accessibility ceiling. `_CompactOnlineAvailability` clamps its title to `_kCompactOnlineTitleMaxLines = 2` with `TextOverflow.ellipsis`, and at 200% text "You're online — receiving requests" no longer fits. Measured with the production Inter faces (not the square test font): at 320 pt the Jeeber reads "You're online — receiving…", at 390 pt "You're online — receiving reque…"; only at 430 pt does the full string survive. The truncation eats the clause that says what being online actually does. Arabic fits two lines at every width, so the AR rendering gives no warning. Nothing in test/ catches it either — the two-line-budget assertions in test/features/jeeber_home/availability_card_test.dart check the rendered HEIGHT stays within two lines, which an ellipsis satisfies by construction.

## F32

AvailabilityCard: The 'compact' online branch stops being compact at 200% text — it is TALLER than the full section it exists to replace. Measured root heights at 390 pt: online 112 px vs offline 100 px at 2.0× (at 1.0× the intended relationship holds: 64 px vs 76 px). The density win the class doc claims ("one compact OMDS switch row") inverts exactly at the accessibility ceiling, so a large-text user pays the section's height and loses the section's heading and supporting copy as well.

## F33

AvailabilityCard: The in-flight frame drops the toggle out of the accessibility tree. Counting `find.bySemanticsIdentifier('availability_switch')` across the two frames gives 1 at rest and 0 while `isToggleInFlight` — `_AvailabilityProgress` renders no Semantics node of its own, and the `OmdsLoadingState` spinner carries no label and no live region. For the duration of the PUT a screen-reader user has neither the control nor any announcement that a change is in progress; the visible "Updating…" headline is the only signal and it is not announced.

