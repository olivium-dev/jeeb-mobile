import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/features/escalate/application/escalate_cubit.dart';
import 'package:jeeb_mobile/features/delivery_receipt/application/delivery_receipt_cubit.dart';
import 'package:jeeb_mobile/features/delivery_receipt/application/delivery_receipt_state.dart';
import 'package:jeeb_mobile/features/dispute_status/application/dispute_status_cubit.dart';
import 'package:jeeb_mobile/features/earnings/application/earnings_cubit.dart';
import 'package:jeeb_mobile/features/earnings/application/earnings_state.dart';
import 'package:jeeb_mobile/features/goods_cost/application/goods_cost_cubit.dart';
import 'package:jeeb_mobile/features/goods_cost/application/goods_cost_state.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/submitted_offers_cubit.dart';
import '../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../support/midnight_test_harness.dart';

Widget _catalog(String feature, String label) {
  final entry = kScreenCatalog.singleWhere((e) => e.feature == feature);
  final state = entry.states.singleWhere((s) => s.label == label);
  return Builder(builder: state.builder);
}

void main() {
  final cases = <(String, String, String)>[
    (
      'customer_profile',
      'Refresh failed over a seeded profile (UX-42)',
      'customer_profile_refresh_error',
    ),
    (
      'customer_profile',
      'Rate-app unavailable (RATE-01)',
      'customer_profile_rate_app_unavailable',
    ),
    (
      'delivery_receipt',
      'Warm — refresh failed over a loaded receipt',
      'receipt_refresh_failed',
    ),
    (
      'dispute_status',
      'Refresh failed over a loaded dispute',
      'dispute_status_refresh_error',
    ),
    (
      'earnings',
      'Refresh failed — the dashboard stays up',
      'earnings_refresh_failed_note',
    ),
    ('earnings', 'Export failed — error snack', 'earnings_export_error_snack'),
    (
      'goods_cost',
      'Amount unconfirmed — the server confirmed nothing',
      'goods_cost_error_note',
    ),
    (
      'jeeber_pending_offers',
      'Error — withdraw failed',
      'pending_offers_withdraw_failed_snack',
    ),
    (
      'jeeber_pending_offers',
      'Refresh failed — stale rows stay up',
      'pending_offers_refresh_failed_note',
    ),
    (
      'active_delivery_jeeber',
      'Error — proof photo refused',
      'active_delivery_proof_photo_error',
    ),
    (
      'active_delivery_jeeber',
      'Warm — refresh failed over a live delivery',
      'active_delivery_refresh_failed',
    ),
  ];
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final loaded in [false, true]) {
      testWidgets(
        'evidence-labelled catalog performs actual preview: ${locale.languageCode} $loaded',
        (tester) async {
          useReduceMotion(tester);
          await tester.pumpWidget(
            wrapMidnight(
              _catalog(
                'escalate',
                loaded
                    ? 'Reason picker (evidence loaded)'
                    : 'Evidence degraded (chat/timeline unavailable)',
              ),
              locale: locale,
              scrollable: false,
            ),
          );
          await pumpPastFakeLatency(tester);
          final result = find.bySemanticsIdentifier(
            loaded ? 'dispute_auto_attach_note' : 'dispute_evidence_error',
          );
          expect(result, findsOneWidget);
          final cubit = tester.element(result).read<EscalateCubit>();
          expect(cubit.state.evidenceLoaded, loaded);
          expect(cubit.state.evidenceLoadFailed, !loaded);
          expect(cubit.state.evidence.isEmpty, !loaded);
          if (!loaded) {
            expect(
              find.bySemanticsIdentifier('dispute_auto_attach_note'),
              findsNothing,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
    for (final (feature, label, resultId) in cases) {
      testWidgets(
        '${locale.languageCode} performs $feature $label before capture',
        (tester) async {
          useReduceMotion(tester);
          tester.view.physicalSize = const Size(440, 956);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            wrapMidnight(
              _catalog(feature, label),
              locale: locale,
              scrollable: false,
            ),
          );
          await pumpPastFakeLatency(tester);
          expect(tester.takeException(), isNull);
          final error = find.bySemanticsIdentifier(resultId);
          expect(
            error,
            findsOneWidget,
            reason:
                'The actual operation must produce a visible failure, not just loaded content.',
          );
          // Assert retained authoritative data and lack of fabricated write success.
          if (feature == 'delivery_receipt') {
            final c = tester.element(error).read<DeliveryReceiptCubit>();
            expect(c.state.status, DeliveryReceiptStatus.loaded);
            expect(c.state.receipt, isNotNull);
            expect(c.state.refreshError, isNotNull);
          }
          if (feature == 'dispute_status') {
            final c = tester.element(error).read<DisputeStatusCubit>();
            expect(c.state.dispute, isNotNull);
            expect(c.state.refreshError, isNotNull);
          }
          if (feature == 'earnings' && label.startsWith('Refresh')) {
            final c = tester.element(error).read<EarningsCubit>();
            expect(c.state.mode, EarningsViewMode.ready);
            expect(c.state.summary, isNotNull);
            expect(c.state.refreshError, isNotNull);
          }
          if (feature == 'goods_cost') {
            final c = tester.element(error).read<GoodsCostCubit>();
            expect(c.state.submitStatus, GoodsCostSubmitStatus.failed);
            expect(c.state.recorded, isNull);
            expect(find.text('42'), findsOneWidget);
          }
          if (feature == 'jeeber_pending_offers') {
            final root = find.bySemanticsIdentifier(
              'jeeber_pending_offers_root',
            );
            final c = tester.element(root).read<SubmittedOffersCubit>();
            expect(c.state.offers, hasLength(2));
            expect(c.state.withdrawingIds, isEmpty);
          }
        },
      );
    }
  }
}
