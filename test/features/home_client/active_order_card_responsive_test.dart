import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/active_request_card.dart';

import '../../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../../support/load_test_fonts.dart';

void main() {
  setUpAll(loadCatalogCaptureFonts);

  for (final locale in kFailureLocales) {
    for (final width in <double>[320, 440]) {
      for (final scale in <double>[1, 2]) {
        testWidgets('active actions fit and work: ${locale.languageCode} '
            '$width px, ${scale}x text', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 1000);
          addTearDown(tester.view.reset);
          var chatTaps = 0;
          var trackTaps = 0;
          await tester.pumpWidget(
            wrapMidnight(
              MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: ActiveOrderCard(
                  request: const ClientHomeRequest(
                    id: 'responsive',
                    title: 'Pharmacy run',
                    status: ClientRequestStatus.enRoute,
                    destinationLabel: 'Achrafieh',
                  ),
                  onTap: () => trackTaps++,
                  onOpenChat: () => chatTaps++,
                ),
              ),
              locale: locale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final chat = find.byKey(const Key('active-open-chat-responsive'));
          final track = find.byKey(const Key('active-track-order-responsive'));
          final card = tester.getRect(find.byType(ActiveOrderCard));
          final chatRect = tester.getRect(chat);
          final trackRect = tester.getRect(track);
          for (final button in <Rect>[chatRect, trackRect]) {
            expect(button.left, greaterThanOrEqualTo(card.left));
            expect(button.right, lessThanOrEqualTo(card.right));
            expect(button.top, greaterThanOrEqualTo(card.top));
            expect(button.bottom, lessThanOrEqualTo(card.bottom));
            expect(button.height, greaterThanOrEqualTo(48));
          }
          expect(chatRect.overlaps(trackRect), isFalse);
          if (width == 440 && scale == 1) {
            expect(
              chatRect.center.dy,
              trackRect.center.dy,
              reason: 'roomy cards retain the existing horizontal layout',
            );
          }
          if (width == 320 && scale == 2) {
            expect(
              chatRect.bottom,
              lessThan(trackRect.top),
              reason: 'constrained cards stack instead of clipping actions',
            );
          }
          await tester.tap(chat);
          await tester.tap(track);
          expect(chatTaps, 1);
          expect(trackTaps, 1);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
