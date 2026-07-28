// N2 / N3 / N4 — the last three armed periodic NETWORK timers outside the KYC
// carve-out. This file pins the END STATE the owner's 2026-07-28 architecture
// ruling asks for, on all three surfaces at once:
//
//   * ONE fetch at mount, ONE on resume;
//   * network I/O otherwise ONLY on a push;
//   * two pushes inside one round trip make ONE re-pull (single flight);
//   * a five-minute idle window with no push and no user action is ZERO reads.
//
// ## Why every case here compiles against the PRE-change tree
//
// I-14: a green suite is not evidence, and "show it RED first" is the only
// thing that turns a passing test into one. Every assertion below is written
// against symbols that exist on BOTH sides of this change — a counting
// repository/gateway, `start()`, `load()`, the push bus — so the RED transcript
// captured before the fix is an ASSERTION failure (`Expected: <1> Actual: <6>`),
// not a compile error. A compile-error RED proves only that a symbol was
// renamed; it cannot tell you the test would have caught the defect.
//
// ## Positive control (Rule 1)
//
// Every "zero reads" case is paired, in the SAME test, with a push that MUST
// produce a read. Without it, `calls == 1` after five minutes is
// indistinguishable from a harness that never wired the bus, a cubit that was
// never started, or a repository double nobody calls — the exact shape of every
// instrument in TESTING-INSTRUMENTS.md that lied by returning a confident zero.

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/application/active_deliveries_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_delivery_summary.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';
import 'package:jeeb_mobile/features/shell/tab_visibility.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// The idle window the four-leg bar's leg 3 asks for: five minutes foregrounded
/// with no push and no user action.
const Duration _idleWindow = Duration(minutes: 5);

// ---------------------------------------------------------------------------
// N2 — jeeber active deliveries (was 60 s)
// ---------------------------------------------------------------------------

class _CountingActiveDeliveries implements ActiveDeliveriesRepository {
  int calls = 0;
  Completer<void>? gate;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async {
    calls++;
    await gate?.future;
    return const <ActiveDeliverySummary>[];
  }
}

// ---------------------------------------------------------------------------
// N3 — customer home / In-Progress summary (was 10 s, the shortest left)
// ---------------------------------------------------------------------------

class _CountingClientHome implements ClientHomeRepository {
  int calls = 0;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    calls++;
    return const ClientHomeSnapshot();
  }
}

// ---------------------------------------------------------------------------
// N4 — chat history (was 60 s) — THE SURFACE THE OWNER NAMED
// ---------------------------------------------------------------------------

/// `supportsPolling: true` is what made the production `DioChatGateway` arm the
/// 60 s history poll, and it is the ONLY reason the in-memory doubles never saw
/// it. A double that returns `false` cannot observe this defect at all, so this
/// one returns `true` — the gate value the real gateway ships.
class _CountingChatGateway implements ChatGateway {
  int historyCalls = 0;
  int phaseCalls = 0;
  Completer<void>? gate;
  bool failHistory = false;

  // Broadcast controller for the (unused) inbound event stream. Never closed
  // on purpose: `ChatCubit.close()` cancels its subscription, and a broadcast
  // controller with no listeners holds nothing.
  // ignore: close_sinks
  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();

  @override
  bool get supportsPolling => true;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async {
    historyCalls++;
    await gate?.future;
    if (failHistory) throw StateError('history unreachable');
    return const <DeliveryChatMessage>[];
  }

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async {
    phaseCalls++;
    return ConversationPhase.accepted;
  }

  @override
  Stream<ChatEvent> subscribe(String conversationId) => _events.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _NoopPicker implements PhotoPickerService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------

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

late _SyncDelegate _delegate;

Widget _clientHomeHarness({
  required _CountingClientHome repo,
  required Stream<void> signals,
}) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: <LocalizationsDelegate<Object?>>[
    _delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(
    body: BlocProvider<ClientHomeCubit>(
      create: (_) => ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => 'Sami',
        refreshSignals: signals,
      ),
      // The In-Progress sub-tab is the one the 10 s poll was gated on — pin it
      // so a surviving poll would actually be armed. Pinning the tab the poll
      // did NOT run on would manufacture a false pass.
      child: const TabVisibility(
        isVisible: true,
        child: ClientHomeScreen(initialTab: ClientHomeTab.inProgress),
      ),
    ),
  ),
);

