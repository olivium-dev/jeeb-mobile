// Render tests for the RepliesCard previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/home_client/presentation/widgets/active_request_card.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/replies_card.dart';

import '../preview_test_harness.dart';

/// The request ids the previews seed, lower-cased into the card's widget keys
/// exactly the way `RepliesCard` builds them.
const String _figmaRowId = 'rep-1';
const String _zeroOfferRowId = 'rep-4';

/// Pumps a preview into a real 390 dp phone-width box at [textScale], the way
/// the canvas renders it, rather than into the 800×600 default test surface.
Future<void> _pumpInPreviewBox(
  WidgetTester tester,
  Widget Function() preview, {
  required double textScale,
  Size box = repliesCardBox,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = box;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'RepliesCard',
    const <String, Widget Function()>{
      'Nine offers · +6': repliesCardWithOverflowCount,
      'Single offer · no counter': repliesCardSingleOffer,
      'Counted, no avatars': repliesCardCountWithoutAvatars,
      'Zero offers · CTAs still shown': repliesCardZeroOffers,
      'No display id · echo guard': repliesCardTitleFallback,
      'Long content · +117': repliesCardLongContent,
    },
    expectedText: const <String, String>{
      'Nine offers · +6': '+6',
      'Single offer · no counter': 'ORD-23471',
      'Counted, no avatars': '+4',
      'Zero offers · CTAs still shown': 'ORD-23473',
      // findsOneWidget is the assertion here: the header renders this string,
      'No display id · echo guard': 'Pharmacy run for Mom',
      'Long content · +117': '+117',
    },
  );

  group('RepliesCard preview specifics', () {
    testWidgets('the "+N" cluster counts OFFERS, not avatars', (
      WidgetTester tester,
    ) async {
      // Nine offers, three inline avatars -> "+6", the Figma cluster. The card
      await pumpPreview(tester, repliesCardWithOverflowCount);

      expect(find.text('ORD-23470'), findsOneWidget);
      expect(find.text('+6'), findsOneWidget);
    });

    testWidgets('a single offer renders no counter at all', (
      WidgetTester tester,
    ) async {
      // `extra > 0` is what hides the counter; an off-by-one there would print
      await pumpPreview(tester, repliesCardSingleOffer);

      expect(find.text('+0'), findsNothing);
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('zero offers collapses the whole cluster', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, repliesCardZeroOffers);

      final SemanticsHandle handle = tester.ensureSemantics();
      expect(
        find.bySemanticsIdentifier(
          'orders_replies_avatar_stack_$_zeroOfferRowId',
        ),
        findsNothing,
      );
      handle.dispose();
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('the summary falls back to the destination, never an echo', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, repliesCardTitleFallback);

      expect(find.text('Pharmacy run for Mom'), findsOneWidget);
      expect(find.text('Mar Mikhael, Beirut'), findsOneWidget);
    });

    testWidgets('every preview reaches a visibly different header', (
      WidgetTester tester,
    ) async {
      // The failure this suite exists to catch: six previews of one widget that
      final Set<String> headers = <String>{};
      for (final Widget Function() preview in <Widget Function()>[
        repliesCardWithOverflowCount,
        repliesCardSingleOffer,
        repliesCardCountWithoutAvatars,
        repliesCardZeroOffers,
        repliesCardTitleFallback,
        repliesCardLongContent,
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpPreview(tester, preview);
        headers.add(tester.widget<Text>(find.byType(Text).first).data!);
      }

      expect(headers, hasLength(6));
    });

    testWidgets('no preview reaches the network for an avatar', (
      WidgetTester tester,
    ) async {
      // The previews pass empty avatar URLs so `OmdsProfileAvatar` short-
      await pumpPreview(tester, repliesCardWithOverflowCount);

      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('RepliesCard defects the preview matrix exposed', () {
    testWidgets('every offerer avatar is hardcoded to the letter "J"', (
      WidgetTester tester,
    ) async {
      // `_OfferAvatar` passes `initial: 'J'` — a literal, not the offerer's
      await pumpPreview(tester, repliesCardWithOverflowCount);

      expect(
        find.text('J'),
        findsNWidgets(3),
        reason: 'delete this expectation once the card takes real initials',
      );
    });

    testWidgets('the card renders no tier badge despite its class doc', (
      WidgetTester tester,
    ) async {
      // `RepliesCard`'s doc opens with "Layout: title + tier badge, …" and the
      await pumpPreview(tester, repliesCardWithOverflowCount);

      expect(find.byType(ClientHomeTierBadge), findsNothing);
    });

    testWidgets('200% TEXT: the CTA row overflows a phone-width card', (
      WidgetTester tester,
    ) async {
      // `_RepliesActions` is an end-aligned Row of two `IntrinsicWidth` pills
      await _pumpInPreviewBox(
        tester,
        repliesCardWithOverflowCount,
        textScale: 1.0,
        box: const Size(390, 2000),
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'at 100% the two CTAs fit inside 390 dp',
      );
      final double acceptAt1x = tester
          .getSize(find.byKey(const Key('replies-accept-$_figmaRowId')))
          .width;
      final double checkAt1x = tester
          .getSize(find.byKey(const Key('replies-check-offers-$_figmaRowId')))
          .width;

      await tester.pumpWidget(const SizedBox.shrink());
      // A tall box so the only axis that can overflow is the horizontal one.
      await _pumpInPreviewBox(
        tester,
        repliesCardWithOverflowCount,
        textScale: 2.0,
        box: const Size(390, 2000),
      );

      final Object? overflow = tester.takeException();
      expect(overflow, isFlutterError);
      expect(
        overflow.toString(),
        contains('overflowed'),
        reason: 'accept ${acceptAt1x.toStringAsFixed(1)} dp + check '
            '${checkAt1x.toStringAsFixed(1)} dp fit at 100%; at 200% the same '
            'row needs ~566 dp against ~358 dp of content width',
      );
      final RegExpMatch? clipped =
          RegExp(r'overflowed by ([\d.]+) pixels').firstMatch(
        overflow.toString(),
      );
      expect(clipped, isNotNull);
      expect(
        double.parse(clipped!.group(1)!),
        greaterThan(150),
        reason: 'clipped by ~208 dp. `MainAxisAlignment.end` puts the negative '
            'remaining space in FRONT of the row, and RenderFlex clips '
            'hard-edge, so `Accept` is scrolled off the LEADING edge entirely '
            '(left in EN, right in AR) and `Check Offers` is cut at the other '
            'end — the row has no reachable action left',
      );
    });

    testWidgets('200% TEXT: Arabic overflows too, just by less', (
      WidgetTester tester,
    ) async {
      // Shorter labels (قبول / عرض العروض) shrink the overflow but do not
      await _pumpInPreviewBox(
        tester,
        repliesCardWithOverflowCount,
        textScale: 2.0,
        box: const Size(390, 2000),
        locale: const Locale('ar'),
      );

      expect(tester.takeException(), isFlutterError);
    });
  });
}
