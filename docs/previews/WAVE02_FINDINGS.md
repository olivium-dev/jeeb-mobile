# Wave 02 (chat, cont.) — defects surfaced by the previews

Eight widgets previewed. As in wave 01 these are problems in the WIDGETS,
found because the matrix renders AR-RTL-dark and 200% text. Recorded, not fixed.

## F01

ConfirmDeliveryActionSheet: Dark-mode contrast failure in the widget's own colour choices (font-independent, measured from AppTheme.dark()): the title paints colorScheme.secondaryContainer (#444559) on surface (#131318) = 1.98:1 where WCAG AA needs 3:1 for large text, and the Confirm CTA paints onPrimary (#252b61) on a secondaryContainer fill = 1.40:1. Role misuse, not a palette bug — a container colour used as on-surface ink, and a label paired with the wrong container; onSecondaryContainer (#e0e0f9) on that fill would be 7.23:1. Light mode is fine (17.13:1).

## F02

ConfirmDeliveryActionSheet: The in-flight spinner is effectively invisible in dark mode: OmdsLoadingButton tints OmdsButtonLoading with the CTA's textColor (onPrimary #252b61) over the fill dimmed to 60% alpha, which is 1.03:1 against AppTheme.dark(). The 'Confirming · spinner' preview's AR RTL dark rendering shows a button that looks merely dead rather than busy.

## F03

ConfirmDeliveryActionSheet: No scroll fallback at the accessibility ceiling. _SheetContent is a plain Column inside a route opened with isScrollControlled: true and no useSafeArea, so nothing can scroll or be clipped safely. Measured with the production Inter face: at 200% text the content is 553 pt against the 568 pt height of the 320-wide phone that width belongs to — 15 pt of scrim left, sheet top at y=14.6 (under the status bar), and any additional bottom inset (gesture bar, keyboard) tips it into a hard RenderFlex overflow.

## F04

ChatComposerIconButton: Tap target is 44x44 dp, below Material's 48dp `kMinInteractiveDimension` (measured with `tester.getSize`, not inferred). The size is `Spacing.small`*2 + `Sizes.large` = 12+20+12. The class doc says it deliberately avoids `IconButton` because OMDS has no icon-only primitive — what that swap silently gave up is `IconButton`'s built-in 48dp minimum target. Both live call sites (attach at chat_composer.dart:241, send at :302) inherit the shortfall, and send is the highest-traffic tap in the app. Fix would be a `ConstrainedBox`/`SizedBox` of 48 around the `Material`, in lib/features/chat/presentation/widgets/chat_composer_icon_button.dart.

## F05

ChatComposerIconButton: The button does not respond to text scaling at all: at `textScaleFactor: 2.0` it still measures exactly 44x44 (verified). `Icon` is given an explicit `size: Sizes.large` and `applyTextScaling` is never enabled, and the padding is a fixed token — so in the 200%-text rendering the surrounding composer text doubles while the tap target stays put. The users who set 200% text are the same users who need a larger target, so the gap is worst exactly where it matters most.

## F06

ChatComposerIconButton: Disabled state is carried by opacity alone — `filled` disabled is `primary` at 50% alpha, borderless disabled is `onSurfaceVariant` at 50%. There is no shape, fill, or glyph change. The `filled: false` + `onPressed: null` combination (previewed as 'Attach · disabled') is the weakest: a 50%-alpha glyph with no pill behind it to anchor it, and it is unreachable in production today, so the first caller to pass a null handler without `filled: true` will be the one to discover it. `Semantics(enabled: false)` is correctly set, so screen readers are fine; this is a sighted-low-vision gap only.

## F07

