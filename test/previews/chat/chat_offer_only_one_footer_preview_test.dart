// Render tests for the ChatOfferOnlyOneFooter previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_offer_only_one_footer.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'One offer': chatOfferOnlyOneFooterSingleOffer,
  'Offer stack': chatOfferOnlyOneFooterOfferStack,
  'Narrow phone · declined offer': chatOfferOnlyOneFooterNarrowPhone,
  'Accept in flight': chatOfferOnlyOneFooterAcceptInFlight,
  'Long neighbour content': chatOfferOnlyOneFooterLongContent,
};

/// The one Text the widget under review actually owns.
Finder _noteText() => find.descendant(
      of: find.byType(ChatOfferOnlyOneFooter),
      matching: find.byType(Text),
    );

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ChatOfferOnlyOneFooter',
    _previews,
    expectedText: const <String, String>{
      'One offer': 'Kamal Hajj',
      'Offer stack': 'Layla Nasr',
      'Narrow phone · declined offer': 'Nour Haddad',
      'Accept in flight': 'Rami Aoun',
      'Long neighbour content': 'Abdulrahman Al-Muhandis Al-Trabulsi',
    },
  );

  group('ChatOfferOnlyOneFooter preview specifics', () {
    for (final MapEntry<String, Widget Function()> entry in _previews.entries) {
      testWidgets('${entry.key} · shows the note exactly once', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, entry.value);

        // Every preview keeps offer cards above the note, because production
        expect(find.byType(ChatOfferOnlyOneFooter), findsOneWidget);
        expect(find.text('Accept only one offer'), findsOneWidget);
      });
    }

    testWidgets('carries the semantics identifier chat tests assert on', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, chatOfferOnlyOneFooterSingleOffer);

      // `chat_detail_offer_only_one_note` is the hook
      expect(
        find.bySemanticsIdentifier('chat_detail_offer_only_one_note'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the note is localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        chatOfferOnlyOneFooterSingleOffer,
        locale: const Locale('ar'),
      );

      final Text note = tester.widget<Text>(_noteText());
      expect(note.data, isNot('Accept only one offer'));
      expect(note.data, matches(RegExp(r'[؀-ۿ]')));
      // Centered on purpose: it is the only cue that the line belongs to the
      expect(note.textAlign, TextAlign.center);
    });

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets(
          'the note itself holds at 320pt · 200% text · ${locale.languageCode}',
          (WidgetTester tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        // Deliberately the bare widget, not a preview: at 200% text the
        await tester.pumpWidget(
          previewCanvas(
            () => Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 320,
                child: ListView(
                  children: const <Widget>[ChatOfferOnlyOneFooter()],
                ),
              ),
            ),
            locale,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ChatOfferOnlyOneFooter), findsOneWidget);
      });
    }
  });
}
