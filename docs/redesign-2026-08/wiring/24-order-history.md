# Wiring requests — 24 · Order history

One batch only. No route, no DI, no theme, no kit, no cross-feature change is needed by this lane.

### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart
need: five new strings for the order-history redesign (date-range chip label ×3, two row CTAs).
exact change:
app_en.arb —
```json
  "orderHistoryFilterRange": "{from} – {to}",
  "@orderHistoryFilterRange": { "description": "Order-history date chip when both ends are set (order_history_filter_chip). {from}/{to} are DateFormat.MMMd outputs, e.g. 'Jun 1 – 30'.", "placeholders": { "from": { "type": "String", "example": "Jun 1" }, "to": { "type": "String", "example": "Jun 30" } } },
  "orderHistoryFilterRangeFrom": "From {from}",
  "@orderHistoryFilterRangeFrom": { "description": "Order-history date chip, open-ended start.", "placeholders": { "from": { "type": "String", "example": "Jun 1" } } },
  "orderHistoryFilterRangeTo": "Until {to}",
  "@orderHistoryFilterRangeTo": { "description": "Order-history date chip, open-ended end.", "placeholders": { "to": { "type": "String", "example": "Jun 30" } } },
  "orderHistoryTrackCta": "Track",
  "@orderHistoryTrackCta": { "description": "Navy pill on the live order-history row (order_history_track_cta_<id>). Routes to the role-aware delivery detail." },
  "orderHistoryReorderCta": "Jeeb it again",
  "@orderHistoryReorderCta": { "description": "Outlined pill on completed/cancelled order-history rows (order_history_reorder_cta_<id>). Enters the create flow (request-type), unseeded." },
```
app_ar.arb —
```json
  "orderHistoryFilterRange": "{from} – {to}",
  "orderHistoryFilterRangeFrom": "من {from}",
  "orderHistoryFilterRangeTo": "حتى {to}",
  "orderHistoryTrackCta": "تتبّع",
  "orderHistoryReorderCta": "اطلبها مرة ثانية",
```
app_localizations.dart (house pattern — `_get` + `replaceFirst`, alphabetical among the
`orderHistory*` getters — insert directly after `orderHistoryFilterCta`) —
```dart
  String orderHistoryFilterRange(String from, String to) => _get('orderHistoryFilterRange')
      .replaceFirst('{from}', from)
      .replaceFirst('{to}', to);
  String orderHistoryFilterRangeFrom(String from) =>
      _get('orderHistoryFilterRangeFrom').replaceFirst('{from}', from);
  String orderHistoryFilterRangeTo(String to) =>
      _get('orderHistoryFilterRangeTo').replaceFirst('{to}', to);
  String get orderHistoryReorderCta => _get('orderHistoryReorderCta');
  String get orderHistoryTrackCta => _get('orderHistoryTrackCta');
```
why: the redesigned header replaces the bare "Filter by date"/"Date filter applied" chip with a
readable range label, and the rows gain the board's Track / "Jeeb it again" retention actions —
all user-visible, bilingual. No plural family needed (all placeholders are pre-formatted
strings). Title reuses the existing `navDelivery`; tab/status/empty/error strings are all
existing keys. `orderHistoryFilterActive` becomes unused by this screen — leaving it in the ARBs
is deliberate; retiring it is the integrator's call.
