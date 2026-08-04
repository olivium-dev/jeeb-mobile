import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/formatting/friendly_reference.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart';

import '../../support/sync_app_localizations.dart';

void main() {
  const requestId = 'req-dead-001';

  // Reduce motion pins the E4 illustration's rest frame; without it the ∞ loop
  // never lets `pumpAndSettle` return.
  Widget harness({
    String id = requestId,
    Locale locale = const Locale('en'),
    void Function()? onBack,
  }) => wrapForTest(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: JeeberRequestUnavailableScreen(
          requestId: id,
          onBack: onBack ?? () {},
        ),
      ),
    ),
    locale: locale,
  );

  testWidgets(
      'renders the localized Jeeb empty state with the request reference and '
      'a "Browse other requests" CTA', (tester) async {
    var backCount = 0;
    await tester.pumpWidget(harness(onBack: () => backCount++));
    await tester.pumpAndSettle();

    // MIDNIGHT: the light-theme OMDS panel became the kit's empty family.
    expect(find.byType(JeebEmptyState), findsOneWidget);
    expect(find.byType(OmdsEmptyState), findsNothing);
    expect(
      find.byKey(const Key('jeeber-request-unavailable-state')),
      findsOneWidget,
    );
    // Localized copy from the ARBs (title + reference-bearing body).
    expect(find.text('Request no longer available'), findsOneWidget,
        reason: 'M3-39: the bar lost its title — the headline prints ONCE, in '
            'the empty block, the way E4 draws it');
    expect(
      find.text('Request ${friendlyReference(requestId)} is no longer '
          'available.'),
      findsOneWidget,
    );
    // The pre-fix hard-coded strings are gone.
    expect(find.text('Request unavailable'), findsNothing);
    expect(find.text('Back'), findsNothing);

    // Semantics id for QA targeting.
    expect(
      find.bySemanticsIdentifier('jeeber_request_unavailable'),
      findsOneWidget,
    );

    // Forward affordance: browse-other-requests CTA fires the onBack edge.
    final cta = find.byKey(const Key('jeeber-request-unavailable-back-cta'));
    expect(cta, findsOneWidget);
    expect(find.text('Browse other requests'), findsOneWidget);
    await tester.tap(cta);
    expect(backCount, 1);
  });

  testWidgets('renders RTL-correct Arabic copy under the ar locale',
      (tester) async {
    await tester.pumpWidget(harness(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('الطلب لم يعد متاحًا'), findsOneWidget);
    expect(find.text('تصفح الطلبات الأخرى'), findsOneWidget);
  });

  // ── MIDNIGHT M3-39 · empty block derived from E4; field stays R17's, the
  // anchor its own route twin measures ───────────────────────────────────────

  testWidgets('mounts the R17 field: content variant, orange glow top-start, '
      'no periwinkle wash, no motion', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final field = tester.widget<JeebMidnightField>(
      find.byType(JeebMidnightField),
    );
    expect(field.variant, JeebFieldVariant.content);
    expect(field.glowPlacement, JeebFieldGlowPlacement.topStart);
    expect(field.washPlacement, isNull,
        reason: 'R17 declares zero periwinkle — a wash here would mirror the '
            'layer the wave-C ruling separated');
    expect(field.animateDecor, isFalse);
  });

  // M3-39: the subject moved from E3 (a jeeber WAITING) to E4 at error status
  // — E4's caption is "Empty ≠ dead", and this route is the dead case.
  testWidgets('the empty subject is E4 at error status, the shared '
      '"unavailable" treatment', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final state = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
    expect(state.variant, JeebEmptyStateVariant.parcel);
    expect(state.status, JeebEmptyStateStatus.error);
  });

  testWidgets('a cold push tap on a raw UUID shows the short reference, not '
      'the 36-character route id', (tester) async {
    const uuid = 'e30b7f2e-7914-402d-8dd3-e699e6775eae';
    await tester.pumpWidget(harness(id: uuid));
    await tester.pumpAndSettle();

    expect(find.textContaining(uuid), findsNothing);
    expect(
      find.text('Request ${friendlyReference(uuid)} is no longer available.'),
      findsOneWidget,
    );
  });

  testWidgets('a blank route id degrades to the reference fallback, never an '
      'empty sentence', (tester) async {
    await tester.pumpWidget(harness(id: ''));
    await tester.pumpAndSettle();

    expect(find.text('Request ${friendlyReference('')} is no longer '
        'available.'), findsOneWidget);
  });
}
