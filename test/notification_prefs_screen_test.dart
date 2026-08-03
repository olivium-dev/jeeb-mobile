// JM-058 — Notification Preferences (blueprint `notification-prefs`).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'package:jeeb_mobile/features/notification_prefs/application/notification_prefs_cubit.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_model.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_repository.dart';
import 'package:jeeb_mobile/features/notification_prefs/presentation/notification_prefs_screen.dart';

class _FakePrefsRepo implements NotificationPrefsRepository {
  NotificationCategoryPrefs? lastSaved;

  @override
  Future<NotificationPrefs> fetch() async => const NotificationPrefs();

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) async {
    lastSaved = categories;
    return NotificationPrefs(categories: categories);
  }
}

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

Widget _harness(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

Future<_FakePrefsRepo> _pumpLoaded(WidgetTester tester) async {
  final repo = _FakePrefsRepo();
  final cubit = NotificationPrefsCubit(
    repository: repo,
    debounce: const Duration(milliseconds: 10),
  );
  addTearDown(cubit.close);
  await tester.pumpWidget(
    _harness(
      BlocProvider<NotificationPrefsCubit>.value(
        value: cubit,
        child: const NotificationPrefsScreen(),
      ),
    ),
  );
  // initState → load() → loaded; pump twice to flush the async emit.
  await tester.pump();
  await tester.pump();
  return repo;
}

void main() {
  setUpAll(_loadArbs);

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  group('JM-058 NotificationPrefsScreen — exact Semantics identifiers', () {
    testWidgets('surfaces root, push-only note, and back', (tester) async {
      await _pumpLoaded(tester);
      for (final id in [
        'notif_prefs_root',
        'notif_prefs_push_only_note',
        'notif_prefs_back',
      ]) {
        expect(
          find.bySemanticsIdentifier(id),
          findsOneWidget,
          reason: '$id must be addressable (JM-058 AC).',
        );
      }
    });

    testWidgets(
      'surfaces the four D64 category toggles + the locked transactional row',
      (tester) async {
        await _pumpLoaded(tester);
        for (final id in [
          'notif_prefs_offers_toggle',
          'notif_prefs_order_status_toggle',
          'notif_prefs_wallet_toggle',
          'notif_prefs_marketing_toggle',
          // The locked always-on transactional row (D64). Coined id per
          'notif_prefs_transactional_lock_icon',
        ]) {
          expect(
            find.bySemanticsIdentifier(id),
            findsOneWidget,
            reason: '$id must be addressable (JM-058 AC).',
          );
        }
      },
    );

    testWidgets(
      'wallet + rating-reminders rows use dedicated subtitles (F9)',
      (tester) async {
        await _pumpLoaded(tester);

        // Wallet row: dedicated wallet-notification subtitle, not the
        expect(
          find.text('Top-ups, refunds, and balance updates'),
          findsOneWidget,
        );

        // Rating-reminders row: dedicated rating copy, not the offers copy.
        expect(
          find.text('Reminders to rate completed deliveries'),
          findsOneWidget,
        );

        // The offers subtitle must now appear exactly once (the offers row
        expect(find.text('Discounts and seasonal promotions'), findsOneWidget);
      },
    );

    testWidgets('toggling a category drives a debounced PUT', (tester) async {
      final repo = await _pumpLoaded(tester);

      // Marketing defaults OFF — tap its switch to turn it on.
      await tester.tap(find.bySemanticsIdentifier('notif_prefs_marketing_toggle'));
      await tester.pump(); // optimistic update
      await tester.pump(const Duration(milliseconds: 30)); // debounce → PUT
      await tester.pump();

      expect(repo.lastSaved, isNotNull);
      expect(repo.lastSaved!.marketing, isTrue);
    });
  });
}
