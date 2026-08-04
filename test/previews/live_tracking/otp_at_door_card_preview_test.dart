// Render tests for the OtpAtDoorCard previews.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/otp_handover/presentation/widgets/handover_code_display.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_glass_card.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/otp_at_door_card.dart';

import '../preview_test_harness.dart';

/// The inline code panel's own key, from `otp_at_door_card.dart`. Distinct from
/// the OTP screen's `otpHandover.codeDisplay` so the two surfaces stay
const Key _inlineCodeKey = Key('tracking.atDoorCode');

/// The at-door → OTP CTA, from `otp_at_door_card.dart`.
const Key _ctaKey = Key('tracking.otpCta');

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'OtpAtDoorCard',
    const <String, Widget Function()>{
      'Code known · 1234': otpAtDoorCardWithCode,
      'Code unknown': otpAtDoorCardWithoutCode,
      'Bidi guard · 0450': otpAtDoorCardLeadingZeroCode,
      'Narrow phone · 320 pt': otpAtDoorCardNarrowPhone,
      'Bottom-anchored over map': otpAtDoorCardOverMap,
    },
    expectedText: const <String, String>{
      // One code per state, so a pin can only be satisfied by its own state.
      'Code known · 1234': '1234',
      // The only state with no code: pinned on the pre-G4 fallback sentence,
      'Code unknown':
          'Share your code with your Jeeber to confirm the handover.',
      'Bidi guard · 0450': '0450',
      'Narrow phone · 320 pt': '9061',
      'Bottom-anchored over map': '7788',
    },
  );

  group('OtpAtDoorCard preview specifics', () {
    testWidgets('a known code is shown INLINE, not hidden behind the CTA '
        '(sprint-009 P0 §G4)', (WidgetTester tester) async {
      await pumpPreview(tester, otpAtDoorCardWithCode);

      // Both, not either: the code is on screen AND the full-screen route is
      expect(find.byKey(_inlineCodeKey), findsOneWidget);
      expect(find.text('1234'), findsOneWidget);
      expect(
        find.text('Share this code with your Jeeber when they arrive'),
        findsOneWidget,
      );
      expect(find.byKey(_ctaKey), findsOneWidget);
    });

    testWidgets('no known code degrades to the CTA with no empty code panel', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, otpAtDoorCardWithoutCode);

      // Absent, never blank — an empty pill would read as a broken code.
      expect(find.byKey(_inlineCodeKey), findsNothing);
      expect(find.byType(HandoverCodeDisplay), findsNothing);
      expect(
        find.text('Share this code with your Jeeber when they arrive'),
        findsNothing,
      );
      // The CTA is the customer's only remaining route to the code.
      expect(find.byKey(_ctaKey), findsOneWidget);
      expect(find.text('Show OTP'), findsOneWidget);
    });

    testWidgets('the code keeps LTR digit order inside the Arabic card', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        otpAtDoorCardLeadingZeroCode,
        locale: const Locale('ar'),
      );

      // The card itself mirrors...
      expect(
        Directionality.of(tester.element(find.byKey(_ctaKey))),
        TextDirection.rtl,
      );
      // ...the digits must not. `0450` mirrored reads as a different code.
      final RenderParagraph code = tester.renderObject<RenderParagraph>(
        find.text('0450'),
      );
      expect(code.textDirection, TextDirection.ltr);
      // The Arabic card is genuinely the Arabic card, not an EN fallback.
      expect(find.text('شارك هذا الرمز مع جيبرك عند وصوله'), findsOneWidget);
    });

    testWidgets('the narrow-phone preview really is pinned to 320 pt', (
      WidgetTester tester,
    ) async {
      // The render harness pumps an 800 px viewport, so a preview that forgot
      await pumpPreview(tester, otpAtDoorCardNarrowPhone);

      // Assert the 320 pin on the card itself. The old form pinned the CTA at
      // `320 - 24 * 2`, which silently doubled as a card-padding assertion and
      // went red when M2-08 restyled the card onto JeebGlassCard's 20 gutter.
      final double cardWidth = tester
          .getSize(find.byType(JeebGlassCard).first)
          .width;
      expect(cardWidth, 320);
      expect(
        tester.getSize(find.byKey(_ctaKey)).width,
        lessThan(cardWidth),
        reason: 'the CTA lives inside the card gutter',
      );
    });

    testWidgets('the map backdrop contributes no text of its own', (
      WidgetTester tester,
    ) async {
      // Every string the pins above find in this state must have come from the
      await pumpPreview(tester, otpAtDoorCardOverMap);

      expect(
        find.byType(Text),
        // headline + share-code line + the code itself + CTA label.
        findsNWidgets(4),
      );
      expect(find.text('7788'), findsOneWidget);
    });
  });
}