AutoDirectionText: Neutral-only strings are handed to the UI language and come out group-reversed in Arabic. `_detectDirection` returns null for a string with no strong-directional character, so the widget adopts `Directionality.of(context)` — the app language, not the content. Measured with a TextPainter at 390pt on '+961 3 000 077': under LTR the '+961' group lays out at x=0 and '077' at x=176; under RTL '+961' lays out at x=160 and '077' at x=0. Per UAX #9 each digit group is its own LTR run inside an RTL paragraph, so the runs are ordered right-to-left and the number displays with its groups in reverse order. A phone number, price, or order code sent as a whole chat message therefore reads back wrong for every Arabic-UI user. Covered by the 'Digits only, no strong character' preview; lib/features/chat/presentation/widgets/auto_direction_text.dart:34 and :51-57.

## F08

AutoDirectionText: `_isStrongLtr` recognises only Latin, Greek and Cyrillic, so every other strong-LTR script falls into the same null/neutral branch and flips direction with the app language. Amharic (Ethiopic, U+1200-U+137F) is strong LTR in Unicode but matches neither `_isStrongLtr` nor `_isStrongRtl`; verified in the test — 'ሰላም በመንገድ ላይ ነኝ' resolves ltr in the en canvas and rtl in the ar canvas. Bengali, Sinhala and Devanagari are outside the ranges too, which matters because Lebanon's domestic-worker population makes those plausible chat traffic. The class comment justifies the neutral default as keeping 'digits and punctuation' from pinning direction, so unlisted alphabets landing in that bucket looks like a side effect of the range list rather than the stated intent. lib/features/chat/presentation/widgets/auto_direction_text.dart:78-88.

## F09

OfferAcceptedBanner: `jeeberName` is a REQUIRED constructor parameter that the widget never renders. `build()` reads `onDismiss`/`onStartActiveDelivery`/`onTrackOrder` and the ARB, never `jeeberName`; the copy is generic ("You are now chatting with your Jeeber."). `ChatScreen._extractWinnerName` walks the message list backwards specifically to supply it (chat_screen.dart:501/713) and the value is dropped on the floor. A caller can pass the wrong name — or any string — with zero visible effect, and every existing test passes 'Kamal Hajj' without ever asserting it appears. lib/features/chat/presentation/widgets/offer_accepted_banner.dart:65

## F10

OfferAcceptedBanner: At 320 dp with 200% text the client's "Track my order" CTA label ellipsises. The banner's `EdgeInsetsDirectional.fromSTEB(16, …, 4, …)` plus the 48 dp dismiss target leave each `Wrap` child at most 320 − 16 − 4 − 48 = 252 dp, and the label needs 262 dp at 200% (measured with the real Inter; 159 dp at 1x). The Jeeber's shorter "Start delivery" needs 239 dp and survives, so the ONLY label that truncates is the customer's only in-chat route into live tracking — it reads "Track my …" on a small phone at the accessibility ceiling. No overflow is thrown, so nothing currently catches it.

## F11

OfferAcceptedBanner: The supporting sentence hits its `maxLines: 2` clamp and truncates at 320 dp × 200% text in the CTA-less state — the one state whose whole justification is that there is room to paint it (measured: a 224 dp column, `didExceedMaxLines` true at 2.0x, false at 1.3x). It stays intact on the row's accessible name, so screen-reader users are unaffected and only sighted large-text users lose it; that asymmetry is also why the existing a11y assertion (`chat_header_a11y_test.dart:283`) passes.

## F12

