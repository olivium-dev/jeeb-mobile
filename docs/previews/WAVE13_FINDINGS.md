# Wave 13 (delivery_man_profile + rating) — defects surfaced by the previews

8/8 written, 46 previews. Recorded, not fixed.

## F01

DeliveryReviewCard: Header Row overflows at 200% text in EVERY state, EN and AR. Measured at 390 logical px: the trailing 'N days ago' stamp in lib/features/delivery_man_profile/presentation/widgets/delivery_review_card.dart:105-111 is a bare Text with no Flexible/maxLines/ellipsis, so it takes 244-293 px of the 318 px content row; the 40 px avatar (Sizes.large * 2) does not shrink; the Expanded name column is squeezed past zero. Result: 'RenderFlex overflowed by 4.4-48 pixels on the right' for all six states (AR overflows by 1.2-45 px too). Worst case is the long-name state, where the stamp is drawn to x=382 on a card that ends at x=370 and is only hidden by the container's Clip.antiAlias.

## F02

DeliveryReviewCard: reviewRelativeDaysAgo has no plural form: it is a bare '{count} days ago' (lib/l10n/app_en.arb:3133) and 'قبل {count} يوم' (lib/l10n/app_ar.arb:1068) with placeholder type int and no ICU plural block. A day-old review renders '  1 days ago' in English; Arabic additionally needs the dual for count == 2 ('قبل يومين', not 'قبل 2 يوم'). The 'Rating only, no body' preview is seeded with daysAgo: 1 so this is visible in the canvas.

## F03

