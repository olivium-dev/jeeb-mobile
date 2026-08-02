// Shared dev-only fixtures for `SettlementDetailScreen` (T-MOB-032 AC2).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entries
//     (`lib/devtool/catalog/entries/batch_10_entries.dart` — BOTH the
//     `SettlementScreen` list and the `SettlementDetailScreen` breakdown), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/settlement/presentation/settlement_detail_screen.dart`.
//
// The catalog owned these as a private `_sampleStatements()` helper that the
// list entry and the detail entry both called. [settlementDetailScreenPaidWeek]
// and [settlementDetailScreenPendingWeek] ARE that helper's two rows, moved
// here byte for byte — no value changed, so the designer sees exactly what was
// signed off. The three fixtures after them are new and preview-only; the
// catalog does not use them, the same way `batch_11_entries.dart` uses two of
// the five rows in `transaction_detail_screen_fixtures.dart`.
//
// There is no fake repository in this file and there cannot be one:
// [SettlementDetailScreen] takes a `statement:` VALUE and reads nothing else —
// no cubit, no `sl<>()`, no `Dio`. Both surfaces are network-free by
// construction rather than by the guard their hosts install.
//
// A note on the two catalog rows, because it reads as a fixture typo and is
// not one: neither statement's `totalPayout` equals the sum of its own
// delivery-line `net`s (184.50 over lines totalling 28.00; 96.00 over a single
// 9.60 line). They are preserved because the screen renders the headline and
// the breakdown as two independent server fields and never reconciles them —
// see the preview section's notes. Changing the numbers here would hide that.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'package:jeeb_mobile/features/settlement/domain/settlement_statement.dart';

/// The settled week: paid out, two delivery lines, USD.
///
/// The catalog's `Paid` state and the closest thing this screen has to a happy
/// path — a status chip on the success role, a two-row breakdown, and short
/// values that fit any width.
const SettlementStatement settlementDetailScreenPaidWeek = SettlementStatement(
  id: 'stmt-1',
  weekLabel: 'Jun 22 – Jun 28',
  totalPayout: 184.50,
  currency: 'USD',
  status: SettlementStatus.paid,
  deliveries: <SettlementDeliveryLine>[
    SettlementDeliveryLine(
      deliveryId: 'REQ-1042',
      date: '2026-06-24',
      tier: 'Express',
      fare: 20.0,
      commission: 4.0,
      net: 16.0,
      currency: 'USD',
    ),
    SettlementDeliveryLine(
      deliveryId: 'REQ-1038',
      date: '2026-06-25',
      tier: 'Flash',
      fare: 15.0,
      commission: 3.0,
      net: 12.0,
      currency: 'USD',
    ),
  ],
);

/// The open week: not yet paid, one delivery line, USD.
///
/// The catalog's `Pending` state. Its only rendered difference from
/// [settlementDetailScreenPaidWeek] is the chip — copy and semantic color role
/// both flip (`warningContainer` instead of `successContainer`).
const SettlementStatement settlementDetailScreenPendingWeek =
    SettlementStatement(
  id: 'stmt-2',
  weekLabel: 'Jun 29 – Jul 5',
  totalPayout: 96.00,
  currency: 'USD',
  status: SettlementStatus.pending,
  deliveries: <SettlementDeliveryLine>[
    SettlementDeliveryLine(
      deliveryId: 'REQ-1055',
      date: '2026-07-01',
      tier: 'Standard',
      fare: 12.0,
      commission: 2.4,
      net: 9.6,
      currency: 'USD',
    ),
  ],
);

/// The two rows the `SettlementScreen` catalog entry lists.
///
/// Declared here rather than in the catalog so the list and the detail cannot
/// disagree about what a statement contains: tapping row 1 of this list is what
/// opens [settlementDetailScreenPaidWeek].
const List<SettlementStatement> settlementDetailScreenSampleWeeks =
    <SettlementStatement>[
  settlementDetailScreenPaidWeek,
  settlementDetailScreenPendingWeek,
];

