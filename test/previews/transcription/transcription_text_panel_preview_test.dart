// Render tests for the TranscriptionTextPanel previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. Each state pins a DISTINCT string, which is
// what separates "the previews render" from "the previews render their own
// state" — six previews all showing the same grey card would pass the weaker
// check.
//
// One preview is pinned in the specifics group instead of through
// `expectedText`: `Whitespace · treated as empty` renders the SAME placeholder
// as the empty state by design, so there is no string that tells the two apart.
// What distinguishes it is its input, and that is asserted directly — the raw
// whitespace must never reach the card.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/transcription/presentation/transcription_screen.dart';
import 'package:jeeb_mobile/features/transcription/presentation/widgets/transcription_text_panel.dart';

import '../preview_test_harness.dart';

/// The whitespace-only transcript the preview feeds in, mirrored here so the
/// assertion can prove it was swallowed rather than rendered.
const String _kWhitespaceTranscript = '   \n  ';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'TranscriptionTextPanel',
    const <String, Widget Function()>{
      'Ready · machine transcript': transcriptionTextPanelReady,
      'Empty · queued placeholder': transcriptionTextPanelEmpty,
      'Whitespace · treated as empty': transcriptionTextPanelWhitespace,
      'Arabic transcript · English UI': transcriptionTextPanelArabicContent,
      'Long transcript · overflow ceiling':
          transcriptionTextPanelLongTranscript,
      'Editing · field + Done': transcriptionTextPanelEditing,
    },
    expectedText: const <String, String>{
      'Ready · machine transcript':
          'Please deliver 2 bags of rice and a water gallon to Hamra, Beirut.',
      'Empty · queued placeholder': 'Type your request here',
      'Arabic transcript · English UI': 'كيلو بندورة من السوق',
      'Long transcript · overflow ceiling':
          'I need someone to go to the Spinneys in Achrafieh and pick up two '
              'bags of rice, a gallon of water, four tomatoes, a kilo of '
              'chicken breast and one box of the green tea I usually get, then '
              'bring everything to the building behind the pharmacy on '
              'Independence street, second floor, and please call me when you '
              'are downstairs because the doorbell has been broken since last '
              'month.',
      'Editing · field + Done': 'Two bags of rice',
    },
  );

  group('TranscriptionTextPanel preview specifics', () {
    Finder editButton() =>
        find.bySemanticsIdentifier(TranscriptionKeys.editButton);

    testWidgets('a real transcript gets the Edit affordance', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, transcriptionTextPanelReady);

      expect(editButton(), findsOneWidget);
    });

    testWidgets('the empty state offers nothing to edit', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, transcriptionTextPanelEmpty);

      expect(editButton(), findsNothing);
    });

    testWidgets('a whitespace-only transcript is swallowed, not rendered', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, transcriptionTextPanelWhitespace);

      // Its own state: the raw input never reaches the card, the placeholder
      // takes its place, and there is still nothing to edit.
      expect(find.text(_kWhitespaceTranscript), findsNothing);
      expect(find.text('Type your request here'), findsOneWidget);
      expect(editButton(), findsNothing);
    });

    testWidgets('edit mode swaps the card for a field and a Done button', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, transcriptionTextPanelEditing);

      expect(find.bySemanticsIdentifier(TranscriptionKeys.textField),
          findsOneWidget);
      expect(find.bySemanticsIdentifier(TranscriptionKeys.saveEditButton),
          findsOneWidget);
      // The read-only affordance is gone while editing.
      expect(editButton(), findsNothing);
    });
  });
}
