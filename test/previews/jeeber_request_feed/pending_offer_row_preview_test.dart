// Render tests for the PendingOfferRow previews.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/pending_offer_row.dart';

import '../preview_test_harness.dart';

/// The Withdraw control, keyed by the row's own `pending-offer-withdraw-<index>`
/// key. Every preview renders index 0.
final Finder _withdrawCta = find.byKey(const Key('pending-offer-withdraw-0'));

/// The price paragraph. It is the first [Text] the row builds, which is how the
/// Arabic rendering is reached without pasting a bidi-marked literal into the
final Finder _price = find.byType(Text).first;

/// Width a [Text] was actually given, and the width it wanted. The gap between
/// them is the ellipsis.
({double given, double wanted}) _budget(WidgetTester tester, Finder text) {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(text);
  return (
    given: paragraph.size.width,
    wanted: paragraph.getMaxIntrinsicWidth(double.infinity),
  );
}

/// Re-scales a preview the way the matrix's "EN 200% text" rendering does.
/// The [MediaQuery] goes *below* the app so it overrides `MediaQuery.fromView`.
Widget Function() _atTextScale(Widget Function() preview, double scale) {
  return () => Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: preview(),
        ),
      );
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'PendingOfferRow',
    const <String, Widget Function()>{
      'Awaiting decision': pendingOfferRowAwaiting,
      'Withdraw in flight': pendingOfferRowWithdrawing,
      'No ETA': pendingOfferRowNoEta,
      'Accepted · terminal': pendingOfferRowAccepted,
      'Not selected · terminal': pendingOfferRowLost,
      'Long price + ETA': pendingOfferRowLongContent,
    },
    // One distinct money string per state: a suite that only asked "did
    expectedText: const <String, String>{
      'Awaiting decision': r'$12.50',
      'Withdraw in flight': r'$18.00',
      'No ETA': r'$7.25',
      'Accepted · terminal': r'$9.00',
      'Not selected · terminal': r'$6.50',
      'Long price + ETA': 'L£2,750,000',
    },
  );

  group('PendingOfferRow preview specifics', () {
    testWidgets('an OPEN offer carries the awaiting label + Withdraw; a '
        'TERMINAL one carries a badge and neither (sprint-009)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingOfferRowAwaiting);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Withdraw offer'), findsOneWidget);
      expect(_withdrawCta, findsOneWidget);

      await pumpPreview(tester, pendingOfferRowAccepted);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Pending'), findsNothing);
      expect(_withdrawCta, findsNothing);

      await pumpPreview(tester, pendingOfferRowLost);
      // Borrowed copy: a snackbar string about declining a REQUEST, shown to a
      expect(find.text('Request declined'), findsOneWidget);
      expect(_withdrawCta, findsNothing);
    });

    testWidgets('the terminal row is 52dp shorter than the open one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingOfferRowAwaiting);
      final double open = tester.getSize(find.byType(PendingOfferRow)).height;

      await pumpPreview(tester, pendingOfferRowAccepted);
      final double terminal =
          tester.getSize(find.byType(PendingOfferRow)).height;

      expect(open, 141.0);
      expect(terminal, 89.0);
    });

    testWidgets('a withdraw in flight swaps the label for a spinner without '
        'resizing the row', (WidgetTester tester) async {
      await pumpPreview(tester, pendingOfferRowAwaiting);
      final double idle = tester.getSize(find.byType(PendingOfferRow)).height;
      final double idleCta = tester.getSize(_withdrawCta).width;

      await pumpPreview(tester, pendingOfferRowWithdrawing);
      expect(find.text('Withdraw offer'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.getSize(find.byType(PendingOfferRow)).height, idle);

      // The height holds, but the control itself collapses from a 197dp pill to
      expect(tester.getSize(_withdrawCta).width, lessThan(idleCta / 2));
    });

    testWidgets('at 200% text the price is the only thing that yields', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        _atTextScale(pendingOfferRowLongContent, 2),
      );

      final ({double given, double wanted}) price = _budget(tester, _price);
      final ({double given, double wanted}) eta =
          _budget(tester, find.text('1440 min'));

      // `_PriceEtaRow` gives the price an Expanded and the ETA a bare Text, so
      expect(eta.given, eta.wanted);
      expect(price.given, lessThan(price.wanted / 2));
    });

    testWidgets('Arabic squeezes the price harder than English, because '
        '"دقيقة" is wider than "min"', (WidgetTester tester) async {
      await pumpPreview(
        tester,
        _atTextScale(pendingOfferRowLongContent, 2),
      );
      final ({double given, double wanted}) en = _budget(tester, _price);

      await pumpPreview(
        tester,
        _atTextScale(pendingOfferRowLongContent, 2),
        locale: const Locale('ar'),
      );
      final ({double given, double wanted}) ar = _budget(tester, _price);

      // "1440 دقيقة" costs 242dp against "1440 min"'s 196dp, and every dp of
      expect(ar.wanted, greaterThan(en.wanted));
      expect(ar.given, lessThan(en.given));
    });

    testWidgets('the price is painted with a container FILL role, which is '
        'what makes it vanish in dark mode', (WidgetTester tester) async {
      await pumpPreview(tester, pendingOfferRowAwaiting);

      final Text price = tester.widget<Text>(find.text(r'$12.50'));
      // `secondaryContainer` is a background role. Light hand-authors it as
      expect(price.style?.color, AppTheme.light().colorScheme.secondaryContainer);
    });
  });
}
