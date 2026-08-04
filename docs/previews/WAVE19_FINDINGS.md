# Wave 19 (jeeber_active_deliveries, jeeber_home, misc) — defects

8/8 written, 44 previews.

## F01

ActiveDeliveriesBanner: OVERFLOW at 200% text in `_ActiveDeliveriesSummaryRow` (active_deliveries_banner.dart:154) — the at-rest state, i.e. what every jeeber with active work sees. The row is `Expanded(title) + SizedBox + OmdsPrimaryButton`; the button is not Flexible and its OMDS-default label is a plain `Text` with no maxLines/overflow, so it claims its full intrinsic width and starves the title. Measured on the preview fixture: EN 100% title=113px ok; EN 150% title=29px ok; EN 200% title=0px, RenderFlex overflows 55px (390 logical width); AR 200% 54px; EN 200% at 360 (Galaxy S22) 85px. 'Your active deliveries' disappears entirely and 'View all (1)' paints ~23px past the right screen edge, so it reads as a vanished section title rather than a yellow stripe. `_kActiveDeliveriesSummaryTitleMaxLines = 2` is dead — the title never gets width to wrap. This is the same defect JEBV4-286 fixed one level down on the card's two actions with `_ButtonLabel` (Flexible + ellipsis); the disclosure toggle never received it.

## F02

ActiveDeliveriesBanner: Title starvation inside the card at 200% (`_ActiveDeliveryCard`, active_deliveries_banner.dart:219) — `Row(Expanded(title), _StatusChip)` with a non-flexible chip. At 200% the 'In Transit' chip takes 245px of the 326px of card content, leaving ~66px for the request title; 'Ordered' takes 171px. No overflow (the chip stops at the card edge), but the delivery ends up identified by its status plus three characters of its title.

## F03

ActiveDeliveriesBanner: No RTL or hardcoded-string defects found: every string routes through AppLocalizations, and the padding is EdgeInsetsDirectional, so AR mirrors correctly at both widths (verified by measuring left/right edges in ar). The `_ButtonLabel` ellipsis fix also holds — the card actions do NOT overflow in EN or AR at 100% or 200%, side-by-side or stacked.

## F04

JeeberFeedTabView: No loading and no error surface exists on this page. `_FeedRequestSliverBody.build` branches only on `visible.isEmpty` and never reads `RequestFeedState.status` or `errorMessageKey`, so a failed `GET /v1/jeebers/me/feed` (which `RequestFeedCubit._refresh` records as `RequestFeedStatus.error` + `errorMessageKey: 'requestFeedErrorLoad'`) and the cold-start loading frame both render the identical 'No Requests yet / All requests will show up here' empty state — a confident, wrong claim with no retry and no spinner. `jeeberFeedTabViewEmptyFeed` is simultaneously the empty, loading and error preview because there is nothing else to look at.

## F05

JeeberFeedTabView: Going offline removes every control on the page, not just the feed. `_buildBody` skips `_feedControls()` wholesale when `avState.status.state != online`, so the search bar AND both chip strips (sub-tab + tier) disappear — a jeeber sitting on the Pending tab who toggles off has no visible way back to it and no indication the tabs ever existed. Pull-to-refresh is dropped in the same branch. Pinned in the test as four `findsNothing` assertions against `searchBarKey`/`tabStripKey`/`tierStripKey`.

## F06

JeeberFeedTabView: The offline copy is printed twice, verbatim and adjacent. `_OfflineBanner` and `_OfflineEmptyBody` both render `jeeberFeedOfflineBannerTitle` + `jeeberFeedOfflineBannerSubtitle` with nothing between them, so 'You are offline' and 'Go online to see available requests.' each appear as two widgets (pinned as `findsNWidgets(2)`). At 200% text those two identical blocks are most of the screen. It also means no offline-state text can be used as a `findsOneWidget` contract.

## F07

