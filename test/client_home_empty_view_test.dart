import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/client_home_empty_view.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/client_home_motion.dart';
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
    testWidgets('renders localized pending copy and first-request CTA (EN)', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(onNewOrder: () {}));
      await tester.pumpAndSettle();

      // The title moved to the mic hero above this view (redesign-2026-08
      // screen 04) — printing "What do you need?" twice on one screen was the
      // duplication the redesign removes, so its absence is the assertion.
      expect(find.text('What do you need?'), findsNothing);
      expect(
        find.text('No pending requests — broadcast a new one to get offers.'),
        findsOneWidget,
      );
      expect(find.text('Create your first request'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty_rounded), findsNothing);
    });

    testWidgets('renders the empty-say-it motion mark', (tester) async {
      await tester.pumpWidget(_harness(onNewOrder: () {}));
      await tester.pumpAndSettle();

      // redesign-2026-08 motion spec §2.6: the client empty state's mark is the
      // mic (`empty-say-it.json`), not the pre-redesign `empty_orders.png` shop
      // illustration — the empty state and the hero above it now say one thing.
      expect(find.byType(ClientHomeEmptyMark), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      final lottie = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      expect(lottie.lottie, isA<AssetLottie>());
      expect(
        (lottie.lottie as AssetLottie).assetName,
        'assets/animations/empty-say-it.json',
      );
      // One-shot by contract: an empty list is a still state.
      expect(lottie.repeat, isFalse);
    });

    testWidgets('reduce motion parks the mark on its settled final frame', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _harness(onNewOrder: () {}),
        ),
      );
      await tester.pumpAndSettle();

      final lottie = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      // `empty-say-it` frame 0 is BLANK (pre-entrance), so parking at 0 would
      // leave an empty box; progress 1.0 is the settled navy mic.
      expect(lottie.animate, isFalse);
      expect(lottie.controller, same(kAlwaysCompleteAnimation));
      expect(lottie.controller!.value, 1.0);
    });

    testWidgets('exposes Semantics identifiers on root and CTA', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(onNewOrder: () {}));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('_request_empty_state_root'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('_request_empty_state_new_order_button'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('tapping the CTA invokes onNewOrder', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_harness(onNewOrder: () => taps++));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create your first request'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('renders mirrored Arabic strings under ar locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(onNewOrder: () {}, locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('ماذا تحتاج؟'), findsNothing);
      expect(
        find.text('لا توجد طلبات معلّقة — أنشئ طلبًا جديدًا لتلقّي العروض.'),
        findsOneWidget,
      );
      expect(find.text('أنشئ أول طلب لك'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(ClientHomeEmptyView))),
        TextDirection.rtl,
      );
    });
  });
}
