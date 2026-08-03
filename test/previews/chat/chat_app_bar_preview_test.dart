// Render tests for the ChatAppBar previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_app_bar.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ChatAppBar',
    <String, Widget Function()>{
      'Broadcasting (order id, no avatar)': chatAppBarBroadcasting,
      'Matched (photo avatar)': chatAppBarMatchedWithPhoto,
      'Matched (initial fallback)': chatAppBarMatchedInitialFallback,
      'Order chat (dispute action)': chatAppBarWithDisputeAction,
      'Longest name + action': chatAppBarLongName,
      'Unresolved counterpart (empty title)': chatAppBarEmptyTitle,
    },
    expectedText: const <String, String>{
      'Broadcasting (order id, no avatar)': 'ORD-23748',
      'Matched (photo avatar)': 'Sami Fawaz',
      'Matched (initial fallback)': 'Layla Haddad',
      'Order chat (dispute action)': 'Kamal Hajj',
      'Longest name + action': 'Abdulrahman Al-Muhandis Al-Trabulsi',
      // The empty title paints nothing, so the state's own fingerprint is the
      'Unresolved counterpart (empty title)': 'J',
    },
  );

  group('ChatAppBar preview specifics', () {
    testWidgets('broadcasting shows the plain back button, no avatar cluster', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatAppBarBroadcasting);

      // OMDSAppBar's own back affordance (Icons.arrow_back), NOT the chat
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
      expect(find.byType(ClipOval), findsNothing);
      // No counterpart, so no initial disc asserting one exists.
      expect(find.text('O'), findsNothing);
    });

    testWidgets('D1: the photo state renders a circular image, not a glyph', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatAppBarMatchedWithPhoto);

      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('S'), findsNothing);
    });

    testWidgets('D1: the no-photo state falls back to an initial in a circle', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatAppBarMatchedInitialFallback);

      expect(find.text('L'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('D2: the header chevron mirrors with the reading direction', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatAppBarMatchedWithPhoto);
      expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsNothing);

      await pumpPreview(
        tester,
        chatAppBarMatchedWithPhoto,
        locale: const Locale('ar'),
      );
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
    });

    testWidgets('the dispute action survives the longest title', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatAppBarLongName);

      // The title takes the squeeze; the trailing affordance must still be
      expect(find.byIcon(Icons.report_gmailerrorred_outlined), findsOneWidget);
      expect(
        tester.getSize(find.byIcon(Icons.report_gmailerrorred_outlined)).width,
        greaterThan(0),
      );
    });

    testWidgets('the worst case survives phone width in both directions', (
      WidgetTester tester,
    ) async {
      // The shared suite pumps the 800 dp test surface, which is roomy enough
      tester.view.physicalSize = const Size(390, 140);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        await pumpPreview(tester, chatAppBarLongName, locale: locale);

        expect(tester.takeException(), isNull, reason: '$locale overflowed');

        // The title yields; the affordances do not. Both the avatar cluster and
        final Rect avatar = tester.getRect(find.text('A'));
        final Rect action = tester.getRect(
          find.byIcon(Icons.report_gmailerrorred_outlined),
        );
        for (final Rect r in <Rect>[avatar, action]) {
          expect(r.left, greaterThanOrEqualTo(0.0), reason: '$locale $r');
          expect(r.right, lessThanOrEqualTo(390.0), reason: '$locale $r');
        }

        // ...and they sit on OPPOSITE edges, mirrored by direction: the
        expect(
          locale.languageCode == 'ar'
              ? action.right < avatar.left
              : avatar.right < action.left,
          isTrue,
          reason: '$locale: avatar $avatar / action $action not mirrored',
        );
      }
    });
  });
}
