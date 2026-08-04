import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb_verified_badge.dart';
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

DeliveryManProfileViewData _data({
  List<DeliveryReviewData>? reviews,
  bool isVerified = true,
}) =>
    DeliveryManProfileViewData(
      name: 'Kamal Hajj',
      rating: 4.3,
      reviewCount: 113,
      location: 'Lebanon',
      isAvailable: true,
      isVerified: isVerified,
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
    // Midnight primitives loop ∞ (02-STUDY-NOTES M0-4): `pumpAndSettle` only
    // terminates under reduce motion.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
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
      // D58: cards attribute by first name only (the seed reviewer is "Karl
      expect(find.text('Karl'), findsNWidgets(2));
      expect(find.text('Karl Assaf'), findsNothing);
    });

    testWidgets(
        'E11 trust badge: renders JeebVerifiedBadge when the jeeber is '
        'verified (default)', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.byType(JeebVerifiedBadge), findsOneWidget);
    });

    testWidgets(
        'E11 trust badge: no JeebVerifiedBadge when isVerified is false',
        (tester) async {
      await tester.pumpWidget(_harness(data: _data(isVerified: false)));
      await tester.pumpAndSettle();

      expect(find.byType(JeebVerifiedBadge), findsNothing);
    });

    testWidgets('uses the localized verified-client reviewer label, not '
        'the Figma "Verified Technician"', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      expect(find.text('Verified Client'), findsNWidgets(2));
      expect(find.text('Verified Technician'), findsNothing);
    });

    testWidgets('renders the JeebEmptyState when there are no reviews',
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

    testWidgets(
        'exposes canonical Semantics identifiers (JM-067): root + close + '
        'view-all + score + cards', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      for (final id in const [
        'delivery_man_profile_screen_root',
        'profile_close',
        'profile_view_all_reviews',
        'profile_score', // shown: 113 reviews (>= 5, not cold-start)
        'delivery_man_profile_review_card_0',
        'delivery_man_profile_review_card_1',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      }
      handle.dispose();
    });

    testWidgets('D57: NO Helpful/Reply controls on review cards',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // The OmdsReviewCard action row (Helpful/Reply) is suppressed
      expect(find.byIcon(Icons.thumb_up_outlined), findsNothing);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
      expect(find.text('Helpful (24)'), findsNothing);
      expect(find.text('Reply'), findsNothing);
    });

    testWidgets('D58: reviewer attribution is FIRST NAME only', (tester) async {
      await tester.pumpWidget(
        _harness(
          data: _data(
            reviews: [
              const DeliveryReviewData(
                id: 'r1',
                reviewerName: 'Karl Assaf',
                rating: 4,
                body: 'Great delivery.',
                daysAgo: 2,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Karl'), findsOneWidget);
      expect(find.text('Karl Assaf'), findsNothing);
    });

    testWidgets('D59 cold-start: < 5 reviews hides the aggregate score',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(
          data: const DeliveryManProfileViewData(
            name: 'Kamal Hajj',
            rating: 4.8,
            reviewCount: 3,
            location: 'Lebanon',
            isAvailable: true,
            reviews: [
              DeliveryReviewData(
                id: 'r1',
                reviewerName: 'Karl Assaf',
                rating: 5,
                body: 'Fast.',
                daysAgo: 1,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Score row absent; the "4.8 . 3 Reviews" summary is NOT shown.
      expect(find.bySemanticsIdentifier('profile_score'), findsNothing);
      expect(find.text('4.8 . 3 Reviews'), findsNothing);
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
