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

      expect(find.text('Hello, Layla'), findsOneWidget);
      expect(find.text('Create your first request'), findsOneWidget);
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

    testWidgets('greeting add button invokes onCreateRequest', (tester) async {
      var taps = 0;
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(_harness(
        repo: repo,
        onCreateRequest: () => taps += 1,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('client-home-greeting-add')));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });

  group('ClientHomeScreen populated state', () {
    testWidgets(
        'renders an active request card with title, destination, and progress labels',
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
      expect(find.text('Ashrafieh, Beirut'), findsOneWidget);
      expect(find.text('Ordered'), findsOneWidget);
      expect(find.text('Picked'), findsOneWidget);
      expect(find.text('In Transit'), findsOneWidget);
    });

    testWidgets('tapping "Track my order" invokes onOpenRequest with that request',
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

      await tester.tap(find.text('Track my order'));
      await tester.pumpAndSettle();

      expect(opened?.id, 'r-1');
    });

    // Recent deliveries section ("Order again" / "Re-order") was removed in
    // the tabbed redesign. The home screen now shows In Progress / Pending
    // Requests / Replies tabs instead.
  });

  group('ClientHomeScreen i18n', () {
    testWidgets('renders Arabic strings under ar locale', (tester) async {
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(_harness(
        repo: repo,
        locale: const Locale('ar'),
        onCreateRequest: () {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('ماذا تحتاج؟'), findsOneWidget);
      expect(find.text('أنشئ أول طلب لك'), findsOneWidget);
    });
  });
}
