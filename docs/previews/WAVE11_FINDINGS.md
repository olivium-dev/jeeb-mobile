# Wave 11 (customer_profile + kyc) — defects surfaced by the previews

8/8 written, 46 previews. Recorded, not fixed.

## F01

CustomerProfileSectionHeader: Dark-mode contrast failure (measured): the title is inked with `theme.colorScheme.secondaryContainer` — a *container* role, i.e. a fill meant to sit behind ink. In AppTheme.dark() (`ColorScheme.fromSeed(_jeebNavy, dark)`) that resolves to a dark container tone against a surface of nearly the same tone: **1.98:1**, below the 4.5:1 WCAG AA floor for body text and below even the 3:1 large-text floor. The Account/Support headers are near-invisible in dark mode. It survives in light only because the light scheme hard-codes that role to the brand navy (17.13:1 on white). `app_theme.dart` states the rule it is breaking in its own words: "Anything that wants to PAINT ... must use `tertiary`, never a `*Container` role." Correct role here is `onSurface`, `secondary`, or `onSecondaryContainer`. Sibling widget `JeebVerifiedBadge` has the identical defect and its preview test already pins the same gap — so this is a palette-usage pattern, not a one-off. Pinned in the new test as `lessThan(3.0)` with a delete-me-when-fixed reason.

## F02

CustomerProfileSectionHeader: A11y: the header is not exposed as a heading. It renders a bare `Text` with no `Semantics(header: true)` and no caller adds one (`customer_profile_rows.dart` just drops it in a Column; the only `Semantics` on the screen wraps the profile header). TalkBack/VoiceOver read "Account" as ordinary text, so heading navigation cannot jump between the Account and Support sections — the sectioning is purely visual. Pinned as `flagsCollection.isHeader` isFalse with a reason saying it documents a gap, not a contract.

## F03

CustomerProfileSectionHeader: Empty title renders an invisible but space-consuming band. `title` is `required`, which only means supplied — nothing asserts non-empty and the widget does not short-circuit. `CustomerProfileSectionHeader(title: '')` paints zero pixels while still reserving 20 (top) + a full line + 8 (bottom), exactly as much vertical space as a titled header (asserted equal in the test). Between two rows that reads as a layout bug rather than as missing copy. Not reachable from today's two ARB-constant callers, but a server-named section or an ARB key lost in a merge reaches it silently.

## F04

CustomerProfileSectionHeader: The widget shrink-wraps under loose constraints. Its only production parent is `CustomerProfileRows`' `Column(crossAxisAlignment: stretch)`, which gives it a tight width; dropped into any loosely-constrained host (the preview `Scaffold` body is one) the `Text` sizes to its own glyphs and the header stops filling the gutter-to-gutter band it is designed to occupy. The preview had to add an explicit `_stretched` host to reproduce production geometry — the widget offers no width behaviour of its own.

## F05

CustomerProfileSectionHeader: `EdgeInsetsDirectional.fromSTEB` is dead intent for the horizontal axis: start and end are both `Spacing.xLarge` (24), so the mirroring it buys is unobservable in the padding. The ONLY thing that mirrors is the paragraph's alignment inside its box, which is a `Text` default, not something this widget does. Verified by measuring glyph boxes (EN glyphs at the left edge, AR glyphs at the right edge) rather than the render box, which is byte-identical in both directions.

## F06

CustomerProfileHeader: Dark-mode contrast failure on the name — the single most important string on the screen. `_NameText` paints with `colorScheme.secondaryContainer` (customer_profile_header.dart:161-163), a *container* role used as ink. In AppTheme.light() that is brand navy on white (17:1), but AppTheme.dark() is `ColorScheme.fromSeed`, where the same role resolves to #44455A against the #131318 surface = **1.98:1**, under the 3:1 WCAG floor for large text (measured from the live ColorScheme, not estimated). The rating/email lines beside it use `onSurfaceVariant` and sit at 10.9:1, so the name is the least legible text in the header. The app runs `themeMode: ThemeMode.system` (app.dart:623, jeeb_bootstrap.dart:192), so this is shipping to any user with a dark OS.

## F07

CustomerProfileHeader: The name never ellipsizes — it wraps and grows the header without bound. `_NameText` passes no `maxLines`/`overflow` to `AutoDirectionText` inside a 222 dp column (390 − 48 padding − 80 avatar − 12 gap − 28 badge). Measured at 390 dp with bundled Inter: 'Abdulrahman Al-Muhandis Al-Trabulsi' takes 3 lines, making the header 236 dp at 1x and **592 dp at 200% text** — taller than a phone viewport, so every account row below it (the header is the first child of the profile ListView) is pushed off screen. The sibling ClientHomeGreeting clamps the same content with `maxLines: 1, TextOverflow.ellipsis` (client_home_greeting.dart:135-136); this header does not.

