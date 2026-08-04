import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/client_home_empty_view.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// Synchronous ARB-backed localizations delegate so widget tests render the
/// real strings without hitting the asset bundle.
class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;

void _loadArbs() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncDelegate({'en': en, 'ar': ar});
}

Widget _harness({
  VoidCallback? onNewOrder,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // E1's illustration loops ∞ (02-STUDY-NOTES M0-4): `pumpAndSettle` only
    // terminates under reduce motion, which is also the capture rest frame.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(body: ClientHomeEmptyView(onNewOrder: onNewOrder)),
  );
}

void main() {
  setUpAll(_loadArbs);

  // Pin a realistic phone window so the list-empty content is exercised at a
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(440 * 3, 956 * 3);
    view.devicePixelRatio = 3.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('ClientHomeEmptyView', () {
    testWidgets('renders the E1 headline and body (EN)', (tester) async {
      await tester.pumpWidget(_harness(onNewOrder: () {}));
      await tester.pumpAndSettle();

      // MIDNIGHT E1 draws the headline INSIDE the empty block; the screen drops
      // its own prompt in this composition, so it is still printed once.
      expect(find.text('What do you need?'), findsOneWidget);
      expect(
        find.text(
          'No pending requests — say it, and offers from nearby Jeebers '
          'arrive in minutes.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.hourglass_empty_rounded), findsNothing);
    });

    testWidgets('draws the composed kit illustration, not a Lottie or PNG', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(onNewOrder: () {}));
      await tester.pumpAndSettle();

      expect(find.byType(JeebEmptyState), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      final state = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(state.variant, JeebEmptyStateVariant.e1);
      expect(state.status, JeebEmptyStateStatus.empty);
    });

    testWidgets('the board draws no CTA button in this block', (tester) async {
      // doc-13 Pattern D: `_request_empty_state_new_order_button` moved onto
      // the screen's voice capsule, which is E1's own create affordance.
      await tester.pumpWidget(_harness(onNewOrder: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Create your first request'), findsNothing);
      expect(
        find.bySemanticsIdentifier('_request_empty_state_new_order_button'),
        findsNothing,
      );
    });

    testWidgets('exposes the frozen root Semantics identifier', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(onNewOrder: () {}));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('_request_empty_state_root'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('renders mirrored Arabic strings under ar locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(onNewOrder: () {}, locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('ماذا تحتاج؟'), findsOneWidget);
      expect(
        find.text(
          'لا توجد طلبات معلّقة — قلها، وستصلك عروض من جيبرز قريبين خلال دقائق.',
        ),
        findsOneWidget,
      );
      expect(
        Directionality.of(tester.element(find.byType(ClientHomeEmptyView))),
        TextDirection.rtl,
      );
    });
  });
}
