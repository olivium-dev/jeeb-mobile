# Wave 20 (final) — defects

6/6 written, 33 previews. Coverage reaches 150/150.

## F01

RecentReviewsSection: OmdsReviewCard's header Row has no give: the trailing `timeAgo` stamp is neither Flexible nor maxLines-capped, so it is laid out at full intrinsic width and the Expanded name column absorbs every squeeze. RecentReviewsSection inherits it. Measured at 390pt (318px content row): the realistic '365 days ago' fixture overflows at 200% text; a spelled-out '11 months and 3 weeks ago' measures 310px of the 318px row and overflows by 44px at ONE-TO-ONE scale, with the name column handed ZERO width so the reviewer name wraps to one character per line. `RecentReviewPreview.timeAgo` is a free-form String with no contract, so nothing stops a caller producing that.

## F02

RecentReviewsSection: Hardcoded English: `title: 'Reviews'` and `viewAllText: 'View all'` are constructor defaults, not ARB lookups, so the header renders English in the AR locale (pinned by a test that pumps the happy path at locale 'ar'). Both translations already exist and go unused: deliveryManProfileReviewsTitle ('التقييمات') and deliveryManProfileViewAllReviews ('عرض الكل').

## F03

RecentReviewsSection: The verified badge is UNREACHABLE English: the widget does not expose `OmdsReviewCard.verifiedPurchaseLabel`, so 'Verified Purchase' cannot be localized even by a caller passing every parameter the section has. `reviewerVerifiedBadge` ('عميل موثّق') sits unused in the ARB.

## F04

RecentReviewsSection: An Arabic reviewer name is anonymised into a '?' avatar: OmdsReviewCard._buildUserAvatar derives its initial via RegExp(r'[a-zA-Z]') and falls back to '?' otherwise. DeliveryReviewCard explicitly works around this by building OmdsProfileAvatar itself; RecentReviewsSection delegates wholesale and inherits the defect (test asserts both Arabic-named reviewers render '?').

## F05

RecentReviewsSection: The header counts what it does not show: `count: reviews.length` over `reviews.take(maxItems)`, so twelve reviews render 'Reviews (12)' above three cards. Defensible with the CTA wired, but `showShowAll: onViewAllTap != null` suppresses the CTA when no callback is passed, leaving a count with no route to the reviews it promises.

## F06

RecentReviewsSection: The empty list renders NOTHING (SizedBox.shrink) — no header, no 'No reviews yet', no space. A parent that spaces its children gets a doubled gap and no explanation; deliveryManProfileEmptyReviewsTitle/Subtitle already exist for the surface that does render an empty state.

## F07

RecentReviewsSection: RTL: the OMDS star row spaces itself with `EdgeInsets.only(right:)` rather than `EdgeInsetsDirectional.only(end:)` (omds_review_card.dart:314), so in Arabic the 2pt gaps land on the leading side of each star. DeliveryReviewCard._ReviewStars already uses the directional form.

## F08

RecentReviewsSection: Star colour drift: `_ReviewCardItem` passes no `starColor`, so cards paint the OMDS gold `#FFB800` while both shipping review surfaces (ReviewRow, DeliveryReviewCard) pass `colorScheme.primary`. Three review widgets, two star colours.

## F09

SuperLoginEntryPoints: Tap targets are 16.0pt tall — measured, exactly one third of the 48pt WCAG 2.5.5 / Material minimum. Both links are a bare GestureDetector wrapped directly around a `bodySmall` Text (super_login_entry_points.dart:144 and :177): no Padding, no InkWell, no MaterialTapTargetSize floor, and default `deferToChild` hit testing, so the tappable region is exactly the glyph box in both axes. Pinned by `neither link reaches the 48dp minimum tap target` in the render test.

## F10

SuperLoginEntryPoints: The `Spacing.medium` separator between the two links is a fixed SizedBox, so at 200% text the labels double (16pt -> 32pt+) while the gap stays exactly 16.0pt. The two targets get closer together relative to their own size without getting any bigger, and the two underlined blocks read as one paragraph. Pinned by `the 16pt gap does NOT grow with text scale` (asserts gapAt200 == gapAt100 and gap < link height at 200%).