## F08

CustomerProfileHeader: The verified badge is orphaned once the name wraps. `_NameRow` uses `CrossAxisAlignment.center`, so the SealCheck is centred against the *whole* wrapped text block rather than following the name: measured at y 94–114 beside a name spanning y 56–152, i.e. floating next to the middle line. Mirrors correctly in AR (x 24–44 vs 346–366), so this is a wrapping bug, not an RTL bug.

## F09

CustomerProfileHeader: Synthetic identities leak on the one screen a customer opens to check who they are. `DioCustomerProfileRepository._parse` (dio_customer_profile_repository.dart:70-71) passes `name`/`email` through verbatim, and the header renders them raw, so an OTP-only account sees 'jeeb-e1a35ea8a520' as its name and 'phone-only+<hash>@jeeb.internal' as its email. ClientHomeGreeting, the offer cards and the chat pinned summary all route the same values through `displayNameOrNull` (core/formatting/friendly_reference.dart) — the sprint-009 §T5 fix never reached this widget.

## F10

CustomerProfileHeader: Cold start has no name affordance and an empty a11y node. `shell_screen.dart:341` mounts the tab as `CustomerProfileScreen(data: CustomerProfileViewData())` — every field null — so the first frame for every user renders `AutoDirectionText('')` inside `Semantics(identifier: 'customer_profile_name', label: '')`: a visible gap where the name will appear, plus a semantics node a screen reader lands on and announces nothing for. There is no skeleton/placeholder (contrast with the avatar, which does fall back to '?').

## F11

CustomerProfileHeader: The email line is unclamped too (`_Email`, bodyMedium, no `maxLines`), so a long address wraps rather than truncating — 'phone-only+cb39e21caa82@jeeb.internal' already makes the header 204 dp at 1x and 424 dp at 200%, before any long *name* is involved.

## F12

CustomerProfileRow: Dark-mode icon disc is invisible (1.40:1). Every CustomerProfileRow composes CustomerProfileIconDisc, which paints Icon(color: colorScheme.onSecondary) on a colorScheme.secondaryContainer fill. The light scheme hand-authors that pair as white-on-navy (measured 17.13:1) so it passes; the dark scheme is ColorScheme.fromSeed, where onSecondary is the DARK ink meant for the light `secondary` tone — #2D2F42 glyph on #444559 disc = 1.40:1. The M3-correct pair for that fill, onSecondaryContainer, measures 7.23:1. Every AR RTL dark rendering of these previews shows an empty navy circle where the row's icon should be.

## F13

CustomerProfileRow: The label truncates instead of wrapping, and the row never grows — so it clips at the 200% text ceiling the goldens already assert. _RowContent's Text passes overflow: TextOverflow.ellipsis with no maxLines, which caps the paragraph at one line rather than wrapping then ellipsizing, and the row measured exactly 56.0dp tall in every configuration probed (390dp and 320dp width, 1x and 2x text). With bundled Inter the label budget at phone width is 286dp: 'Password and security' wants 155dp at 1x (fine) but 307dp at 200% text, and the Arabic 'كلمة المرور والأمان' wants 327dp — i.e. the longest Account row label is already cut at the accessibility ceiling.

## F14

CustomerProfileRow: The trailing widget is charged to the label, not to the row, so the register row clips first. CustomerRegisterPill is an intrinsic-width OmdsPrimaryButton that consumes ~89dp of the row before the Expanded label sees any of it (213dp of label at 390dp width, versus 286dp for a chevron row). On a 320dp phone at 200% text the label is squeezed to 87dp of the 289dp it wants while the pill keeps its full intrinsic width — the row's own affordance text is what gets cut, and what survives is a pill that duplicates the tap action the whole row already exposes (CustomerRegisterPill is even wrapped in ExcludeSemantics for exactly that reason).

## F15

CustomerProfileRow: The list's only destructive row is visually indistinguishable from its navigation siblings. 'Sign out' renders with the same onSurfaceVariant label, the same navy icon disc and the same forward disclosure chevron as 'Language' or 'Saved addresses'; CustomerProfileRow has no variant/tone parameter, so nothing in the row signals that this one does not open a screen. Design-level rather than a layout defect, but it is only visible when the sign-out row is reviewed next to a navigation row, which the preview set now makes possible.

