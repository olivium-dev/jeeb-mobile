// The client-home create surface (redesign-2026-08 screen 04).
//
// The buried "+" icon button became the navy mic hero. Two things must hold on
// EVERY load phase, not just the happy one — a customer who cannot start a
// request because the list is loading or the gateway 429'd is the defect these
// pin:
//   * `orders_create_request_button` (frozen: jm-023/jm-024, flows 08/13/14/15,
//     client_home_429_tolerant_test) is present and tappable;
//   * `client_home_mic_cta` (newly coined) is present.
//
// Plus the two negative pins the July "single create entry point" directive
// left behind, which the hero must NOT revive, and an RTL smoke test.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_mic_hero.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';

import '../../support/sync_app_localizations.dart';

/// Never completes — pins the screen in its loading layout.
class _HangingRepo implements ClientHomeRepository {
  @override
  Future<ClientHomeSnapshot> loadSnapshot() => Completer<ClientHomeSnapshot>()
      .future;
}

/// Always throws — pins the screen in its failed layout.
class _FailingRepo implements ClientHomeRepository {
  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      throw StateError('offline');
}

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
    // Midnight primitives loop ∞ (02-STUDY-NOTES M0-4): `pumpAndSettle` only
    // terminates under reduce motion.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      body: BlocProvider(
        create: (_) =>
            ClientHomeCubit(repository: repo, greetingNameProvider: () => 'Lina'),
        child: ClientHomeScreen(
          initialTab: ClientHomeTab.pendingRequests,
          onCreateRequest: () {},
        ),
      ),
    ),
  );
}

const _reply = ClientHomeRequest(
  id: 'rep-1',
  title: 'ORD-23470',
  displayId: 'ORD-23470',
  destinationLabel: 'Spinneys Achrafieh',
  itemsSummary: 'Groceries',
  status: ClientRequestStatus.offersReceived,
  tier: ClientRequestTier.onTheWay,
  offerCount: 3,
  offerAvatarUrls: <String>['a', 'b', 'c'],
);

void main() {
  group('ClientHomeRequestHero is reachable on every load phase', () {
    for (final entry in <String, ClientHomeRepository Function()>{
      'ready': () => InMemoryClientHomeRepository(latency: Duration.zero),
      'loading': _HangingRepo.new,
      'failed': _FailingRepo.new,
    }.entries) {
      testWidgets('${entry.key} layout exposes both hero ids', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_harness(repo: entry.value()));
        // No pumpAndSettle: the loading layout never settles by design.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.bySemanticsIdentifier('orders_create_request_button'),
          findsOneWidget,
        );
        expect(
          tester
              .getSemantics(
                find.bySemanticsIdentifier('orders_create_request_button'),
              )
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
          reason: 'a create surface with no tap handler is the guarded defect',
        );
        expect(
          find.bySemanticsIdentifier('client_home_mic_cta'),
          findsOneWidget,
        );

        // The retired ids stay retired — the hero is a NEW surface, not the
        // revival of the deleted voice CTA.
        expect(
          find.bySemanticsIdentifier('client_home_voice_request'),
          findsNothing,
        );
        expect(
          find.byKey(const Key('client-home-voice-cta')),
          findsNothing,
        );
        handle.dispose();
      });
    }
  });

  testWidgets('exactly one create surface exists on the ready screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(repo: InMemoryClientHomeRepository(latency: Duration.zero)),
    );
    await tester.pumpAndSettle();

    // The July directive's intent: one create SURFACE. The prompt text renders
    // once, in the hero — the empty view no longer repeats it.
    expect(find.text('What do you need?'), findsOneWidget);
    expect(find.byType(JeebMicHero), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('ar: the screen mirrors and the mic sits at the start edge', (
    tester,
  ) async {
    final repo = InMemoryClientHomeRepository.fromSnapshot(
      const ClientHomeSnapshot(replies: [_reply]),
      latency: Duration.zero,
    );
    await tester.pumpWidget(
      _harness(repo: repo, locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(JeebMicHero))),
      TextDirection.rtl,
    );
    // Start edge under RTL is the RIGHT edge: the mic's right side must sit
    // near the screen's right gutter, not the left.
    final micRight = tester.getTopRight(find.byType(JeebMicHero)).dx;
    final screenWidth = tester.getSize(find.byType(ClientHomeScreen)).width;
    expect(
      screenWidth - micRight,
      lessThan(screenWidth / 2),
      reason: 'the mic must mirror to the start (right) edge under ar',
    );
    // The whole screen laid out without an overflow (the tester turns those
    // into test failures automatically, so simply arriving here is the pin).
    expect(tester.takeException(), isNull);
  });
}
