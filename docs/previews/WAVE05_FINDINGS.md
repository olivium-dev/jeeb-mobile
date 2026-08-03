# Wave 05 (home_client) — defects surfaced by the previews

8/8 written, 44 previews, no failures. Recorded, not fixed.

## F01

RepliesTab: DARK-MODE CONTRAST (real defect): lib/features/home_client/presentation/widgets/replies_card.dart:93 paints the order id — the card's primary identifier — with `color: theme.colorScheme.secondaryContainer`, i.e. a CONTAINER/background role used as ink. AppTheme.light() hand-pins secondaryContainer to _jeebNavy so light measures 17.1:1 and the mistake is invisible; AppTheme.dark() is ColorScheme.fromSeed, where secondaryContainer is a dark tonal fill, and on the dark surface it measures 1.98:1 — below even the 3:1 large-text floor, while onSurface on the same surface is 14.3:1. Every AR-RTL-dark rendering in the matrix shows it. Pinned as a number in the test.

## F02

RepliesTab: 200% TEXT OVERFLOW (real defect): `_RepliesActions` at lib/features/home_client/presentation/widgets/replies_card.dart:154 is an end-aligned Row of two IntrinsicWidth pills with no Wrap, Flexible or FittedBox, so its width scales with the text scale while the card does not. Measured in the preview's own 390 dp box with a tall viewport (so only the horizontal axis can overflow): at 100% the CTAs are 100.6 + 201.2 dp and fit; at 200% they are 184.6 + 369.2 dp and the row overflows by 208 px in EN and 94 px in AR. The primary 'Check Offers' CTA is clipped off the trailing edge with no way to reach it. Invisible at the 800 dp default test surface and at 100% text.

## F03

RepliesTab: LOADING STATE IS SILENT (a11y): `_RepliesLoading` is a bare OmdsLoadingState with no `message`, so the branch renders zero Text nodes — a screen-reader user is told nothing at all while the read is in flight. It is the only one of the tab's four branches with no announceable content.

## F04

RepliesTab: PRE-LOAD FRAME IS INDISTINGUISHABLE FROM EMPTY: `_RepliesContent` (replies_tab.dart:151) checks failed → loading → `replies.isEmpty`, so ClientHomeStatus.initial falls through to `_RepliesEmpty`. 'We have not asked the server yet' and 'there are no replies' are pixel-identical.

## F05

RepliesTab: EMPTY-STATE COPY IS THE WRONG PROMPT: `_RepliesEmpty` (replies_tab.dart:208) titles the Replies empty state with `l10n.homeEmptyTitle` = 'What do you need?', the NEW-ORDER prompt, over a subtitle explaining there are no replies. It reads as a call to action on a tab that offers no action.

## F06

InProgressTab: ActiveOrderCard._ActiveOrderActions (lib/features/home_client/presentation/widgets/active_request_card.dart:392) lays the "Open chat" + "Track my order" pills out in a bare Row(mainAxisAlignment: end) with neither button in a Flexible/Expanded/Wrap and no ellipsis on either label. Past the width the pair needs, the failure is a hard RenderFlex overflow (striped bar), not a shrink or a wrap. Measured at 390 pt (phone width) in the widget-test font it overflowed by 70 px at 1.0 text scale on the long-title card, and every row that shows both pills overflowed. The test font is wider than the shipping face so the real-device threshold is higher, but the mode is font-independent and the EN 200%-text rendering of the preview matrix crosses it by construction: the two pills need ~2x their 1.0 width while the card's content box stays fixed at 314 pt (390 - 32 card padding - 40 avatar - 4 gap).

## F07

InProgressTab: ActiveOrderCard._ActiveOrderProgressLabels (active_request_card.dart:340) has the same shape and is worse in Arabic: three Text widgets in Row(spaceBetween) with no maxLines, no overflow, no flex. At 390 pt in AR the measured overflow grew 16 px -> 115 px -> 346 px as the text scale went 1.0 -> 1.3 -> 2.0 (the AR labels "تم الاستلام" / "قيد التوصيل" are longer than "Picked" / "In Transit"). This is the row the AR RTL rendering of the matrix exists to catch. RTL *mirroring* itself is correct throughout the card — EdgeInsetsDirectional/AlignmentDirectional are used consistently — the problem is purely width.

## F08

InProgressTab: Error-state copy drift between the tab and its host screen: InProgressTab's _InProgressError pairs l10n.homeLoadFailedTitle ("Couldn't load your home") with l10n.homeErrorRetry ("We could not load your orders. Tap to retry."), while _FailedLayout in lib/features/home_client/presentation/client_home_screen.dart pairs the SAME title with l10n.homeLoadFailedBody ("Check your connection and try again."). Two different bodies under one title, reachable from the same screen. Separately, "Tap to retry" instructs a gesture this widget does not offer — the retry affordance is a discrete labelled "Retry" button (retryLabel: homeLoadFailedRetry) and the message text is not tappable.

