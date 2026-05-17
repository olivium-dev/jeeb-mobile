import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/domain/recent_delivery_summary.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) =>
      _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return debugLoadAppLocalizationsSync(
      locale,
      _arbByTag[locale.languageCode]!,
    );
  }

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
  required ClientHomeRepository repo,
  String? greetingName,
  void Function(ClientHomeRequest)? onOpenRequest,
  VoidCallback? onCreateRequest,
  void Function(RecentDeliverySummary)? onReorder,
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
    home: Scaffold(
      body: BlocProvider(
        create: (_) => ClientHomeCubit(
          repository: repo,
          greetingNameProvider: () => greetingName,
        ),
        child: ClientHomeScreen(
          onOpenRequest: onOpenRequest,
          onCreateRequest: onCreateRequest,
          onReorder: onReorder,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(_loadArbs);

  group('ClientHomeScreen empty state', () {
    testWidgets(
        'renders greeting, voice CTA, and "create your first request" CTA '
        'when no active deliveries exist', (tester) async {
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(
        _harness(
          repo: repo,
          greetingName: 'Layla',
          onCreateRequest: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hi, Layla'), findsOneWidget);
      expect(find.text('Record a request'), findsOneWidget);
      expect(find.byKey(const Key('client-home-empty-state')), findsOneWidget);
      expect(find.text('Create your first request'), findsOneWidget);
      expect(
        find.byKey(const Key('client-home-active-section')),
        findsNothing,
      );
    });

    testWidgets('falls back to generic greeting when no name is provided',
        (tester) async {
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('empty-state CTA invokes onCreateRequest', (tester) async {
      var taps = 0;
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(_harness(
        repo: repo,
        onCreateRequest: () => taps += 1,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create your first request'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('voice CTA invokes onCreateRequest', (tester) async {
      var taps = 0;
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(_harness(
        repo: repo,
        onCreateRequest: () => taps += 1,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('client-home-voice-cta')));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });

  group('ClientHomeScreen populated state', () {
    testWidgets(
        'renders an active request card with status, ETA, and Jeeber name',
        (tester) async {
      final repo = InMemoryClientHomeRepository(
        latency: Duration.zero,
        seedActive: const [
          ClientHomeRequest(
            id: 'r-7',
            title: 'Pharmacy run',
            destinationLabel: 'Ashrafieh, Beirut',
            status: ClientRequestStatus.enRoute,
            etaMinutes: 8,
            jeeberName: 'Karim',
          ),
        ],
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('active-request-card-r-7')),
        findsOneWidget,
      );
      expect(find.text('Pharmacy run'), findsOneWidget);
      expect(find.text('On the way'), findsOneWidget);
      expect(find.text('8 min away'), findsOneWidget);
      expect(find.text('with Karim'), findsOneWidget);
      expect(
        find.byKey(const Key('client-home-empty-state')),
        findsNothing,
      );
    });

    testWidgets('tapping an active card invokes onOpenRequest with that request',
        (tester) async {
      ClientHomeRequest? opened;
      final repo = InMemoryClientHomeRepository(
        latency: Duration.zero,
        seedActive: const [
          ClientHomeRequest(
            id: 'r-1',
            title: 'Grocery pickup',
            destinationLabel: 'Hamra',
            status: ClientRequestStatus.searching,
          ),
        ],
      );
      await tester.pumpWidget(_harness(
        repo: repo,
        onOpenRequest: (r) => opened = r,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('active-request-card-r-1')));
      await tester.pumpAndSettle();

      expect(opened?.id, 'r-1');
    });

    testWidgets('renders "Order again" with the most recent completed delivery',
        (tester) async {
      final repo = InMemoryClientHomeRepository(
        latency: Duration.zero,
        seedRecent: [
          RecentDeliverySummary(
            id: 'd-1',
            title: 'Sushi from Caspar',
            destinationLabel: 'Mar Mikhael',
            completedAt: DateTime.utc(2026, 5, 16),
          ),
        ],
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Order again'), findsOneWidget);
      expect(find.text('Sushi from Caspar'), findsOneWidget);
      expect(find.text('Re-order'), findsOneWidget);
    });

    testWidgets('Re-order tap invokes onReorder with the right summary',
        (tester) async {
      RecentDeliverySummary? reordered;
      final repo = InMemoryClientHomeRepository(
        latency: Duration.zero,
        seedRecent: [
          RecentDeliverySummary(
            id: 'd-9',
            title: 'Late-night water',
            destinationLabel: 'Achrafieh',
            completedAt: DateTime.utc(2026, 5, 16),
          ),
        ],
      );
      await tester.pumpWidget(_harness(
        repo: repo,
        onReorder: (s) => reordered = s,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recent-delivery-reorder-d-9')));
      await tester.pumpAndSettle();

      expect(reordered?.id, 'd-9');
    });
  });

  group('ClientHomeScreen i18n', () {
    testWidgets('renders Arabic strings under ar locale', (tester) async {
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(_harness(
        repo: repo,
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ماذا تحتاج؟'), findsOneWidget);
      expect(find.text('سجّل طلبًا'), findsOneWidget);
    });
  });
}