## F11

SuperLoginEntryPoints: At a 160pt column the English labels fit on one line and the Arabic ones do not: neither Text sets maxLines or an overflow, so `superLoginPlusTitle` degrades by growing into a multi-line underlined block and the two affordances stop reading as two. The EN light card looks settled in exactly the state where AR is broken — which is why that preview carries `matrix: true`. Pinned by `the narrow column wraps the Arabic labels, not the English`.

## F12

ReviewRow: The reviewer's first name is rendered TWICE, stacked, in the same style. review_row.dart:52 paints the D58 attribution `Text(review.reviewerFirstName)`, then line 65 passes the same string to `OmdsReviewCard(userName:)`, which paints it again in titleSmall/w600/onSurface — identical styling. Every card reads "Sami" / avatar + "Sami" / stars. Invisible to the existing suite: test/semantics_identifier_surfacing_test.dart only asserts that `review_<id>_reviewer_name` resolves, which it does. The in-code comment calls the second one "visual parity", but the two are never de-duplicated.

## F13

ReviewRow: The D27 report button renders BELOW the card's own bottom border, so in a list the hairline falls between a review's text and that review's own Report button — the flag visually attaches to the NEXT review. `OmdsReviewCard` paints a `Border(bottom: BorderSide(...))` on its container, and the report CTA is a sibling AFTER the card in ReviewRow's Column (review_row.dart:73-100).

## F14

ReviewRow: Consecutive rows draw two hairlines. The card's own bottom `BorderSide` always paints, and `ListView.separated` in reviews_list_screen.dart:466 inserts a `Divider(height: 1, indent: 16, endIndent: 16)` on top of it — two lines of slightly different inset between every pair of rows, plus one stray unpaired line under the last row (where the separator is suppressed but the card border is not).

## F15

ReviewRow: ReviewRow has no injectable clock. It calls `copy.relativeTime(review.timestamp)` without the `now` argument that `ReviewsL10n.relativeTime` accepts, so the displayed age resolves against the wall clock and cannot be pinned by a caller. Its direct sibling NotificationRow takes a `DateTime? now` for exactly this reason. Consequence beyond previews: any widget test of the age has to freeze the clock globally or accept drift.

## F16

ReviewRow: Every Arabic-named reviewer gets the "?" avatar. `OmdsReviewCard._buildUserAvatar` only accepts a first letter matching `[a-zA-Z]` (omds_library/lib/src/reviews/omds_review_card.dart:283), so "نور" produces no initial and falls through to the same "?" placeholder used for a completely unknown account — in an app that ships 1534 keys in Arabic. Visible in `reviewRowArabicReviewer`.

## F17

ReviewRow: `reportable: false` removes the row's only bottom padding, not just the button. The `bottom: Spacing.xSmall` inset lives on the report CTA's own `Padding` (review_row.dart:74-78), so a non-reportable row ends flush at the card's border — measured 159 pt vs 194 pt. The next row's attribution then butts directly against the divider.

## F18

ReviewRow: A star-only rating (`body: null`, which the R1m contract allows and `StubReviewsRepository` returns for one row per page) leaves a dangling 12 pt gap. ReviewRow coerces the null body to `''`, `OmdsReviewCard` then skips its text block entirely via `if (reviewText.isNotEmpty)`, but the `SizedBox(height: Spacing.small)` above it is unconditional — so the gap under the star row is there with nothing after it.

## F19

ReviewRow: Nothing on this row clamps at any level — no `maxLines`/`overflow` on the attribution, the card's `userName`, the `timeAgo`, or the body. A long but entirely plausible comment measures 425 pt at 1.0× text and 1339 pt at 200% on a 390 pt-wide phone: one review taller than three screens. It never overflows (the list scrolls) but it buries every row under it, and the 200% card has to be scrolled to be read.

