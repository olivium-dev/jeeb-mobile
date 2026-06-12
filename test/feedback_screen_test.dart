import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/rating/presentation/rating_screen.dart';
import 'package:jeeb_mobile/features/rating/presentation/widgets/feedback_avatar.dart';
import 'package:jeeb_mobile/features/rating/presentation/widgets/feedback_star_input.dart';

import 'support/sync_app_localizations.dart';

void main() {
  testWidgets('renders title, ratee name, avatar, stars and submit',
      (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        const RatingScreen(deliveryId: 'd-1', rateeName: 'Sami'),
      ),
    );
    await tester.pump();

    expect(find.text('We appreciate your feedback'), findsOneWidget);
    expect(find.text('Rate Sami'), findsOneWidget);
    expect(find.byKey(FeedbackAvatar.rootKey), findsOneWidget);
    expect(find.byKey(FeedbackStarInput.rootKey), findsOneWidget);
    expect(find.text('Submit feedback'), findsOneWidget);
  });

  testWidgets('client audience shows the delivery-man subtitle', (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        const RatingScreen(deliveryId: 'd-1', rateeName: 'Sami'),
      ),
    );
    await tester.pump();
    expect(
      find.textContaining('evaluate the delivery man'),
      findsOneWidget,
    );
  });

  testWidgets('jeeber audience shows the client subtitle', (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        const RatingScreen(
          deliveryId: 'd-1',
          isClient: false,
          rateeName: 'Lina',
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('evaluate the client'), findsOneWidget);
    expect(find.text('Rate Lina'), findsOneWidget);
  });

  testWidgets('selecting stars + submit pops with the rating payload',
      (tester) async {
    Map<String, Object?>? result;
    await tester.pumpWidget(
      wrapForTest(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<Map<String, Object?>>(
                MaterialPageRoute(
                  builder: (_) => const RatingScreen(
                    deliveryId: 'd-1',
                    rateeName: 'Sami',
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tap the 4th star (icons rendered left-to-right by OmdsStarRating). The
    // star row sits low in the scroll view, so bring it on-screen first.
    final stars = find.byIcon(Icons.star);
    await tester.ensureVisible(stars.at(3));
    await tester.pump();
    await tester.tap(stars.at(3));
    await tester.pump();
    await tester.tap(find.text('Submit feedback'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!['stars'], 4);
  });

  testWidgets('renders mirrored under Arabic locale', (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        const RatingScreen(deliveryId: 'd-1', rateeName: 'Sami'),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();

    final dir = Directionality.of(tester.element(find.byType(RatingScreen)));
    expect(dir, TextDirection.rtl);
    expect(find.text('نقدّر ملاحظاتك'), findsOneWidget);
    expect(find.text('إرسال الملاحظات'), findsOneWidget);
  });
}
