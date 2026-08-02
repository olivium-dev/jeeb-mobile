// Render tests for the JeeberRequestDetailLoadingView previews.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_loader.dart';

import '../preview_test_harness.dart';

/// Exact ARB copy, so a reworded string breaks the test instead of silently
/// unpinning the preview.
const String _title = 'Request details';
const String _titleAr = 'تفاصيل الطلب';

/// The captions the preview frames paint. Mirrored here rather than imported
/// (they are private) so a preview silently rewired to another device fails.
const String _phoneCaption =
    'Push tap · by-id fetch in flight · 390 × 844 · inset 47/34';
const String _redirectCaption =
    'Redirect hold · route swap pending · 390 × 844 · inset 47/34';
const String _compactCaption = 'Compact phone · 320 × 568 · no insets';
const String _landscapeCaption = 'Landscape · 852 × 393 · inset 59/59/21';
const String _largeTextCaption =
    'Text ceiling · EN 200% · 390 × 844 · inset 47/34';
const String _compactLargeTextCaption =
    'Compact + 200% · 320 × 568 · title band 216 dp';

/// The frames the previews pin, mirrored for the same reason.
const Size _phoneFrame = Size(390, 844);
const Size _compactFrame = Size(320, 568);
const Size _landscapeFrame = Size(852, 393);

/// Status bar / home indicator of the phone frame.
const double _statusBar = 47;
const double _homeIndicator = 34;

/// Toolbar geometry the assertions are written against: the width the back
/// button claims, and the gap `NavigationToolbar` keeps either side of the
const double _leadingWidth = 56;
const double _middleSpacing = 16;

double _titleBand(double frameWidth) =>
    frameWidth - _leadingWidth - _middleSpacing - 2 * _middleSpacing;

/// Either request id the previews carry. Neither may ever reach the screen.
const String _requestId = 'e30b7f2e-7914-402d-8dd3-e699e6775eae';
const String _deliveryId = '4d1c90ab-5f22-4c17-9d0e-0b6a3f77c145';