/// A statement with NO delivery lines — the week a Jeeber took no jobs.
///
/// Ordinary, not contrived: statements are issued per period, and an approved
/// Jeeber who drove nothing still gets one. `deliveries` is also the field
/// `SettlementStatement.fromJson` defaults to `[]` whenever the gateway omits
/// it, so any contract drift on that key lands on this rendering too.
const SettlementStatement settlementDetailScreenNoDeliveriesWeek =
    SettlementStatement(
  id: 'stmt-3',
  weekLabel: 'Jul 6 – Jul 12',
  totalPayout: 0.0,
  currency: 'USD',
  status: SettlementStatus.pending,
  deliveries: <SettlementDeliveryLine>[],
);

/// The layout ceiling: Lebanese pounds, six lines, and a corrected period.
///
/// LBP is the live currency of this market and it has no minor unit in
/// practice, so a week's payout is eight digits. The screen prints every amount
/// as `'<currency> <toStringAsFixed(2)>'` — no grouping separators and two
/// forced decimals — which makes `LBP 12555000.00` the widest value the
/// breakdown row can be handed by an ordinary payload, not an invented one.
///
/// The `weekLabel` is long for the same reason: it is free server text rendered
/// straight into the app-bar title, and a re-issued statement carrying its
/// carry-over period in the label is the shape that arrives in practice.
///
/// Unlike the two catalog rows above, this one RECONCILES — the six `net`s sum
/// to [totalPayout] and every `commission` is exactly 10% of its `fare`
/// (D37) — so the previews show both a statement that adds up and two that do
/// not, side by side.
const SettlementStatement settlementDetailScreenLbpWeek = SettlementStatement(
  id: 'stmt-lbp-2026-w31',
  weekLabel: 'Jul 27 – Aug 2 (adjusted, includes Jun 29 – Jul 5 carry-over)',
  totalPayout: 12555000.00,
  currency: 'LBP',
  status: SettlementStatus.pending,
  deliveries: <SettlementDeliveryLine>[
    SettlementDeliveryLine(
      deliveryId: 'REQ-20412',
      date: '2026-07-27',
      tier: 'Flash',
      fare: 2250000.0,
      commission: 225000.0,
      net: 2025000.0,
      currency: 'LBP',
    ),
    SettlementDeliveryLine(
      deliveryId: 'REQ-20455',
      date: '2026-07-28',
      tier: 'Express',
      fare: 1800000.0,
      commission: 180000.0,
      net: 1620000.0,
      currency: 'LBP',
    ),
    SettlementDeliveryLine(
      deliveryId: 'REQ-20489',
      date: '2026-07-29',
      tier: 'Standard',
      fare: 1350000.0,
      commission: 135000.0,
      net: 1215000.0,
      currency: 'LBP',
    ),
    SettlementDeliveryLine(
      deliveryId: 'REQ-20502',
      date: '2026-07-30',
      tier: 'Express',
      fare: 2700000.0,
      commission: 270000.0,
      net: 2430000.0,
      currency: 'LBP',
    ),
    SettlementDeliveryLine(
      deliveryId: 'REQ-20544',
      date: '2026-07-31',
      tier: 'Flash',
      fare: 3150000.0,
      commission: 315000.0,
      net: 2835000.0,
      currency: 'LBP',
    ),
    SettlementDeliveryLine(
      deliveryId: 'REQ-20571',
      date: '2026-08-01',
      tier: 'Standard',
      fare: 2700000.0,
      commission: 270000.0,
      net: 2430000.0,
      currency: 'LBP',
    ),
  ],
);

/// What a payload missing `weekLabel` and `deliveries` actually renders.
///
/// Built by calling the REAL [SettlementStatement.fromJson] on a partial map
/// rather than by hand-writing the defaults, so the fixture cannot drift from
/// the parser it is meant to characterise. The parser accepts both `weekLabel`
/// and `periodLabel` for the title and falls back to `''`; a third spelling —
/// or a statement the gateway has not labelled yet — lands here.
///
/// Not const: `fromJson` is a factory. Returned fresh per call, which costs
/// nothing and keeps the two surfaces from sharing a mutable-looking global.
SettlementStatement settlementDetailScreenPartialPayloadWeek() =>
    SettlementStatement.fromJson(const <String, dynamic>{
      'id': 'stmt-partial-4',
      'period': 'Jul 13 – Jul 19',
      'totalPayout': 42.75,
      'currency': 'USD',
      'status': 'pending',
    });
