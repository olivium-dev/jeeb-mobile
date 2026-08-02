// Render tests for the JeeberFeedEmptyView previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. See `test/previews/preview_test_harness.dart`.
//
// The empty copy ("No Requests yet") is identical in all six states, so the
// pinned string for each one is its GREETING line — that is the only text this
// widget varies, and pinning the shared copy instead would let six previews of
// the same state pass.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/previews/jeeber_home/jeeber_feed_empty_view_preview.dart';

import '../preview_test_harness.dart';

const Key _switchKey = Key('jeeber-home-accept-orders-switch');

OmdsSwitchTile _switchTile(WidgetTester tester) =>
    tester.widget<OmdsSwitchTile>(find.byKey(_switchKey));

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeeberFeedEmptyView',
    const <String, Widget Function()>{
      'Online · nothing in range': jeeberFeedEmptyViewAccepting,
      'Offline · switch off': jeeberFeedEmptyViewPaused,
      'Toggle not wired · no avatar': jeeberFeedEmptyViewDeadToggle,
      'Cold start · generic greeting': jeeberFeedEmptyViewColdStart,
      'Ambient profile wins (P0-X06)': jeeberFeedEmptyViewAmbientProfile,
      'Long name · short viewport': jeeberFeedEmptyViewLongName,
    },
    expectedText: const <String, String>{
      'Online · nothing in range': 'Hello, Kamal',
      'Offline · switch off': 'Hello, Layla',
      'Toggle not wired · no avatar': 'Hello, Nadia',
      'Cold start · generic greeting': 'Welcome back',
      'Ambient profile wins (P0-X06)': 'Hello, Rami',
      'Long name · short viewport': 'Hello, Abdulrahman',
    },
  );

  group('JeeberFeedEmptyView preview specifics', () {
    testWidgets('the wired toggle actually moves', (WidgetTester tester) async {
      await pumpPreview(tester, jeeberFeedEmptyViewAccepting);

      expect(_switchTile(tester).value, isTrue);
      await tester.tap(find.byKey(_switchKey));
      await tester.pumpAndSettle();
      expect(_switchTile(tester).value, isFalse);
    });

    testWidgets('the offline state opens with availability OFF', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberFeedEmptyViewPaused);

      expect(_switchTile(tester).value, isFalse);
    });

    testWidgets('the unwired state leaves the switch dead but full-strength', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberFeedEmptyViewDeadToggle);

      // What the dev-seam host renders today: no callback, so the Switch is
      // disabled — yet `enabled` stays true, so the title is NOT dimmed and the
      // control reads as live.
      expect(_switchTile(tester).onChanged, isNull);
      expect(_switchTile(tester).enabled, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);

      // No avatar threaded → the greeting collapses to a bare line.
      expect(find.byType(OmdsProfileAvatar), findsNothing);
    });

    testWidgets('the ambient profile beats the threaded placeholder (P0-X06)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberFeedEmptyViewAmbientProfile);

      expect(find.text('Hello, Rami'), findsOneWidget);
      expect(find.textContaining('Kamal'), findsNothing);
    });

    testWidgets('the long name ellipsizes on one line', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberFeedEmptyViewLongName);

      final Text greeting = tester.widget<Text>(
        find.text('Hello, Abdulrahman'),
      );
      expect(greeting.maxLines, 1);
      expect(greeting.overflow, TextOverflow.ellipsis);
    });

    testWidgets('every state renders the same empty copy, in both locales', (
      WidgetTester tester,
    ) async {
      const List<Widget Function()> all = <Widget Function()>[
        jeeberFeedEmptyViewAccepting,
        jeeberFeedEmptyViewPaused,
        jeeberFeedEmptyViewDeadToggle,
        jeeberFeedEmptyViewColdStart,
        jeeberFeedEmptyViewAmbientProfile,
        jeeberFeedEmptyViewLongName,
      ];

      for (final Widget Function() preview in all) {
        await pumpPreview(tester, preview);
        expect(find.text('No Requests yet'), findsOneWidget);
        expect(find.text('All requests will show up here'), findsOneWidget);

        await pumpPreview(tester, preview, locale: const Locale('ar'));
        expect(find.text('لا توجد طلبات بعد'), findsOneWidget);
        expect(find.text('قبول الطلبات'), findsOneWidget);
      }
    });
  });
}