## F16

CustomerProfileIconDisc: DARK-SCHEME CONTRAST (real, measured): the disc pairs `secondaryContainer` (fill) with `onSecondary` (glyph) — not an M3 pair. In AppTheme.light() `onSecondary` is hardcoded white so the glyph is 17.13:1 on navy and the bug is invisible. AppTheme.dark() is `ColorScheme.fromSeed`, where `onSecondary` is a DARK tone: the glyph renders at 1.40:1 against its own fill — below the WCAG 1.4.11 3:1 floor for graphical objects, i.e. a navy circle with nothing legible in it, on all 8 customer-profile rows. `onSecondaryContainer` on the same fill measures 7.23:1. Caution for whoever fixes it: the naive swap also changes light mode, where `onSecondaryContainer` is `_jeebMutedPurple` = 4.55:1 (passes 3:1, but drops from 17.13:1). Ratios computed from AppTheme.light()/dark() via a throwaway probe (now deleted). Source: lib/features/customer_profile/presentation/widgets/customer_profile_icon_disc.dart:26.

## F17

CustomerProfileIconDisc: DARK-SCHEME DISC-ON-SURFACE (same root cause, second symptom): `secondaryContainer` against dark `surface` is 1.98:1, so in dark mode the disc barely separates from the page either — the leading column of every profile row loses both its glyph and its shape at once.

## F18

CustomerProfileIconDisc: RTL: THE SIGN-OUT GLYPH DOES NOT MIRROR. `Icons.logout_outlined` is `IconData(0xf199, fontFamily: 'MaterialIcons')` with no `matchTextDirection` (unlike `Icons.arrow_forward` / `chevron_right`, which do carry it). The disc passes its IconData straight to `Icon`, so in Arabic the door-and-arrow still points right — the user exits backwards. `lib/core/widgets/directional_icons.dart` exists precisely to prevent this and the sign-out row never went through it. The fix belongs at the call site, lib/features/customer_profile/presentation/widgets/customer_profile_rows.dart:103, not in the disc.

## F19

