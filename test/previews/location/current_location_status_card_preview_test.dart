// Render tests for the CurrentLocationStatusCard previews.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/location/presentation/widgets/current_location_status_card.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Idle · no detail': currentLocationStatusCardIdle,
  'Resolving · spinner': currentLocationStatusCardResolving,
  'Resolved · real fix': currentLocationStatusCardResolved,
  'Permission denied · recovery': currentLocationStatusCardPermissionDenied,
  'Services off · unselected (panel persists)':
      currentLocationStatusCardServiceDisabledUnselected,
  'Failed · retry only': currentLocationStatusCardFailed,
};

final Finder _card = find.byType(CurrentLocationStatusCard);
final Finder _ctas = find.byType(OmdsPrimaryButton);
final Finder _spinner = find.byType(CircularProgressIndicator);

/// Pumps [preview] on a real 390pt phone instead of the 800x600 test surface,
/// optionally at a raised text scale. Both ceiling tests need the card to be as
Future<void> _pumpOnPhone(
  WidgetTester tester,
  Widget Function() preview, {
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 900);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pump();
}

/// The paragraph behind a rendered string, for the questions a [Finder] cannot
/// answer: how tall the text WANTED to be, and whether it was truncated.
RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text));

void main() {
  setUpAll(loadPreviewArbs);
  setUp(currentLocationStatusCardResetTaps);

  testPreviewsRender(
    'CurrentLocationStatusCard',
    _previews,
    expectedText: const <String, String>{
      'Idle · no detail': 'Current Location',
      'Resolving · spinner': 'Finding your location…',
      'Resolved · real fix': 'Using your current location',
      'Permission denied · recovery': 'Location permission needed',
      'Services off · unselected (panel persists)': 'Location is turned off',
      'Failed · retry only': "Couldn't get your location",
    },
  );

  group('CurrentLocationStatusCard preview specifics', () {
    testWidgets('idle renders the option row and NOTHING else', (
      WidgetTester tester,
    ) async {
      // `idle` has no string of its own, so this absence is what distinguishes
      await _pumpOnPhone(tester, currentLocationStatusCardIdle);

      expect(find.text('Current Location'), findsOneWidget);
      expect(_spinner, findsNothing);
      expect(_ctas, findsNothing);
      expect(find.text('Finding your location…'), findsNothing);
      expect(find.text('Using your current location'), findsNothing);
      expect(find.textContaining('Location'), findsOneWidget);

      final double idleHeight = tester.getSize(_card).height;
      await _pumpOnPhone(tester, currentLocationStatusCardResolved);
      expect(
        tester.getSize(_card).height,
        greaterThan(idleHeight),
        reason: 'every non-idle status adds a detail row below the option',
      );
    });

    testWidgets('permission-denied CTAs reach their OWN handlers', (
      WidgetTester tester,
    ) async {
      // The two recovery panels are near-identical; only the destination
      await _pumpOnPhone(tester, currentLocationStatusCardPermissionDenied);

      await tester.tap(find.text('Open settings'));
      await tester.pump();
      expect(currentLocationStatusCardTaps['appSettings'], 1);
      expect(
        currentLocationStatusCardTaps['locationSettings'],
        0,
        reason: 'a DENIED permission is fixed in APP settings, not the OS '
            'location toggle',
      );

      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(currentLocationStatusCardTaps['retry'], 1);
      expect(currentLocationStatusCardTaps['appSettings'], 1);
    });

    testWidgets('services-off CTA opens LOCATION settings', (
      WidgetTester tester,
    ) async {
      await _pumpOnPhone(
        tester,
        currentLocationStatusCardServiceDisabledUnselected,
      );

      await tester.tap(find.text('Turn on location'));
      await tester.pump();
      expect(currentLocationStatusCardTaps['locationSettings'], 1);
      expect(
        currentLocationStatusCardTaps['appSettings'],
        0,
        reason: 'the OS GPS toggle is not the app permission page',
      );
    });

    testWidgets('failed promotes retry to the only CTA', (
      WidgetTester tester,
    ) async {
      // `failed` passes no onRetry/retryLabel to _Recovery, so the secondary
      await _pumpOnPhone(tester, currentLocationStatusCardFailed);

      expect(_ctas, findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(currentLocationStatusCardTaps['retry'], 1);
      expect(currentLocationStatusCardTaps['appSettings'], 0);
      expect(currentLocationStatusCardTaps['locationSettings'], 0);
    });

    testWidgets('the recovery panel stays up while the option is UNSELECTED', (
      WidgetTester tester,
    ) async {
      // Reachable today: GPS fails, the customer works around it by picking a
      await _pumpOnPhone(
        tester,
        currentLocationStatusCardServiceDisabledUnselected,
      );

      expect(find.text('Location is turned off'), findsOneWidget);
      expect(_ctas, findsNWidgets(2));

      // And the unselected option row is still its own live tap target.
      await tester.tap(find.text('Current Location'));
      await tester.pump();
      expect(currentLocationStatusCardTaps['select'], 1);
    });

    testWidgets('the status row mirrors in Arabic', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, currentLocationStatusCardResolving);
      Rect card = tester.getRect(_card);
      expect(
        tester.getRect(_spinner).left,
        lessThan(tester.getRect(find.text('Finding your location…')).left),
        reason: 'LTR: the spinner leads the label',
      );
      expect(tester.getRect(_spinner).left, greaterThanOrEqualTo(card.left));

      await pumpPreview(
        tester,
        currentLocationStatusCardResolving,
        locale: const Locale('ar'),
      );
      card = tester.getRect(_card);
      expect(
        tester.getRect(_spinner).left,
        greaterThan(tester.getRect(find.text('جارٍ تحديد موقعك…')).left),
        reason: 'AR: the spinner must move to the trailing (right) edge',
      );
      expect(tester.getRect(_spinner).right, lessThanOrEqualTo(card.right));
    });

    testWidgets('the recovery CTA label is CUT at the 200% ceiling', (
      WidgetTester tester,
    ) async {
      // `OmdsPrimaryButton` fixes its height to `Sizes.fourXLarge` (48) and
      await _pumpOnPhone(tester, currentLocationStatusCardPermissionDenied);
      final double pillHeight = tester.getSize(_ctas.first).height;
      RenderParagraph label = _paragraph(tester, 'Open settings');
      expect(
        label.getMinIntrinsicHeight(label.size.width),
        label.size.height,
        reason: 'at 1.0 the label fits the pill exactly as designed',
      );

      await _pumpOnPhone(
        tester,
        currentLocationStatusCardPermissionDenied,
        textScale: 2.0,
      );
      expect(
        tester.getSize(_ctas.first).height,
        pillHeight,
        reason: 'the pill is a fixed 48pt and ignores the text scaler',
      );
      label = _paragraph(tester, 'Open settings');
      expect(
        label.getMinIntrinsicHeight(label.size.width),
        greaterThan(label.size.height),
        reason: 'the scaled label needs more height than the pill allows, so '
            'the recovery CTA is truncated for the users who most need to read '
            'it',
      );
    });

    testWidgets('the option label ellipsizes at the 200% ceiling', (
      WidgetTester tester,
    ) async {
      // `ClientLocationOptionCard._Label` is a single ellipsized line inside an
      await _pumpOnPhone(tester, currentLocationStatusCardIdle);
      expect(
        _paragraph(tester, 'Current Location').didExceedMaxLines,
        isFalse,
        reason: 'the label is intact at 1.0',
      );

      await _pumpOnPhone(
        tester,
        currentLocationStatusCardIdle,
        textScale: 2.0,
      );
      expect(
        _paragraph(tester, 'Current Location').didExceedMaxLines,
        isTrue,
        reason: 'the row has no second line to give the label',
      );
    });
  });
}
