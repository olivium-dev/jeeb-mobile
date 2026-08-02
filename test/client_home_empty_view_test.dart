import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
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

      expect(find.text('What do you need?'), findsOneWidget);
      expect(
        find.text('No pending requests — broadcast a new one to get offers.'),
        findsOneWidget,
      );
      expect(find.text('Create your first request'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty_rounded), findsNothing);
    });

    testWidgets('renders the hero illustration asset', (tester) async {
      await tester.pumpWidget(_harness(onNewOrder: () {}));
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect(
        (image.image as AssetImage).assetName,
        'assets/illustrations/empty_orders.png',
      );
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

      expect(find.text('ماذا تحتاج؟'), findsOneWidget);
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
