// The empty-list-is-not-pullable defect (LR-24) has one structural fix: the
// block always lives inside a scroll host with AlwaysScrollableScrollPhysics.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_pull_to_refresh.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_state_host.dart';

import '../../../support/midnight_test_harness.dart';
import 'jeeb_failure_test_harness.dart';

/// A block far shorter than the viewport — the case where a default
/// `ScrollPhysics` refuses to drag and the refresh gesture dies.
const Widget _kShortBlock = SizedBox(
  height: 40,
  child: Text('Nothing here yet'),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
}) async {
  useReduceMotion(tester);
  await tester.pumpWidget(
    wrapMidnight(
      SizedBox(height: 600, child: child),
      locale: locale,
      scrollable: false,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('JeebStateHost · scrolling', () {
    testWidgets('a short block is still draggable', (WidgetTester tester) async {
      await _pump(
        tester,
        JeebStateHost(onRefresh: () async {}, child: _kShortBlock),
      );

      final SingleChildScrollView view = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(
        view.physics,
        isA<AlwaysScrollableScrollPhysics>(),
        reason: 'without this a short empty state never reaches the drag '
            'threshold and pull-to-refresh is dead (LR-24)',
      );
    });

    testWidgets('the block fills the viewport so it centres', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebStateHost(onRefresh: () async {}, child: _kShortBlock),
      );

      final Size inner = tester.getSize(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(ConstrainedBox),
        ).first,
      );
      expect(inner.height, greaterThanOrEqualTo(600));
    });

    testWidgets('a block taller than the viewport scrolls rather than clips', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebStateHost(
          onRefresh: () async {},
          child: const SizedBox(height: 1400, child: Text('tall')),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('tall'), findsOneWidget);
    });
  });

  group('JeebStateHost · refresh', () {
    testWidgets('onRefresh wraps the host in JeebPullToRefresh', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebStateHost(onRefresh: () async {}, child: _kShortBlock),
      );

      expect(find.byType(JeebPullToRefresh), findsOneWidget);
    });

    testWidgets('no onRefresh means no ring — never a dead gesture', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const JeebStateHost(child: _kShortBlock));

      expect(find.byType(JeebPullToRefresh), findsNothing);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('pulling an EMPTY state actually refetches', (
      WidgetTester tester,
    ) async {
      int refreshes = 0;
      await _pump(
        tester,
        JeebStateHost(
          onRefresh: () async => refreshes++,
          child: const JeebEmptyState(
            headline: 'No orders yet',
            identifier: 'order_history_empty',
          ),
        ),
      );

      await tester.fling(
        find.bySemanticsIdentifier('order_history_empty'),
        const Offset(0, 320),
        1200,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(refreshes, 1);
    });
  });

  group('JeebPullToRefresh', () {
    testWidgets('the ring is muted ink, not the orange accent', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebPullToRefresh(
          onRefresh: () async {},
          child: ListView(children: const <Widget>[Text('row')]),
        ),
      );

      final RefreshIndicator indicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      final ColorScheme scheme = Theme.of(
        tester.element(find.byType(RefreshIndicator)),
      ).colorScheme;
      expect(
        indicator.color,
        isNot(scheme.primary),
        reason: 'OMDS defaults to colorScheme.primary, which on Midnight is '
            'the accent orange reserved for the tile-drawn act (LR-20)',
      );
    });

    testWidgets('an explicit colour still wins', (WidgetTester tester) async {
      await _pump(
        tester,
        JeebPullToRefresh(
          onRefresh: () async {},
          color: const Color(0xFF00FF00),
          child: ListView(children: const <Widget>[Text('row')]),
        ),
      );

      expect(
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).color,
        const Color(0xFF00FF00),
      );
    });
  });
}