DeliveryReviewCard: The star score does not scale with text size. _ReviewStars renders each icon at a fixed size: Sizes.small (12 px) — delivery_review_card.dart:159-160 — and the avatar is a fixed Sizes.large * 2 (40 px). At the 200% text rendering the name, badge and body double while the star row and avatar stay at 12/40 px, so the rating (the card's primary content) becomes proportionally tiny for exactly the users who enlarged the text. The stars are also inside ExcludeSemantics, so that label is a screen reader's only access to the score.

## F04

DeliveryManMetaRow: Contrast fails AA: _MetaText inks the label with colorScheme.onSecondaryContainer (periwinkle #777FC0) and the row sits on the white profile surface (#FFFFFF) — 3.76:1 measured, against the 4.5:1 threshold that applies because bodyMedium is 14sp regular. The sibling chip rendering the SAME ARB keys (CustomerProfileRating, lib/features/customer_profile/presentation/widgets/customer_profile_rating.dart) uses onSurfaceVariant (#5C4038) and passes. #777FC0 has already been ruled out for text by in-repo audits in chat_fee_banner.dart, offer_accepted_banner.dart, settlement_screen.dart and active_request_card.dart; this row was missed. Pinned by the 'the label fails AA on the white profile surface' test.

## F05

DeliveryManMetaRow: Doc/implementation drift on the accent glyph: the class doc comment claims 'The leading glyph is brand orange (ColorScheme.primary per design §4)', but the b02 palette audit in lib/core/theme/app_theme.dart moved brand orange (#D73B00) onto `tertiary` and left `primary` navy (#0B1351) — and explicitly says 'Anything that wants to PAINT with brand orange (a progress bar, an accent icon) must use `tertiary`'. The star/location glyph renders navy, so the design's orange accent never ships and the doc asserts the opposite. Pinned by the 'the "brand orange" glyph is navy' test.

## F06

DeliveryManMetaRow: Icon does not scale with text: Icon(size: Sizes.medium /*16dp*/) with applyTextScaling left at its false default. At the 200% ceiling the label goes 14sp -> 28sp while the glyph stays exactly 16x16, and it still consumes 24pt (icon + Spacing.xSmall gap) of the 250pt column that the label is at that point truncating out of. Same defect class already documented for CustomerProfileRating's star.

## F07

DeliveryManMetaRow: Content truncation drops the actionable half of the row: at the DEFAULT text size (not only at 200%), 'Bourj Hammoud, Mount Lebanon . Unavailable' is ellipsized in the 180pt column a 320pt phone gives the details column (156pt after the glyph and gap). Because Text ellipsizes the END, what is cut is the availability label — the one fact on the row a client acts on — leaving a bare place name. `overflow: ellipsis` also wins over the null maxLines, so the row stays one line and nothing signals the loss. At 200% text even the plainest state, 'Lebanon . Available', truncates on a full-size 390pt phone.

## F08

DeliveryManMetaRow: Mixed-direction user content is not direction-handled: `location` is gateway free text and is routinely Latin script even in the Arabic UI, but _MetaText is a plain Text. The name one row above it in the same header (_NameText in delivery_man_profile_header.dart) runs through AutoDirectionText for exactly this reason. The AR rendering lays out 'Lebanon . متاح' by ambient paragraph direction alone, with the neutral separator resolving to the base direction.

## F09

DeliveryManMetaRow: No empty-state copy: with reviewCount 0 the cold-start branch renders the count template literally — ' 0 Reviews', and in Arabic '0 تقييم' with a Western digit inside Arabic script. CustomerProfileRating meets the identical payload and switches to deliveryManProfileEmptyReviewsTitle ('No reviews yet' / 'لا توجد تقييمات بعد') — a key this widget's OWN feature namespace owns. Two surfaces, one payload, two different answers.

## F10

DeliveryManMetaRow: Copy defect visible in every joined state: the ARB values are '{rating} . {count}' and '{location} . {availability}' — a full stop with a space either side — while the widget's design intent, the F9 test comments and the semantics test fixture all write the separator as '·'. What ships reads '4.3 . 113 Reviews', which parses (and is announced by a screen reader) as a sentence break rather than a separator.

## F11

DeliveryManProfileHeader: Availability is silently truncated away at 1x on a full-size phone. `_AvailabilityRow` joins location + availability into ONE string with availability LAST, and `DeliveryManMetaRow._MetaText` sets `overflow: ellipsis` with `maxLines: null` — which the paragraph builder resolves to single-line truncation, not wrapping. Measured: 'Beirut, Mount Lebanon Governorate . Available' gets 226 dp, `didExceedMaxLines` is true, so the cut end is ' . Available'. The answer to 'can this jeeber take my delivery?' disappears with no text scaling involved. Pinned in the test.

## F12

DeliveryManProfileHeader: Dark theme: the jeeber's name and the verified badge are both inked with `colorScheme.secondaryContainer` — a *container* role used as ink. Measured #44455A on the #131318 surface of `ColorScheme.fromSeed(_jeebNavy, dark)` = 1.98:1, under the 3:1 WCAG floor for large text. Light measures 17.1:1, so the AR RTL dark rendering of every state is the name nearly dissolved into the page.

## F13

DeliveryManProfileHeader: Light theme (the default): both meta rows use `colorScheme.onSecondaryContainer` = `_jeebMutedPurple` #777FC0 on white = 3.76:1 at 14 dp regular, under the 4.5:1 AA floor. That is the score AND the location/availability line — every word of the header except the name. Dark measures 14.3:1 on the same role. (Same number already flagged from the child's side in `delivery_man_meta_row_preview.dart`.)

## F14

DeliveryManProfileHeader: `_NameText` passes no `maxLines`/`overflow`, so names wrap and grow the header instead of ellipsizing (`ClientHomeGreeting` clamps to one line). Measured at 390 dp: an ordinary four-word Arabic name already takes 2 lines / 140 dp at 1x, and the longest plausible Latin name takes 3 lines / 172 dp at 1x and 436 dp at 200% text — over half a 390x844 phone for the header alone, pushing the reviews list it heads below the fold.

## F15

DeliveryManProfileHeader: `_NameRow` centres the SealCheck (`CrossAxisAlignment.center`) against the whole wrapped name block: measured at y 50–70 against a name spanning y 12–108, so on a 3-line name the badge floats beside the middle line and reads as an orphaned glyph.

## F16

DeliveryManProfileHeader: D59 cold-start copy has no plural form in either locale. `deliveryManProfileReviewsCount` is resolved by literal `{count}` substitution, so a jeeber's first review reads '1 Reviews' and no ARB edit can fix it; the Arabic value `{count} تقييم` is the singular for every count from the other side. Counts are also interpolated as `'$count'` — '1284' ungrouped in English, Western digits inside Arabic script.

## F17

DeliveryManProfileHeader: `rating.toStringAsFixed(1)` rounds UP: 4.96 renders as a perfect '5.0'. That is the one direction a trust signal must not round. Pinned in the test.

## F18

DeliveryManProfileHeader: The verified badge is granted by a default, not by evidence. `DeliveryManProfileViewData.isVerified` defaults to true and `ClientOffersScreen._openJeeberProfile` (the only route into this screen) never passes it, so a zero-review account whose name fell back to the localized 'New Jeeber' placeholder is still shown the strongest trust signal on the screen. Pinned as a tripwire test.

## F19

DeliveryManProfileHeader: `DeliveryManMetaRow`'s own doc claims its leading glyph is 'brand orange ([ColorScheme.primary] per design §4)', but after the b02 palette audit `primary` is `_jeebNavy` #0B1351 — the star and the pin render navy. Brand orange lives on `tertiary`. (Also already flagged in `delivery_man_meta_row_preview.dart`.)

## F20

DeliveryReviewsHeader: Pluralization: `deliveryManProfileReviewsCount` is `"{count} Reviews"` with a plain `int` placeholder and `AppLocalizations` resolves it with `replaceFirst('{count}', '$count')` — there is no ICU `plural` select, so a jeeber's first rating renders "1 Reviews". Arabic is worse: `"{count} تقييم"` is one fixed form for every count, so the 3–10 band (تقييمات) and the 11+ band are both wrong. Reachable constantly (every new jeeber). Pinned in the test as a defect, not a contract.

## F21

DeliveryReviewsHeader: Dark-mode contrast: `_ReviewsTitle` inks with `theme.colorScheme.secondaryContainer` — a *container* role, i.e. a fill meant to sit behind ink (app_theme.dart says so itself). Light survives only because the light scheme hard-codes that role to brand navy (17.13:1 on white). The dark scheme is `ColorScheme.fromSeed(_jeebNavy, dark)`, where it resolves to a dark container tone on a near-identical surface — under 3:1, i.e. the "Reviews" heading is near-invisible in dark mode. Same defect class already pinned for `CustomerProfileSectionHeader` and `JeebVerifiedBadge`.

## F22

DeliveryReviewsHeader: Light-mode contrast (the DEFAULT rendering): `_CountAndViewAll` inks the count with `theme.colorScheme.onSecondaryContainer` — a colour chosen to sit ON the navy `secondaryContainer` fill — but paints it on the plain `surface`. That is muted purple #777FC0 on white = **3.763:1**, under the 4.5:1 WCAG AA floor for 14 pt `bodyMedium`. Against the fill it was named for it measures 4.55:1, so the colour is fine and the surface it is used on is the bug.

## F23

DeliveryReviewsHeader: Number formatting: the count is interpolated raw (`'$count'`), so there is no thousands grouping ("128450 Reviews", never "128,450") and no locale digit shaping — the Arabic string carries Western digits. The ARB placeholder declares `type: int` but no `format`, so no NumberFormat is ever applied.

## F24

DeliveryReviewsHeader: Row priority at the accessibility ceiling: the count is `Flexible` but the "View all" `OmdsPrimaryButton` defaults to `width: null`, so the button is laid out with unbounded main-axis constraints and keeps its full intrinsic width while the count absorbs the loss. At 320 pt / 200% text the count wraps onto two lines. It does not clip only because the count `Text` has no `maxLines` and no `overflow` to fall back on — nothing in the widget enforces the graceful degradation, and adding either would turn this into an ellipsis or a clip.

## F25

DeliveryReviewsHeader: Zero-count copy: at `reviewCount == 0` the header still renders "0 Reviews" and a live "View all" that pushes the paginated `reviews-list` route, stacked directly on top of `DeliveryReviewsList`'s "No reviews yet" empty state. A brand-new jeeber's profile therefore offers a navigation into a second empty list. Not a crash — a copy/UX decision that had never been looked at in a picture.

## F26

DeliveryReviewsList: DeliveryReviewCard header row overflows and the reviewer's name is squeezed to ZERO width at 200% text. The header is Row(avatar, gap, Expanded(name/badge/stars), Text(daysAgo)) at lib/features/delivery_man_profile/presentation/widgets/delivery_review_card.dart:62 — the relative timestamp Text (line 105) is the one child with no Flexible/Expanded around it, so it takes its full natural width and the Expanded name column absorbs the entire deficit. Measured on a 390 pt card: timestamp 148.8 pt -> 292.8 pt between 1x and 2x while the name column goes 115.2 pt -> 0.0 pt, and the row overflows by 29 px. Result at the 200% accessibility ceiling: the review is attributed to nobody — the first name and the 'Verified Client' badge are both gone, and the timestamp survives. It is not exotic: at 1.5x the default two-review list and even the short 'Rania / 30 days ago' card overflow too. Pinned in the render test as 'DEFECT: at 200% text the reviewer name is squeezed to zero'.

## F27

DeliveryReviewsList: The star rating does not scale with text at all. _ReviewStars (delivery_review_card.dart:158) builds Icon(..., size: Sizes.small) with no applyTextScaling, so the five stars measure exactly 12x12 at 1x AND at 2x while every surrounding string doubles. A user who has doubled their text size gets 24 pt type wrapped around a 12 pt rating — the one element the card exists to convey. It is also the second half of the overflow above: the star Row is mainAxisSize.min and cannot shrink, so once the Expanded column is squeezed the stars are what spills over the trailing edge. Pinned as 'DEFECT: the stars do not scale with text'.

## F28

DeliveryReviewsList: NOT a defect, recorded so it isn't re-investigated: RTL is clean. The list padding is EdgeInsetsDirectional, the star gaps use EdgeInsetsDirectional.only(end:), and all six states mirror correctly with no hardcoded English — the AR renderings and the ar-locale render tests pass. The failures above are locale-independent.

## F29

FeedbackStarInput: Tap targets are 8 dp under the project's own floor: each star is a bare 40 dp Icon inside a GestureDetector (starSize: Sizes.threeXLarge = 40), and RenderPadding does not hit-test the 4 dp spacer, so all five hit boxes measure exactly 40x40 against A11y.minTapTargetSize = 48 (AC T-mobile-036). Nothing wraps them in MinTapTarget. Pinned by 'every star is 8 dp under the minimum tap target'.

## F30

FeedbackStarInput: RTL does not mirror the row spacing. OmdsStarRating (omds_library/lib/src/reviews/omds_star_rating.dart:66) spaces with a PHYSICAL EdgeInsets.only(right: spacing) instead of EdgeInsetsDirectional.only(end:). The Row mirrors, the padding does not, so under Arabic the whole gap sequence slides one glyph over: gaps become [4, 4, 4, 0] — the 4th and 5th stars touch — plus a stray 4 dp inset on the leading (right) edge. Measured, and mutation-checked (asserting [4,4,4,4] fails). Fix is upstream in OMDS, not in FeedbackStarInput.

## F31

FeedbackStarInput: The control does not scale with text. Icon sizes are logical pixels, so the row is the same 216 x 40 at 100% and at the 200% ceiling the accessibility AC asks for — the label describing the rating doubles while the thing being labelled stays put, which is the worst pairing for low-vision users.

## F32

FeedbackStarInput: Semantics announces a slider that cannot be adjusted. The wrapper sets slider: true and value: '$stars / 5' but wires up neither SemanticsAction.increase nor decrease, so a screen reader offers 'swipe up/down to adjust' on a control where that does nothing; the only way to rate is to hit one of the 40 dp stars. The node also carries no label at all, so it announces bare '0 / 5' with nothing to say it is a rating.

## F33

FeedbackStarInput: `stars` is an unvalidated int with no assert and no clamp: 9 paints five filled stars, pixel-identical to a genuine five-star rating, and a negative value is pixel-identical to *unrated* — the one value the submit gate (`if (_stars == 0) return`) treats as special. This is reachable from data, not just a typo: CounterpartRating.fromJson parses the score-taking payload as `(raw as num?)?.toInt() ?? 0`, tolerating both the `stars` and `score` keys and clamping neither.

## F34

FeedbackStarInput: Doc/impl mismatch in the widget's own comment: it says the container announces 'e.g. "3 of 5 stars"' for screen readers, but the code publishes '3 / 5'. The published string is also punctuation, not localized copy, so it reads the same in Arabic.

## F35

FeedbackAvatar: CONTRAST (light theme, ships this way): OmdsProfileAvatar defaults `initialColor` to a hardcoded `Colors.white` and FeedbackAvatar overrides nothing, so the initial is white ink on `colorScheme.primaryContainer`. Since the b02 tone-pair correction that role is the M3 tone-90 #FFDBD1 — white on it measures 1.29:1, far under the 3:1 WCAG floor for large text. Measured off the live render tree, not the palette constants. The dark scheme's generated #3C4279 is fine at 9.34:1, so only the EN light rendering shows it. Pinned by the `paints the initial white on primaryContainer (1.29:1 light)` tripwire test. This is not FeedbackAvatar-specific: every OmdsProfileAvatar placeholder in the light theme has it.

## F36

FeedbackAvatar: CRASH on a non-BMP first character: FeedbackAvatar computes `trimmed.characters.first` (a grapheme, 2 UTF-16 code units for an emoji) and OmdsProfileAvatar re-slices it with `initial[0]` (omds_profile_avatar.dart:135), leaving an unpaired high surrogate in the Text. The engine throws `ArgumentError: string is not well-formed UTF-16` from `_NativeParagraphBuilder.addText` during layout — no render, not a replacement glyph. Reachable in production: `rateeName` comes unsanitized from `state.uri.queryParameters['name']` on `/orders/:id/feedback` (app_router.dart:1441). This state could NOT be shipped as a preview (it fails the harness's `takeException() isNull` check by definition), so it is documented in the preview's library doc instead.

## F37

FeedbackAvatar: GRAPHEME TRUNCATION (same root cause, non-fatal): a decomposed first letter loses its combining marks. 'ا'+U+0653 (NFD 'آ', what an iOS keyboard produces) renders as a bare alef — a different letter from the one the user types. Previewed as 'Decomposed first letter' and pinned by a tripwire test.

## F38

FeedbackAvatar: 200% TEXT: the initial is a plain `fontSize: size / 2.5` with no TextScaler clamp while the circle is a hard 96 dp (`Sizes.tenXLarge`). Measured: 38.7x55.0 dp at 1x; at 2.0 the line box wants 110 dp and is clamped to the 96 dp the circle can give, so the glyph paints past the circle edge — `Container` sets no `clipBehavior` — landing white-on-white on the page background. The two sizes being equal is the overflow.

## F39

FeedbackAvatar: SEMANTICS: the decorative initial is not excluded from the semantics tree, so the image node's label is the name plus the glyph — measured `'We appreciate your feedback\n?'`, and `'Rami Chidiac\nR'` for a named ratee. A screen reader announces the letter after the name. Related dead branch: the localized fallback is guarded by `name.isEmpty`, not by the trimmed name, so a whitespace-only name ('   ') renders '?' visually while the a11y label is blank whitespace.

## F40

FeedbackAvatar: DEAD PHOTO PATH: `avatarUrl` cannot be exercised on the only route that mounts this widget — `/orders/:id/feedback` (app_router.dart:1433) builds RatingScreen with deliveryId/isClient/rateeName and never passes `rateeAvatarUrl`, which itself defaults to null. The shipped feedback screen always renders an initial; the CachedNetworkImage branch is unreachable there.

## F41

FeedbackHeader: Subtitle fails WCAG AA in LIGHT mode — the DEFAULT rendering. `_FeedbackSubtitle` inks with `colorScheme.onSecondaryContainer`, which AppTheme's light scheme hard-codes to the Figma muted purple #777FC0; on the white surface that measures 3.76:1 against the 4.5:1 floor for 14sp body text. It is being read against `surface`, not against the `secondaryContainer` fill it is the ON-colour for — nothing on this screen paints that fill. Fix: ink with `onSurfaceVariant`, the role AppTheme already reserves for subtitles.

## F42

FeedbackHeader: Title is near-invisible in dark mode: `_FeedbackTitle` inks with `colorScheme.secondaryContainer` — a container role used as ink, the exact misuse app_theme.dart warns about in its own comments. Light survives at 17.13:1 only because the role is hard-coded to brand navy; the dark scheme is `ColorScheme.fromSeed(_jeebNavy, dark)` where it resolves to 1.98:1, under even the 3:1 large-text floor. Same defect class already pinned for CustomerProfileSectionHeader and JeebVerifiedBadge, so this is a third instance of one palette bug.

## F43

FeedbackHeader: The two defects are mirror images, so no single rendering shows both: in light the title is fine (17.13:1) and the subtitle fails (3.76:1); in dark the subtitle is fine (14.29:1) and the title fails (1.98:1). Reviewing only the EN light card hides half of it.

## F44

FeedbackHeader: `FeedbackHeader`'s Column leaves `mainAxisSize` at its `MainAxisSize.max` default, so in any parent that passes a bounded height it swells to fill it and pins its two paragraphs to the top of that space — on a widget whose every other alignment decision (`TextAlign.center`, the Column's default `CrossAxisAlignment.center`) says 'centred block'. Today's single caller only escapes it because `_FeedbackContent` sits inside a `SingleChildScrollView`, which hands unbounded height; a Stack/Expanded/fixed-height slot would land it as 'the title sticks to the top', which reads as a padding bug three files from the cause. Pinned by the 'fills a bounded parent instead of shrink-wrapping' test.

## F45

FeedbackHeader: The screen's own heading is not a heading to a screen reader: the title is a bare `Text` with no `Semantics(header: true)`, so heading navigation has nothing to land on. Pinned as a documented gap (with a delete-me note) rather than as a contract.

