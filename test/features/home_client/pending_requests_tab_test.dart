import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_system_chip.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/pending_requests_tab.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

Widget _harness({
  required ClientHomeRepository repo,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // Midnight primitives loop ∞ (02-STUDY-NOTES M0-4), so `pumpAndSettle`
    // only terminates under reduce motion — the sanctioned way to settle a
    // tree that mounts them.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      body: BlocProvider(
        create: (_) => ClientHomeCubit(
          repository: repo,
          greetingNameProvider: () => 'Sami',
        )..load(),
        child: const PendingRequestsTab(),
      ),
    ),
  );
}

ClientHomeRequest _pendingRequest({
  String id = 'pen-1',
  String displayId = 'ORD-23470',
  int? ttlSeconds,
  int offerCount = 0,
  bool hasNewOffers = false,
  DateTime? createdAt,
}) => ClientHomeRequest(
  id: id,
  displayId: displayId,
  title: displayId,
  status: ClientRequestStatus.searching,
  destinationLabel: 'Achrafieh',
  tier: ClientRequestTier.express,
  ttlSeconds: ttlSeconds,
  offerCount: offerCount,
  hasNewOffers: hasNewOffers,
  createdAt: createdAt,
);

class _MutableClientHomeRepository implements ClientHomeRepository {
  _MutableClientHomeRepository(this.snapshot);

  ClientHomeSnapshot snapshot;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async => snapshot;
}