JeeberFeedTabView: `JeeberFeedTabView.offlineBannerKey` (`'jeeber-feed-tab-view-offline-banner'`) is a declared public contract that is never attached to anything: `_OfflineBanner` takes no key and `SliverToBoxAdapter(child: _OfflineBanner())` does not supply one. Every sibling key (`rootKey`, `searchBarKey`, `tabStripKey`, `tierStripKey`, `listKey`, `pendingListKey`) is wired; this one is dead, so nothing can key off the banner today.

## F08

JeeberFeedTabView: `initialTab` is honoured only at State creation — `late JeeberFeedTab _activeTab = widget.initialTab;` with no `didUpdateWidget` reconcile. A rebuild that changes `initialTab` in place (deep link / dev-seam re-entry while the element is retained) silently keeps the previously active tab. This is not theoretical: pumping a second preview into the same tree reused `_JeeberFeedTabViewState` and kept the first preview's tab, which failed the first version of the tier-strip test until it was split one-preview-per-test.

## F09

JeeberFeedTabView: Inconsistent router guarding inside the same file. `_defaultMakeOffer` correctly bails on `GoRouter.maybeOf(context) == null`, but the accepted-card tap in `_FeedRequestSliverBody` calls `GoRouter.of(context).pushNamed('chat-detail', …)` unguarded, so that tap throws wherever no router is mounted — which is exactly the case in the preview canvas and in bare widget tests. It makes the Replies preview look-only.

## F10

JeeberFeedTabView: Carried into page context rather than newly measured here: the incoming card's Ignore/Offer pair is a non-wrapping `Row(mainAxisSize: min)` and the Arabic labels are wider than the English ones, so at the 360 pt Galaxy S22 width the Offer button runs off the trailing edge at default text size. The numbers are the measured table already recorded in `jeeber_feed_card.dart`'s own preview section (2 pt at 390, 32 pt at 360, far worse at 200%); `jeeberFeedTabViewLongContent` is pinned at 360 pt with `matrix: true` so it is visible in the real page, under the real header stack, instead of in card isolation.

## F11

MaskedCallButton: The in-flight CTA has NO accessible name. `Semantics(identifier: 'masked_call_cta', button: true, container: true, ...)` in `_MaskedCallButtonView` carries no `label` of its own, so its only text comes from the descendant `Text` — and that is exactly what `OmdsLoadingButton` removes while `isLoading`. Measured: the semantics node's `label` and `hint` are both empty for the whole second the call takes to place, while `isButton` stays true. It is not announced as disabled either — `Semantics` never sets `enabled`, so `flagsCollection.isEnabled == Tristate.none` and there is no dimmed/greyed hint explaining why tapping does nothing. Pinned in `FINDING: the in-flight CTA announces as an unnamed button` with the idle case as a control.

## F12

MaskedCallButton: Three materially different states paint a byte-identical frame: idle, call-placed (`sessionId` set) and call-failed all render one full-bleed `Call` pill at the same rect. The widget never reads `sessionId`, so a placed call is indistinguishable from one never started and the pill invites the user to place a second one. Pinned in `FINDING: three states paint the SAME pill`.

## F13

MaskedCallButton: A failure that predates the consumer's subscription is swallowed entirely. `BlocConsumer` invokes its listener only on state *changes*, so a cubit seeded/rebuilt with `failed: true` produces no snackbar, no inline error, no retry affordance — the screen says nothing at all. Even on the live path, the only signal is a 4-second floating snackbar; once its timer runs out nothing on screen records that the call was never placed.

## F14

MaskedCallButton: `MaskedCallState.failed` is unreachable from the real cubit: `MaskedCallCubit.initiateCall` wraps `await Future.delayed(...)` in a `try/catch` that nothing can throw from, so the `catch` branch — and therefore the entire error snackbar in `_onState` — is dead code in production. The preview can only reach it by seeding the state directly.

## F15

MaskedCallButton: The CTA's height is a hard-coded `Sizes.fourXLarge` (48 dp) that does not scale with text. Measured in a 390x120 box: the label grows 20 dp -> 40 dp between 100% and 200% text (identical in EN and AR) while the pill stays at 48 dp, leaving 4 dp of clearance top and bottom. It fits today with no headroom, so a longer word or a higher scale clips rather than grows. Pinned in the `layout ceiling` group.

