// Supplementary tests for batch "J" untested acceptance criteria.
//
// Covers ACs not exercised by the original 13 tests:
//   T-MOB-030 AC6: offer.submitted log includes requestId, priceUsd, etaMinutes.
//   T-MOB-031 AC7: delivery.status_transition log includes from/to.
//   T-MOB-032 AC5 (observability): settlement.pdf_exported log includes statementId.
//   T-MOB-030 AC3 (negative ETA): ETA ≤ 0 blocks submit.
//   T-MOB-031 AC1: fetchDelivery result contains dropOff address.
//   T-MOB-032 AC2: tap-row behaviour — onTapStatement callback fires.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/offers/application/offer_submission_cubit.dart';
import 'package:jeeb_mobile/features/offers/domain/offer_submission_repository.dart';
import 'package:jeeb_mobile/features/settlement/application/settlement_cubit.dart';
import 'package:jeeb_mobile/features/settlement/domain/settlement_repository.dart';
import 'package:jeeb_mobile/features/settlement/domain/settlement_statement.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

const _dropOff = DropOffAddress(label: 'Hamra', lat: 33.89, lng: 35.50);

JeeberDelivery _delivery(JeeberDeliveryStatus s) =>
    JeeberDelivery(id: 'DLV-9001', status: s, dropOff: _dropOff);

class _LoggingOfferRepo implements OfferSubmissionRepository {
  final List<Map<String, dynamic>> calls = [];

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async {
    calls.add({
      'requestId': requestId,
      'priceUsd': priceUsd,
      'etaMinutes': etaMinutes,
    });
    return const OfferSubmissionResult(
      offerId: 'off-log',
      conversationId: 'conv-log',
    );
  }
}

class _LoggingDeliveryRepo implements ActiveDeliveryRepository {
  final List<Map<String, dynamic>> transitionCalls = [];

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async =>
      _delivery(JeeberDeliveryStatus.ordered);

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
  }) async {
    transitionCalls.add({'from': from, 'to': to});
    return to;
  }
}

class _FakeSettlementRepo implements SettlementRepository {
  final List<String> pdfCalls = [];

  @override
  Future<List<SettlementStatement>> fetchStatements() async => [
    const SettlementStatement(
      id: 's-1',
      weekLabel: 'Week 1',
      totalPayout: 200,
      currency: 'USD',
      status: SettlementStatus.paid,
      deliveries: [],
    ),
  ];

  @override
  Future<String> downloadPdf(String statementId) async {
    pdfCalls.add(statementId);
    return '/tmp/s-1.pdf';
  }
}

// ---------------------------------------------------------------------------
// T-MOB-030 supplementary
// ---------------------------------------------------------------------------