OfferAcceptedBanner: The Arabic title truncates where the English one does not. "تم قبول العرض!" exceeds `maxLines: 1` at 320 dp × 200% (measured 224 dp of available width with the repo's deterministic Noto Arabic face), while "Offer accepted!" still fits at the same width and scale. At that point the AR banner has ellipsised its title and dropped its sentence, so the whole strip is a truncated phrase plus a CTA — a failure invisible to any EN-only review.

## F13

OfferAcceptedBanner: Neither icon responds to `textScaler`. The leading `check_circle_outline` and the dismiss `close` are both pinned to `Sizes.large` (a 20 dp glyph box, measured identical at 1.0x and 2.0x) while the title's line height goes 20 dp → 40 dp at 200%. The success check-mark — the fastest-read part of a success banner — ends up half the height of the type beside it. Same species as WAVE01 F04 on ChatConnectionBanner, so it reads as a pattern rather than a one-off.

## F14

DeliveryConfirmIllustration: Dark-mode contrast failure. The painter inks with `colorScheme.secondaryContainer` on the sheet's `colorScheme.surface`. Light measures 17.13:1 (brand navy #0B1351 on white); dark is `ColorScheme.fromSeed(_jeebNavy, Brightness.dark)`, which puts that role at a dark tone on an equally dark surface and measures 1.98:1 — below the 3:1 WCAG 1.4.11 asks of a graphical object. The AR RTL dark rendering of every preview shows the line art nearly dissolved into the sheet. Measured in the test via AppTheme.light()/AppTheme.dark(); the light figure is now guarded at >= 3.0, the dark one is deliberately left unpinned so fixing the palette is not a test failure.

## F15

DeliveryConfirmIllustration: Unclipped out-of-bounds painting when the host box is tight on both axes at any ratio other than 271:150. `RenderAspectRatio` short-circuits on tight constraints and returns `constraints.smallest`, so `AspectRatio` stops defending the ratio; `_ParcelClockPinPainter.paint` still derives `scale` from `size.width` alone and then vertically centres with a negative translate. At a tight 300x60 box it draws 166.05pt of art and paints ~53pt above and ~53pt below the widget bounds, over whatever the parent put there — `CustomPaint` does not clip, so there is no overflow stripe and no exception. Not reachable from the shipping call site (the sheet's `FractionallySizedBox` leaves height unbounded), but nothing in the widget prevents the next caller from hitting it. A `ClipRect`, or scaling by `min(width/271, height/150)`, would close it.

## F16

DeliveryConfirmIllustration: No RTL mirroring. The painter takes only a stroke colour and never reads `Directionality`; clock-left / parcel-centre / pin-right is baked into absolute canvas coordinates. The AR rendering is therefore pixel-identical to the EN one while the sheet's padding, text and CTA around it all mirror. Whether a directional illustration should mirror is a design call, but today it is not a choice the widget can express.

## F17

DeliveryConfirmIllustration: Latent crash if both axes are unbounded (e.g. dropped into a horizontally scrolling `ListView` or an unbounded `Row` without a height). `RenderAspectRatio` falls back to `constraints.maxHeight` when width is infinite, so an infinite height yields an infinite size and the `size.isFinite` assertion fires. The `Height-driven in a row` preview pins the one-sided version of this branch (unbounded width, tight height -> 180.67x100) so the boundary is documented.

## F18

OfferCardBubble: FOOTER ROW OVERFLOWS ON EVERY PHONE WIDTH. The Accept + Decline footer is a Row(mainAxisSize: min) of two intrinsically-sized OmdsPrimaryButtons and is simply wider than the card. Measured at lib/features/chat/presentation/widgets/offer_card_bubble.dart:86 (_OfferActions): at 390pt EN light the Accept pill is 201.2px and Decline 133.7px and the row overflows by 97px; at 360pt (narrow-phone floor) by 127px; AR RTL dark by 11px; EN 200% text by 363px. Even Accept ALONE (the declined-offer presentation) overflows by 119px at 200% text. Invisible to test/features/chat/offer_card_bubble_widget_test.dart only because widget tests pump into an 800x600 viewport where the same row has ~450px to spare.

## F19

OfferCardBubble: acceptDisabled HAS NO VISUAL OR SEMANTIC EFFECT. _AcceptButton (offer_card_bubble.dart:118-137) implements 'disabled' as an early `return` inside onTap and never passes `isEnabled: false` to OmdsPrimaryButton, which ships a disabled treatment (0.45-alpha fill, dimmed label) it therefore never uses. The 'Accept locked (rival winning)' preview is pixel-identical to 'Live offer', and the Semantics(button: true) node carries no disabled flag — so while a rival accept is in flight the client taps a full-strength navy CTA and nothing happens, with no feedback to sighted or screen-reader users.

## F20

OfferCardBubble: THE OFFER PRICE IS NEVER DRAWN. payload.fee and payload.currency are rendered by no Text in the widget — _OfferNote (offer_card_bubble.dart:273-292) shows the free-text note, or falls back to the ETA line when the note is empty. So an offer whose jeeber did not type the price into the note shows the client no price at all, while the Accept button's a11y label still announces it: a sighted user gets strictly less information than a blind one. Exposed by the 'No note, no rating' preview and pinned in the test.

## F21

OfferCardBubble: THE A11Y FEE STRING IS AN UNFORMATTED RAW DOUBLE. offer_card_bubble.dart:124-126 interpolates '${payload.fee} ${payload.currency}', so the merged Accept label reads 'Accept Offer: Kamal Hajj, 35.0 USD, ETA 20 min' — TalkBack says 'thirty-five point zero USD'. No NumberFormat/currency localization, and it stays Western digits + the literal 'USD' in the Arabic rendering while every other number on the card is locale-formatted (the clock goes through DateFormat.Hm).

## F22

OfferCardBubble: ISACCEPTING IS A LABEL SWAP AND NOTHING ELSE. The only in-flight affordance is the text changing to 'Accepting…'; there is no spinner and the pill keeps its full saturation. In EN at 200% text the new label is NARROWER than the old one (313px vs 369.2px), so the footer visibly twitches inward mid-accept, and on a slow accept saga the card reads as idle rather than busy.

## F23

BroadcastTtlIndicator: Arabic label has no plural forms. `chatBroadcastTtlLabel` is a flat template resolved with `_get(...).replaceFirst('{seconds}', ...)`, so the AR RTL rendering reads 'نافذة العروض تُغلق خلال 1 ثانية' / '… 2 ثانية' / '… 5 ثانية' — the singular ثانية at every count, where correct Arabic needs ثانية واحدة (1), ثانيتان (2), ثوانٍ (3–10). This key is an outlier in the codebase: comparable counters ship all six CLDR forms (`pendingCardCreatedMinutes*`, `dashboardNearbyRequests*`, `pendingCardOffersBadge*`) with matching branch logic in AppLocalizations. Visible in the AR renderings of 'One second left' and 'Final seconds'.

## F24

BroadcastTtlIndicator: The icon does not scale with text. `Icons.timer_outlined` is pinned to `Sizes.medium` (16 logical px); measured at both a 1.0 and a 2.0 text scale it stays 16.0 px wide while the label's line height doubles (16 → 32 px). At the 200%-text rendering the glyph is half the cap height of the text beside it. The icon is decorative — the text carries the meaning — so this is polish, not a blocker.

## F25

BroadcastTtlIndicator: The countdown is raw seconds with no upper bound and no mm:ss formatting. `_secondsLeft` is clamped only at the bottom (`remaining < 0 ? 0 : remaining`), and `expiresAt` is a SERVER-derived instant (first offer card's `sentAt` + 5 min) compared against the DEVICE clock via `DateTime.now()`. A handset whose clock runs behind the server therefore renders a countdown far longer than the five-minute window it describes, as a four-digit second count ('Offer window closes in 3900s') — the state the 'Clock-skewed long count' preview pins. Even the correct-clock case opens at 'closes in 300s' rather than '5:00'.

## F26

BroadcastTtlIndicator: The ticker never stops when the band is hidden. `Timer.periodic` is cancelled only in `dispose`, and `_update()` calls `setState` unconditionally — including the early-return branch where `expiresAt == null`. The 'No window' and 'Expired window' previews are therefore a zero-height `SizedBox.shrink` that rebuilds once a second for as long as the chat screen lives, which in production is the whole post-accept phase. Minor (a rebuild of an empty box is cheap) but it is real, continuous, and invisible without a preview.

## F27

ChatFeeBanner: DARK-MODE CONTRAST FAILURE (ships to users): the band paints colorScheme.secondaryContainer with colorScheme.onPrimary copy. In AppTheme.dark() that is #444559 on #252B61 — a measured contrast ratio of 1.40:1, against the 4.5:1 the widget's own class doc claims is 'an M3-guaranteed >=4.5:1 pair'. It is not an M3-guaranteed pair; the guaranteed partner is onSecondaryContainer (measured 7.23:1 dark / 4.55:1 light). Light mode is fine (17.13:1) only because onPrimary happens to be white there. This is not preview-only: jeeb_bootstrap.dart:191 and app.dart:622 both set themeMode: ThemeMode.system, so a Jeeber on a dark-mode phone sees the fee notice at 1.40:1. The AR RTL dark rendering of the matrix is what surfaced it.

## F28

ChatFeeBanner: The 'Order picked' pill starves the notice and overflows the Row. _BannerOrderPicked mounts an OmdsPrimaryButton (AnimatedContainer with width: null) as a NON-FLEX child of the banner's Row, so RenderFlex lays it out with an unbounded main axis and it claims its full intrinsic width BEFORE the Expanded notice is given the remainder. Measured at 390 dp: pill 201.2 dp / notice 128.8 dp / band 132 dp at 1.0 text scale; at 200% the pill is 369.2 dp of a 390 dp band, the notice is allocated 0.0 dp, the text wraps one character per line (1440 dp tall) and the framework reports 'A RenderFlex overflowed by 39 pixels on the right.' The dismiss and none variants never do this (92 -> 192/232 dp, clean reflow). Fix would be a Flexible/ConstrainedBox cap on the pill, or wrapping to a Column above a threshold — not applied, production code was off limits.

## F29

ChatFeeBanner: The same defect is WORSE in Arabic and at the narrowest shipped width. The AR label 'تم استلام الطلب' makes the pill wider than the English one — 242.0 dp at 1.0 and 452.0 dp at 200% (vs 201.2 / 369.2 EN) — so AR hits the starvation earlier at every width. At 320 dp (the narrowest width the app ships to) the pill does not shrink at all: it stays 201.2 dp, squeezing the notice to 58.8 dp and taking the band from 92 dp to 232 dp at an ordinary 1.0 text scale, i.e. 2.5x taller than the copy needs before the keyboard is even up. Since the banner is the first chrome child of the bounded header slot, that height comes straight out of the message list's budget.

## F30

ChatFeeBanner: The dismiss (×) hit target is 32 x 20 dp, not the '>=48dp hit target' its own doc comment on _BannerDismiss claims. Measured: Icon(size: Sizes.large) renders 20 x 20 dp and the whole InkResponse measures 32 x 20 dp. InkResponse's `radius: Sizes.fourXLarge` sets the SPLASH radius, not the hit area, and InkResponse (unlike IconButton) gets no MaterialTapTargetSize padding. Below both the Material 48 x 48 minimum and WCAG 2.5.8.

## F31

ChatFeeBanner: The amount bypasses the app's single money formatter. MoneyFormat (lib/core/formatting/money_format.dart) is documented as the one rule for every customer/jeeber-facing amount — always two decimals, and always wrapped in a U+2066…U+2069 LTR isolate so a Latin money token cannot be bidi-reordered inside an Arabic paragraph (JEBV4-98 / F10). The fee banner takes a raw pre-formatted gateway string instead, and the only call site in the tree (dev_chat_preview_screen.dart:94, `static const String _feeAmount = r'$0.5'`) is neither two-decimal nor isolated — so the amount that reaches the Arabic sentence in production carries no isolate. The 'Long LBP amount' preview passes a real MoneyFormat token for contrast.