## F16

MaskedCallButton: Not a defect, asserted so it cannot become one: a full-bleed pill with a single centred word has nothing to mirror, and the label does sit on the box centre line in both LTR and RTL. There is no RTL bug here today.

## F17

MixedDirectionText: CRASH: `MixedDirectionText.detectDirection` throws `Bad state: No element` on whitespace-only text. The guard runs on the UNtrimmed string (`if (text.isEmpty) return TextDirection.ltr;`) while the read runs on the trimmed one (`text.trim().codeUnits.first`), so `'   '` — a pasted-then-cleared delivery note, or a server field that is spaces rather than null — takes the crash path out of `build()`. Both live call sites (`rating_screen.dart:269` via `feedbackRateName`, `delivery_tracking_panel.dart:164` via a server-formatted status line) pass strings the app does not sanitize. This state is the ONE state that could not be previewed — a preview that throws marks the whole library — so `mixedDirectionTextLeadingWhitespace` holds the nearest renderable neighbour and its doc comment records the boundary. Fix is one character: guard on `text.trim().isEmpty`.

## F18

MixedDirectionText: RTL: the first character decides the whole paragraph, so a mostly-Arabic note that opens with a digit, a Latin token or ASCII punctuation is laid out LTR. The Screen Catalog's own fixture for this widget, `'2 boxes - توصيل سريع'`, starts at the LEFT edge with the `-` on the wrong side of the Arabic run — i.e. the quantity and the note read in the opposite order from every other note in a list. `mixedDirectionTextLeadingDigit` is matrixed because the AR RTL card is where it is unmissable: everything else on the screen has mirrored and this line has not. Pinned as-is in the render test (labelled KNOWN MISFIRE) so a future fix has to change the preview and the test together rather than silently changing what a courier reads.

## F19

MixedDirectionText: RTL: `codeUnits.first` reads a UTF-16 code unit, not a rune, so any text opening with a non-BMP character yields a high surrogate (0xD800–0xDBFF) that matches none of the three ranges and always falls to LTR — e.g. `'🚗 وصل السائق'`, exactly the shape of the tracking-panel status copy. The range table is also narrower than the script: it covers Arabic (0600–06FF), Arabic Presentation Forms-B (FE70–FEFF) and Hebrew (0590–05FF), but not Arabic Supplement (0750–077F), Arabic Extended-A (08A0–08FF) or Presentation Forms-A (FB50–FDFF).

## F20

MixedDirectionText: Cosmetic/RTL: leading whitespace is trimmed for DETECTION but kept in the rendered `Text`, so under RTL the spaces indent the line from the RIGHT edge and read as a layout bug rather than as the user's own input. Visible in `mixedDirectionTextLeadingWhitespace`; asserted in the render test (`find.text('توصيل من الأشرفية')` finds nothing — only the space-prefixed string exists).

## F21

MixedDirectionText: Stale annotation, not a layout bug, but material: line 3 of the source reads `// ORPHAN (JEBV4-227, verified 2026-07-12): zero refs`. The widget has two live call sites — `lib/features/rating/presentation/rating_screen.dart:269` and `lib/features/live_tracking/presentation/widgets/delivery_tracking_panel.dart:164` — plus a Screen Catalog entry in `lib/devtool/catalog/entries/batch_06_entries.dart:445`. Left untouched (production code above the banner), but anyone acting on that comment would delete a widget two screens depend on.

## F22

NotificationRow: Nothing on the row clamps: neither the title nor the body sets maxLines/overflow. Measured at 390pt width, the long-payload fixture is 328pt tall at 1.0x text and 1252pt at 200% — one notification taller than three phone screens. It never overflows (the list scrolls) but it buries every row beneath it in the inbox.

## F23

