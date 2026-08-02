// Render tests for the ChatComposer previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_composer_icon_button.dart';

import '../preview_test_harness.dart';

/// Text pinned by the attaching preview. Declared here because that preview is
/// exercised below by hand rather than through [testPreviewsRender].
const String _kAttachingDraft = 'Photo of the gate coming now';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Attaching · spinner`, which cannot settle — see the
  testPreviewsRender(
    'ChatComposer',
    const <String, Widget Function()>{
      'Empty · send disabled': chatComposerEmpty,
      'Draft · send enabled': chatComposerDraft,
      'Jeeber hint · Price / time': chatComposerJeeberHint,
      'Bidi draft': chatComposerBidiDraft,
      'Long draft · maxLines cap': chatComposerLongDraft,
    },
    expectedText: const <String, String>{
      'Empty · send disabled': 'Type a message',
      'Draft · send enabled':
          'I need standard delivery from downtown to airport',
      'Jeeber hint · Price / time': 'Price / time',
      'Bidi draft': 'OK شكراً',
      'Long draft · maxLines cap':
          'Please leave the parcel with the concierge at the main entrance, '
              'tell him it is for apartment 12B, and if nobody answers call me '
              'before you leave the building.',
    },
  );

  // The attaching state renders `OmdsButtonLoading`, i.e. an INDETERMINATE
  group('ChatComposer previews · Attaching · spinner', () {
    Future<void> pumpAttaching(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(chatComposerAttaching, locale));
      await tester.pump(); // runs the post-frame "type the draft" callback
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Attaching · spinner · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpAttaching(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Attaching · spinner renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpAttaching(tester);

      expect(find.text(_kAttachingDraft), findsOneWidget);
    });

    testWidgets('the "+" is swapped for a spinner, so a second tap can\'t race',
        (WidgetTester tester) async {
      await pumpAttaching(tester);

      expect(find.byKey(ChatComposer.attachButtonKey), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('ChatComposer preview specifics', () {
    VoidCallback? sendHandler(WidgetTester tester) => tester
        .widget<ChatComposerIconButton>(find.byKey(ChatComposer.sendButtonKey))
        .onPressed;

    testWidgets('empty draft leaves the send pill disabled', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatComposerEmpty);

      expect(sendHandler(tester), isNull);
    });

    testWidgets('a typed draft enables the send pill', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatComposerDraft);

      expect(sendHandler(tester), isNotNull);
    });

    testWidgets('B-04 — no preview renders a mic affordance', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in <Widget Function()>[
        chatComposerEmpty,
        chatComposerDraft,
        chatComposerLongDraft,
      ]) {
        await pumpPreview(tester, preview);

        expect(find.byIcon(Icons.mic_none), findsNothing);
        expect(
          find.bySemanticsIdentifier('chat_detail_voice_button'),
          findsNothing,
        );
      }
    });
  });
}