## F09

InProgressTab: InProgressTab has no scroll of its own: _InProgressList is a plain Column, so the widget is only viable as a child of the home ListView (client_home_screen.dart -> _ReadyLayout). Hosting it in a fixed-height box — which is what a preview canvas and any standalone embed do — turns a multi-row list at large text scales into a vertical RenderFlex overflow. The previews compensate with a SingleChildScrollView and a render test pins that host so the compensation is not silently dropped.

## F10

PendingRequestsTab: OVERFLOW: `_PendingServerStatus` (lib/features/home_client/presentation/tabs/pending_requests_tab.dart:303-320) is a bare `Row` of `Icon + SizedBox + Text(l10n.pendingTabSearchingLabel)` with the Text neither `Expanded` nor `Flexible`, so the status line cannot ellipsize or wrap. At 390 logical px the row has 358 px of usable width, but 'Searching for Jeebers…' at `labelMedium` measures 539 px once text is scaled. Measured RenderFlex overflow, EN: 16 px at 1.3x text, 95 px at 1.6x, 201 px at 2.0x; AR: 46 px at 2.0x. This is the DEFAULT pending state (offerCount == 0), so it hits every pending row a user sees. It is visible in the 'EN 200% text' rendering of both `pendingRequestsTabSearching` and `pendingRequestsTabLongContent`. The sibling `_PendingOffersBadge` branch does not overflow at any scale — only the searching line does. Wrapping the Text in `Expanded`/`Flexible` (as `_PendingCardHeader` already does for the title) fixes it; the header row is safe precisely because of that `Expanded`.

## F11

PendingRequestsTab: A11Y: the loading branch (`_PendingLoading`, pending_requests_tab.dart:81-88) renders `Center(child: OmdsLoadingState())` with no `message`, and `OmdsLoadingState` builds a `CircularProgressIndicator` with no `semanticsLabel`. The tab is therefore completely silent to a screen reader while loading and is the only branch that does not respond to text scale at all — the 200% rendering of `pendingRequestsTabLoading` looks identical to the 100% one. Every other branch (empty, error, rows) carries localized text.

## F12

PendingCountdownCard: OVERFLOW (shipping, default state): `_PendingServerStatus` in lib/features/home_client/presentation/tabs/pending_requests_tab.dart:296 builds `Row(children: [Icon, SizedBox, Text(l10n.pendingTabSearchingLabel)])` where the Text is neither Flexible nor Expanded and sets no `overflow`/`maxLines`. It claims its full single-line intrinsic width, so the row runs off the card. Measured per-config with isolated pumps (one testWidgets per config, because RenderFlex dedupes its overflow report across pumps on a reused render object) — overflow in logical px: EN 1.0x -> 7 @320pt; EN 1.3x -> 86/46/16 @320/360/390; EN 1.5x -> 139/99/69/29 @320/360/390/430; EN 2.0x -> 271/231/201/161; AR 2.0x -> 116/76/46/6. So the DEFAULT state of the Pending tab stripes at 100% text on any 320 pt phone, and from roughly 1.25x text on a 390 pt phone. The offers-badge branch never overflows (OmdsChip wraps its own label), so only the `offerCount == 0` path — the normal one — is affected. No existing test catches it: test/features/home_client/pending_requests_tab_test.dart pumps into the 800x600 viewport at 1.0x where the row has ~440 px to spare.

## F13

PendingCountdownCard: DANGLING GAP: `ClientHomeTierBadge._labelFor` (lib/features/home_client/presentation/widgets/active_request_card.dart:276) returns '' for `ClientRequestTier.unknown`, but `_PendingCardHeader` still emits `const SizedBox(width: Spacing.xSmall)` before it. A request on a tier the app has not shipped yet renders an empty Text plus a trailing gap, so the header title ellipsizes earlier than it needs to for a badge that draws nothing.

## F14

PendingCountdownCard: SEEN/UNSEEN IS FILL-ONLY: the entire visual difference between '3 offers you have not seen' and '1 offer you already read' is `OmdsChip.isSelected` (filled vs `primaryContainer` tonal) — no icon change, no dot, no weight change. In the AR RTL dark rendering the tonal fill sits close to the card surface, so the unseen signal is the weakest affordance on the card. Flagged for a designer eye in the canvas; I did not measure contrast ratios.

## F15