CustomerProfileIconDisc: TEXT SCALING: both dimensions are fixed tokens (`Sizes.twoXLarge` = 32dp disc, `Sizes.large` = 20dp glyph) and `Icon` is not opted into `applyTextScaling`, so at the 200%-text rendering the row label doubles while the disc does not move. Nothing clips (CustomerProfileRow's 48dp ConstrainedBox absorbs it), but the leading icon shrinks in relative terms until it reads as decoration for exactly the users who need it to read as an affordance.

## F20

CustomerProfileIconDisc: GLYPH-SET WEIGHT INCONSISTENCY (visual, lower confidence — judgement not measurement): the 8 production glyphs mix `_outline`, `_outlined` and `_none` variants. Seen together in the 'All 8 production glyphs' specimen, `notifications_none` is a hairline bell beside the much heavier `delivery_dining_outlined`; at 20dp that weight difference is the loudest signal in the leading column.

## F21

CustomerRegisterPill: CustomerRegisterPill does not own its 'hugs its label' width — it borrows it from the Row it happens to live in. OmdsPrimaryButton is given `width: null`, so its inner `Center` shrink-wraps ONLY while the main-axis constraint is unbounded (which is what CustomerProfileRow's non-flexible Row slot supplies). Measured: 144.8 dp wide in the row vs 374.0 dp when the parent hands it a bounded width (Column with crossAxisAlignment.stretch, SizedBox, bottom sheet). Same widget, same arguments, silently a full-width CTA instead of a chip. Nothing in the widget prevents it (no IntrinsicWidth / mainAxisSize.min wrapper / width) and its own doc comment claims the opposite: 'sized to wrap its label'. lib/features/customer_profile/presentation/widgets/customer_register_pill.dart:26

## F22

CustomerRegisterPill: The pill's box is hard-coded to 40 dp (`height: Sizes.threeXLarge`) but its label scales with text size, so the label is cropped, not accommodated, above 200%. Measured at 390 dp: 1.0x -> pill 144.8x40, label line box 20.0; 2.0x -> pill 256.8x40, label line box 40.0 — exactly flush, 0.0 dp of vertical headroom at the accessibility ceiling the goldens assert. At 2.5x the label's natural line box is 50.0 dp and RenderParagraph crops it back to 40.0: no overflow stripes, no exception, just a guillotined 'Register'. iOS Dynamic Type goes past 250%. Pinned by the 'crops its label above 200%' test.

## F23

CustomerRegisterPill: At 250% text the register row overflows horizontally: 'A RenderFlex overflowed by 11 pixels on the right' at a 390 dp width. The pill is a non-flexible Row child that keeps growing with text scale (144.8 -> 312.8 dp at 2.5x) while the Expanded row label has already collapsed to zero, so there is nothing left to give. This is why 250% is documented in the preview but deliberately NOT a preview state — it throws during layout and would fail the whole render-test file instead of reporting the one defect.

## F24

CustomerRegisterPill: Exposed by the real composition, and it belongs to the HOST not the pill: CustomerProfileRow announces its label TWICE. The merged semantics node reads label: "Register as a delivery\nRegister as a delivery" — once from its `Semantics(label:)` wrapper and once from the visible `Text` it does not exclude. The pill's own JEBV4-98 / F10-F11 contract is intact (its text folds into the row's node, id-identical, and contributes no third 'Register' segment), which is what the specifics test asserts per-segment rather than pinning the duplicated string.

## F25

CustomerProfileRating: Arabic empty state truncates on a full-size phone at the accessibility ceiling. At 200% text the cold-start copy 'لا توجد تقييمات بعد' is ellipsized inside the 250pt identity column (measured with production Inter + the repo's deterministic Arabic subset: paragraph pinned to the full 226pt available, didExceedMaxLines true), while the English 'No reviews yet' fits at 178pt. It is the empty state — the one every unrated account, i.e. the seeded customer, lands on — that breaks first, in the locale half the users read.

## F26

CustomerProfileRating: On a 320pt phone (iPhone SE / small Android) the label loses its review count at 200% text. The 180pt column leaves 156pt after the 20dp star and its 4pt gap; '5.0 . 1284 Reviews' wants 224pt. Because Text ellipsizes the END, what survives is the score and what is cut is the number of ratings backing it — a trust signal with its denominator silently removed. The same string clears the 390pt column with ~2pt to spare, so this is invisible on a large test device.

## F27

CustomerProfileRating: The chip contradicts D59 and its own sibling. customer_profile_view_data.dart documents ratingCount as driving 'the cold-start copy, D59-consistent'; D59 is hide the aggregate until N>=5, and DeliveryManProfileHeader._RatingRow implements exactly that (isColdStart -> deliveryManProfileReviewsCount, no score). CustomerProfileRating shows the aggregate from the FIRST review, so one rating renders a confident '5.0' here and no score at all on the jeeber surface, out of the same two ARB keys.

## F28

CustomerProfileRating: _hasRating folds two independent payload fields through one `&&` (`rating != null && ratingCount > 0`), and the false branch is the cold-start copy. A payload with 42 ratings and no aggregated average renders 'No reviews yet' — a stronger claim than 'no score available', and one the account's own data contradicts. The mirror payload (rating 4.8, ratingCount 0) collapses identically, discarding a score the server did send. Neither case surfaces the field that WAS delivered.

## F29

CustomerProfileRating: No plural handling, and none reachable. The borrowed deliveryManProfileRatingSummary renders '5.0 . 1 Reviews' for a single review. AppLocalizations resolves keys by `_get(...).replaceFirst('{count}', '$count')` — literal substitution with no ICU plural support — so this cannot be fixed by writing a plural form into the ARB. Arabic has the same hole from the other side: '{rating} . {count} تقييم' is the singular for every count.

## F30

CustomerProfileRating: (rating ?? 0).toStringAsFixed(1) rounds UP: an account at 4.96 is presented as a perfect '5.0'. For a trust signal this is the one direction the rounding must not go.

## F31

CustomerProfileRating: The count is interpolated as a raw int ('$count'), so it renders '1284' with no grouping separator in English and with Western digits embedded in Arabic script in AR. No NumberFormat anywhere on the path.

## F32

CustomerProfileRating: The separator that ships is not the one specified. The widget's own doc comment and docs/build-out/50_ROUTE_REQUESTS.md both write this as '4.9 · 312', but the borrowed ARB value is '{rating} . {count}' — a full stop with a space either side. What ships reads '4.9 . 312 Reviews', which parses as a sentence break visually and is announced as one by a screen reader.

## F33

CustomerProfileRating: The star is frozen at Sizes.large (20dp) while the label doubles: Icon.applyTextScaling is left at its false default and nothing in AppTheme or OMDS sets it (measured: Size(20,20) at both 100% and 200%). It also keeps 24pt of the column at 200% that the label — which is truncating at that point — could have used.

## F34

CustomerProfileRating: A 0.0 account and a 4.9 account get the same solid, brand-primary Icons.star_rounded. The icon encodes 'has a score', the digits encode what the score is, and at a glance the icon reads louder — nothing but the number distinguishes the worst-rated account in the app from the best.

## F35

CustomerProfileRows: Register row overflows horizontally at 320 pt + 200% text: CustomerProfileRow gives the label an Expanded and CustomerRegisterPill is intrinsically sized and never yields, so the label is allotted ZERO width and the row overflows on the trailing edge. The user is left with a bare 'Register' button and no statement of what they are registering for. (lib/features/customer_profile/presentation/widgets/customer_profile_row.dart _RowContent + customer_register_pill.dart)

## F36

CustomerProfileRows: Same squeeze at normal phone width: at 390 pt / 200% the 'Register as a delivery' label shrinks 157 pt -> 45 pt while the pill grows 113 pt -> 225 pt. No overflow, so it fails silently — the row's meaning disappears while its chrome stays intact.

## F37

CustomerProfileRows: CustomerProfileRow's label is Text(overflow: TextOverflow.ellipsis) with NO maxLines, which truncates the paragraph at one line rather than wrapping. Every row label therefore clips instead of reflowing as width shrinks or text scale grows (same defect shape already documented on ClientLocationAddRow).

## F38

CustomerProfileRows: CustomerRegisterPill hardcodes height: Sizes.threeXLarge (40 pt) while its text scales with the user's setting: at 200% the 40 pt-tall CTA text fills the 40 pt button edge to edge with zero internal padding.

## F39

CustomerProfileRows: Dark-mode contrast failures, visible in every AR RTL dark rendering: CustomerProfileSectionHeader paints 'Account'/'Support' in colorScheme.secondaryContainer (#444559) on surface #131318 = 1.98:1, and CustomerProfileIconDisc paints an onSecondary glyph (#2d2f42) on a secondaryContainer disc (#444559) = 1.40:1. Both pairings are written for the light scheme (navy-on-white / white-on-navy, 17.13:1); AppTheme.dark() is ColorScheme.fromSeed, where both roles are dark. Row labels (10.87:1) and chevrons (5.87:1) are fine, so only the header text and the disc glyphs are affected.

## F40

KycStatusView: No scroll view: the status body is a bare Column + Spacer (kyc_status_view.dart:244, _StatusScaffold), so on a 390x700 phone body it OVERFLOWS at the DEFAULT text size — 'Resubmit requested · all slots' by 100 dp EN / 60 dp AR, and 'Pending · auto-check stopped' by 40 dp EN. What overflows is the CTA stack, so the resubmit CTA (the entire point of that state) and 'Back to profile' are clipped and unreachable. find.byType(Scrollable) finds nothing anywhere in the view.

## F41

KycStatusView: At 200% text EVERY branch overflows the same 390x700 body: approved 180 dp (the SHORTEST body), rejected 716 dp, pending 736 dp, pending-stopped 972 dp, resubmit 1252 dp. Pinned as a test: on the approved body at 200% the third post-approval CTA (kyc_status_topup_cta) lays out with its bottom past 700 dp — off the phone, with nothing to scroll it back.

## F42

KycStatusView: The isLoadingStatus branch renders `Center(child: OmdsLoadingState())` with message: null — zero Text widgets and no semantics label — inside the Semantics(identifier: 'kyc_status_root') container. A screen reader is told nothing at all while the app decides whether the jeeber is approved, and this frame is visually identical to the JEBV4-271 round-6 stuck-flag defect (spinner forever, _ApprovedBody never built), so 'loading' and 'wedged' cannot be told apart by the user or by an accessibility client.

## F43

KycStatusView: Two primary CTAs ship borrowed copy (the production file marks both L10N-REQ, and the previews make it visible in EN and AR): the approved screen's primary action reads 'Available requests' (jeeberFeedSectionTitle — a section heading, not an action) instead of 'Go to feed'; the rejected screen's primary reads 'View status' (profileKycViewCta) on the screen that IS the status, instead of 'View rejection details'.

## F44

KycStatusView: OmdsLoadingButton swaps its LABEL for the spinner, so 'Check again' disappears entirely while a status probe is in flight — the control becomes an unlabelled filled box with no accessible name. Because the automatic poller probes on a timer (38 times over 15 minutes), this happens repeatedly with no user action, not just on tap.