## F20

ReviewRow: `OmdsReviewCard`'s star row uses non-directional insets — `EdgeInsets.only(right: index < 4 ? ... : 0)` at omds_review_card.dart:314 — so the inter-star gap does not mirror in RTL and the trailing star keeps its gap on the physical right. Cosmetic (the glyphs are near-symmetric) and it lives in OMDS rather than ReviewRow, but it is the one element in this row that ignores text direction. Same pattern on the `reviewImages` strip, which this screen does not use.

## F21

TierCard: The recommended badge is INVISIBLE on the selected card (light theme). The pill paints `scheme.tertiaryContainer` and the selected card paints `scheme.primaryContainer`, and AppTheme maps BOTH to #FFDBD1 — contrast 1.0:1 — while its ink `onTertiaryContainer` is byte-identical to the card's `onPrimaryContainer`. Flash is the only tier the catalog ever flags (`recommended: id == TierId.flash`), and a customer tapping that recommendation is exactly what turns the card `primaryContainer`, so the endorsement vanishes on the one card it can appear on. The dark scheme (ColorScheme.fromSeed) separates the roles, so it is a light-palette collision, not a layout bug. Pinned in `TierCard defects > the recommended pill is INVISIBLE on the selected card`.

## F22

TierCard: An unselected card has no visible edge. Fill is `surfaceContainerLow` #FAF8FA on the white page (1.04:1) and the only boundary is 1 dp of `outlineVariant` #E5E1E5 at 1.21:1 against that fill — well under the 3:1 WCAG 1.4.11 asks of a boundary that identifies a control. The selected card is fine (2 dp of `primary`); it is the four tiers a customer has not chosen yet, i.e. the ones they are comparing, that read as unbounded text blocks. Pinned in `TierCard defects > an unselected card is a 1.21:1 hairline on the page`.

## F23

TierCard: All three `TextOverflow.ellipsis` declarations in this widget are dead code. The header title (tier_card.dart:184) and both `_MetaRow` labels (tier_card.dart:239) declare `ellipsis` with NO `maxLines`, and the card is always measured against unbounded height (a `ListView` child in `_LoadedView`, a shrink-wrapping column in the preview), so they wrap instead of truncating and the card grows without bound on ops-authored catalog copy — 944 dp at 200% text for the long-copy state versus 584 dp for the longest shipping tier. Pinned in `TierCard defects > no `TextOverflow.ellipsis` in this card can ever fire`.

## F24

TierCard: Nothing in the card scales with text. Both `_MetaRow` glyphs are `Icon(size: Sizes.medium)` (16 dp) and the selected check is `Icon(size: Sizes.large)` (20 dp), all raw dp constants — at the 200% accessibility ceiling they stay 16/20 dp beside labels that have doubled. The check is also the only selection signal that survives a grayscale or colour-blind reading (`selected` otherwise only swaps fill, ink and border colour), so the mark that carries the most meaning is the one that shrinks relative to everything around it. Pinned in `TierCard defects > neither meta glyph nor the check grows with the text`.

## F25

AnimatedMicButton: The recording state cannot be pumped at all as written: `isRecording: true` starts `AnimationController.repeat(reverse: true)` in initState, which schedules frames forever, so the shared harness's `pumpAndSettle` fails with `pumpAndSettle timed out` (verified by temporarily un-muting the ticker and running the preview test). Every specimen therefore renders inside `TickerMode(enabled: false)`; that is a preview-side workaround, and it means the widget is untestable by any pumpAndSettle-based test in the repo today.

## F26