PendingReconnectBanner: Chrome dwarfs content: the banner measures 64.0pt tall for a 16.0pt line of text, in every locale and text scale. `OmdsLoadingState(size: Sizes.medium)` is constructed without a `padding`, so it keeps its default `EdgeInsets.all(Spacing.large)` (20) — a 16pt spinner inside a 56pt box. The banner's own `vertical: Spacing.twoXSmall` (4) never gets a say. Horizontally the same padding puts the spinner's optical edge 36pt (16 + 20) from the leading edge and opens a 28pt gap (20 + 8) to the label instead of the intended `Spacing.xSmall` (8). Fix is one argument: `padding: EdgeInsets.zero`. Until then a dropped socket shoves the whole pending list down 64pt and back up on reconnect.

## F16

PendingReconnectBanner: The label cannot degrade: `Text(l10n.pendingTabReconnecting)` sits directly in the Row with no Expanded/Flexible, no maxLines and no overflow, so it has no ellipsize or wrap path — it fits until it doesn't, then stripes. With the real fonts loaded (Inter + the Noto Arabic subset) it does survive today: 174pt of text at 200% scale against 288pt of usable width on a 320pt phone. That margin is accidental, not designed — under the preview render harness's default test font the same Row already overflows by 46pt at 200pt width, and any longer translation of `pendingTabReconnecting` (the Arabic string is already the wider of the two) or a narrower multi-window host overflows hard rather than truncating.

## F17

PendingReconnectBanner: No accessibility announcement: the widget wraps nothing in `Semantics(liveRegion: true)` and gives the spinner no `semanticsLabel`. It appears when the socket drops and the tab starts showing stale rows, but a screen-reader user is told nothing unless they happen to sweep focus back to the top of the list — the one signal that the data is stale is purely visual.

## F18

PendingRequestCard: Dark-mode header is illegible: lib/features/home_client/presentation/widgets/pending_request_card.dart:84 paints the order-id title with `color: theme.colorScheme.secondaryContainer` — a CONTAINER (fill) role used as ink. Measured against AppTheme.dark(): secondaryContainer #444559 on surface #131318 = 1.98:1 contrast (WCAG AA needs 4.5:1; even the large-text floor is 3:1). `onSurface` on the same surface is 14.33:1. In light mode it is 17.13:1, which is why only the AR-RTL-dark rendering of the matrix exposes it. The identical bug was already fixed in the sibling `_PendingCardHeader` (lib/features/home_client/presentation/tabs/pending_requests_tab.dart:261, comment: 'Role fix: `secondaryContainer` is a CONTAINER (fill) role, not an ink role — as text it went illegible on dark surfaces') and was never back-ported to this widget.

## F19

PendingRequestCard: Blank second line when `summaryLine` resolves to empty: `_PendingSummary` (pending_request_card.dart:106) renders the raw string, so a row whose gateway payload carries neither `itemsSummary` nor `destinationLabel` shows an order id above an empty line. The sibling `_PendingCardSummary` guards this with `text.isNotEmpty ? text : l10n.pendingTabSearchingLabel`. Exposed by the 'Empty summary line' preview.

## F20

PendingRequestCard: `ClientRequestTier.unknown` renders an EMPTY badge, contradicting the enum's own doc: client_home_request.dart:36 promises 'a neutral chip so the screen never crashes', but `ClientHomeTierBadge._labelFor` (active_request_card.dart:276) returns '' for `unknown`, so the badge silently disappears and the row loses its only classifier. Nothing crashes, but a backend that introduces a new tier mid-deploy produces unlabelled rows. Exposed by the 'Unknown tier badge' preview.

## F21

PendingRequestCard: Screen-reader a11y gap: the card's `Semantics(identifier: 'pending_requests_item_<id>', button: onTap != null)` carries no `label`, so a reader announces only the raw order id with no role or status context. The sibling `PendingCountdownCard` supplies `l10n.pendingCardA11yLabel(header, statusLabel)` plus a searching/offers status line; this card renders no localized string at all except the tier badge.

## F22

ActiveOrderCard: Two-pill action row overflows at real phone width in EVERY rendering. Body column gets 390 - 32 (card padding) - 40 (avatar) - 4 (gap) = 314 pt; the `_ActiveOrderActions` Row (active_request_card.dart:394) lays out at 384 pt EN (70 px overflow), 354 pt AR (40 px), 706 pt at 200% text (392 px). It is a plain `Row(mainAxisAlignment: end)` of two intrinsically-sized OMDS pills with no Flexible/Wrap, so the trailing pill is clipped on any 390 pt phone whenever a Jeeber is engaged (accepted / atPickup / enRoute) — i.e. the most common In-Progress state. No test/ file sees it: widget tests pump into an 800x600 viewport where the same column has 724 pt.