/// Pumps [preview] and returns the rect of the view inside its simulated
/// window, then UNMOUNTS so the next pump in the same test starts clean.
Future<Rect> _viewRect(WidgetTester tester, Widget Function() preview) async {
  await pumpPreview(tester, preview);
  final Rect rect = tester.getRect(
    find.byType(JeeberRequestDetailLoadingView),
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  return rect;
}

/// Width the app-bar title would need if nothing constrained it. Font-relative,
/// so only ever compared against ANOTHER reading of the same string.
double _titleIntrinsic(WidgetTester tester) => tester
    .renderObject<RenderParagraph>(find.text(_title))
    .getMaxIntrinsicWidth(double.infinity);

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeeberRequestDetailLoadingView',
    const <String, Widget Function()>{
      'Loading scaffold · phone 390 × 844': jeeberRequestDetailLoadingViewPushTap,
      'Redirect hold · same frame, other id':
          jeeberRequestDetailLoadingViewRedirectHold,
      'Compact phone 320 × 568': jeeberRequestDetailLoadingViewCompactPhone,
      'Landscape 852 × 393': jeeberRequestDetailLoadingViewLandscape,
      'Text ceiling · EN 200%': jeeberRequestDetailLoadingViewLargeText,
      'Compact 320 × 568 · EN 200%':
          jeeberRequestDetailLoadingViewCompactLargeText,
    },
    // Each state names its own window. The widget draws the same title and the
    expectedText: const <String, String>{
      'Loading scaffold · phone 390 × 844': _phoneCaption,
      'Redirect hold · same frame, other id': _redirectCaption,
      'Compact phone 320 × 568': _compactCaption,
      'Landscape 852 × 393': _landscapeCaption,
      'Text ceiling · EN 200%': _largeTextCaption,
      'Compact 320 × 568 · EN 200%': _compactLargeTextCaption,
    },
  );

  group('JeeberRequestDetailLoadingView preview specifics', () {
    testWidgets('each preview simulates its own window, not the 800 × 600 host',
        (WidgetTester tester) async {
      // If the frame ever stopped pinning the MediaQuery/SizedBox, every state
      expect(
        (await _viewRect(tester, jeeberRequestDetailLoadingViewPushTap)).size,
        _phoneFrame,
      );
      expect(
        (await _viewRect(tester, jeeberRequestDetailLoadingViewCompactPhone))
            .size,
        _compactFrame,
      );
      expect(
        (await _viewRect(tester, jeeberRequestDetailLoadingViewLandscape)).size,
        _landscapeFrame,
      );
    });

    testWidgets('the requestId never reaches the screen', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberRequestDetailLoadingViewPushTap);

      // The scaffold takes an id and renders a title and a spinner. Nothing
      expect(find.textContaining(_requestId), findsNothing);
      expect(find.textContaining('75EAE'), findsNothing);
      expect(find.text(_title), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'the redirect hold is the SAME frame as the in-flight fetch — a '
      'different id changes nothing',
      (WidgetTester tester) async {
        final Rect fetching = await _viewRect(
          tester,
          jeeberRequestDetailLoadingViewPushTap,
        );
        final Rect redirecting = await _viewRect(
          tester,
          jeeberRequestDetailLoadingViewRedirectHold,
        );

        expect(redirecting.size, fetching.size);

        // Same window, same two elements, and the id the redirect carries is
        await pumpPreview(tester, jeeberRequestDetailLoadingViewRedirectHold);
        expect(find.textContaining(_deliveryId), findsNothing);
        expect(find.text(_title), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('the spinner is centred in the BODY, below optical centre', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberRequestDetailLoadingViewPushTap);

      final Rect view = tester.getRect(
        find.byType(JeeberRequestDetailLoadingView),
      );
      final Rect spinner = tester.getRect(
        find.byType(CircularProgressIndicator),
      );

      // 47 dp status bar + 56 dp toolbar come off the top and only the 34 dp
      final double bodyCentre =
          (view.top + _statusBar + kToolbarHeight + view.bottom - _homeIndicator) /
              2;
      expect(spinner.center.dy, moreOrLessEquals(bodyCentre, epsilon: 1.0));
      expect(
        spinner.center.dy - view.center.dy,
        moreOrLessEquals(34.5, epsilon: 1.0),
      );
      expect(spinner.center.dx, moreOrLessEquals(view.center.dx, epsilon: 0.5));
      // The indicator is a fixed box; nothing about it responds to the window.
      expect(spinner.size, const Size(48, 48));
    });

    testWidgets('the layout mirrors in AR', (WidgetTester tester) async {
      Future<(double back, double title, double centre)> measure(
        Locale locale,
        String title,
      ) async {
        await pumpPreview(
          tester,
          jeeberRequestDetailLoadingViewPushTap,
          locale: locale,
        );
        expect(find.text(title), findsOneWidget);
        final Rect view = tester.getRect(
          find.byType(JeeberRequestDetailLoadingView),
        );
        return (
          tester.getRect(find.byIcon(Icons.arrow_back)).center.dx,
          tester.getRect(find.text(title)).center.dx,
          view.center.dx,
        );
      }

      final (double backEn, double titleEn, double centreEn) = await measure(
        const Locale('en'),
        _title,
      );
      final (double backAr, double titleAr, double centreAr) = await measure(
        const Locale('ar'),
        _titleAr,
      );

      // The back affordance swaps edges…
      expect(backEn, lessThan(centreEn));
      expect(backAr, greaterThan(centreAr));
      expect(
        backEn - centreEn,
        moreOrLessEquals(centreAr - backAr, epsilon: 0.5),
      );
      // …and the title's offset from the axis is the exact negative of itself
      expect(
        titleEn - centreEn,
        moreOrLessEquals(centreAr - titleAr, epsilon: 0.5),
      );
    });

    testWidgets('200% text moves ONE element, and Material clamps that', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberRequestDetailLoadingViewPushTap);
      final double atDefault = _titleIntrinsic(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await pumpPreview(tester, jeeberRequestDetailLoadingViewLargeText);
      expect(tester.takeException(), isNull);
      final double atCeiling = _titleIntrinsic(tester);

      // The title is the only thing on this screen that reads the text scaler,
      expect(atCeiling / atDefault, moreOrLessEquals(1.34, epsilon: 0.01));

      final Rect view = tester.getRect(
        find.byType(JeeberRequestDetailLoadingView),
      );
      final Rect title = tester.getRect(find.text(_title));
      final Rect spinner = tester.getRect(
        find.byType(CircularProgressIndicator),
      );

      // It stays inside the toolbar rather than pushing into the body…
      expect(title.bottom, lessThan(view.top + _statusBar + kToolbarHeight));
      // …inside the band the toolbar reserves for it…
      expect(
        title.left,
        greaterThanOrEqualTo(view.left + _leadingWidth + _middleSpacing - 0.5),
      );
      expect(title.width, lessThanOrEqualTo(_titleBand(_phoneFrame.width) + 0.5));
      // …and the indicator ignores the scaler entirely, so at the accessibility
      expect(spinner.size, const Size(48, 48));
      expect(spinner.center.dx, moreOrLessEquals(view.center.dx, epsilon: 0.5));
    });

    testWidgets('the 320 dp floor at 200% is where the title band is tightest',
        (WidgetTester tester) async {
      await pumpPreview(tester, jeeberRequestDetailLoadingViewCompactLargeText);
      expect(tester.takeException(), isNull);

      final Rect view = tester.getRect(
        find.byType(JeeberRequestDetailLoadingView),
      );
      final Rect title = tester.getRect(find.text(_title));

      // 320 − 56 leading − 16 trailing − 16 either side of the title. This is
      expect(_titleBand(_compactFrame.width), 216.0);
      expect(
        _titleBand(_phoneFrame.width) - _titleBand(_compactFrame.width),
        70.0,
      );

      // The title is laid out into that band and stays in the toolbar. Whether
      expect(title.width, lessThanOrEqualTo(_titleBand(_compactFrame.width) + 0.5));
      expect(title.bottom, lessThan(view.top + kToolbarHeight));
      expect(find.text(_title), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
