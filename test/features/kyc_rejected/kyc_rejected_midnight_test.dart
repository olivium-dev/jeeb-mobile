// M3-21 · kyc-rejected derived from R23 "Become a Jeeber" — per-element
// MIDNIGHT assertions.
//
// Goldens tolerate 5% pixel diff, so a headline re-inked from `onSurface` to
// `primary` (which IS #D73B00 on Midnight) moves far too few pixels to fail
// one. Everything here reads the colour/variant off the widget instead.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/kyc_rejected_screen_fixtures.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc_rejected/presentation/kyc_rejected_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Carries the two named routes the screen's edges target so `goNamed` resolves.
Widget _harness(KycGateway gateway, {Locale? locale, double textScale = 1}) {
  final GoRouter router = GoRouter(
    initialLocation: '/kyc/rejected',
    routes: <RouteBase>[
      GoRoute(
        path: '/kyc/rejected',
        builder: (_, _) => KycRejectedScreen(gateway: gateway),
      ),
      GoRoute(
        name: 'support-ticket',
        path: '/support',
        builder: (_, _) => const Scaffold(body: Text('SUPPORT')),
      ),
      GoRoute(
        name: 'customer-profile',
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('PROFILE')),
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
    // The E3 scene loops ∞ by design (02-STUDY-NOTES §Motion), so the tree only
    // settles under reduce motion.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: true,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
  );
}

Future<void> _pump(WidgetTester tester, KycGateway gateway) async {
  await tester.pumpWidget(_harness(gateway));
  await tester.pump();
  await tester.pump();
}

void main() {
  final JeebSemanticColors midnight = JeebSemanticColors.midnight();

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    // The board canvas — the E3 scene is 300 wide and the block gutters 36.
    view.physicalSize = const Size(440, 956);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  ColorScheme schemeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(JeebMidnightField))).colorScheme;

  group('M3-21 field — R23s measured anchor', () {
    testWidgets(
        'mounts one still CONTENT field with the ORANGE glow at the top end '
        'and declares no periwinkle wash', (tester) async {
      await _pump(tester, KycRejectedScreenFixtures.idUnreadable());

      final Finder finder = find.byType(JeebMidnightField);
      expect(finder, findsOneWidget, reason: 'one field, not one per phase');
      final JeebMidnightField field = tester.widget<JeebMidnightField>(finder);

      expect(field.variant, JeebFieldVariant.content);
      expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
      // A wash here would paint a periwinkle bloom R23's fit says is absent.
      expect(field.washPlacement, isNull);
      // M3 standing ruling: no motion beyond what kit widgets animate.
      expect(field.animateDecor, isFalse);
    });

    testWidgets('the Scaffold is transparent so the field is what paints',
        (tester) async {
      await _pump(tester, KycRejectedScreenFixtures.idUnreadable());

      final Scaffold scaffold =
          tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, Colors.transparent);
      expect(scaffold.appBar, isNull, reason: 'the header is an in-body row');
    });
  });

  group('M3-21 the decision block', () {
    testWidgets('is the empty familys ERROR form on E3s parked scooter',
        (tester) async {
      await _pump(tester, KycRejectedScreenFixtures.idUnreadable());

      final JeebEmptyState block =
          tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(block.status, JeebEmptyStateStatus.error);
      expect(block.status, isNot(JeebEmptyStateStatus.empty));
      expect(block.variant, JeebEmptyStateVariant.street);
      expect(block.compact, isFalse, reason: 'the block owns the screen');
    });

    testWidgets('headline reads onSurface and body reads the muted rung',
        (tester) async {
      await _pump(tester, KycRejectedScreenFixtures.idUnreadable());
      final ColorScheme scheme = schemeOf(tester);
      final AppLocalizations l10n =
          AppLocalizations.of(tester.element(find.byType(JeebEmptyState)));

      final Text headline = tester.widget<Text>(find.text(l10n.kycRejectedHeadline));
      expect(headline.style!.color, scheme.onSurface);

      final Text body = tester.widget<Text>(find.text(l10n.kycRejectedBody));
      expect(body.style!.color, midnight.mutedText);
    });

    testWidgets(
        'ORANGE-BUDGET GUARD: not one Text on this screen is inked '
        'colorScheme.primary — which IS #D73B00 under Midnight', (tester) async {
      await _pump(tester, KycRejectedScreenFixtures.idUnreadable());
      final ColorScheme scheme = schemeOf(tester);

      for (final Text text in tester.widgetList<Text>(find.byType(Text))) {
        expect(
          text.style?.color,
          isNot(scheme.primary),
          reason: 'pass-1 inked the headline primary when primary was navy',
        );
      }
    });
  });

  group('M3-21 the structured cause', () {
    testWidgets('is danger-SOFT on its container, never full-strength error',
        (tester) async {
      await _pump(tester, KycRejectedScreenFixtures.expired());
      final ColorScheme scheme = schemeOf(tester);
      final AppLocalizations l10n =
          AppLocalizations.of(tester.element(find.byType(JeebInfoNote)));

      final JeebInfoNote note =
          tester.widget<JeebInfoNote>(find.byType(JeebInfoNote));
      expect(note.tone, JeebInfoNoteTone.error);

      final Text cause =
          tester.widget<Text>(find.text(l10n.kycRejectionReasonExpired));
      // R22: destructive/negative COPY is #FF7B7B, not the #FF5252 solid.
      expect(cause.style!.color, scheme.onErrorContainer);
      expect(cause.style!.color, isNot(scheme.error));

      final DecoratedBox fill = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(JeebInfoNote),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (fill.decoration as BoxDecoration).color,
        scheme.errorContainer,
      );
    });

    testWidgets('keeps its frozen id', (tester) async {
      await _pump(tester, KycRejectedScreenFixtures.expired());
      expect(find.bySemanticsIdentifier('kyc_rejected_reason'), findsOneWidget);
    });
  });

  group('M3-21 the two exits', () {
    testWidgets(
        'the appeal pill is PERIWINKLE — R23 spends its one orange pill on the '
        'forward act and this screen closes the funnel', (tester) async {
      await _pump(tester, KycRejectedScreenFixtures.idUnreadable());

      final JeebCtaButton appeal = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('kyc_rejected_appeal_cta'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      expect(appeal.variant, JeebCtaVariant.primary);
      expect(appeal.variant, isNot(JeebCtaVariant.accent));

      final JeebCtaButton back = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('kyc_rejected_back_cta'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      expect(back.variant, JeebCtaVariant.text);
    });
  });

  group('M3-21 every phase of the cause enrichment', () {
    /// The decision and both exits are the primary content: they never wait on
    /// `GET /v1/kyc/status`, and no phase substitutes a skeleton for them.
    Future<void> expectFrameComplete(WidgetTester tester) async {
      expect(find.byType(JeebEmptyState), findsOneWidget);
      expect(
        tester.widget<JeebEmptyState>(find.byType(JeebEmptyState)).status,
        JeebEmptyStateStatus.error,
      );
      expect(
        find.bySemanticsIdentifier('kyc_rejected_appeal_cta'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('kyc_rejected_back_cta'),
        findsOneWidget,
      );
      expect(find.byType(JeebInfoNote), findsNothing);
    }

    testWidgets('no structured reason — the FINAL copy stands alone',
        (tester) async {
      await _pump(tester, KycRejectedScreenFixtures.rejectedWithoutReason());
      await expectFrameComplete(tester);
    });

    testWidgets('the status read failed', (tester) async {
      await _pump(tester, KycRejectedScreenFixtures.failing());
      await expectFrameComplete(tester);
    });

    testWidgets('the status read is still in flight', (tester) async {
      await _pump(tester, KycRejectedScreenFixtures.pending());
      await expectFrameComplete(tester);
    });

    testWidgets('D52 holds in every phase: no resubmit affordance',
        (tester) async {
      await _pump(tester, KycRejectedScreenFixtures.failing());
      expect(
        find.bySemanticsIdentifier('kyc_rejected_resubmit_cta'),
        findsNothing,
      );
    });
  });

  group('M3-21 gutters', () {
    testWidgets('runs the token sheets 24px screen gutter, directionally',
        (tester) async {
      await _pump(tester, KycRejectedScreenFixtures.idUnreadable());

      final ListView list = tester.widget<ListView>(find.byType(ListView));
      final EdgeInsetsDirectional pad =
          list.padding! as EdgeInsetsDirectional;
      expect(pad.start, 24);
      expect(pad.end, 24);
    });

    testWidgets('lays out under Arabic at 200% on the smallest canvas',
        (tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      final view = binding.platformDispatcher.views.first;
      view.physicalSize = const Size(320, 480);
      view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        _harness(
          KycRejectedScreenFixtures.idUnreadable(),
          locale: const Locale('ar'),
          textScale: 2,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(tester.element(find.byType(JeebMidnightField))),
        TextDirection.rtl,
      );
    });
  });
}