## F23

ActiveOrderCard: The three progress stage labels overflow in Arabic on EVERY card, including cards with no buttons at all. `_ActiveOrderProgressLabels` is a fixed `Row(spaceBetween)` of three Texts; AR measures 88 + 121 + 121 = 330 pt against 314 pt available (16 px overflow at 390 pt, ~46 px at the 360 pt narrow-phone floor). EN 100% fits at 265 pt, so this is a pure localization/layout bug, provable on the Delivered preview which renders no CTA row and still stripes in AR. At EN 200% text the same row is 518 pt (204 px overflow).

## F24

ActiveOrderCard: Even the single-pill (track-only) action row overflows at 200% text: the Track pill alone is 425 pt against 314 pt. So the accessibility ceiling breaks the CTA on every In-Progress card, not just the two-pill ones.

## F25

ActiveOrderCard: The progress bar tops out one stage past its own legend. `progressStep: 3` is documented as AtDoor/Done and fills the bar to 100%, but `_ActiveOrderProgressLabels` is hardcoded to Ordered / Picked / In Transit — there is no fourth label for the full bar to point at, so a completed order shows a full bar under a legend that stops mid-journey.

## F26

ActiveOrderCard: A card can render with a completely blank header while its CTAs are live. `ClientRequestTier.unknown` returns an empty label string (`ClientHomeTierBadge._labelFor`), so the badge is a 0 pt `Text('')` that still carries its 8 pt leading gap; combined with an empty title the whole header row is blank and the only identifying text is the destination line — while `atPickup` keeps both Open chat and Track my order armed. A tier the backend adds mid-deploy lands in exactly this state.

## F27

ActiveOrderCard: The card can only clip, never grow. Title and summary line are both `maxLines: 1` + ellipsis, so the Long-content preview is byte-for-byte the same height (181 pt) as the short one: a real 6-item order ('1 kilo potato, water gallon, coffee blend, …') shows the client the first three words and offers no way to see the rest.

## F28

ClientHomeTierBadge: `ClientRequestTier.unknown` renders NOTHING, not the fallback the domain promises. `_labelFor` returns '' (active_request_card.dart:277), so the badge is a zero-width Text carrying a colorScheme.tertiary that inks nothing — while ClientRequestTier's own doc (client_home_request.dart:34-36) says unknown 'falls back to a neutral chip so the screen never crashes when the backend introduces a new tier mid-deploy'. A new server tier therefore makes the order silently lose its tier and leaves the row's Spacing.xSmall as 8pt of stray trailing air. Measured: badge width == 0.0.

## F29

ClientHomeTierBadge: The tier palette has no dark variant. AppTheme._build (app_theme.dart:158-166) registers `JeebTierColors.standard()` unconditionally, while the two extensions on the very next lines (JeebSemanticColors, JeebColorRoles) are per-brightness. AppTheme.light().extension<JeebTierColors>() == AppTheme.dark()'s, so the AR RTL dark rendering paints light-scheme hexes on a near-black surface.

## F30

ClientHomeTierBadge: None of the three tier inks meets WCAG AA (4.5:1) as 11pt labelSmall text on the light surface: Flash #E53935 = 4.23:1, Express #FB8C00 = 2.37:1 (barely half of AA), Standard #1E88E5 = 3.68:1. On the dark surface the ranking inverts (Express 7.81, Standard 5.03) because nothing re-tunes the hexes — Flash fails at both ends (4.38:1).

## F31

ClientHomeTierBadge: Tier is carried by hue alone: 11pt text, no fill, no border, no icon (despite the class doc calling it a 'Tier chip'). Flash and Standard sit at 0.198 and 0.235 relative luminance, so a color-blind reader or a sun-washed screen has no second channel distinguishing Flash from Standard.

## F32

ClientHomeTierBadge: The same badge is positioned differently by its two production hosts. `_ActiveOrderHeader` leaves Row.crossAxisAlignment at its `center` default (badge centre == title centre, measured <1px apart), while `_PendingHeader` (pending_request_card.dart:78) and `_PendingCardHeader` (pending_requests_tab.dart:253) pass CrossAxisAlignment.start — the same label then rides 6px higher against the title's ascender on the sibling tab. The badge is a bare Text with no baseline or alignment of its own, so it cannot defend against this.

## F33

ClientHomeTierBadge: `letterSpacing: 0.5` is applied unconditionally to the localized label (active_request_card.dart:250), including the Arabic strings سريع / إكسبرس / قياسي, where letter spacing pulls apart a cursive script whose glyphs are meant to join.

