import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/domain/delivery_man_profile_view_data.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/presentation/delivery_man_profile_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) =>
      _arbByTag.containsKey(locale.languageCode);

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

DeliveryReviewData _review(String id) => DeliveryReviewData(
      id: id,
      reviewerName: 'Karl Assaf',
      rating: 4,
      body: 'Great delivery, fast and friendly.',
      daysAgo: 2,
      helpfulCount: 24,
    );

DeliveryManProfileViewData _data({List<DeliveryReviewData>? reviews}) =>
    DeliveryManProfileViewData(
      name: 'Kamal Hajj',
      rating: 4.3,
      reviewCount: 113,
      location: 'Lebanon',
      isAvailable: true,
      reviews: reviews ?? [_review('r1'), _review('r2')],
    );

Widget _harness({
  DeliveryManProfileViewData? data,
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
    home: DeliveryManProfileScreen(data: data ?? _data()),
  );
}

void main() {
  setUpAll(_loadArbs);

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

  group('DeliveryManProfileScreen', () {
    testWidgets('renders identity header + reviews section (EN)',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('Kamal Hajj'), findsOneWidget);
      expect(find.text('4.3 . 113 Reviews'), findsOneWidget);
      expect(find.text('Lebanon . Available'), findsOneWidget);
      expect(find.text('Reviews'), findsOneWidget);
      expect(find.text('113 Reviews'), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);
      expect(find.text('Karl Assaf'), findsNWidgets(2));
    });

    testWidgets('uses the localized verified-client reviewer label, not '
        'the Figma "Verified Technician"', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      expect(find.text('Verified Client'), findsNWidgets(2));
      expect(find.text('Verified Technician'), findsNothing);
    });

    testWidgets('renders the OmdsEmptyState when there are no reviews',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          data: const DeliveryManProfileViewData(
            name: 'Kamal Hajj',
            rating: 0,
            reviewCount: 0,
            location: 'Lebanon',
            isAvailable: false,
            reviews: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No reviews yet'), findsOneWidget);
      expect(find.text('Lebanon . Unavailable'), findsOneWidget);
    });

    testWidgets('exposes Semantics identifiers on close + view-all + cards',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      for (final id in const [
        'delivery_man_profile_close',
        'delivery_man_profile_view_all_reviews',
        'delivery_man_profile_review_card_0',
        'delivery_man_profile_review_card_1',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      }
      handle.dispose();
    });

    testWidgets('renders mirrored Arabic strings under ar locale',
        (tester) async {
      await tester.pumpWidget(_harness(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('التقييمات'), findsOneWidget);
      expect(find.text('عرض الكل'), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.byKey(DeliveryManProfileScreen.rootKey)),
        ),
        TextDirection.rtl,
      );
    });
  });
}