void main() {
  group('PendingRequestsTab — T-MOB-007', () {
    testWidgets('AC1: pending row renders with order id and tier', (
      tester,
    ) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(pending: [_pendingRequest()]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('pending-requests-tab-list')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pending-countdown-card-pen-1')),
        findsOneWidget,
      );
      expect(find.text('ORD-23470'), findsOneWidget);
    });

    testWidgets(
      'server-pending row without expiry shows searching, not expired',
      (tester) async {
        final repo = InMemoryClientHomeRepository.fromSnapshot(
          ClientHomeSnapshot(pending: [_pendingRequest()]),
          latency: Duration.zero,
        );
        await tester.pumpWidget(_harness(repo: repo));
        await tester.pumpAndSettle();

        expect(find.text('Broadcasting'), findsOneWidget);
        expect(find.text('Expired'), findsNothing);
        expect(find.byKey(const Key('pending-server-status')), findsOneWidget);
      },
    );

    testWidgets(
      'legacy zero TTL cannot override authoritative pending status',
      (tester) async {
        final repo = InMemoryClientHomeRepository.fromSnapshot(
          ClientHomeSnapshot(pending: [_pendingRequest(ttlSeconds: 0)]),
          latency: Duration.zero,
        );
        await tester.pumpWidget(_harness(repo: repo));
        await tester.pumpAndSettle();

        expect(find.text('Broadcasting'), findsOneWidget);
        expect(find.text('Expired'), findsNothing);
      },
    );

    testWidgets(
      'server-pending card stays tappable even when a legacy zero TTL exists',
      (tester) async {
        var tapped = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              SyncAppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: PendingCountdownCard(
                request: _pendingRequest(ttlSeconds: 0),
                onTap: () => tapped++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Expired'), findsNothing);
        expect(find.text('Broadcasting'), findsOneWidget);
        await tester.tap(find.byKey(const Key('pending-countdown-card-pen-1')));
        expect(tapped, 1);
      },
    );

    testWidgets('empty state when no pending requests', (tester) async {
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending-empty')), findsOneWidget);
      expect(find.byKey(const Key('pending-requests-tab-list')), findsNothing);
      // E1 draws the headline INSIDE the empty block (the screen drops its own
      // prompt in this composition, so it is still printed exactly once).
      expect(find.text('Ready when you are'), findsOneWidget);
      expect(
        find.text(
          'No pending requests — say it, and offers from nearby Jeebers '
          'arrive in minutes.',
        ),
        findsOneWidget,
      );
      // The board draws no CTA button here — the voice capsule the SCREEN
      // mounts below is the create affordance (doc-13 Pattern D).
      expect(find.text('Create your first request'), findsNothing);
      expect(find.byType(JeebEmptyState), findsOneWidget);
      expect(find.byType(LottieBuilder), findsNothing);
    });

    testWidgets('each pending row renders its own server-derived status', (
      tester,
    ) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          pending: [
            _pendingRequest(id: 'p1', displayId: 'ORD-001'),
            _pendingRequest(id: 'p2', displayId: 'ORD-002'),
          ],
        ),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.byType(PendingCountdownCard), findsNWidgets(2));
      expect(find.text('Broadcasting'), findsNWidgets(2));
      expect(find.text('Expired'), findsNothing);
    });

    testWidgets(
      'refresh removes a row only when the server snapshot removes it',
      (tester) async {
        final repo = _MutableClientHomeRepository(
          ClientHomeSnapshot(pending: [_pendingRequest()]),
        );
        await tester.pumpWidget(_harness(repo: repo));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('pending-countdown-card-pen-1')),
          findsOneWidget,
        );

        repo.snapshot = const ClientHomeSnapshot();
        final cubit = BlocProvider.of<ClientHomeCubit>(
          tester.element(find.byType(PendingRequestsTab)),
        );
        await cubit.refresh();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('pending-countdown-card-pen-1')),
          findsNothing,
        );
        expect(find.byKey(const Key('pending-empty')), findsOneWidget);
      },
    );

    testWidgets('reconnect banner hidden when visible=false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          supportedLocales: [Locale('en')],
          localizationsDelegates: [
            SyncAppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: PendingReconnectBanner(visible: false)),
        ),
      );
      expect(find.byKey(const Key('pending-reconnect-banner')), findsNothing);
    });

    testWidgets('reconnect banner visible when visible=true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          supportedLocales: [Locale('en')],
          localizationsDelegates: [
            SyncAppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: PendingReconnectBanner(visible: true)),
        ),
      );
      expect(find.byKey(const Key('pending-reconnect-banner')), findsOneWidget);
      expect(find.text('Reconnecting…'), findsOneWidget);
    });
  });

  group('PendingRequestsTab — M2 offers badge', () {
    testWidgets(
      'offers badge replaces the searching line when offerCount > 0',
      (tester) async {
        final repo = InMemoryClientHomeRepository.fromSnapshot(
          ClientHomeSnapshot(pending: [_pendingRequest(offerCount: 3)]),
          latency: Duration.zero,
        );
        await tester.pumpWidget(_harness(repo: repo));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('pending-offers-badge')), findsOneWidget);
        expect(find.text('3 offers'), findsOneWidget);
        expect(find.text('Broadcasting'), findsNothing);
        expect(find.byKey(const Key('pending-server-status')), findsNothing);
      },
    );

    testWidgets('a single offer uses the singular form', (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(pending: [_pendingRequest(offerCount: 1)]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();
      expect(find.text('1 offer'), findsOneWidget);
    });

    testWidgets('badge is emphasised (filled) only when hasNewOffers is set', (
      tester,
    ) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          pending: [
            _pendingRequest(id: 'p-new', offerCount: 2, hasNewOffers: true),
          ],
        ),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();
      final chip = tester.widget<JeebSystemChip>(
        find.byKey(const Key('pending-offers-badge')),
      );
      expect(chip.tone, JeebSystemChipTone.accent);
    });

    testWidgets('badge is tonal (not filled) when the offers are not new', (
      tester,
    ) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          pending: [_pendingRequest(offerCount: 2, hasNewOffers: false)],
        ),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();
      final chip = tester.widget<JeebSystemChip>(
        find.byKey(const Key('pending-offers-badge')),
      );
      expect(chip.tone, JeebSystemChipTone.filled);
    });

    testWidgets('offers badge renders localized Arabic text', (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(pending: [_pendingRequest(offerCount: 1)]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo, locale: const Locale('ar')));
      await tester.pumpAndSettle();
      expect(find.text('عرض واحد'), findsOneWidget);
    });
  });

  group('PendingRequestsTab — M2 age line', () {
    testWidgets('shows "created N ago" derived from a real createdAt', (
      tester,
    ) async {
      final created = DateTime.now().toUtc().subtract(
        const Duration(minutes: 12, seconds: 30),
      );
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(pending: [_pendingRequest(createdAt: created)]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending-created-age')), findsOneWidget);
      expect(find.text('Created 12 minutes ago'), findsOneWidget);
    });

    testWidgets('no age line at all when createdAt is null (no fabrication)', (
      tester,
    ) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(pending: [_pendingRequest()]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending-created-age')), findsNothing);
      expect(find.byKey(const Key('pending-server-status')), findsOneWidget);
    });

    testWidgets('a fresh request (<1 min old) reads "just now"', (
      tester,
    ) async {
      final created = DateTime.now().toUtc().subtract(
        const Duration(seconds: 20),
      );
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(pending: [_pendingRequest(createdAt: created)]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();
      expect(find.text('Created just now'), findsOneWidget);
    });

    testWidgets('age line renders localized Arabic text', (tester) async {
      final created = DateTime.now().toUtc().subtract(
        const Duration(minutes: 3),
      );
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(pending: [_pendingRequest(createdAt: created)]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo, locale: const Locale('ar')));
      await tester.pumpAndSettle();
      expect(find.text('أُنشئ قبل 3 دقائق'), findsOneWidget);
    });
  });

  group('pendingCreatedAgeLabel — honest "ago", never a countdown', () {
    late AppLocalizations en;
    setUpAll(() {
      final raw = File('lib/l10n/app_en.arb').readAsStringSync();
      en = debugLoadAppLocalizationsSync(const Locale('en'), raw);
    });

    final base = DateTime.utc(2026, 6, 26, 12);

    test('under a minute → just now', () {
      expect(
        pendingCreatedAgeLabel(en, base, base.add(const Duration(seconds: 40))),
        'Created just now',
      );
    });

    test('a future createdAt (clock skew) → just now, never negative', () {
      expect(
        pendingCreatedAgeLabel(
          en,
          base,
          base.subtract(const Duration(minutes: 5)),
        ),
        'Created just now',
      );
    });

    test('minutes forms', () {
      expect(
        pendingCreatedAgeLabel(en, base, base.add(const Duration(minutes: 1))),
        'Created 1 minute ago',
      );
      expect(
        pendingCreatedAgeLabel(en, base, base.add(const Duration(minutes: 59))),
        'Created 59 minutes ago',
      );
    });

    test('hours forms', () {
      expect(
        pendingCreatedAgeLabel(en, base, base.add(const Duration(minutes: 60))),
        'Created 1 hour ago',
      );
      expect(
        pendingCreatedAgeLabel(en, base, base.add(const Duration(hours: 23))),
        'Created 23 hours ago',
      );
    });

    test('days forms', () {
      expect(
        pendingCreatedAgeLabel(en, base, base.add(const Duration(hours: 24))),
        'Created 1 day ago',
      );
      expect(
        pendingCreatedAgeLabel(en, base, base.add(const Duration(days: 3))),
        'Created 3 days ago',
      );
    });
  });
}
