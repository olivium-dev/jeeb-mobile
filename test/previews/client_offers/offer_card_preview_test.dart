// Render tests for the OfferCard previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`, with one documented exception: the
// in-flight preview cannot go through `testPreviewsRender`, because its
// `OmdsButtonLoading` spinner is an indefinite animation and `pumpAndSettle`
// never returns. It gets its own pump-once group below, pinning the same kind
// of state-specific content in both locales.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_card.dart';

import '../preview_test_harness.dart';

/// Pumps a preview WITHOUT settling — for states that hold a running animation.
///
/// The preview canvas's ARB delegate resolves asynchronously, so the first
/// frame builds an empty `Localizations`; the extra pumps let the load land and
/// the card build. `pumpAndSettle` is deliberately not used.
Future<void> _pumpUnsettled(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(previewCanvas(preview, locale));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Accept in flight` (see the group at the bottom).
  testPreviewsRender(
    'OfferCard',
    const <String, Widget Function()>{
      'Rated jeeber': offerCardRated,
      'New jeeber, no ratings': offerCardNoRatings,
      'UUID name suppressed': offerCardIdentitySuppressed,
      'Accept locked (rival winning)': offerCardAcceptLocked,
      'Long name, note, LBP ceiling': offerCardLongContent,
    },
    expectedText: const <String, String>{
      'Rated jeeber': 'Hadi',
      'New jeeber, no ratings': 'No ratings yet',
      'UUID name suppressed': 'New Jeeber',
      'Accept locked (rival winning)': 'Nour Haddad',
      // The fee pill carries the whole MoneyFormat token, LTR-isolated
      // (JEBV4-98/F10). The cash-on-delivery line embeds the same amount in a
      // different sentence, so this string still resolves to exactly one node.
      'Long name, note, LBP ceiling': '\u{2066}LBP 1,234,567,890.99\u{2069}',
    },
  );

  group('OfferCard preview specifics', () {
    testWidgets('the UUID name never reaches the card (SW-08)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerCardIdentitySuppressed);

      expect(find.textContaining('9acb579d'), findsNothing);
      expect(find.text('New Jeeber'), findsOneWidget);
      // The avatar initial comes from the RESOLVED name, never from the raw id.
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is OmdsProfileAvatar && w.initial == 'N',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is OmdsProfileAvatar && w.initial == '9',
        ),
        findsNothing,
      );
    });

    testWidgets('an unrated jeeber gets no stars and no fabricated score', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerCardNoRatings);

      expect(find.bySemanticsIdentifier('offer_card_no_ratings'),
          findsOneWidget);
      expect(find.byType(OmdsStarRatingDisplay), findsNothing);
      expect(find.text('(0)'), findsNothing);
      expect(find.text('0.0'), findsNothing);
    });

    testWidgets('the rated preview DOES show stars — the two are distinct', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerCardRated);

      expect(find.byType(OmdsStarRatingDisplay), findsOneWidget);
      expect(find.text('(132)'), findsOneWidget);
      expect(find.text('No ratings yet'), findsNothing);
    });

    testWidgets('the locked CTA is really locked, and the armed one is not', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerCardAcceptLocked);
      expect(
        tester.widget<OmdsPrimaryButton>(find.byType(OmdsPrimaryButton))
            .isEnabled,
        isFalse,
        reason: 'acceptDisabled must reach OmdsPrimaryButton.isEnabled, or the '
            'dead pill looks identical to a live one.',
      );

      await pumpPreview(tester, offerCardRated);
      expect(
        tester.widget<OmdsPrimaryButton>(find.byType(OmdsPrimaryButton))
            .isEnabled,
        isTrue,
      );
    });

    testWidgets('the note renders only where a note exists', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerCardLongContent);
      expect(find.bySemanticsIdentifier('offer_card_0_note'), findsOneWidget);

      await pumpPreview(tester, offerCardRated);
      expect(find.bySemanticsIdentifier('offer_card_0_note'), findsNothing);
    });
  });

  // `Accept in flight` — the state `testPreviewsRender` cannot host, covered to
  // the same standard: builds in both locales, and pins its own content.
  group('OfferCard in-flight preview (never settles)', () {
    testWidgets('renders its own state · en', (WidgetTester tester) async {
      await _pumpUnsettled(tester, offerCardAccepting);

      expect(tester.takeException(), isNull);
      expect(find.text('Accepting…'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(find.byType(OmdsButtonLoading), findsOneWidget);
      expect(
        tester.widget<OmdsPrimaryButton>(find.byType(OmdsPrimaryButton))
            .isEnabled,
        isFalse,
      );
    });

    testWidgets('renders its own state · ar', (WidgetTester tester) async {
      await _pumpUnsettled(tester, offerCardAccepting,
          locale: const Locale('ar'));

      expect(tester.takeException(), isNull);
      expect(find.text('جاري القبول…'), findsOneWidget);
      expect(find.byType(OmdsButtonLoading), findsOneWidget);
    });
  });
}