NotificationRow: The unread dot does not scale with text. It is a fixed 12pt circle (Spacing.small) with a fixed 8pt top nudge (EdgeInsetsDirectional.only(top: Spacing.xSmall)) tuned against a 16pt eyebrow line. At 200% text the eyebrow line measures 64pt, so the dot sits in its top quarter and stops reading as 'beside the category label'.

## F24

NotificationRow: The G3 empty-payload fallback covers NotificationKind.newRequest only. An unknown-kind row (any wire `type` the mobile enum does not know) whose payload has empty title/body/ts renders as an 80pt tap target showing nothing but the generic 'Notification' eyebrow and an unread dot — all three `if (…isNotEmpty)` guards fail. Tapping it only marks it read (no deep-link, by design), so the user gets an unlabelled control that does nothing visible.

## F25

NotificationRow: An unparseable timestamp is printed verbatim in the timestamp slot. NotificationsL10n.relativeTime falls through to the raw string when DateTime.tryParse returns null, and DioNotificationsRepository accepts `ts`/`timestamp`/`createdAt` as whatever string the service sent — so one service formatting dates for humans leaks a raw field ('18/06/2026 10:00 AM') into the row. Invisible to every existing test, which asserts on semantics identifiers only.

## F26

NotificationRow: Read and unread rows differ by exactly two things: a FontWeight.w600→w400 swap on the title, and the presence of a 12pt dot. The dot carries no icon and no text — it is announced to screen readers by `copy.unreadLabel` on a decoration-only Container. Side by side in the canvas the two states are hard to separate at a glance, which is the condition the unread affordance exists to prevent.

## F27

OfflineBanner: Width starvation at phone width: MaterialBanner's single-action path lays icon + message + DISMISS out as ONE row, and OmdsPrimaryButton sizes to its label and never shrinks, so at 390 pt / 1x text the 62-char message gets 187 of 390 pt — SIX wrapped lines for one sentence, a 122 pt slab. Measured in lib/features/offline_mode/presentation/offline_banner.dart:41 (MaterialBanner has no forceActionsBelow). `forceActionsBelow: true` is the one-line fix.

## F28

OfflineBanner: The 200% ceiling makes it worse, not better, and does so SILENTLY: the DISMISS label grows with the text scale, so the message column NARROWS from 187 pt to 138 pt and wraps to eleven lines — a 332 pt banner, ~40% of a phone screen for one sentence. No RenderFlex overflow is thrown (the Expanded absorbs the squeeze), so nothing but a preview or an explicit geometry assertion catches it. Pinned by the 200% guard test.

## F29

OfflineBanner: OfflineState.pendingSyncCount (lib/features/offline_mode/application/offline_cubit.dart:15, maintained by enqueuePendingSync/syncCompleted) never reaches a pixel: a user with three unsent writes and a user with none see the byte-identical card and the same generic promise that 'changes will sync'. The `offlineBannerPendingSync` preview exists to show the count has nowhere to appear; the render test asserts the two banners are the same size and that no digit renders.

## F30

OrderSummaryPinned: `_PriceBlock` is a rigid (non-Flexible) child of the header Row with an unclamped `Text('$amount $currency')` — no maxLines, no overflow, no width ceiling. It claims its full intrinsic width, starves the `Expanded(_JeeberBlock)` beside it toward zero, and then the Row overflows. Measured on a 390dp canvas: the ORDINARY card (Kamal Hajj / 9.00 USD) is clean at 1.7x text scale, overflows by 3.6px at 1.8x and by 29px at 2.0x. This is not a rating-chip problem — the no-rating state overflows by the identical 29px.

## F31

OrderSummaryPinned: The same overflow reaches DEFAULT text size for high-magnitude currencies. With `1234567.89 SYP` in the pill the header Row overflows from a text scale of ~1.1 (21px), 43px at 1.2x, 222px at 2.0x. A 7-digit lira amount is the everyday case in a SYP market, so this is a shipping defect on ordinary data, not an a11y edge case.

## F32