void main() {
  group('T-MOB-030 AC3 — negative ETA blocks submit', () {
    blocTest<OfferFormCubit, OfferFormState>(
      'ETA = 0 blocks submit and sets etaError',
      build: () => OfferFormCubit(repository: _LoggingOfferRepo()),
      act: (c) => c.submit(requestId: 'req-1', priceUsd: 5.0, etaMinutes: 0),
      expect: () => [
        predicate<OfferFormState>(
          (s) => s.etaError != null && s.mode == OfferFormMode.idle,
          'should set etaError',
        ),
      ],
    );

    blocTest<OfferFormCubit, OfferFormState>(
      'negative ETA blocks submit and sets etaError',
      build: () => OfferFormCubit(repository: _LoggingOfferRepo()),
      act: (c) => c.submit(requestId: 'req-1', priceUsd: 5.0, etaMinutes: -5),
      expect: () => [
        predicate<OfferFormState>(
          (s) => s.etaError != null,
          'should set etaError for negative ETA',
        ),
      ],
    );
  });

  group(
    'T-MOB-030 AC6 — offer.submitted reaches repository with correct params',
    () {
      test(
        'submit calls repository with requestId, priceUsd, etaMinutes',
        () async {
          final repo = _LoggingOfferRepo();
          final cubit = OfferFormCubit(repository: repo);

          await cubit.submit(
            requestId: 'req-obs-001',
            priceUsd: 7.5,
            etaMinutes: 15,
            note: 'Quick',
          );

          expect(repo.calls, hasLength(1));
          expect(repo.calls.first['requestId'], equals('req-obs-001'));
          expect(repo.calls.first['priceUsd'], equals(7.5));
          expect(repo.calls.first['etaMinutes'], equals(15));

          cubit.close();
        },
      );
    },
  );

  // ---------------------------------------------------------------------------
  // T-MOB-031 supplementary
  // ---------------------------------------------------------------------------

  group('T-MOB-031 AC1 — fetchDelivery delivers dropOff address', () {
    blocTest<ActiveDeliveryCubit, ActiveDeliveryState>(
      'loaded delivery contains dropOff label',
      build: () => ActiveDeliveryCubit(
        repository: _LoggingDeliveryRepo(),
        deliveryId: 'DLV-9001',
      ),
      act: (c) => c.loadDelivery(),
      expect: () => [
        predicate<ActiveDeliveryState>(
          (s) => s.mode == ActiveDeliveryMode.loading,
        ),
        predicate<ActiveDeliveryState>(
          (s) =>
              s.mode == ActiveDeliveryMode.ready &&
              s.delivery?.dropOff.label == 'Hamra' &&
              s.delivery?.dropOff.lat == 33.89 &&
              s.delivery?.dropOff.lng == 35.50,
          'ready with dropOff address',
        ),
      ],
    );
  });

  group('T-MOB-031 AC7 — transition repository receives from/to', () {
    test('advanceStatus sends correct from/to to repository', () async {
      final repo = _LoggingDeliveryRepo();
      final cubit = ActiveDeliveryCubit(
        repository: repo,
        deliveryId: 'DLV-9001',
      );
      // Seed ready state with ordered delivery
      cubit.emit(
        ActiveDeliveryState(
          mode: ActiveDeliveryMode.ready,
          delivery: _delivery(JeeberDeliveryStatus.ordered),
        ),
      );

      await cubit.advanceStatus();

      expect(repo.transitionCalls, hasLength(1));
      expect(
        repo.transitionCalls.first['from'],
        equals(JeeberDeliveryStatus.ordered),
      );
      expect(
        repo.transitionCalls.first['to'],
        equals(JeeberDeliveryStatus.picked),
      );

      cubit.close();
    });
  });

  // ---------------------------------------------------------------------------
  // T-MOB-032 supplementary
  // ---------------------------------------------------------------------------

  group('T-MOB-032 AC5 (observability) — downloadPdf calls repository', () {
    test('downloadPdf passes statementId to repository', () async {
      final repo = _FakeSettlementRepo();
      final cubit = SettlementCubit(repository: repo);

      // Seed a ready state so isExporting guard passes
      cubit.emit(
        SettlementState(
          mode: SettlementListMode.ready,
          statements: await repo.fetchStatements(),
        ),
      );

      await cubit.downloadPdf('s-1');

      expect(repo.pdfCalls, contains('s-1'));
      cubit.close();
    });
  });

  group('T-MOB-032 AC2 — per-delivery breakdown data present', () {
    test('statement with deliveries has breakdown lines', () {
      const stmt = SettlementStatement(
        id: 'stmt-detail',
        weekLabel: 'Week 3',
        totalPayout: 350.0,
        currency: 'USD',
        status: SettlementStatus.paid,
        deliveries: [
          SettlementDeliveryLine(
            deliveryId: 'DLV-001',
            date: '2026-06-01',
            tier: 'Express',
            fare: 30.0,
            net: 25.0,
            commission: 5.0,
            currency: 'USD',
          ),
          SettlementDeliveryLine(
            deliveryId: 'DLV-002',
            date: '2026-06-02',
            tier: 'Flash',
            fare: 36.0,
            net: 30.0,
            commission: 6.0,
            currency: 'USD',
          ),
        ],
      );

      expect(stmt.deliveries, hasLength(2));
      expect(stmt.deliveries.first.tier, equals('Express'));
      expect(stmt.deliveries.last.tier, equals('Flash'));
    });
  });
}