AnimatedMicButton: Disabled contrast fails badly in the light theme (animated_mic_button.dart:82-84 vs :137). The circle drops to `colorScheme.outline` (#916F66) at 40% alpha — ~#D3C5C2 over the white surface — while the glyph keeps `colorScheme.onPrimary` (pure white). That is roughly 1.7:1, far under the 3:1 WCAG minimum for a graphical object, and the mic is the only affordance on the voice-recording screen. Visible immediately in the 'Disabled · mic unavailable' card.

## F27

AnimatedMicButton: The halo is clamped before it finishes growing. The widget reserves `diameter * 1.6` (SizedBox at :103-104) but draws the halo at `diameter * _pulse.value * 1.35` (:111-112), which at the tween's 1.25 ceiling wants `diameter * 1.6875` — 222.75dp inside a 211.2dp box. A `Container` cannot exceed its constraints, so the top ~5% of every pulse cycle sits flat instead of expanding. Pinned in the test ('the reserved box is smaller than the peak halo') and drawn as two rings in the 'Halo ceiling' preview.

## F28

AnimatedMicButton: `haloColor` is derived from `colorScheme.primary` with no reference to `enabled` (:85-87), so `enabled: false, isRecording: true` renders a live brand-coloured halo around a dead grey circle. No screen builds that combination today, but it is one state update away (e.g. the 60s cap disabling the button under a held finger) — the 'Disabled mid-recording' preview is what that would ship as.

## F29

AnimatedMicButton: A single `semanticLabel` prop is the widget's only a11y channel, and it does not vary with `isRecording` or `enabled` — only `Semantics.enabled` flips. A screen-reader user pressing a disabled or already-recording mic hears the same 'Press and hold to record, release to stop' unless the host remembers to swap the string, which the production call site does not do.

## F30

WalletActivityRow: 200% text overflow — the signed amount is the ONLY non-flexible child of the Row and has no maxLines/overflow, so it takes its intrinsic width first. Measured at 390 pt with textScaler 2.0 on `walletActivityRowLongRef` (+1250.00 USD): the amount wants 337 pt of the 342 pt of content width, the Expanded text column collapses to ZERO width (type label and ref become invisible; 'Top up' reflows into a 200 pt-tall zero-width column) and the Row still throws 'A RenderFlex overflowed by 59 pixels on the right.' The EN 1.0x card looks fine. Fix would be Flexible/clamping on the amount Text in lib/features/wallet/presentation/widgets/wallet_activity_row.dart:101 — a production change, deliberately NOT made.

## F31

WalletActivityRow: RTL: the sign lands on the wrong side of the amount. WalletActivityL10n.signedAmount (lib/features/wallet/presentation/wallet_activity_l10n.dart:94) builds '+'/'-' + magnitude + ' ' + currency by concatenation. In an RTL paragraph the leading sign is a bidi neutral that resolves to the paragraph direction, so it is laid out at the RIGHT end of the run and the currency at the left: '-0.90 USD' renders visually as 'USD 0.90 -'. Measured with TextPainter(textDirection: rtl) on '+5.00 USD' — the sign's box is x 112..126 of a 126-wide run, the digits x 56..112, ' USD' x 0..56. This matters because the sign is the primary credit/debit signal (the only other one is the tint), so the Arabic row reads as the wrong direction of money. Needs a directional isolate or intl NumberFormat — production change, not made.

## F32

WalletActivityRow: The 56 pt _LeadingIcon is a fixed Sizes.fiveXLarge box and does not scale with text. At 200% the row grows 84 pt -> 344 pt while the typed glyph stays 24 pt, so the icon — one of the two at-a-glance signals for the ledger type — shrinks to a rounding detail at the accessibility ceiling.

## F33

WalletActivityRow: A row with a null `currency` renders a bare unit-less number. `currency` is nullable on WalletLedgerEntry and signedAmount simply drops the suffix, so `walletActivityRowUnknownType` shows '-1.75' with no unit at all. In a ledger a jeeber reconciles by hand that is a real ambiguity, and it is invisible to every existing test because they all assert on Semantics identifiers.

## F34

WalletActivityRow: The floor row is barely shorter than the full row: with no ref and no timestamp it is 80 pt vs 84 pt for the three-line state, because the 56 pt icon (not the text) sets the height. A page of degraded rows is mostly empty space with tap targets that say nothing about where they lead.

