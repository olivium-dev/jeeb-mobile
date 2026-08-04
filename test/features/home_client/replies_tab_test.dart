// Tests for T-MOB-008: RepliesTab with stacked avatars and Check Offers CTA.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/replies_tab.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/replies_card.dart';

import '../../support/sync_app_localizations.dart';

Widget _harness({
  required ClientHomeRepository repo,
  void Function(ClientHomeRequest)? onCheckOffers,
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
    // Midnight primitives loop ∞ (02-STUDY-NOTES M0-4): `pumpAndSettle` only
    // terminates under reduce motion.
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
        child: RepliesTab(onCheckOffers: onCheckOffers),
      ),
    ),
  );
}

ClientHomeRequest _repliesRequest({
  String id = 'rep-1',
  String displayId = 'ORD-23470',
  int offerCount = 5,
  List<String>? avatarUrls,
  String? conversationId,
}) =>
    ClientHomeRequest(
      id: id,
      displayId: displayId,
      title: displayId,
      status: ClientRequestStatus.offersReceived,
      destinationLabel: 'Hamra, Beirut',
      tier: ClientRequestTier.express,
      offerCount: offerCount,
      offerAvatarUrls: avatarUrls ?? ['url1', 'url2', 'url3'],
      conversationId: conversationId ?? 'conv-$id',
    );

void main() {
  group('RepliesTab — T-MOB-008', () {
    testWidgets('AC1: row renders with 3 avatars + overflow for 5 offers',
        (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          replies: [_repliesRequest(offerCount: 5, avatarUrls: ['a', 'b', 'c'])],
        ),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('replies-tab-list')), findsOneWidget);
      expect(find.byKey(const Key('replies-card-rep-1')), findsOneWidget);
      // Overflow "+2" (5 total - 3 inline = 2 extra)
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('AC1: offer count badge shown correctly', (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          replies: [
            _repliesRequest(offerCount: 9, avatarUrls: ['a', 'b', 'c']),
          ],
        ),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      // 9 - 3 = 6 extra, so "+6"
      expect(find.text('+6'), findsOneWidget);
    });

    testWidgets('AC3: tapping Check Offers invokes onCheckOffers',
        (tester) async {
      ClientHomeRequest? opened;
      final request = _repliesRequest(id: 'rep-nav', conversationId: 'conv-nav');
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(replies: [request]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(
        repo: repo,
        onCheckOffers: (r) => opened = r,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('replies-check-offers-rep-nav')));
      await tester.pumpAndSettle();

      expect(opened?.id, 'rep-nav');
    });

    testWidgets('AC4: avatar stack carries Semantics identifier', (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          replies: [_repliesRequest(id: 'sem-1', offerCount: 3)],
        ),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsIdentifier('orders_replies_avatar_stack_sem-1'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('AC5: empty state when no replies', (tester) async {
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('replies-empty')), findsOneWidget);
      expect(find.byKey(const Key('replies-tab-list')), findsNothing);
    });

    testWidgets('renders RepliesCard for each reply', (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          replies: [
            _repliesRequest(id: 'r1'),
            _repliesRequest(id: 'r2'),
          ],
        ),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.byType(RepliesCard), findsNWidgets(2));
    });

    testWidgets('Arabic: Check Offers CTA renders in Arabic', (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(replies: [_repliesRequest()]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo, locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('عرض العروض'), findsOneWidget);
      expect(find.text('Check Offers'), findsNothing);
    });
  });
}
