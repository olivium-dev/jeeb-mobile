// UX-38 + LR-29 + GEN-01: only a validation rejection is the field's fault, a
// failed currency read is announced with a retry, and a DI miss cannot record
// a goods cost against a fake.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/goods_cost/data/unavailable_goods_cost_repository.dart';
import 'package:jeeb_mobile/features/goods_cost/domain/goods_cost.dart';
import 'package:jeeb_mobile/features/goods_cost/domain/goods_cost_repository.dart';
import 'package:jeeb_mobile/features/goods_cost/presentation/goods_cost_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _ScriptedGoodsCostRepository implements GoodsCostRepository {
  _ScriptedGoodsCostRepository({this.fetchFailure, this.recordFailure});

  static const String currency = 'USD';
  final GoodsCostFailure? fetchFailure;
  final GoodsCostFailure? recordFailure;

  int currencyReads = 0;

  @override
  Future<String> fetchCurrency(String deliveryId) async {
    currencyReads++;
    final f = fetchFailure;
    if (f != null) throw GoodsCostRepositoryException(f);
    return currency;
  }

  @override
  Future<GoodsCost> recordGoodsCost({
    required String deliveryId,
    required double amount,
  }) async {
    final f = recordFailure;
    if (f != null) throw GoodsCostRepositoryException(f);
    return GoodsCost(
      deliveryId: deliveryId,
      amount: amount,
      currency: currency,
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  GoodsCostRepository repo, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    wrapForTest(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: GoodsCostScreen(deliveryId: 'DEL-1', repository: repo),
        ),
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.enterText(find.byType(EditableText).first, '12');
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsIdentifier('goods_cost_submit_cta'));
  await tester.pumpAndSettle();
}

void main() {
  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String tag = locale.languageCode;

    testWidgets('$tag: a NETWORK failure renders the note and leaves the '
        'amount field clean', (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(
        tester,
        _ScriptedGoodsCostRepository(
          recordFailure: GoodsCostFailure.network,
        ),
        locale: locale,
      );
      await _submit(tester);

      expect(
        find.bySemanticsIdentifier('goods_cost_error_note'),
        findsOneWidget,
      );
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.decoration?.errorText, isNull);

      handle.dispose();
    });

    testWidgets('$tag: a VALIDATION failure does the opposite', (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(
        tester,
        _ScriptedGoodsCostRepository(
          recordFailure: GoodsCostFailure.validation,
        ),
        locale: locale,
      );
      await _submit(tester);

      expect(
        find.bySemanticsIdentifier('goods_cost_error_note'),
        findsNothing,
      );

      handle.dispose();
    });

    testWidgets('$tag: LR-29 — a failed currency read announces itself and '
        'offers a retry beside the neutral label', (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      final repo = _ScriptedGoodsCostRepository(
        fetchFailure: GoodsCostFailure.network,
      );
      await _pump(tester, repo, locale: locale);

      expect(
        find.bySemanticsIdentifier('goods_cost_currency_retry'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('goods_cost_currency_note'),
        findsOneWidget,
      );
      expect(repo.currencyReads, 1);

      await tester.tap(
        find.bySemanticsIdentifier('goods_cost_currency_retry'),
      );
      await tester.pumpAndSettle();
      expect(repo.currencyReads, 2);

      handle.dispose();
    });
  }

  test('GEN-01: the release-path stand-in THROWS rather than record against a '
      'fake in-memory repository', () async {
    const repo = UnavailableGoodsCostRepository();

    await expectLater(
      repo.recordGoodsCost(deliveryId: 'DEL-1', amount: 12),
      throwsA(isA<GoodsCostRepositoryException>()),
    );
    await expectLater(
      repo.fetchCurrency('DEL-1'),
      throwsA(isA<GoodsCostRepositoryException>().having(
        (e) => e.failure,
        'failure',
        GoodsCostFailure.currencyUnavailable,
      )),
    );
  });
}
