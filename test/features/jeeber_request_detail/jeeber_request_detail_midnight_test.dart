// MIDNIGHT M3-06 — the jeeber request detail has no tile of its own. Every
// assertion below is traced to R17 (nearest tile: page shape, field, CTA) or to
// R16's feed card (the request-content ink ranking), never to taste.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_section_label.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/feed_request.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Token sheet §1/§3, spelled out rather than read off the implementation.
const Color _orange = Color(0xFFD73B00);
const Color _periwinkle = Color(0xFF8A93D8);
const Color _ink = Color(0xFFEDEFFC);

const FeedRequest _request = FeedRequest(
  id: 'REQ-001',
  shortLabel: 'Hamra, Beirut',
  description: '2 shawarma + cola from Barbar, extra garlic, no pickles',
);

void main() {
  Widget harness({Locale locale = const Locale('en')}) => MaterialApp(
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: JeeberRequestDetailScreen(
      request: _request,
      reportService: const ProhibitedItemReportService(),
      onDeclined: (_) {},
    ),
  );

  BoxDecoration decorationOf(WidgetTester tester, Finder button) =>
      tester.widget<DecoratedBox>(
            find.descendant(of: button, matching: find.byType(DecoratedBox)).first,
          ).decoration
          as BoxDecoration;

  Finder ctaFor(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(JeebCtaButton));

  group('field (R17)', () {
    testWidgets('content variant, orange glow top-start, zero periwinkle wash',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      final field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      expect(field.variant, JeebFieldVariant.content);
      expect(
        field.glowPlacement,
        JeebFieldGlowPlacement.topStart,
        reason: 'R17 measures (0.12, -0.08); the null default is topEnd — the '
            'MIRRORED anchor several screens shipped by accident',
      );
      expect(
        field.washPlacement,
        isNull,
        reason: 'wave-C: R4/R9/R17 draw an orange glow and declare no '
            'periwinkle; a wash here paints the wrong layer',
      );
    });

    testWidgets('renders its rest frame — M3 earns no motion', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<JeebMidnightField>(find.byType(JeebMidnightField))
            .animateDecor,
        isFalse,
      );
    });

    testWidgets('the field paints the page, not the Scaffold', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.transparent,
      );
    });
  });

  group('docked footer (R16 tpl 943 / R17 tpl 1031)', () {
    testWidgets('make-offer is the ORANGE h58 pill with the ctaOrange lift',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      final cta = ctaFor('Make offer');
      expect(cta, findsOneWidget);
      final decoration = decorationOf(tester, cta);

      expect(
        decoration.color,
        _orange,
        reason: 'both neighbours draw THIS act orange; the periwinkle '
            '`primary` default would paint $_periwinkle',
      );
      expect(decoration.boxShadow, JeebShadows.ctaOrange);
      expect(
        tester.getSize(cta).height,
        JeebCtaButton.primaryHeightTall,
        reason: 'R17 docks its pill at h58',
      );
      expect(
        find.bySemanticsIdentifier('jeeber-request-detail-make-offer'),
        findsOneWidget,
      );
    });

    testWidgets('decline is the secondary WORD — no pill, no fill, never red',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      final scheme = AppTheme.midnight().colorScheme;
      final decoration = decorationOf(tester, ctaFor('Decline request'));
      expect(
        decoration.color,
        isNull,
        reason: 'R4/R16: declining is a word, not a second pill',
      );
      expect(decoration.border, isNull);

      final label = tester.widget<Text>(find.text('Decline request'));
      expect(label.style!.color, scheme.onSurfaceVariant);
      expect(label.style!.color, isNot(scheme.error));
      expect(label.style!.color, isNot(_orange));
      expect(
        find.bySemanticsIdentifier('jeeber-request-detail-decline'),
        findsOneWidget,
      );
    });
  });

  group('summary card (R16 ranking)', () {
    testWidgets('the request content is the card HEADLINE — cardTitle 15.5 '
        'w700 on onSurface, un-truncated', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      final headline = tester.widget<Text>(find.text(_request.description!));
      expect(headline.style!.fontSize, 15.5);
      expect(headline.style!.fontWeight, FontWeight.w700);
      expect(headline.style!.color, _ink);
      expect(headline.maxLines, isNull);
    });

    testWidgets('the field name is the muted qualifier BENEATH the content',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      final qualifier = tester.widget<Text>(
        find.text('What the client says'),
      );
      expect(qualifier.style!.color, _periwinkle);
      expect(
        qualifier.style!.fontSize,
        lessThan(15.5),
        reason: 'the qualifier never outranks the fact it qualifies',
      );
      expect(
        tester.getTopLeft(find.text('What the client says')).dy,
        greaterThan(tester.getTopLeft(find.text(_request.description!)).dy),
      );
    });

    testWidgets('no glyph column inside the card — neither R16 nor R17 draws '
        'one', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('jeeber-request-detail-summary')),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
    });

    testWidgets('the section label rides the sectionLabel token ink',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.byType(JeebSectionLabel), findsOneWidget);
      final label = tester.widget<Text>(
        find.descendant(
          of: find.byType(JeebSectionLabel),
          matching: find.byType(Text),
        ),
      );
      expect(label.style!.color, _periwinkle);
    });
  });

  testWidgets('mirrors under RTL without overflow', (tester) async {
    await tester.pumpWidget(harness(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_request.description!), findsOneWidget);
  });
}
