# Wiring requests — 17 · Offer composer

Lane: `lib/features/offers/**`. Everything below is a shared file this lane must not edit.
The screen is written **as if these are granted**; it ships correct without WR-6.

Status note (2026-08-03): WR-2 (`JeebCtaButton.isLoading`), WR-3 (`JeebTopBar.close` with
`subtitle`/`subtitleIdentifier`/`identifier`/`leadingTooltip`/`onLeadingPressed`) and WR-4
(`JeebInfoNote` `linkLabel`/`onLink`/`linkIdentifier` + `JeebMoneyBreakdown` per-row identifiers)
**shipped with Wave 1** — verified in `03-WAVE1-KIT.md` §2 and consumed as-is. No action needed.
Only WR-1, WR-5 and WR-6 remain open.

### kit
file: lib/core/widgets/jeeb/jeeb_money_field.dart
need: WR-1 — promote the screen-local `JeebMoneyField` into the kit. Wave 1 §5 deliberately left it "screen-17-local by assignment", so it currently lives at `lib/features/offers/presentation/widgets/jeeb_money_field.dart`. Two things it cannot do from inside `lib/features`: the board's exact `$` 24/w800 + amount 26/w800 type (the `fontSize:` literal ban applies to `lib/features`, so the shipped file snaps to `jeebText.price` 21/w800 and `jeebText.h1`@w800 24/w800), and a raw `TextField` without a line-level gate exemption.
exact change: `git mv lib/features/offers/presentation/widgets/jeeb_money_field.dart lib/core/widgets/jeeb/jeeb_money_field.dart`; fix the three relative imports (`../../../core/theme/…` → `../../theme/…`, `jeeb_stepper_pill.dart` stays a sibling); update the single import in `offer_submission_screen.dart` to `package:jeeb_mobile/core/widgets/jeeb/jeeb_money_field.dart`; then restore the design-exact type inside the widget (kit is exempt per plan §4.4):
```dart
static const double markFontSize = 24;    // tpl 996
static const double amountFontSize = 26;  // tpl 997
// _markStyle:   context.jeebText.price.copyWith(fontSize: markFontSize)
// _amountStyle: context.jeebText.h1.copyWith(fontSize: amountFontSize, fontWeight: FontWeight.w800)
```
and drop the `// EXEMPT(flutter-omds-design-system-usage)` comment on the raw `TextField(` line (the gate only scans `lib/features`).
why: `tool/check_design_tokens.sh` bans `fontSize:` literals and raw `TextField(` in `lib/features`; the money field is 2px under the board on the amount and 3px under on the `$` mark until it moves. Behaviour, identifiers and RTL handling are already final — this is a move, not a rewrite.

### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart
need: WR-5 — the offer-composer redesign keys. The screen ships meanwhile on the `OfferComposerL10n` feature-local resolver per its own documented JM-008/JM-031 interim pattern; the swap is call-site-free.
exact change (EN; the AR values are already in `offer_composer_l10n.dart`, ready to copy):
```json
  "offerComposerTitle": "Your offer",
  "offerComposerPriceSectionLabel": "Your price",
  "offerComposerPricePlaceholder": "0.00",
  "offerComposerEtaSectionLabel": "Pickup ETA",
  "offerComposerEtaCeilingHint": "· ≤ {minutes} min",
  "offerComposerEtaOther": "Other",
  "offerComposerOfferRowLabel": "Your offer",
  "offerComposerFeeRowLabel": "Platform fee ({percent}%)",
  "offerComposerKeepRowLabel": "You keep",
  "offerComposerWalletStrip": "Wallet: {amount} available",
  "offerComposerSendKeep": "Send offer — keep {amount}",
  "offerComposerNoteHint": "Add a note — \"I'm 5 mins from the pharmacy\" (optional)",
  "offerComposerPriceDecrement": "Decrease offer by 1",
  "offerComposerPriceIncrement": "Increase offer by 1"
```
(+ `@`-descriptions and the 4-edit recipe per §7.4. `{percent}` MUST be interpolated from
`kJeebCommissionPercent` at the call site — never a literal `10`.)
NOTE for owner visibility: `offerComposerKeepRowLabel` changes `offer_composer_net_line` semantics
from "You earn (cash): <full price>" to "You keep: <price − platform fee>". Adopted per the board
(`17-offer-composer.html` tpl 1018), the designer note, and earnings-model consistency
(`netPerOffer`, `earnings_summary.dart:170`). The board's `You keep (cash)` drops the `(cash)`
qualifier — under this reading it is literally wrong (cash in hand is the full $8.00); the reserve
footnote carries the wallet-vs-cash mechanics. **Flagged, not silent** — one-line revert.
why: guardrail 5 — every user-visible string through l10n; the feature-local map is the sanctioned
interim and these keys are the permanent home.

### route
file: lib/core/router/app_router.dart (+ jeeber_request_detail_screen.dart:58-63, jeeber_feed_tab_view.dart:159-171 — other lanes)
need: WR-6 (OPTIONAL — the screen is correct and shippable without it): pass the `DeliveryRequest` as `extra` on `pushNamed('jeeber-offer-submission')` and read it in the route builder.
exact change: builder reads `final request = state.extra as DeliveryRequest?;` and hands the composer an optional `DeliveryRequest? request` ctor param (additive, defaulted null); both call sites add `extra: request`.
why: lights up the header's `· Pharmacy run · ⚡ Flash` (itemsSummary + tier) and the real per-tier ETA band — which collapses the ETA row from 3 pills + `Other` to exactly the board's 3 pills and makes the section hint read the tier's own ceiling. The degraded path (ORD-ref only, fallback band) must exist regardless: deep-link/push entry never carries `extra`. Only `flash` maps to a marketing tier name; the other enum values must not be relabelled.