OrderSummaryPinned: The sibling rendering of the same JM-031 contract already fixed exactly this and left the comment explaining why: `lib/features/live_tracking/presentation/widgets/order_summary_pinned_header.dart:78-92` wraps its price in `Flexible` + `maxLines: 1` + `TextOverflow.ellipsis` ("Flexible, not rigid: the name beside it is Expanded, so a long price would otherwise starve the name to zero width and then overflow the row itself"). `OrderSummaryPinned` — the primary widget — never got that treatment, so the two customer-facing renderings of one contract behave differently.

## F33

OrderSummaryPinned: The price renders as a bare `1234567.89` in BOTH locales: no thousands separator, no Arabic-Indic digits in AR, and the ISO code rather than a symbol. `price.toStringAsFixed(2)` at line 57 bypasses `intl` entirely.

## F34

OrderSummaryPinned: `summary.itemSummary` is free customer-typed text drawn through a bare `Text`, so the paragraph takes the AMBIENT direction rather than the string's own first-strong character (UAX#9). An Arabic item summary inside an EN UI is laid out LTR. The chat surface's sibling strip routes the same field through `AutoDirectionText`; this one does not.

## F35

OrderSummaryPinned: `dense: true` buys almost nothing — it swaps `Spacing.medium` for `Spacing.small` on the OUTER margin only (line 64) and leaves the inner padding and every inter-row gap untouched. Measured 314dp non-dense with an item line and 2 CTAs vs 266dp dense with neither; essentially all of that 48dp came from the dropped rows, not the flag.

## F36

HandoverCodeDisplay: The code WRAPS MID-NUMBER when it does not fit — HandoverCodeDisplay renders a bare Text with no FittedBox, no maxLines and no overflow, and Flutter's line breaker falls back to breaking a digit run at an arbitrary grapheme. Measured (widget-test font, so a worst case): in the 272 pt slot a 320 pt phone leaves (device - EdgeInsets.all(Spacing.xLarge) at both call sites), the 4-digit hero lays out on 2 lines at 1.0 text ('906' over '1') and 4 lines at 200% — one digit per line. A 6-digit code at the shipping 390 pt width (342 pt slot) lays out on 2 lines ('4819' / '02'). Stacked fragments read as two separate numbers, which is worse than clipping for the one string this widget exists to convey.

## F37

HandoverCodeDisplay: This CORRECTS the WAVE09 finding on OtpAtDoorCard, which recorded 'an all-numeric string has no break opportunity' and concluded the panel clips. It does not clip — it re-flows. Anyone triaging the at-door card from that note will be looking for the wrong symptom.

## F38

HandoverCodeDisplay: The Semantics live region merges its child, so the code is announced twice. `Semantics(identifier:…, liveRegion: true, label:…, value: code.split('').join(' '))` sets neither `container: true` nor `explicitChildNodes`, so the code Text merges in: the announced node comes out with label 'رمز التسليم\n‪0450‬' AND value '0 4 5 0'. A screen reader is free to voice the unspaced run in the label as the numeral 'four hundred fifty' before reading the digits individually — which defeats the point of the spaced value. Pinned in the render test ('the digits keep LTR order inside an Arabic tree'); `container: true` on that Semantics would drop the duplicate.

## F39

HandoverCodeDisplay: Roughly 112 pt of the hero panel's width is scale-invariant: `letterSpacing: Spacing.small` is a fixed 12 pt per glyph (48 pt for 4 digits) and the horizontal padding is a fixed Spacing.twoXLarge × 2 (64 pt). Neither responds to the text scaler while the glyphs do, so the 200% panel is more than twice as wide as the 100% one — that fixed 112 pt is what tips a code that would otherwise fit over the edge of its slot. On a standard 390 pt phone (342 pt slot) the 200% hero needs roughly 385 pt even with real Inter metrics, so the wrap is not only a test-font artefact or a 320 pt edge case.

## F40

HandoverCodeDisplay: Nothing in the widget enforces the 4-digit contract — `code` is rendered and announced verbatim at any length; only the JEEBER's submit button gates on `code.length == 4`. Not a bug today, but it is why the widened-code state degrades by re-flow rather than being rejected.

