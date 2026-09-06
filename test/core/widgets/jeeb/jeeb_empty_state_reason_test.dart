// The §3.4 extension: `reason` collapses the four axes `status` alone could
// not express, `secondaryAction` gives a filtered empty a way out, and the
// error rung announces itself. `status:` keeps working for the 115 call sites
// that already pass it.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';

import '../../../support/midnight_test_harness.dart';
import 'jeeb_failure_test_harness.dart';

/// reason → the rung it must paint.
const Map<JeebEmptyStateReason, JeebEmptyStateStatus> _kRungs =
    <JeebEmptyStateReason, JeebEmptyStateStatus>{
      JeebEmptyStateReason.nothingYet: JeebEmptyStateStatus.empty,
      JeebEmptyStateReason.filtered: JeebEmptyStateStatus.empty,
      JeebEmptyStateReason.noResults: JeebEmptyStateStatus.empty,
      JeebEmptyStateReason.offline: JeebEmptyStateStatus.error,
      JeebEmptyStateReason.notFound: JeebEmptyStateStatus.error,
      JeebEmptyStateReason.failed: JeebEmptyStateStatus.error,
      JeebEmptyStateReason.loading: JeebEmptyStateStatus.loading,
    };

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
}) async {
  useReduceMotion(tester);
  await tester.pumpWidget(wrapMidnight(child, locale: locale));
  await tester.pumpAndSettle();
}