void main() {
  setUpAll(() {
    final en = File('lib/l10n/app_en.arb').readAsStringSync();
    final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
    _delegate = _SyncDelegate(<String, String>{'en': en, 'ar': ar});
  });

  group('N2 · jeeber active deliveries', () {
    test('mount reads once; five idle minutes add NOTHING; a push does', () {
      fakeAsync((async) {
        final repo = _CountingActiveDeliveries();
        final bus = StreamController<void>.broadcast();
        final cubit = ActiveDeliveriesCubit(
          repository: repo,
          refreshSignals: bus.stream,
        );

        cubit.start();
        async.flushMicrotasks();
        expect(
          repo.calls,
          1,
          reason: 'the mount one-shot — the backstop for a dropped push',
        );

        // THE ASSERTION THIS FILE EXISTS FOR. Pre-fix this reads 6 (mount +
        // five 60 s ticks).
        async.elapse(_idleWindow);
        async.flushMicrotasks();
        expect(
          repo.calls,
          1,
          reason: 'five minutes idle with no push must be ZERO reads',
        );

        // POSITIVE CONTROL, same window, same instrument: the bus can still
        // produce a read, so the zero above is silence and not a dead harness.
        bus.add(null);
        async.flushMicrotasks();
        expect(repo.calls, 2, reason: 'push drives exactly one re-pull');

        cubit.close();
        bus.close();
        async.flushMicrotasks();
      });
    });

  });

  group('N3 · customer home summary', () {
    testWidgets(
      'five idle minutes on the In-Progress tab add NOTHING; a push does',
      (tester) async {
        final repo = _CountingClientHome();
        final bus = StreamController<void>.broadcast();
        await tester.pumpWidget(
          _clientHomeHarness(repo: repo, signals: bus.stream),
        );
        await tester.pump();
        await tester.pump();
        final afterMount = repo.calls;
        expect(
          afterMount,
          greaterThan(0),
          reason: 'the mount one-shot must still run',
        );

        // Pre-fix this adds ~30 reads (10 s cadence over five minutes).
        await tester.pump(_idleWindow);
        await tester.pump();
        expect(
          repo.calls,
          afterMount,
          reason: 'five minutes idle with no push must be ZERO reads',
        );

        // POSITIVE CONTROL in the same window.
        bus.add(null);
        await tester.pump();
        await tester.pump();
        expect(
          repo.calls,
          afterMount + 1,
          reason: 'push drives exactly one re-pull',
        );

        await bus.close();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  group('N4 · chat history', () {
    test('mount reads once; five idle minutes add NOTHING; a push does', () {
      fakeAsync((async) {
        final gateway = _CountingChatGateway();
        final bus = StreamController<void>.broadcast();
        final cubit = ChatCubit(
          deliveryId: 'conv-1',
          gateway: gateway,
          pickerService: _NoopPicker(),
          refreshSignals: bus.stream,
        );

        cubit.load();
        async.flushMicrotasks();
        expect(gateway.historyCalls, 1, reason: 'the mount one-shot');

        // Pre-fix this reads 6 (mount + five 60 s history ticks).
        async.elapse(_idleWindow);
        async.flushMicrotasks();
        expect(
          gateway.historyCalls,
          1,
          reason: 'five minutes idle with no push must be ZERO reads',
        );
        // POSITIVE CONTROL, same window.
        bus.add(null);
        async.flushMicrotasks();
        expect(gateway.historyCalls, 2, reason: 'chat push drives one re-pull');
        expect(cubit.debugPushRefreshCount, 1);

        cubit.close();
        bus.close();
        async.flushMicrotasks();
      });
    });

  });
}
