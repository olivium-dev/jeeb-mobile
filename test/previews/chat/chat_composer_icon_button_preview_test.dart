// Render tests for the ChatComposerIconButton previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the shared template — see
// `test/previews/preview_test_harness.dart`.
//
// The widget renders no text, so `expectedText` pins each specimen's caption.
// That is not a formality here: six icon-only circles are the easiest possible
// case for a preview file to render the same state six times and still pass.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_composer_icon_button.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ChatComposerIconButton',
    const <String, Widget Function()>{
      'Attach · enabled': chatComposerIconButtonAttach,
      'Send · enabled': chatComposerIconButtonSendEnabled,
      'Send · disabled': chatComposerIconButtonSendDisabled,
      'Attach · disabled': chatComposerIconButtonAttachDisabled,
      'Voice · B-04 hidden role': chatComposerIconButtonVoice,
      'Tap target · 44dp in 48dp': chatComposerIconButtonTapTarget,
    },
    expectedText: const <String, String>{
      'Attach · enabled': 'Attach · enabled',
      'Send · enabled': 'Send · enabled',
      'Send · disabled': 'Send · disabled',
      'Attach · disabled': 'Attach · disabled',
      'Voice · B-04 hidden role': 'Voice · B-04 hidden role',
      'Tap target · 44dp in 48dp': 'Tap target · 44dp in 48dp',
    },
  );

  group('ChatComposerIconButton preview specifics', () {
    ChatComposerIconButton buttonIn(WidgetTester tester) =>
        tester.widget<ChatComposerIconButton>(
          find.byType(ChatComposerIconButton),
        );

    testWidgets('each specimen shows exactly one button', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in <Widget Function()>[
        chatComposerIconButtonAttach,
        chatComposerIconButtonSendEnabled,
        chatComposerIconButtonSendDisabled,
        chatComposerIconButtonAttachDisabled,
        chatComposerIconButtonVoice,
        chatComposerIconButtonTapTarget,
      ]) {
        await pumpPreview(tester, preview);
        expect(find.byType(ChatComposerIconButton), findsOneWidget);
      }
    });

    testWidgets('the disabled specimens carry a null handler', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatComposerIconButtonSendDisabled);
      expect(buttonIn(tester).onPressed, isNull);

      await pumpPreview(tester, chatComposerIconButtonAttachDisabled);
      expect(buttonIn(tester).onPressed, isNull);
    });

    testWidgets('the enabled specimens carry a real handler', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatComposerIconButtonSendEnabled);
      expect(buttonIn(tester).onPressed, isNotNull);

      await pumpPreview(tester, chatComposerIconButtonAttach);
      expect(buttonIn(tester).onPressed, isNotNull);
    });

    // The semantics label is the only user-facing string this widget has, and
    // it is passed in by the caller — so a preview that hardcoded English
    // would render an identical-looking canvas while hiding a missing
    // translation. Pin the real ARB values in both locales.
    testWidgets('semantics labels come from the ambient locale', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatComposerIconButtonSendEnabled);
      expect(buttonIn(tester).semanticsLabel, 'Send message');

      await pumpPreview(
        tester,
        chatComposerIconButtonSendEnabled,
        locale: const Locale('ar'),
      );
      expect(buttonIn(tester).semanticsLabel, 'إرسال الرسالة');

      await pumpPreview(
        tester,
        chatComposerIconButtonAttach,
        locale: const Locale('ar'),
      );
      expect(buttonIn(tester).semanticsLabel, 'إرفاق صورة');
    });

    // The tap-target specimen only means something if the ring it draws is
    // actually Material's minimum and the button fits inside it. Both hold
    // today (44dp in 48dp) and would still hold if the widget were fixed to
    // fill the 48dp, so this pins the preview's premise without pinning the
    // defect.
    testWidgets('the tap-target specimen measures the button against 48dp', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatComposerIconButtonTapTarget);

      final Size button = tester.getSize(find.byType(ChatComposerIconButton));
      expect(button.width, lessThanOrEqualTo(kMinInteractiveDimension));
      expect(button.height, lessThanOrEqualTo(kMinInteractiveDimension));
      expect(button.width, button.height);
    });
  });
}