void main() {
  group('JeebEmptyState · reason derives the rung', () {
    for (final MapEntry<JeebEmptyStateReason, JeebEmptyStateStatus> entry
        in _kRungs.entries) {
      test('${entry.key.name} → ${entry.value.name}', () {
        expect(entry.key.status, entry.value);
      });
    }

    testWidgets('reason overrides an inconsistent status:', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const JeebEmptyState(
          headline: 'Nothing here',
          status: JeebEmptyStateStatus.empty,
          reason: JeebEmptyStateReason.failed,
          identifier: 'order_history_error',
        ),
      );

      final JeebEmptyState state = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      expect(state.effectiveStatus, JeebEmptyStateStatus.error);
    });

    testWidgets('status: still decides when no reason is passed', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const JeebEmptyState(
          headline: 'Loading',
          status: JeebEmptyStateStatus.loading,
          identifier: 'order_history_loading',
        ),
      );

      final JeebEmptyState state = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      expect(state.effectiveStatus, JeebEmptyStateStatus.loading);
    });
  });

  group('JeebEmptyState · secondaryAction', () {
    testWidgets('renders below the primary act', (WidgetTester tester) async {
      await _pump(
        tester,
        JeebEmptyState(
          headline: 'No orders in this range',
          reason: JeebEmptyStateReason.filtered,
          identifier: 'order_history_empty',
          action: Semantics(
            identifier: 'order_history_new_cta',
            container: true,
            child: const Text('New request'),
          ),
          secondaryAction: Semantics(
            identifier: 'order_history_clear_filters_cta',
            container: true,
            child: const Text('Clear filters'),
          ),
        ),
      );

      final Offset primary = tester.getCenter(
        find.bySemanticsIdentifier('order_history_new_cta'),
      );
      final Offset secondary = tester.getCenter(
        find.bySemanticsIdentifier('order_history_clear_filters_cta'),
      );
      expect(secondary.dy, greaterThan(primary.dy));
    });

    testWidgets('is withheld while loading, exactly like the primary act', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebEmptyState(
          headline: 'Loading',
          reason: JeebEmptyStateReason.loading,
          identifier: 'order_history_loading',
          action: const Text('New request'),
          secondaryAction: Semantics(
            identifier: 'order_history_clear_filters_cta',
            container: true,
            child: const Text('Clear filters'),
          ),
        ),
      );

      expect(find.text('New request'), findsNothing);
      expect(
        find.bySemanticsIdentifier('order_history_clear_filters_cta'),
        findsNothing,
      );
    });

    testWidgets('renders alone when there is no primary act', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebEmptyState(
          headline: 'No orders in this range',
          reason: JeebEmptyStateReason.filtered,
          identifier: 'order_history_empty',
          secondaryAction: Semantics(
            identifier: 'order_history_clear_filters_cta',
            container: true,
            child: const Text('Clear filters'),
          ),
        ),
      );

      expect(
        find.bySemanticsIdentifier('order_history_clear_filters_cta'),
        findsOneWidget,
      );
    });
  });

  group('JeebEmptyState · asserts', () {
    test('an empty identifier is rejected', () {
      expect(
        () => JeebEmptyState(headline: 'x', identifier: ''),
        throwsAssertionError,
      );
      expect(
        () => JeebEmptyState.compact(headline: 'x', identifier: ''),
        throwsAssertionError,
      );
    });

    test('a null identifier is still allowed', () {
      expect(const JeebEmptyState(headline: 'x').identifier, isNull);
    });

    test('a filtered empty without a way to clear the filter is rejected', () {
      expect(
        () => JeebEmptyState(
          headline: 'No orders in this range',
          reason: JeebEmptyStateReason.filtered,
        ),
        throwsAssertionError,
      );
      expect(
        () => JeebEmptyState.compact(
          headline: 'No orders in this range',
          reason: JeebEmptyStateReason.filtered,
        ),
        throwsAssertionError,
      );
    });
  });

  group('JeebEmptyState · liveRegion', () {
    testWidgets('defaults to true on the error rung', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const JeebEmptyState(
          headline: 'Something went wrong',
          reason: JeebEmptyStateReason.failed,
          identifier: 'order_history_error',
        ),
      );

      final SemanticsData data = tester
          .getSemantics(find.bySemanticsIdentifier('order_history_error'))
          .getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, isTrue);
      expect(
        data.label,
        'Something went wrong',
        reason: 'an announced node with no label of its own reads as silence',
      );
    });

    testWidgets('an announced block folds the body into its label', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const JeebEmptyState(
          headline: 'Something went wrong',
          body: 'Check your connection and try again.',
          reason: JeebEmptyStateReason.failed,
          identifier: 'order_history_error',
        ),
      );

      expect(
        tester
            .getSemantics(find.bySemanticsIdentifier('order_history_error'))
            .getSemanticsData()
            .label,
        'Something went wrong. Check your connection and try again.',
      );
    });

    testWidgets('defaults to false on the empty and loading rungs', (
      WidgetTester tester,
    ) async {
      for (final JeebEmptyStateReason reason in <JeebEmptyStateReason>[
        JeebEmptyStateReason.nothingYet,
        JeebEmptyStateReason.loading,
      ]) {
        await _pump(
          tester,
          JeebEmptyState(
            headline: 'Nothing here',
            reason: reason,
            identifier: 'order_history_empty',
          ),
        );

        expect(
          tester
              .getSemantics(find.bySemanticsIdentifier('order_history_empty'))
              .getSemanticsData()
              .flagsCollection
              .isLiveRegion,
          isFalse,
          reason: '${reason.name} is not news',
        );
      }
    });

    testWidgets('an explicit liveRegion wins in both directions', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const JeebEmptyState(
          headline: 'Nothing here',
          reason: JeebEmptyStateReason.nothingYet,
          liveRegion: true,
          identifier: 'order_history_empty',
        ),
      );
      expect(
        tester
            .getSemantics(find.bySemanticsIdentifier('order_history_empty'))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );

      await _pump(
        tester,
        const JeebEmptyState(
          headline: 'Something went wrong',
          reason: JeebEmptyStateReason.failed,
          liveRegion: false,
          identifier: 'order_history_error',
        ),
      );
      expect(
        tester
            .getSemantics(find.bySemanticsIdentifier('order_history_error'))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isFalse,
      );
    });
  });
}
