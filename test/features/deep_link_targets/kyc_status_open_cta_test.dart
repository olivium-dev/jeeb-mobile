// LR-35: the stub is UNROUTED and had no exit — a dead end. R2 forbids
// deleting it, so it gains the one act that makes it truthful.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/deep_link_targets/kyc_status_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';
import '../../support/load_test_fonts.dart';

Widget _harness({Locale locale = const Locale('en'), double textScale = 1}) {
  final GoRouter router = GoRouter(
    initialLocation: '/deep-link/kyc',
    routes: <RouteBase>[
      GoRoute(
        path: '/deep-link/kyc',
        builder: (_, _) => const KycStatusScreen(),
      ),
      GoRoute(
        name: 'kyc-status',
        path: '/profile/kyc',
        builder: (_, _) => const Scaffold(body: Text('KYC_WIZARD')),
      ),
    ],
  );
  addTearDown(router.dispose);
  return MaterialApp.router(
    theme: AppTheme.midnight(),
    routerConfig: router,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: true,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
  );
}

void main() {
  setUpAll(loadCatalogCaptureFonts);
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    for (final width in <double>[320, 390, 393]) {
      testWidgets(
        'whole CTA readable and tappable at 200%: ${locale.languageCode} $width',
        (tester) async {
          useReduceMotion(tester);
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 568);
          addTearDown(tester.view.reset);
          await tester.pumpWidget(_harness(locale: locale, textScale: 2));
          await tester.pumpAndSettle();
          final cta = find.bySemanticsIdentifier(
            'deep_link_kyc_status_open_cta',
          );
          await tester.ensureVisible(cta);
          await tester.pumpAndSettle();
          final copy = AppLocalizations.of(
            tester.element(find.byType(KycStatusScreen)),
          );
          final label = find.text(copy.kycStatusOpenWizardCta);
          final paragraph = tester.renderObject<RenderParagraph>(label);
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: 'the complete localized action must remain readable',
          );
          final buttonRect = tester.getRect(cta);
          final textRect = tester.getRect(label);
          expect(textRect.left, greaterThanOrEqualTo(buttonRect.left));
          expect(textRect.right, lessThanOrEqualTo(buttonRect.right));
          expect(textRect.top, greaterThanOrEqualTo(buttonRect.top));
          expect(textRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
          expect(buttonRect.height, greaterThanOrEqualTo(56));
          expect(buttonRect.left, greaterThanOrEqualTo(0));
          expect(buttonRect.right, lessThanOrEqualTo(width));
          expect(tester.takeException(), isNull);
          await tester.tap(cta);
          await tester.pumpAndSettle();
          expect(find.text('KYC_WIZARD'), findsOneWidget);
        },
      );
    }
  }
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('${locale.languageCode} · the root id survives and the CTA is '
        'there', (tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(_harness(locale: locale));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('deep_link_kyc_status_root'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('deep_link_kyc_status_open_cta'),
        findsOneWidget,
      );
    });
  }

  testWidgets('the CTA lands on the real wizard', (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.bySemanticsIdentifier('deep_link_kyc_status_open_cta'),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsIdentifier('deep_link_kyc_status_open_cta'),
    );
    await tester.pumpAndSettle();

    expect(find.text('KYC_WIZARD'), findsOneWidget);
  });
}
