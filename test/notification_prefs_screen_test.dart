// JM-058 — Notification Preferences (blueprint `notification-prefs`).

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_list_row.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'package:jeeb_mobile/features/notification_prefs/application/notification_prefs_cubit.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_model.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_repository.dart';
import 'package:jeeb_mobile/features/notification_prefs/presentation/notification_prefs_screen.dart';
import 'package:jeeb_mobile/features/settings/presentation/widgets/notification_toggle_track.dart';

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

/// A cold read that never resolves — the `NotificationPrefsLoading` branch.
class _PendingPrefsRepo implements NotificationPrefsRepository {
  @override
  Future<NotificationPrefs> fetch() => Completer<NotificationPrefs>().future;

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) =>
      Completer<NotificationPrefs>().future;
}

/// A cold read that fails — the `NotificationPrefsError` branch.
class _FailingPrefsRepo implements NotificationPrefsRepository {
  int fetchCount = 0;

  @override
  Future<NotificationPrefs> fetch() async {
    fetchCount++;
    throw const NotificationPrefsRepositoryException(
      NotificationPrefsFailure.network,
    );
  }

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) async =>
      throw const NotificationPrefsRepositoryException(
        NotificationPrefsFailure.network,
      );
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

Widget _harness(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // The empty-state illustrations loop by design, so pin the rest frame.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: child,
  );
}

Future<void> _pumpWithRepo(
  WidgetTester tester,
  NotificationPrefsRepository repo, {
  Locale locale = const Locale('en'),
}) async {
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
      locale: locale,
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<_FakePrefsRepo> _pumpLoaded(WidgetTester tester) async {
  final repo = _FakePrefsRepo();
  await _pumpWithRepo(tester, repo);
  return repo;
}

/// The `Semantics` widget carrying [identifier], as an element finder — the
/// `find.bySemanticsIdentifier` node finder cannot be composed with
/// `find.descendant`.
Finder _semanticsHost(String identifier) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == identifier,
    );

BoxDecoration _trackDecoration(WidgetTester tester, String rowIdentifier) {
  final track = find.descendant(
    of: _semanticsHost(rowIdentifier),
    matching: find.byType(NotificationToggleTrack),
  );
  expect(track, findsOneWidget);
  return tester
      .widget<DecoratedBox>(
        find.descendant(of: track, matching: find.byType(DecoratedBox)).first,
      )
      .decoration as BoxDecoration;
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

  group('MIDNIGHT M3-24 — carried from R22 (M2-19)', () {
    testWidgets('mounts the content field with R22\'s single top-end glow',
        (tester) async {
      await _pumpLoaded(tester);
      final field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      expect(field.variant, JeebFieldVariant.content);
      expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
      // R22 declares no periwinkle, and is board-still.
      expect(field.washPlacement, isNull);
      expect(field.animateDecor, isFalse);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.transparent,
        reason: 'an opaque scaffold would occlude the field.',
      );
    });

    testWidgets('an ON toggle draws the accent track, never the periwinkle one',
        (tester) async {
      await _pumpLoaded(tester);
      final roles = JeebColorRoles.midnight();
      // Defaults: offers/orderStatus/wallet ON, marketing OFF.
      final on = _trackDecoration(tester, 'notif_prefs_offers_toggle');

      expect(on.color, roles.accent);
      expect(on.color, isNot(JeebSemanticColors.midnight().mutedText),
          reason: 'the OMDS switch resolved its ON track off '
              'SwitchThemeData.trackColor — periwinkle inkMuted.');
      expect(on.boxShadow, hasLength(1));
      expect(
        on.boxShadow!.single.color,
        roles.accent.withValues(alpha: NotificationToggleTrack.glowAlpha),
      );
      expect(on.boxShadow!.single.blurRadius, NotificationToggleTrack.glowBlur);
    });

    testWidgets('an OFF toggle draws pressed glass and no bloom',
        (tester) async {
      await _pumpLoaded(tester);
      final off = _trackDecoration(tester, 'notif_prefs_marketing_toggle');

      expect(off.color, JeebSemanticColors.midnight().glassFillPressed);
      expect(off.boxShadow, isEmpty);
    });

    testWidgets('the knob is white and travels to the reading end when on',
        (tester) async {
      await _pumpLoaded(tester);
      final onTrack = find.descendant(
        of: _semanticsHost('notif_prefs_offers_toggle'),
        matching: find.byType(NotificationToggleTrack),
      );
      final knob = tester.widget<DecoratedBox>(
        find.descendant(of: onTrack, matching: find.byType(DecoratedBox)).last,
      );
      final decoration = knob.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, AppTheme.midnight().colorScheme.onPrimary);

      expect(
        tester
            .widget<Align>(
              find.descendant(of: onTrack, matching: find.byType(Align)),
            )
            .alignment,
        AlignmentDirectional.centerEnd,
      );
      final offTrack = find.descendant(
        of: _semanticsHost('notif_prefs_marketing_toggle'),
        matching: find.byType(NotificationToggleTrack),
      );
      expect(
        tester
            .widget<Align>(
              find.descendant(of: offTrack, matching: find.byType(Align)),
            )
            .alignment,
        AlignmentDirectional.centerStart,
      );
      final size = tester.getSize(onTrack);
      expect(size.width, NotificationToggleTrack.trackWidth);
      expect(size.height, NotificationToggleTrack.trackHeight);
    });

    testWidgets('the ON knob mirrors to the start edge under Arabic',
        (tester) async {
      await _pumpWithRepo(tester, _FakePrefsRepo(),
          locale: const Locale('ar'));
      final track = find.descendant(
        of: _semanticsHost('notif_prefs_offers_toggle'),
        matching: find.byType(NotificationToggleTrack),
      );
      final knob =
          find.descendant(of: track, matching: find.byType(SizedBox)).last;
      expect(
        tester.getCenter(knob).dx,
        lessThan(tester.getCenter(track).dx),
        reason: 'AlignmentDirectional.centerEnd is the LEFT half under RTL.',
      );
    });

    testWidgets('no Material switch survives on the screen', (tester) async {
      await _pumpLoaded(tester);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets('the locked transactional row is a row, not a dead switch',
        (tester) async {
      await _pumpLoaded(tester);
      final row = tester.widget<JeebListRow>(
        find.descendant(
          of: _semanticsHost('notif_prefs_transactional_lock_icon'),
          matching: find.byType(JeebListRow),
        ),
      );
      expect(row.onTap, isNull);
      expect((row.trailing! as Icon).icon, Icons.lock);
    });

    testWidgets('the cold read shows the radar illustration, not a spinner',
        (tester) async {
      await _pumpWithRepo(tester, _PendingPrefsRepo());
      final empty = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(empty.status, JeebEmptyStateStatus.loading);
      expect(empty.variant, JeebEmptyStateVariant.radar);
      expect(empty.medallions, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a failed read keeps the illustration and re-fetches on retry',
        (tester) async {
      final repo = _FailingPrefsRepo();
      await _pumpWithRepo(tester, repo);
      final empty = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(empty.status, JeebEmptyStateStatus.error);
      expect(empty.variant, JeebEmptyStateVariant.radar);
      expect(repo.fetchCount, 1);

      expect(find.bySemanticsIdentifier('notif_prefs_retry_cta'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(repo.fetchCount, 2);
    });
  });
}
