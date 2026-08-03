# Wiring requests — W4 · Goods cost

Lane: `lib/features/goods_cost/**`. The screen ships **correct and complete without any of these** —
nothing below blocks it. Both entries are follow-ons that would let this lane delete code.

### kit
file: lib/core/widgets/jeeb/jeeb_money_field.dart
need: **WR-GOODS-1 — an optional stepper slot on `JeebMoneyField`, on top of 17's WR-1 promotion.**
Screen 17's `wiring/17-offer-composer.md` WR-1 already asks for
`lib/features/offers/presentation/widgets/jeeb_money_field.dart` to be promoted into the kit. Once it
is, this screen wants to consume it — but today it *cannot*, because `onStep` is a **required**
parameter and the `−1` / `+1` [`JeebStepperPill`] pair always renders. Goods cost has no ±1
affordance (the Jeeber types the receipt total; there is nothing to nudge), so mounting the widget
verbatim would add an affordance this flow does not have. This lane therefore ships a screen-local
`_AmountField` inside `goods_cost_screen.dart` that reproduces the board's `min-h 64 / r16 / 2px
navy / surfaceContainerHigh` box and nothing else.
exact change: after 17's WR-1 lands, relax two params on the promoted widget —
```dart
  final ValueChanged<int>? onStep;   // was: required ValueChanged<int> onStep
  // build(): render the JeebStepperPill pair only when `onStep != null`
```
No other signature changes; 17 passes `onStep` and is unaffected. This lane then deletes
`_AmountField` (~85 LOC) and calls
`JeebMoneyField(controller:…, currencyMark:…, onChanged:…, identifier: 'goods_cost_amount_field')`.
why: one money-field treatment instead of two. It also recovers the two design values `lib/features`
cannot express — the board's 26/w800 amount (the `fontSize:` ban snaps this lane to `jeebText.h1`
@w800 = 24) and a raw `TextField(` without the line-level gate-exemption comment.

### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart
need: **WR-GOODS-2 — one honest-cash string, `goodsCostCashNote`.** The design language's signature
voice on a money surface is the plain-spoken guarantee (`_ds/readme.md` CONTENT FUNDAMENTALS:
*"We only take a cut of the delivery fee. Never your goods."*), and `JeebInfoNote` is the shape it
lives in. This lane deliberately did **not** invent the string: it re-housed the screen's existing
`goodsCostBody` into the note instead, so no new copy and no feature-local l10n shim ships. Grant
this and the note carries the guarantee instead of the instruction.
exact change (EN / AR):
```json
  "goodsCostCashNote": "The Client pays this in cash. Jeeb takes a cut of the delivery fee only — never of your goods.",
  "@goodsCostCashNote": {"description": "Honest cash-on-delivery note on the Jeeber goods-cost screen: the platform never touches the goods cost."},
```
```json
  "goodsCostCashNote": "يدفع العميل هذا المبلغ نقداً. جيب تأخذ نسبة من رسوم التوصيل فقط — ولا تأخذ شيئاً من ثمن البضاعة.",
```
and the getter `String get goodsCostCashNote => _get('goodsCostCashNote');` beside the existing
`goodsCost*` getters in `app_localizations.dart` (~line 2483).
call-site change once granted (one line, in `goods_cost_screen.dart`):
```dart
  JeebInfoNote.muted(
    icon: Icons.payments,
-   text: l10n.goodsCostBody,
+   text: l10n.goodsCostCashNote,
    identifier: 'goods_cost_cash_note',
  ),
```
…and `goodsCostBody` returns to a body line under the h1 headline.
why: this is the one screen where the guarantee is load-bearing — it is the moment a Jeeber declares
money they fronted. Reviewer note: the copy states a **fee-only** model (D41/D44 wording — "cut of
the delivery fee", never "commission") and must be owner-confirmed before it ships, which is exactly
why this lane refused to hardcode it.
