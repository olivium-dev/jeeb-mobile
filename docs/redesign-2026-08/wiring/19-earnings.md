# Wiring requests — 19 · Earnings

Lane: `lib/features/earnings/**`. Everything below is a shared file this lane must not edit.
The screen is written **as if §A is granted** — see the status note.

**§A is BLOCKING.** `earnings_dashboard_screen.dart` (the `_DeliveryRow` cash amount) calls
`MoneyFormat.format(…, signed: true)` today, which does not compile until §A lands. That is the
one and only analyze error in this lane; everything else is clean. If §A is refused, the fix is
to delete that single named argument — the `+` is decorative and the screen is otherwise final.

§B is a non-blocking follow-up: the strings already ship from the lane-owned
`earnings_dashboard_l10n.dart` resolver, so nothing is waiting on it.

No route, DI, theme or kit change is needed. The wallet-balance plumbing that the original
proposal wanted from `earnings_tab.dart` is resolved inside the lane instead (an optional
`WalletRepository?` on `EarningsCubit`, defaulted through `sl.isRegistered<WalletRepository>()`),
so `lib/features/shell/*`, `injection_container.dart` and `app_router.dart` stay untouched.

### cross-feature
file: lib/core/formatting/money_format.dart
need: an opt-in `+` sign rendered inside the existing LTR isolate, for 19's per-delivery cash-in rows (`+$8.00`, html:49).
exact change:
```dart
  /// Formats [amount] in [currency] — `$12.00` for USD, `LBP 15,000.00`
  /// otherwise, wrapped in an LTR isolate so it renders correctly in ar/RTL.
  ///
  /// [signed] prefixes a `+` for positive amounts, INSIDE the isolate — a
  /// cash-in row on the earnings breakdown (screen 19). Defaults to false, so
  /// every existing call site is byte-identical.
  static String format(
    double amount, {
    String currency = 'USD',
    bool signed = false,
  }) {
    final value = _group(amount.toStringAsFixed(2));
    final code = currency.trim().toUpperCase();
    final sign = signed && amount > 0 ? '+' : '';
    final token =
        (code.isEmpty || code == 'USD') ? '$sign\$$value' : '$sign$code $value';
    return '$_lri$token$_pdi';
  }
```
why: `U+002B` is bidi-class ES; concatenated outside the isolate it resolves with the paragraph direction and renders `$8.00+` in Arabic. `_group` already emits its own leading `-` for negatives, so `signed` deliberately only adds the positive sign. Default `false` keeps every existing call site byte-identical. If refused, screen 19 drops the `+` (decorative) — it will not hand-roll a local isolate in `lib/features`.

### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart
need: dedicated keys for the earnings fee-only copy currently served by `earnings_dashboard_l10n.dart` `_pick` pairs (that file's own protocol: fold in and delete when the keys land). Non-blocking — the resolver already ships these strings in both locales.
exact change (EN; the AR values are already in `earnings_dashboard_l10n.dart`, ready to copy):
```json
  "earningsTotalCashHint": "Paid to you directly — never through Jeeb.",
  "earningsNetPerOfferLabel": "Avg kept / offer",
  "earningsFeesPaidHint": "{percent}% per won offer, from your wallet",
  "earningsWalletLink": "Wallet",
  "earningsActivityLink": "See all",
  "earningsDeliveryRowTitleDated": "Delivery {id} · {weekday}"
```
AR:
```json
  "earningsTotalCashHint": "يُدفع لك مباشرة — لا يمر عبر جيب أبدًا.",
  "earningsNetPerOfferLabel": "متوسط المحتفظ به / عرض",
  "earningsFeesPaidHint": "{percent}٪ لكل عرض فائز، من محفظتك",
  "earningsWalletLink": "المحفظة",
  "earningsActivityLink": "عرض الكل",
  "earningsDeliveryRowTitleDated": "توصيلة {id} · {weekday}"
```
`{percent}` must be fed `kJeebCommissionPercent` (`lib/core/jeeb_commission.dart`) at the call site — plan row 481 pins "10% only via the constant", never a typed literal.
Retired by this lane (no consumers left, safe to skip entirely): the wallet/activity subtitle strings `walletLinkSubtitle` / `activityLinkSubtitle`.
why: keeps the ARB parity gate untouched now, while recording the eventual migration so no translation is orphaned.
