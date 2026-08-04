# l10n queue — M3-05 order summary (`/orders/:id/summary`)

Three keys. Everything else the restyle needed already exists in both catalogs
(verified against `lib/l10n/app_en.arb` / `app_ar.arb` on 2026-08-04).

## Why anything is queued at all

M3-05 splits the screen's single `failed` picture into the two rungs of the
§2.7 family: a **404 is an absence** (empty rung, E4's parcel, no Retry) and a
transport failure is a **fault** (error rung, danger-tinted centre, Retry). The
error rung is fully covered by keys that already exist. The empty rung is not:
nothing in either catalog says "this order is not here" as a *headline*.

## 1. `orderSummaryNotFoundTitle`

Currently on the nearest existing key, `receiptErrorNotFound`
("We couldn't find this delivery."), tagged `TODO(midnight): l10n-queued` at
`lib/features/order_summary/presentation/order_summary_l10n.dart`
(`String get notFoundTitle`).

That key is JM-033 **receipt** copy: it is a full sentence written as *error
banner* text, and it is rendered on a screen this lane does not own. Reading it
is safe; rewriting it is not. A headline in the empty family is a short noun
phrase (`orderHistoryEmptyTitle` = "No orders yet", E4's own headline), so the
scoped key should read like one.

```
file: lib/l10n/app_en.arb
  "orderSummaryNotFoundTitle": "This order isn't here",
  "@orderSummaryNotFoundTitle": {"description": "M3-05 empty-rung headline when /orders/:id/summary 404s — the order was cancelled, cleared, or the deep link carried an id this account cannot see. Do NOT reuse receiptErrorNotFound: that is JM-033 receipt error-banner copy on another screen."},

file: lib/l10n/app_ar.arb
  "orderSummaryNotFoundTitle": "هذا الطلب غير موجود",

file: lib/l10n/app_localizations.dart
  String get orderSummaryNotFoundTitle => _get('orderSummaryNotFoundTitle');
```

## 2. `orderSummaryNotFoundBody`

**Currently UNMOUNTED**, not faked. `JeebEmptyState.body` is optional and the
empty rung ships with `body: null` rather than borrowing a line whose meaning is
wrong (`orderHistoryEmptyActive` promises deliveries will appear; they will not).
E2's precedent — an affordance with no honest content stays unmounted — applies
to copy as well as to CTAs.

```
file: lib/l10n/app_en.arb
  "orderSummaryNotFoundBody": "It may have been cancelled, or the link is out of date.",
  "@orderSummaryNotFoundBody": {"description": "M3-05 empty-rung body under orderSummaryNotFoundTitle. Names the two real causes of a 404 on this route; deliberately does NOT offer a retry, because refetching a deleted delivery cannot succeed."},

file: lib/l10n/app_ar.arb
  "orderSummaryNotFoundBody": "قد يكون قد أُلغي، أو أن الرابط لم يعد صالحاً.",

file: lib/l10n/app_localizations.dart
  String get orderSummaryNotFoundBody => _get('orderSummaryNotFoundBody');
```

After both land: point `notFoundTitle` at key 1, drop its TODO, add a
`notFoundBody` getter for key 2 and pass it to the `_notFound` block in
`order_summary_screen.dart`. `order_summary_screen_test.dart` asserts the
identifier and the rung, not the string, so nothing there re-points.

## 3. `orderSummaryErrorTitle`

Currently on `requestSummaryErrorGeneric` ("Something went wrong. Please try
again.") via `OrderSummaryL10n.errorGeneric`, tagged
`TODO(midnight): l10n-queued`. This is the copy the screen already shipped, so
nothing regressed — but it is a **two-sentence error-banner blob standing in a
headline slot**, and over the network body it says "try again" twice:

> **Something went wrong. Please try again.**
> You appear to be offline. Check your connection and try again.

`orderHistoryErrorTitle` ("Couldn't load orders") is the nearest existing
headline and is **not** used: it is plural, and this route shows exactly one
order. A wrong noun reads worse than a redundant clause.

```
file: lib/l10n/app_en.arb
  "orderSummaryErrorTitle": "Couldn't load this order",
  "@orderSummaryErrorTitle": {"description": "M3-05 error-rung headline on /orders/:id/summary (network or server failure; a 404 takes the empty rung instead). Singular on purpose — orderHistoryErrorTitle is the plural list-screen twin."},

file: lib/l10n/app_ar.arb
  "orderSummaryErrorTitle": "تعذّر تحميل هذا الطلب",

file: lib/l10n/app_localizations.dart
  String get orderSummaryErrorTitle => _get('orderSummaryErrorTitle');
```

After it lands: point `errorGeneric`'s call site in `_failure` at a new
`errorTitle` getter and drop the TODO. `errorGeneric` itself stays — nothing
else reads it, so it can be deleted in the same pass if the sweep prefers.

## Deliberately NOT queued

- **The error-rung body.** `orderHistoryErrorNetwork` / `orderHistoryErrorServer`
  are read as-is. They are generic transport copy, they carry no order-history
  noun, and `OrderSummaryL10n` already reads across features this way
  (`trackingEtaLabel`, `requestSummaryErrorGeneric`). A scoped duplicate would
  add two keys with identical strings.
- **The Retry label.** Stays `trackingGpsLostRetry` ("Refresh now") — the copy
  that shipped on this screen before the restyle. Changing it is a product call,
  not a Midnight one.
- **`priceLabel` / `cashLabel` / `itemLabel` / `etaPending`.** Still hard-coded
  EN/AR pairs inside `OrderSummaryL10n._pick`. Pre-existing, untouched by M3-05,
  and worth a sweep of its own — flagged, not fixed here.
