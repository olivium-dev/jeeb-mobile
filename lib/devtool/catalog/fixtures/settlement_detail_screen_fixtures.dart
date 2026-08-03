// Shared dev-only fixtures for `SettlementDetailScreen` (T-MOB-032 AC2).

import 'package:jeeb_mobile/features/settlement/domain/settlement_statement.dart';

/// The settled week: paid out, two delivery lines, USD.
/// The catalog's `Paid` state and the closest thing this screen has to a happy
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
/// The catalog's `Pending` state. Its only rendered difference from
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
/// Declared here rather than in the catalog so the list and the detail cannot
const List<SettlementStatement> settlementDetailScreenSampleWeeks =
    <SettlementStatement>[
  settlementDetailScreenPaidWeek,
  settlementDetailScreenPendingWeek,
];

/// A statement with NO delivery lines — the week a Jeeber took no jobs.
/// Ordinary, not contrived: statements are issued per period, and an approved
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
/// LBP is the live currency of this market and it has no minor unit in
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
/// Built by calling the REAL [SettlementStatement.fromJson] on a partial map
SettlementStatement settlementDetailScreenPartialPayloadWeek() =>
    SettlementStatement.fromJson(const <String, dynamic>{
      'id': 'stmt-partial-4',
      'period': 'Jul 13 – Jul 19',
      'totalPayout': 42.75,
      'currency': 'USD',
      'status': 'pending',
    });
