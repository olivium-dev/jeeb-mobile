import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/dm_onboarding_screen_fixtures.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/dm_onboarding_screen.dart';

import '../../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../../support/midnight_test_harness.dart';

void main() {
  // Deliberately the ordinary smoke font, not a font substitution that could
  // conceal the original layout failure.
  for (final locale in kFailureLocales) {
    for (final width in <double>[320, 440]) {
      for (final scale in <double>[1, 2]) {
        for (final checking in <bool>[true, false]) {
          testWidgets('coverage ${checking ? 'checking' : 'failed'} fits '
              '${locale.languageCode} $width ${scale}x', (tester) async {
            useReduceMotion(tester);
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(width, 956);
            addTearDown(tester.view.reset);
            DmOnboardingCubit? cubit;
            addTearDown(() => cubit?.close());
            await tester.pumpWidget(
              wrapMidnight(
                Builder(
                  builder: (context) {
                    cubit ??= checking
                        ? DmOnboardingScreenPreviewFixtures.checkingCoverage()
                        : DmOnboardingScreenPreviewFixtures.coverageFailed();
                    return MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: DmOnboardingScreen(cubit: cubit),
                    );
                  },
                ),
                locale: locale,
                scrollable: false,
              ),
            );
            // The actual pending-coverage spinner never settles.
            await tester.pump(const Duration(milliseconds: 400));
            expect(tester.takeException(), isNull);
            final map = find.bySemanticsIdentifier('service_area_map_pin');
            await tester.ensureVisible(map);
            await tester.pump();
            final label = find.descendant(
              of: map,
              matching: find.text(
                DmOnboardingScreenPreviewFixtures.geocodedBase.label,
              ),
            );
            expect(label, findsOneWidget);
            final paragraph = tester.renderObject<RenderParagraph>(label);
            expect(paragraph.didExceedMaxLines, isFalse);
            final mapRect = tester.getRect(map);
            final labelRect = tester.getRect(label);
            expect(labelRect.left, greaterThanOrEqualTo(mapRect.left));
            expect(labelRect.right, lessThanOrEqualTo(mapRect.right));
            expect(labelRect.top, greaterThanOrEqualTo(mapRect.top));
            expect(labelRect.bottom, lessThanOrEqualTo(mapRect.bottom));
            final row = find.bySemanticsIdentifier(
              'service_area_select_location',
            );
            await tester.ensureVisible(row);
            await tester.pump();
            expect(tester.getRect(row).left, greaterThanOrEqualTo(0));
            expect(tester.getRect(row).right, lessThanOrEqualTo(width));
            final button = tester.widget<JeebCtaButton>(
              find.byType(JeebCtaButton),
            );
            expect(button.isLoading, checking);
            expect(button.isEnabled, !checking);
            expect(cubit!.state.hasHomeBase, isTrue);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}
